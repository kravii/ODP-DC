#!/bin/bash

# Quick Start Script for Shared Storage with Separate Allocations
# Sets up 1.8TB storage split into 1.5TB for /k8s-storage and 1.5TB for /vm-storage

set -euo pipefail

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

# Display welcome message
display_welcome() {
    echo ""
    echo "=========================================="
    echo "  SHARED STORAGE QUICK START"
    echo "=========================================="
    echo ""
    echo "This script will set up shared storage with separate allocations:"
    echo "  • K8s Storage: 1.5TB for Kubernetes workloads"
    echo "  • VM Storage: 1.5TB for VM provisioning"
    echo "  • System Reserve: 300GB for system operations"
    echo ""
    echo "Storage Allocation (1.8TB total per server):"
    echo "  K8s Storage (1.5TB):"
    echo "    - Databases: /shared-storage/k8s-storage/databases"
    echo "    - Applications: /shared-storage/k8s-storage/applications"
    echo "    - Monitoring: /shared-storage/k8s-storage/monitoring"
    echo "    - Logs: /shared-storage/k8s-storage/logs"
    echo "    - Backups: /shared-storage/k8s-storage/backups"
    echo ""
    echo "  VM Storage (1.5TB):"
    echo "    - Images: /shared-storage/vm-storage/images"
    echo "    - Templates: /shared-storage/vm-storage/templates"
    echo "    - Instances: /shared-storage/vm-storage/instances"
    echo "    - Snapshots: /shared-storage/vm-storage/snapshots"
    echo "    - Backups: /shared-storage/vm-storage/backups"
    echo ""
    echo "  System Reserve (300GB):"
    echo "    - OS files, temporary files, cache, swap"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl is not installed or not in PATH"
        echo "Please install kubectl and configure it to connect to your cluster"
        exit 1
    fi
    
    # Check if we can connect to Kubernetes cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cannot connect to Kubernetes cluster"
        echo "Please ensure kubectl is configured and the cluster is accessible"
        exit 1
    fi
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        log_warning "This script should be run as root or with sudo for optimal results"
        echo "Some operations may require elevated privileges"
    fi
    
    log_success "Prerequisites check passed"
}

# Deploy shared storage
deploy_shared_storage() {
    log_info "Deploying shared storage with separate allocations..."
    
    # Run the deployment script
    if ./scripts/deploy-shared-storage-with-allocation.sh; then
        log_success "Shared storage deployed successfully"
    else
        log_error "Shared storage deployment failed"
        exit 1
    fi
}

# Test shared storage
test_shared_storage() {
    log_info "Testing shared storage configuration..."
    
    # Run the test script
    if ./scripts/test-shared-storage-with-allocation.sh; then
        log_success "Shared storage tests passed"
    else
        log_warning "Some shared storage tests failed - please review the output"
        echo "You may need to troubleshoot issues before proceeding"
    fi
}

# Display next steps
display_next_steps() {
    echo ""
    echo "=========================================="
    echo "  SHARED STORAGE COMPLETED"
    echo "=========================================="
    echo ""
    echo "Your shared storage with separate allocations is now configured and ready to use!"
    echo ""
    echo "Storage Configuration:"
    echo "  • Total Storage: 1.8TB per server"
    echo "  • K8s Storage: 1.5TB allocation"
    echo "  • VM Storage: 1.5TB allocation"
    echo "  • System Reserve: 300GB allocation"
    echo ""
    echo "Next Steps:"
    echo "1. Deploy your Kubernetes applications using the K8s storage classes:"
    echo "   • k8s-database-storage (for databases)"
    echo "   • k8s-app-storage (default, for applications)"
    echo "   • k8s-monitoring-storage (for monitoring)"
    echo "   • k8s-log-storage (for logs)"
    echo "   • k8s-backup-storage (for backups)"
    echo ""
    echo "2. Create VMs using the VM storage allocation:"
    echo "   • API endpoint: vm-storage-api.shared-storage-system.svc.cluster.local:8080"
    echo "   • Storage path: /shared-storage/vm-storage"
    echo "   • Documentation: docs/shared-storage-with-allocation-guide.md"
    echo ""
    echo "3. Monitor storage allocation usage:"
    echo "   • Overall: kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- /shared-storage/monitor-storage.sh"
    echo "   • K8s storage: kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- du -sh /shared-storage/k8s-storage/*"
    echo "   • VM storage: kubectl exec -n shared-storage-system daemonset/vm-storage-manager -- du -sh /shared-storage/vm-storage/*"
    echo ""
    echo "4. Set up backups and maintenance:"
    echo "   • Automatic cleanup: Daily at 2 AM"
    echo "   • Manual cleanup: kubectl create job --from=cronjob/storage-cleanup storage-cleanup-manual -n shared-storage-system"
    echo ""
    echo "Useful Commands:"
    echo "  # Check storage classes"
    echo "  kubectl get storageclass | grep k8s-"
    echo ""
    echo "  # Check storage usage"
    echo "  kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- /shared-storage/monitor-storage.sh"
    echo ""
    echo "  # Check VM storage manager"
    echo "  kubectl get pods -n shared-storage-system -l app=vm-storage-manager"
    echo ""
    echo "  # Check storage monitor"
    echo "  kubectl get pods -n shared-storage-system -l app=storage-monitor"
    echo ""
    echo "Documentation:"
    echo "  • Deployment Guide: docs/shared-storage-with-allocation-guide.md"
    echo "  • Configuration Guide: docs/shared-storage-configuration.md"
    echo ""
    echo "Support:"
    echo "  • Run tests: ./scripts/test-shared-storage-with-allocation.sh"
    echo "  • Check logs: kubectl logs -n shared-storage-system -l app=k8s-storage-provisioner"
    echo "  • Check VM logs: kubectl logs -n shared-storage-system -l app=vm-storage-manager"
    echo ""
    echo "Storage Allocation Features:"
    echo "  • K8s storage: 1.5TB limit with separate subdirectories"
    echo "  • VM storage: 1.5TB limit with VM templates and instances"
    echo "  • System reserve: 300GB for system operations"
    echo "  • Monitoring: Real-time monitoring of each allocation"
    echo "  • Cleanup: Automatic cleanup for each allocation"
    echo ""
}

# Main execution
main() {
    display_welcome
    
    # Ask for confirmation
    read -p "Do you want to proceed with the shared storage configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Shared storage configuration cancelled"
        exit 0
    fi
    
    check_prerequisites
    deploy_shared_storage
    test_shared_storage
    display_next_steps
    
    log_success "Shared storage quick start completed successfully!"
}

# Run main function
main "$@"