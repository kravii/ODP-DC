# Configuration Reference

This document provides detailed configuration options for the Hetzner DC & Kubernetes cluster setup.

## Table of Contents

1. [Environment Variables](#environment-variables)
2. [Terraform Configuration](#terraform-configuration)
3. [Ansible Configuration](#ansible-configuration)
4. [Kubernetes Configuration](#kubernetes-configuration)
5. [Monitoring Configuration](#monitoring-configuration)
6. [VM Provisioning Configuration](#vm-provisioning-configuration)
7. [Security Configuration](#security-configuration)

## Environment Variables

### Core Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `HETZNER_API_TOKEN` | Hetzner Cloud API token | - | Yes |
| `HETZNER_REGION` | Hetzner Cloud region | `fsn1` | No |
| `CLUSTER_NAME` | Name of the Kubernetes cluster | `hetzner-dc-cluster` | No |

### Kubernetes Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `K8S_VERSION` | Kubernetes version | `1.28.0` | No |
| `K8S_POD_CIDR` | Pod network CIDR | `10.244.0.0/16` | No |
| `K8S_SERVICE_CIDR` | Service network CIDR | `10.96.0.0/12` | No |
| `CONTROL_PLANE_COUNT` | Number of control plane nodes | `3` | No |
| `CONTROL_PLANE_TYPE` | Server type for control plane | `cx31` | No |
| `WORKER_NODE_COUNT` | Number of worker nodes | `3` | No |
| `WORKER_NODE_TYPE` | Server type for worker nodes | `cx41` | No |

### VM Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `VM_MAX_COUNT` | Maximum number of VMs | `300` | No |
| `VM_IP_RANGE` | IP range for VMs | `192.168.100.0/24` | No |
| `VM_DEFAULT_USER` | Default user for VMs | `acceldata` | No |
| `VM_DEFAULT_SSH_KEY_PATH` | Path to SSH public key | `~/.ssh/id_rsa.pub` | No |

### Monitoring Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `PROMETHEUS_RETENTION` | Prometheus data retention | `30d` | No |
| `GRAFANA_ADMIN_USER` | Grafana admin username | `admin` | No |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password | `admin123` | No |
| `PROMETHEUS_URL` | Prometheus API URL | `http://prometheus:9090` | No |
| `GRAFANA_URL` | Grafana URL | `http://grafana:3000` | No |

### Notification Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `SLACK_WEBHOOK_URL` | Slack webhook URL | - | No |
| `JIRA_WEBHOOK_URL` | JIRA webhook URL | - | No |
| `JIRA_PROJECT_KEY` | JIRA project key | `DC` | No |
| `JIRA_USERNAME` | JIRA username | - | No |
| `JIRA_PASSWORD` | JIRA password/token | - | No |

### Database Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `POSTGRES_HOST` | PostgreSQL host | `postgresql-service` | No |
| `POSTGRES_PORT` | PostgreSQL port | `5432` | No |
| `POSTGRES_DB` | Database name | `hetzner_dc` | No |
| `POSTGRES_USER` | Database user | `hetzner_dc_user` | No |
| `POSTGRES_PASSWORD` | Database password | - | Yes |

### Application Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `SECRET_KEY` | Application secret key | - | Yes |
| `DEBUG` | Debug mode | `false` | No |
| `LOG_LEVEL` | Logging level | `INFO` | No |
| `REDIS_HOST` | Redis host | `redis-service` | No |
| `REDIS_PORT` | Redis port | `6379` | No |
| `REDIS_PASSWORD` | Redis password | - | No |

## Terraform Configuration

### Provider Configuration

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.42.0"
    }
  }
}

provider "hcloud" {
  token = var.hetzner_token
}
```

### Server Types

Available Hetzner server types:

| Type | CPU | RAM | Storage | Price (€/month) |
|------|-----|-----|---------|----------------|
| `cx11` | 1 | 4GB | 20GB | 3.29 |
| `cx21` | 2 | 8GB | 40GB | 5.83 |
| `cx31` | 2 | 8GB | 80GB | 11.66 |
| `cx41` | 4 | 16GB | 160GB | 23.32 |
| `cx51` | 8 | 32GB | 320GB | 46.64 |

### Regions

Available Hetzner regions:

- `fsn1` - Falkenstein, Germany
- `nbg1` - Nuremberg, Germany
- `hel1` - Helsinki, Finland
- `ash` - Ashburn, USA
- `hil` - Hillsboro, USA

### Custom Variables

```hcl
variable "custom_labels" {
  description = "Custom labels for resources"
  type        = map(string)
  default     = {
    environment = "production"
    project     = "hetzner-dc"
  }
}

variable "additional_volumes" {
  description = "Additional volumes for servers"
  type        = list(object({
    name = string
    size = number
  }))
  default = []
}
```

## Ansible Configuration

### Inventory Structure

```yaml
all:
  children:
    control_plane:
      hosts:
        cluster-cp-1:
          ansible_host: 1.2.3.4
          node_role: control-plane
        cluster-cp-2:
          ansible_host: 1.2.3.5
          node_role: control-plane
        cluster-cp-3:
          ansible_host: 1.2.3.6
          node_role: control-plane
    worker_nodes:
      hosts:
        cluster-worker-1:
          ansible_host: 1.2.3.7
          node_role: worker
        cluster-worker-2:
          ansible_host: 1.2.3.8
          node_role: worker
        cluster-worker-3:
          ansible_host: 1.2.3.9
          node_role: worker
```

### Group Variables

```yaml
# group_vars/all/cluster-config.yml
cluster_name: "hetzner-dc-cluster"
kubernetes_version: "1.28.0"
pod_cidr: "10.244.0.0/16"
service_cidr: "10.96.0.0/12"
container_runtime: "docker"
cni_plugin: "flannel"
```

### Host Variables

```yaml
# host_vars/cluster-cp-1.yml
node_index: 1
is_initial_control_plane: true
etcd_initial_cluster: "cluster-cp-1=https://1.2.3.4:2380"
```

## Kubernetes Configuration

### Cluster Configuration

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: "1.28.0"
controlPlaneEndpoint: "1.2.3.10:6443"
clusterName: "hetzner-dc-cluster"
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
  dnsDomain: "cluster.local"
etcd:
  local:
    dataDir: "/var/lib/etcd"
apiServer:
  extraArgs:
    enable-admission-plugins: "NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook"
```

### Node Configuration

```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: "systemd"
failSwapOn: false
```

### RBAC Configuration

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: vm-provisioner
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

## Monitoring Configuration

### Prometheus Configuration

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'hetzner-dc-cluster'
    environment: 'production'

rule_files:
  - "/etc/prometheus/rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'kubernetes-apiservers'
    kubernetes_sd_configs:
    - role: endpoints
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
```

### Grafana Configuration

```yaml
grafana:
  adminUser: "admin"
  adminPassword: "admin123"
  persistence:
    enabled: true
    storageClassName: "hetzner-csi"
    size: 10Gi
  service:
    type: LoadBalancer
    port: 80
  dashboards:
    default:
      datacenter-overview:
        gnetId: 1860
        revision: 1
        datasource: Prometheus
```

### Alert Rules

```yaml
groups:
- name: kubernetes.rules
  rules:
  - alert: KubernetesNodeNotReady
    expr: kube_node_status_condition{condition="Ready",status="true"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Kubernetes node not ready"
      description: "Node {{ $labels.node }} has been unready for more than 5 minutes."
```

## VM Provisioning Configuration

### API Configuration

```python
# vm-provisioning/api/config.py
class Settings:
    # Database
    database_url: str = "postgresql://user:pass@localhost/db"
    
    # Redis
    redis_url: str = "redis://localhost:6379"
    
    # Hetzner
    hetzner_api_token: str = "your-token"
    
    # Security
    secret_key: str = "your-secret-key"
    access_token_expire_minutes: int = 30
    
    # VM Configuration
    vm_max_count: int = 300
    vm_ip_range: str = "192.168.100.0/24"
    vm_default_user: str = "acceldata"
```

### VM Templates

```yaml
# kubernetes/vm-provisioning/vm-templates.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vm-templates
data:
  ubuntu22.yaml: |
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - curl
      - wget
      - git
      - vim
      - htop
      - net-tools
    users:
      - name: acceldata
        sudo: ALL=(ALL) NOPASSWD:ALL
        ssh_authorized_keys:
          - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... acceldata@hetzner-dc
```

### Resource Limits

```yaml
# kubernetes/vm-provisioning/resource-limits.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: vm-resource-limits
spec:
  limits:
  - type: Container
    max:
      cpu: "4"
      memory: "8Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
  - type: Pod
    max:
      cpu: "8"
      memory: "16Gi"
```

## Security Configuration

### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vm-provisioning-network-policy
spec:
  podSelector:
    matchLabels:
      app: vm-provisioner
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: vm-system
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090
```

### Pod Security Policies

```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: vm-provisioning-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
```

### RBAC Policies

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: vm-provisioner-role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

## Customization Examples

### Custom Server Types

```hcl
# terraform/custom-server-types.tf
resource "hcloud_server" "custom_worker" {
  count       = var.custom_worker_count
  name        = "${var.cluster_name}-custom-worker-${count.index + 1}"
  image       = "ubuntu-22.04"
  server_type = "cx51"  # High-performance workers
  location    = var.hetzner_region
  ssh_keys    = [hcloud_ssh_key.default.id]
  
  labels = {
    role = "custom-worker"
    node = "custom-worker-${count.index + 1}"
  }
}
```

### Custom Monitoring

```yaml
# kubernetes/monitoring/custom-metrics.yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: vm-provisioning-metrics
spec:
  selector:
    matchLabels:
      app: vm-provisioner
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### Custom VM Images

```yaml
# kubernetes/vm-provisioning/custom-images.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-vm-images
data:
  custom-image.yaml: |
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - docker.io
      - docker-compose
      - kubectl
      - helm
    users:
      - name: acceldata
        sudo: ALL=(ALL) NOPASSWD:ALL
        groups: docker
        ssh_authorized_keys:
          - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... acceldata@hetzner-dc
```

This configuration reference provides comprehensive details for customizing your Hetzner DC and Kubernetes cluster setup. Adjust the values according to your specific requirements and environment.