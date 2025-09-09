from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timedelta

from app.core.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.monitoring import MonitoringMetric, Alert, Notification
from app.models.baremetal import Baremetal
from app.models.vm import VM
from app.schemas.monitoring import (
    MonitoringMetricResponse, 
    AlertResponse, 
    NotificationResponse,
    HealthStatusResponse,
    ResourceUtilizationResponse
)

router = APIRouter()

@router.get("/health", response_model=HealthStatusResponse)
async def get_health_status(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    # Get baremetal health
    total_baremetals = db.query(Baremetal).count()
    active_baremetals = db.query(Baremetal).filter(Baremetal.status == 'active').count()
    failed_baremetals = db.query(Baremetal).filter(Baremetal.status == 'failed').count()
    
    # Get VM health
    total_vms = db.query(VM).count()
    running_vms = db.query(VM).filter(VM.status == 'running').count()
    failed_vms = db.query(VM).filter(VM.status == 'failed').count()
    
    # Get active alerts
    active_alerts = db.query(Alert).filter(Alert.is_resolved == False).count()
    critical_alerts = db.query(Alert).filter(
        Alert.is_resolved == False,
        Alert.severity == 'critical'
    ).count()
    
    return HealthStatusResponse(
        baremetals={
            "total": total_baremetals,
            "active": active_baremetals,
            "failed": failed_baremetals
        },
        vms={
            "total": total_vms,
            "running": running_vms,
            "failed": failed_vms
        },
        alerts={
            "active": active_alerts,
            "critical": critical_alerts
        },
        overall_status="healthy" if critical_alerts == 0 else "degraded"
    )

@router.get("/metrics", response_model=List[MonitoringMetricResponse])
async def get_metrics(
    resource_type: Optional[str] = None,
    resource_id: Optional[str] = None,
    metric_name: Optional[str] = None,
    hours: int = 24,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    query = db.query(MonitoringMetric)
    
    # Filter by resource type
    if resource_type:
        query = query.filter(MonitoringMetric.resource_type == resource_type)
    
    # Filter by resource ID
    if resource_id:
        query = query.filter(MonitoringMetric.resource_id == resource_id)
    
    # Filter by metric name
    if metric_name:
        query = query.filter(MonitoringMetric.metric_name == metric_name)
    
    # Filter by time range
    since = datetime.utcnow() - timedelta(hours=hours)
    query = query.filter(MonitoringMetric.timestamp >= since)
    
    metrics = query.order_by(MonitoringMetric.timestamp.desc()).limit(1000).all()
    return metrics

@router.get("/alerts", response_model=List[AlertResponse])
async def get_alerts(
    resolved: Optional[bool] = None,
    severity: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    query = db.query(Alert)
    
    # Filter by resolved status
    if resolved is not None:
        query = query.filter(Alert.is_resolved == resolved)
    
    # Filter by severity
    if severity:
        query = query.filter(Alert.severity == severity)
    
    alerts = query.order_by(Alert.created_at.desc()).offset(skip).limit(limit).all()
    return alerts

@router.post("/alerts/{alert_id}/resolve")
async def resolve_alert(
    alert_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    alert = db.query(Alert).filter(Alert.id == alert_id).first()
    if alert is None:
        raise HTTPException(status_code=404, detail="Alert not found")
    
    alert.is_resolved = True
    alert.resolved_at = datetime.utcnow()
    db.commit()
    
    return {"message": "Alert resolved"}

@router.get("/notifications", response_model=List[NotificationResponse])
async def get_notifications(
    status: Optional[str] = None,
    channel: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    query = db.query(Notification)
    
    # Filter by status
    if status:
        query = query.filter(Notification.status == status)
    
    # Filter by channel
    if channel:
        query = query.filter(Notification.channel == channel)
    
    notifications = query.order_by(Notification.created_at.desc()).offset(skip).limit(limit).all()
    return notifications

@router.get("/utilization", response_model=ResourceUtilizationResponse)
async def get_resource_utilization(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    # Get latest metrics for all resources
    since = datetime.utcnow() - timedelta(minutes=5)
    
    # Baremetal utilization
    baremetal_metrics = db.query(MonitoringMetric).filter(
        MonitoringMetric.resource_type == 'baremetal',
        MonitoringMetric.timestamp >= since
    ).all()
    
    # VM utilization
    vm_metrics = db.query(MonitoringMetric).filter(
        MonitoringMetric.resource_type == 'vm',
        MonitoringMetric.timestamp >= since
    ).all()
    
    # Calculate average utilization
    baremetal_cpu_avg = 0
    baremetal_memory_avg = 0
    vm_cpu_avg = 0
    vm_memory_avg = 0
    
    if baremetal_metrics:
        cpu_metrics = [m for m in baremetal_metrics if m.metric_name == 'cpu_usage']
        memory_metrics = [m for m in baremetal_metrics if m.metric_name == 'memory_usage']
        
        if cpu_metrics:
            baremetal_cpu_avg = sum(float(m.metric_value) for m in cpu_metrics) / len(cpu_metrics)
        if memory_metrics:
            baremetal_memory_avg = sum(float(m.metric_value) for m in memory_metrics) / len(memory_metrics)
    
    if vm_metrics:
        cpu_metrics = [m for m in vm_metrics if m.metric_name == 'cpu_usage']
        memory_metrics = [m for m in vm_metrics if m.metric_name == 'memory_usage']
        
        if cpu_metrics:
            vm_cpu_avg = sum(float(m.metric_value) for m in cpu_metrics) / len(cpu_metrics)
        if memory_metrics:
            vm_memory_avg = sum(float(m.metric_value) for m in memory_metrics) / len(memory_metrics)
    
    return ResourceUtilizationResponse(
        baremetal={
            "cpu_usage_percent": round(baremetal_cpu_avg, 2),
            "memory_usage_percent": round(baremetal_memory_avg, 2)
        },
        vm={
            "cpu_usage_percent": round(vm_cpu_avg, 2),
            "memory_usage_percent": round(vm_memory_avg, 2)
        }
    )