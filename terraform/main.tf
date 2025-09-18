terraform {
  required_version = ">= 1.5.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.42.0"
    }
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

# Configure the Hetzner Cloud Provider
provider "hcloud" {
  token = var.hetzner_token
}

# Generate SSH key pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "hcloud_ssh_key" "default" {
  name       = "${var.cluster_name}-ssh-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Save private key to local file
resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "${path.module}/../ansible/ssh_keys/${var.cluster_name}-private-key.pem"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "${path.module}/../ansible/ssh_keys/${var.cluster_name}-public-key.pub"
}

# Control Plane Nodes
resource "hcloud_server" "control_plane" {
  count       = var.control_plane_count
  name        = "${var.cluster_name}-cp-${count.index + 1}"
  image       = var.control_plane_image
  server_type = var.control_plane_type
  location    = var.hetzner_region
  ssh_keys    = [hcloud_ssh_key.default.id]
  
  labels = {
    role = "control-plane"
    node = "cp-${count.index + 1}"
  }

  # Additional disk for data
  additional_volumes = [hcloud_volume.control_plane_data[count.index].id]

  user_data = templatefile("${path.module}/templates/control-plane-userdata.yaml", {
    cluster_name = var.cluster_name
    node_index   = count.index + 1
    pod_cidr     = var.pod_cidr
    service_cidr = var.service_cidr
  })
}

# Control Plane Data Volumes
resource "hcloud_volume" "control_plane_data" {
  count    = var.control_plane_count
  name     = "${var.cluster_name}-cp-data-${count.index + 1}"
  size     = var.control_plane_disk_size
  location = var.hetzner_region
}

# Worker Nodes
resource "hcloud_server" "worker_nodes" {
  count       = var.worker_node_count
  name        = "${var.cluster_name}-worker-${count.index + 1}"
  image       = var.worker_node_image
  server_type = var.worker_node_type
  location    = var.hetzner_region
  ssh_keys    = [hcloud_ssh_key.default.id]
  
  labels = {
    role = "worker"
    node = "worker-${count.index + 1}"
  }

  # Additional disk for data
  additional_volumes = [hcloud_volume.worker_data[count.index].id]

  user_data = templatefile("${path.module}/templates/worker-userdata.yaml", {
    cluster_name = var.cluster_name
    node_index   = count.index + 1
    pod_cidr     = var.pod_cidr
    service_cidr = var.service_cidr
  })
}

# Worker Data Volumes
resource "hcloud_volume" "worker_data" {
  count    = var.worker_node_count
  name     = "${var.cluster_name}-worker-data-${count.index + 1}"
  size     = var.worker_node_disk_size
  location = var.hetzner_region
}

# Load Balancer for API Server
resource "hcloud_load_balancer" "api_server" {
  name     = "${var.cluster_name}-api-lb"
  load_balancer_type = "lb11"
  location = var.hetzner_region
  
  labels = {
    role = "api-server-lb"
  }
}

resource "hcloud_load_balancer_target" "api_server_targets" {
  count            = var.control_plane_count
  type             = "server"
  load_balancer_id = hcloud_load_balancer.api_server.id
  server_id        = hcloud_server.control_plane[count.index].id
}

resource "hcloud_load_balancer_service" "api_server_service" {
  load_balancer_id = hcloud_load_balancer.api_server.id
  protocol         = "tcp"
  listen_port      = 6443
  destination_port = 6443
  health_check {
    protocol = "tcp"
    port     = 6443
  }
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