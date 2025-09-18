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