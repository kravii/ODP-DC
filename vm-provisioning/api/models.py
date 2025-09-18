"""
Database models for VM Provisioning API
"""

from sqlalchemy import Column, Integer, String, DateTime, Boolean, Float, Text, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime
import bcrypt

Base = declarative_base()

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(20), nullable=False, default="user")  # admin, user
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
    
    # Relationships
    vms = relationship("VM", back_populates="user")
    namespaces = relationship("Namespace", back_populates="user")
    
    def set_password(self, password: str):
        """Hash and set password"""
        salt = bcrypt.gensalt()
        self.password_hash = bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')
    
    def check_password(self, password: str) -> bool:
        """Check password"""
        return bcrypt.checkpw(password.encode('utf-8'), self.password_hash.encode('utf-8'))
    
    def can_create_vm(self, namespace: str) -> bool:
        """Check if user can create VMs in namespace"""
        if self.role == "admin":
            return True
        # Check if user owns the namespace
        return any(ns.name == namespace for ns in self.namespaces)

class Namespace(Base):
    __tablename__ = "namespaces"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, index=True, nullable=False)
    cpu_limit = Column(Integer, nullable=False)  # CPU cores limit
    memory_limit = Column(Integer, nullable=False)  # Memory in GB limit
    storage_limit = Column(Integer, nullable=False)  # Storage in GB limit
    cpu_used = Column(Integer, default=0)  # CPU cores currently used
    memory_used = Column(Integer, default=0)  # Memory in GB currently used
    storage_used = Column(Integer, default=0)  # Storage in GB currently used
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="namespaces")
    vms = relationship("VM", back_populates="namespace_obj")
    
    def can_allocate_resources(self, cpu: int, memory: int, storage: int) -> bool:
        """Check if namespace can allocate resources"""
        return (
            self.cpu_used + cpu <= self.cpu_limit and
            self.memory_used + memory <= self.memory_limit and
            self.storage_used + storage <= self.storage_limit
        )
    
    def allocate_resources(self, cpu: int, memory: int, storage: int):
        """Allocate resources"""
        self.cpu_used += cpu
        self.memory_used += memory
        self.storage_used += storage
    
    def deallocate_resources(self, cpu: int, memory: int, storage: int):
        """Deallocate resources"""
        self.cpu_used = max(0, self.cpu_used - cpu)
        self.memory_used = max(0, self.memory_used - memory)
        self.storage_used = max(0, self.storage_used - storage)

class VM(Base):
    __tablename__ = "vms"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, index=True, nullable=False)
    image = Column(String(50), nullable=False)  # OS image
    server_type = Column(String(20), nullable=False)  # Hetzner server type
    cpu = Column(Integer, nullable=False)  # CPU cores
    memory = Column(Integer, nullable=False)  # Memory in GB
    storage = Column(Integer, nullable=False)  # Storage in GB
    ip_address = Column(String(45), nullable=True)  # IPv4 or IPv6
    status = Column(String(20), nullable=False, default="creating")  # creating, running, stopped, error
    namespace = Column(String(100), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    namespace_id = Column(Integer, ForeignKey("namespaces.id"), nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="vms")
    namespace_obj = relationship("Namespace", back_populates="vms")
    
    def to_dict(self):
        """Convert to dictionary"""
        return {
            "id": self.id,
            "name": self.name,
            "image": self.image,
            "server_type": self.server_type,
            "cpu": self.cpu,
            "memory": self.memory,
            "storage": self.storage,
            "ip_address": self.ip_address,
            "status": self.status,
            "namespace": self.namespace,
            "user_id": self.user_id,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None
        }

class BaremetalServer(Base):
    __tablename__ = "baremetal_servers"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, index=True, nullable=False)
    hostname = Column(String(100), nullable=False)
    ip_address = Column(String(45), nullable=False)
    server_type = Column(String(20), nullable=False)
    cpu_cores = Column(Integer, nullable=False)
    memory_gb = Column(Integer, nullable=False)
    storage_gb = Column(Integer, nullable=False)
    status = Column(String(20), nullable=False, default="active")  # active, inactive, maintenance
    cluster_status = Column(String(20), nullable=False, default="inactive")  # active, inactive
    cpu_usage = Column(Float, default=0.0)  # CPU usage percentage
    memory_usage = Column(Float, default=0.0)  # Memory usage percentage
    storage_usage = Column(Float, default=0.0)  # Storage usage percentage
    last_heartbeat = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
    
    def to_dict(self):
        """Convert to dictionary"""
        return {
            "id": self.id,
            "name": self.name,
            "hostname": self.hostname,
            "ip_address": self.ip_address,
            "server_type": self.server_type,
            "cpu_cores": self.cpu_cores,
            "memory_gb": self.memory_gb,
            "storage_gb": self.storage_gb,
            "status": self.status,
            "cluster_status": self.cluster_status,
            "cpu_usage": self.cpu_usage,
            "memory_usage": self.memory_usage,
            "storage_usage": self.storage_usage,
            "last_heartbeat": self.last_heartbeat.isoformat() if self.last_heartbeat else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None
        }

class MonitoringData(Base):
    __tablename__ = "monitoring_data"
    
    id = Column(Integer, primary_key=True, index=True)
    resource_type = Column(String(20), nullable=False)  # vm, baremetal
    resource_id = Column(Integer, nullable=False)
    metric_name = Column(String(50), nullable=False)
    metric_value = Column(Float, nullable=False)
    timestamp = Column(DateTime, default=func.now())
    
    def to_dict(self):
        """Convert to dictionary"""
        return {
            "id": self.id,
            "resource_type": self.resource_type,
            "resource_id": self.resource_id,
            "metric_name": self.metric_name,
            "metric_value": self.metric_value,
            "timestamp": self.timestamp.isoformat() if self.timestamp else None
        }

class Alert(Base):
    __tablename__ = "alerts"
    
    id = Column(Integer, primary_key=True, index=True)
    alert_name = Column(String(100), nullable=False)
    severity = Column(String(20), nullable=False)  # critical, warning, info
    status = Column(String(20), nullable=False, default="firing")  # firing, resolved
    resource_type = Column(String(20), nullable=False)  # vm, baremetal, cluster
    resource_id = Column(Integer, nullable=True)
    description = Column(Text, nullable=True)
    summary = Column(String(255), nullable=True)
    labels = Column(Text, nullable=True)  # JSON string
    annotations = Column(Text, nullable=True)  # JSON string
    starts_at = Column(DateTime, nullable=False)
    ends_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
    
    def to_dict(self):
        """Convert to dictionary"""
        return {
            "id": self.id,
            "alert_name": self.alert_name,
            "severity": self.severity,
            "status": self.status,
            "resource_type": self.resource_type,
            "resource_id": self.resource_id,
            "description": self.description,
            "summary": self.summary,
            "labels": self.labels,
            "annotations": self.annotations,
            "starts_at": self.starts_at.isoformat() if self.starts_at else None,
            "ends_at": self.ends_at.isoformat() if self.ends_at else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None
        }