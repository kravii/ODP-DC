# Hetzner Baremetal DC & Kubernetes Cluster Setup

A comprehensive solution for setting up a VM Data Center and Kubernetes cluster on Hetzner baremetal servers with automated provisioning, monitoring, and management capabilities.

## 🏗️ Architecture Overview

This project provides:
- **Pre-provisioned Server Support**: Works with existing Rocky Linux 9 baremetal servers
- **Shared RAID Storage**: 1.8TB RAID storage shared across all nodes for K8s and VMs
- **Automated K8s Setup**: High-availability Kubernetes cluster with 3 control plane nodes
- **SSH Key Management**: Flexible SSH key and port configuration
- **Resource Pooling**: Unified resource management across all baremetal servers
- **VM Provisioning**: GUI-based VM creation with multiple OS options
- **Storage Management**: Shared RAID storage (1.8TB) with dynamic allocation and monitoring
- **Monitoring**: Comprehensive monitoring with Grafana dashboards
- **User Management**: RBAC with namespace isolation
- **Scalability**: Support for up to 200 baremetal servers and 300 VMs

## 🚀 Features

### Core Infrastructure
- ✅ Automated Kubernetes cluster setup with HA control plane
- ✅ Resource pooling from multiple baremetal servers
- ✅ Support for up to 200 baremetal servers
- ✅ Automated VM provisioning (up to 300 VMs)
- ✅ Multiple OS support (CentOS7, RHEL7/8/9, RockyLinux9, Ubuntu20/22/24, OEL8.10)

### Management & Monitoring
- ✅ Rancher-based cluster management
- ✅ GUI for adding/removing servers from cluster
- ✅ Resource allocation and scaling per namespace
- ✅ Comprehensive monitoring dashboard
- ✅ Slack/JIRA notification system
- ✅ Health monitoring for all baremetal servers

### Security & Access
- ✅ User management with admin/user roles
- ✅ Namespace-based resource isolation
- ✅ Default user `acceldata` with SSH key on all VMs/containers
- ✅ RBAC configuration

## 📁 Project Structure

```
├── terraform/                 # Infrastructure as Code
│   ├── hetzner/              # Hetzner provider configuration
│   ├── kubernetes/           # K8s cluster setup
│   └── monitoring/           # Monitoring infrastructure
├── ansible/                  # Configuration management
│   ├── playbooks/           # Ansible playbooks
│   ├── roles/               # Reusable roles
│   └── inventory/           # Server inventory
├── kubernetes/               # K8s manifests and configs
│   ├── cluster-setup/       # Cluster initialization
│   ├── monitoring/          # Monitoring stack
│   └── applications/        # Application deployments
├── monitoring/               # Monitoring configuration
│   ├── prometheus/          # Prometheus configs
│   ├── grafana/             # Grafana dashboards
│   └── alertmanager/        # Alerting rules
├── vm-provisioning/         # VM management system
│   ├── api/                 # REST API for VM operations
│   ├── frontend/            # Web GUI
│   └── templates/           # VM templates
├── scripts/                 # Utility scripts
└── docs/                    # Documentation
```

## 🛠️ Prerequisites

### Management Machine
- Terraform >= 1.5.0
- Ansible >= 2.12.0
- kubectl >= 1.28.0
- Helm >= 3.12.0
- Docker >= 20.10.0
- SSH access to baremetal servers

### Baremetal Servers
- **Operating System**: Rocky Linux 9 (latest)
- **CPU**: Minimum 2 cores, recommended 4+ cores
- **RAM**: Minimum 4GB, recommended 8GB+
- **Storage**: Minimum 40GB, recommended 100GB+
- **Network**: Stable network connectivity
- **Access**: Root or sudo access to all servers
- **SSH**: SSH access with private key

## 🚀 Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd hetzner-dc-k8s-setup
   ```

2. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your server IPs and SSH configuration
   ```

3. **Prepare servers** (if not already done)
   ```bash
   # Follow the Rocky Linux setup guide
   # See docs/rocky-linux-setup.md for detailed instructions
   ```

4. **Configure infrastructure**
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

5. **Setup Kubernetes cluster**
   ```bash
   cd ../ansible
   ansible-playbook -i inventory/hosts.yml playbooks/prepare-servers.yml
   ansible-playbook -i inventory/hosts.yml playbooks/setup-k8s-cluster.yml
   ```

5. **Deploy monitoring stack**
   ```bash
   cd ../kubernetes
   kubectl apply -f monitoring/
   ```

6. **Access Rancher dashboard**
   ```bash
   kubectl port-forward svc/rancher-server 8080:80
   # Open http://localhost:8080
   ```

## 📊 Monitoring

The monitoring stack includes:
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **AlertManager**: Alert routing and notification
- **Node Exporter**: Baremetal metrics
- **cAdvisor**: Container metrics

Access Grafana at `http://<grafana-service>:3000` (default: admin/admin)

## 🔧 Management Tools

This project integrates with:
- **Rancher**: Cluster management and GUI
- **Helm**: Package management
- **kubectl**: Command-line interface
- **k9s**: Terminal-based UI
- **Telepresence**: Local development integration

## 📚 Documentation

- [Setup Guide](docs/setup-guide.md)
- [Configuration Reference](docs/configuration.md)
- [Troubleshooting](docs/troubleshooting.md)
- [API Documentation](docs/api.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:
- Create an issue in the GitHub repository
- Check the [troubleshooting guide](docs/troubleshooting.md)
- Review the [FAQ](docs/faq.md)

## 🔄 Version History

- **v1.0.0**: Initial release with basic K8s cluster setup
- **v1.1.0**: Added VM provisioning capabilities
- **v1.2.0**: Enhanced monitoring and alerting
- **v1.3.0**: GUI improvements and user management