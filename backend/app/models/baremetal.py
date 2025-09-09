from sqlalchemy import Column, String, Integer, DateTime, func, Enum, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.core.utils import generate_uuid

class Baremetal(Base):
    __tablename__ = "baremetals"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    hostname = Column(String(100), unique=True, nullable=False)
    ip_address = Column(String(45), nullable=False)
    os_type = Column(Enum('rhel8', 'rocky9', 'ubuntu20', 'ubuntu22'), nullable=False)
    cpu_cores = Column(Integer, nullable=False)
    memory_gb = Column(Integer, nullable=False)
    status = Column(Enum('active', 'inactive', 'maintenance', 'failed'), default='active')
    last_health_check = Column(DateTime)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    # Relationships
    storage_mounts = relationship("BaremetalStorageMount", back_populates="baremetal", cascade="all, delete-orphan")
    vms = relationship("VM", back_populates="baremetal")
    ssh_access = relationship("BaremetalSSHAccess", back_populates="baremetal", cascade="all, delete-orphan")

class BaremetalStorageMount(Base):
    __tablename__ = "baremetal_storage_mounts"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    baremetal_id = Column(String(36), ForeignKey("baremetals.id", ondelete="CASCADE"), nullable=False)
    mount_point = Column(String(255), nullable=False)
    storage_gb = Column(Integer, nullable=False)
    storage_type = Column(Enum('standard', 'ssd', 'nvme'), default='standard')
    iops = Column(Integer, default=0)
    created_at = Column(DateTime, server_default=func.now())

    # Relationships
    baremetal = relationship("Baremetal", back_populates="storage_mounts")