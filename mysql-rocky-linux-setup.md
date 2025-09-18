# MySQL Setup on Rocky Linux 9 - Complete Guide

This guide provides comprehensive instructions for setting up MySQL on Rocky Linux 9 machines, including both manual and automated approaches.

## Prerequisites

- Rocky Linux 9 machine(s) with root or sudo access
- Private key for SSH access
- Network connectivity to download packages
- Basic knowledge of Linux commands

## Method 1: Manual Setup (Step-by-Step)

### Step 1: Update System Packages

```bash
# Update package cache and upgrade system
sudo dnf update -y

# Install EPEL repository for additional packages
sudo dnf install epel-release -y
```

### Step 2: Install MySQL Server

```bash
# Install MySQL 8.0 server
sudo dnf install mysql-server -y

# Start and enable MySQL service
sudo systemctl start mysqld
sudo systemctl enable mysqld

# Check service status
sudo systemctl status mysqld
```

### Step 3: Secure MySQL Installation

```bash
# Run MySQL secure installation script
sudo mysql_secure_installation
```

**Interactive prompts during secure installation:**
- Set root password: `Y` (recommended)
- Remove anonymous users: `Y`
- Disallow root login remotely: `Y` (recommended for security)
- Remove test database: `Y`
- Reload privilege tables: `Y`

### Step 4: Configure MySQL

```bash
# Create MySQL configuration directory
sudo mkdir -p /etc/mysql/conf.d

# Create custom configuration file
sudo tee /etc/mysql/conf.d/custom.cnf > /dev/null <<EOF
[mysqld]
# Basic settings
bind-address = 0.0.0.0
port = 3306
max_connections = 200
max_allowed_packet = 64M

# InnoDB settings
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
innodb_flush_log_at_trx_commit = 2

# Logging
log-error = /var/log/mysqld.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql-slow.log
long_query_time = 2

# Character set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4

[client]
default-character-set = utf8mb4
EOF

# Restart MySQL to apply configuration
sudo systemctl restart mysqld
```

### Step 5: Create Database and User

```bash
# Login to MySQL as root
sudo mysql -u root -p

# Run these commands in MySQL prompt:
```

```sql
-- Create a new database
CREATE DATABASE myapp_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create a new user
CREATE USER 'myapp_user'@'%' IDENTIFIED BY 'SecurePassword123!';

-- Grant privileges to the user
GRANT ALL PRIVILEGES ON myapp_db.* TO 'myapp_user'@'%';

-- Create a user for local access only
CREATE USER 'myapp_user'@'localhost' IDENTIFIED BY 'SecurePassword123!';
GRANT ALL PRIVILEGES ON myapp_db.* TO 'myapp_user'@'localhost';

-- Flush privileges
FLUSH PRIVILEGES;

-- Show databases to verify
SHOW DATABASES;

-- Exit MySQL
EXIT;
```

### Step 6: Configure Firewall

```bash
# Open MySQL port in firewall
sudo firewall-cmd --permanent --add-port=3306/tcp
sudo firewall-cmd --reload

# Verify firewall rules
sudo firewall-cmd --list-ports
```

### Step 7: Test Connection

```bash
# Test local connection
mysql -u myapp_user -p -h localhost myapp_db

# Test remote connection (from another machine)
mysql -u myapp_user -p -h <server_ip> myapp_db
```

## Method 2: Automated Setup Script

### Create Setup Script

Create a script file `mysql-setup.sh`:

```bash
#!/bin/bash

# MySQL Setup Script for Rocky Linux 9
# Usage: ./mysql-setup.sh [database_name] [username] [password]

set -e

# Default values
DB_NAME=${1:-"myapp_db"}
DB_USER=${2:-"myapp_user"}
DB_PASS=${3:-"SecurePassword123!"}
MYSQL_ROOT_PASS=${4:-"RootPassword123!"}

echo "Starting MySQL setup on Rocky Linux 9..."
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "Password: [HIDDEN]"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Update system
echo "Updating system packages..."
sudo dnf update -y
sudo dnf install epel-release -y

# Install MySQL
echo "Installing MySQL server..."
sudo dnf install mysql-server -y

# Start and enable MySQL
echo "Starting MySQL service..."
sudo systemctl start mysqld
sudo systemctl enable mysqld

# Wait for MySQL to start
sleep 5

# Get temporary root password
TEMP_PASS=$(sudo grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}' | tail -1)

if [ -z "$TEMP_PASS" ]; then
    echo "No temporary password found. MySQL might already be configured."
    TEMP_PASS=""
fi

# Configure MySQL
echo "Configuring MySQL..."

# Create configuration file
sudo tee /etc/mysql/conf.d/custom.cnf > /dev/null <<EOF
[mysqld]
bind-address = 0.0.0.0
port = 3306
max_connections = 200
max_allowed_packet = 64M
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
innodb_flush_log_at_trx_commit = 2
log-error = /var/log/mysqld.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql-slow.log
long_query_time = 2
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4

[client]
default-character-set = utf8mb4
EOF

# Restart MySQL
sudo systemctl restart mysqld

# Configure MySQL security
echo "Configuring MySQL security..."

# Create SQL commands file
cat > /tmp/mysql_setup.sql <<EOF
-- Set root password
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';

-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';

-- Remove test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Create application database
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create application user
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';

-- Grant privileges
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';

-- Flush privileges
FLUSH PRIVILEGES;
EOF

# Execute SQL commands
if [ -n "$TEMP_PASS" ]; then
    mysql -u root -p"$TEMP_PASS" --connect-expired-password < /tmp/mysql_setup.sql
else
    mysql -u root -p"$MYSQL_ROOT_PASS" < /tmp/mysql_setup.sql
fi

# Configure firewall
echo "Configuring firewall..."
sudo firewall-cmd --permanent --add-port=3306/tcp
sudo firewall-cmd --reload

# Clean up
rm -f /tmp/mysql_setup.sql

echo "MySQL setup completed successfully!"
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "Root password: $MYSQL_ROOT_PASS"
echo "MySQL is running on port 3306"
echo ""
echo "Test connection with:"
echo "mysql -u $DB_USER -p -h localhost $DB_NAME"
```

### Make Script Executable and Run

```bash
# Make script executable
chmod +x mysql-setup.sh

# Run the script
./mysql-setup.sh

# Or with custom parameters
./mysql-setup.sh mydatabase myuser mypassword rootpass
```

## Method 3: Remote Execution from Mac

### Prerequisites on Mac

```bash
# Install required tools (if not already installed)
brew install mysql-client
```

### Create Remote Execution Script

Create `remote-mysql-setup.sh`:

```bash
#!/bin/bash

# Remote MySQL Setup Script
# Usage: ./remote-mysql-setup.sh <host_ip> <ssh_key> [database_name] [username] [password]

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <host_ip> <ssh_key> [database_name] [username] [password]"
    echo "Example: $0 192.168.1.100 ~/.ssh/id_rsa myapp_db myuser mypass"
    exit 1
fi

HOST_IP=$1
SSH_KEY=$2
DB_NAME=${3:-"myapp_db"}
DB_USER=${4:-"myapp_user"}
DB_PASS=${5:-"SecurePassword123!"}

echo "Setting up MySQL on remote host: $HOST_IP"
echo "Using SSH key: $SSH_KEY"

# Create the setup script content
cat > /tmp/mysql-setup-remote.sh <<'EOF'
#!/bin/bash

set -e

DB_NAME=$1
DB_USER=$2
DB_PASS=$3
MYSQL_ROOT_PASS=$4

echo "Starting MySQL setup on Rocky Linux 9..."

# Update system
sudo dnf update -y
sudo dnf install epel-release -y

# Install MySQL
sudo dnf install mysql-server -y

# Start and enable MySQL
sudo systemctl start mysqld
sudo systemctl enable mysqld

# Wait for MySQL to start
sleep 5

# Get temporary root password
TEMP_PASS=$(sudo grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}' | tail -1)

# Create configuration file
sudo tee /etc/mysql/conf.d/custom.cnf > /dev/null <<'MYSQLCONF'
[mysqld]
bind-address = 0.0.0.0
port = 3306
max_connections = 200
max_allowed_packet = 64M
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
innodb_flush_log_at_trx_commit = 2
log-error = /var/log/mysqld.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql-slow.log
long_query_time = 2
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4

[client]
default-character-set = utf8mb4
MYSQLCONF

# Restart MySQL
sudo systemctl restart mysqld

# Create SQL setup commands
cat > /tmp/mysql_setup.sql <<SQLSETUP
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQLSETUP

# Execute SQL commands
if [ -n "$TEMP_PASS" ]; then
    mysql -u root -p"$TEMP_PASS" --connect-expired-password < /tmp/mysql_setup.sql
else
    mysql -u root -p"$MYSQL_ROOT_PASS" < /tmp/mysql_setup.sql
fi

# Configure firewall
sudo firewall-cmd --permanent --add-port=3306/tcp
sudo firewall-cmd --reload

# Clean up
rm -f /tmp/mysql_setup.sql

echo "MySQL setup completed successfully!"
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "Root password: $MYSQL_ROOT_PASS"
EOF

# Copy script to remote host
scp -i "$SSH_KEY" /tmp/mysql-setup-remote.sh root@$HOST_IP:/tmp/

# Execute script on remote host
ssh -i "$SSH_KEY" root@$HOST_IP "chmod +x /tmp/mysql-setup-remote.sh && /tmp/mysql-setup-remote.sh '$DB_NAME' '$DB_USER' '$DB_PASS' 'RootPassword123!'"

# Clean up local temp file
rm -f /tmp/mysql-setup-remote.sh

echo "Remote MySQL setup completed!"
echo "You can now connect to MySQL on $HOST_IP:3306"
```

### Execute Remote Setup

```bash
# Make script executable
chmod +x remote-mysql-setup.sh

# Run remote setup
./remote-mysql-setup.sh 192.168.1.100 ~/.ssh/id_rsa myapp_db myuser mypassword

# Test remote connection
mysql -h 192.168.1.100 -u myuser -p myapp_db
```

## Method 4: Multiple Machine Setup

### Create Host List File

Create `hosts.txt`:

```
192.168.1.100
192.168.1.101
192.168.1.102
192.168.1.103
```

### Create Batch Setup Script

Create `batch-mysql-setup.sh`:

```bash
#!/bin/bash

# Batch MySQL Setup Script
# Usage: ./batch-mysql-setup.sh <hosts_file> <ssh_key>

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <hosts_file> <ssh_key>"
    echo "Example: $0 hosts.txt ~/.ssh/id_rsa"
    exit 1
fi

HOSTS_FILE=$1
SSH_KEY=$2

if [ ! -f "$HOSTS_FILE" ]; then
    echo "Hosts file $HOSTS_FILE not found!"
    exit 1
fi

echo "Starting batch MySQL setup..."
echo "Hosts file: $HOSTS_FILE"
echo "SSH key: $SSH_KEY"
echo ""

# Read hosts and setup MySQL on each
while IFS= read -r host; do
    if [ -n "$host" ] && [[ ! "$host" =~ ^# ]]; then
        echo "Setting up MySQL on $host..."
        
        # Use the remote setup script
        ./remote-mysql-setup.sh "$host" "$SSH_KEY" "myapp_db" "myapp_user" "SecurePassword123!"
        
        echo "Completed setup on $host"
        echo "----------------------------------------"
    fi
done < "$HOSTS_FILE"

echo "Batch MySQL setup completed for all hosts!"
```

### Execute Batch Setup

```bash
# Make script executable
chmod +x batch-mysql-setup.sh

# Run batch setup
./batch-mysql-setup.sh hosts.txt ~/.ssh/id_rsa
```

## Security Best Practices

### 1. Firewall Configuration

```bash
# Allow only specific IPs to access MySQL
sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='192.168.1.0/24' port protocol='tcp' port='3306' accept"
sudo firewall-cmd --permanent --remove-port=3306/tcp
sudo firewall-cmd --reload
```

### 2. SSL Configuration

```bash
# Generate SSL certificates
sudo mysql_ssl_rsa_setup --uid=mysql

# Add SSL configuration to MySQL config
sudo tee -a /etc/mysql/conf.d/custom.cnf > /dev/null <<EOF

# SSL Configuration
ssl-ca=/var/lib/mysql/ca.pem
ssl-cert=/var/lib/mysql/server-cert.pem
ssl-key=/var/lib/mysql/server-key.pem
require_secure_transport=ON
EOF

sudo systemctl restart mysqld
```

### 3. User Management

```sql
-- Create read-only user
CREATE USER 'readonly_user'@'%' IDENTIFIED BY 'ReadOnlyPass123!';
GRANT SELECT ON myapp_db.* TO 'readonly_user'@'%';

-- Create backup user
CREATE USER 'backup_user'@'localhost' IDENTIFIED BY 'BackupPass123!';
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON myapp_db.* TO 'backup_user'@'localhost';

-- Remove unnecessary privileges
REVOKE ALL PRIVILEGES ON *.* FROM 'myapp_user'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp_db.* TO 'myapp_user'@'%';
```

## Monitoring and Maintenance

### 1. Enable MySQL Logging

```bash
# Create log directory
sudo mkdir -p /var/log/mysql
sudo chown mysql:mysql /var/log/mysql

# Add logging configuration
sudo tee -a /etc/mysql/conf.d/custom.cnf > /dev/null <<EOF

# Logging
general_log = 1
general_log_file = /var/log/mysql/mysql-general.log
log_queries_not_using_indexes = 1
log_slow_admin_statements = 1
EOF

sudo systemctl restart mysqld
```

### 2. Backup Script

Create `mysql-backup.sh`:

```bash
#!/bin/bash

# MySQL Backup Script
# Usage: ./mysql-backup.sh [database_name]

DB_NAME=${1:-"myapp_db"}
BACKUP_DIR="/var/backups/mysql"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_$DATE.sql"

# Create backup directory
sudo mkdir -p "$BACKUP_DIR"

# Create backup
mysqldump -u root -p"RootPassword123!" --single-transaction --routines --triggers "$DB_NAME" > "$BACKUP_FILE"

# Compress backup
gzip "$BACKUP_FILE"

echo "Backup created: ${BACKUP_FILE}.gz"

# Remove backups older than 7 days
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +7 -delete

echo "Old backups cleaned up"
```

### 3. Performance Monitoring

```sql
-- Check MySQL status
SHOW STATUS;

-- Check slow queries
SHOW VARIABLES LIKE 'slow_query_log%';

-- Check connections
SHOW STATUS LIKE 'Connections';
SHOW STATUS LIKE 'Max_used_connections';

-- Check InnoDB status
SHOW ENGINE INNODB STATUS;
```

## Troubleshooting

### Common Issues and Solutions

1. **MySQL won't start:**
```bash
# Check error logs
sudo journalctl -u mysqld
sudo tail -f /var/log/mysqld.log

# Check configuration
sudo mysqld --help --verbose | head -20
```

2. **Connection refused:**
```bash
# Check if MySQL is running
sudo systemctl status mysqld

# Check port binding
sudo netstat -tlnp | grep 3306

# Check firewall
sudo firewall-cmd --list-ports
```

3. **Permission denied:**
```bash
# Check MySQL user permissions
mysql -u root -p -e "SELECT user, host FROM mysql.user;"

# Reset root password
sudo systemctl stop mysqld
sudo mysqld_safe --skip-grant-tables &
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'newpassword';"
sudo systemctl restart mysqld
```

## Summary

This guide provides multiple approaches for setting up MySQL on Rocky Linux 9:

1. **Manual Setup**: Step-by-step commands for single machine setup
2. **Automated Script**: Single script for automated setup
3. **Remote Execution**: Setup from Mac to remote Rocky Linux machines
4. **Batch Setup**: Setup multiple machines simultaneously

Choose the method that best fits your needs. The automated approaches are recommended for production environments to ensure consistency across multiple machines.

Remember to:
- Change default passwords
- Configure firewall rules appropriately
- Enable SSL for production environments
- Set up regular backups
- Monitor MySQL performance and logs