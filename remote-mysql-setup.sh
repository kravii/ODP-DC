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