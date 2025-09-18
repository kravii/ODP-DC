#!/bin/bash

# Quick Start Script for Shared Storage Configuration
# Sets up 1.8TB RAID storage for Kubernetes and VM provisioning

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
    echo "This script will set up 1.8TB RAID storage for:"
    echo "  • Kubernetes persistent volumes"
    echo "  • VM provisioning"
    echo "  • Monitoring and logging"
    echo "  • Backup and recovery"
    echo ""
    echo "Storage Allocation:"
    echo "  • VM Storage: 1TB"
    echo "  • Kubernetes: 500GB"
    echo "  • Monitoring: 200GB"
    echo "  • Backups: 80GB"
    echo "  • Logs: 20GB"
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

# Deploy storage configuration
deploy_storage() {
    log_info "Deploying shared storage configuration..."
    
    # Run the deployment script
    if ./scripts/deploy-shared-storage.sh; then
        log_success "Storage configuration deployed successfully"
    else
        log_error "Storage configuration deployment failed"
        exit 1
    fi
}

# Test storage configuration
test_storage() {
    log_info "Testing storage configuration..."
    
    # Run the test script
    if ./scripts/test-shared-storage.sh; then
        log_success "Storage configuration tests passed"
    else
        log_warning "Some storage tests failed - please review the output"
        echo "You may need to troubleshoot issues before proceeding"
    fi
}

# Display next steps
display_next_steps() {
    echo ""
    echo "=========================================="
    echo "  QUICK START COMPLETED"
    echo "=========================================="
    echo ""
    echo "Your shared storage is now configured and ready to use!"
    echo ""
    echo "Next Steps:"
    echo "1. Deploy your applications using the storage classes:"
    echo "   • shared-storage-fast (default)"
    echo "   • shared-storage-slow"
    echo "   • shared-storage-monitoring"
    echo "   • vm-storage"
    echo ""
    echo "2. Create VMs using the VM provisioning API:"
    echo "   • API endpoint: vm-provisioner-service.vm-system.svc.cluster.local:8080"
    echo "   • Documentation: docs/shared-storage-deployment-guide.md"
    echo ""
    echo "3. Monitor storage usage:"
    echo "   • kubectl exec -n shared-storage-system deployment/enhanced-local-path-provisioner -- /shared-storage/monitor-storage.sh usage"
    echo "   • kubectl exec -n shared-storage-system deployment/enhanced-local-path-provisioner -- /shared-storage/monitor-storage.sh health"
    echo ""
    echo "4. Set up backups and maintenance:"
    echo "   • Automatic cleanup runs daily at 2-3 AM"
    echo "   • Manual cleanup: kubectl create job --from=cronjob/storage-cleanup storage-cleanup-manual -n shared-storage-system"
    echo ""
    echo "Useful Commands:"
    echo "  # Check storage classes"
    echo "  kubectl get storageclass"
    echo ""
    echo "  # Check storage usage"
    echo "  kubectl exec -n shared-storage-system deployment/enhanced-local-path-provisioner -- /shared-storage/monitor-storage.sh usage"
    echo ""
    echo "  # Check VM provisioner status"
    echo "  kubectl get pods -n vm-system -l app=vm-provisioner"
    echo ""
    echo "  # Check storage monitor"
    echo "  kubectl get pods -n shared-storage-system -l app=storage-monitor"
    echo ""
    echo "Documentation:"
    echo "  • Deployment Guide: docs/shared-storage-deployment-guide.md"
    echo "  • Configuration Guide: docs/shared-storage-configuration.md"
    echo ""
    echo "Support:"
    echo "  • Run tests: ./scripts/test-shared-storage.sh"
    echo "  • Check logs: kubectl logs -n shared-storage-system -l app=storage-monitor"
    echo ""
}

# Main execution
main() {
    display_welcome
    
    # Ask for confirmation
    read -p "Do you want to proceed with the storage configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Storage configuration cancelled"
        exit 0
    fi
    
    check_prerequisites
    deploy_storage
    test_storage
    display_next_steps
    
    log_success "Quick start completed successfully!"
}

# Run main function
main "$@"