#!/bin/bash

# Data Center Management System Restore Script

set -e

if [ $# -eq 0 ]; then
    echo "❌ Please provide backup directory path"
    echo "Usage: $0 <backup_directory>"
    exit 1
fi

BACKUP_DIR="$1"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Backup directory does not exist: $BACKUP_DIR"
    exit 1
fi

echo "🔄 Starting restore process from: $BACKUP_DIR"

# Stop services
echo "⏹️  Stopping services..."
docker-compose down

# Restore database
if [ -f "$BACKUP_DIR/database.sql" ]; then
    echo "📊 Restoring database..."
    docker-compose up -d db
    sleep 10
    docker-compose exec -T db psql -U admin -d datacenter -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
    docker-compose exec -T db psql -U admin -d datacenter < "$BACKUP_DIR/database.sql"
else
    echo "⚠️  Database backup not found, skipping database restore"
fi

# Restore configuration files
if [ -f "$BACKUP_DIR/docker-compose.yml" ]; then
    echo "⚙️  Restoring configuration files..."
    cp "$BACKUP_DIR/docker-compose.yml" .
fi

if [ -f "$BACKUP_DIR/.env" ]; then
    echo "⚙️  Restoring environment file..."
    cp "$BACKUP_DIR/.env" .
fi

# Restore shared data
if [ -d "$BACKUP_DIR/shared" ]; then
    echo "📁 Restoring shared data..."
    rm -rf shared
    cp -r "$BACKUP_DIR/shared" .
fi

# Start services
echo "🚀 Starting services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

# Restore monitoring data
if [ -f "$BACKUP_DIR/prometheus_data.tar.gz" ]; then
    echo "📈 Restoring Prometheus data..."
    docker-compose exec -T prometheus tar -xzf - -C / < "$BACKUP_DIR/prometheus_data.tar.gz" || echo "⚠️  Prometheus data restore failed"
fi

if [ -f "$BACKUP_DIR/grafana_data.tar.gz" ]; then
    echo "📈 Restoring Grafana data..."
    docker-compose exec -T grafana tar -xzf - -C / < "$BACKUP_DIR/grafana_data.tar.gz" || echo "⚠️  Grafana data restore failed"
fi

# Restart services to apply changes
echo "🔄 Restarting services..."
docker-compose restart

echo "✅ Restore completed successfully!"
echo "🌐 Access URLs:"
echo "   Frontend Dashboard: http://localhost:3000"
echo "   API Documentation: http://localhost:8000/docs"
echo "   Monitoring (Grafana): http://localhost:3001"