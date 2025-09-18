output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

output "control_plane_ips" {
  description = "IP addresses of control plane nodes"
  value       = var.control_plane_ips
}

output "worker_node_ips" {
  description = "IP addresses of worker nodes"
  value       = var.worker_node_ips
}

output "api_server_endpoint" {
  description = "API server endpoint (first control plane node)"
  value       = var.control_plane_ips[0]
}

output "cluster_ssh_private_key_path" {
  description = "Path to the cluster SSH private key"
  value       = local_file.cluster_private_key.filename
}

output "cluster_ssh_public_key_path" {
  description = "Path to the cluster SSH public key"
  value       = local_file.cluster_public_key.filename
}

output "ansible_inventory_path" {
  description = "Path to the generated Ansible inventory"
  value       = local_file.ansible_inventory.filename
}

output "cluster_config_path" {
  description = "Path to the cluster configuration"
  value       = local_file.cluster_config.filename
}

output "control_plane_names" {
  description = "Names of control plane nodes"
  value       = [for server in local.control_plane_servers : server.name]
}

output "worker_node_names" {
  description = "Names of worker nodes"
  value       = [for server in local.worker_servers : server.name]
}

output "total_nodes" {
  description = "Total number of nodes in the cluster"
  value       = var.control_plane_count + var.worker_node_count
}

output "cluster_info" {
  description = "Complete cluster information"
  value = {
    name                = var.cluster_name
    api_endpoint        = var.control_plane_ips[0]
    control_plane_count = var.control_plane_count
    worker_count        = var.worker_node_count
    total_nodes         = var.control_plane_count + var.worker_node_count
    pod_cidr           = var.pod_cidr
    service_cidr       = var.service_cidr
    ssh_user           = var.ssh_user
    ssh_port           = var.ssh_port
  }
}