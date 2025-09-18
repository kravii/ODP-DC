variable "hetzner_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "hetzner_region" {
  description = "Hetzner Cloud region"
  type        = string
  default     = "fsn1"
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "hetzner-dc-cluster"
}

variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 3
}

variable "control_plane_type" {
  description = "Server type for control plane nodes"
  type        = string
  default     = "cx31"
}

variable "control_plane_image" {
  description = "OS image for control plane nodes"
  type        = string
  default     = "ubuntu-22.04"
}

variable "control_plane_disk_size" {
  description = "Additional disk size for control plane nodes (GB)"
  type        = number
  default     = 40
}

variable "worker_node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "worker_node_type" {
  description = "Server type for worker nodes"
  type        = string
  default     = "cx41"
}

variable "worker_node_image" {
  description = "OS image for worker nodes"
  type        = string
  default     = "ubuntu-22.04"
}

variable "worker_node_disk_size" {
  description = "Additional disk size for worker nodes (GB)"
  type        = number
  default     = 80
}

variable "pod_cidr" {
  description = "CIDR block for pod network"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "CIDR block for service network"
  type        = string
  default     = "10.96.0.0/12"
}

variable "max_baremetal_count" {
  description = "Maximum number of baremetal servers supported"
  type        = number
  default     = 200
}

variable "max_vm_count" {
  description = "Maximum number of VMs supported"
  type        = number
  default     = 300
}

variable "vm_ip_range" {
  description = "IP range for VMs"
  type        = string
  default     = "192.168.100.0/24"
}

variable "default_vm_user" {
  description = "Default user for VMs"
  type        = string
  default     = "acceldata"
}

variable "storage_pool_size" {
  description = "Total storage pool size in GB"
  type        = number
  default     = 1000
}

variable "monitoring_enabled" {
  description = "Enable monitoring stack"
  type        = bool
  default     = true
}

variable "rancher_enabled" {
  description = "Enable Rancher management"
  type        = bool
  default     = true
}

variable "rancher_version" {
  description = "Rancher version to install"
  type        = string
  default     = "2.7.5"
}

variable "notification_webhook_url" {
  description = "Webhook URL for notifications"
  type        = string
  default     = ""
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for alerts"
  type        = string
  default     = ""
}

variable "jira_webhook_url" {
  description = "JIRA webhook URL for incidents"
  type        = string
  default     = ""
}

variable "jira_project_key" {
  description = "JIRA project key for incidents"
  type        = string
  default     = "DC"
}