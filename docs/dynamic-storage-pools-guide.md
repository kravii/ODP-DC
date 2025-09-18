# Dynamic Storage Pools Guide

This guide explains how to deploy and manage dynamic storage pools where each server contributes 1.5TB to its assigned pool (K8s or VM), with automatic scaling as servers are added or removed.

## Overview

The dynamic storage pools system uses a **pool-based approach** where:

- **K8s Pool**: Each K8s server contributes 1.5TB to the K8s storage pool
- **VM Pool**: Each VM server contributes 1.5TB to the VM storage pool
- **Dynamic Scaling**: Storage pools automatically grow/shrink as servers are added/removed
- **No Subdivision**: Each server's entire 1.5TB goes to its assigned pool

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Dynamic Storage Pools                    │
└─────────────────────────────────────────────────────────────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
        ┌───────▼───────┐ ┌─────▼─────┐ ┌──────▼──────┐
        │ K8s Pool      │ │ VM Pool   │ │ System     │
        │ (1.5TB/server)│ │ (1.5TB/server)│ │ Reserve   │
        │               │ │           │ │ (300GB/server)│
        │ Server 1: 1.5TB│ │ Server 1: 1.5TB│ │ Server 1: 300GB│
        │ Server 2: 1.5TB│ │ Server 2: 1.5TB│ │ Server 2: 300GB│
        │ Server 3: 1.5TB│ │ Server 3: 1.5TB│ │ Server 3: 300GB│
        │ ...           │ │ ...       │ │ ...        │
        │ Total: N×1.5TB│ │ Total: M×1.5TB│ │ Total: (N+M)×300GB│
        └───────────────┘ └───────────┘ └─────────────┘
```

## Dynamic Pool Scaling

### Adding Servers
- **Add server to K8s pool** → +1.5TB to K8s pool
- **Add server to VM pool** → +1.5TB to VM pool
- **Pool capacity automatically updates**

### Removing Servers
- **Remove server from K8s pool** → -1.5TB from K8s pool
- **Remove server from VM pool** → -1.5TB from VM pool
- **Pool capacity automatically updates**

### Pool Capacity Calculation
```
K8s Pool Capacity = (Number of K8s servers) × 1.5TB
VM Pool Capacity = (Number of VM servers) × 1.5TB
Total System Reserve = (Total servers) × 300GB
```

## Prerequisites

- Kubernetes cluster with at least 2 nodes
- kubectl configured and connected to the cluster
- Root access to all nodes
- 1.8TB storage per server (1.5TB for pool + 300GB system reserve)

## Deployment

### 1. Deploy Dynamic Storage Pools

```bash
# Make deployment script executable
chmod +x scripts/deploy-dynamic-storage-pools.sh

# Deploy the dynamic storage pools
./scripts/deploy-dynamic-storage-pools.sh
```

This script will:
- Label nodes for K8s and VM pools
- Set up dynamic storage pool directories
- Deploy K8s pool provisioner
- Deploy VM pool storage manager
- Deploy pool monitoring and scaling
- Verify the deployment

### 2. Verify Deployment

```bash
# Make test script executable
chmod +x scripts/test-dynamic-storage-pools.sh

# Run comprehensive tests
./scripts/test-dynamic-storage-pools.sh
```

## Storage Classes

### k8s-pool-storage (Default)
- **Purpose**: Kubernetes persistent volumes
- **Reclaim Policy**: Delete
- **Binding Mode**: WaitForFirstConsumer
- **Pool**: K8s pool (1.5TB per server)
- **Path**: `/k8s-storage-pool`

### vm-pool-storage
- **Purpose**: VM disk images
- **Reclaim Policy**: Retain
- **Binding Mode**: WaitForFirstConsumer
- **Pool**: VM pool (1.5TB per server)
- **Path**: `/vm-storage-pool`

## Usage Examples

### Creating K8s Persistent Volumes

```yaml
# Use K8s pool storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: k8s-pool-storage
  resources:
    requests:
      storage: 100Gi
```

### Creating VMs

```bash
# Create a VM using the VM pool API
curl -X POST http://vm-pool-api.dynamic-storage-pools.svc.cluster.local:8080/api/v1/vms \
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

## Pool Management

### Adding Servers to Pools

```bash
# Add server to K8s pool
kubectl label node <node-name> pool=k8s

# Add server to VM pool
kubectl label node <node-name> pool=vm
```

### Removing Servers from Pools

```bash
# Remove server from pool
kubectl label node <node-name> pool-
```

### Checking Pool Status

```bash
# Check current pool status
kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- /k8s-storage-pool/monitor-pools.sh

# Check K8s pool usage
kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- du -sh /k8s-storage-pool

# Check VM pool usage
kubectl exec -n dynamic-storage-pools daemonset/vm-pool-storage-manager -- du -sh /vm-storage-pool
```

## Monitoring

### Pool Capacity Monitoring

```bash
# Get detailed pool status
kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- /k8s-storage-pool/monitor-pools.sh

# Check pool scaling controller
kubectl get pods -n dynamic-storage-pools -l app=pool-scaling-controller

# Check pool status in configmap
kubectl get configmap dynamic-storage-config -n dynamic-storage-pools -o yaml | grep -A 5 "pool-status"
```

### Pool Health Monitoring

The system automatically monitors pool health and generates alerts:

- **Warning**: Pool usage > 75% of capacity
- **Critical**: Pool usage > 90% of capacity

### Pool Scaling Monitoring

```bash
# Check current pool capacities
kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- /k8s-storage-pool/monitor-pools.sh

# Check pool scaling controller logs
kubectl logs -n dynamic-storage-pools -l app=pool-scaling-controller
```

## Maintenance

### Automatic Cleanup

The system includes automatic cleanup jobs:

- **Pool Cleanup**: Daily at 2 AM
- **K8s Pool Cleanup**: Temporary files, old logs
- **VM Pool Cleanup**: Orphaned files, old VM images

### Manual Cleanup

```bash
# Run pool cleanup manually
kubectl create job --from=cronjob/pool-cleanup pool-cleanup-manual -n dynamic-storage-pools

# Check cleanup job status
kubectl get jobs -n dynamic-storage-pools
```

### Pool Optimization

```bash
# Optimize VM disk images
kubectl exec -n dynamic-storage-pools daemonset/vm-pool-storage-manager -- find /vm-storage-pool -name "*.qcow2" -exec qemu-img convert -O qcow2 -c {} {}.optimized \;

# Check pool usage after optimization
kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- /k8s-storage-pool/monitor-pools.sh
```

## Troubleshooting

### Common Issues

#### 1. Pool Capacity Issues
```bash
# Check pool capacity
kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- /k8s-storage-pool/monitor-pools.sh

# Check server count in each pool
kubectl get nodes -l pool=k8s --no-headers | wc -l
kubectl get nodes -l pool=vm --no-headers | wc -l
```

#### 2. Node Label Issues
```bash
# Check node labels
kubectl get nodes --show-labels | grep -E "(pool=k8s|pool=vm)"

# Fix node labels
kubectl label node <node-name> pool=k8s --overwrite
kubectl label node <node-name> pool=vm --overwrite
```

#### 3. Storage Class Issues
```bash
# Check storage classes
kubectl get storageclass | grep -E "(k8s-pool|vm-pool)"

# Check K8s pool provisioner
kubectl get pods -n dynamic-storage-pools -l app=k8s-pool-provisioner

# Check provisioner logs
kubectl logs -n dynamic-storage-pools -l app=k8s-pool-provisioner
```

#### 4. VM Pool Issues
```bash
# Check VM pool storage manager
kubectl get pods -n dynamic-storage-pools -l app=vm-pool-storage-manager

# Check VM templates
kubectl exec -n dynamic-storage-pools daemonset/vm-pool-storage-manager -- ls -la /vm-storage-pool/

# Check VM pool storage manager logs
kubectl logs -n dynamic-storage-pools -l app=vm-pool-storage-manager
```

### Logs

```bash
# K8s pool provisioner logs
kubectl logs -n dynamic-storage-pools -l app=k8s-pool-provisioner

# VM pool storage manager logs
kubectl logs -n dynamic-storage-pools -l app=vm-pool-storage-manager

# Dynamic pool monitor logs
kubectl logs -n dynamic-storage-pools -l app=dynamic-pool-monitor

# Pool scaling controller logs
kubectl logs -n dynamic-storage-pools -l app=pool-scaling-controller
```

## Pool Scaling Examples

### Example 1: Adding Servers

```bash
# Current status: 2 K8s servers, 2 VM servers
# K8s Pool: 2 × 1.5TB = 3TB
# VM Pool: 2 × 1.5TB = 3TB

# Add 1 server to K8s pool
kubectl label node new-k8s-server pool=k8s

# New status: 3 K8s servers, 2 VM servers
# K8s Pool: 3 × 1.5TB = 4.5TB (+1.5TB)
# VM Pool: 2 × 1.5TB = 3TB (unchanged)
```

### Example 2: Removing Servers

```bash
# Current status: 3 K8s servers, 2 VM servers
# K8s Pool: 3 × 1.5TB = 4.5TB
# VM Pool: 2 × 1.5TB = 3TB

# Remove 1 server from K8s pool
kubectl label node old-k8s-server pool-

# New status: 2 K8s servers, 2 VM servers
# K8s Pool: 2 × 1.5TB = 3TB (-1.5TB)
# VM Pool: 2 × 1.5TB = 3TB (unchanged)
```

### Example 3: Moving Servers Between Pools

```bash
# Current status: 2 K8s servers, 2 VM servers
# K8s Pool: 2 × 1.5TB = 3TB
# VM Pool: 2 × 1.5TB = 3TB

# Move 1 server from K8s pool to VM pool
kubectl label node server-1 pool=vm

# New status: 1 K8s server, 3 VM servers
# K8s Pool: 1 × 1.5TB = 1.5TB (-1.5TB)
# VM Pool: 3 × 1.5TB = 4.5TB (+1.5TB)
```

## Security Considerations

1. **Access Control**: Proper permissions for each pool
2. **Pool Isolation**: Separate pools for K8s and VM storage
3. **Monitoring**: Continuous monitoring of pool capacity
4. **Backup**: Regular backups of critical data
5. **Audit**: Comprehensive logging for all pool operations

## Performance Optimization

1. **Local Storage**: Each pool uses local storage for optimal performance
2. **Pool Management**: Proper pool sizing and monitoring
3. **Cleanup**: Regular cleanup to maintain performance
4. **Monitoring**: Real-time monitoring of pool usage
5. **Optimization**: Storage optimization and compression

## Scaling

The dynamic storage pools system is designed to scale horizontally:

1. **Add Servers**: Add more servers to increase pool capacity
2. **Monitor Pools**: Monitor pool usage across all servers
3. **Optimize Usage**: Optimize storage usage within pools
4. **Balance Load**: Distribute load across all servers

## API Reference

### Pool Management API

#### Get Pool Status
```http
GET /api/v1/pools/status
```

Response:
```json
{
  "k8s_pool": {
    "servers": 3,
    "total_capacity_gb": 4500,
    "used_capacity_gb": 1200,
    "available_capacity_gb": 3300,
    "usage_percentage": 26.67
  },
  "vm_pool": {
    "servers": 2,
    "total_capacity_gb": 3000,
    "used_capacity_gb": 800,
    "available_capacity_gb": 2200,
    "usage_percentage": 26.67
  },
  "system_reserve": {
    "total_servers": 5,
    "total_capacity_gb": 1500,
    "used_capacity_gb": 200,
    "available_capacity_gb": 1300,
    "usage_percentage": 13.33
  }
}
```

#### Get Pool Health
```http
GET /api/v1/pools/health
```

Response:
```json
{
  "status": "healthy",
  "pools": {
    "k8s_pool": "healthy",
    "vm_pool": "healthy"
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
POST /api/v1/vms/{vm_id}/resize
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
4. Check pool capacity and server counts
5. Contact the system administrator for complex issues

## Conclusion

This dynamic storage pools configuration provides a robust, scalable solution for both Kubernetes and VM provisioning using dynamic storage pools. Each server contributes 1.5TB to its assigned pool, with automatic scaling as servers are added or removed. The system includes comprehensive monitoring, automatic cleanup, and management tools to ensure optimal performance and reliability while maintaining proper pool isolation and capacity management.