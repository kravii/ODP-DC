from sqlalchemy import Column, String, Integer, DateTime, func, CheckConstraint, ForeignKey
from sqlalchemy.dialects.postgresql import UUID, INET
from sqlalchemy.orm import relationship
import uuid
from app.core.database import Base

class VMImage(Base):
    __tablename__ = "vm_images"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False)
    os_type = Column(String(50), nullable=False)
    version = Column(String(50), nullable=False)
    image_url = Column(String, nullable=False)
    min_cpu = Column(Integer, default=1)
    min_memory = Column(Integer, default=1024)
    min_storage = Column(Integer, default=20)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class VM(Base):
    __tablename__ = "vms"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    hostname = Column(String(100), unique=True, nullable=False)
    ip_address = Column(INET)
    baremetal_id = Column(UUID(as_uuid=True), ForeignKey("baremetals.id"))
    image_id = Column(UUID(as_uuid=True), ForeignKey("vm_images.id"))
    cpu_cores = Column(Integer, nullable=False)
    memory_mb = Column(Integer, nullable=False)
    status = Column(String(20), default='creating')
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    baremetal = relationship("Baremetal", back_populates="vms")
    image = relationship("VMImage")
    creator = relationship("User")

    __table_args__ = (
        CheckConstraint("status IN ('creating', 'running', 'stopped', 'failed', 'deleting')", name='check_vm_status'),
    )

class VMStorageMount(Base):
    __tablename__ = "vm_storage_mounts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    vm_id = Column(UUID(as_uuid=True), ForeignKey("vms.id", ondelete="CASCADE"))
    mount_point = Column(String(255), nullable=False)
    storage_gb = Column(Integer, nullable=False)
    storage_type = Column(String(20), default='standard')
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        CheckConstraint("storage_type IN ('standard', 'ssd', 'nvme')", name='check_storage_type'),
    )