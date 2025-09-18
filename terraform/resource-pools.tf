# Resource Pool Isolation Configuration
# Separates baremetal servers into dedicated K8s and VM pools

# Data source for existing baremetal servers
locals {
  # Total baremetal servers available
  total_baremetal_servers = var.total_baremetal_count
  
  # Split servers between K8s and VM pools
  k8s_pool_size = var.k8s_pool_size
  vm_pool_size = var.vm_pool_size
  
  # Validate pool sizes
  k8s_pool_size_valid = local.k8s_pool_size <= local.total_baremetal_servers
  vm_pool_size_valid = local.vm_pool_size <= local.total_baremetal_servers
  total_pool_size_valid = (local.k8s_pool_size + local.vm_pool_size) <= local.total_baremetal_servers
  
  # K8s Pool Configuration
  k8s_control_plane_servers = [
    for i in range(var.k8s_control_plane_count) : {
      name = "${var.cluster_name}-k8s-cp-${i + 1}"
      ip   = var.k8s_control_plane_ips[i]
      role = "k8s-control-plane"
      pool = "k8s"
      storage_size = var.storage_per_server_gb
    }
  ]
  
  k8s_worker_servers = [
    for i in range(var.k8s_worker_count) : {
      name = "${var.cluster_name}-k8s-worker-${i + 1}"
      ip   = var.k8s_worker_ips[i]
      role = "k8s-worker"
      pool = "k8s"
      storage_size = var.storage_per_server_gb
    }
  ]
  
  # VM Pool Configuration
  vm_servers = [
    for i in range(var.vm_pool_size) : {
      name = "${var.cluster_name}-vm-${i + 1}"
      ip   = var.vm_server_ips[i]
      role = "vm-host"
      pool = "vm"
      storage_size = var.storage_per_server_gb
    }
  ]
  
  # All servers grouped by pool
  k8s_pool_servers = concat(local.k8s_control_plane_servers, local.k8s_worker_servers)
  all_k8s_servers = local.k8s_pool_servers
  all_vm_servers = local.vm_servers
  
  # Storage allocation per pool
  k8s_pool_storage_total = length(local.k8s_pool_servers) * var.storage_per_server_gb
  vm_pool_storage_total = length(local.vm_servers) * var.storage_per_server_gb
}

# Validation rules
resource "null_resource" "validate_pool_sizes" {
  count = local.k8s_pool_size_valid && local.vm_pool_size_valid && local.total_pool_size_valid ? 1 : 0
  
  provisioner "local-exec" {
    command = "echo 'Resource pool sizes validated successfully'"
  }
}

# K8s Pool Network Configuration
resource "local_file" "k8s_pool_network_config" {
  content = templatefile("${path.module}/templates/k8s-pool-network.tpl", {
    cluster_name = var.cluster_name
    k8s_pool_servers = local.k8s_pool_servers
    k8s_pod_cidr = var.k8s_pod_cidr
    k8s_service_cidr = var.k8s_service_cidr
    k8s_storage_total = local.k8s_pool_storage_total
  })
  filename = "${path.module}/../ansible/group_vars/k8s_pool/network-config.yml"
}

# VM Pool Network Configuration
resource "local_file" "vm_pool_network_config" {
  content = templatefile("${path.module}/templates/vm-pool-network.tpl", {
    cluster_name = var.cluster_name
    vm_pool_servers = local.vm_servers
    vm_ip_range = var.vm_ip_range
    vm_storage_total = local.vm_pool_storage_total
  })
  filename = "${path.module}/../ansible/group_vars/vm_pool/network-config.yml"
}

# K8s Pool Storage Configuration
resource "local_file" "k8s_pool_storage_config" {
  content = templatefile("${path.module}/templates/k8s-pool-storage.tpl", {
    cluster_name = var.cluster_name
    k8s_pool_servers = local.k8s_pool_servers
    storage_per_server = var.storage_per_server_gb
    total_storage = local.k8s_pool_storage_total
    storage_allocations = {
      databases = var.k8s_database_storage_gb
      applications = var.k8s_app_storage_gb
      monitoring = var.k8s_monitoring_storage_gb
      logs = var.k8s_log_storage_gb
      backups = var.k8s_backup_storage_gb
    }
  })
  filename = "${path.module}/../ansible/group_vars/k8s_pool/storage-config.yml"
}

# VM Pool Storage Configuration
resource "local_file" "vm_pool_storage_config" {
  content = templatefile("${path.module}/templates/vm-pool-storage.tpl", {
    cluster_name = var.cluster_name
    vm_pool_servers = local.vm_servers
    storage_per_server = var.storage_per_server_gb
    total_storage = local.vm_pool_storage_total
    storage_allocations = {
      vm_images = var.vm_image_storage_gb
      vm_templates = var.vm_template_storage_gb
      vm_instances = var.vm_instance_storage_gb
      vm_snapshots = var.vm_snapshot_storage_gb
      vm_backups = var.vm_backup_storage_gb
    }
  })
  filename = "${path.module}/../ansible/group_vars/vm_pool/storage-config.yml"
}

# Generate K8s Pool Ansible Inventory
resource "local_file" "k8s_pool_inventory" {
  content = templatefile("${path.module}/templates/k8s-pool-inventory.tpl", {
    cluster_name = var.cluster_name
    k8s_control_plane_servers = local.k8s_control_plane_servers
    k8s_worker_servers = local.k8s_worker_servers
    k8s_api_server_endpoint = var.k8s_api_server_endpoint
  })
  filename = "${path.module}/../ansible/inventory/k8s_pool_hosts.yml"
}

# Generate VM Pool Ansible Inventory
resource "local_file" "vm_pool_inventory" {
  content = templatefile("${path.module}/templates/vm-pool-inventory.tpl", {
    cluster_name = var.cluster_name
    vm_servers = local.vm_servers
    vm_api_endpoint = var.vm_api_endpoint
  })
  filename = "${path.module}/../ansible/inventory/vm_pool_hosts.yml"
}

# K8s Pool Load Balancer Configuration
resource "local_file" "k8s_pool_load_balancer_config" {
  content = templatefile("${path.module}/templates/k8s-pool-load-balancer.tpl", {
    cluster_name = var.cluster_name
    k8s_control_plane_ips = [for server in local.k8s_control_plane_servers : server.ip]
    api_server_port = 6443
  })
  filename = "${path.module}/../ansible/group_vars/k8s_pool/load-balancer.yml"
}

# VM Pool Load Balancer Configuration
resource "local_file" "vm_pool_load_balancer_config" {
  content = templatefile("${path.module}/templates/vm-pool-load-balancer.tpl", {
    cluster_name = var.cluster_name
    vm_server_ips = [for server in local.vm_servers : server.ip]
    vm_api_port = 8080
  })
  filename = "${path.module}/../ansible/group_vars/vm_pool/load-balancer.yml"
}

# Resource Pool Isolation Rules
resource "local_file" "resource_pool_isolation_rules" {
  content = templatefile("${path.module}/templates/resource-pool-isolation.tpl", {
    cluster_name = var.cluster_name
    k8s_pool_servers = local.k8s_pool_servers
    vm_pool_servers = local.vm_servers
    isolation_enabled = var.resource_pool_isolation_enabled
  })
  filename = "${path.module}/../ansible/group_vars/all/resource-pool-isolation.yml"
}

# Output resource pool information
output "k8s_pool_info" {
  description = "K8s pool configuration"
  value = {
    pool_name = "k8s"
    server_count = length(local.k8s_pool_servers)
    control_plane_count = length(local.k8s_control_plane_servers)
    worker_count = length(local.k8s_worker_servers)
    total_storage_gb = local.k8s_pool_storage_total
    servers = local.k8s_pool_servers
  }
}

output "vm_pool_info" {
  description = "VM pool configuration"
  value = {
    pool_name = "vm"
    server_count = length(local.vm_servers)
    total_storage_gb = local.vm_pool_storage_total
    servers = local.vm_servers
  }
}

output "resource_pool_summary" {
  description = "Resource pool summary"
  value = {
    total_baremetal_servers = local.total_baremetal_servers
    k8s_pool_servers = length(local.k8s_pool_servers)
    vm_pool_servers = length(local.vm_servers)
    k8s_pool_storage_gb = local.k8s_pool_storage_total
    vm_pool_storage_gb = local.vm_pool_storage_total
    isolation_enabled = var.resource_pool_isolation_enabled
  }
}