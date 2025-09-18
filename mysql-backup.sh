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