# Shared Storage Configuration Guide

This guide explains how the Hetzner DC & Kubernetes cluster uses the shared RAID storage (1.8TB) mounted at `/` for all storage needs.

## Table of Contents

1. [Storage Overview](#storage-overview)
2. [Storage Allocation](#storage-allocation)
3. [Directory Structure](#directory-structure)
4. [Kubernetes Storage](#kubernetes-storage)
5. [VM Storage](#vm-storage)
6. [Monitoring Storage](#monitoring-storage)
7. [Storage Management](#storage-management)
8. [Backup and Recovery](#backup-and-recovery)
9. [Troubleshooting](#troubleshooting)

## Storage Overview

### Shared RAID Storage
- **Total Capacity**: 1.8TB
- **Mount Point**: `/` (root filesystem)
- **RAID Configuration**: Hardware RAID enabled
- **File System**: Ext4 or XFS
- **Access**: Shared across all nodes

### Storage Allocation Strategy
The 1.8TB storage is allocated as follows:

| Component | Allocation | Purpose |
|-----------|------------|---------|
| VM Storage | 1TB (1000GB) | Virtual machine disk images, templates, snapshots |
| Kubernetes Storage | 500GB | Persistent volumes, databases, applications |
| Monitoring Storage | 200GB | Prometheus metrics, Grafana dashboards, logs |
| Backup Storage | 80GB | System backups, VM snapshots |
| Log Storage | 20GB | Application logs, system logs |

## Storage Allocation

### Automatic Allocation
The system automatically manages storage allocation based on the following limits:

```yaml
storage_limits:
  total: 1800  # 1.8TB total
  vm_storage: 1000  # 1TB for VMs
  k8s_storage: 500  # 500GB for Kubernetes
  monitoring: 200  # 200GB for monitoring
  backups: 80  # 80GB for backups
  logs: 20  # 20GB for logs
```

### Dynamic Allocation
- Storage is allocated dynamically as needed
- Automatic cleanup of old backups and logs
- Warning alerts when storage usage exceeds 75%
- Critical alerts when storage usage exceeds 90%

## Directory Structure

### Main Storage Directory
```
/shared-storage/
├── k8s-pv/                    # Kubernetes Persistent Volumes
│   ├── databases/            # Database storage
│   ├── applications/         # Application data
│   └── logs/                 # Application logs
├── vm-storage/               # VM Storage
│   ├── images/               # VM disk images
│   ├── templates/            # VM templates
│   ├── instances/            # VM instances
│   └── snapshots/            # VM snapshots
├── monitoring/               # Monitoring Data
│   ├── prometheus/           # Prometheus metrics
│   ├── grafana/              # Grafana dashboards
│   └── alertmanager/         # AlertManager data
├── backups/                  # Backup Storage
│   ├── system/               # System backups
│   ├── vm-snapshots/         # VM snapshots
│   └── k8s-backups/          # Kubernetes backups
└── logs/                     # Log Storage
    ├── application/          # Application logs
    ├── system/               # System logs
    └── audit/                # Audit logs
```

## Kubernetes Storage

### Local Path Provisioner
The cluster uses a local path provisioner that creates persistent volumes in the shared storage:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

### Persistent Volume Configuration
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: example-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 10Gi
```

### Storage Classes
- **local-path**: Default storage class using shared storage
- **shared-storage**: For applications requiring ReadWriteMany access

## VM Storage

### VM Disk Images
VM disk images are stored as QCOW2 format in the shared storage:

```bash
/shared-storage/vm-storage/instances/{vm_id}/disk.qcow2
```

### VM Templates
Pre-built VM templates are stored in:
```bash
/shared-storage/vm-storage/templates/
├── centos7.qcow2
├── rhel8.qcow2
├── ubuntu22.qcow2
└── rockylinux9.qcow2
```

### VM Snapshots
VM snapshots are stored in:
```bash
/shared-storage/vm-storage/snapshots/{vm_id}_{snapshot_name}.qcow2
```

### Storage Management API
The VM provisioning API provides storage management endpoints:

```python
# Allocate VM storage
POST /api/v1/storage/vms/{vm_id}/allocate
{
    "size_gb": 50
}

# Resize VM storage
POST /api/v1/storage/vms/{vm_id}/resize
{
    "new_size_gb": 100
}

# Create VM snapshot
POST /api/v1/storage/vms/{vm_id}/snapshot
{
    "snapshot_name": "backup-2024-01-01"
}
```

## Monitoring Storage

### Prometheus Storage
Prometheus metrics are stored in:
```bash
/shared-storage/monitoring/prometheus/
├── data/                     # Metrics data
├── wal/                      # Write-ahead log
└── rules/                    # Alert rules
```

### Grafana Storage
Grafana dashboards and configuration:
```bash
/shared-storage/monitoring/grafana/
├── dashboards/               # Dashboard definitions
├── datasources/              # Data source configurations
└── plugins/                  # Grafana plugins
```

### AlertManager Storage
AlertManager configuration and state:
```bash
/shared-storage/monitoring/alertmanager/
├── config/                   # AlertManager configuration
├── data/                     # Alert state data
└── templates/                # Alert templates
```

## Storage Management

### Storage Usage Monitoring
The system provides real-time storage usage monitoring:

```python
# Get storage usage statistics
GET /api/v1/storage/usage

# Response
{
    "vm_storage": {
        "used_gb": 250.5,
        "limit_gb": 1000,
        "available_gb": 749.5,
        "usage_percentage": 25.05
    },
    "k8s_storage": {
        "used_gb": 120.3,
        "limit_gb": 500,
        "available_gb": 379.7,
        "usage_percentage": 24.06
    },
    "total": {
        "used_gb": 450.8,
        "total_gb": 1800,
        "available_gb": 1349.2,
        "usage_percentage": 25.04
    }
}
```

### Storage Health Checks
```python
# Get storage health information
GET /api/v1/storage/health

# Response
{
    "status": "healthy",
    "usage_stats": {...},
    "warnings": [],
    "errors": []
}
```

### Storage Alerts
The system generates alerts for:
- Storage usage > 75% (Warning)
- Storage usage > 90% (Critical)
- Disk space < 10GB (Critical)
- Failed storage operations

## Backup and Recovery

### Automated Backups
The system performs automated backups:

1. **Daily VM Snapshots**: Automatic snapshots of running VMs
2. **Weekly System Backups**: Full system configuration backup
3. **Monthly Archive**: Long-term storage of important data

### Backup Retention Policy
- **VM Snapshots**: 30 days
- **System Backups**: 90 days
- **Archive Backups**: 1 year

### Recovery Procedures
```bash
# Restore VM from snapshot
qemu-img create -f qcow2 -b /shared-storage/vm-storage/snapshots/vm-001_backup-2024-01-01.qcow2 /shared-storage/vm-storage/instances/vm-001/disk.qcow2

# Restore Kubernetes data
kubectl apply -f /shared-storage/backups/k8s-backups/backup-2024-01-01/

# Restore monitoring data
cp -r /shared-storage/backups/monitoring/backup-2024-01-01/* /shared-storage/monitoring/
```

## Storage Configuration

### Environment Variables
```bash
# Storage Configuration
SHARED_STORAGE_PATH=/shared-storage
STORAGE_TOTAL_SIZE=1800
STORAGE_VM_ALLOCATION=1000
STORAGE_K8S_ALLOCATION=500
STORAGE_MONITORING_ALLOCATION=200
STORAGE_BACKUP_ALLOCATION=80
STORAGE_LOG_ALLOCATION=20
```

### Ansible Configuration
```yaml
# ansible/group_vars/all/storage-config.yml
storage:
  shared_path: "/shared-storage"
  allocations:
    vm_storage: 1000
    k8s_storage: 500
    monitoring: 200
    backups: 80
    logs: 20
  cleanup:
    backup_retention_days: 30
    log_retention_days: 7
```

## Performance Optimization

### Storage Performance
- **RAID Configuration**: Hardware RAID for redundancy and performance
- **File System**: Optimized for large files (VM images)
- **Caching**: Kernel page cache for frequently accessed data
- **Compression**: Automatic compression for backup files

### Monitoring Performance
```bash
# Check disk I/O performance
iostat -x 1

# Check disk usage
df -h /shared-storage

# Check inode usage
df -i /shared-storage
```

## Troubleshooting

### Common Issues

#### 1. Storage Full
```bash
# Check storage usage
du -sh /shared-storage/*

# Clean up old backups
find /shared-storage/backups -type f -mtime +30 -delete

# Clean up old logs
find /shared-storage/logs -type f -mtime +7 -delete
```

#### 2. Permission Issues
```bash
# Fix permissions
chown -R root:root /shared-storage
chmod -R 755 /shared-storage

# Fix specific directory permissions
chown -R 1000:1000 /shared-storage/k8s-pv
chown -R 1001:1001 /shared-storage/vm-storage
```

#### 3. Disk I/O Issues
```bash
# Check disk health
smartctl -a /dev/sda

# Check RAID status
cat /proc/mdstat

# Monitor I/O
iotop -o
```

### Storage Maintenance

#### Daily Maintenance
```bash
#!/bin/bash
# daily-storage-maintenance.sh

# Clean up old logs
find /shared-storage/logs -type f -mtime +7 -delete

# Clean up old backups
find /shared-storage/backups -type f -mtime +30 -delete

# Check storage health
df -h /shared-storage
du -sh /shared-storage/*

# Update storage statistics
curl -X POST http://localhost:8080/api/v1/storage/health-check
```

#### Weekly Maintenance
```bash
#!/bin/bash
# weekly-storage-maintenance.sh

# Create VM snapshots
for vm in $(kubectl get vms -o jsonpath='{.items[*].metadata.name}'); do
    kubectl create vm-snapshot $vm --snapshot-name="weekly-$(date +%Y-%m-%d)"
done

# Archive old snapshots
find /shared-storage/vm-storage/snapshots -type f -mtime +90 -exec mv {} /shared-storage/backups/archive/ \;

# Optimize storage
fstrim /shared-storage
```

### Storage Monitoring Scripts

#### Storage Usage Alert
```python
#!/usr/bin/env python3
# storage-alert.py

import requests
import json

def check_storage_usage():
    try:
        response = requests.get('http://localhost:8080/api/v1/storage/usage')
        data = response.json()
        
        for name, stats in data.items():
            if name == 'total':
                continue
                
            usage_percentage = stats.get('usage_percentage', 0)
            if usage_percentage > 90:
                print(f"CRITICAL: {name} storage is {usage_percentage}% full")
            elif usage_percentage > 75:
                print(f"WARNING: {name} storage is {usage_percentage}% full")
                
    except Exception as e:
        print(f"Error checking storage usage: {e}")

if __name__ == "__main__":
    check_storage_usage()
```

This comprehensive guide ensures proper management of the shared RAID storage for both Kubernetes and VM resources, with monitoring, backup, and recovery procedures.