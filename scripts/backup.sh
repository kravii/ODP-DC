#!/bin/bash

# Data Center Management System Backup Script

set -e

BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "🔄 Starting backup process..."

# Backup database
echo "📊 Backing up database..."
docker-compose exec -T db pg_dump -U admin datacenter > "$BACKUP_DIR/database.sql"

# Backup configuration files
echo "⚙️  Backing up configuration files..."
cp docker-compose.yml "$BACKUP_DIR/"
cp .env "$BACKUP_DIR/" 2>/dev/null || echo "⚠️  .env file not found"

# Backup shared data
echo "📁 Backing up shared data..."
cp -r shared "$BACKUP_DIR/"

# Backup monitoring data
echo "📈 Backing up monitoring data..."
docker-compose exec -T prometheus tar -czf - /prometheus > "$BACKUP_DIR/prometheus_data.tar.gz" 2>/dev/null || echo "⚠️  Prometheus data backup failed"
docker-compose exec -T grafana tar -czf - /var/lib/grafana > "$BACKUP_DIR/grafana_data.tar.gz" 2>/dev/null || echo "⚠️  Grafana data backup failed"

# Create backup info file
cat > "$BACKUP_DIR/backup_info.txt" << EOF
Backup created: $(date)
System version: Data Center Management System v1.0.0
Docker Compose version: $(docker-compose --version)
Backup size: $(du -sh "$BACKUP_DIR" | cut -f1)
EOF

echo "✅ Backup completed successfully!"
echo "📦 Backup location: $BACKUP_DIR"
echo "💾 Backup size: $(du -sh "$BACKUP_DIR" | cut -f1)"