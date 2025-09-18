#!/bin/bash

# Deploy Shared Storage Configuration Script
# Sets up 1.8TB RAID storage for Kubernetes and VM provisioning

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KUBECTL_CMD="kubectl"
NAMESPACE_PREFIX="shared-storage"

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
        "$PROJECT_ROOT/scripts/setup-shared-storage.sh"
        "$PROJECT_ROOT/kubernetes/storage/enhanced-shared-storage.yaml"
        "$PROJECT_ROOT/kubernetes/vm-provisioning/enhanced-vm-provisioner.yaml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Required file not found: $file"
            exit 1
        fi
    done
    
    log_success "Prerequisites check passed"
}

# Setup shared storage on nodes
setup_shared_storage() {
    log_info "Setting up shared storage on nodes..."
    
    # Make the setup script executable
    chmod +x "$PROJECT_ROOT/scripts/setup-shared-storage.sh"
    
    # Get all nodes
    local nodes=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
    
    if [[ ${#nodes[@]} -eq 0 ]]; then
        log_error "No nodes found in the cluster"
        exit 1
    fi
    
    log_info "Found ${#nodes[@]} nodes: ${nodes[*]}"
    
    # Run setup script on each node
    for node in "${nodes[@]}"; do
        log_info "Setting up shared storage on node: $node"
        
        # Copy setup script to node
        kubectl cp "$PROJECT_ROOT/scripts/setup-shared-storage.sh" "$node:/tmp/setup-shared-storage.sh"
        
        # Execute setup script on node
        kubectl exec "$node" -- /bin/bash /tmp/setup-shared-storage.sh
        
        # Clean up
        kubectl exec "$node" -- rm -f /tmp/setup-shared-storage.sh
        
        log_success "Shared storage setup completed on node: $node"
    done
}

# Deploy Kubernetes storage configuration
deploy_k8s_storage() {
    log_info "Deploying Kubernetes storage configuration..."
    
    # Apply enhanced shared storage configuration
    kubectl apply -f "$PROJECT_ROOT/kubernetes/storage/enhanced-shared-storage.yaml"
    
    # Wait for storage setup job to complete
    log_info "Waiting for storage setup job to complete..."
    kubectl wait --for=condition=complete job/setup-enhanced-shared-storage -n shared-storage-system --timeout=300s
    
    # Wait for local path provisioner to be ready
    log_info "Waiting for local path provisioner to be ready..."
    kubectl wait --for=condition=available deployment/enhanced-local-path-provisioner -n shared-storage-system --timeout=300s
    
    # Wait for storage monitor to be ready
    log_info "Waiting for storage monitor to be ready..."
    kubectl wait --for=condition=ready pod -l app=storage-monitor -n shared-storage-system --timeout=300s
    
    log_success "Kubernetes storage configuration deployed successfully"
}

# Deploy VM provisioning configuration
deploy_vm_provisioning() {
    log_info "Deploying VM provisioning configuration..."
    
    # Apply enhanced VM provisioner configuration
    kubectl apply -f "$PROJECT_ROOT/kubernetes/vm-provisioning/enhanced-vm-provisioner.yaml"
    
    # Wait for VM provisioner to be ready
    log_info "Waiting for VM provisioner to be ready..."
    kubectl wait --for=condition=available deployment/vm-provisioner -n vm-system --timeout=300s
    
    # Wait for VM storage manager to be ready
    log_info "Waiting for VM storage manager to be ready..."
    kubectl wait --for=condition=ready pod -l app=vm-storage-manager -n vm-system --timeout=300s
    
    log_success "VM provisioning configuration deployed successfully"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check storage namespaces
    log_info "Checking storage namespaces..."
    kubectl get namespaces | grep -E "(shared-storage-system|vm-system)"
    
    # Check storage classes
    log_info "Checking storage classes..."
    kubectl get storageclass
    
    # Check persistent volumes
    log_info "Checking persistent volumes..."
    kubectl get pv
    
    # Check storage monitor
    log_info "Checking storage monitor..."
    kubectl get pods -n shared-storage-system -l app=storage-monitor
    
    # Check VM provisioner
    log_info "Checking VM provisioner..."
    kubectl get pods -n vm-system -l app=vm-provisioner
    
    # Check VM storage manager
    log_info "Checking VM storage manager..."
    kubectl get pods -n vm-system -l app=vm-storage-manager
    
    # Check storage usage
    log_info "Checking storage usage..."
    kubectl exec -n shared-storage-system deployment/enhanced-local-path-provisioner -- /shared-storage/monitor-storage.sh usage
    
    log_success "Deployment verification completed"
}

# Display deployment summary
display_summary() {
    log_info "Deployment completed successfully!"
    echo ""
    echo "=========================================="
    echo "SHARED STORAGE DEPLOYMENT SUMMARY"
    echo "=========================================="
    echo ""
    echo "Storage Configuration:"
    echo "  - Total Storage: 1.8TB RAID"
    echo "  - VM Storage: 1TB"
    echo "  - Kubernetes Storage: 500GB"
    echo "  - Monitoring Storage: 200GB"
    echo "  - Backup Storage: 80GB"
    echo "  - Log Storage: 20GB"
    echo ""
    echo "Deployed Components:"
    echo "  - Enhanced Local Path Provisioner"
    echo "  - Storage Monitor DaemonSet"
    echo "  - Storage Cleanup CronJob"
    echo "  - VM Provisioner"
    echo "  - VM Storage Manager"
    echo "  - VM Storage Cleanup CronJob"
    echo ""
    echo "Storage Classes:"
    echo "  - shared-storage-fast (default)"
    echo "  - shared-storage-slow"
    echo "  - shared-storage-monitoring"
    echo "  - vm-storage"
    echo ""
    echo "Management Commands:"
    echo "  # Check storage usage"
    echo "  kubectl exec -n shared-storage-system deployment/enhanced-local-path-provisioner -- /shared-storage/monitor-storage.sh usage"
    echo ""
    echo "  # Get storage statistics"
    echo "  kubectl exec -n shared-storage-system deployment/enhanced-local-path-provisioner -- /shared-storage/monitor-storage.sh stats"
    echo ""
    echo "  # Check storage health"
    echo "  kubectl exec -n shared-storage-system deployment/enhanced-local-path-provisioner -- /shared-storage/monitor-storage.sh health"
    echo ""
    echo "  # Run storage cleanup"
    echo "  kubectl create job --from=cronjob/storage-cleanup storage-cleanup-manual -n shared-storage-system"
    echo ""
    echo "  # Run VM storage cleanup"
    echo "  kubectl create job --from=cronjob/vm-storage-cleanup vm-storage-cleanup-manual -n vm-system"
    echo ""
    echo "API Endpoints:"
    echo "  - VM Provisioning: kubectl get svc vm-provisioner-service -n vm-system"
    echo "  - Storage Monitoring: kubectl get pods -n shared-storage-system -l app=storage-monitor"
    echo ""
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    # Add any cleanup logic here if needed
}

# Main execution
main() {
    log_info "Starting shared storage deployment..."
    echo "=========================================="
    
    # Set up error handling
    trap cleanup EXIT
    
    check_prerequisites
    setup_shared_storage
    deploy_k8s_storage
    deploy_vm_provisioning
    verify_deployment
    display_summary
    
    log_success "Shared storage deployment completed successfully!"
}

# Run main function
main "$@"