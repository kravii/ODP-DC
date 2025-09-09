# Data Center Management System on Hetzner Baremetal

A comprehensive solution for managing a data center infrastructure on Hetzner baremetal servers with VM provisioning, monitoring, and user management capabilities.

## Features

### 🖥️ Baremetal Management
- **Resource Pool Management**: Aggregate CPU, Memory, Storage, and IOPS from all baremetal servers
- **Dynamic Scaling**: Add/remove up to 200 baremetal servers with automatic resource pool updates
- **Health Monitoring**: Real-time monitoring of server health, resource utilization, and performance

### 🖼️ VM Provisioning
- **Multi-OS Support**: CentOS 7, RHEL 7/8/9, Rocky Linux 9, Ubuntu 20/22/24, OEL 8.10
- **Flexible Resource Allocation**: Choose CPU, memory, storage, and mount points per VM
- **Scale Support**: Launch up to 300 VMs with automatic IP management
- **Default Configuration**: Pre-configured `acceldata` user with SSH key access

### 📊 Monitoring & Alerts
- **Real-time Dashboard**: Monitor all baremetals and VMs with hostname/IP tracking
- **Resource Utilization**: CPU, memory, storage monitoring with threshold alerts
- **Notification System**: Slack and JIRA integration for incidents and alerts

### 👥 User Management
- **Role-based Access**: Admin and user roles with different permissions
- **VM Operations**: Launch, terminate, and modify VM resources based on user role
- **Secure Authentication**: JWT-based authentication with role management

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Backend API   │    │   Database      │
│   (React)       │◄──►│   (FastAPI)     │◄──►│   (PostgreSQL)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   Monitoring    │
                       │   (Prometheus   │
                       │   + Grafana)    │
                       └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   Hetzner       │
                       │   Baremetals    │
                       │   (200 max)     │
                       └─────────────────┘
```

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Hetzner Cloud API token
- Slack webhook URL (optional)
- JIRA credentials (optional)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd datacenter-management
   ```

2. **Run the setup script**
   ```bash
   chmod +x scripts/setup.sh
   ./scripts/setup.sh
   ```

3. **Or configure manually**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   docker-compose up -d
   ```

4. **Access the dashboard**
   - Frontend: http://localhost:3000
   - API Documentation: http://localhost:8000/docs
   - Monitoring: http://localhost:3001
   - MySQL Database: localhost:3306

### Configuration

#### Environment Variables
```bash
# Database
MYSQL_PASSWORD=your_password
MYSQL_ROOT_PASSWORD=your_root_password

# Hetzner API
HETZNER_API_TOKEN=your_hetzner_token

# JWT
JWT_SECRET_KEY=your_jwt_secret

# Slack (optional)
SLACK_WEBHOOK_URL=your_slack_webhook

# JIRA (optional)
JIRA_URL=your_jira_url
JIRA_USERNAME=your_jira_username
JIRA_API_TOKEN=your_jira_token
```

## Usage

### Adding Baremetal Servers

1. Access the dashboard at http://localhost:3000
2. Navigate to "Baremetal Management"
3. Click "Add Server" and provide:
   - Server name/hostname
   - IP address
   - Operating System (RHEL 8, Rocky Linux 9, Ubuntu 20/22)
   - Resource specifications (CPU, Memory)
   - Storage mount points (multiple mounts supported)
4. The server will be added to the resource pool automatically

### Provisioning VMs

1. Go to "VM Management" in the dashboard
2. Click "Launch VM"
3. Configure:
   - VM hostname
   - Operating system image (pre-configured dropdown)
   - CPU and memory allocation
   - Storage configuration with mount points
4. Click "Launch" to provision the VM

### Monitoring

- **Baremetal Health**: View real-time status and resource utilization
- **VM Status**: Monitor all provisioned VMs
- **Alerts**: Configure thresholds and notification channels

## API Documentation

The API is fully documented with Swagger UI available at `/docs` endpoint.

### Key Endpoints

- `GET /api/baremetals` - List all baremetal servers
- `POST /api/baremetals` - Add new baremetal server
- `GET /api/vms` - List all VMs
- `POST /api/vms` - Launch new VM
- `GET /api/monitoring/health` - Get system health status

## Monitoring and Alerts

### Metrics Collected
- CPU utilization per baremetal and VM
- Memory usage and available
- Storage utilization and IOPS
- Network traffic and latency
- System health and uptime

### Alert Thresholds
- CPU usage > 80%
- Memory usage > 85%
- Disk usage > 90%
- System down/offline

### Notification Channels
- Slack webhook integration
- JIRA ticket creation
- Email notifications (configurable)

## Security

- JWT-based authentication
- Role-based access control (RBAC)
- SSH key management for VM access
- Secure API endpoints with rate limiting
- Database encryption at rest

## Scaling

### Horizontal Scaling
- Add up to 200 baremetal servers
- Launch up to 300 VMs
- Automatic load balancing across servers

### Resource Management
- Dynamic resource allocation
- Automatic failover for failed servers
- Resource optimization and rebalancing

## Troubleshooting

### Common Issues

1. **VM Launch Failures**
   - Check resource availability in pool
   - Verify image availability
   - Check network connectivity

2. **Monitoring Alerts**
   - Review threshold configurations
   - Check notification channel settings
   - Verify server connectivity

3. **Performance Issues**
   - Monitor resource utilization
   - Check for resource contention
   - Review VM resource allocations

### Logs
- Application logs: `docker-compose logs -f app`
- Database logs: `docker-compose logs -f db`
- Monitoring logs: `docker-compose logs -f monitoring`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

For support and questions:
- Create an issue in the repository
- Check the documentation
- Review the troubleshooting guide

## Roadmap

- [ ] Kubernetes integration
- [ ] Advanced networking features
- [ ] Backup and disaster recovery
- [ ] Cost optimization tools
- [ ] Multi-cloud support