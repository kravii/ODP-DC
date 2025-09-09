from pydantic import BaseModel, IPvAnyAddress
from typing import Optional, List

class BaremetalStorageMountCreate(BaseModel):
    mount_point: str
    storage_gb: int
    storage_type: str = "standard"
    iops: int = 0

class BaremetalSSHAccessCreate(BaseModel):
    ssh_key_id: str
    username: str
    port: int = 22

class BaremetalCreate(BaseModel):
    hostname: str
    ip_address: IPvAnyAddress
    os_type: str
    cpu_cores: int
    memory_gb: int
    storage_mounts: List[BaremetalStorageMountCreate] = []
    ssh_access: Optional[BaremetalSSHAccessCreate] = None

class BaremetalUpdate(BaseModel):
    hostname: Optional[str] = None
    ip_address: Optional[IPvAnyAddress] = None
    os_type: Optional[str] = None
    cpu_cores: Optional[int] = None
    memory_gb: Optional[int] = None
    status: Optional[str] = None

class BaremetalStorageMountResponse(BaseModel):
    id: str
    mount_point: str
    storage_gb: int
    storage_type: str
    iops: int
    created_at: str

    class Config:
        from_attributes = True

class BaremetalSSHAccessResponse(BaseModel):
    id: str
    username: str
    port: int
    is_active: bool
    ssh_key_name: str
    created_at: str

    class Config:
        from_attributes = True

class BaremetalResponse(BaseModel):
    id: str
    hostname: str
    ip_address: str
    os_type: str
    cpu_cores: int
    memory_gb: int
    status: str
    last_health_check: Optional[str] = None
    created_at: str
    updated_at: str
    storage_mounts: List[BaremetalStorageMountResponse] = []
    ssh_access: Optional[BaremetalSSHAccessResponse] = None

    class Config:
        from_attributes = True