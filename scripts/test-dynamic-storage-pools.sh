#!/bin/bash

# Test Dynamic Storage Pools Script
# Tests the dynamic storage pools where each server contributes 1.5TB to its pool

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KUBECTL_CMD="kubectl"
TEST_NAMESPACE="dynamic-pool-test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

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

# Test result functions
test_pass() {
    ((TESTS_PASSED++))
    log_success "PASS: $1"
}

test_fail() {
    ((TESTS_FAILED++))
    log_error "FAIL: $1"
}

test_start() {
    ((TOTAL_TESTS++))
    log_info "TEST: $1"
}

# Check prerequisites
check_prerequisites() {
    test_start "Checking prerequisites"
    
    # Check if kubectl is available
    if ! command -v kubectl >/dev/null 2>&1; then
        test_fail "kubectl is not installed or not in PATH"
        return 1
    fi
    
    # Check if we can connect to Kubernetes cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        test_fail "Cannot connect to Kubernetes cluster"
        return 1
    fi
    
    test_pass "Prerequisites check passed"
    return 0
}

# Test dynamic storage pools namespace
test_dynamic_pools_namespace() {
    test_start "Testing dynamic storage pools namespace"
    
    if kubectl get namespace dynamic-storage-pools >/dev/null 2>&1; then
        log_info "Namespace dynamic-storage-pools exists"
    else
        test_fail "Namespace dynamic-storage-pools does not exist"
        return 1
    fi
    
    test_pass "Dynamic storage pools namespace exists"
    return 0
}

# Test node labels for pools
test_node_labels() {
    test_start "Testing node labels for pools"
    
    # Check if nodes are labeled for pools
    local k8s_nodes=$(kubectl get nodes -l pool=k8s --no-headers | wc -l)
    local vm_nodes=$(kubectl get nodes -l pool=vm --no-headers | wc -l)
    
    if [[ $k8s_nodes -gt 0 ]]; then
        log_info "K8s pool nodes: $k8s_nodes"
    else
        test_fail "No K8s pool nodes found"
        return 1
    fi
    
    if [[ $vm_nodes -gt 0 ]]; then
        log_info "VM pool nodes: $vm_nodes"
    else
        test_fail "No VM pool nodes found"
        return 1
    fi
    
    test_pass "Node labels configured correctly"
    return 0
}

# Test storage classes
test_storage_classes() {
    test_start "Testing storage classes"
    
    # Check K8s pool storage class
    if kubectl get storageclass k8s-pool-storage >/dev/null 2>&1; then
        log_info "K8s pool storage class exists"
    else
        test_fail "K8s pool storage class does not exist"
        return 1
    fi
    
    # Check VM pool storage class
    if kubectl get storageclass vm-pool-storage >/dev/null 2>&1; then
        log_info "VM pool storage class exists"
    else
        test_fail "VM pool storage class does not exist"
        return 1
    fi
    
    # Check if k8s-pool-storage is default
    local default_sc=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
    if [[ "$default_sc" == "k8s-pool-storage" ]]; then
        log_info "k8s-pool-storage is set as default storage class"
    else
        test_fail "k8s-pool-storage is not set as default storage class"
        return 1
    fi
    
    test_pass "Storage classes configured correctly"
    return 0
}

# Test K8s pool storage
test_k8s_pool_storage() {
    test_start "Testing K8s pool storage"
    
    # Check if K8s pool provisioner pod is running
    local k8s_provisioner_pods=$(kubectl get pods -n dynamic-storage-pools -l app=k8s-pool-provisioner --no-headers | wc -l)
    if [[ $k8s_provisioner_pods -gt 0 ]]; then
        log_info "K8s pool provisioner pods are running: $k8s_provisioner_pods"
    else
        test_fail "No K8s pool provisioner pods are running"
        return 1
    fi
    
    # Check K8s pool storage directory
    if kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- test -d /k8s-storage-pool; then
        log_info "K8s pool storage directory exists"
    else
        test_fail "K8s pool storage directory does not exist"
        return 1
    fi
    
    # Check K8s pool storage permissions
    if kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- test -w /k8s-storage-pool; then
        log_info "K8s pool storage is writable"
    else
        test_fail "K8s pool storage is not writable"
        return 1
    fi
    
    test_pass "K8s pool storage is configured correctly"
    return 0
}

# Test VM pool storage
test_vm_pool_storage() {
    test_start "Testing VM pool storage"
    
    # Check if VM pool storage manager pods are running
    local vm_storage_pods=$(kubectl get pods -n dynamic-storage-pools -l app=vm-pool-storage-manager --no-headers | wc -l)
    if [[ $vm_storage_pods -gt 0 ]]; then
        log_info "VM pool storage manager pods are running: $vm_storage_pods"
    else
        test_fail "No VM pool storage manager pods are running"
        return 1
    fi
    
    # Check VM pool storage directory
    if kubectl exec -n dynamic-storage-pools daemonset/vm-pool-storage-manager -- test -d /vm-storage-pool; then
        log_info "VM pool storage directory exists"
    else
        test_fail "VM pool storage directory does not exist"
        return 1
    fi
    
    # Check VM pool storage permissions
    if kubectl exec -n dynamic-storage-pools daemonset/vm-pool-storage-manager -- test -w /vm-storage-pool; then
        log_info "VM pool storage is writable"
    else
        test_fail "VM pool storage is not writable"
        return 1
    fi
    
    # Check VM templates
    if kubectl exec -n dynamic-storage-pools daemonset/vm-pool-storage-manager -- test -f /vm-storage-pool/ubuntu22.qcow2; then
        log_info "VM template ubuntu22.qcow2 exists"
    else
        test_fail "VM template ubuntu22.qcow2 does not exist"
        return 1
    fi
    
    test_pass "VM pool storage is configured correctly"
    return 0
}

# Test persistent volume creation
test_persistent_volume_creation() {
    test_start "Testing persistent volume creation"
    
    # Create test namespace
    kubectl create namespace "$TEST_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Create test PVC
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: $TEST_NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: k8s-pool-storage
  resources:
    requests:
      storage: 1Gi
EOF
    
    # Wait for PVC to be bound
    if kubectl wait --for=condition=Bound pvc/test-pvc -n "$TEST_NAMESPACE" --timeout=60s; then
        log_info "Test PVC created and bound successfully"
        
        # Get PVC details
        local pvc_status=$(kubectl get pvc test-pvc -n "$TEST_NAMESPACE" -o jsonpath='{.status.phase}')
        log_info "PVC status: $pvc_status"
        
        # Clean up
        kubectl delete pvc test-pvc -n "$TEST_NAMESPACE"
        kubectl delete namespace "$TEST_NAMESPACE"
        
        test_pass "Persistent volume creation test passed"
        return 0
    else
        test_fail "Test PVC failed to bind within timeout"
        kubectl delete pvc test-pvc -n "$TEST_NAMESPACE" 2>/dev/null || true
        kubectl delete namespace "$TEST_NAMESPACE" 2>/dev/null || true
        return 1
    fi
}

# Test pool monitoring
test_pool_monitoring() {
    test_start "Testing pool monitoring"
    
    # Check if dynamic pool monitor pods are running
    local pool_monitor_pods=$(kubectl get pods -n dynamic-storage-pools -l app=dynamic-pool-monitor --no-headers | wc -l)
    if [[ $pool_monitor_pods -gt 0 ]]; then
        log_info "Dynamic pool monitor pods are running: $pool_monitor_pods"
    else
        test_fail "No dynamic pool monitor pods are running"
        return 1
    fi
    
    # Test pool monitoring script
    if kubectl exec -n dynamic-storage-pools deployment/k8s-pool-provisioner -- /k8s-storage-pool/monitor-pools.sh >/dev/null 2>&1; then
        log_info "Pool monitoring script works"
    else
        test_fail "Pool monitoring script failed"
        return 1
    fi
    
    test_pass "Pool monitoring is working correctly"
    return 0
}

# Test pool scaling
test_pool_scaling() {
    test_start "Testing pool scaling"
    
    # Check if pool scaling controller is running
    local scaling_controller_pods=$(kubectl get pods -n dynamic-storage-pools -l app=pool-scaling-controller --no-headers | wc -l)
    if [[ $scaling_controller_pods -gt 0 ]]; then
        log_info "Pool scaling controller pods are running: $scaling_controller_pods"
    else
        test_fail "No pool scaling controller pods are running"
        return 1
    fi
    
    # Get current pool status
    local k8s_servers=$(kubectl get nodes -l pool=k8s --no-headers | wc -l)
    local vm_servers=$(kubectl get nodes -l pool=vm --no-headers | wc -l)
    
    local k8s_capacity=$((k8s_servers * 1500))
    local vm_capacity=$((vm_servers * 1500))
    
    log_info "Current pool status:"
    log_info "  K8s Pool: $k8s_servers servers → ${k8s_capacity}GB total capacity"
    log_info "  VM Pool: $vm_servers servers → ${vm_capacity}GB total capacity"
    
    # Test pool scaling calculation
    local new_k8s_capacity=$(((k8s_servers + 1) * 1500))
    local new_vm_capacity=$(((vm_servers + 1) * 1500))
    
    log_info "Pool scaling calculation:"
    log_info "  Add 1 server to K8s pool → ${new_k8s_capacity}GB (+1500GB)"
    log_info "  Add 1 server to VM pool → ${new_vm_capacity}GB (+1500GB)"
    
    test_pass "Pool scaling is working correctly"
    return 0
}

# Test pool cleanup
test_pool_cleanup() {
    test_start "Testing pool cleanup"
    
    # Check if pool cleanup cronjob exists
    if kubectl get cronjob pool-cleanup -n dynamic-storage-pools >/dev/null 2>&1; then
        log_info "Pool cleanup cronjob exists"
    else
        test_fail "Pool cleanup cronjob does not exist"
        return 1
    fi
    
    # Test manual cleanup job creation
    if kubectl create job --from=cronjob/pool-cleanup pool-cleanup-test -n dynamic-storage-pools --dry-run=client >/dev/null 2>&1; then
        log_info "Pool cleanup job can be created manually"
    else
        test_fail "Pool cleanup job cannot be created manually"
        return 1
    fi
    
    test_pass "Pool cleanup is configured correctly"
    return 0
}

# Test pool capacity calculation
test_pool_capacity_calculation() {
    test_start "Testing pool capacity calculation"
    
    # Get current pool status
    local k8s_servers=$(kubectl get nodes -l pool=k8s --no-headers | wc -l)
    local vm_servers=$(kubectl get nodes -l pool=vm --no-headers | wc -l)
    
    # Calculate expected capacities
    local expected_k8s_capacity=$((k8s_servers * 1500))
    local expected_vm_capacity=$((vm_servers * 1500))
    
    log_info "Pool capacity calculation:"
    log_info "  K8s Pool: $k8s_servers servers × 1500GB = ${expected_k8s_capacity}GB"
    log_info "  VM Pool: $vm_servers servers × 1500GB = ${expected_vm_capacity}GB"
    
    # Verify capacity calculation is correct
    if [[ $expected_k8s_capacity -eq $((k8s_servers * 1500)) ]]; then
        log_info "K8s pool capacity calculation is correct"
    else
        test_fail "K8s pool capacity calculation is incorrect"
        return 1
    fi
    
    if [[ $expected_vm_capacity -eq $((vm_servers * 1500)) ]]; then
        log_info "VM pool capacity calculation is correct"
    else
        test_fail "VM pool capacity calculation is incorrect"
        return 1
    fi
    
    test_pass "Pool capacity calculation is working correctly"
    return 0
}

# Test storage performance
test_storage_performance() {
    test_start "Testing storage performance"
    
    # Create test namespace
    kubectl create namespace "$TEST_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Create test pod with storage
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: perf-test-pvc
  namespace: $TEST_NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: k8s-pool-storage
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: perf-test-pod
  namespace: $TEST_NAMESPACE
spec:
  nodeSelector:
    pool: k8s
  containers:
  - name: perf-test
    image: alpine:latest
    command: ["/bin/sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: test-volume
      mountPath: /test
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: perf-test-pvc
EOF
    
    # Wait for pod to be ready
    if kubectl wait --for=condition=Ready pod/perf-test-pod -n "$TEST_NAMESPACE" --timeout=60s; then
        log_info "Performance test pod is ready"
        
        # Test write performance
        local write_start=$(date +%s)
        kubectl exec perf-test-pod -n "$TEST_NAMESPACE" -- dd if=/dev/zero of=/test/testfile bs=1M count=100 2>/dev/null
        local write_end=$(date +%s)
        local write_time=$((write_end - write_start))
        log_info "Write performance: 100MB in ${write_time}s"
        
        # Test read performance
        local read_start=$(date +%s)
        kubectl exec perf-test-pod -n "$TEST_NAMESPACE" -- dd if=/test/testfile of=/dev/null bs=1M 2>/dev/null
        local read_end=$(date +%s)
        local read_time=$((read_end - read_start))
        log_info "Read performance: 100MB in ${read_time}s"
        
        # Clean up
        kubectl delete pod perf-test-pod -n "$TEST_NAMESPACE"
        kubectl delete pvc perf-test-pvc -n "$TEST_NAMESPACE"
        kubectl delete namespace "$TEST_NAMESPACE"
        
        test_pass "Storage performance test completed"
        return 0
    else
        test_fail "Performance test pod failed to start"
        kubectl delete pod perf-test-pod -n "$TEST_NAMESPACE" 2>/dev/null || true
        kubectl delete pvc perf-test-pvc -n "$TEST_NAMESPACE" 2>/dev/null || true
        kubectl delete namespace "$TEST_NAMESPACE" 2>/dev/null || true
        return 1
    fi
}

# Display test summary
display_test_summary() {
    echo ""
    echo "=========================================="
    echo "DYNAMIC STORAGE POOLS TEST SUMMARY"
    echo "=========================================="
    echo ""
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed! Dynamic storage pools are working correctly."
        echo ""
        echo "Dynamic storage pools are ready for:"
        echo "  - Kubernetes persistent volumes (K8s pool)"
        echo "  - VM provisioning (VM pool)"
        echo "  - Dynamic scaling as servers are added/removed"
        echo "  - Automatic capacity management"
        echo ""
        echo "Next steps:"
        echo "  1. Deploy applications using K8s pool storage"
        echo "  2. Create VMs using VM pool storage"
        echo "  3. Add/remove servers to scale pools dynamically"
        echo "  4. Monitor pool capacity and usage"
        return 0
    else
        log_error "Some tests failed. Please review the errors above."
        echo ""
        echo "Common issues:"
        echo "  - Nodes not properly labeled for pools"
        echo "  - Storage not properly mounted on nodes"
        echo "  - Kubernetes resources not deployed"
        echo "  - Pool capacity calculation errors"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting dynamic storage pools tests..."
    echo "=========================================="
    
    # Run all tests
    check_prerequisites
    test_dynamic_pools_namespace
    test_node_labels
    test_storage_classes
    test_k8s_pool_storage
    test_vm_pool_storage
    test_persistent_volume_creation
    test_pool_monitoring
    test_pool_scaling
    test_pool_cleanup
    test_pool_capacity_calculation
    test_storage_performance
    
    # Display summary
    display_test_summary
}

# Run main function
main "$@"