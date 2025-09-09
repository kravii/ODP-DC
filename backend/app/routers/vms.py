from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import ipaddress

from app.core.database import get_db
from app.core.security import get_current_active_user, require_admin
from app.models.user import User
from app.models.vm import VM, VMImage, VMStorageMount
from app.models.baremetal import Baremetal
from app.models.monitoring import ResourcePool
from app.schemas.vm import VMCreate, VMResponse, VMUpdate, VMImageResponse, VMStorageMountCreate
from app.tasks.vm_tasks import create_vm_task, delete_vm_task
from app.tasks.baremetal_tasks import update_resource_pool

router = APIRouter()

@router.get("/images", response_model=List[VMImageResponse])
async def get_vm_images(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    images = db.query(VMImage).filter(VMImage.is_active == True).all()
    return images

@router.post("/", response_model=VMResponse)
async def create_vm(
    vm: VMCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    # Validate IP address if provided
    if vm.ip_address:
        try:
            ipaddress.ip_address(vm.ip_address)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid IP address format"
            )
    
    # Check if hostname already exists
    if db.query(VM).filter(VM.hostname == vm.hostname).first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Hostname already exists"
        )
    
    # Check if IP already exists
    if vm.ip_address and db.query(VM).filter(VM.ip_address == vm.ip_address).first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="IP address already exists"
        )
    
    # Get VM image
    image = db.query(VMImage).filter(VMImage.id == vm.image_id).first()
    if not image:
        raise HTTPException(status_code=404, detail="VM image not found")
    
    # Check resource availability
    pool = db.query(ResourcePool).first()
    if not pool:
        raise HTTPException(status_code=500, detail="Resource pool not initialized")
    
    if pool.available_cpu_cores < vm.cpu_cores:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Insufficient CPU cores available"
        )
    
    if pool.available_memory_gb < (vm.memory_mb / 1024):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Insufficient memory available"
        )
    
    # Find suitable baremetal
    suitable_baremetal = db.query(Baremetal).filter(
        Baremetal.status == 'active',
        Baremetal.cpu_cores >= vm.cpu_cores,
        Baremetal.memory_gb >= (vm.memory_mb / 1024)
    ).first()
    
    if not suitable_baremetal:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No suitable baremetal server available"
        )
    
    # Create VM record
    db_vm = VM(
        hostname=vm.hostname,
        ip_address=vm.ip_address,
        baremetal_id=suitable_baremetal.id,
        image_id=vm.image_id,
        cpu_cores=vm.cpu_cores,
        memory_mb=vm.memory_mb,
        created_by=current_user.id
    )
    db.add(db_vm)
    db.commit()
    db.refresh(db_vm)
    
    # Create storage mounts
    for mount in vm.storage_mounts:
        db_mount = VMStorageMount(
            vm_id=db_vm.id,
            mount_point=mount.mount_point,
            storage_gb=mount.storage_gb,
            storage_type=mount.storage_type
        )
        db.add(db_mount)
    
    db.commit()
    
    # Start VM creation task
    create_vm_task.delay(str(db_vm.id))
    
    # Update resource pool
    update_resource_pool.delay()
    
    return db_vm

@router.get("/", response_model=List[VMResponse])
async def read_vms(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    vms = db.query(VM).offset(skip).limit(limit).all()
    return vms

@router.get("/{vm_id}", response_model=VMResponse)
async def read_vm(
    vm_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    vm = db.query(VM).filter(VM.id == vm_id).first()
    if vm is None:
        raise HTTPException(status_code=404, detail="VM not found")
    return vm

@router.put("/{vm_id}", response_model=VMResponse)
async def update_vm(
    vm_id: str,
    vm_update: VMUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    vm = db.query(VM).filter(VM.id == vm_id).first()
    if vm is None:
        raise HTTPException(status_code=404, detail="VM not found")
    
    # Check permissions (users can only modify their own VMs unless admin)
    if current_user.role != "admin" and vm.created_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    # Update fields
    if vm_update.hostname is not None:
        vm.hostname = vm_update.hostname
    if vm_update.ip_address is not None:
        try:
            ipaddress.ip_address(vm_update.ip_address)
            vm.ip_address = vm_update.ip_address
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid IP address format"
            )
    if vm_update.cpu_cores is not None:
        vm.cpu_cores = vm_update.cpu_cores
    if vm_update.memory_mb is not None:
        vm.memory_mb = vm_update.memory_mb
    if vm_update.status is not None:
        vm.status = vm_update.status
    
    db.commit()
    db.refresh(vm)
    
    return vm

@router.delete("/{vm_id}")
async def delete_vm(
    vm_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    vm = db.query(VM).filter(VM.id == vm_id).first()
    if vm is None:
        raise HTTPException(status_code=404, detail="VM not found")
    
    # Check permissions
    if current_user.role != "admin" and vm.created_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    # Start VM deletion task
    delete_vm_task.delay(str(vm.id))
    
    # Update VM status
    vm.status = 'deleting'
    db.commit()
    
    # Update resource pool
    update_resource_pool.delay()
    
    return {"message": "VM deletion started"}

@router.post("/{vm_id}/start")
async def start_vm(
    vm_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    vm = db.query(VM).filter(VM.id == vm_id).first()
    if vm is None:
        raise HTTPException(status_code=404, detail="VM not found")
    
    # Check permissions
    if current_user.role != "admin" and vm.created_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    # Update VM status
    vm.status = 'running'
    db.commit()
    
    return {"message": "VM started"}

@router.post("/{vm_id}/stop")
async def stop_vm(
    vm_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    vm = db.query(VM).filter(VM.id == vm_id).first()
    if vm is None:
        raise HTTPException(status_code=404, detail="VM not found")
    
    # Check permissions
    if current_user.role != "admin" and vm.created_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    # Update VM status
    vm.status = 'stopped'
    db.commit()
    
    return {"message": "VM stopped"}