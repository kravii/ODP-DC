# VM Pool Network Configuration
# Isolated network configuration for VM resource pool

cluster_name: ${cluster_name}
network:
  pool_name: "vm"
  isolation_enabled: true
  
  # VM Pool Network Settings
  vm_ip_range: "${vm_ip_range}"
  management_network: "10.0.2.0/24"
  
  # Server Network Configuration
  servers:
%{ for server in vm_pool_servers ~}
    - name: ${server.name}
      ip: ${server.ip}
      role: ${server.role}
      pool: ${server.pool}
      storage_size_gb: ${server.storage_size}
%{ endfor ~}
  
  # Network Isolation Rules
  isolation_rules:
    - name: "vm-pool-isolation"
      description: "Isolate VM pool from K8s pool"
      enabled: true
      rules:
        - action: "ALLOW"
          source: "10.0.2.0/24"
          destination: "10.0.2.0/24"
          protocol: "all"
        - action: "DENY"
          source: "10.0.1.0/24"
          destination: "10.0.2.0/24"
          protocol: "all"
        - action: "DENY"
          source: "10.0.2.0/24"
          destination: "10.0.1.0/24"
          protocol: "all"
        - action: "ALLOW"
          source: "192.168.100.0/24"
          destination: "10.0.2.0/24"
          protocol: "tcp"
          port: 22
  
  # Load Balancer Configuration
  load_balancer:
    enabled: true
    type: "haproxy"
    backend_servers:
%{ for server in vm_pool_servers ~}
      - ip: ${server.ip}
        port: 8080
        weight: 1
%{ endfor ~}
  
  # DNS Configuration
  dns:
    enabled: true
    domain: "vm.hetzner-dc.local"
    records:
      - name: "api"
        type: "A"
        value: "10.0.2.100"
      - name: "*.vm"
        type: "A"
        value: "10.0.2.100"
  
  # VM Network Configuration
  vm_networks:
    - name: "vm-management"
      cidr: "192.168.100.0/24"
      gateway: "192.168.100.1"
      dns_servers: ["8.8.8.8", "8.8.4.4"]
    - name: "vm-isolated"
      cidr: "192.168.101.0/24"
      gateway: "192.168.101.1"
      dns_servers: ["8.8.8.8", "8.8.4.4"]
  
  # Storage Network
  storage_network:
    enabled: true
    total_storage_gb: ${vm_storage_total}
    network_storage_enabled: false  # Local storage only for isolation
    storage_isolation_enabled: true