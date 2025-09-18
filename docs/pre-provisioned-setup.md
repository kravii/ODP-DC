# Pre-Provisioned Server Setup Guide

This guide provides step-by-step instructions for setting up the Hetzner DC & Kubernetes cluster using pre-provisioned Rocky Linux 9 baremetal servers.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Server Preparation](#server-preparation)
4. [Environment Configuration](#environment-configuration)
5. [SSH Key Management](#ssh-key-management)
6. [Infrastructure Configuration](#infrastructure-configuration)
7. [Kubernetes Cluster Setup](#kubernetes-cluster-setup)
8. [Monitoring and Management](#monitoring-and-management)
9. [Verification](#verification)
10. [Troubleshooting](#troubleshooting)

## Overview

This setup assumes you have:
- Pre-provisioned baremetal servers running Rocky Linux 9
- SSH access to all servers with a private key
- Network connectivity between all servers
- Root or sudo access on all servers

The setup process includes:
1. Preparing servers for Kubernetes
2. Configuring SSH keys and ports
3. Setting up infrastructure configuration
4. Deploying Kubernetes cluster
5. Installing monitoring and management tools

## Prerequisites

### Management Machine Requirements

- **OS**: Linux (Ubuntu 20.04+ recommended)
- **RAM**: Minimum 4GB, recommended 8GB+
- **Storage**: Minimum 20GB free space
- **Network**: Access to all baremetal servers

### Required Software

```bash
# Install required tools
sudo apt-get update
sudo apt-get install -y curl wget git vim htop net-tools bridge-utils \
    iptables conntrack socat ipvsadm python3 python3-pip python3-venv \
    jq unzip

# Install Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Install Ansible
pip3 install ansible

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -aG docker $USER
```

### Baremetal Server Requirements

- **OS**: Rocky Linux 9 (latest)
- **CPU**: Minimum 2 cores, recommended 4+ cores
- **RAM**: Minimum 4GB, recommended 8GB+
- **Storage**: Minimum 40GB, recommended 100GB+
- **Network**: Stable connectivity, all required ports open
- **Access**: Root or sudo access, SSH key authentication

## Server Preparation

### 1. Update All Servers

```bash
# On each server, run:
sudo dnf update -y
sudo dnf install -y curl wget git vim htop net-tools bridge-utils \
    iptables conntrack-tools socat ipvsadm firewalld NetworkManager \
    openssh-server rsync tar gzip unzip
```

### 2. Configure Hostnames

```bash
# Set hostnames (replace with your server names)
sudo hostnamectl set-hostname server-01  # Control plane 1
sudo hostnamectl set-hostname server-02  # Control plane 2
sudo hostnamectl set-hostname server-03  # Control plane 3
sudo hostnamectl set-hostname worker-01  # Worker 1
sudo hostnamectl set-hostname worker-02  # Worker 2
sudo hostnamectl set-hostname worker-03  # Worker 3
```

### 3. Update /etc/hosts

```bash
# On each server, add entries for all servers
sudo tee -a /etc/hosts <<EOF
10.0.1.10 server-01
10.0.1.11 server-02
10.0.1.12 server-03
10.0.1.20 worker-01
10.0.1.21 worker-02
10.0.1.22 worker-03
EOF
```

### 4. Configure Firewall

```bash
# Start and enable firewalld
sudo systemctl enable firewalld
sudo systemctl start firewalld

# Open required ports
sudo firewall-cmd --permanent --add-port=22/tcp
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --permanent --add-port=2379-2380/tcp
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=10251/tcp
sudo firewall-cmd --permanent --add-port=10252/tcp
sudo firewall-cmd --permanent --add-port=10255/tcp
sudo firewall-cmd --permanent --add-port=30000-32767/tcp
sudo firewall-cmd --permanent --add-port=8285/udp
sudo firewall-cmd --permanent --add-port=8472/udp

# Reload firewall
sudo firewall-cmd --reload
```

### 5. Configure Kernel Parameters

```bash
# Load required kernel modules
sudo modprobe br_netfilter
sudo modprobe overlay

# Configure modules to load on boot
echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf
echo "overlay" | sudo tee -a /etc/modules-load.d/k8s.conf

# Configure sysctl parameters
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
vm.swappiness = 0
EOF

# Apply sysctl configuration
sudo sysctl --system
```

### 6. Disable SELinux

```bash
# Temporarily disable SELinux
sudo setenforce 0

# Permanently disable SELinux
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config
```

## Environment Configuration

### 1. Clone Repository

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
# Existing Baremetal Server Configuration
CONTROL_PLANE_IPS=10.0.1.10,10.0.1.11,10.0.1.12
WORKER_NODE_IPS=10.0.1.20,10.0.1.21,10.0.1.22

# SSH Configuration for existing servers
SSH_PRIVATE_KEY_PATH=~/.ssh/id_rsa
SSH_PORT=22
SSH_USER=root

# Kubernetes Configuration
K8S_CLUSTER_NAME=hetzner-dc-cluster
K8S_VERSION=1.28.0
K8S_POD_CIDR=10.244.0.0/16
K8S_SERVICE_CIDR=10.96.0.0/12

# Control Plane Configuration
CONTROL_PLANE_COUNT=3

# Worker Node Configuration
WORKER_NODE_COUNT=3

# VM Configuration
VM_MAX_COUNT=300
VM_IP_RANGE=192.168.100.0/24
VM_DEFAULT_USER=acceldata

# Monitoring Configuration
PROMETHEUS_RETENTION=30d
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin123

# Database Configuration
POSTGRES_HOST=postgresql-service
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

### 3. Generate SSH Key Pair (if needed)

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Copy public key to all servers
for server in 10.0.1.10 10.0.1.11 10.0.1.12 10.0.1.20 10.0.1.21 10.0.1.22; do
    ssh-copy-id -i ~/.ssh/id_rsa.pub root@$server
done
```

## SSH Key Management

### 1. Change SSH Port (Optional)

If you want to use a custom SSH port:

```bash
# Update SSH configuration on all servers
for server in 10.0.1.10 10.0.1.11 10.0.1.12 10.0.1.20 10.0.1.21 10.0.1.22; do
    ssh root@$server "sed -i 's/^#Port 22/Port 2222/' /etc/ssh/sshd_config && systemctl restart sshd"
done

# Update .env file
echo "SSH_PORT=2222" >> .env
```

### 2. Change SSH User (Optional)

If you want to use a different SSH user:

```bash
# Create new user on all servers
for server in 10.0.1.10 10.0.1.11 10.0.1.12 10.0.1.20 10.0.1.21 10.0.1.22; do
    ssh root@$server "useradd -m -s /bin/bash admin && usermod -aG wheel admin && echo 'admin ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/admin"
done

# Copy SSH key to new user
for server in 10.0.1.10 10.0.1.11 10.0.1.12 10.0.1.20 10.0.1.21 10.0.1.22; do
    ssh root@$server "mkdir -p /home/admin/.ssh && cp /root/.ssh/authorized_keys /home/admin/.ssh/ && chown -R admin:admin /home/admin/.ssh && chmod 700 /home/admin/.ssh && chmod 600 /home/admin/.ssh/authorized_keys"
done

# Update .env file
echo "SSH_USER=admin" >> .env
```

### 3. Use Ansible for SSH Management

```bash
# Run SSH management playbook
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/manage-ssh-keys.yml \
                 -e "ssh_port=2222" \
                 -e "ssh_user=admin" \
                 -e "ssh_private_key_path=~/.ssh/id_rsa"
```

## Infrastructure Configuration

### 1. Configure Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Plan configuration
terraform plan -var="cluster_name=$CLUSTER_NAME" \
               -var="control_plane_ips=[\"$(echo $CONTROL_PLANE_IPS | tr ',' '\"' | sed 's/,/","/g')\"]" \
               -var="worker_node_ips=[\"$(echo $WORKER_NODE_IPS | tr ',' '\"' | sed 's/,/","/g')\"]" \
               -var="ssh_private_key_path=$SSH_PRIVATE_KEY_PATH" \
               -var="ssh_port=$SSH_PORT" \
               -var="ssh_user=$SSH_USER"

# Apply configuration
terraform apply -auto-approve \
                -var="cluster_name=$CLUSTER_NAME" \
                -var="control_plane_ips=[\"$(echo $CONTROL_PLANE_IPS | tr ',' '\"' | sed 's/,/","/g')\"]" \
                -var="worker_node_ips=[\"$(echo $WORKER_NODE_IPS | tr ',' '\"' | sed 's/,/","/g')\"]" \
                -var="ssh_private_key_path=$SSH_PRIVATE_KEY_PATH" \
                -var="ssh_port=$SSH_PORT" \
                -var="ssh_user=$SSH_USER"
```

### 2. Verify Configuration

```bash
# Check generated files
ls -la ansible/inventory/hosts.yml
ls -la ansible/group_vars/all/cluster-config.yml

# Test Ansible connectivity
ansible all -i ansible/inventory/hosts.yml -m ping
```

## Kubernetes Cluster Setup

### 1. Prepare Servers

```bash
cd ansible

# Run server preparation playbook
ansible-playbook -i inventory/hosts.yml playbooks/prepare-servers.yml \
                 -e "cluster_ssh_user=$SSH_USER" \
                 -e "cluster_ssh_port=$SSH_PORT"
```

### 2. Setup Kubernetes Cluster

```bash
# Run Kubernetes setup playbook
ansible-playbook -i inventory/hosts.yml playbooks/setup-k8s-cluster.yml
```

### 3. Install Monitoring Stack

```bash
# Run monitoring installation playbook
ansible-playbook -i inventory/hosts.yml playbooks/install-monitoring.yml
```

### 4. Install Rancher

```bash
# Run Rancher installation playbook
ansible-playbook -i inventory/hosts.yml playbooks/install-rancher.yml
```

## Monitoring and Management

### 1. Deploy VM Provisioning System

```bash
cd ../kubernetes

# Create namespace
kubectl create namespace vm-system

# Deploy database
kubectl apply -f database/

# Deploy VM provisioning
kubectl apply -f vm-provisioning/

# Deploy frontend
kubectl apply -f frontend/
```

### 2. Configure Notifications

```bash
# Update notification configuration
kubectl create configmap notification-config -n vm-system \
  --from-literal=slack_webhook_url="$SLACK_WEBHOOK_URL" \
  --from-literal=jira_webhook_url="$JIRA_WEBHOOK_URL" \
  --from-literal=jira_project_key="$JIRA_PROJECT_KEY"
```

## Verification

### 1. Check Cluster Status

```bash
# Check nodes
kubectl get nodes

# Check pods
kubectl get pods --all-namespaces

# Check services
kubectl get svc --all-namespaces
```

### 2. Test Services

```bash
# Test Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Test Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Test Rancher
kubectl port-forward -n cattle-system svc/rancher 8080:80
```

### 3. Access Information

```bash
# Get cluster information
kubectl cluster-info

# Get service endpoints
kubectl get svc --all-namespaces -o wide

# Get ingress information
kubectl get ingress --all-namespaces
```

## Troubleshooting

### Common Issues

#### 1. SSH Connection Failures

```bash
# Test SSH connectivity
ssh -o ConnectTimeout=10 $SSH_USER@$SERVER_IP

# Check SSH configuration
ssh -v $SSH_USER@$SERVER_IP

# Verify SSH key
ssh-keygen -l -f ~/.ssh/id_rsa.pub
```

#### 2. Ansible Connection Issues

```bash
# Test Ansible connectivity
ansible all -i inventory/hosts.yml -m ping

# Check Ansible configuration
ansible-config dump

# Run with verbose output
ansible-playbook -i inventory/hosts.yml playbooks/prepare-servers.yml -vvv
```

#### 3. Kubernetes Cluster Issues

```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Check logs
kubectl logs -n kube-system -l component=kube-apiserver
kubectl logs -n kube-system -l component=kube-controller-manager
kubectl logs -n kube-system -l component=kube-scheduler

# Check kubelet status
systemctl status kubelet
journalctl -u kubelet -f
```

#### 4. Firewall Issues

```bash
# Check firewall status
sudo firewall-cmd --list-all

# Check if ports are open
sudo firewall-cmd --query-port=6443/tcp
sudo firewall-cmd --query-port=10250/tcp

# Open specific port
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --reload
```

### Log Collection

```bash
# Collect system logs
sudo journalctl --since "1 hour ago" > system.log

# Collect Kubernetes logs
kubectl logs --all-containers=true --all-namespaces=true > k8s.log

# Collect Ansible logs
ansible-playbook -i inventory/hosts.yml playbooks/prepare-servers.yml --check -vvv > ansible.log
```

### Recovery Procedures

#### 1. Reset Kubernetes Cluster

```bash
# Reset cluster on all nodes
ansible all -i inventory/hosts.yml -m shell -a "kubeadm reset --force"

# Clean up on all nodes
ansible all -i inventory/hosts.yml -m shell -a "rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet"

# Re-run cluster setup
ansible-playbook -i inventory/hosts.yml playbooks/setup-k8s-cluster.yml
```

#### 2. Reconfigure SSH

```bash
# Run SSH management playbook
ansible-playbook -i inventory/hosts.yml playbooks/manage-ssh-keys.yml \
                 -e "ssh_port=22" \
                 -e "ssh_user=root" \
                 -e "ssh_private_key_path=~/.ssh/id_rsa"
```

This comprehensive guide ensures successful setup of your Hetzner DC and Kubernetes cluster using pre-provisioned Rocky Linux 9 servers. Follow each step carefully and refer to the troubleshooting section if you encounter any issues.