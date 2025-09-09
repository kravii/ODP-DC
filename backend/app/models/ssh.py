from sqlalchemy import Column, String, Integer, DateTime, func, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.core.utils import generate_uuid

class SSHKey(Base):
    __tablename__ = "ssh_keys"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    name = Column(String(100), nullable=False)
    public_key = Column(String, nullable=False)
    private_key = Column(String)
    is_default = Column(Boolean, default=False)
    created_by = Column(String(36), ForeignKey("users.id"))
    created_at = Column(DateTime, server_default=func.now())

    # Relationships
    creator = relationship("User")
    baremetal_access = relationship("BaremetalSSHAccess", back_populates="ssh_key")

class BaremetalSSHAccess(Base):
    __tablename__ = "baremetal_ssh_access"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    baremetal_id = Column(String(36), ForeignKey("baremetals.id", ondelete="CASCADE"), nullable=False)
    ssh_key_id = Column(String(36), ForeignKey("ssh_keys.id", ondelete="CASCADE"), nullable=False)
    username = Column(String(50), nullable=False)
    port = Column(Integer, default=22)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())

    # Relationships
    baremetal = relationship("Baremetal", back_populates="ssh_access")
    ssh_key = relationship("SSHKey", back_populates="baremetal_access")