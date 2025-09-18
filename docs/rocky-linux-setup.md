# Rocky Linux 9 Server Setup Guide

This guide provides detailed instructions for preparing Rocky Linux 9 baremetal servers for Kubernetes cluster deployment.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Server Preparation](#server-preparation)
3. [Package Installation](#package-installation)
4. [SSH Configuration](#ssh-configuration)
5. [Firewall Configuration](#firewall-configuration)
6. [Kernel Configuration](#kernel-configuration)
7. [Container Runtime Setup](#container-runtime-setup)
8. [Kubernetes Prerequisites](#kubernetes-prerequisites)
9. [Verification Steps](#verification-steps)
10. [Troubleshooting](#troubleshooting)

## Prerequisites

### Server Requirements

- **Operating System**: Rocky Linux 9 (latest)
- **CPU**: Minimum 2 cores, recommended 4+ cores
- **RAM**: Minimum 4GB, recommended 8GB+
- **Storage**: Minimum 40GB, recommended 100GB+
- **Network**: Stable network connectivity
- **Access**: Root or sudo access to all servers

### Network Requirements

- **SSH Access**: Port 22 (or custom port)
- **Kubernetes API**: Port 6443
- **etcd**: Ports 2379-2380
- **kubelet**: Port 10250
- **kube-scheduler**: Port 10251
- **kube-controller-manager**: Port 10252
- **kube-proxy**: Port 10255
- **NodePort Services**: Ports 30000-32767
- **Flannel**: Ports 8285 (UDP), 8472 (UDP)

## Server Preparation

### 1. Update System Packages

```bash
# Update all packages to latest versions
sudo dnf update -y

# Install essential packages
sudo dnf install -y curl wget git vim htop net-tools bridge-utils \
    iptables conntrack-tools socat ipvsadm firewalld NetworkManager \
    openssh-server rsync tar gzip unzip
```

### 2. Configure Hostname

```bash
# Set hostname (replace with your server name)
sudo hostnamectl set-hostname server-01

# Update /etc/hosts
echo "127.0.0.1 server-01" | sudo tee -a /etc/hosts
```

### 3. Configure Network

```bash
# Ensure NetworkManager is running
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

# Check network configuration
ip addr show
ip route show
```

## Package Installation

### 1. Install Container Runtime (containerd)

```bash
# Add Docker repository
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install containerd
sudo dnf install -y containerd.io

# Configure containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Modify containerd configuration for systemd cgroup
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Start and enable containerd
sudo systemctl enable containerd
sudo systemctl start containerd
```

### 2. Install Kubernetes Packages

```bash
# Add Kubernetes repository
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
EOF

# Install Kubernetes packages
sudo dnf install -y kubelet kubeadm kubectl

# Enable kubelet service
sudo systemctl enable kubelet
```

## SSH Configuration

### 1. Configure SSH Daemon

```bash
# Backup original SSH configuration
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Configure SSH daemon
sudo tee -a /etc/ssh/sshd_config <<EOF

# Custom SSH configuration
Port 22
PermitRootLogin yes
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
StrictModes yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

# Restart SSH service
sudo systemctl restart sshd
```

### 2. Configure SSH Keys

```bash
# Generate SSH key pair (if not exists)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Copy public key to authorized_keys
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

### 3. Create Cluster Management User

```bash
# Create acceldata user
sudo useradd -m -s /bin/bash acceldata
sudo usermod -aG wheel acceldata

# Create SSH directory for acceldata
sudo mkdir -p /home/acceldata/.ssh
sudo chown acceldata:acceldata /home/acceldata/.ssh
sudo chmod 700 /home/acceldata/.ssh

# Copy SSH key to acceldata user
sudo cp ~/.ssh/id_rsa.pub /home/acceldata/.ssh/authorized_keys
sudo chown acceldata:acceldata /home/acceldata/.ssh/authorized_keys
sudo chmod 600 /home/acceldata/.ssh/authorized_keys

# Configure sudo for acceldata
echo "acceldata ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/acceldata
sudo chmod 440 /etc/sudoers.d/acceldata
```

## Firewall Configuration

### 1. Configure firewalld

```bash
# Start and enable firewalld
sudo systemctl enable firewalld
sudo systemctl start firewalld

# Open SSH port
sudo firewall-cmd --permanent --add-port=22/tcp

# Open Kubernetes ports
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

# Check firewall status
sudo firewall-cmd --list-all
```

## Kernel Configuration

### 1. Configure Kernel Modules

```bash
# Load required kernel modules
sudo modprobe br_netfilter
sudo modprobe overlay

# Configure modules to load on boot
echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf
echo "overlay" | sudo tee -a /etc/modules-load.d/k8s.conf
```

### 2. Configure sysctl Parameters

```bash
# Configure sysctl for Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
vm.swappiness = 0
EOF

# Apply sysctl configuration
sudo sysctl --system
```

### 3. Disable SELinux

```bash
# Check SELinux status
sudo sestatus

# Disable SELinux
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config

# Reboot to apply changes
sudo reboot
```

## Container Runtime Setup

### 1. Configure containerd

```bash
# Create containerd configuration
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Modify configuration for systemd cgroup
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart containerd
sudo systemctl restart containerd
sudo systemctl enable containerd
```

### 2. Configure crictl

```bash
# Download crictl
VERSION="v1.28.0"
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
sudo tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-$VERSION-linux-amd64.tar.gz

# Configure crictl
sudo mkdir -p /etc/crictl.d
cat <<EOF | sudo tee /etc/crictl.d/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
pull-image-on-create: false
EOF
```

## Kubernetes Prerequisites

### 1. Create Required Directories

```bash
# Create Kubernetes directories
sudo mkdir -p /etc/kubernetes/manifests
sudo mkdir -p /var/lib/kubelet
sudo mkdir -p /var/lib/etcd
sudo mkdir -p /etc/kubernetes/pki
```

### 2. Configure kubelet

```bash
# Create kubelet configuration
sudo mkdir -p /var/lib/kubelet
cat <<EOF | sudo tee /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
failSwapOn: false
EOF
```

### 3. Install CNI Plugins

```bash
# Download CNI plugins
CNI_VERSION="v1.3.0"
sudo mkdir -p /opt/cni/bin
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}.tgz" | sudo tar -C /opt/cni/bin -xz
```

## Verification Steps

### 1. Check System Status

```bash
# Check system information
uname -a
cat /etc/os-release

# Check memory and CPU
free -h
lscpu

# Check disk space
df -h

# Check network interfaces
ip addr show
```

### 2. Check Services

```bash
# Check containerd status
sudo systemctl status containerd

# Check kubelet status
sudo systemctl status kubelet

# Check firewalld status
sudo systemctl status firewalld

# Check SSH status
sudo systemctl status sshd
```

### 3. Test Container Runtime

```bash
# Test containerd
sudo crictl version

# Test pulling an image
sudo crictl pull hello-world

# List images
sudo crictl images
```

### 4. Test Network Connectivity

```bash
# Test SSH connectivity
ssh -o ConnectTimeout=10 user@server-ip

# Test port connectivity
telnet server-ip 6443
telnet server-ip 10250
```

## Troubleshooting

### Common Issues

#### 1. containerd fails to start

```bash
# Check containerd logs
sudo journalctl -u containerd -f

# Check containerd configuration
sudo containerd config dump

# Restart containerd
sudo systemctl restart containerd
```

#### 2. kubelet fails to start

```bash
# Check kubelet logs
sudo journalctl -u kubelet -f

# Check kubelet configuration
sudo cat /var/lib/kubelet/config.yaml

# Restart kubelet
sudo systemctl restart kubelet
```

#### 3. Firewall blocking connections

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

#### 4. SELinux issues

```bash
# Check SELinux status
sudo sestatus

# Check SELinux logs
sudo ausearch -m AVC -ts recent

# Temporarily disable SELinux
sudo setenforce 0
```

### Log Collection

```bash
# Collect system logs
sudo journalctl --since "1 hour ago" > system.log

# Collect containerd logs
sudo journalctl -u containerd --since "1 hour ago" > containerd.log

# Collect kubelet logs
sudo journalctl -u kubelet --since "1 hour ago" > kubelet.log

# Collect firewall logs
sudo firewall-cmd --get-log-denied > firewall.log
```

### Performance Optimization

```bash
# Optimize system limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Optimize kernel parameters
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
echo "fs.file-max=65536" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## Automation Script

Create an automation script to prepare all servers:

```bash
#!/bin/bash
# rocky-linux-prepare.sh

set -e

# Configuration
SSH_USER="root"
SSH_PORT="22"
CLUSTER_USER="acceldata"

# Function to run commands on remote server
run_remote() {
    local server_ip=$1
    local command=$2
    ssh -p $SSH_PORT $SSH_USER@$server_ip "$command"
}

# Function to copy files to remote server
copy_to_remote() {
    local server_ip=$1
    local local_file=$2
    local remote_file=$3
    scp -P $SSH_PORT $local_file $SSH_USER@$server_ip:$remote_file
}

# Server IPs (update with your server IPs)
SERVERS=("10.0.1.10" "10.0.1.11" "10.0.1.12" "10.0.1.20" "10.0.1.21" "10.0.1.22")

echo "Preparing Rocky Linux 9 servers for Kubernetes..."

for server in "${SERVERS[@]}"; do
    echo "Preparing server: $server"
    
    # Update system
    run_remote $server "dnf update -y"
    
    # Install packages
    run_remote $server "dnf install -y curl wget git vim htop net-tools bridge-utils iptables conntrack-tools socat ipvsadm firewalld NetworkManager openssh-server"
    
    # Configure firewall
    run_remote $server "systemctl enable firewalld && systemctl start firewalld"
    run_remote $server "firewall-cmd --permanent --add-port=22/tcp && firewall-cmd --permanent --add-port=6443/tcp && firewall-cmd --permanent --add-port=10250/tcp && firewall-cmd --reload"
    
    # Configure kernel modules
    run_remote $server "modprobe br_netfilter && modprobe overlay"
    run_remote $server "echo 'br_netfilter' > /etc/modules-load.d/k8s.conf && echo 'overlay' >> /etc/modules-load.d/k8s.conf"
    
    # Configure sysctl
    run_remote $server "echo 'net.bridge.bridge-nf-call-iptables = 1' > /etc/sysctl.d/k8s.conf && echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/k8s.conf && sysctl --system"
    
    # Disable SELinux
    run_remote $server "setenforce 0 && sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config"
    
    echo "Server $server prepared successfully!"
done

echo "All servers prepared successfully!"
```

This comprehensive guide ensures that all Rocky Linux 9 servers are properly configured for Kubernetes cluster deployment. Follow these steps on each server before running the Ansible playbooks.