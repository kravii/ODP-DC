"""
VM Provisioning API
Handles VM creation, management, and monitoring for Hetzner DC
"""

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List, Optional
import asyncio
import logging
from datetime import datetime

from .models import VM, BaremetalServer, User, Namespace
from .schemas import (
    VMCreateRequest, VMResponse, VMUpdateRequest,
    BaremetalResponse, UserCreateRequest, UserResponse,
    NamespaceCreateRequest, NamespaceResponse
)
from .database import get_db, engine
from .auth import verify_token, get_current_user
from .hetzner_client import HetznerClient
from .monitoring import MonitoringService

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Hetzner DC VM Provisioning API",
    description="API for managing VMs and baremetal servers in Hetzner DC",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security
security = HTTPBearer()

# Initialize services
hetzner_client = HetznerClient()
monitoring_service = MonitoringService()

@app.on_event("startup")
async def startup_event():
    """Initialize database and services on startup"""
    # Create database tables
    from .models import Base
    Base.metadata.create_all(bind=engine)
    
    # Initialize monitoring
    await monitoring_service.initialize()
    
    logger.info("VM Provisioning API started successfully")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    await monitoring_service.cleanup()
    logger.info("VM Provisioning API shutdown")

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.utcnow()}

# VM Management Endpoints
@app.post("/api/v1/vms", response_model=VMResponse)
async def create_vm(
    vm_request: VMCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create a new VM"""
    try:
        # Check if user has permission to create VMs in the namespace
        if not current_user.can_create_vm(vm_request.namespace):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions to create VMs in this namespace"
            )
        
        # Check resource availability
        available_resources = await hetzner_client.get_available_resources()
        if not available_resources.can_allocate(vm_request.cpu, vm_request.memory, vm_request.storage):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Insufficient resources available"
            )
        
        # Create VM
        vm = await hetzner_client.create_vm(
            name=vm_request.name,
            image=vm_request.image,
            server_type=vm_request.server_type,
            cpu=vm_request.cpu,
            memory=vm_request.memory,
            storage=vm_request.storage,
            mount_points=vm_request.mount_points,
            namespace=vm_request.namespace,
            user_id=current_user.id
        )
        
        # Save to database
        db_vm = VM(
            name=vm.name,
            image=vm.image,
            server_type=vm.server_type,
            cpu=vm.cpu,
            memory=vm.memory,
            storage=vm.storage,
            ip_address=vm.ip_address,
            status=vm.status,
            namespace=vm.namespace,
            user_id=current_user.id,
            created_at=datetime.utcnow()
        )
        db.add(db_vm)
        db.commit()
        db.refresh(db_vm)
        
        # Start monitoring
        await monitoring_service.start_vm_monitoring(db_vm.id)
        
        logger.info(f"VM {vm_request.name} created successfully")
        return VMResponse.from_orm(db_vm)
        
    except Exception as e:
        logger.error(f"Failed to create VM {vm_request.name}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create VM: {str(e)}"
        )

@app.get("/api/v1/vms", response_model=List[VMResponse])
async def list_vms(
    namespace: Optional[str] = None,
    user_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List VMs with optional filtering"""
    query = db.query(VM)
    
    # Apply filters based on user permissions
    if current_user.role == "user":
        query = query.filter(VM.user_id == current_user.id)
    elif namespace:
        query = query.filter(VM.namespace == namespace)
    elif user_id:
        query = query.filter(VM.user_id == user_id)
    
    vms = query.all()
    return [VMResponse.from_orm(vm) for vm in vms]

@app.get("/api/v1/vms/{vm_id}", response_model=VMResponse)
async def get_vm(
    vm_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get VM details"""
    vm = db.query(VM).filter(VM.id == vm_id).first()
    if not vm:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="VM not found"
        )
    
    # Check permissions
    if current_user.role == "user" and vm.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied"
        )
    
    return VMResponse.from_orm(vm)

@app.put("/api/v1/vms/{vm_id}", response_model=VMResponse)
async def update_vm(
    vm_id: int,
    vm_update: VMUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update VM resources"""
    vm = db.query(VM).filter(VM.id == vm_id).first()
    if not vm:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="VM not found"
        )
    
    # Check permissions
    if current_user.role == "user" and vm.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied"
        )
    
    try:
        # Update VM resources
        updated_vm = await hetzner_client.update_vm(
            vm_id=vm_id,
            cpu=vm_update.cpu,
            memory=vm_update.memory,
            storage=vm_update.storage
        )
        
        # Update database
        vm.cpu = updated_vm.cpu
        vm.memory = updated_vm.memory
        vm.storage = updated_vm.storage
        vm.updated_at = datetime.utcnow()
        
        db.commit()
        db.refresh(vm)
        
        logger.info(f"VM {vm_id} updated successfully")
        return VMResponse.from_orm(vm)
        
    except Exception as e:
        logger.error(f"Failed to update VM {vm_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update VM: {str(e)}"
        )

@app.delete("/api/v1/vms/{vm_id}")
async def delete_vm(
    vm_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete VM"""
    vm = db.query(VM).filter(VM.id == vm_id).first()
    if not vm:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="VM not found"
        )
    
    # Check permissions
    if current_user.role == "user" and vm.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied"
        )
    
    try:
        # Delete VM from Hetzner
        await hetzner_client.delete_vm(vm_id)
        
        # Stop monitoring
        await monitoring_service.stop_vm_monitoring(vm_id)
        
        # Remove from database
        db.delete(vm)
        db.commit()
        
        logger.info(f"VM {vm_id} deleted successfully")
        return {"message": "VM deleted successfully"}
        
    except Exception as e:
        logger.error(f"Failed to delete VM {vm_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete VM: {str(e)}"
        )

# Baremetal Management Endpoints
@app.get("/api/v1/baremetals", response_model=List[BaremetalResponse])
async def list_baremetals(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List all baremetal servers"""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    
    baremetals = db.query(BaremetalServer).all()
    return [BaremetalResponse.from_orm(bm) for bm in baremetals]

@app.post("/api/v1/baremetals/{server_id}/add-to-cluster")
async def add_baremetal_to_cluster(
    server_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Add baremetal server to Kubernetes cluster"""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    
    try:
        await hetzner_client.add_server_to_cluster(server_id)
        
        # Update database
        baremetal = db.query(BaremetalServer).filter(BaremetalServer.id == server_id).first()
        if baremetal:
            baremetal.cluster_status = "active"
            baremetal.updated_at = datetime.utcnow()
            db.commit()
        
        logger.info(f"Baremetal server {server_id} added to cluster")
        return {"message": "Server added to cluster successfully"}
        
    except Exception as e:
        logger.error(f"Failed to add baremetal {server_id} to cluster: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to add server to cluster: {str(e)}"
        )

@app.post("/api/v1/baremetals/{server_id}/remove-from-cluster")
async def remove_baremetal_from_cluster(
    server_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Remove baremetal server from Kubernetes cluster"""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    
    try:
        await hetzner_client.remove_server_from_cluster(server_id)
        
        # Update database
        baremetal = db.query(BaremetalServer).filter(BaremetalServer.id == server_id).first()
        if baremetal:
            baremetal.cluster_status = "inactive"
            baremetal.updated_at = datetime.utcnow()
            db.commit()
        
        logger.info(f"Baremetal server {server_id} removed from cluster")
        return {"message": "Server removed from cluster successfully"}
        
    except Exception as e:
        logger.error(f"Failed to remove baremetal {server_id} from cluster: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to remove server from cluster: {str(e)}"
        )

# User Management Endpoints
@app.post("/api/v1/users", response_model=UserResponse)
async def create_user(
    user_request: UserCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create a new user"""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    
    # Check if user already exists
    existing_user = db.query(User).filter(User.email == user_request.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User with this email already exists"
        )
    
    # Create user
    user = User(
        username=user_request.username,
        email=user_request.email,
        role=user_request.role,
        created_at=datetime.utcnow()
    )
    user.set_password(user_request.password)
    
    db.add(user)
    db.commit()
    db.refresh(user)
    
    logger.info(f"User {user_request.username} created successfully")
    return UserResponse.from_orm(user)

@app.get("/api/v1/users", response_model=List[UserResponse])
async def list_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List all users"""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    
    users = db.query(User).all()
    return [UserResponse.from_orm(user) for user in users]

# Namespace Management Endpoints
@app.post("/api/v1/namespaces", response_model=NamespaceResponse)
async def create_namespace(
    namespace_request: NamespaceCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create a new namespace"""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    
    # Create namespace
    namespace = Namespace(
        name=namespace_request.name,
        cpu_limit=namespace_request.cpu_limit,
        memory_limit=namespace_request.memory_limit,
        storage_limit=namespace_request.storage_limit,
        user_id=namespace_request.user_id,
        created_at=datetime.utcnow()
    )
    
    db.add(namespace)
    db.commit()
    db.refresh(namespace)
    
    logger.info(f"Namespace {namespace_request.name} created successfully")
    return NamespaceResponse.from_orm(namespace)

@app.get("/api/v1/namespaces", response_model=List[NamespaceResponse])
async def list_namespaces(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List namespaces"""
    if current_user.role == "admin":
        namespaces = db.query(Namespace).all()
    else:
        namespaces = db.query(Namespace).filter(Namespace.user_id == current_user.id).all()
    
    return [NamespaceResponse.from_orm(ns) for ns in namespaces]

# Monitoring Endpoints
@app.get("/api/v1/monitoring/dashboard")
async def get_monitoring_dashboard(
    current_user: User = Depends(get_current_user)
):
    """Get monitoring dashboard data"""
    try:
        dashboard_data = await monitoring_service.get_dashboard_data()
        return dashboard_data
    except Exception as e:
        logger.error(f"Failed to get monitoring data: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get monitoring data: {str(e)}"
        )

@app.get("/api/v1/monitoring/vms/{vm_id}")
async def get_vm_monitoring(
    vm_id: int,
    current_user: User = Depends(get_current_user)
):
    """Get VM monitoring data"""
    try:
        vm_data = await monitoring_service.get_vm_monitoring_data(vm_id)
        return vm_data
    except Exception as e:
        logger.error(f"Failed to get VM monitoring data: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get VM monitoring data: {str(e)}"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)