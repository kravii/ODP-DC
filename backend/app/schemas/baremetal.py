from pydantic import BaseModel, IPvAnyAddress
from typing import Optional

class BaremetalCreate(BaseModel):
    hostname: str
    ip_address: IPvAnyAddress
    cpu_cores: int
    memory_gb: int
    storage_gb: int
    iops: int = 0

class BaremetalUpdate(BaseModel):
    hostname: Optional[str] = None
    ip_address: Optional[IPvAnyAddress] = None
    cpu_cores: Optional[int] = None
    memory_gb: Optional[int] = None
    storage_gb: Optional[int] = None
    iops: Optional[int] = None
    status: Optional[str] = None

class BaremetalResponse(BaseModel):
    id: str
    hostname: str
    ip_address: str
    cpu_cores: int
    memory_gb: int
    storage_gb: int
    iops: int
    status: str
    last_health_check: Optional[str] = None
    created_at: str
    updated_at: str

    class Config:
        from_attributes = True