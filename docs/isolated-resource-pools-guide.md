# Isolated Resource Pools Deployment Guide

This guide explains how to deploy and manage isolated resource pools for Kubernetes and VM provisioning, ensuring complete separation between the two resource pools.

## Overview

The isolated resource pools system separates baremetal servers into dedicated pools:

- **K8s Pool**: Dedicated servers for Kubernetes workloads
- **VM Pool**: Dedicated servers for VM provisioning
- **Complete Isolation**: No sharing of resources between pools

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Baremetal Servers                        │
│                     (1.8TB each)                           │
└─────────────────────────────────────────────────────────────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
        ┌───────▼───────┐ ┌─────▼─────┐ ┌──────▼──────┐
        │ K8s Pool      │ │ Isolation │ │ VM Pool     │
        │ (10.0.1.0/24) │ │ Layer     │ │ (10.0.2.0/24)│
        │               │ │           │ │             │
        │ • Control     │ │ • Network │ │ • VM Hosts  │
        │   Plane       │ │ • Storage │ │ • Templates │
        │ • Workers     │ │ • Access  │ │ • Instances │
        │ • Storage     │ │           │ │ • Snapshots │
        │ • Monitoring  │ │           │ │ • Backups   │
        └───────────────┘ └───────────┘ └─────────────┘
```

## Resource Pool Configuration

### K8s Pool (Kubernetes)
- **Network**: 10.0.1.0/24
- **Storage**: 1.8TB per server
- **Allocation**:
  - Databases: 500GB
  - Applications: 1000GB
  - Monitoring: 200GB
  - Logs: 50GB
  - Backups: 50GB

### VM Pool (VM Provisioning)
- **Network**: 10.0.2.0/24
- **Storage**: 1.8TB per server
- **Allocation**:
  - VM Images: 500GB
  - VM Templates: 200GB
  - VM Instances: 1000GB
  - VM Snapshots: 50GB
  - VM Backups: 50GB

## Prerequisites

- Kubernetes cluster with at least 4 nodes
- kubectl configured and connected to the cluster
- Root access to all nodes
- 1.8TB storage per server

## Deployment

### 1. Deploy Isolated Resource Pools

```bash
# Make deployment script executable
chmod +x scripts/deploy-isolated-resource-pools.sh

# Deploy the complete isolated resource pools configuration
./scripts/deploy-isolated-resource-pools.sh
```

This script will:
- Label nodes for resource pools
- Deploy K8s pool storage configuration
- Deploy VM pool storage configuration
- Deploy network isolation policies
- Verify the deployment
- Test resource pool isolation

### 2. Verify Deployment

```bash
# Make test script executable
chmod +x scripts/test-isolated-resource-pools.sh

# Run comprehensive tests
./scripts/test-isolated-resource-pools.sh
```

## Storage Classes

### K8s Pool Storage Classes

#### k8s-database-storage
- **Purpose**: Database storage
- **Reclaim Policy**: Retain
- **Binding Mode**: WaitForFirstConsumer
- **Path**: `/k8s-storage/databases`

#### k8s-app-storage (Default)
- **Purpose**: Application storage
- **Reclaim Policy**: Delete
- **Binding Mode**: WaitForFirstConsumer
- **Path**: `/k8s-storage/applications`

#### k8s-monitoring-storage
- **Purpose**: Monitoring data storage
- **Reclaim Policy**: Retain
- **Binding Mode**: WaitForFirstConsumer
- **Path**: `/k8s-storage/monitoring`

#### k8s-log-storage
- **Purpose**: Log storage
- **Reclaim Policy**: Delete
- **Binding Mode**: WaitForFirstConsumer
- **Path**: `/k8s-storage/logs`

#### k8s-backup-storage
- **Purpose**: Backup storage
- **Reclaim Policy**: Retain
- **Binding Mode**: WaitForFirstConsumer
- **Path**: `/k8s-storage/backups`

### VM Pool Storage Classes

#### vm-pool-storage
- **Purpose**: VM disk images
- **Reclaim Policy**: Retain
- **Binding Mode**: WaitForFirstConsumer
- **Path**: `/vm-storage`

## Usage Examples

### Creating K8s Pool Persistent Volumes

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

### Creating VMs in VM Pool

```bash
# Create a VM using the VM pool API
curl -X POST http://vm-pool-storage-api.vm-pool-storage.svc.cluster.local:8080/api/v1/vms \
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

### K8s Pool Storage Monitoring

```bash
# Check K8s pool storage usage
kubectl exec -n k8s-pool-storage deployment/k8s-pool-local-path-provisioner -- /k8s-storage/monitor-k8s-storage.sh

# Get K8s pool storage statistics
kubectl exec -n k8s-pool-storage deployment/k8s-pool-local-path-provisioner -- df -h /k8s-storage
```

### VM Pool Storage Monitoring

```bash
# Check VM pool storage usage
kubectl exec -n vm-pool-storage daemonset/vm-pool-storage-manager -- /vm-storage/monitor-vm-storage.sh

# Get VM pool storage statistics
kubectl exec -n vm-pool-storage daemonset/vm-pool-storage-manager -- df -h /vm-storage
```

### Resource Pool Isolation Monitoring

```bash
# Check isolation status
kubectl logs -n network-isolation deployment/resource-pool-isolation-monitor

# Run isolation test
kubectl create job --from=cronjob/test-resource-pool-isolation isolation-test-manual -n network-isolation
```

## Maintenance

### Automatic Cleanup

The system includes automatic cleanup jobs:

- **K8s Pool Cleanup**: Daily at 2 AM
- **VM Pool Cleanup**: Daily at 3 AM

### Manual Cleanup

```bash
# Run K8s pool cleanup manually
kubectl create job --from=cronjob/k8s-pool-storage-cleanup k8s-cleanup-manual -n k8s-pool-storage

# Run VM pool cleanup manually
kubectl create job --from=cronjob/vm-pool-storage-cleanup vm-cleanup-manual -n vm-pool-storage
```

### Backup Procedures

```bash
# Create VM snapshot
curl -X POST http://vm-pool-storage-api.vm-pool-storage.svc.cluster.local:8080/api/v1/storage/vms/{vm_id}/snapshot \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"snapshot_name": "backup-2024-01-01"}'

# Resize VM storage
curl -X POST http://vm-pool-storage-api.vm-pool-storage.svc.cluster.local:8080/api/v1/storage/vms/{vm_id}/resize \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"new_size_gb": 100}'
```

## Troubleshooting

### Common Issues

#### 1. Nodes Not Labeled for Resource Pools
```bash
# Check node labels
kubectl get nodes --show-labels | grep -E "(pool=k8s|pool=vm)"

# Label nodes manually
kubectl label node <node-name> pool=k8s
kubectl label node <node-name> pool=vm
```

#### 2. Storage Not Accessible
```bash
# Check storage directories
kubectl exec -n k8s-pool-storage deployment/k8s-pool-local-path-provisioner -- ls -la /k8s-storage
kubectl exec -n vm-pool-storage daemonset/vm-pool-storage-manager -- ls -la /vm-storage

# Check permissions
kubectl exec -n k8s-pool-storage deployment/k8s-pool-local-path-provisioner -- ls -la /k8s-storage
```

#### 3. Network Isolation Issues
```bash
# Check network policies
kubectl get networkpolicies --all-namespaces | grep -E "(k8s-pool|vm-pool)"

# Check isolation monitor
kubectl logs -n network-isolation deployment/resource-pool-isolation-monitor
```

#### 4. Cross-Pool Access Detected
```bash
# Run isolation test
kubectl create job --from=cronjob/test-resource-pool-isolation isolation-test-manual -n network-isolation

# Check test results
kubectl logs job/isolation-test-manual -n network-isolation
```

### Logs

```bash
# K8s pool logs
kubectl logs -n k8s-pool-storage -l app=k8s-pool-local-path-provisioner
kubectl logs -n k8s-pool-storage -l app=k8s-pool-storage-monitor

# VM pool logs
kubectl logs -n vm-pool-storage -l app=vm-pool-storage-manager

# Isolation monitor logs
kubectl logs -n network-isolation -l app=resource-pool-isolation-monitor
```

## Security Considerations

1. **Network Isolation**: Complete separation between K8s and VM pools
2. **Storage Isolation**: No cross-pool storage access
3. **Access Control**: Proper RBAC policies for each pool
4. **Monitoring**: Continuous monitoring of isolation status
5. **Audit Logging**: Comprehensive logging for all operations

## Performance Optimization

1. **Local Storage**: Each pool uses local storage for optimal performance
2. **Resource Allocation**: Proper resource allocation for each pool
3. **Monitoring**: Real-time monitoring of resource usage
4. **Cleanup**: Automatic cleanup to maintain performance
5. **Isolation**: No cross-pool interference

## Scaling

The isolated resource pools system is designed to scale horizontally:

1. **Add K8s Pool Nodes**: Add more nodes to the K8s pool
2. **Add VM Pool Nodes**: Add more nodes to the VM pool
3. **Monitor Usage**: Monitor resource usage across all pools
4. **Optimize Allocation**: Adjust resource allocations based on usage patterns

## API Reference

### K8s Pool Storage API

#### Get K8s Pool Storage Usage
```http
GET /api/v1/k8s-pool/storage/usage
```

Response:
```json
{
  "databases": {
    "used_gb": 120.5,
    "limit_gb": 500,
    "available_gb": 379.5,
    "usage_percentage": 24.1
  },
  "applications": {
    "used_gb": 250.3,
    "limit_gb": 1000,
    "available_gb": 749.7,
    "usage_percentage": 25.03
  },
  "total": {
    "used_gb": 450.8,
    "total_gb": 1800,
    "available_gb": 1349.2,
    "usage_percentage": 25.04
  }
}
```

### VM Pool Storage API

#### Get VM Pool Storage Usage
```http
GET /api/v1/vm-pool/storage/usage
```

Response:
```json
{
  "vm_images": {
    "used_gb": 200.5,
    "limit_gb": 500,
    "available_gb": 299.5,
    "usage_percentage": 40.1
  },
  "vm_instances": {
    "used_gb": 350.3,
    "limit_gb": 1000,
    "available_gb": 649.7,
    "usage_percentage": 35.03
  },
  "total": {
    "used_gb": 650.8,
    "total_gb": 1800,
    "available_gb": 1149.2,
    "usage_percentage": 36.16
  }
}
```

## Support

For issues and support:

1. Check the troubleshooting section above
2. Review logs for error messages
3. Run the test script to identify issues
4. Check resource pool isolation status
5. Contact the system administrator for complex issues

## Conclusion

This isolated resource pools configuration provides a robust, scalable solution for both Kubernetes and VM provisioning with complete isolation between the two resource pools. The system includes comprehensive monitoring, automatic cleanup, and management tools to ensure optimal performance and reliability while maintaining strict isolation between the pools.