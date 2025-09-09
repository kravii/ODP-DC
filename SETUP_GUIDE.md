# Data Center Management System - Setup Guide

This guide will walk you through setting up the Data Center Management System on Hetzner baremetal servers.

## Prerequisites

### System Requirements
- **Operating System**: Linux (Ubuntu 20.04+ recommended)
- **RAM**: Minimum 8GB, Recommended 16GB+
- **Storage**: Minimum 100GB free space
- **CPU**: Minimum 4 cores, Recommended 8+ cores
- **Network**: Stable internet connection

### Software Requirements
- **Docker**: Version 20.10+
- **Docker Compose**: Version 2.0+
- **Git**: For cloning the repository
- **SSH**: For server access

### Hetzner Requirements
- **Hetzner Cloud API Token**: For managing baremetal servers
- **Baremetal Servers**: At least 1 server to start with
- **Network Configuration**: Proper firewall rules

## Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd datacenter-management
```

### 2. Run the Setup Script

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

This script will:
- Create necessary directories
- Generate SSH keys
- Set up environment variables
- Build and start all services

### 3. Manual Setup (Alternative)

If you prefer manual setup:

```bash
# Copy environment file
cp .env.example .env

# Edit configuration
nano .env

# Create shared directories
mkdir -p shared/{ssh_keys,images,logs}

# Generate SSH key
ssh-keygen -t rsa -b 4096 -f shared/ssh_keys/default_key -N ""

# Start services
docker-compose up -d
```

## Configuration

### Environment Variables

Edit the `.env` file with your configuration:

```bash
# Database Configuration
POSTGRES_PASSWORD=your_secure_password

# Hetzner API Configuration
HETZNER_API_TOKEN=your_hetzner_api_token

# JWT Configuration
JWT_SECRET_KEY=your_super_secret_jwt_key

# Slack Integration (Optional)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK

# JIRA Integration (Optional)
JIRA_URL=https://your-domain.atlassian.net
JIRA_USERNAME=your-email@domain.com
JIRA_API_TOKEN=your_jira_api_token
```

### Hetzner API Setup

1. **Get API Token**:
   - Go to [Hetzner Cloud Console](https://console.hetzner.cloud/)
   - Navigate to "Security" → "API Tokens"
   - Create a new token with full access

2. **Configure Firewall**:
   - Allow SSH (port 22)
   - Allow HTTP (port 80)
   - Allow HTTPS (port 443)
   - Allow custom ports for monitoring (9100, 3000, 8000)

### Network Configuration

Ensure your servers can communicate:
- All servers should be in the same network
- Firewall rules allow inter-server communication
- DNS resolution works between servers

## Adding Baremetal Servers

### 1. Access the Dashboard

Open your browser and go to: `http://your-server-ip:3000`

### 2. Login

Use the default credentials:
- **Username**: `admin`
- **Password**: `admin123`

**⚠️ Important**: Change the default password immediately after first login.

### 3. Add Your First Server

1. Go to "Baremetal Servers" in the sidebar
2. Click "Add Server"
3. Fill in the details:
   - **Hostname**: `server-01` (or your preferred name)
   - **IP Address**: Your server's IP address
   - **CPU Cores**: Number of CPU cores
   - **Memory (GB)**: Amount of RAM in GB
   - **Storage (GB)**: Available storage in GB
   - **IOPS**: Input/Output operations per second (optional)

4. Click "Add" to add the server

### 4. Verify Server Status

- The server should appear in the list with "Active" status
- Check the resource pool to see aggregated resources
- Monitor the health status in the monitoring section

## Launching Virtual Machines

### 1. Prepare VM Images

The system comes with pre-configured images for:
- CentOS 7
- RHEL 7/8/9
- Rocky Linux 9
- Ubuntu 20.04/22.04/24.04
- Oracle Linux 8.10

### 2. Launch a VM

1. Go to "Virtual Machines" in the sidebar
2. Click "Launch VM"
3. Configure the VM:
   - **Hostname**: `vm-01`
   - **Operating System**: Select from available images
   - **CPU Cores**: Allocate CPU cores
   - **Memory**: Allocate memory in MB
   - **Storage Mounts**: Configure storage with mount points

4. Click "Launch" to create the VM

### 3. Monitor VM Status

- VMs will show "Creating" status initially
- Once ready, status changes to "Running"
- Monitor resource usage in the monitoring section

## Monitoring Setup

### 1. Access Grafana

Go to: `http://your-server-ip:3001`

Default credentials:
- **Username**: `admin`
- **Password**: `admin` (as configured in .env)

### 2. Configure Dashboards

The system includes pre-configured dashboards:
- **Data Center Overview**: System-wide metrics
- **Baremetal Monitoring**: Individual server metrics
- **VM Monitoring**: Virtual machine metrics
- **Alert Management**: System alerts and notifications

### 3. Set Up Alerts

Configure alert thresholds:
- **CPU Usage**: > 80% for 5 minutes
- **Memory Usage**: > 85% for 5 minutes
- **Disk Usage**: > 90% for 5 minutes
- **Service Down**: Any service unavailable

## User Management

### 1. Create Users

1. Go to "User Management" (Admin only)
2. Click "Add User"
3. Fill in user details:
   - **Username**: Unique username
   - **Email**: User's email address
   - **Password**: Secure password
   - **Role**: Admin or User

### 2. Role Permissions

**Admin Users**:
- Full access to all features
- Can manage users
- Can add/remove baremetal servers
- Can launch/terminate VMs
- Can configure monitoring

**Regular Users**:
- Can launch VMs (up to their quota)
- Can manage their own VMs
- Can view monitoring data
- Cannot manage other users or baremetal servers

## Scaling Your Infrastructure

### Adding More Baremetal Servers

1. **Prepare the Server**:
   - Install required monitoring agents
   - Configure SSH access
   - Ensure network connectivity

2. **Add to System**:
   - Use the "Add Server" function
   - The system will automatically update the resource pool
   - VMs can be launched on the new server

### Launching Multiple VMs

1. **Resource Planning**:
   - Check available resources in the resource pool
   - Plan VM resource allocation
   - Consider load balancing across servers

2. **Batch VM Creation**:
   - Use the API for bulk VM creation
   - Monitor resource usage
   - Set up auto-scaling policies

## Backup and Recovery

### 1. Automated Backups

Run the backup script:

```bash
./scripts/backup.sh
```

This creates a timestamped backup including:
- Database data
- Configuration files
- Shared data (SSH keys, images)
- Monitoring data

### 2. Manual Backup

```bash
# Database backup
docker-compose exec db pg_dump -U admin datacenter > backup.sql

# Configuration backup
cp .env docker-compose.yml backup/

# Shared data backup
cp -r shared/ backup/
```

### 3. Restore from Backup

```bash
./scripts/restore.sh /path/to/backup/directory
```

## Troubleshooting

### Common Issues

1. **Services Won't Start**:
   ```bash
   # Check logs
   docker-compose logs
   
   # Restart services
   docker-compose restart
   ```

2. **Database Connection Issues**:
   ```bash
   # Check database status
   docker-compose exec db pg_isready -U admin
   
   # Reset database
   docker-compose down
   docker volume rm datacenter_postgres_data
   docker-compose up -d
   ```

3. **VM Creation Fails**:
   - Check resource availability
   - Verify image URLs
   - Check network connectivity
   - Review logs: `docker-compose logs api`

4. **Monitoring Not Working**:
   - Verify Prometheus targets
   - Check Grafana data sources
   - Restart monitoring services

### Log Locations

- **Application Logs**: `docker-compose logs api`
- **Database Logs**: `docker-compose logs db`
- **Monitoring Logs**: `docker-compose logs prometheus grafana`
- **System Logs**: `/var/log/syslog`

### Performance Optimization

1. **Database Tuning**:
   - Adjust PostgreSQL settings
   - Monitor query performance
   - Set up connection pooling

2. **Resource Monitoring**:
   - Set up proper alerting thresholds
   - Monitor disk I/O
   - Check network utilization

3. **Scaling Considerations**:
   - Use load balancers for high availability
   - Implement horizontal scaling
   - Set up automated failover

## Security Considerations

### 1. Network Security

- Use VPN for remote access
- Implement proper firewall rules
- Enable SSL/TLS encryption
- Regular security updates

### 2. Access Control

- Use strong passwords
- Enable two-factor authentication
- Regular user access reviews
- Principle of least privilege

### 3. Data Protection

- Encrypt sensitive data
- Regular backups
- Secure key management
- Audit logging

## Support and Maintenance

### Regular Maintenance Tasks

1. **Daily**:
   - Check system health
   - Review alerts
   - Monitor resource usage

2. **Weekly**:
   - Review logs
   - Update security patches
   - Check backup integrity

3. **Monthly**:
   - Performance review
   - Capacity planning
   - Security audit

### Getting Help

- Check the logs first
- Review this documentation
- Check the API documentation at `/docs`
- Create an issue in the repository

## API Usage

### Authentication

All API calls require authentication:

```bash
# Get token
curl -X POST "http://your-server:8000/api/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=admin123"

# Use token in requests
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://your-server:8000/api/baremetals"
```

### Key Endpoints

- **Baremetals**: `/api/baremetals`
- **VMs**: `/api/vms`
- **Monitoring**: `/api/monitoring`
- **Users**: `/api/users`

Full API documentation available at: `http://your-server:8000/docs`

## Conclusion

You now have a fully functional Data Center Management System! The system provides:

- ✅ Baremetal server management
- ✅ VM provisioning and management
- ✅ Real-time monitoring and alerting
- ✅ User management and access control
- ✅ Scalable architecture
- ✅ Backup and recovery capabilities

For additional features and customization, refer to the API documentation and source code.