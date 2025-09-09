#!/bin/bash

# Data Center Management System Setup Script

set -e

echo "🚀 Setting up Data Center Management System..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your configuration before running docker-compose up"
fi

# Create shared directories
echo "📁 Creating shared directories..."
mkdir -p shared/ssh_keys
mkdir -p shared/images
mkdir -p shared/logs

# Generate default SSH key if it doesn't exist
if [ ! -f shared/ssh_keys/default_key ]; then
    echo "🔑 Generating default SSH key..."
    ssh-keygen -t rsa -b 4096 -f shared/ssh_keys/default_key -N "" -C "datacenter-default"
    chmod 600 shared/ssh_keys/default_key
    chmod 644 shared/ssh_keys/default_key.pub
fi

# Set proper permissions
echo "🔐 Setting proper permissions..."
chmod 755 shared/ssh_keys
chmod 755 shared/images
chmod 755 shared/logs

# Build and start services
echo "🏗️  Building and starting services..."
docker-compose build
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

# Check if services are running
echo "🔍 Checking service status..."
docker-compose ps

# Display access information
echo ""
echo "✅ Setup completed successfully!"
echo ""
echo "🌐 Access URLs:"
echo "   Frontend Dashboard: http://localhost:3000"
echo "   API Documentation: http://localhost:8000/docs"
echo "   Monitoring (Grafana): http://localhost:3001"
echo "   Prometheus: http://localhost:9090"
echo "   MySQL Database: localhost:3306"
echo ""
echo "🔑 Default credentials:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "📚 Next steps:"
echo "   1. Access the frontend dashboard at http://localhost:3000"
echo "   2. Add your first baremetal server with OS selection and storage mounts"
echo "   3. Configure monitoring alerts"
echo "   4. Launch your first VM with pre-configured images"
echo ""
echo "🆕 New Features:"
echo "   - MySQL database for better performance"
echo "   - Multiple storage mount points per baremetal"
echo "   - OS type selection (RHEL8, Rocky Linux 9, Ubuntu 20/22)"
echo "   - Enhanced GUI with better resource management"
echo ""
echo "🛠️  Useful commands:"
echo "   View logs: docker-compose logs -f"
echo "   Stop services: docker-compose down"
echo "   Restart services: docker-compose restart"
echo "   Update services: docker-compose pull && docker-compose up -d"