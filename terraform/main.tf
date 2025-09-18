terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.0"
    }
  }
}

# Data source for existing baremetal servers
# This assumes servers are already provisioned and accessible
locals {
  # Define your existing baremetal servers here
  control_plane_servers = [
    {
      name = "${var.cluster_name}-cp-1"
      ip   = var.control_plane_ips[0]
      role = "control-plane"
    },
    {
      name = "${var.cluster_name}-cp-2"
      ip   = var.control_plane_ips[1]
      role = "control-plane"
    },
    {
      name = "${var.cluster_name}-cp-3"
      ip   = var.control_plane_ips[2]
      role = "control-plane"
    }
  ]
  
  worker_servers = [
    for i in range(var.worker_node_count) : {
      name = "${var.cluster_name}-worker-${i + 1}"
      ip   = var.worker_node_ips[i]
      role = "worker"
    }
  ]
  
  all_servers = concat(local.control_plane_servers, local.worker_servers)
}

# Generate SSH key pair for cluster management
resource "tls_private_key" "cluster_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key to local file
resource "local_file" "cluster_private_key" {
  content  = tls_private_key.cluster_ssh_key.private_key_pem
  filename = "${path.module}/../ansible/ssh_keys/${var.cluster_name}-cluster-key.pem"
  file_permission = "0600"
}

resource "local_file" "cluster_public_key" {
  content  = tls_private_key.cluster_ssh_key.public_key_openssh
  filename = "${path.module}/../ansible/ssh_keys/${var.cluster_name}-cluster-key.pub"
}

# Create load balancer configuration for API server
resource "local_file" "load_balancer_config" {
  content = templatefile("${path.module}/templates/load-balancer-config.tpl", {
    cluster_name        = var.cluster_name
    control_plane_ips   = var.control_plane_ips
    api_server_port     = 6443
  })
  filename = "${path.module}/../ansible/group_vars/all/load-balancer.yml"
}

# Generate Ansible inventory
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    cluster_name        = var.cluster_name
    control_plane_ips   = hcloud_server.control_plane[*].ipv4_address
    worker_ips          = hcloud_server.worker_nodes[*].ipv4_address
    api_server_endpoint = hcloud_load_balancer.api_server.ipv4
  })
  filename = "${path.module}/../ansible/inventory/hosts.yml"
}

# Generate cluster configuration
resource "local_file" "cluster_config" {
  content = templatefile("${path.module}/templates/cluster-config.tpl", {
    cluster_name        = var.cluster_name
    api_server_endpoint = hcloud_load_balancer.api_server.ipv4
    pod_cidr           = var.pod_cidr
    service_cidr       = var.service_cidr
    control_plane_ips  = hcloud_server.control_plane[*].ipv4_address
    worker_ips         = hcloud_server.worker_nodes[*].ipv4_address
  })
  filename = "${path.module}/../ansible/group_vars/all/cluster-config.yml"
}