output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

output "control_plane_ips" {
  description = "IP addresses of control plane nodes"
  value       = hcloud_server.control_plane[*].ipv4_address
}

output "worker_node_ips" {
  description = "IP addresses of worker nodes"
  value       = hcloud_server.worker_nodes[*].ipv4_address
}

output "api_server_endpoint" {
  description = "Load balancer endpoint for Kubernetes API server"
  value       = hcloud_load_balancer.api_server.ipv4
}

output "ssh_private_key_path" {
  description = "Path to the SSH private key"
  value       = local_file.private_key.filename
}

output "ssh_public_key_path" {
  description = "Path to the SSH public key"
  value       = local_file.public_key.filename
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
  value       = hcloud_server.control_plane[*].name
}

output "worker_node_names" {
  description = "Names of worker nodes"
  value       = hcloud_server.worker_nodes[*].name
}

output "total_nodes" {
  description = "Total number of nodes in the cluster"
  value       = var.control_plane_count + var.worker_node_count
}

output "cluster_info" {
  description = "Complete cluster information"
  value = {
    name                = var.cluster_name
    api_endpoint        = hcloud_load_balancer.api_server.ipv4
    control_plane_count = var.control_plane_count
    worker_count        = var.worker_node_count
    total_nodes         = var.control_plane_count + var.worker_node_count
    pod_cidr           = var.pod_cidr
    service_cidr       = var.service_cidr
  }
}