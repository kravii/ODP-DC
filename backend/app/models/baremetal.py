from sqlalchemy import Column, String, Integer, DateTime, func, CheckConstraint
from sqlalchemy.dialects.postgresql import UUID, INET
import uuid
from app.core.database import Base

class Baremetal(Base):
    __tablename__ = "baremetals"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    hostname = Column(String(100), unique=True, nullable=False)
    ip_address = Column(INET, nullable=False)
    cpu_cores = Column(Integer, nullable=False)
    memory_gb = Column(Integer, nullable=False)
    storage_gb = Column(Integer, nullable=False)
    iops = Column(Integer, default=0)
    status = Column(String(20), default='active')
    last_health_check = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        CheckConstraint("status IN ('active', 'inactive', 'maintenance', 'failed')", name='check_status'),
    )