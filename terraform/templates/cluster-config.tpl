---
# Kubernetes Cluster Configuration
cluster_name: "${cluster_name}"
api_server_endpoint: "${api_server_endpoint}"
pod_cidr: "${pod_cidr}"
service_cidr: "${service_cidr}"

# SSH Configuration
ssh_user: "${ssh_user}"
ssh_port: ${ssh_port}
ssh_private_key_path: "${ssh_private_key_path}"

# Control Plane Configuration
control_plane_nodes:
%{ for i, ip in control_plane_ips ~}
  - name: "${cluster_name}-cp-${i + 1}"
    ip: "${ip}"
    role: "control-plane"
    os_type: "rocky_linux_9"
%{ endfor ~}

# Worker Nodes Configuration
worker_nodes:
%{ for i, ip in worker_ips ~}
  - name: "${cluster_name}-worker-${i + 1}"
    ip: "${ip}"
    role: "worker"
    os_type: "rocky_linux_9"
%{ endfor ~}

# Cluster Settings
kubernetes_version: "1.28.0"
container_runtime: "containerd"
cni_plugin: "flannel"
storage_class: "local-path"

# Rocky Linux 9 Specific Configuration
os_config:
  os_type: "rocky_linux_9"
  package_manager: "dnf"
  firewall_service: "firewalld"
  network_manager: "NetworkManager"

# Monitoring Configuration
monitoring_enabled: true
prometheus_retention: "30d"
grafana_admin_user: "admin"
grafana_admin_password: "admin123"

# Rancher Configuration
rancher_enabled: true
rancher_version: "2.7.5"
rancher_admin_password: "admin123"

# VM Configuration
vm_max_count: 300
vm_ip_range: "192.168.100.0/24"
vm_default_user: "acceldata"

# Notification Configuration
slack_webhook_url: ""
jira_webhook_url: ""
jira_project_key: "DC"