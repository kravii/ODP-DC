# K8s Pool Network Configuration
# Isolated network configuration for Kubernetes resource pool

cluster_name: ${cluster_name}
network:
  pool_name: "k8s"
  isolation_enabled: true
  
  # K8s Pool Network Settings
  pod_cidr: "${k8s_pod_cidr}"
  service_cidr: "${k8s_service_cidr}"
  
  # Server Network Configuration
  servers:
%{ for server in k8s_pool_servers ~}
    - name: ${server.name}
      ip: ${server.ip}
      role: ${server.role}
      pool: ${server.pool}
      storage_size_gb: ${server.storage_size}
%{ endfor ~}
  
  # Network Isolation Rules
  isolation_rules:
    - name: "k8s-pool-isolation"
      description: "Isolate K8s pool from VM pool"
      enabled: true
      rules:
        - action: "ALLOW"
          source: "10.0.1.0/24"
          destination: "10.0.1.0/24"
          protocol: "all"
        - action: "DENY"
          source: "10.0.2.0/24"
          destination: "10.0.1.0/24"
          protocol: "all"
        - action: "DENY"
          source: "10.0.1.0/24"
          destination: "10.0.2.0/24"
          protocol: "all"
  
  # Load Balancer Configuration
  load_balancer:
    enabled: true
    type: "haproxy"
    backend_servers:
%{ for server in k8s_pool_servers ~}
%{ if server.role == "k8s-control-plane" ~}
      - ip: ${server.ip}
        port: 6443
        weight: 1
%{ endif ~}
%{ endfor ~}
  
  # DNS Configuration
  dns:
    enabled: true
    domain: "k8s.hetzner-dc.local"
    records:
      - name: "api"
        type: "A"
        value: "10.0.1.100"
      - name: "*.k8s"
        type: "A"
        value: "10.0.1.100"
  
  # Storage Network
  storage_network:
    enabled: true
    total_storage_gb: ${k8s_storage_total}
    network_storage_enabled: false  # Local storage only for isolation
    storage_isolation_enabled: true