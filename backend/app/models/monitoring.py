from sqlalchemy import Column, String, Integer, DateTime, func, Enum, ForeignKey, Boolean, Text, DECIMAL
from app.core.database import Base
from app.core.utils import generate_uuid

class ResourcePool(Base):
    __tablename__ = "resource_pool"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    total_cpu_cores = Column(Integer, default=0)
    total_memory_gb = Column(Integer, default=0)
    total_storage_gb = Column(Integer, default=0)
    total_iops = Column(Integer, default=0)
    available_cpu_cores = Column(Integer, default=0)
    available_memory_gb = Column(Integer, default=0)
    available_storage_gb = Column(Integer, default=0)
    available_iops = Column(Integer, default=0)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

class MonitoringMetric(Base):
    __tablename__ = "monitoring_metrics"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    resource_type = Column(Enum('baremetal', 'vm'), nullable=False)
    resource_id = Column(String(36), nullable=False)
    metric_name = Column(String(50), nullable=False)
    metric_value = Column(DECIMAL(10, 4), nullable=False)
    timestamp = Column(DateTime, server_default=func.now())

class Alert(Base):
    __tablename__ = "alerts"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    resource_type = Column(Enum('baremetal', 'vm'), nullable=False)
    resource_id = Column(String(36), nullable=False)
    alert_type = Column(String(50), nullable=False)
    severity = Column(Enum('low', 'medium', 'high', 'critical'), nullable=False)
    message = Column(Text, nullable=False)
    is_resolved = Column(Boolean, default=False)
    created_at = Column(DateTime, server_default=func.now())
    resolved_at = Column(DateTime)

class Notification(Base):
    __tablename__ = "notifications"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    alert_id = Column(String(36), ForeignKey("alerts.id", ondelete="CASCADE"))
    channel = Column(Enum('slack', 'jira', 'email'), nullable=False)
    status = Column(Enum('pending', 'sent', 'failed'), default='pending')
    sent_at = Column(DateTime)
    error_message = Column(Text)
    created_at = Column(DateTime, server_default=func.now())