#!/bin/bash

# Deploy Dynamic Storage Pools Script
# Sets up dynamic storage pools where each server contributes 1.5TB to its pool

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
        "$PROJECT_ROOT/kubernetes/dynamic-storage-pools/dynamic-storage-pools.yaml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Required file not found: $file"
            exit 1
        fi
    done
    
    log_success "Prerequisites check passed"
}

# Label nodes for dynamic pools
label_nodes_for_pools() {
    log_info "Labeling nodes for dynamic storage pools..."
    
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
        log_success "Labeled node $node as K8s pool (contributes 1.5TB to K8s pool)"
    done
    
    # Label VM pool nodes
    for node in "${vm_nodes[@]}"; do
        kubectl label node "$node" pool=vm --overwrite
        log_success "Labeled node $node as VM pool (contributes 1.5TB to VM pool)"
    done
    
    # Verify node labels
    log_info "Node labels:"
    kubectl get nodes --show-labels | grep -E "(pool=k8s|pool=vm)"
}

# Deploy dynamic storage pools
deploy_dynamic_pools() {
    log_info "Deploying dynamic storage pools..."
    
    # Apply dynamic storage pools configuration
    kubectl apply -f "$PROJECT_ROOT/kubernetes/dynamic-storage-pools/dynamic-storage-pools.yaml"
    
    # Wait for storage setup job to complete
    log_info "Waiting for dynamic storage pools setup job to complete..."
    kubectl wait --for=condition=complete job/setup-dynamic-storage-pools -n dynamic-storage-pools --timeout=300s
    
    # Wait for K8s pool provisioner to be ready
    log_info "Waiting for K8s pool provisioner to be ready..."
    kubectl wait --for=condition=available deployment/k8s-pool-provisioner -n dynamic-storage-pools --timeout=300s
    
    # Wait for VM pool storage manager to be ready
    log_info "Waiting for VM pool storage manager to be ready..."
    kubectl wait --for=condition=ready pod -l app=vm-pool-storage-manager -n dynamic-storage-pools --timeout=300s
    
    # Wait for dynamic pool monitor to be ready
    log_info "Waiting for dynamic pool monitor to be ready..."
    kubectl wait --for=condition=ready pod -l app=dynamic-pool-monitor -n dynamic-storage-pools --timeout=300s
    
    # Wait for pool scaling controller to be ready
    log_info "Waiting for pool scaling controller to be ready..."
    kubectl wait --for=condition=available deployment/pool-scaling-controller -n dynamic-storage-pools --timeout=300s
    
    log_success "Dynamic storage pools deployed successfully"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check namespace
    log_info "Checking namespace..."
    kubectl get namespace dynamic-storage-pools
    
    # Check node labels
    log_info "Checking node labels..."
    kubectl get nodes --show-labels | grep -E "(pool=k8s|pool=vm)"
    
    # Check storage classes
    log_info "Checking storage classes..."
    kubectl get storageclass | grep -E "(k8s-pool|vm-pool)"
    
    # Check K8s pool provisioner
    log_info "Checking K8s pool provisioner..."
    kubectl get pods -n dynamic-storage-pools -l app=k8s-pool-provisioner
    
    # Check VM pool storage manager
    log_info "Checking VM pool storage manager..."
    kubectl get pods -n dynamic-storage-pools -l app=vm-pool-storage-manager
    
    # Check dynamic pool monitor
    log_info "Checking dynamic pool monitor..."
    kubectl get pods -n dynamic-storage-pools -l app=dynamic-pool-monitor
    
    # Check pool scaling controller
    log_info "Checking pool scaling controller..."
    kubectl get pods -n dynamic-storage-pools -l app=pool-scaling-controller
    
    # Check pool status
    log_info "Checking pool status..."
    kubectl get configmap dynamic-storage-config -n dynamic-storage-pools -o yaml | grep -A 5 "pool-status"
    
    log_success "Deployment verification completed"
}

# Test dynamic pool functionality
test_dynamic_pools() {
    log_info "Testing dynamic pool functionality..."
    
    # Test K8s pool storage
    log_info "Testing K8s pool storage..."
    kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- test -d /k8s-storage-pool
    kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- ls -la /k8s-storage-pool
    
    # Test VM pool storage
    log_info "Testing VM pool storage..."
    kubectl exec -n dynamic-storage-pools daemonset/vm-pool-storage-manager -- test -d /vm-storage-pool
    kubectl exec -n dynamic-storage-pools daemonset/vm-pool-storage-manager -- ls -la /vm-storage-pool
    
    # Test VM templates
    log_info "Testing VM templates..."
    kubectl exec -n dynamic-storage-pools daemonset/vm-pool-storage-manager -- ls -la /vm-storage-pool/*.qcow2
    
    # Test pool monitoring
    log_info "Testing pool monitoring..."
    kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- /k8s-storage-pool/monitor-pools.sh
    
    log_success "Dynamic pool functionality test completed"
}

# Test pool scaling
test_pool_scaling() {
    log_info "Testing pool scaling..."
    
    # Get current pool status
    local k8s_servers=$(kubectl get nodes -l pool=k8s --no-headers | wc -l)
    local vm_servers=$(kubectl get nodes -l pool=vm --no-headers | wc -l)
    
    local k8s_capacity=$((k8s_servers * 1500))
    local vm_capacity=$((vm_servers * 1500))
    
    log_info "Current pool status:"
    log_info "  K8s Pool: $k8s_servers servers → ${k8s_capacity}GB total capacity"
    log_info "  VM Pool: $vm_servers servers → ${vm_capacity}GB total capacity"
    
    # Test adding a node to K8s pool (simulate)
    log_info "Testing pool scaling calculation..."
    local new_k8s_capacity=$(((k8s_servers + 1) * 1500))
    local new_vm_capacity=$(((vm_servers + 1) * 1500))
    
    log_info "If we add 1 server to each pool:"
    log_info "  K8s Pool: $((k8s_servers + 1)) servers → ${new_k8s_capacity}GB total capacity (+1500GB)"
    log_info "  VM Pool: $((vm_servers + 1)) servers → ${new_vm_capacity}GB total capacity (+1500GB)"
    
    log_success "Pool scaling test completed"
}

# Display deployment summary
display_summary() {
    log_info "Deployment completed successfully!"
    echo ""
    echo "=========================================="
    echo "DYNAMIC STORAGE POOLS DEPLOYMENT SUMMARY"
    echo "=========================================="
    echo ""
    echo "Dynamic Storage Pool Configuration:"
    echo "  - Each server contributes 1.5TB to its assigned pool"
    echo "  - K8s Pool: All K8s servers contribute 1.5TB each"
    echo "  - VM Pool: All VM servers contribute 1.5TB each"
    echo "  - System Reserve: 300GB per server for OS operations"
    echo ""
    
    # Get current pool status
    local k8s_servers=$(kubectl get nodes -l pool=k8s --no-headers | wc -l)
    local vm_servers=$(kubectl get nodes -l pool=vm --no-headers | wc -l)
    
    local k8s_capacity=$((k8s_servers * 1500))
    local vm_capacity=$((vm_servers * 1500))
    
    echo "Current Pool Status:"
    echo "  K8s Pool: $k8s_servers servers → ${k8s_capacity}GB total capacity"
    echo "  VM Pool: $vm_servers servers → ${vm_capacity}GB total capacity"
    echo ""
    echo "Deployed Components:"
    echo "  - K8s Pool Provisioner (runs on K8s pool nodes)"
    echo "  - VM Pool Storage Manager (runs on VM pool nodes)"
    echo "  - Dynamic Pool Monitor (monitors both pools)"
    echo "  - Pool Scaling Controller (tracks pool changes)"
    echo "  - Pool Cleanup CronJob (daily cleanup)"
    echo ""
    echo "Storage Classes:"
    echo "  - k8s-pool-storage (default, uses K8s pool)"
    echo "  - vm-pool-storage (uses VM pool)"
    echo ""
    echo "Pool Scaling:"
    echo "  - Add server to K8s pool → +1.5TB to K8s pool"
    echo "  - Add server to VM pool → +1.5TB to VM pool"
    echo "  - Remove server from pool → -1.5TB from pool"
    echo "  - Automatic scaling detection and capacity updates"
    echo ""
    echo "Management Commands:"
    echo "  # Check pool status"
    echo "  kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- /k8s-storage-pool/monitor-pools.sh"
    echo ""
    echo "  # Check K8s pool usage"
    echo "  kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- du -sh /k8s-storage-pool"
    echo ""
    echo "  # Check VM pool usage"
    echo "  kubectl exec -n dynamic-storage-pools daemonset/vm-pool-storage-manager -- du -sh /vm-storage-pool"
    echo ""
    echo "  # Run pool cleanup"
    echo "  kubectl create job --from=cronjob/pool-cleanup pool-cleanup-manual -n dynamic-storage-pools"
    echo ""
    echo "API Endpoints:"
    echo "  - VM Pool API: vm-pool-api.dynamic-storage-pools.svc.cluster.local:8080"
    echo ""
    echo "Pool Management:"
    echo "  - Add server to K8s pool: kubectl label node <node-name> pool=k8s"
    echo "  - Add server to VM pool: kubectl label node <node-name> pool=vm"
    echo "  - Remove server from pool: kubectl label node <node-name> pool-"
    echo "  - Pool capacity automatically updates based on server count"
    echo ""
}

# Main execution
main() {
    log_info "Starting dynamic storage pools deployment..."
    echo "=========================================="
    
    check_prerequisites
    label_nodes_for_pools
    deploy_dynamic_pools
    verify_deployment
    test_dynamic_pools
    test_pool_scaling
    display_summary
    
    log_success "Dynamic storage pools deployment completed successfully!"
}

# Run main function
main "$@"