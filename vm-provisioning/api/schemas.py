"""
Pydantic schemas for VM Provisioning API
"""

from pydantic import BaseModel, EmailStr, validator
from typing import List, Optional, Dict, Any
from datetime import datetime
from enum import Enum

class UserRole(str, Enum):
    ADMIN = "admin"
    USER = "user"

class VMStatus(str, Enum):
    CREATING = "creating"
    RUNNING = "running"
    STOPPED = "stopped"
    ERROR = "error"

class ServerStatus(str, Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    MAINTENANCE = "maintenance"

class ClusterStatus(str, Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"

class AlertSeverity(str, Enum):
    CRITICAL = "critical"
    WARNING = "warning"
    INFO = "info"

class AlertStatus(str, Enum):
    FIRING = "firing"
    RESOLVED = "resolved"

# VM Schemas
class MountPoint(BaseModel):
    mount_path: str
    size_gb: int
    storage_type: str = "ssd"

class VMCreateRequest(BaseModel):
    name: str
    image: str  # centos7, rhel7, rhel8, rhel9, rockylinux9, ubuntu20, ubuntu22, ubuntu24, oel8
    server_type: str  # cx11, cx21, cx31, cx41, cx51
    cpu: int
    memory: int  # in GB
    storage: int  # in GB
    mount_points: List[MountPoint] = []
    namespace: str
    
    @validator('cpu')
    def validate_cpu(cls, v):
        if v < 1 or v > 32:
            raise ValueError('CPU must be between 1 and 32 cores')
        return v
    
    @validator('memory')
    def validate_memory(cls, v):
        if v < 1 or v > 128:
            raise ValueError('Memory must be between 1 and 128 GB')
        return v
    
    @validator('storage')
    def validate_storage(cls, v):
        if v < 10 or v > 1000:
            raise ValueError('Storage must be between 10 and 1000 GB')
        return v

class VMUpdateRequest(BaseModel):
    cpu: Optional[int] = None
    memory: Optional[int] = None
    storage: Optional[int] = None
    
    @validator('cpu')
    def validate_cpu(cls, v):
        if v is not None and (v < 1 or v > 32):
            raise ValueError('CPU must be between 1 and 32 cores')
        return v
    
    @validator('memory')
    def validate_memory(cls, v):
        if v is not None and (v < 1 or v > 128):
            raise ValueError('Memory must be between 1 and 128 GB')
        return v
    
    @validator('storage')
    def validate_storage(cls, v):
        if v is not None and (v < 10 or v > 1000):
            raise ValueError('Storage must be between 10 and 1000 GB')
        return v

class VMResponse(BaseModel):
    id: int
    name: str
    image: str
    server_type: str
    cpu: int
    memory: int
    storage: int
    ip_address: Optional[str]
    status: VMStatus
    namespace: str
    user_id: int
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

# Baremetal Schemas
class BaremetalResponse(BaseModel):
    id: int
    name: str
    hostname: str
    ip_address: str
    server_type: str
    cpu_cores: int
    memory_gb: int
    storage_gb: int
    status: ServerStatus
    cluster_status: ClusterStatus
    cpu_usage: float
    memory_usage: float
    storage_usage: float
    last_heartbeat: Optional[datetime]
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

# User Schemas
class UserCreateRequest(BaseModel):
    username: str
    email: EmailStr
    password: str
    role: UserRole = UserRole.USER
    
    @validator('username')
    def validate_username(cls, v):
        if len(v) < 3 or len(v) > 50:
            raise ValueError('Username must be between 3 and 50 characters')
        return v
    
    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        return v

class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    role: UserRole
    is_active: bool
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class UserLoginRequest(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    expires_in: int

# Namespace Schemas
class NamespaceCreateRequest(BaseModel):
    name: str
    cpu_limit: int
    memory_limit: int
    storage_limit: int
    user_id: int
    
    @validator('cpu_limit')
    def validate_cpu_limit(cls, v):
        if v < 1 or v > 200:
            raise ValueError('CPU limit must be between 1 and 200 cores')
        return v
    
    @validator('memory_limit')
    def validate_memory_limit(cls, v):
        if v < 1 or v > 1000:
            raise ValueError('Memory limit must be between 1 and 1000 GB')
        return v
    
    @validator('storage_limit')
    def validate_storage_limit(cls, v):
        if v < 10 or v > 10000:
            raise ValueError('Storage limit must be between 10 and 10000 GB')
        return v

class NamespaceUpdateRequest(BaseModel):
    cpu_limit: Optional[int] = None
    memory_limit: Optional[int] = None
    storage_limit: Optional[int] = None
    
    @validator('cpu_limit')
    def validate_cpu_limit(cls, v):
        if v is not None and (v < 1 or v > 200):
            raise ValueError('CPU limit must be between 1 and 200 cores')
        return v
    
    @validator('memory_limit')
    def validate_memory_limit(cls, v):
        if v is not None and (v < 1 or v > 1000):
            raise ValueError('Memory limit must be between 1 and 1000 GB')
        return v
    
    @validator('storage_limit')
    def validate_storage_limit(cls, v):
        if v is not None and (v < 10 or v > 10000):
            raise ValueError('Storage limit must be between 10 and 10000 GB')
        return v

class NamespaceResponse(BaseModel):
    id: int
    name: str
    cpu_limit: int
    memory_limit: int
    storage_limit: int
    cpu_used: int
    memory_used: int
    storage_used: int
    user_id: int
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

# Monitoring Schemas
class MonitoringData(BaseModel):
    resource_type: str
    resource_id: int
    metric_name: str
    metric_value: float
    timestamp: datetime

class DashboardData(BaseModel):
    total_vms: int
    running_vms: int
    total_baremetals: int
    active_baremetals: int
    total_cpu_cores: int
    used_cpu_cores: int
    total_memory_gb: int
    used_memory_gb: int
    total_storage_gb: int
    used_storage_gb: int
    recent_alerts: List[Dict[str, Any]]

class VMMonitoringData(BaseModel):
    vm_id: int
    vm_name: str
    cpu_usage: float
    memory_usage: float
    storage_usage: float
    network_in: float
    network_out: float
    disk_read: float
    disk_write: float
    uptime: int
    last_updated: datetime

class BaremetalMonitoringData(BaseModel):
    server_id: int
    server_name: str
    cpu_usage: float
    memory_usage: float
    storage_usage: float
    temperature: Optional[float]
    network_in: float
    network_out: float
    disk_read: float
    disk_write: float
    uptime: int
    last_updated: datetime

# Alert Schemas
class AlertResponse(BaseModel):
    id: int
    alert_name: str
    severity: AlertSeverity
    status: AlertStatus
    resource_type: str
    resource_id: Optional[int]
    description: Optional[str]
    summary: Optional[str]
    labels: Optional[str]
    annotations: Optional[str]
    starts_at: datetime
    ends_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class AlertCreateRequest(BaseModel):
    alert_name: str
    severity: AlertSeverity
    resource_type: str
    resource_id: Optional[int]
    description: Optional[str]
    summary: Optional[str]
    labels: Optional[Dict[str, Any]]
    annotations: Optional[Dict[str, Any]]

# Resource Schemas
class ResourceUsage(BaseModel):
    cpu_cores: int
    memory_gb: int
    storage_gb: int
    
    def can_allocate(self, cpu: int, memory: int, storage: int) -> bool:
        """Check if resources can be allocated"""
        return (
            self.cpu_cores >= cpu and
            self.memory_gb >= memory and
            self.storage_gb >= storage
        )

class AvailableResources(BaseModel):
    total_cpu_cores: int
    available_cpu_cores: int
    total_memory_gb: int
    available_memory_gb: int
    total_storage_gb: int
    available_storage_gb: int
    
    def can_allocate(self, cpu: int, memory: int, storage: int) -> bool:
        """Check if resources can be allocated"""
        return (
            self.available_cpu_cores >= cpu and
            self.available_memory_gb >= memory and
            self.available_storage_gb >= storage
        )

# Health Check Schema
class HealthCheck(BaseModel):
    status: str
    timestamp: datetime
    services: Dict[str, str]
    version: str
    uptime: int