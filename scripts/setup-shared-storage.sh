#!/bin/bash

# Setup Shared Storage Configuration Script
# Configures 1.8TB RAID storage for Kubernetes and VM provisioning

set -euo pipefail

# Configuration
SHARED_STORAGE_ROOT="/shared-storage"
STORAGE_TOTAL_SIZE=1800  # 1.8TB in GB
VM_STORAGE_ALLOCATION=1000  # 1TB for VMs
K8S_STORAGE_ALLOCATION=500  # 500GB for Kubernetes
MONITORING_ALLOCATION=200   # 200GB for monitoring
BACKUP_ALLOCATION=80        # 80GB for backups
LOG_ALLOCATION=20          # 20GB for logs

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check available disk space
check_disk_space() {
    log_info "Checking available disk space..."
    
    # Get root filesystem usage
    ROOT_USAGE=$(df -BG / | tail -1 | awk '{print $3}' | sed 's/G//')
    ROOT_AVAILABLE=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
    ROOT_TOTAL=$(df -BG / | tail -1 | awk '{print $2}' | sed 's/G//')
    
    log_info "Root filesystem: ${ROOT_TOTAL}GB total, ${ROOT_USAGE}GB used, ${ROOT_AVAILABLE}GB available"
    
    if [[ $ROOT_AVAILABLE -lt $STORAGE_TOTAL_SIZE ]]; then
        log_warning "Available space (${ROOT_AVAILABLE}GB) is less than required (${STORAGE_TOTAL_SIZE}GB)"
        log_warning "Proceeding with available space..."
    fi
}

# Create storage directory structure
create_storage_structure() {
    log_info "Creating shared storage directory structure..."
    
    # Main directories
    local directories=(
        "$SHARED_STORAGE_ROOT"
        "$SHARED_STORAGE_ROOT/k8s-pv"
        "$SHARED_STORAGE_ROOT/vm-storage"
        "$SHARED_STORAGE_ROOT/monitoring"
        "$SHARED_STORAGE_ROOT/backups"
        "$SHARED_STORAGE_ROOT/logs"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
        log_success "Created directory: $dir"
    done
    
    # VM storage subdirectories
    local vm_subdirs=(
        "$SHARED_STORAGE_ROOT/vm-storage/images"
        "$SHARED_STORAGE_ROOT/vm-storage/templates"
        "$SHARED_STORAGE_ROOT/vm-storage/instances"
        "$SHARED_STORAGE_ROOT/vm-storage/snapshots"
    )
    
    for dir in "${vm_subdirs[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
        log_success "Created VM subdirectory: $dir"
    done
    
    # Kubernetes storage subdirectories
    local k8s_subdirs=(
        "$SHARED_STORAGE_ROOT/k8s-pv/databases"
        "$SHARED_STORAGE_ROOT/k8s-pv/applications"
        "$SHARED_STORAGE_ROOT/k8s-pv/logs"
    )
    
    for dir in "${k8s_subdirs[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
        log_success "Created K8s subdirectory: $dir"
    done
    
    # Monitoring subdirectories
    local monitoring_subdirs=(
        "$SHARED_STORAGE_ROOT/monitoring/prometheus"
        "$SHARED_STORAGE_ROOT/monitoring/grafana"
        "$SHARED_STORAGE_ROOT/monitoring/alertmanager"
    )
    
    for dir in "${monitoring_subdirs[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
        log_success "Created monitoring subdirectory: $dir"
    done
}

# Set proper ownership and permissions
set_permissions() {
    log_info "Setting proper ownership and permissions..."
    
    # Set ownership for Kubernetes (user/group 1000)
    chown -R 1000:1000 "$SHARED_STORAGE_ROOT/k8s-pv"
    chown -R 1000:1000 "$SHARED_STORAGE_ROOT/monitoring"
    
    # Set ownership for VM storage (user/group 1001)
    chown -R 1001:1001 "$SHARED_STORAGE_ROOT/vm-storage"
    
    # Set ownership for system directories
    chown -R root:root "$SHARED_STORAGE_ROOT/backups"
    chown -R root:root "$SHARED_STORAGE_ROOT/logs"
    
    log_success "Permissions set successfully"
}

# Create storage configuration file
create_storage_config() {
    log_info "Creating storage configuration file..."
    
    cat > "$SHARED_STORAGE_ROOT/storage-config.yaml" << EOF
# Shared Storage Configuration
# Generated on $(date)

storage:
  root_path: "$SHARED_STORAGE_ROOT"
  total_size_gb: $STORAGE_TOTAL_SIZE
  
  allocations:
    vm_storage:
      path: "$SHARED_STORAGE_ROOT/vm-storage"
      size_gb: $VM_STORAGE_ALLOCATION
      owner: "1001:1001"
    
    k8s_storage:
      path: "$SHARED_STORAGE_ROOT/k8s-pv"
      size_gb: $K8S_STORAGE_ALLOCATION
      owner: "1000:1000"
    
    monitoring:
      path: "$SHARED_STORAGE_ROOT/monitoring"
      size_gb: $MONITORING_ALLOCATION
      owner: "1000:1000"
    
    backups:
      path: "$SHARED_STORAGE_ROOT/backups"
      size_gb: $BACKUP_ALLOCATION
      owner: "root:root"
    
    logs:
      path: "$SHARED_STORAGE_ROOT/logs"
      size_gb: $LOG_ALLOCATION
      owner: "root:root"

  cleanup:
    backup_retention_days: 30
    log_retention_days: 7
    snapshot_retention_days: 90

  monitoring:
    usage_warning_threshold: 75
    usage_critical_threshold: 90
    health_check_interval: 300
EOF
    
    chmod 644 "$SHARED_STORAGE_ROOT/storage-config.yaml"
    log_success "Storage configuration file created"
}

# Create storage monitoring script
create_monitoring_script() {
    log_info "Creating storage monitoring script..."
    
    cat > "$SHARED_STORAGE_ROOT/monitor-storage.sh" << 'EOF'
#!/bin/bash

# Storage Monitoring Script
# Monitors shared storage usage and health

SHARED_STORAGE_ROOT="/shared-storage"
CONFIG_FILE="$SHARED_STORAGE_ROOT/storage-config.yaml"

# Get storage usage for a directory
get_directory_usage() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        du -s "$dir" 2>/dev/null | awk '{print $1}' || echo "0"
    else
        echo "0"
    fi
}

# Convert KB to GB
kb_to_gb() {
    local kb="$1"
    echo "scale=2; $kb / 1024 / 1024" | bc
}

# Get storage statistics
get_storage_stats() {
    local stats="{}"
    
    # VM Storage
    vm_usage_kb=$(get_directory_usage "$SHARED_STORAGE_ROOT/vm-storage")
    vm_usage_gb=$(kb_to_gb "$vm_usage_kb")
    
    # K8s Storage
    k8s_usage_kb=$(get_directory_usage "$SHARED_STORAGE_ROOT/k8s-pv")
    k8s_usage_gb=$(kb_to_gb "$k8s_usage_kb")
    
    # Monitoring Storage
    monitoring_usage_kb=$(get_directory_usage "$SHARED_STORAGE_ROOT/monitoring")
    monitoring_usage_gb=$(kb_to_gb "$monitoring_usage_kb")
    
    # Backup Storage
    backup_usage_kb=$(get_directory_usage "$SHARED_STORAGE_ROOT/backups")
    backup_usage_gb=$(kb_to_gb "$backup_usage_kb")
    
    # Log Storage
    log_usage_kb=$(get_directory_usage "$SHARED_STORAGE_ROOT/logs")
    log_usage_gb=$(kb_to_gb "$log_usage_kb")
    
    # Total usage
    total_usage_kb=$((vm_usage_kb + k8s_usage_kb + monitoring_usage_kb + backup_usage_kb + log_usage_kb))
    total_usage_gb=$(kb_to_gb "$total_usage_kb")
    
    # Get root filesystem info
    root_info=$(df -BG / | tail -1)
    root_total=$(echo "$root_info" | awk '{print $2}' | sed 's/G//')
    root_used=$(echo "$root_info" | awk '{print $3}' | sed 's/G//')
    root_available=$(echo "$root_info" | awk '{print $4}' | sed 's/G//')
    
    cat << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "vm_storage": {
    "used_gb": $vm_usage_gb,
    "limit_gb": 1000,
    "available_gb": $(echo "scale=2; 1000 - $vm_usage_gb" | bc),
    "usage_percentage": $(echo "scale=2; ($vm_usage_gb / 1000) * 100" | bc)
  },
  "k8s_storage": {
    "used_gb": $k8s_usage_gb,
    "limit_gb": 500,
    "available_gb": $(echo "scale=2; 500 - $k8s_usage_gb" | bc),
    "usage_percentage": $(echo "scale=2; ($k8s_usage_gb / 500) * 100" | bc)
  },
  "monitoring": {
    "used_gb": $monitoring_usage_gb,
    "limit_gb": 200,
    "available_gb": $(echo "scale=2; 200 - $monitoring_usage_gb" | bc),
    "usage_percentage": $(echo "scale=2; ($monitoring_usage_gb / 200) * 100" | bc)
  },
  "backups": {
    "used_gb": $backup_usage_gb,
    "limit_gb": 80,
    "available_gb": $(echo "scale=2; 80 - $backup_usage_gb" | bc),
    "usage_percentage": $(echo "scale=2; ($backup_usage_gb / 80) * 100" | bc)
  },
  "logs": {
    "used_gb": $log_usage_gb,
    "limit_gb": 20,
    "available_gb": $(echo "scale=2; 20 - $log_usage_gb" | bc),
    "usage_percentage": $(echo "scale=2; ($log_usage_gb / 20) * 100" | bc)
  },
  "total": {
    "used_gb": $total_usage_gb,
    "total_gb": $root_total,
    "available_gb": $root_available,
    "usage_percentage": $(echo "scale=2; ($root_used / $root_total) * 100" | bc)
  }
}
EOF
}

# Check storage health
check_storage_health() {
    local stats=$(get_storage_stats)
    local status="healthy"
    local warnings=()
    local errors=()
    
    # Check each storage component
    echo "$stats" | jq -r '.vm_storage.usage_percentage' | while read -r usage; do
        if (( $(echo "$usage > 90" | bc -l) )); then
            echo "CRITICAL: VM storage is ${usage}% full"
        elif (( $(echo "$usage > 75" | bc -l) )); then
            echo "WARNING: VM storage is ${usage}% full"
        fi
    done
    
    echo "$stats" | jq -r '.k8s_storage.usage_percentage' | while read -r usage; do
        if (( $(echo "$usage > 90" | bc -l) )); then
            echo "CRITICAL: K8s storage is ${usage}% full"
        elif (( $(echo "$usage > 75" | bc -l) )); then
            echo "WARNING: K8s storage is ${usage}% full"
        fi
    done
    
    echo "$stats" | jq -r '.total.usage_percentage' | while read -r usage; do
        if (( $(echo "$usage > 95" | bc -l) )); then
            echo "CRITICAL: Total storage is ${usage}% full"
        elif (( $(echo "$usage > 90" | bc -l) )); then
            echo "WARNING: Total storage is ${usage}% full"
        fi
    done
}

# Main execution
case "${1:-stats}" in
    "stats")
        get_storage_stats
        ;;
    "health")
        check_storage_health
        ;;
    "usage")
        echo "Storage Usage Summary:"
        echo "===================="
        df -h "$SHARED_STORAGE_ROOT"
        echo ""
        echo "Directory Usage:"
        du -sh "$SHARED_STORAGE_ROOT"/*
        ;;
    *)
        echo "Usage: $0 {stats|health|usage}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$SHARED_STORAGE_ROOT/monitor-storage.sh"
    log_success "Storage monitoring script created"
}

# Create cleanup script
create_cleanup_script() {
    log_info "Creating storage cleanup script..."
    
    cat > "$SHARED_STORAGE_ROOT/cleanup-storage.sh" << 'EOF'
#!/bin/bash

# Storage Cleanup Script
# Cleans up old files and optimizes storage usage

SHARED_STORAGE_ROOT="/shared-storage"
BACKUP_RETENTION_DAYS=30
LOG_RETENTION_DAYS=7
SNAPSHOT_RETENTION_DAYS=90

# Clean up old backup files
cleanup_backups() {
    echo "Cleaning up old backup files (older than $BACKUP_RETENTION_DAYS days)..."
    find "$SHARED_STORAGE_ROOT/backups" -type f -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null || true
    echo "Backup cleanup completed"
}

# Clean up old log files
cleanup_logs() {
    echo "Cleaning up old log files (older than $LOG_RETENTION_DAYS days)..."
    find "$SHARED_STORAGE_ROOT/logs" -type f -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true
    echo "Log cleanup completed"
}

# Clean up old VM snapshots
cleanup_snapshots() {
    echo "Cleaning up old VM snapshots (older than $SNAPSHOT_RETENTION_DAYS days)..."
    find "$SHARED_STORAGE_ROOT/vm-storage/snapshots" -type f -mtime +$SNAPSHOT_RETENTION_DAYS -delete 2>/dev/null || true
    echo "Snapshot cleanup completed"
}

# Optimize storage
optimize_storage() {
    echo "Optimizing storage..."
    
    # Trim filesystem if supported
    if command -v fstrim >/dev/null 2>&1; then
        fstrim "$SHARED_STORAGE_ROOT" 2>/dev/null || true
        echo "Filesystem trimmed"
    fi
    
    # Clean up temporary files
    find "$SHARED_STORAGE_ROOT" -name "*.tmp" -delete 2>/dev/null || true
    find "$SHARED_STORAGE_ROOT" -name "*.temp" -delete 2>/dev/null || true
    
    echo "Storage optimization completed"
}

# Main cleanup function
main() {
    echo "Starting storage cleanup..."
    echo "=========================="
    
    cleanup_backups
    cleanup_logs
    cleanup_snapshots
    optimize_storage
    
    echo ""
    echo "Storage cleanup completed successfully"
    echo "Current usage:"
    "$SHARED_STORAGE_ROOT/monitor-storage.sh" usage
}

# Run cleanup
main "$@"
EOF
    
    chmod +x "$SHARED_STORAGE_ROOT/cleanup-storage.sh"
    log_success "Storage cleanup script created"
}

# Create systemd service for storage monitoring
create_monitoring_service() {
    log_info "Creating systemd service for storage monitoring..."
    
    cat > /etc/systemd/system/shared-storage-monitor.service << EOF
[Unit]
Description=Shared Storage Monitor
After=network.target

[Service]
Type=oneshot
ExecStart=$SHARED_STORAGE_ROOT/monitor-storage.sh health
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/shared-storage-monitor.timer << EOF
[Unit]
Description=Run Shared Storage Monitor every 5 minutes
Requires=shared-storage-monitor.service

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable shared-storage-monitor.timer
    systemctl start shared-storage-monitor.timer
    
    log_success "Storage monitoring service created and started"
}

# Create cron job for cleanup
create_cleanup_cron() {
    log_info "Creating cron job for storage cleanup..."
    
    # Add cleanup job to run daily at 2 AM
    (crontab -l 2>/dev/null; echo "0 2 * * * $SHARED_STORAGE_ROOT/cleanup-storage.sh >> /var/log/storage-cleanup.log 2>&1") | crontab -
    
    log_success "Storage cleanup cron job created"
}

# Display storage information
display_storage_info() {
    log_info "Storage configuration completed successfully!"
    echo ""
    echo "=========================================="
    echo "SHARED STORAGE CONFIGURATION SUMMARY"
    echo "=========================================="
    echo ""
    echo "Storage Root: $SHARED_STORAGE_ROOT"
    echo "Total Allocation: ${STORAGE_TOTAL_SIZE}GB"
    echo ""
    echo "Storage Allocations:"
    echo "  - VM Storage: ${VM_STORAGE_ALLOCATION}GB"
    echo "  - Kubernetes: ${K8S_STORAGE_ALLOCATION}GB"
    echo "  - Monitoring: ${MONITORING_ALLOCATION}GB"
    echo "  - Backups: ${BACKUP_ALLOCATION}GB"
    echo "  - Logs: ${LOG_ALLOCATION}GB"
    echo ""
    echo "Directory Structure:"
    echo "  $SHARED_STORAGE_ROOT/"
    echo "  ├── k8s-pv/          # Kubernetes Persistent Volumes"
    echo "  ├── vm-storage/      # VM Storage"
    echo "  ├── monitoring/      # Monitoring Data"
    echo "  ├── backups/         # Backup Storage"
    echo "  └── logs/            # Log Storage"
    echo ""
    echo "Management Scripts:"
    echo "  - Monitor: $SHARED_STORAGE_ROOT/monitor-storage.sh"
    echo "  - Cleanup: $SHARED_STORAGE_ROOT/cleanup-storage.sh"
    echo "  - Config: $SHARED_STORAGE_ROOT/storage-config.yaml"
    echo ""
    echo "Services:"
    echo "  - Monitoring Timer: shared-storage-monitor.timer"
    echo "  - Cleanup Cron: Daily at 2 AM"
    echo ""
    echo "Usage Commands:"
    echo "  # Check storage usage"
    echo "  $SHARED_STORAGE_ROOT/monitor-storage.sh usage"
    echo ""
    echo "  # Get storage statistics"
    echo "  $SHARED_STORAGE_ROOT/monitor-storage.sh stats"
    echo ""
    echo "  # Check storage health"
    echo "  $SHARED_STORAGE_ROOT/monitor-storage.sh health"
    echo ""
    echo "  # Run cleanup"
    echo "  $SHARED_STORAGE_ROOT/cleanup-storage.sh"
    echo ""
}

# Main execution
main() {
    log_info "Starting shared storage configuration..."
    echo "=========================================="
    
    check_root
    check_disk_space
    create_storage_structure
    set_permissions
    create_storage_config
    create_monitoring_script
    create_cleanup_script
    create_monitoring_service
    create_cleanup_cron
    display_storage_info
    
    log_success "Shared storage configuration completed successfully!"
}

# Run main function
main "$@"