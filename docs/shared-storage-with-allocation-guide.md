# Shared Storage with Separate Allocations Guide

This guide explains how to deploy and manage shared storage with separate allocations for Kubernetes and VM provisioning using the same 1.8TB storage.

## Overview

The shared storage system uses a single 1.8TB storage per server split into separate allocations:

- **K8s Storage**: 1.5TB for Kubernetes workloads (`/shared-storage/k8s-storage`)
- **VM Storage**: 1.5TB for VM provisioning (`/shared-storage/vm-storage`)
- **System Reserve**: 300GB for system operations (`/shared-storage/system`)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   1.8TB Storage per Server                  │
│                     (mounted at /)                          │
└─────────────────────────────────────────────────────────────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
        ┌───────▼───────┐ ┌─────▼─────┐ ┌──────▼──────┐
        │ K8s Storage   │ │ VM Storage│ │ System      │
        │ (1.5TB)       │ │ (1.5TB)   │ │ Reserve     │
        │               │ │           │ │ (300GB)     │
        │ • Databases   │ │ • Images  │ │ • OS        │
        │ • Applications│ │ • Templates│ │ • Temp      │
        │ • Monitoring  │ │ • Instances│ │ • Cache     │
        │ • Logs        │ │ • Snapshots│ │ • Swap      │
        │ • Backups     │ │ • Backups │ │ • Logs      │
        └───────────────┘ └───────────┘ └─────────────┘
```

## Storage Allocation

### K8s Storage (1.5TB)
- **Path**: `/shared-storage/k8s-storage`
- **Owner**: `1000:1000`
- **Subdirectories**:
  - `databases/` - Database storage
  - `applications/` - Application data
  - `monitoring/` - Monitoring data
  - `logs/` - Log storage
  - `backups/` - Backup storage

### VM Storage (1.5TB)
- **Path**: `/shared-storage/vm-storage`
- **Owner**: `1001:1001`
- **Subdirectories**:
  - `images/` - Base VM images
  - `templates/` - VM templates
  - `instances/` - VM instance disks
  - `snapshots/` - VM snapshots
  - `backups/` - VM backups

### System Reserve (300GB)
- **Path**: `/shared-storage/system`
- **Owner**: `root:root`
- **Purpose**: System operations, temporary files, cache, swap

## Prerequisites

- Kubernetes cluster with at least 2 nodes
- kubectl configured and connected to the cluster
- Root access to all nodes
- 1.8TB storage per server

## Deployment

### 1. Deploy Shared Storage with Allocations

```bash
# Make deployment script executable
chmod +x scripts/deploy-shared-storage-with-allocation.sh

# Deploy the shared storage with separate allocations
./scripts/deploy-shared-storage-with-allocation.sh
```

This script will:
- Set up shared storage directories with proper allocations
- Deploy K8s storage provisioner
- Deploy VM storage manager
- Deploy storage monitoring
- Deploy cleanup jobs
- Verify the deployment

### 2. Verify Deployment

```bash
# Make test script executable
chmod +x scripts/test-shared-storage-with-allocation.sh

# Run comprehensive tests
./scripts/test-shared-storage-with-allocation.sh
```

## Storage Classes

### K8s Storage Classes

#### k8s-database-storage
- **Purpose**: Database storage
- **Reclaim Policy**: Retain
- **Binding Mode**: WaitForFirstConsumer
- **Path**: `/shared-storage/k8s-storage/databases`

#### k8s-app-storage (Default)
- **Purpose**: Application storage
- **Reclaim Policy**: Delete
- **Binding Mode**: WaitForFirstConsumer
- **Path**: `/shared-storage/k8s-storage/applications`

#### k8s-monitoring-storage
- **Purpose**: Monitoring data storage
- **Reclaim Policy**: Retain
- **Binding Mode**: WaitForFirstConsumer
- **Path**: `/shared-storage/k8s-storage/monitoring`

#### k8s-log-storage
- **Purpose**: Log storage
- **Reclaim Policy**: Delete
- **Binding Mode**: WaitForFirstConsumer
- **Path**: `/shared-storage/k8s-storage/logs`

#### k8s-backup-storage
- **Purpose**: Backup storage
- **Reclaim Policy**: Retain
- **Binding Mode**: WaitForFirstConsumer
- **Path**: `/shared-storage/k8s-storage/backups`

## Usage Examples

### Creating K8s Persistent Volumes

```yaml
# Database storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: k8s-database-storage
  resources:
    requests:
      storage: 50Gi
---
# Application storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: k8s-app-storage
  resources:
    requests:
      storage: 100Gi
---
# Monitoring storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: monitoring-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: k8s-monitoring-storage
  resources:
    requests:
      storage: 50Gi
```

### Creating VMs

```bash
# Create a VM using the VM storage API
curl -X POST http://vm-storage-api.shared-storage-system.svc.cluster.local:8080/api/v1/vms \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-vm",
    "image": "ubuntu22",
    "server_type": "cx21",
    "cpu": 2,
    "memory": 4,
    "storage": 50,
    "namespace": "default"
  }'
```

## Monitoring

### Storage Usage Monitoring

```bash
# Check overall storage usage
kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- /shared-storage/monitor-storage.sh

# Check K8s storage usage
kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- du -sh /shared-storage/k8s-storage/*

# Check VM storage usage
kubectl exec -n shared-storage-system daemonset/vm-storage-manager -- du -sh /shared-storage/vm-storage/*
```

### Storage Health Monitoring

The system automatically monitors storage usage and generates alerts:

- **Warning**: Storage usage > 75% of allocation
- **Critical**: Storage usage > 90% of allocation

### Storage Allocation Monitoring

```bash
# Check K8s storage allocation (1.5TB limit)
kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- df -h /shared-storage/k8s-storage

# Check VM storage allocation (1.5TB limit)
kubectl exec -n shared-storage-system daemonset/vm-storage-manager -- df -h /shared-storage/vm-storage

# Check system reserve (300GB limit)
kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- df -h /shared-storage/system
```

## Maintenance

### Automatic Cleanup

The system includes automatic cleanup jobs:

- **Storage Cleanup**: Daily at 2 AM
- **K8s Storage Cleanup**: Old backups (>30 days), logs (>7 days)
- **VM Storage Cleanup**: Old snapshots (>90 days), orphaned files

### Manual Cleanup

```bash
# Run storage cleanup manually
kubectl create job --from=cronjob/storage-cleanup storage-cleanup-manual -n shared-storage-system

# Check cleanup job status
kubectl get jobs -n shared-storage-system
```

### Backup Procedures

```bash
# Create VM snapshot
curl -X POST http://vm-storage-api.shared-storage-system.svc.cluster.local:8080/api/v1/storage/vms/{vm_id}/snapshot \
  -d '{"snapshot_name": "backup-2024-01-01"}'

# Resize VM storage
curl -X POST http://vm-storage-api.shared-storage-system.svc.cluster.local:8080/api/v1/storage/vms/{vm_id}/resize \
  -d '{"new_size_gb": 100}'
```

## Troubleshooting

### Common Issues

#### 1. Storage Allocation Full
```bash
# Check storage usage
kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- /shared-storage/monitor-storage.sh

# Check specific allocation
kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- df -h /shared-storage/k8s-storage
kubectl exec -n shared-storage-system daemonset/vm-storage-manager -- df -h /shared-storage/vm-storage
```

#### 2. Permission Issues
```bash
# Fix K8s storage permissions
kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- chown -R 1000:1000 /shared-storage/k8s-storage

# Fix VM storage permissions
kubectl exec -n shared-storage-system daemonset/vm-storage-manager -- chown -R 1001:1001 /shared-storage/vm-storage
```

#### 3. Storage Classes Not Working
```bash
# Check storage classes
kubectl get storageclass | grep k8s-

# Check K8s storage provisioner
kubectl get pods -n shared-storage-system -l app=k8s-storage-provisioner

# Check provisioner logs
kubectl logs -n shared-storage-system -l app=k8s-storage-provisioner
```

#### 4. VM Storage Issues
```bash
# Check VM storage manager
kubectl get pods -n shared-storage-system -l app=vm-storage-manager

# Check VM templates
kubectl exec -n shared-storage-system daemonset/vm-storage-manager -- ls -la /shared-storage/vm-storage/templates/

# Check VM storage manager logs
kubectl logs -n shared-storage-system -l app=vm-storage-manager
```

### Logs

```bash
# K8s storage provisioner logs
kubectl logs -n shared-storage-system -l app=k8s-storage-provisioner

# VM storage manager logs
kubectl logs -n shared-storage-system -l app=vm-storage-manager

# Storage monitor logs
kubectl logs -n shared-storage-system -l app=storage-monitor
```

## Storage Allocation Management

### Monitoring Allocation Usage

```bash
# Get detailed storage usage
kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- /shared-storage/monitor-storage.sh

# Check allocation limits
kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- df -h /shared-storage
```

### Allocation Optimization

1. **Monitor Usage**: Regularly check allocation usage
2. **Cleanup**: Remove old files and backups
3. **Optimize**: Compress and optimize storage
4. **Balance**: Adjust allocations if needed

## Security Considerations

1. **Access Control**: Proper permissions for each allocation
2. **Isolation**: Separate ownership for K8s and VM storage
3. **Monitoring**: Continuous monitoring of allocation usage
4. **Backup**: Regular backups of critical data
5. **Audit**: Comprehensive logging for all operations

## Performance Optimization

1. **Local Storage**: Each allocation uses local storage for optimal performance
2. **Allocation Management**: Proper allocation sizing and monitoring
3. **Cleanup**: Regular cleanup to maintain performance
4. **Monitoring**: Real-time monitoring of allocation usage
5. **Optimization**: Storage optimization and compression

## Scaling

The shared storage system is designed to scale horizontally:

1. **Add Nodes**: Add more nodes to increase total storage capacity
2. **Monitor Allocations**: Monitor allocation usage across all nodes
3. **Optimize Usage**: Optimize storage usage within allocations
4. **Balance Load**: Distribute load across all nodes

## API Reference

### Storage Management API

#### Get Storage Usage
```http
GET /api/v1/storage/usage
```

Response:
```json
{
  "k8s_storage": {
    "used_gb": 250.5,
    "limit_gb": 1500,
    "available_gb": 1249.5,
    "usage_percentage": 16.7
  },
  "vm_storage": {
    "used_gb": 350.3,
    "limit_gb": 1500,
    "available_gb": 1149.7,
    "usage_percentage": 23.35
  },
  "system_reserve": {
    "used_gb": 50.8,
    "limit_gb": 300,
    "available_gb": 249.2,
    "usage_percentage": 16.93
  },
  "total": {
    "used_gb": 651.6,
    "total_gb": 1800,
    "available_gb": 1148.4,
    "usage_percentage": 36.2
  }
}
```

#### Get Storage Health
```http
GET /api/v1/storage/health
```

Response:
```json
{
  "status": "healthy",
  "allocations": {
    "k8s_storage": "healthy",
    "vm_storage": "healthy",
    "system_reserve": "healthy"
  },
  "warnings": [],
  "errors": []
}
```

### VM Management API

#### Create VM
```http
POST /api/v1/vms
Content-Type: application/json

{
  "name": "test-vm",
  "image": "ubuntu22",
  "server_type": "cx21",
  "cpu": 2,
  "memory": 4,
  "storage": 50,
  "namespace": "default"
}
```

#### Resize VM Storage
```http
POST /api/v1/storage/vms/{vm_id}/resize
Content-Type: application/json

{
  "new_size_gb": 100
}
```

## Support

For issues and support:

1. Check the troubleshooting section above
2. Review logs for error messages
3. Run the test script to identify issues
4. Check storage allocation usage
5. Contact the system administrator for complex issues

## Conclusion

This shared storage configuration provides a robust, scalable solution for both Kubernetes and VM provisioning using the same 1.8TB storage with separate allocations. The system includes comprehensive monitoring, automatic cleanup, and management tools to ensure optimal performance and reliability while maintaining proper allocation limits for each use case.