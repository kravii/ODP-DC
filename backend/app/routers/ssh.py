from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.core.database import get_db
from app.core.security import get_current_active_user, require_admin
from app.models.user import User
from app.models.ssh import SSHKey
from app.schemas.ssh import SSHKeyCreate, SSHKeyResponse, SSHKeyUpdate

router = APIRouter()

@router.post("/", response_model=SSHKeyResponse)
async def create_ssh_key(
    ssh_key: SSHKeyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    # Check if name already exists
    if db.query(SSHKey).filter(SSHKey.name == ssh_key.name).first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="SSH key name already exists"
        )
    
    # If setting as default, unset other default keys
    if ssh_key.is_default:
        db.query(SSHKey).filter(SSHKey.is_default == True).update({"is_default": False})
    
    # Create SSH key
    db_ssh_key = SSHKey(
        name=ssh_key.name,
        public_key=ssh_key.public_key,
        private_key=ssh_key.private_key,
        is_default=ssh_key.is_default,
        created_by=current_user.id
    )
    db.add(db_ssh_key)
    db.commit()
    db.refresh(db_ssh_key)
    
    return db_ssh_key

@router.get("/", response_model=List[SSHKeyResponse])
async def read_ssh_keys(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    ssh_keys = db.query(SSHKey).offset(skip).limit(limit).all()
    return ssh_keys

@router.get("/{ssh_key_id}", response_model=SSHKeyResponse)
async def read_ssh_key(
    ssh_key_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    ssh_key = db.query(SSHKey).filter(SSHKey.id == ssh_key_id).first()
    if ssh_key is None:
        raise HTTPException(status_code=404, detail="SSH key not found")
    return ssh_key

@router.put("/{ssh_key_id}", response_model=SSHKeyResponse)
async def update_ssh_key(
    ssh_key_id: str,
    ssh_key_update: SSHKeyUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    ssh_key = db.query(SSHKey).filter(SSHKey.id == ssh_key_id).first()
    if ssh_key is None:
        raise HTTPException(status_code=404, detail="SSH key not found")
    
    # Update fields
    if ssh_key_update.name is not None:
        ssh_key.name = ssh_key_update.name
    if ssh_key_update.is_default is not None:
        if ssh_key_update.is_default:
            # Unset other default keys
            db.query(SSHKey).filter(SSHKey.is_default == True).update({"is_default": False})
        ssh_key.is_default = ssh_key_update.is_default
    
    db.commit()
    db.refresh(ssh_key)
    
    return ssh_key

@router.delete("/{ssh_key_id}")
async def delete_ssh_key(
    ssh_key_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    ssh_key = db.query(SSHKey).filter(SSHKey.id == ssh_key_id).first()
    if ssh_key is None:
        raise HTTPException(status_code=404, detail="SSH key not found")
    
    db.delete(ssh_key)
    db.commit()
    
    return {"message": "SSH key deleted successfully"}