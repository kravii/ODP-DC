# VM Pool Storage Configuration
# Dedicated storage configuration for VM resource pool

cluster_name: ${cluster_name}
storage:
  pool_name: "vm"
  isolation_enabled: true
  
  # Storage Configuration
  total_storage_gb: ${total_storage}
  storage_per_server_gb: ${storage_per_server}
  
  # Server Storage Configuration
  servers:
%{ for server in vm_pool_servers ~}
    - name: ${server.name}
      ip: ${server.ip}
      role: ${server.role}
      pool: ${server.pool}
      storage_size_gb: ${server.storage_size}
      storage_path: "/vm-storage"
%{ endfor ~}
  
  # Storage Allocations
  allocations:
    vm_images:
      size_gb: ${storage_allocations.vm_images}
      path: "/vm-storage/images"
      description: "Base VM images"
    
    vm_templates:
      size_gb: ${storage_allocations.vm_templates}
      path: "/vm-storage/templates"
      description: "VM templates"
    
    vm_instances:
      size_gb: ${storage_allocations.vm_instances}
      path: "/vm-storage/instances"
      description: "VM instance disks"
    
    vm_snapshots:
      size_gb: ${storage_allocations.vm_snapshots}
      path: "/vm-storage/snapshots"
      description: "VM snapshots"
    
    vm_backups:
      size_gb: ${storage_allocations.vm_backups}
      path: "/vm-storage/backups"
      description: "VM backups"
  
  # VM Storage Configuration
  vm_storage:
    image_format: "qcow2"
    compression_enabled: true
    thin_provisioning: true
    snapshot_enabled: true
    
    # VM Templates
    templates:
      - name: "ubuntu22"
        path: "/vm-storage/templates/ubuntu22.qcow2"
        size_gb: 20
      - name: "centos7"
        path: "/vm-storage/templates/centos7.qcow2"
        size_gb: 20
      - name: "rhel8"
        path: "/vm-storage/templates/rhel8.qcow2"
        size_gb: 20
      - name: "rockylinux9"
        path: "/vm-storage/templates/rockylinux9.qcow2"
        size_gb: 20
  
  # Storage Monitoring
  monitoring:
    enabled: true
    check_interval: 300
    warning_threshold: 75
    critical_threshold: 90
  
  # Storage Cleanup
  cleanup:
    enabled: true
    schedule: "0 3 * * *"  # Daily at 3 AM
    retention_days: 30
    snapshot_retention_days: 90
  
  # Storage Isolation
  isolation:
    enabled: true
    deny_cross_pool_access: true
    k8s_pool_blocked: true
  
  # VM Storage Management
  vm_management:
    max_vm_count: 300
    default_vm_size_gb: 50
    max_vm_size_gb: 500
    auto_cleanup_enabled: true
    auto_snapshot_enabled: true
    snapshot_schedule: "0 1 * * *"  # Daily at 1 AM