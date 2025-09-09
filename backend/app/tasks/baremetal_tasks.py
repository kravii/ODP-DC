from celery import current_task
from sqlalchemy.orm import sessionmaker
from app.core.database import engine
from app.core.celery_app import celery_app
from app.models.baremetal import Baremetal
from app.models.monitoring import ResourcePool
from app.tasks.notification_tasks import send_alert_notification
import logging

logger = logging.getLogger(__name__)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@celery_app.task
def update_resource_pool():
    """Update the resource pool with current baremetal resources"""
    db = SessionLocal()
    try:
        # Get all active baremetals
        baremetals = db.query(Baremetal).filter(Baremetal.status == 'active').all()
        
        # Calculate total resources
        total_cpu = sum(bm.cpu_cores for bm in baremetals)
        total_memory = sum(bm.memory_gb for bm in baremetals)
        total_storage = sum(bm.storage_gb for bm in baremetals)
        total_iops = sum(bm.iops for bm in baremetals)
        
        # Calculate used resources (simplified - in real implementation, 
        # you'd query VM usage from the database)
        used_cpu = 0
        used_memory = 0
        used_storage = 0
        used_iops = 0
        
        # Get or create resource pool
        pool = db.query(ResourcePool).first()
        if not pool:
            pool = ResourcePool()
            db.add(pool)
        
        # Update pool
        pool.total_cpu_cores = total_cpu
        pool.total_memory_gb = total_memory
        pool.total_storage_gb = total_storage
        pool.total_iops = total_iops
        pool.available_cpu_cores = total_cpu - used_cpu
        pool.available_memory_gb = total_memory - used_memory
        pool.available_storage_gb = total_storage - used_storage
        pool.available_iops = total_iops - used_iops
        
        db.commit()
        logger.info(f"Resource pool updated: {total_cpu} CPU, {total_memory}GB RAM, {total_storage}GB storage")
        
    except Exception as e:
        logger.error(f"Error updating resource pool: {str(e)}")
        db.rollback()
    finally:
        db.close()

@celery_app.task
def check_baremetal_health():
    """Check health of all baremetal servers"""
    db = SessionLocal()
    try:
        baremetals = db.query(Baremetal).filter(Baremetal.status == 'active').all()
        
        for baremetal in baremetals:
            try:
                # In a real implementation, you would ping the server
                # and check various health metrics
                is_healthy = check_server_health(baremetal.ip_address)
                
                if not is_healthy:
                    # Update status to failed
                    baremetal.status = 'failed'
                    db.commit()
                    
                    # Create alert
                    from app.models.monitoring import Alert
                    alert = Alert(
                        resource_type='baremetal',
                        resource_id=str(baremetal.id),
                        alert_type='server_down',
                        severity='critical',
                        message=f"Baremetal server {baremetal.hostname} is not responding"
                    )
                    db.add(alert)
                    db.commit()
                    
                    # Send notification
                    send_alert_notification.delay(str(alert.id))
                    
                    logger.warning(f"Baremetal {baremetal.hostname} is not healthy")
                else:
                    # Update last health check
                    from datetime import datetime
                    baremetal.last_health_check = datetime.utcnow()
                    db.commit()
                    
            except Exception as e:
                logger.error(f"Error checking health for {baremetal.hostname}: {str(e)}")
                
    except Exception as e:
        logger.error(f"Error in baremetal health check: {str(e)}")
    finally:
        db.close()

def check_server_health(ip_address: str) -> bool:
    """Check if a server is healthy (simplified implementation)"""
    import socket
    try:
        # Try to connect to SSH port (22)
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((str(ip_address), 22))
        sock.close()
        return result == 0
    except:
        return False