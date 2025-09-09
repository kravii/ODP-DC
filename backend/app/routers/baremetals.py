from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import ipaddress

from app.core.database import get_db
from app.core.security import get_current_active_user, require_admin
from app.models.user import User
from app.models.baremetal import Baremetal
from app.models.monitoring import ResourcePool
from app.schemas.baremetal import BaremetalCreate, BaremetalResponse, BaremetalUpdate
from app.tasks.baremetal_tasks import update_resource_pool

router = APIRouter()

@router.post("/", response_model=BaremetalResponse)
async def create_baremetal(
    baremetal: BaremetalCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    # Validate IP address
    try:
        ipaddress.ip_address(baremetal.ip_address)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid IP address format"
        )
    
    # Check if hostname already exists
    if db.query(Baremetal).filter(Baremetal.hostname == baremetal.hostname).first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Hostname already exists"
        )
    
    # Check if IP already exists
    if db.query(Baremetal).filter(Baremetal.ip_address == baremetal.ip_address).first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="IP address already exists"
        )
    
    # Create baremetal
    db_baremetal = Baremetal(
        hostname=baremetal.hostname,
        ip_address=baremetal.ip_address,
        cpu_cores=baremetal.cpu_cores,
        memory_gb=baremetal.memory_gb,
        storage_gb=baremetal.storage_gb,
        iops=baremetal.iops
    )
    db.add(db_baremetal)
    db.commit()
    db.refresh(db_baremetal)
    
    # Update resource pool
    update_resource_pool.delay()
    
    return db_baremetal

@router.get("/", response_model=List[BaremetalResponse])
async def read_baremetals(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    baremetals = db.query(Baremetal).offset(skip).limit(limit).all()
    return baremetals

@router.get("/{baremetal_id}", response_model=BaremetalResponse)
async def read_baremetal(
    baremetal_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    baremetal = db.query(Baremetal).filter(Baremetal.id == baremetal_id).first()
    if baremetal is None:
        raise HTTPException(status_code=404, detail="Baremetal not found")
    return baremetal

@router.put("/{baremetal_id}", response_model=BaremetalResponse)
async def update_baremetal(
    baremetal_id: str,
    baremetal_update: BaremetalUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    baremetal = db.query(Baremetal).filter(Baremetal.id == baremetal_id).first()
    if baremetal is None:
        raise HTTPException(status_code=404, detail="Baremetal not found")
    
    # Update fields
    if baremetal_update.hostname is not None:
        baremetal.hostname = baremetal_update.hostname
    if baremetal_update.ip_address is not None:
        try:
            ipaddress.ip_address(baremetal_update.ip_address)
            baremetal.ip_address = baremetal_update.ip_address
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid IP address format"
            )
    if baremetal_update.cpu_cores is not None:
        baremetal.cpu_cores = baremetal_update.cpu_cores
    if baremetal_update.memory_gb is not None:
        baremetal.memory_gb = baremetal_update.memory_gb
    if baremetal_update.storage_gb is not None:
        baremetal.storage_gb = baremetal_update.storage_gb
    if baremetal_update.iops is not None:
        baremetal.iops = baremetal_update.iops
    if baremetal_update.status is not None:
        baremetal.status = baremetal_update.status
    
    db.commit()
    db.refresh(baremetal)
    
    # Update resource pool
    update_resource_pool.delay()
    
    return baremetal

@router.delete("/{baremetal_id}")
async def delete_baremetal(
    baremetal_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    baremetal = db.query(Baremetal).filter(Baremetal.id == baremetal_id).first()
    if baremetal is None:
        raise HTTPException(status_code=404, detail="Baremetal not found")
    
    # Check if baremetal has running VMs
    if baremetal.vms and len(baremetal.vms) > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete baremetal with running VMs"
        )
    
    db.delete(baremetal)
    db.commit()
    
    # Update resource pool
    update_resource_pool.delay()
    
    return {"message": "Baremetal deleted successfully"}

@router.get("/pool/resources")
async def get_resource_pool(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    pool = db.query(ResourcePool).first()
    if pool is None:
        return {
            "total_cpu_cores": 0,
            "total_memory_gb": 0,
            "total_storage_gb": 0,
            "total_iops": 0,
            "available_cpu_cores": 0,
            "available_memory_gb": 0,
            "available_storage_gb": 0,
            "available_iops": 0
        }
    return pool