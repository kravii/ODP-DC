# Resource Pool Variables
# Configuration for isolated K8s and VM resource pools

# Total Infrastructure
variable "total_baremetal_count" {
  description = "Total number of baremetal servers available"
  type        = number
  default     = 20
}

variable "storage_per_server_gb" {
  description = "Storage size per server in GB (1.8TB = 1800GB)"
  type        = number
  default     = 1800
}

# Resource Pool Sizes
variable "k8s_pool_size" {
  description = "Number of servers dedicated to Kubernetes pool"
  type        = number
  default     = 10
}

variable "vm_pool_size" {
  description = "Number of servers dedicated to VM pool"
  type        = number
  default     = 10
}

# K8s Pool Configuration
variable "k8s_control_plane_count" {
  description = "Number of K8s control plane nodes"
  type        = number
  default     = 3
}

variable "k8s_worker_count" {
  description = "Number of K8s worker nodes"
  type        = number
  default     = 7
}

variable "k8s_control_plane_ips" {
  description = "IP addresses of K8s control plane nodes"
  type        = list(string)
  default     = [
    "10.0.1.10", "10.0.1.11", "10.0.1.12"
  ]
}

variable "k8s_worker_ips" {
  description = "IP addresses of K8s worker nodes"
  type        = list(string)
  default     = [
    "10.0.1.20", "10.0.1.21", "10.0.1.22", 
    "10.0.1.23", "10.0.1.24", "10.0.1.25", "10.0.1.26"
  ]
}

variable "k8s_pod_cidr" {
  description = "CIDR block for K8s pod network"
  type        = string
  default     = "10.244.0.0/16"
}

variable "k8s_service_cidr" {
  description = "CIDR block for K8s service network"
  type        = string
  default     = "10.96.0.0/12"
}

variable "k8s_api_server_endpoint" {
  description = "K8s API server endpoint"
  type        = string
  default     = "k8s-api.hetzner-dc.local"
}

# VM Pool Configuration
variable "vm_server_ips" {
  description = "IP addresses of VM pool servers"
  type        = list(string)
  default     = [
    "10.0.2.10", "10.0.2.11", "10.0.2.12", "10.0.2.13", "10.0.2.14",
    "10.0.2.15", "10.0.2.16", "10.0.2.17", "10.0.2.18", "10.0.2.19"
  ]
}

variable "vm_ip_range" {
  description = "IP range for VMs"
  type        = string
  default     = "192.168.100.0/24"
}

variable "vm_api_endpoint" {
  description = "VM provisioning API endpoint"
  type        = string
  default     = "vm-api.hetzner-dc.local"
}

# K8s Pool Storage Allocations
variable "k8s_database_storage_gb" {
  description = "Storage allocation for K8s databases in GB"
  type        = number
  default     = 500
}

variable "k8s_app_storage_gb" {
  description = "Storage allocation for K8s applications in GB"
  type        = number
  default     = 1000
}

variable "k8s_monitoring_storage_gb" {
  description = "Storage allocation for K8s monitoring in GB"
  type        = number
  default     = 200
}

variable "k8s_log_storage_gb" {
  description = "Storage allocation for K8s logs in GB"
  type        = number
  default     = 50
}

variable "k8s_backup_storage_gb" {
  description = "Storage allocation for K8s backups in GB"
  type        = number
  default     = 50
}

# VM Pool Storage Allocations
variable "vm_image_storage_gb" {
  description = "Storage allocation for VM images in GB"
  type        = number
  default     = 500
}

variable "vm_template_storage_gb" {
  description = "Storage allocation for VM templates in GB"
  type        = number
  default     = 200
}

variable "vm_instance_storage_gb" {
  description = "Storage allocation for VM instances in GB"
  type        = number
  default     = 1000
}

variable "vm_snapshot_storage_gb" {
  description = "Storage allocation for VM snapshots in GB"
  type        = number
  default     = 50
}

variable "vm_backup_storage_gb" {
  description = "Storage allocation for VM backups in GB"
  type        = number
  default     = 50
}

# Resource Pool Isolation
variable "resource_pool_isolation_enabled" {
  description = "Enable strict resource pool isolation"
  type        = bool
  default     = true
}

variable "network_isolation_enabled" {
  description = "Enable network isolation between pools"
  type        = bool
  default     = true
}

variable "storage_isolation_enabled" {
  description = "Enable storage isolation between pools"
  type        = bool
  default     = true
}

# Pool Management
variable "k8s_pool_auto_scaling_enabled" {
  description = "Enable auto-scaling for K8s pool"
  type        = bool
  default     = false
}

variable "vm_pool_auto_scaling_enabled" {
  description = "Enable auto-scaling for VM pool"
  type        = bool
  default     = false
}

variable "pool_monitoring_enabled" {
  description = "Enable monitoring for resource pools"
  type        = bool
  default     = true
}

variable "pool_backup_enabled" {
  description = "Enable backup for resource pools"
  type        = bool
  default     = true
}

# Security
variable "pool_security_groups" {
  description = "Security groups for resource pools"
  type = map(object({
    k8s_pool = list(string)
    vm_pool  = list(string)
  }))
  default = {
    k8s_pool = ["k8s-control-plane", "k8s-worker"]
    vm_pool  = ["vm-host"]
  }
}

variable "pool_firewall_rules" {
  description = "Firewall rules for resource pools"
  type = map(object({
    k8s_pool = list(object({
      port     = number
      protocol = string
      source   = string
    }))
    vm_pool = list(object({
      port     = number
      protocol = string
      source   = string
    }))
  }))
  default = {
    k8s_pool = [
      { port = 6443, protocol = "tcp", source = "0.0.0.0/0" },
      { port = 2379, protocol = "tcp", source = "10.0.1.0/24" },
      { port = 2380, protocol = "tcp", source = "10.0.1.0/24" }
    ]
    vm_pool = [
      { port = 8080, protocol = "tcp", source = "0.0.0.0/0" },
      { port = 22, protocol = "tcp", source = "0.0.0.0/0" }
    ]
  }
}