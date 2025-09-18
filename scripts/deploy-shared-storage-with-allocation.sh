#!/bin/bash

# Deploy Shared Storage with Separate Allocations Script
# Sets up 1.8TB storage split into 1.5TB for /k8s-storage and 1.5TB for /vm-storage

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KUBECTL_CMD="kubectl"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we can connect to Kubernetes cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if required files exist
    local required_files=(
        "$PROJECT_ROOT/kubernetes/shared-storage/shared-storage-with-allocation.yaml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Required file not found: $file"
            exit 1
        fi
    done
    
    log_success "Prerequisites check passed"
}

# Deploy shared storage with allocation
deploy_shared_storage() {
    log_info "Deploying shared storage with separate allocations..."
    
    # Apply shared storage configuration
    kubectl apply -f "$PROJECT_ROOT/kubernetes/shared-storage/shared-storage-with-allocation.yaml"
    
    # Wait for storage setup job to complete
    log_info "Waiting for shared storage setup job to complete..."
    kubectl wait --for=condition=complete job/setup-shared-storage-with-allocation -n shared-storage-system --timeout=300s
    
    # Wait for K8s storage provisioner to be ready
    log_info "Waiting for K8s storage provisioner to be ready..."
    kubectl wait --for=condition=available deployment/k8s-storage-provisioner -n shared-storage-system --timeout=300s
    
    # Wait for VM storage manager to be ready
    log_info "Waiting for VM storage manager to be ready..."
    kubectl wait --for=condition=ready pod -l app=vm-storage-manager -n shared-storage-system --timeout=300s
    
    # Wait for storage monitor to be ready
    log_info "Waiting for storage monitor to be ready..."
    kubectl wait --for=condition=ready pod -l app=storage-monitor -n shared-storage-system --timeout=300s
    
    log_success "Shared storage with separate allocations deployed successfully"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check namespace
    log_info "Checking namespace..."
    kubectl get namespace shared-storage-system
    
    # Check storage classes
    log_info "Checking storage classes..."
    kubectl get storageclass | grep k8s-
    
    # Check K8s storage provisioner
    log_info "Checking K8s storage provisioner..."
    kubectl get pods -n shared-storage-system -l app=k8s-storage-provisioner
    
    # Check VM storage manager
    log_info "Checking VM storage manager..."
    kubectl get pods -n shared-storage-system -l app=vm-storage-manager
    
    # Check storage monitor
    log_info "Checking storage monitor..."
    kubectl get pods -n shared-storage-system -l app=storage-monitor
    
    # Check storage usage
    log_info "Checking storage usage..."
    kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- /shared-storage/monitor-storage.sh
    
    log_success "Deployment verification completed"
}

# Test storage allocation
test_storage_allocation() {
    log_info "Testing storage allocation..."
    
    # Test K8s storage allocation
    log_info "Testing K8s storage allocation..."
    kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- test -d /shared-storage/k8s-storage
    kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- test -d /shared-storage/k8s-storage/databases
    kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- test -d /shared-storage/k8s-storage/applications
    kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- test -d /shared-storage/k8s-storage/monitoring
    kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- test -d /shared-storage/k8s-storage/logs
    kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- test -d /shared-storage/k8s-storage/backups
    
    # Test VM storage allocation
    log_info "Testing VM storage allocation..."
    kubectl exec -n shared-storage-system daemonset/vm-storage-manager -- test -d /shared-storage/vm-storage
    kubectl exec -n shared-storage-system daemonset/vm-storage-manager -- test -d /shared-storage/vm-storage/images
    kubectl exec -n shared-storage-system daemonset/vm-storage-manager -- test -d /shared-storage/vm-storage/templates
    kubectl exec -n shared-storage-system daemonset/vm-storage-manager -- test -d /shared-storage/vm-storage/instances
    kubectl exec -n shared-storage-system daemonset/vm-storage-manager -- test -d /shared-storage/vm-storage/snapshots
    kubectl exec -n shared-storage-system daemonset/vm-storage-manager -- test -d /shared-storage/vm-storage/backups
    
    # Test VM templates
    log_info "Testing VM templates..."
    kubectl exec -n shared-storage-system daemonset/vm-storage-manager -- ls -la /shared-storage/vm-storage/templates/
    
    log_success "Storage allocation test completed"
}

# Test persistent volume creation
test_pv_creation() {
    log_info "Testing persistent volume creation..."
    
    # Create test namespace
    kubectl create namespace storage-test --dry-run=client -o yaml | kubectl apply -f -
    
    # Create test PVC for K8s storage
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: k8s-test-pvc
  namespace: storage-test
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: k8s-app-storage
  resources:
    requests:
      storage: 1Gi
EOF
    
    # Wait for PVC to be bound
    if kubectl wait --for=condition=Bound pvc/k8s-test-pvc -n storage-test --timeout=60s; then
        log_info "K8s storage test PVC created and bound successfully"
        
        # Get PVC details
        local pvc_status=$(kubectl get pvc k8s-test-pvc -n storage-test -o jsonpath='{.status.phase}')
        log_info "K8s storage PVC status: $pvc_status"
        
        # Clean up
        kubectl delete pvc k8s-test-pvc -n storage-test
        kubectl delete namespace storage-test
        
        test_pass "K8s storage persistent volume creation test passed"
        return 0
    else
        test_fail "K8s storage test PVC failed to bind within timeout"
        kubectl delete pvc k8s-test-pvc -n storage-test 2>/dev/null || true
        kubectl delete namespace storage-test 2>/dev/null || true
        return 1
    fi
}

# Display deployment summary
display_summary() {
    log_info "Deployment completed successfully!"
    echo ""
    echo "=========================================="
    echo "SHARED STORAGE WITH ALLOCATION SUMMARY"
    echo "=========================================="
    echo ""
    echo "Storage Configuration:"
    echo "  - Total Storage: 1.8TB per server"
    echo "  - K8s Storage: 1.5TB (/shared-storage/k8s-storage)"
    echo "  - VM Storage: 1.5TB (/shared-storage/vm-storage)"
    echo "  - System Reserve: 300GB (/shared-storage/system)"
    echo ""
    echo "K8s Storage Allocation (1.5TB):"
    echo "  - Databases: /shared-storage/k8s-storage/databases"
    echo "  - Applications: /shared-storage/k8s-storage/applications"
    echo "  - Monitoring: /shared-storage/k8s-storage/monitoring"
    echo "  - Logs: /shared-storage/k8s-storage/logs"
    echo "  - Backups: /shared-storage/k8s-storage/backups"
    echo ""
    echo "VM Storage Allocation (1.5TB):"
    echo "  - Images: /shared-storage/vm-storage/images"
    echo "  - Templates: /shared-storage/vm-storage/templates"
    echo "  - Instances: /shared-storage/vm-storage/instances"
    echo "  - Snapshots: /shared-storage/vm-storage/snapshots"
    echo "  - Backups: /shared-storage/vm-storage/backups"
    echo ""
    echo "Deployed Components:"
    echo "  - K8s Storage Provisioner"
    echo "  - VM Storage Manager"
    echo "  - Storage Monitor"
    echo "  - Storage Cleanup CronJob"
    echo ""
    echo "Storage Classes:"
    echo "  - k8s-database-storage (Retain)"
    echo "  - k8s-app-storage (Default, Delete)"
    echo "  - k8s-monitoring-storage (Retain)"
    echo "  - k8s-log-storage (Delete)"
    echo "  - k8s-backup-storage (Retain)"
    echo ""
    echo "Management Commands:"
    echo "  # Check storage usage"
    echo "  kubectl exec -n shared-storage-system deployment/k8s-storage-provisioner -- /shared-storage/monitor-storage.sh"
    echo ""
    echo "  # Check VM storage usage"
    echo "  kubectl exec -n shared-storage-system daemonset/vm-storage-manager -- /shared-storage/monitor-storage.sh"
    echo ""
    echo "  # Run storage cleanup"
    echo "  kubectl create job --from=cronjob/storage-cleanup storage-cleanup-manual -n shared-storage-system"
    echo ""
    echo "API Endpoints:"
    echo "  - VM Storage API: vm-storage-api.shared-storage-system.svc.cluster.local:8080"
    echo ""
    echo "Storage Isolation:"
    echo "  - K8s storage: /shared-storage/k8s-storage (1.5TB limit)"
    echo "  - VM storage: /shared-storage/vm-storage (1.5TB limit)"
    echo "  - Separate monitoring for each allocation"
    echo "  - Independent cleanup for each allocation"
    echo ""
}

# Main execution
main() {
    log_info "Starting shared storage with allocation deployment..."
    echo "=========================================="
    
    check_prerequisites
    deploy_shared_storage
    verify_deployment
    test_storage_allocation
    test_pv_creation
    display_summary
    
    log_success "Shared storage with allocation deployment completed successfully!"
}

# Run main function
main "$@"