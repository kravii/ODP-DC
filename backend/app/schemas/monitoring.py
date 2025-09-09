from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime

class MonitoringMetricResponse(BaseModel):
    id: str
    resource_type: str
    resource_id: str
    metric_name: str
    metric_value: float
    timestamp: datetime

    class Config:
        from_attributes = True

class AlertResponse(BaseModel):
    id: str
    resource_type: str
    resource_id: str
    alert_type: str
    severity: str
    message: str
    is_resolved: bool
    created_at: datetime
    resolved_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class NotificationResponse(BaseModel):
    id: str
    alert_id: str
    channel: str
    status: str
    sent_at: Optional[datetime] = None
    error_message: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

class HealthStatusResponse(BaseModel):
    baremetals: Dict[str, int]
    vms: Dict[str, int]
    alerts: Dict[str, int]
    overall_status: str

class ResourceUtilizationResponse(BaseModel):
    baremetal: Dict[str, float]
    vm: Dict[str, float]