# Shared Storage Deployment Guide

This guide explains how to deploy and use the 1.8TB RAID storage configuration for both Kubernetes and VM provisioning.

## Overview

The shared storage system uses a 1.8TB RAID storage mounted at `/` (root filesystem) and allocates it as follows:

| Component | Allocation | Purpose |
|-----------|------------|---------|
| VM Storage | 1TB (1000GB) | Virtual machine disk images, templates, snapshots |
| Kubernetes Storage | 500GB | Persistent volumes, databases, applications |
| Monitoring Storage | 200GB | Prometheus metrics, Grafana dashboards, logs |
| Backup Storage | 80GB | System backups, VM snapshots |
| Log Storage | 20GB | Application logs, system logs |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   1.8TB RAID Storage                        │
│                     (mounted at /)                          │
└─────────────────────────────────────────────────────────────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
        ┌───────▼───────┐ ┌─────▼─────┐ ┌──────▼──────┐
        │ VM Storage    │ │ K8s Storage│ │ Monitoring  │
        │ (1TB)         │ │ (500GB)    │ │ (200GB)     │
        │               │ │            │ │             │
        │ • Images      │ │ • PVs      │ │ • Prometheus│
        │ • Templates   │ │ • Databases│ │ • Grafana   │
        │ • Instances   │ │ • Apps     │ │ • Alerts   │
        │ • Snapshots   │ │ • Logs     │ │ • Logs     │
        └───────────────┘ └────────────┘ └─────────────┘
                │               │               │
        ┌──────▼──────┐ ┌──────▼──────┐ ┌─────▼─────┐
        │ Backups     │ │ Logs        │ │ System    │
        │ (80GB)      │ │ (20GB)      │ │ Reserve   │
        │             │ │             │ │           │
        │ • VM Snaps  │ │ • App Logs  │ │ • OS      │
        │ • K8s Backs │ │ • Sys Logs  │ │ • Temp    │
        │ • Archives  │ │ • Audit     │ │ • Cache   │
        └─────────────┘ └─────────────┘ └───────────┘
```

## Prerequisites

- Kubernetes cluster with at least 2 nodes
- kubectl configured and connected to the cluster
- Root access to all nodes
- 1.8TB RAID storage mounted at `/` on each node

## Deployment

### 1. Deploy Shared Storage Configuration

```bash
# Make deployment script executable
chmod +x scripts/deploy-shared-storage.sh

# Deploy the complete storage configuration
./scripts/deploy-shared-storage.sh
```

This script will:
- Set up shared storage directories on all nodes
- Deploy Kubernetes storage classes and provisioners
- Deploy VM provisioning components
- Configure monitoring and cleanup jobs
- Verify the deployment

### 2. Verify Deployment

```bash
# Make test script executable
chmod +x scripts/test-shared-storage.sh

# Run comprehensive tests
./scripts/test-shared-storage.sh
```

## Storage Classes

The system provides several storage classes for different use cases:

### shared-storage-fast (Default)
- **Purpose**: High-performance applications
- **Reclaim Policy**: Delete
- **Binding Mode**: WaitForFirstConsumer
- **Path**: `/shared-storage/k8s-pv`

### shared-storage-slow
- **Purpose**: Long-term storage
- **Reclaim Policy**: Retain
- **Binding Mode**: WaitForFirstConsumer
- **Path**: `/shared-storage/k8s-pv`

### shared-storage-monitoring
- **Purpose**: Monitoring data storage
- **Reclaim Policy**: Retain
- **Binding Mode**: WaitForFirstConsumer
- **Path**: `/shared-storage/monitoring`

### vm-storage
- **Purpose**: VM disk images
- **Reclaim Policy**: Retain
- **Binding Mode**: WaitForFirstConsumer
- **Path**: `/shared-storage/vm-storage`

## Usage Examples

### Creating Persistent Volumes

```yaml
# Database storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: shared-storage-fast
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
  storageClassName: shared-storage-fast
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
  storageClassName: shared-storage-monitoring
  resources:
    requests:
      storage: 50Gi
```

### Creating VMs

```bash
# Create a VM using the API
curl -X POST http://vm-provisioner-service.vm-system.svc.cluster.local:8080/api/v1/vms \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
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

### Storage Usage

```bash
# Check storage usage
kubectl exec -n shared-storage-system deployment/enhanced-local-path-provisioner -- /shared-storage/monitor-storage.sh usage

# Get detailed statistics
kubectl exec -n shared-storage-system deployment/enhanced-local-path-provisioner -- /shared-storage/monitor-storage.sh stats

# Check storage health
kubectl exec -n shared-storage-system deployment/enhanced-local-path-provisioner -- /shared-storage/monitor-storage.sh health
```

### Storage Health Alerts

The system automatically monitors storage usage and generates alerts:

- **Warning**: Storage usage > 75%
- **Critical**: Storage usage > 90%

### Monitoring Dashboard

Access the monitoring dashboard at:
```
http://grafana.monitoring.svc.cluster.local:3000
```

## Maintenance

### Automatic Cleanup

The system includes automatic cleanup jobs:

- **Storage Cleanup**: Daily at 2 AM
- **VM Storage Cleanup**: Daily at 3 AM

### Manual Cleanup

```bash
# Run storage cleanup manually
kubectl create job --from=cronjob/storage-cleanup storage-cleanup-manual -n shared-storage-system

# Run VM storage cleanup manually
kubectl create job --from=cronjob/vm-storage-cleanup vm-storage-cleanup-manual -n vm-system
```

### Backup Procedures

```bash
# Create VM snapshot
curl -X POST http://vm-provisioner-service.vm-system.svc.cluster.local:8080/api/v1/storage/vms/{vm_id}/snapshot \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"snapshot_name": "backup-2024-01-01"}'

# Resize VM storage
curl -X POST http://vm-provisioner-service.vm-system.svc.cluster.local:8080/api/v1/storage/vms/{vm_id}/resize \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"new_size_gb": 100}'
```

## Troubleshooting

### Common Issues

#### 1. Storage Full
```bash
# Check storage usage
kubectl exec -n shared-storage-system deployment/enhanced-local-path-provisioner -- /shared-storage/monitor-storage.sh usage

# Clean up old files
kubectl create job --from=cronjob/storage-cleanup storage-cleanup-manual -n shared-storage-system
```

#### 2. Permission Issues
```bash
# Fix permissions on nodes
kubectl exec <node-name> -- chown -R 1000:1000 /shared-storage/k8s-pv
kubectl exec <node-name> -- chown -R 1001:1001 /shared-storage/vm-storage
```

#### 3. Storage Classes Not Working
```bash
# Check storage classes
kubectl get storageclass

# Check local path provisioner
kubectl get pods -n shared-storage-system -l app=enhanced-local-path-provisioner
```

#### 4. VM Provisioning Issues
```bash
# Check VM provisioner
kubectl get pods -n vm-system -l app=vm-provisioner

# Check VM storage manager
kubectl get pods -n vm-system -l app=vm-storage-manager
```

### Logs

```bash
# Storage monitor logs
kubectl logs -n shared-storage-system -l app=storage-monitor

# VM provisioner logs
kubectl logs -n vm-system -l app=vm-provisioner

# VM storage manager logs
kubectl logs -n vm-system -l app=vm-storage-manager
```

## API Reference

### Storage Management API

#### Get Storage Usage
```http
GET /api/v1/storage/usage
```

Response:
```json
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

#### Get Storage Health
```http
GET /api/v1/storage/health
```

Response:
```json
{
  "status": "healthy",
  "usage_stats": {...},
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

#### Create VM Snapshot
```http
POST /api/v1/storage/vms/{vm_id}/snapshot
Content-Type: application/json

{
  "snapshot_name": "backup-2024-01-01"
}
```

## Security Considerations

1. **Access Control**: Ensure proper RBAC policies are in place
2. **Network Security**: Use network policies to restrict access
3. **Data Encryption**: Consider encrypting sensitive data at rest
4. **Backup Security**: Secure backup storage and access
5. **Audit Logging**: Enable audit logging for storage operations

## Performance Optimization

1. **RAID Configuration**: Use hardware RAID for better performance
2. **File System**: Use XFS or Ext4 with appropriate mount options
3. **Caching**: Enable kernel page cache for frequently accessed data
4. **Compression**: Use compression for backup files
5. **Monitoring**: Monitor I/O performance and optimize as needed

## Scaling

The storage system is designed to scale horizontally:

1. **Add Nodes**: Add more nodes to increase storage capacity
2. **Distribute Load**: Use node affinity to distribute storage load
3. **Monitor Usage**: Monitor storage usage across all nodes
4. **Optimize Allocation**: Adjust storage allocations based on usage patterns

## Support

For issues and support:

1. Check the troubleshooting section above
2. Review logs for error messages
3. Run the test script to identify issues
4. Check storage health and usage statistics
5. Contact the system administrator for complex issues

## Conclusion

This shared storage configuration provides a robust, scalable solution for both Kubernetes and VM provisioning using the 1.8TB RAID storage. The system includes comprehensive monitoring, automatic cleanup, and management tools to ensure optimal performance and reliability.