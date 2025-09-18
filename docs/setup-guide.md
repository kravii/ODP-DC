# Hetzner DC & Kubernetes Cluster Setup Guide

This comprehensive guide will walk you through setting up a complete VM Data Center and Kubernetes cluster on Hetzner baremetal servers.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Automated Setup](#automated-setup)
4. [Manual Setup](#manual-setup)
5. [Configuration](#configuration)
6. [Accessing Services](#accessing-services)
7. [Management Tools](#management-tools)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

- **Operating System**: Ubuntu 20.04+ or similar Linux distribution
- **RAM**: Minimum 8GB, recommended 16GB+
- **Storage**: Minimum 100GB free space
- **Network**: Stable internet connection
- **User**: Non-root user with sudo privileges

### Required Tools

The setup script will automatically install these tools, but you can install them manually:

- **Terraform** >= 1.5.0
- **Ansible** >= 2.12.0
- **kubectl** >= 1.28.0
- **Helm** >= 3.12.0
- **Docker** >= 20.10.0
- **Python** >= 3.8
- **Git**

### Hetzner Cloud Requirements

- **Hetzner Cloud Account**: Active account with billing configured
- **API Token**: Hetzner Cloud API token with read/write permissions
- **SSH Key**: SSH key pair for server access
- **Credit**: Sufficient credit for server provisioning

## Environment Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd hetzner-dc-k8s-setup
```

### 2. Configure Environment Variables

```bash
cp .env.example .env
```

Edit the `.env` file with your configuration:

```bash
# Hetzner Configuration
HETZNER_API_TOKEN=your_hetzner_api_token_here
HETZNER_REGION=fsn1
HETZNER_SSH_KEY_NAME=hetzner-dc-key

# Kubernetes Configuration
K8S_CLUSTER_NAME=hetzner-dc-cluster
K8S_VERSION=1.28.0
K8S_POD_CIDR=10.244.0.0/16
K8S_SERVICE_CIDR=10.96.0.0/12

# Control Plane Configuration
CONTROL_PLANE_COUNT=3
CONTROL_PLANE_TYPE=cx31
CONTROL_PLANE_DISK_SIZE=40

# Worker Node Configuration
WORKER_NODE_COUNT=3
WORKER_NODE_TYPE=cx41
WORKER_NODE_DISK_SIZE=80

# VM Configuration
VM_MAX_COUNT=300
VM_IP_RANGE=192.168.100.0/24
VM_DEFAULT_USER=acceldata
VM_DEFAULT_SSH_KEY_PATH=~/.ssh/id_rsa.pub

# Monitoring Configuration
PROMETHEUS_RETENTION=30d
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin123

# Notification Configuration
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
JIRA_WEBHOOK_URL=https://your-domain.atlassian.net/rest/api/3/webhook
JIRA_PROJECT_KEY=DC

# Database Configuration
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=hetzner_dc
POSTGRES_USER=hetzner_dc_user
POSTGRES_PASSWORD=secure_password_here

# Application Configuration
SECRET_KEY=your_secret_key_here
DEBUG=false
LOG_LEVEL=INFO

# Rancher Configuration
RANCHER_VERSION=2.7.5
RANCHER_ADMIN_PASSWORD=admin123
```

### 3. Generate SSH Key Pair

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/hetzner-dc-key -N ""
```

## Automated Setup

### Quick Setup

Run the automated setup script:

```bash
./scripts/setup.sh
```

This script will:
1. Check prerequisites
2. Install required tools
3. Deploy infrastructure with Terraform
4. Setup Kubernetes cluster with Ansible
5. Install monitoring stack
6. Install Rancher
7. Deploy VM provisioning system
8. Configure notifications

### Setup Process

The setup process typically takes 30-45 minutes and includes:

1. **Infrastructure Deployment** (10-15 minutes)
   - Provision Hetzner baremetal servers
   - Configure load balancers
   - Setup networking

2. **Kubernetes Cluster Setup** (15-20 minutes)
   - Initialize control plane
   - Join worker nodes
   - Install CNI (Flannel)
   - Configure RBAC

3. **Monitoring Stack Installation** (5-10 minutes)
   - Deploy Prometheus
   - Install Grafana
   - Configure AlertManager
   - Setup Node Exporter

4. **Rancher Installation** (5-10 minutes)
   - Deploy Rancher server
   - Configure ingress
   - Setup SSL certificates

5. **VM Provisioning System** (5-10 minutes)
   - Deploy API backend
   - Install frontend
   - Configure database
   - Setup monitoring

## Manual Setup

If you prefer to run each step manually:

### 1. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
cd ..
```

### 2. Setup Kubernetes Cluster

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/setup-k8s-cluster.yml
cd ..
```

### 3. Install Monitoring

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/install-monitoring.yml
cd ..
```

### 4. Install Rancher

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/install-rancher.yml
cd ..
```

### 5. Deploy VM Provisioning

```bash
kubectl apply -f kubernetes/vm-provisioning/
kubectl apply -f kubernetes/database/
kubectl apply -f kubernetes/frontend/
```

## Configuration

### Cluster Configuration

The cluster is configured with:

- **High Availability**: 3 control plane nodes
- **Load Balancing**: Hetzner Load Balancer for API server
- **Networking**: Flannel CNI with custom pod/service CIDRs
- **Storage**: Hetzner CSI driver for persistent volumes
- **Security**: RBAC enabled, network policies configured

### Resource Limits

Default resource limits per namespace:

- **CPU**: 100 cores
- **Memory**: 500GB
- **Storage**: 2TB
- **VMs**: 50 per namespace

### Monitoring Configuration

Monitoring includes:

- **Metrics Collection**: Prometheus with 30-day retention
- **Visualization**: Grafana with custom dashboards
- **Alerting**: AlertManager with Slack/JIRA integration
- **Logging**: Centralized logging with ELK stack

## Accessing Services

### Kubernetes Cluster

```bash
# Get kubeconfig
kubectl config view --raw > ~/.kube/config

# Test cluster access
kubectl get nodes
kubectl get pods --all-namespaces
```

### Rancher

1. **Access URL**: `https://rancher.<cluster-name>.local`
2. **Username**: `admin`
3. **Password**: Set in environment variables

### Grafana

1. **Access URL**: `http://<grafana-service-ip>:3000`
2. **Username**: `admin`
3. **Password**: Set in environment variables

### VM Provisioning Frontend

1. **Access URL**: `http://<frontend-service-ip>:3000`
2. **Login**: Use admin credentials

## Management Tools

### kubectl

Command-line tool for Kubernetes management:

```bash
# View cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Manage resources
kubectl create namespace my-namespace
kubectl apply -f my-manifest.yaml
kubectl delete pod my-pod
```

### k9s

Terminal-based UI for Kubernetes:

```bash
# Install k9s
brew install k9s  # macOS
# or
curl -sS https://webinstall.dev/k9s | bash

# Run k9s
k9s
```

### Helm

Package manager for Kubernetes:

```bash
# Add repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install packages
helm install prometheus prometheus-community/kube-prometheus-stack
```

### Telepresence

Local development with Kubernetes:

```bash
# Install telepresence
brew install telepresence  # macOS
# or
curl -s https://packagecloud.io/install/repositories/datawireio/telepresence/script.deb.sh | sudo bash
sudo apt install telepresence

# Connect to cluster
telepresence connect
```

## Troubleshooting

### Common Issues

#### 1. Terraform Deployment Fails

**Problem**: Terraform fails to create resources

**Solutions**:
- Check Hetzner API token permissions
- Verify available credit in Hetzner account
- Check region availability
- Review Terraform logs for specific errors

#### 2. Kubernetes Cluster Initialization Fails

**Problem**: kubeadm init fails

**Solutions**:
- Check network connectivity between nodes
- Verify firewall rules
- Check system requirements
- Review kubeadm logs

#### 3. Monitoring Stack Not Working

**Problem**: Prometheus/Grafana not accessible

**Solutions**:
- Check pod status: `kubectl get pods -n monitoring`
- Verify service endpoints: `kubectl get svc -n monitoring`
- Check ingress configuration
- Review logs: `kubectl logs -n monitoring`

#### 4. VM Provisioning API Errors

**Problem**: API returns errors

**Solutions**:
- Check database connectivity
- Verify Hetzner API token
- Review API logs: `kubectl logs -n vm-system`
- Check resource availability

### Log Collection

Collect logs for troubleshooting:

```bash
# Kubernetes cluster logs
kubectl logs -n kube-system -l component=kube-apiserver
kubectl logs -n kube-system -l component=kube-controller-manager
kubectl logs -n kube-system -l component=kube-scheduler

# Monitoring logs
kubectl logs -n monitoring -l app=prometheus
kubectl logs -n monitoring -l app=grafana

# VM provisioning logs
kubectl logs -n vm-system -l app=vm-provisioner
```

### Health Checks

Verify system health:

```bash
# Cluster health
kubectl get nodes
kubectl get pods --all-namespaces

# Service health
kubectl get svc --all-namespaces

# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

### Support

For additional support:

1. **Check Documentation**: Review this guide and API documentation
2. **Review Logs**: Check application and system logs
3. **Community Support**: Post issues on GitHub
4. **Professional Support**: Contact support team

## Security Considerations

### Network Security

- **Firewall Rules**: Configure appropriate firewall rules
- **Network Policies**: Implement Kubernetes network policies
- **TLS/SSL**: Enable TLS for all services
- **VPN Access**: Consider VPN for secure access

### Access Control

- **RBAC**: Configure role-based access control
- **SSH Keys**: Use SSH keys instead of passwords
- **API Tokens**: Rotate API tokens regularly
- **User Management**: Implement proper user management

### Data Protection

- **Backups**: Regular backups of critical data
- **Encryption**: Encrypt sensitive data at rest and in transit
- **Secrets Management**: Use Kubernetes secrets for sensitive data
- **Audit Logging**: Enable audit logging for compliance

## Performance Optimization

### Cluster Optimization

- **Resource Limits**: Set appropriate resource limits
- **Node Affinity**: Use node affinity for workload placement
- **Horizontal Pod Autoscaling**: Enable HPA for dynamic scaling
- **Vertical Pod Autoscaling**: Use VPA for resource optimization

### Storage Optimization

- **Storage Classes**: Configure appropriate storage classes
- **Volume Snapshots**: Enable volume snapshots
- **Storage Monitoring**: Monitor storage usage and performance
- **Cleanup Policies**: Implement storage cleanup policies

### Network Optimization

- **CNI Configuration**: Optimize CNI configuration
- **Service Mesh**: Consider service mesh for advanced networking
- **Load Balancing**: Optimize load balancing configuration
- **Network Monitoring**: Monitor network performance

## Maintenance

### Regular Maintenance Tasks

1. **Security Updates**: Apply security updates regularly
2. **Backup Verification**: Verify backups are working
3. **Resource Monitoring**: Monitor resource usage
4. **Log Rotation**: Configure log rotation
5. **Certificate Renewal**: Renew SSL certificates

### Upgrade Procedures

1. **Backup**: Create full backup before upgrades
2. **Staging**: Test upgrades in staging environment
3. **Rolling Updates**: Use rolling updates for zero-downtime
4. **Rollback Plan**: Have rollback plan ready
5. **Monitoring**: Monitor system during upgrades

This setup guide provides comprehensive instructions for deploying and managing your Hetzner DC and Kubernetes cluster. Follow the steps carefully and refer to the troubleshooting section if you encounter any issues.