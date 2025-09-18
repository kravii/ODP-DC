"""
Storage Manager for VM Provisioning
Manages shared RAID storage for VMs and Kubernetes resources
"""

import os
import shutil
import subprocess
from typing import Dict, List, Optional, Tuple
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

class StorageManager:
    """Manages shared RAID storage for VMs and Kubernetes"""
    
    def __init__(self):
        self.shared_storage_root = "/shared-storage"
        self.vm_storage_path = f"{self.shared_storage_root}/vm-storage"
        self.k8s_storage_path = f"{self.shared_storage_root}/k8s-pv"
        self.monitoring_storage_path = f"{self.shared_storage_root}/monitoring"
        self.backup_storage_path = f"{self.shared_storage_root}/backups"
        self.log_storage_path = f"{self.shared_storage_root}/logs"
        
        # Storage allocation limits (in GB)
        self.storage_limits = {
            "total": 1800,  # 1.8TB total
            "vm_storage": 1000,  # 1TB for VMs
            "k8s_storage": 500,  # 500GB for Kubernetes
            "monitoring": 200,  # 200GB for monitoring
            "backups": 80,  # 80GB for backups
            "logs": 20  # 20GB for logs
        }
    
    def initialize_storage(self) -> bool:
        """Initialize shared storage directories"""
        try:
            # Create main directories
            directories = [
                self.shared_storage_root,
                self.vm_storage_path,
                self.k8s_storage_path,
                self.monitoring_storage_path,
                self.backup_storage_path,
                self.log_storage_path
            ]
            
            for directory in directories:
                Path(directory).mkdir(parents=True, exist_ok=True)
                os.chmod(directory, 0o755)
            
            # Create VM storage subdirectories
            vm_subdirs = [
                f"{self.vm_storage_path}/images",
                f"{self.vm_storage_path}/templates",
                f"{self.vm_storage_path}/instances",
                f"{self.vm_storage_path}/snapshots"
            ]
            
            for subdir in vm_subdirs:
                Path(subdir).mkdir(parents=True, exist_ok=True)
                os.chmod(subdir, 0o755)
            
            # Create Kubernetes storage subdirectories
            k8s_subdirs = [
                f"{self.k8s_storage_path}/databases",
                f"{self.k8s_storage_path}/applications",
                f"{self.k8s_storage_path}/logs"
            ]
            
            for subdir in k8s_subdirs:
                Path(subdir).mkdir(parents=True, exist_ok=True)
                os.chmod(subdir, 0o755)
            
            # Create monitoring subdirectories
            monitoring_subdirs = [
                f"{self.monitoring_storage_path}/prometheus",
                f"{self.monitoring_storage_path}/grafana",
                f"{self.monitoring_storage_path}/alertmanager"
            ]
            
            for subdir in monitoring_subdirs:
                Path(subdir).mkdir(parents=True, exist_ok=True)
                os.chmod(subdir, 0o755)
            
            logger.info("Shared storage initialized successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to initialize shared storage: {str(e)}")
            return False
    
    def get_storage_usage(self) -> Dict[str, Dict[str, float]]:
        """Get current storage usage statistics"""
        try:
            usage_stats = {}
            
            # Get disk usage for each directory
            directories = {
                "vm_storage": self.vm_storage_path,
                "k8s_storage": self.k8s_storage_path,
                "monitoring": self.monitoring_storage_path,
                "backups": self.backup_storage_path,
                "logs": self.log_storage_path
            }
            
            for name, path in directories.items():
                if os.path.exists(path):
                    # Get disk usage in GB
                    result = subprocess.run(
                        ["du", "-s", path], 
                        capture_output=True, 
                        text=True
                    )
                    if result.returncode == 0:
                        used_kb = int(result.stdout.split()[0])
                        used_gb = used_kb / (1024 * 1024)  # Convert KB to GB
                        
                        usage_stats[name] = {
                            "used_gb": round(used_gb, 2),
                            "limit_gb": self.storage_limits[name],
                            "available_gb": round(self.storage_limits[name] - used_gb, 2),
                            "usage_percentage": round((used_gb / self.storage_limits[name]) * 100, 2)
                        }
            
            # Get total usage
            result = subprocess.run(
                ["df", "-BG", "/"], 
                capture_output=True, 
                text=True
            )
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) > 1:
                    parts = lines[1].split()
                    total_gb = int(parts[1].replace('G', ''))
                    used_gb = int(parts[2].replace('G', ''))
                    available_gb = int(parts[3].replace('G', ''))
                    
                    usage_stats["total"] = {
                        "used_gb": used_gb,
                        "total_gb": total_gb,
                        "available_gb": available_gb,
                        "usage_percentage": round((used_gb / total_gb) * 100, 2)
                    }
            
            return usage_stats
            
        except Exception as e:
            logger.error(f"Failed to get storage usage: {str(e)}")
            return {}
    
    def allocate_vm_storage(self, vm_id: str, size_gb: int) -> Tuple[bool, str]:
        """Allocate storage for a VM"""
        try:
            # Check if enough storage is available
            usage_stats = self.get_storage_usage()
            vm_usage = usage_stats.get("vm_storage", {})
            available_gb = vm_usage.get("available_gb", 0)
            
            if available_gb < size_gb:
                return False, f"Insufficient VM storage. Available: {available_gb}GB, Required: {size_gb}GB"
            
            # Create VM storage directory
            vm_dir = f"{self.vm_storage_path}/instances/{vm_id}"
            Path(vm_dir).mkdir(parents=True, exist_ok=True)
            os.chmod(vm_dir, 0o755)
            
            # Create VM disk image
            disk_path = f"{vm_dir}/disk.qcow2"
            result = subprocess.run([
                "qemu-img", "create", "-f", "qcow2", 
                disk_path, f"{size_gb}G"
            ], capture_output=True, text=True)
            
            if result.returncode == 0:
                logger.info(f"VM storage allocated: {vm_id} - {size_gb}GB")
                return True, disk_path
            else:
                return False, f"Failed to create VM disk: {result.stderr}"
                
        except Exception as e:
            logger.error(f"Failed to allocate VM storage: {str(e)}")
            return False, str(e)
    
    def deallocate_vm_storage(self, vm_id: str) -> bool:
        """Deallocate storage for a VM"""
        try:
            vm_dir = f"{self.vm_storage_path}/instances/{vm_id}"
            if os.path.exists(vm_dir):
                shutil.rmtree(vm_dir)
                logger.info(f"VM storage deallocated: {vm_id}")
                return True
            return False
            
        except Exception as e:
            logger.error(f"Failed to deallocate VM storage: {str(e)}")
            return False
    
    def create_vm_snapshot(self, vm_id: str, snapshot_name: str) -> Tuple[bool, str]:
        """Create a snapshot of a VM"""
        try:
            vm_dir = f"{self.vm_storage_path}/instances/{vm_id}"
            disk_path = f"{vm_dir}/disk.qcow2"
            snapshot_path = f"{self.vm_storage_path}/snapshots/{vm_id}_{snapshot_name}.qcow2"
            
            if not os.path.exists(disk_path):
                return False, "VM disk not found"
            
            # Create snapshot directory
            Path(f"{self.vm_storage_path}/snapshots").mkdir(parents=True, exist_ok=True)
            
            # Create snapshot
            result = subprocess.run([
                "qemu-img", "create", "-f", "qcow2", "-b", disk_path,
                snapshot_path
            ], capture_output=True, text=True)
            
            if result.returncode == 0:
                logger.info(f"VM snapshot created: {vm_id} - {snapshot_name}")
                return True, snapshot_path
            else:
                return False, f"Failed to create snapshot: {result.stderr}"
                
        except Exception as e:
            logger.error(f"Failed to create VM snapshot: {str(e)}")
            return False, str(e)
    
    def cleanup_old_backups(self, days_to_keep: int = 30) -> bool:
        """Clean up old backup files"""
        try:
            backup_dir = Path(self.backup_storage_path)
            if not backup_dir.exists():
                return True
            
            # Find files older than specified days
            cutoff_time = time.time() - (days_to_keep * 24 * 60 * 60)
            
            for file_path in backup_dir.rglob("*"):
                if file_path.is_file() and file_path.stat().st_mtime < cutoff_time:
                    file_path.unlink()
                    logger.info(f"Deleted old backup: {file_path}")
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to cleanup old backups: {str(e)}")
            return False
    
    def get_storage_health(self) -> Dict[str, any]:
        """Get storage health information"""
        try:
            usage_stats = self.get_storage_usage()
            
            health_info = {
                "status": "healthy",
                "usage_stats": usage_stats,
                "warnings": [],
                "errors": []
            }
            
            # Check for storage warnings
            for name, stats in usage_stats.items():
                if name == "total":
                    continue
                    
                usage_percentage = stats.get("usage_percentage", 0)
                if usage_percentage > 90:
                    health_info["warnings"].append(f"{name} storage is {usage_percentage}% full")
                elif usage_percentage > 95:
                    health_info["status"] = "critical"
                    health_info["errors"].append(f"{name} storage is critically full: {usage_percentage}%")
            
            # Check total storage
            total_stats = usage_stats.get("total", {})
            total_usage = total_stats.get("usage_percentage", 0)
            if total_usage > 95:
                health_info["status"] = "critical"
                health_info["errors"].append(f"Total storage is critically full: {total_usage}%")
            elif total_usage > 90:
                health_info["warnings"].append(f"Total storage is {total_usage}% full")
            
            return health_info
            
        except Exception as e:
            logger.error(f"Failed to get storage health: {str(e)}")
            return {
                "status": "error",
                "error": str(e),
                "usage_stats": {},
                "warnings": [],
                "errors": [str(e)]
            }
    
    def resize_vm_storage(self, vm_id: str, new_size_gb: int) -> Tuple[bool, str]:
        """Resize VM storage"""
        try:
            vm_dir = f"{self.vm_storage_path}/instances/{vm_id}"
            disk_path = f"{vm_dir}/disk.qcow2"
            
            if not os.path.exists(disk_path):
                return False, "VM disk not found"
            
            # Check if enough storage is available
            usage_stats = self.get_storage_usage()
            vm_usage = usage_stats.get("vm_storage", {})
            available_gb = vm_usage.get("available_gb", 0)
            
            # Get current disk size
            result = subprocess.run([
                "qemu-img", "info", disk_path
            ], capture_output=True, text=True)
            
            if result.returncode != 0:
                return False, f"Failed to get disk info: {result.stderr}"
            
            # Parse current size
            current_size_gb = 0
            for line in result.stdout.split('\n'):
                if 'virtual size' in line:
                    size_str = line.split()[2]
                    current_size_gb = int(size_str.replace('G', ''))
                    break
            
            size_diff = new_size_gb - current_size_gb
            if size_diff > available_gb:
                return False, f"Insufficient storage. Available: {available_gb}GB, Required: {size_diff}GB"
            
            # Resize the disk
            result = subprocess.run([
                "qemu-img", "resize", disk_path, f"{new_size_gb}G"
            ], capture_output=True, text=True)
            
            if result.returncode == 0:
                logger.info(f"VM storage resized: {vm_id} - {new_size_gb}GB")
                return True, f"Storage resized to {new_size_gb}GB"
            else:
                return False, f"Failed to resize disk: {result.stderr}"
                
        except Exception as e:
            logger.error(f"Failed to resize VM storage: {str(e)}")
            return False, str(e)