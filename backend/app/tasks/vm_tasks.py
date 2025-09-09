from celery import current_task
from sqlalchemy.orm import sessionmaker
from app.core.database import engine
from app.core.celery_app import celery_app
from app.models.vm import VM, VMImage
from app.models.baremetal import Baremetal
from app.tasks.notification_tasks import send_alert_notification
import logging
import subprocess
import os

logger = logging.getLogger(__name__)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@celery_app.task
def create_vm_task(vm_id: str):
    """Create a VM on the assigned baremetal server"""
    db = SessionLocal()
    try:
        vm = db.query(VM).filter(VM.id == vm_id).first()
        if not vm:
            logger.error(f"VM {vm_id} not found")
            return
        
        baremetal = db.query(Baremetal).filter(Baremetal.id == vm.baremetal_id).first()
        if not baremetal:
            logger.error(f"Baremetal for VM {vm_id} not found")
            vm.status = 'failed'
            db.commit()
            return
        
        image = db.query(VMImage).filter(VMImage.id == vm.image_id).first()
        if not image:
            logger.error(f"Image for VM {vm_id} not found")
            vm.status = 'failed'
            db.commit()
            return
        
        # Update VM status to creating
        vm.status = 'creating'
        db.commit()
        
        # In a real implementation, you would:
        # 1. Download the image if not already present
        # 2. Create a VM configuration
        # 3. Start the VM using libvirt or similar
        # 4. Configure networking
        # 5. Set up SSH keys
        
        try:
            # Simulate VM creation process
            logger.info(f"Creating VM {vm.hostname} on {baremetal.hostname}")
            
            # For now, just mark as running after a delay
            # In real implementation, this would be the actual VM creation
            vm.status = 'running'
            db.commit()
            
            logger.info(f"VM {vm.hostname} created successfully")
            
        except Exception as e:
            logger.error(f"Error creating VM {vm.hostname}: {str(e)}")
            vm.status = 'failed'
            db.commit()
            
            # Create alert
            from app.models.monitoring import Alert
            alert = Alert(
                resource_type='vm',
                resource_id=str(vm.id),
                alert_type='vm_creation_failed',
                severity='high',
                message=f"Failed to create VM {vm.hostname}: {str(e)}"
            )
            db.add(alert)
            db.commit()
            
            # Send notification
            send_alert_notification.delay(str(alert.id))
            
    except Exception as e:
        logger.error(f"Error in VM creation task: {str(e)}")
    finally:
        db.close()

@celery_app.task
def delete_vm_task(vm_id: str):
    """Delete a VM from the assigned baremetal server"""
    db = SessionLocal()
    try:
        vm = db.query(VM).filter(VM.id == vm_id).first()
        if not vm:
            logger.error(f"VM {vm_id} not found")
            return
        
        baremetal = db.query(Baremetal).filter(Baremetal.id == vm.baremetal_id).first()
        if not baremetal:
            logger.error(f"Baremetal for VM {vm_id} not found")
            return
        
        # Update VM status to deleting
        vm.status = 'deleting'
        db.commit()
        
        try:
            # In a real implementation, you would:
            # 1. Stop the VM
            # 2. Delete the VM configuration
            # 3. Clean up storage
            # 4. Remove from monitoring
            
            logger.info(f"Deleting VM {vm.hostname} from {baremetal.hostname}")
            
            # For now, just delete the database record
            # In real implementation, this would be the actual VM deletion
            db.delete(vm)
            db.commit()
            
            logger.info(f"VM {vm.hostname} deleted successfully")
            
        except Exception as e:
            logger.error(f"Error deleting VM {vm.hostname}: {str(e)}")
            vm.status = 'failed'
            db.commit()
            
            # Create alert
            from app.models.monitoring import Alert
            alert = Alert(
                resource_type='vm',
                resource_id=str(vm.id),
                alert_type='vm_deletion_failed',
                severity='high',
                message=f"Failed to delete VM {vm.hostname}: {str(e)}"
            )
            db.add(alert)
            db.commit()
            
            # Send notification
            send_alert_notification.delay(str(alert.id))
            
    except Exception as e:
        logger.error(f"Error in VM deletion task: {str(e)}")
    finally:
        db.close()

@celery_app.task
def check_vm_health():
    """Check health of all VMs"""
    db = SessionLocal()
    try:
        vms = db.query(VM).filter(VM.status == 'running').all()
        
        for vm in vms:
            try:
                # In a real implementation, you would check VM health
                # by connecting to the VM or checking its status
                is_healthy = check_vm_health_status(vm)
                
                if not is_healthy:
                    # Update status to failed
                    vm.status = 'failed'
                    db.commit()
                    
                    # Create alert
                    from app.models.monitoring import Alert
                    alert = Alert(
                        resource_type='vm',
                        resource_id=str(vm.id),
                        alert_type='vm_down',
                        severity='high',
                        message=f"VM {vm.hostname} is not responding"
                    )
                    db.add(alert)
                    db.commit()
                    
                    # Send notification
                    send_alert_notification.delay(str(alert.id))
                    
                    logger.warning(f"VM {vm.hostname} is not healthy")
                    
            except Exception as e:
                logger.error(f"Error checking health for VM {vm.hostname}: {str(e)}")
                
    except Exception as e:
        logger.error(f"Error in VM health check: {str(e)}")
    finally:
        db.close()

def check_vm_health_status(vm: VM) -> bool:
    """Check if a VM is healthy (simplified implementation)"""
    # In a real implementation, you would:
    # 1. Check if the VM process is running
    # 2. Ping the VM's IP address
    # 3. Check resource utilization
    # 4. Verify services are running
    
    # For now, just return True (simplified)
    return True