from sqlalchemy import Column, String, Integer, DateTime, func, Enum, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.core.utils import generate_uuid

class VMImage(Base):
    __tablename__ = "vm_images"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    name = Column(String(100), nullable=False)
    os_type = Column(String(50), nullable=False)
    version = Column(String(50), nullable=False)
    image_url = Column(String, nullable=False)
    min_cpu = Column(Integer, default=1)
    min_memory = Column(Integer, default=1024)
    min_storage = Column(Integer, default=20)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())

class VM(Base):
    __tablename__ = "vms"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    hostname = Column(String(100), unique=True, nullable=False)
    ip_address = Column(String(45))
    baremetal_id = Column(String(36), ForeignKey("baremetals.id"))
    image_id = Column(String(36), ForeignKey("vm_images.id"))
    cpu_cores = Column(Integer, nullable=False)
    memory_mb = Column(Integer, nullable=False)
    status = Column(Enum('creating', 'running', 'stopped', 'failed', 'deleting'), default='creating')
    created_by = Column(String(36), ForeignKey("users.id"))
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    # Relationships
    baremetal = relationship("Baremetal", back_populates="vms")
    image = relationship("VMImage")
    creator = relationship("User")
    storage_mounts = relationship("VMStorageMount", back_populates="vm", cascade="all, delete-orphan")

class VMStorageMount(Base):
    __tablename__ = "vm_storage_mounts"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    vm_id = Column(String(36), ForeignKey("vms.id", ondelete="CASCADE"))
    mount_point = Column(String(255), nullable=False)
    storage_gb = Column(Integer, nullable=False)
    storage_type = Column(Enum('standard', 'ssd', 'nvme'), default='standard')
    created_at = Column(DateTime, server_default=func.now())

    # Relationships
    vm = relationship("VM", back_populates="storage_mounts")