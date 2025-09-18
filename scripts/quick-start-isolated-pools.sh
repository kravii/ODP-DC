#!/bin/bash

# Quick Start Script for Isolated Resource Pools
# Sets up isolated K8s and VM resource pools with complete separation

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
    echo "  ISOLATED RESOURCE POOLS QUICK START"
    echo "=========================================="
    echo ""
    echo "This script will set up isolated resource pools for:"
    echo "  • Kubernetes workloads (K8s Pool)"
    echo "  • VM provisioning (VM Pool)"
    echo "  • Complete isolation between pools"
    echo ""
    echo "Resource Pool Configuration:"
    echo "  • K8s Pool: Dedicated servers for Kubernetes"
    echo "  • VM Pool: Dedicated servers for VM provisioning"
    echo "  • Storage: 1.8TB per server"
    echo "  • Network: Complete isolation (10.0.1.0/24 <-> 10.0.2.0/24)"
    echo ""
    echo "Storage Allocation per Pool:"
    echo "  K8s Pool (1.8TB per server):"
    echo "    - Databases: 500GB"
    echo "    - Applications: 1000GB"
    echo "    - Monitoring: 200GB"
    echo "    - Logs: 50GB"
    echo "    - Backups: 50GB"
    echo ""
    echo "  VM Pool (1.8TB per server):"
    echo "    - VM Images: 500GB"
    echo "    - VM Templates: 200GB"
    echo "    - VM Instances: 1000GB"
    echo "    - VM Snapshots: 50GB"
    echo "    - VM Backups: 50GB"
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

# Deploy isolated resource pools
deploy_isolated_pools() {
    log_info "Deploying isolated resource pools..."
    
    # Run the deployment script
    if ./scripts/deploy-isolated-resource-pools.sh; then
        log_success "Isolated resource pools deployed successfully"
    else
        log_error "Isolated resource pools deployment failed"
        exit 1
    fi
}

# Test isolated resource pools
test_isolated_pools() {
    log_info "Testing isolated resource pools..."
    
    # Run the test script
    if ./scripts/test-isolated-resource-pools.sh; then
        log_success "Isolated resource pools tests passed"
    else
        log_warning "Some isolated resource pools tests failed - please review the output"
        echo "You may need to troubleshoot issues before proceeding"
    fi
}

# Display next steps
display_next_steps() {
    echo ""
    echo "=========================================="
    echo "  ISOLATED RESOURCE POOLS COMPLETED"
    echo "=========================================="
    echo ""
    echo "Your isolated resource pools are now configured and ready to use!"
    echo ""
    echo "Resource Pool Summary:"
    echo "  • K8s Pool: Dedicated servers for Kubernetes workloads"
    echo "  • VM Pool: Dedicated servers for VM provisioning"
    echo "  • Complete isolation between pools"
    echo ""
    echo "Next Steps:"
    echo "1. Deploy your Kubernetes applications using K8s pool storage classes:"
    echo "   • k8s-database-storage (for databases)"
    echo "   • k8s-app-storage (default, for applications)"
    echo "   • k8s-monitoring-storage (for monitoring)"
    echo "   • k8s-log-storage (for logs)"
    echo "   • k8s-backup-storage (for backups)"
    echo ""
    echo "2. Create VMs using the VM pool:"
    echo "   • API endpoint: vm-pool-storage-api.vm-pool-storage.svc.cluster.local:8080"
    echo "   • Storage class: vm-pool-storage"
    echo "   • Documentation: docs/isolated-resource-pools-guide.md"
    echo ""
    echo "3. Monitor resource pool usage:"
    echo "   • K8s pool: kubectl exec -n k8s-pool-storage deployment/k8s-pool-local-path-provisioner -- /k8s-storage/monitor-k8s-storage.sh"
    echo "   • VM pool: kubectl exec -n vm-pool-storage daemonset/vm-pool-storage-manager -- /vm-storage/monitor-vm-storage.sh"
    echo "   • Isolation: kubectl logs -n network-isolation deployment/resource-pool-isolation-monitor"
    echo ""
    echo "4. Set up backups and maintenance:"
    echo "   • K8s pool cleanup: Daily at 2 AM"
    echo "   • VM pool cleanup: Daily at 3 AM"
    echo "   • Manual cleanup: kubectl create job --from=cronjob/k8s-pool-storage-cleanup k8s-cleanup-manual -n k8s-pool-storage"
    echo ""
    echo "Useful Commands:"
    echo "  # Check resource pool status"
    echo "  kubectl get nodes --show-labels | grep -E '(pool=k8s|pool=vm)'"
    echo ""
    echo "  # Check storage classes"
    echo "  kubectl get storageclass | grep -E '(k8s-|vm-)'"
    echo ""
    echo "  # Check isolation status"
    echo "  kubectl logs -n network-isolation deployment/resource-pool-isolation-monitor"
    echo ""
    echo "  # Run isolation test"
    echo "  kubectl create job --from=cronjob/test-resource-pool-isolation isolation-test-manual -n network-isolation"
    echo ""
    echo "Documentation:"
    echo "  • Deployment Guide: docs/isolated-resource-pools-guide.md"
    echo "  • Configuration Guide: docs/shared-storage-configuration.md"
    echo ""
    echo "Support:"
    echo "  • Run tests: ./scripts/test-isolated-resource-pools.sh"
    echo "  • Check logs: kubectl logs -n k8s-pool-storage -l app=k8s-pool-local-path-provisioner"
    echo "  • Check VM logs: kubectl logs -n vm-pool-storage -l app=vm-pool-storage-manager"
    echo ""
    echo "Isolation Features:"
    echo "  • Network isolation: K8s pool (10.0.1.0/24) <-> VM pool (10.0.2.0/24)"
    echo "  • Storage isolation: /k8s-storage <-> /vm-storage"
    echo "  • Resource isolation: No cross-pool resource sharing"
    echo "  • Monitoring isolation: Separate monitoring for each pool"
    echo ""
}

# Main execution
main() {
    display_welcome
    
    # Ask for confirmation
    read -p "Do you want to proceed with the isolated resource pools configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Isolated resource pools configuration cancelled"
        exit 0
    fi
    
    check_prerequisites
    deploy_isolated_pools
    test_isolated_pools
    display_next_steps
    
    log_success "Isolated resource pools quick start completed successfully!"
}

# Run main function
main "$@"