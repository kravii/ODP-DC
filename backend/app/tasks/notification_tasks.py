from celery import current_task
from sqlalchemy.orm import sessionmaker
from app.core.database import engine
from app.core.celery_app import celery_app
from app.models.monitoring import Alert, Notification
from app.core.config import settings
import logging
import httpx
import json

logger = logging.getLogger(__name__)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@celery_app.task
def send_alert_notification(alert_id: str):
    """Send alert notification via configured channels"""
    db = SessionLocal()
    try:
        alert = db.query(Alert).filter(Alert.id == alert_id).first()
        if not alert:
            logger.error(f"Alert {alert_id} not found")
            return
        
        # Send Slack notification if configured
        if settings.SLACK_WEBHOOK_URL:
            send_slack_notification.delay(alert_id)
        
        # Send JIRA notification if configured
        if settings.JIRA_URL and settings.JIRA_USERNAME and settings.JIRA_API_TOKEN:
            send_jira_notification.delay(alert_id)
            
    except Exception as e:
        logger.error(f"Error sending alert notification: {str(e)}")
    finally:
        db.close()

@celery_app.task
def send_slack_notification(alert_id: str):
    """Send notification to Slack"""
    db = SessionLocal()
    try:
        alert = db.query(Alert).filter(Alert.id == alert_id).first()
        if not alert:
            logger.error(f"Alert {alert_id} not found")
            return
        
        # Create notification record
        notification = Notification(
            alert_id=alert.id,
            channel='slack',
            status='pending'
        )
        db.add(notification)
        db.commit()
        
        # Prepare Slack message
        color = {
            'low': '#good',
            'medium': '#warning',
            'high': '#danger',
            'critical': '#danger'
        }.get(alert.severity, '#good')
        
        message = {
            "attachments": [
                {
                    "color": color,
                    "title": f"Data Center Alert: {alert.alert_type}",
                    "text": alert.message,
                    "fields": [
                        {
                            "title": "Resource Type",
                            "value": alert.resource_type,
                            "short": True
                        },
                        {
                            "title": "Severity",
                            "value": alert.severity.upper(),
                            "short": True
                        },
                        {
                            "title": "Resource ID",
                            "value": str(alert.resource_id),
                            "short": True
                        },
                        {
                            "title": "Timestamp",
                            "value": alert.created_at.isoformat(),
                            "short": True
                        }
                    ]
                }
            ]
        }
        
        # Send to Slack
        async with httpx.AsyncClient() as client:
            response = await client.post(
                settings.SLACK_WEBHOOK_URL,
                json=message,
                timeout=10.0
            )
            
            if response.status_code == 200:
                notification.status = 'sent'
                notification.sent_at = db.query(func.now()).scalar()
                logger.info(f"Slack notification sent for alert {alert_id}")
            else:
                notification.status = 'failed'
                notification.error_message = f"HTTP {response.status_code}: {response.text}"
                logger.error(f"Failed to send Slack notification: {response.text}")
            
            db.commit()
            
    except Exception as e:
        logger.error(f"Error sending Slack notification: {str(e)}")
        notification.status = 'failed'
        notification.error_message = str(e)
        db.commit()
    finally:
        db.close()

@celery_app.task
def send_jira_notification(alert_id: str):
    """Send notification to JIRA"""
    db = SessionLocal()
    try:
        alert = db.query(Alert).filter(Alert.id == alert_id).first()
        if not alert:
            logger.error(f"Alert {alert_id} not found")
            return
        
        # Create notification record
        notification = Notification(
            alert_id=alert.id,
            channel='jira',
            status='pending'
        )
        db.add(notification)
        db.commit()
        
        # Prepare JIRA issue
        issue_data = {
            "fields": {
                "project": {"key": "DC"},  # You may need to adjust this
                "summary": f"Data Center Alert: {alert.alert_type}",
                "description": f"""
**Alert Details:**
- Message: {alert.message}
- Resource Type: {alert.resource_type}
- Resource ID: {alert.resource_id}
- Severity: {alert.severity.upper()}
- Timestamp: {alert.created_at.isoformat()}
                """,
                "issuetype": {"name": "Bug"},
                "priority": {"name": "High" if alert.severity in ['high', 'critical'] else "Medium"}
            }
        }
        
        # Send to JIRA
        auth = (settings.JIRA_USERNAME, settings.JIRA_API_TOKEN)
        headers = {"Content-Type": "application/json"}
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{settings.JIRA_URL}/rest/api/2/issue",
                json=issue_data,
                auth=auth,
                headers=headers,
                timeout=30.0
            )
            
            if response.status_code == 201:
                notification.status = 'sent'
                notification.sent_at = db.query(func.now()).scalar()
                logger.info(f"JIRA notification sent for alert {alert_id}")
            else:
                notification.status = 'failed'
                notification.error_message = f"HTTP {response.status_code}: {response.text}"
                logger.error(f"Failed to send JIRA notification: {response.text}")
            
            db.commit()
            
    except Exception as e:
        logger.error(f"Error sending JIRA notification: {str(e)}")
        notification.status = 'failed'
        notification.error_message = str(e)
        db.commit()
    finally:
        db.close()

@celery_app.task
def collect_metrics():
    """Collect metrics from all resources"""
    db = SessionLocal()
    try:
        from app.models.baremetal import Baremetal
        from app.models.vm import VM
        from app.models.monitoring import MonitoringMetric
        from datetime import datetime
        
        # Collect baremetal metrics
        baremetals = db.query(Baremetal).filter(Baremetal.status == 'active').all()
        for baremetal in baremetals:
            # In a real implementation, you would collect actual metrics
            # For now, we'll simulate some metrics
            import random
            
            # CPU usage
            cpu_usage = random.uniform(10, 80)
            metric = MonitoringMetric(
                resource_type='baremetal',
                resource_id=str(baremetal.id),
                metric_name='cpu_usage',
                metric_value=cpu_usage
            )
            db.add(metric)
            
            # Memory usage
            memory_usage = random.uniform(20, 70)
            metric = MonitoringMetric(
                resource_type='baremetal',
                resource_id=str(baremetal.id),
                metric_name='memory_usage',
                metric_value=memory_usage
            )
            db.add(metric)
            
            # Storage usage
            storage_usage = random.uniform(30, 60)
            metric = MonitoringMetric(
                resource_type='baremetal',
                resource_id=str(baremetal.id),
                metric_name='storage_usage',
                metric_value=storage_usage
            )
            db.add(metric)
        
        # Collect VM metrics
        vms = db.query(VM).filter(VM.status == 'running').all()
        for vm in vms:
            # In a real implementation, you would collect actual metrics
            import random
            
            # CPU usage
            cpu_usage = random.uniform(5, 50)
            metric = MonitoringMetric(
                resource_type='vm',
                resource_id=str(vm.id),
                metric_name='cpu_usage',
                metric_value=cpu_usage
            )
            db.add(metric)
            
            # Memory usage
            memory_usage = random.uniform(10, 60)
            metric = MonitoringMetric(
                resource_type='vm',
                resource_id=str(vm.id),
                metric_name='memory_usage',
                metric_value=memory_usage
            )
            db.add(metric)
        
        db.commit()
        logger.info("Metrics collected successfully")
        
    except Exception as e:
        logger.error(f"Error collecting metrics: {str(e)}")
        db.rollback()
    finally:
        db.close()