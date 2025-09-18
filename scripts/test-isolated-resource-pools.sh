#!/bin/bash

# Test Isolated Resource Pools Script
# Tests the isolated K8s and VM resource pools

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KUBECTL_CMD="kubectl"
TEST_NAMESPACE="resource-pool-test"

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

# Test resource pool namespaces
test_resource_pool_namespaces() {
    test_start "Testing resource pool namespaces"
    
    local namespaces=("k8s-pool-storage" "vm-pool-storage" "network-isolation")
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" >/dev/null 2>&1; then
            log_info "Namespace $ns exists"
        else
            test_fail "Namespace $ns does not exist"
            return 1
        fi
    done
    
    test_pass "Resource pool namespaces exist"
    return 0
}

# Test node labels
test_node_labels() {
    test_start "Testing node labels"
    
    # Check if nodes are labeled for resource pools
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

# Test K8s pool storage classes
test_k8s_pool_storage_classes() {
    test_start "Testing K8s pool storage classes"
    
    local storage_classes=("k8s-database-storage" "k8s-app-storage" "k8s-monitoring-storage" "k8s-log-storage" "k8s-backup-storage")
    
    for sc in "${storage_classes[@]}"; do
        if kubectl get storageclass "$sc" >/dev/null 2>&1; then
            log_info "Storage class $sc exists"
        else
            test_fail "Storage class $sc does not exist"
            return 1
        fi
    done
    
    # Check if k8s-app-storage is default
    local default_sc=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
    if [[ "$default_sc" == "k8s-app-storage" ]]; then
        log_info "k8s-app-storage is set as default storage class"
    else
        test_fail "k8s-app-storage is not set as default storage class"
        return 1
    fi
    
    test_pass "K8s pool storage classes configured correctly"
    return 0
}

# Test VM pool storage classes
test_vm_pool_storage_classes() {
    test_start "Testing VM pool storage classes"
    
    if kubectl get storageclass "vm-pool-storage" >/dev/null 2>&1; then
        log_info "VM pool storage class exists"
    else
        test_fail "VM pool storage class does not exist"
        return 1
    fi
    
    test_pass "VM pool storage classes configured correctly"
    return 0
}

# Test K8s pool persistent volume creation
test_k8s_pool_pv_creation() {
    test_start "Testing K8s pool persistent volume creation"
    
    # Create test namespace
    kubectl create namespace "$TEST_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Create test PVC
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: k8s-test-pvc
  namespace: $TEST_NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: k8s-app-storage
  resources:
    requests:
      storage: 1Gi
EOF
    
    # Wait for PVC to be bound
    if kubectl wait --for=condition=Bound pvc/k8s-test-pvc -n "$TEST_NAMESPACE" --timeout=60s; then
        log_info "K8s pool test PVC created and bound successfully"
        
        # Get PVC details
        local pvc_status=$(kubectl get pvc k8s-test-pvc -n "$TEST_NAMESPACE" -o jsonpath='{.status.phase}')
        log_info "K8s pool PVC status: $pvc_status"
        
        # Clean up
        kubectl delete pvc k8s-test-pvc -n "$TEST_NAMESPACE"
        kubectl delete namespace "$TEST_NAMESPACE"
        
        test_pass "K8s pool persistent volume creation test passed"
        return 0
    else
        test_fail "K8s pool test PVC failed to bind within timeout"
        kubectl delete pvc k8s-test-pvc -n "$TEST_NAMESPACE" 2>/dev/null || true
        kubectl delete namespace "$TEST_NAMESPACE" 2>/dev/null || true
        return 1
    fi
}

# Test VM pool storage
test_vm_pool_storage() {
    test_start "Testing VM pool storage"
    
    # Check if VM pool storage manager pods are running
    local vm_storage_pods=$(kubectl get pods -n vm-pool-storage -l app=vm-pool-storage-manager --no-headers | wc -l)
    if [[ $vm_storage_pods -gt 0 ]]; then
        log_info "VM pool storage manager pods are running: $vm_storage_pods"
    else
        test_fail "No VM pool storage manager pods are running"
        return 1
    fi
    
    # Check VM storage directory structure
    if kubectl exec -n vm-pool-storage daemonset/vm-pool-storage-manager -- test -d /vm-storage; then
        log_info "VM storage directory exists"
    else
        test_fail "VM storage directory does not exist"
        return 1
    fi
    
    # Check VM storage subdirectories
    local vm_subdirs=("images" "templates" "instances" "snapshots" "backups")
    for subdir in "${vm_subdirs[@]}"; do
        if kubectl exec -n vm-pool-storage daemonset/vm-pool-storage-manager -- test -d "/vm-storage/$subdir"; then
            log_info "VM storage subdirectory $subdir exists"
        else
            test_fail "VM storage subdirectory $subdir does not exist"
            return 1
        fi
    done
    
    test_pass "VM pool storage is configured correctly"
    return 0
}

# Test network isolation
test_network_isolation() {
    test_start "Testing network isolation"
    
    # Check if network policies exist
    local network_policies=$(kubectl get networkpolicies --all-namespaces | grep -E "(k8s-pool|vm-pool)" | wc -l)
    if [[ $network_policies -gt 0 ]]; then
        log_info "Network isolation policies exist: $network_policies"
    else
        test_fail "No network isolation policies found"
        return 1
    fi
    
    # Check if isolation monitor is running
    local isolation_monitor_pods=$(kubectl get pods -n network-isolation -l app=resource-pool-isolation-monitor --no-headers | wc -l)
    if [[ $isolation_monitor_pods -gt 0 ]]; then
        log_info "Resource pool isolation monitor pods are running: $isolation_monitor_pods"
    else
        test_fail "No resource pool isolation monitor pods are running"
        return 1
    fi
    
    test_pass "Network isolation is configured correctly"
    return 0
}

# Test cross-pool isolation
test_cross_pool_isolation() {
    test_start "Testing cross-pool isolation"
    
    # Create isolation test job
    kubectl create job --from=cronjob/test-resource-pool-isolation isolation-test-manual -n network-isolation
    
    # Wait for test to complete
    if kubectl wait --for=condition=complete job/isolation-test-manual -n network-isolation --timeout=300s; then
        log_info "Isolation test completed successfully"
        
        # Get test results
        local test_output=$(kubectl logs job/isolation-test-manual -n network-isolation)
        echo "$test_output"
        
        # Check if test passed
        if echo "$test_output" | grep -q "All isolation tests passed!"; then
            log_info "Cross-pool isolation test passed"
        else
            test_fail "Cross-pool isolation test failed"
            kubectl delete job isolation-test-manual -n network-isolation
            return 1
        fi
        
        # Clean up test job
        kubectl delete job isolation-test-manual -n network-isolation
        
        test_pass "Cross-pool isolation test passed"
        return 0
    else
        test_fail "Isolation test failed to complete within timeout"
        kubectl delete job isolation-test-manual -n network-isolation 2>/dev/null || true
        return 1
    fi
}

# Test storage monitoring
test_storage_monitoring() {
    test_start "Testing storage monitoring"
    
    # Test K8s pool storage monitoring
    if kubectl exec -n k8s-pool-storage deployment/k8s-pool-local-path-provisioner -- /k8s-storage/monitor-k8s-storage.sh >/dev/null 2>&1; then
        log_info "K8s pool storage monitoring works"
    else
        test_fail "K8s pool storage monitoring failed"
        return 1
    fi
    
    # Test VM pool storage monitoring
    if kubectl exec -n vm-pool-storage daemonset/vm-pool-storage-manager -- /vm-storage/monitor-vm-storage.sh >/dev/null 2>&1; then
        log_info "VM pool storage monitoring works"
    else
        test_fail "VM pool storage monitoring failed"
        return 1
    fi
    
    test_pass "Storage monitoring is working correctly"
    return 0
}

# Test storage cleanup
test_storage_cleanup() {
    test_start "Testing storage cleanup"
    
    # Check if K8s pool cleanup cronjob exists
    if kubectl get cronjob k8s-pool-storage-cleanup -n k8s-pool-storage >/dev/null 2>&1; then
        log_info "K8s pool storage cleanup cronjob exists"
    else
        test_fail "K8s pool storage cleanup cronjob does not exist"
        return 1
    fi
    
    # Check if VM pool cleanup cronjob exists
    if kubectl get cronjob vm-pool-storage-cleanup -n vm-pool-storage >/dev/null 2>&1; then
        log_info "VM pool storage cleanup cronjob exists"
    else
        test_fail "VM pool storage cleanup cronjob does not exist"
        return 1
    fi
    
    # Test manual cleanup job creation
    if kubectl create job --from=cronjob/k8s-pool-storage-cleanup k8s-cleanup-test -n k8s-pool-storage --dry-run=client >/dev/null 2>&1; then
        log_info "K8s pool cleanup job can be created manually"
    else
        test_fail "K8s pool cleanup job cannot be created manually"
        return 1
    fi
    
    if kubectl create job --from=cronjob/vm-pool-storage-cleanup vm-cleanup-test -n vm-pool-storage --dry-run=client >/dev/null 2>&1; then
        log_info "VM pool cleanup job can be created manually"
    else
        test_fail "VM pool cleanup job cannot be created manually"
        return 1
    fi
    
    test_pass "Storage cleanup is configured correctly"
    return 0
}

# Test resource pool performance
test_resource_pool_performance() {
    test_start "Testing resource pool performance"
    
    # Create test namespace
    kubectl create namespace "$TEST_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Create test pod with K8s pool storage
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: perf-test-pvc
  namespace: $TEST_NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: k8s-app-storage
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
        log_info "K8s pool write performance: 100MB in ${write_time}s"
        
        # Test read performance
        local read_start=$(date +%s)
        kubectl exec perf-test-pod -n "$TEST_NAMESPACE" -- dd if=/test/testfile of=/dev/null bs=1M 2>/dev/null
        local read_end=$(date +%s)
        local read_time=$((read_end - read_start))
        log_info "K8s pool read performance: 100MB in ${read_time}s"
        
        # Clean up
        kubectl delete pod perf-test-pod -n "$TEST_NAMESPACE"
        kubectl delete pvc perf-test-pvc -n "$TEST_NAMESPACE"
        kubectl delete namespace "$TEST_NAMESPACE"
        
        test_pass "Resource pool performance test completed"
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
    echo "ISOLATED RESOURCE POOLS TEST SUMMARY"
    echo "=========================================="
    echo ""
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed! Isolated resource pools are working correctly."
        echo ""
        echo "Resource pools are ready for:"
        echo "  - Kubernetes persistent volumes (K8s pool)"
        echo "  - VM provisioning (VM pool)"
        echo "  - Complete isolation between pools"
        echo "  - Independent monitoring and management"
        echo ""
        echo "Next steps:"
        echo "  1. Deploy applications using K8s pool storage classes"
        echo "  2. Create VMs using VM pool storage"
        echo "  3. Monitor resource usage for each pool"
        echo "  4. Set up backup procedures for each pool"
        return 0
    else
        log_error "Some tests failed. Please review the errors above."
        echo ""
        echo "Common issues:"
        echo "  - Nodes not properly labeled for resource pools"
        echo "  - Storage not properly mounted on nodes"
        echo "  - Network isolation policies not applied"
        echo "  - Storage classes not configured correctly"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting isolated resource pools tests..."
    echo "=========================================="
    
    # Run all tests
    check_prerequisites
    test_resource_pool_namespaces
    test_node_labels
    test_k8s_pool_storage_classes
    test_vm_pool_storage_classes
    test_k8s_pool_pv_creation
    test_vm_pool_storage
    test_network_isolation
    test_cross_pool_isolation
    test_storage_monitoring
    test_storage_cleanup
    test_resource_pool_performance
    
    # Display summary
    display_test_summary
}

# Run main function
main "$@"