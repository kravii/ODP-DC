# K8s Pool Storage Configuration
# Dedicated storage configuration for Kubernetes resource pool

cluster_name: ${cluster_name}
storage:
  pool_name: "k8s"
  isolation_enabled: true
  
  # Storage Configuration
  total_storage_gb: ${total_storage}
  storage_per_server_gb: ${storage_per_server}
  
  # Server Storage Configuration
  servers:
%{ for server in k8s_pool_servers ~}
    - name: ${server.name}
      ip: ${server.ip}
      role: ${server.role}
      pool: ${server.pool}
      storage_size_gb: ${server.storage_size}
      storage_path: "/k8s-storage"
%{ endfor ~}
  
  # Storage Allocations
  allocations:
    databases:
      size_gb: ${storage_allocations.databases}
      path: "/k8s-storage/databases"
      storage_class: "k8s-database-storage"
      access_mode: "ReadWriteOnce"
    
    applications:
      size_gb: ${storage_allocations.applications}
      path: "/k8s-storage/applications"
      storage_class: "k8s-app-storage"
      access_mode: "ReadWriteOnce"
    
    monitoring:
      size_gb: ${storage_allocations.monitoring}
      path: "/k8s-storage/monitoring"
      storage_class: "k8s-monitoring-storage"
      access_mode: "ReadWriteOnce"
    
    logs:
      size_gb: ${storage_allocations.logs}
      path: "/k8s-storage/logs"
      storage_class: "k8s-log-storage"
      access_mode: "ReadWriteOnce"
    
    backups:
      size_gb: ${storage_allocations.backups}
      path: "/k8s-storage/backups"
      storage_class: "k8s-backup-storage"
      access_mode: "ReadWriteOnce"
  
  # Storage Classes
  storage_classes:
    - name: "k8s-database-storage"
      provisioner: "k8s.io/local-path"
      reclaim_policy: "Retain"
      volume_binding_mode: "WaitForFirstConsumer"
      parameters:
        path: "/k8s-storage/databases"
    
    - name: "k8s-app-storage"
      provisioner: "k8s.io/local-path"
      reclaim_policy: "Delete"
      volume_binding_mode: "WaitForFirstConsumer"
      parameters:
        path: "/k8s-storage/applications"
    
    - name: "k8s-monitoring-storage"
      provisioner: "k8s.io/local-path"
      reclaim_policy: "Retain"
      volume_binding_mode: "WaitForFirstConsumer"
      parameters:
        path: "/k8s-storage/monitoring"
    
    - name: "k8s-log-storage"
      provisioner: "k8s.io/local-path"
      reclaim_policy: "Delete"
      volume_binding_mode: "WaitForFirstConsumer"
      parameters:
        path: "/k8s-storage/logs"
    
    - name: "k8s-backup-storage"
      provisioner: "k8s.io/local-path"
      reclaim_policy: "Retain"
      volume_binding_mode: "WaitForFirstConsumer"
      parameters:
        path: "/k8s-storage/backups"
  
  # Storage Monitoring
  monitoring:
    enabled: true
    check_interval: 300
    warning_threshold: 75
    critical_threshold: 90
  
  # Storage Cleanup
  cleanup:
    enabled: true
    schedule: "0 2 * * *"  # Daily at 2 AM
    retention_days: 30
  
  # Storage Isolation
  isolation:
    enabled: true
    deny_cross_pool_access: true
    vm_pool_blocked: true