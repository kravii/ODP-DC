#!/bin/bash

# Quick Start Script for Dynamic Storage Pools
# Sets up dynamic storage pools where each server contributes 1.5TB to its pool

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
    echo "  DYNAMIC STORAGE POOLS QUICK START"
    echo "=========================================="
    echo ""
    echo "This script will set up dynamic storage pools:"
    echo "  • K8s Pool: Each K8s server contributes 1.5TB"
    echo "  • VM Pool: Each VM server contributes 1.5TB"
    echo "  • System Reserve: 300GB per server for OS operations"
    echo ""
    echo "Dynamic Pool Scaling:"
    echo "  • Add server to K8s pool → +1.5TB to K8s pool"
    echo "  • Add server to VM pool → +1.5TB to VM pool"
    echo "  • Remove server from pool → -1.5TB from pool"
    echo "  • Pool capacity automatically updates"
    echo ""
    echo "Pool Configuration:"
    echo "  K8s Pool:"
    echo "    - Path: /k8s-storage-pool"
    echo "    - Capacity: (Number of K8s servers) × 1.5TB"
    echo "    - Storage Class: k8s-pool-storage (default)"
    echo ""
    echo "  VM Pool:"
    echo "    - Path: /vm-storage-pool"
    echo "    - Capacity: (Number of VM servers) × 1.5TB"
    echo "    - Storage Class: vm-pool-storage"
    echo "    - VM Templates: ubuntu22, centos7, rhel8, rockylinux9"
    echo ""
    echo "  System Reserve:"
    echo "    - Path: /system-reserve"
    echo "    - Capacity: (Total servers) × 300GB"
    echo "    - Purpose: OS files, temporary files, cache, swap"
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

# Deploy dynamic storage pools
deploy_dynamic_pools() {
    log_info "Deploying dynamic storage pools..."
    
    # Run the deployment script
    if ./scripts/deploy-dynamic-storage-pools.sh; then
        log_success "Dynamic storage pools deployed successfully"
    else
        log_error "Dynamic storage pools deployment failed"
        exit 1
    fi
}

# Test dynamic storage pools
test_dynamic_pools() {
    log_info "Testing dynamic storage pools configuration..."
    
    # Run the test script
    if ./scripts/test-dynamic-storage-pools.sh; then
        log_success "Dynamic storage pools tests passed"
    else
        log_warning "Some dynamic storage pools tests failed - please review the output"
        echo "You may need to troubleshoot issues before proceeding"
    fi
}

# Display next steps
display_next_steps() {
    echo ""
    echo "=========================================="
    echo "  DYNAMIC STORAGE POOLS COMPLETED"
    echo "=========================================="
    echo ""
    echo "Your dynamic storage pools are now configured and ready to use!"
    echo ""
    
    # Get current pool status
    local k8s_servers=$(kubectl get nodes -l pool=k8s --no-headers 2>/dev/null | wc -l)
    local vm_servers=$(kubectl get nodes -l pool=vm --no-headers 2>/dev/null | wc -l)
    
    local k8s_capacity=$((k8s_servers * 1500))
    local vm_capacity=$((vm_servers * 1500))
    
    echo "Current Pool Status:"
    echo "  • K8s Pool: $k8s_servers servers → ${k8s_capacity}GB total capacity"
    echo "  • VM Pool: $vm_servers servers → ${vm_capacity}GB total capacity"
    echo ""
    echo "Next Steps:"
    echo "1. Deploy your Kubernetes applications using the K8s pool storage:"
    echo "   • Storage Class: k8s-pool-storage (default)"
    echo "   • Pool Capacity: ${k8s_capacity}GB (grows as you add K8s servers)"
    echo ""
    echo "2. Create VMs using the VM pool storage:"
    echo "   • API endpoint: vm-pool-api.dynamic-storage-pools.svc.cluster.local:8080"
    echo "   • Pool Capacity: ${vm_capacity}GB (grows as you add VM servers)"
    echo "   • VM Templates: ubuntu22, centos7, rhel8, rockylinux9"
    echo ""
    echo "3. Scale your pools dynamically:"
    echo "   • Add server to K8s pool: kubectl label node <node-name> pool=k8s"
    echo "   • Add server to VM pool: kubectl label node <node-name> pool=vm"
    echo "   • Remove server from pool: kubectl label node <node-name> pool-"
    echo "   • Pool capacity automatically updates"
    echo ""
    echo "4. Monitor pool capacity and usage:"
    echo "   • Overall: kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- /k8s-storage-pool/monitor-pools.sh"
    echo "   • K8s pool: kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- du -sh /k8s-storage-pool"
    echo "   • VM pool: kubectl exec -n dynamic-storage-pools daemonset/vm-pool-storage-manager -- du -sh /vm-storage-pool"
    echo ""
    echo "5. Set up backups and maintenance:"
    echo "   • Automatic cleanup: Daily at 2 AM"
    echo "   • Manual cleanup: kubectl create job --from=cronjob/pool-cleanup pool-cleanup-manual -n dynamic-storage-pools"
    echo ""
    echo "Useful Commands:"
    echo "  # Check pool status"
    echo "  kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- /k8s-storage-pool/monitor-pools.sh"
    echo ""
    echo "  # Check storage classes"
    echo "  kubectl get storageclass | grep -E '(k8s-pool|vm-pool)'"
    echo ""
    echo "  # Check node labels"
    echo "  kubectl get nodes --show-labels | grep -E '(pool=k8s|pool=vm)'"
    echo ""
    echo "  # Check pool scaling controller"
    echo "  kubectl get pods -n dynamic-storage-pools -l app=pool-scaling-controller"
    echo ""
    echo "Documentation:"
    echo "  • Deployment Guide: docs/dynamic-storage-pools-guide.md"
    echo "  • Configuration Guide: docs/shared-storage-configuration.md"
    echo ""
    echo "Support:"
    echo "  • Run tests: ./scripts/test-dynamic-storage-pools.sh"
    echo "  • Check logs: kubectl logs -n dynamic-storage-pools -l app=k8s-pool-provisioner"
    echo "  • Check VM logs: kubectl logs -n dynamic-storage-pools -l app=vm-pool-storage-manager"
    echo ""
    echo "Dynamic Pool Features:"
    echo "  • K8s pool: 1.5TB per server, automatic scaling"
    echo "  • VM pool: 1.5TB per server, automatic scaling"
    echo "  • System reserve: 300GB per server for OS operations"
    echo "  • Pool monitoring: Real-time monitoring of each pool"
    echo "  • Pool scaling: Automatic capacity updates as servers are added/removed"
    echo "  • Pool cleanup: Automatic cleanup for each pool"
    echo ""
    echo "Pool Scaling Examples:"
    echo "  • Add 1 server to K8s pool → +1.5TB to K8s pool"
    echo "  • Add 1 server to VM pool → +1.5TB to VM pool"
    echo "  • Remove 1 server from pool → -1.5TB from pool"
    echo "  • Move server between pools → Transfer 1.5TB between pools"
    echo ""
}

# Main execution
main() {
    display_welcome
    
    # Ask for confirmation
    read -p "Do you want to proceed with the dynamic storage pools configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Dynamic storage pools configuration cancelled"
        exit 0
    fi
    
    check_prerequisites
    deploy_dynamic_pools
    test_dynamic_pools
    display_next_steps
    
    log_success "Dynamic storage pools quick start completed successfully!"
}

# Run main function
main "$@"