#!/bin/bash

# Deploy Isolated Resource Pools Script
# Sets up separate K8s and VM resource pools with complete isolation

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
        "$PROJECT_ROOT/kubernetes/k8s-pool/k8s-pool-storage.yaml"
        "$PROJECT_ROOT/kubernetes/vm-pool/vm-pool-storage.yaml"
        "$PROJECT_ROOT/kubernetes/network-policies/resource-pool-isolation.yaml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Required file not found: $file"
            exit 1
        fi
    done
    
    log_success "Prerequisites check passed"
}

# Label nodes for resource pools
label_nodes() {
    log_info "Labeling nodes for resource pools..."
    
    # Get all nodes
    local nodes=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
    
    if [[ ${#nodes[@]} -eq 0 ]]; then
        log_error "No nodes found in the cluster"
        exit 1
    fi
    
    log_info "Found ${#nodes[@]} nodes: ${nodes[*]}"
    
    # Split nodes between K8s and VM pools
    local k8s_nodes=()
    local vm_nodes=()
    
    for i in "${!nodes[@]}"; do
        if [[ $i -lt $((${#nodes[@]} / 2)) ]]; then
            k8s_nodes+=("${nodes[$i]}")
        else
            vm_nodes+=("${nodes[$i]}")
        fi
    done
    
    log_info "K8s pool nodes: ${k8s_nodes[*]}"
    log_info "VM pool nodes: ${vm_nodes[*]}"
    
    # Label K8s pool nodes
    for node in "${k8s_nodes[@]}"; do
        kubectl label node "$node" pool=k8s --overwrite
        log_success "Labeled node $node as K8s pool"
    done
    
    # Label VM pool nodes
    for node in "${vm_nodes[@]}"; do
        kubectl label node "$node" pool=vm --overwrite
        log_success "Labeled node $node as VM pool"
    done
    
    # Verify node labels
    log_info "Node labels:"
    kubectl get nodes --show-labels | grep -E "(pool=k8s|pool=vm)"
}

# Deploy K8s pool storage
deploy_k8s_pool_storage() {
    log_info "Deploying K8s pool storage configuration..."
    
    # Apply K8s pool storage configuration
    kubectl apply -f "$PROJECT_ROOT/kubernetes/k8s-pool/k8s-pool-storage.yaml"
    
    # Wait for K8s pool storage setup job to complete
    log_info "Waiting for K8s pool storage setup job to complete..."
    kubectl wait --for=condition=complete job/setup-k8s-pool-storage -n k8s-pool-storage --timeout=300s
    
    # Wait for K8s pool local path provisioner to be ready
    log_info "Waiting for K8s pool local path provisioner to be ready..."
    kubectl wait --for=condition=available deployment/k8s-pool-local-path-provisioner -n k8s-pool-storage --timeout=300s
    
    # Wait for K8s pool storage monitor to be ready
    log_info "Waiting for K8s pool storage monitor to be ready..."
    kubectl wait --for=condition=ready pod -l app=k8s-pool-storage-monitor -n k8s-pool-storage --timeout=300s
    
    log_success "K8s pool storage configuration deployed successfully"
}

# Deploy VM pool storage
deploy_vm_pool_storage() {
    log_info "Deploying VM pool storage configuration..."
    
    # Apply VM pool storage configuration
    kubectl apply -f "$PROJECT_ROOT/kubernetes/vm-pool/vm-pool-storage.yaml"
    
    # Wait for VM pool storage setup job to complete
    log_info "Waiting for VM pool storage setup job to complete..."
    kubectl wait --for=condition=complete job/setup-vm-pool-storage -n vm-pool-storage --timeout=300s
    
    # Wait for VM pool storage manager to be ready
    log_info "Waiting for VM pool storage manager to be ready..."
    kubectl wait --for=condition=ready pod -l app=vm-pool-storage-manager -n vm-pool-storage --timeout=300s
    
    log_success "VM pool storage configuration deployed successfully"
}

# Deploy network isolation
deploy_network_isolation() {
    log_info "Deploying network isolation policies..."
    
    # Apply network isolation policies
    kubectl apply -f "$PROJECT_ROOT/kubernetes/network-policies/resource-pool-isolation.yaml"
    
    # Wait for isolation monitor to be ready
    log_info "Waiting for resource pool isolation monitor to be ready..."
    kubectl wait --for=condition=available deployment/resource-pool-isolation-monitor -n network-isolation --timeout=300s
    
    log_success "Network isolation policies deployed successfully"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check namespaces
    log_info "Checking namespaces..."
    kubectl get namespaces | grep -E "(k8s-pool-storage|vm-pool-storage|network-isolation)"
    
    # Check node labels
    log_info "Checking node labels..."
    kubectl get nodes --show-labels | grep -E "(pool=k8s|pool=vm)"
    
    # Check storage classes
    log_info "Checking storage classes..."
    kubectl get storageclass | grep -E "(k8s-|vm-)"
    
    # Check K8s pool components
    log_info "Checking K8s pool components..."
    kubectl get pods -n k8s-pool-storage
    kubectl get storageclass | grep k8s-
    
    # Check VM pool components
    log_info "Checking VM pool components..."
    kubectl get pods -n vm-pool-storage
    kubectl get storageclass | grep vm-
    
    # Check network policies
    log_info "Checking network policies..."
    kubectl get networkpolicies --all-namespaces | grep -E "(k8s-pool|vm-pool)"
    
    # Check isolation monitor
    log_info "Checking isolation monitor..."
    kubectl get pods -n network-isolation
    
    log_success "Deployment verification completed"
}

# Test resource pool isolation
test_isolation() {
    log_info "Testing resource pool isolation..."
    
    # Create isolation test job
    kubectl create job --from=cronjob/test-resource-pool-isolation isolation-test-manual -n network-isolation
    
    # Wait for test to complete
    log_info "Waiting for isolation test to complete..."
    kubectl wait --for=condition=complete job/isolation-test-manual -n network-isolation --timeout=300s
    
    # Get test results
    log_info "Isolation test results:"
    kubectl logs job/isolation-test-manual -n network-isolation
    
    # Clean up test job
    kubectl delete job isolation-test-manual -n network-isolation
    
    log_success "Resource pool isolation test completed"
}

# Display deployment summary
display_summary() {
    log_info "Deployment completed successfully!"
    echo ""
    echo "=========================================="
    echo "ISOLATED RESOURCE POOLS DEPLOYMENT SUMMARY"
    echo "=========================================="
    echo ""
    echo "Resource Pool Configuration:"
    echo "  - K8s Pool: Dedicated servers for Kubernetes"
    echo "  - VM Pool: Dedicated servers for VM provisioning"
    echo "  - Complete isolation between pools"
    echo ""
    echo "Storage Configuration:"
    echo "  - K8s Pool: 1.8TB per server (databases, apps, monitoring, logs, backups)"
    echo "  - VM Pool: 1.8TB per server (images, templates, instances, snapshots, backups)"
    echo ""
    echo "Deployed Components:"
    echo "  - K8s Pool Storage Classes: k8s-database-storage, k8s-app-storage, k8s-monitoring-storage"
    echo "  - VM Pool Storage Classes: vm-pool-storage"
    echo "  - Network Isolation Policies: Complete separation between pools"
    echo "  - Storage Monitors: Real-time monitoring for each pool"
    echo "  - Cleanup Jobs: Automatic cleanup for each pool"
    echo ""
    echo "Management Commands:"
    echo "  # Check K8s pool storage usage"
    echo "  kubectl exec -n k8s-pool-storage deployment/k8s-pool-local-path-provisioner -- /k8s-storage/monitor-k8s-storage.sh"
    echo ""
    echo "  # Check VM pool storage usage"
    echo "  kubectl exec -n vm-pool-storage daemonset/vm-pool-storage-manager -- /vm-storage/monitor-vm-storage.sh"
    echo ""
    echo "  # Check isolation status"
    echo "  kubectl logs -n network-isolation deployment/resource-pool-isolation-monitor"
    echo ""
    echo "  # Run isolation test"
    echo "  kubectl create job --from=cronjob/test-resource-pool-isolation isolation-test-manual -n network-isolation"
    echo ""
    echo "API Endpoints:"
    echo "  - K8s Pool: k8s-pool-local-path-provisioner.k8s-pool-storage.svc.cluster.local"
    echo "  - VM Pool: vm-pool-storage-api.vm-pool-storage.svc.cluster.local"
    echo ""
    echo "Isolation Features:"
    echo "  - Network isolation: K8s pool (10.0.1.0/24) <-> VM pool (10.0.2.0/24)"
    echo "  - Storage isolation: /k8s-storage <-> /vm-storage"
    echo "  - Resource isolation: No cross-pool resource sharing"
    echo "  - Monitoring isolation: Separate monitoring for each pool"
    echo ""
}

# Main execution
main() {
    log_info "Starting isolated resource pools deployment..."
    echo "=========================================="
    
    check_prerequisites
    label_nodes
    deploy_k8s_pool_storage
    deploy_vm_pool_storage
    deploy_network_isolation
    verify_deployment
    test_isolation
    display_summary
    
    log_success "Isolated resource pools deployment completed successfully!"
}

# Run main function
main "$@"