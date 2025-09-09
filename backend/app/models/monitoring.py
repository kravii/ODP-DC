from sqlalchemy import Column, String, Integer, DateTime, func, CheckConstraint, ForeignKey, Boolean, Text, DECIMAL
from sqlalchemy.dialects.postgresql import UUID
import uuid
from app.core.database import Base

class ResourcePool(Base):
    __tablename__ = "resource_pool"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    total_cpu_cores = Column(Integer, default=0)
    total_memory_gb = Column(Integer, default=0)
    total_storage_gb = Column(Integer, default=0)
    total_iops = Column(Integer, default=0)
    available_cpu_cores = Column(Integer, default=0)
    available_memory_gb = Column(Integer, default=0)
    available_storage_gb = Column(Integer, default=0)
    available_iops = Column(Integer, default=0)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

class MonitoringMetric(Base):
    __tablename__ = "monitoring_metrics"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    resource_type = Column(String(20), nullable=False)
    resource_id = Column(UUID(as_uuid=True), nullable=False)
    metric_name = Column(String(50), nullable=False)
    metric_value = Column(DECIMAL(10, 4), nullable=False)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        CheckConstraint("resource_type IN ('baremetal', 'vm')", name='check_resource_type'),
    )

class Alert(Base):
    __tablename__ = "alerts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    resource_type = Column(String(20), nullable=False)
    resource_id = Column(UUID(as_uuid=True), nullable=False)
    alert_type = Column(String(50), nullable=False)
    severity = Column(String(20), nullable=False)
    message = Column(Text, nullable=False)
    is_resolved = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    resolved_at = Column(DateTime(timezone=True))

    __table_args__ = (
        CheckConstraint("resource_type IN ('baremetal', 'vm')", name='check_alert_resource_type'),
        CheckConstraint("severity IN ('low', 'medium', 'high', 'critical')", name='check_alert_severity'),
    )

class Notification(Base):
    __tablename__ = "notifications"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    alert_id = Column(UUID(as_uuid=True), ForeignKey("alerts.id", ondelete="CASCADE"))
    channel = Column(String(20), nullable=False)
    status = Column(String(20), default='pending')
    sent_at = Column(DateTime(timezone=True))
    error_message = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        CheckConstraint("channel IN ('slack', 'jira', 'email')", name='check_notification_channel'),
        CheckConstraint("status IN ('pending', 'sent', 'failed')", name='check_notification_status'),
    )