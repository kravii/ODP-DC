from pydantic import BaseModel, IPvAnyAddress
from typing import Optional, List

class VMStorageMountCreate(BaseModel):
    mount_point: str
    storage_gb: int
    storage_type: str = "standard"

class VMCreate(BaseModel):
    hostname: str
    ip_address: Optional[IPvAnyAddress] = None
    image_id: str
    cpu_cores: int
    memory_mb: int
    storage_mounts: List[VMStorageMountCreate] = []

class VMUpdate(BaseModel):
    hostname: Optional[str] = None
    ip_address: Optional[IPvAnyAddress] = None
    cpu_cores: Optional[int] = None
    memory_mb: Optional[int] = None
    status: Optional[str] = None

class VMImageResponse(BaseModel):
    id: str
    name: str
    os_type: str
    version: str
    image_url: str
    min_cpu: int
    min_memory: int
    min_storage: int
    is_active: bool
    created_at: str

    class Config:
        from_attributes = True

class VMStorageMountResponse(BaseModel):
    id: str
    mount_point: str
    storage_gb: int
    storage_type: str
    created_at: str

    class Config:
        from_attributes = True

class VMResponse(BaseModel):
    id: str
    hostname: str
    ip_address: Optional[str] = None
    baremetal_id: Optional[str] = None
    image_id: str
    cpu_cores: int
    memory_mb: int
    status: str
    created_by: str
    created_at: str
    updated_at: str
    storage_mounts: List[VMStorageMountResponse] = []

    class Config:
        from_attributes = True