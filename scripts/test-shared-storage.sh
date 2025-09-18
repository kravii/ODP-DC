#!/bin/bash

# Test Shared Storage Configuration Script
# Tests the 1.8TB RAID storage setup for Kubernetes and VM provisioning

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KUBECTL_CMD="kubectl"
TEST_NAMESPACE="storage-test"

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

# Test storage namespaces
test_storage_namespaces() {
    test_start "Testing storage namespaces"
    
    local namespaces=("shared-storage-system" "vm-system")
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" >/dev/null 2>&1; then
            log_info "Namespace $ns exists"
        else
            test_fail "Namespace $ns does not exist"
            return 1
        fi
    done
    
    test_pass "Storage namespaces exist"
    return 0
}

# Test storage classes
test_storage_classes() {
    test_start "Testing storage classes"
    
    local storage_classes=("shared-storage-fast" "shared-storage-slow" "shared-storage-monitoring" "vm-storage")
    
    for sc in "${storage_classes[@]}"; do
        if kubectl get storageclass "$sc" >/dev/null 2>&1; then
            log_info "Storage class $sc exists"
        else
            test_fail "Storage class $sc does not exist"
            return 1
        fi
    done
    
    # Check if shared-storage-fast is default
    local default_sc=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
    if [[ "$default_sc" == "shared-storage-fast" ]]; then
        log_info "shared-storage-fast is set as default storage class"
    else
        test_fail "shared-storage-fast is not set as default storage class"
        return 1
    fi
    
    test_pass "Storage classes configured correctly"
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
  storageClassName: shared-storage-fast
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

# Test storage monitoring
test_storage_monitoring() {
    test_start "Testing storage monitoring"
    
    # Check if storage monitor pod is running
    local monitor_pods=$(kubectl get pods -n shared-storage-system -l app=storage-monitor --no-headers | wc -l)
    if [[ $monitor_pods -gt 0 ]]; then
        log_info "Storage monitor pods are running: $monitor_pods"
    else
        test_fail "No storage monitor pods are running"
        return 1
    fi
    
    # Test storage usage command
    if kubectl exec -n shared-storage-system deployment/enhanced-local-path-provisioner -- /shared-storage/monitor-storage.sh usage >/dev/null 2>&1; then
        log_info "Storage usage command works"
    else
        test_fail "Storage usage command failed"
        return 1
    fi
    
    # Test storage stats command
    if kubectl exec -n shared-storage-system deployment/enhanced-local-path-provisioner -- /shared-storage/monitor-storage.sh stats >/dev/null 2>&1; then
        log_info "Storage stats command works"
    else
        test_fail "Storage stats command failed"
        return 1
    fi
    
    # Test storage health command
    if kubectl exec -n shared-storage-system deployment/enhanced-local-path-provisioner -- /shared-storage/monitor-storage.sh health >/dev/null 2>&1; then
        log_info "Storage health command works"
    else
        test_fail "Storage health command failed"
        return 1
    fi
    
    test_pass "Storage monitoring is working correctly"
    return 0
}

# Test VM provisioning
test_vm_provisioning() {
    test_start "Testing VM provisioning"
    
    # Check if VM provisioner pods are running
    local vm_provisioner_pods=$(kubectl get pods -n vm-system -l app=vm-provisioner --no-headers | wc -l)
    if [[ $vm_provisioner_pods -gt 0 ]]; then
        log_info "VM provisioner pods are running: $vm_provisioner_pods"
    else
        test_fail "No VM provisioner pods are running"
        return 1
    fi
    
    # Check if VM storage manager pods are running
    local vm_storage_pods=$(kubectl get pods -n vm-system -l app=vm-storage-manager --no-headers | wc -l)
    if [[ $vm_storage_pods -gt 0 ]]; then
        log_info "VM storage manager pods are running: $vm_storage_pods"
    else
        test_fail "No VM storage manager pods are running"
        return 1
    fi
    
    # Check VM storage directory structure
    if kubectl exec -n vm-system deployment/vm-provisioner -- test -d /shared-storage/vm-storage; then
        log_info "VM storage directory exists"
    else
        test_fail "VM storage directory does not exist"
        return 1
    fi
    
    # Check VM storage subdirectories
    local vm_subdirs=("images" "templates" "instances" "snapshots")
    for subdir in "${vm_subdirs[@]}"; do
        if kubectl exec -n vm-system deployment/vm-provisioner -- test -d "/shared-storage/vm-storage/$subdir"; then
            log_info "VM storage subdirectory $subdir exists"
        else
            test_fail "VM storage subdirectory $subdir does not exist"
            return 1
        fi
    done
    
    test_pass "VM provisioning is configured correctly"
    return 0
}

# Test storage cleanup
test_storage_cleanup() {
    test_start "Testing storage cleanup"
    
    # Check if storage cleanup cronjob exists
    if kubectl get cronjob storage-cleanup -n shared-storage-system >/dev/null 2>&1; then
        log_info "Storage cleanup cronjob exists"
    else
        test_fail "Storage cleanup cronjob does not exist"
        return 1
    fi
    
    # Check if VM storage cleanup cronjob exists
    if kubectl get cronjob vm-storage-cleanup -n vm-system >/dev/null 2>&1; then
        log_info "VM storage cleanup cronjob exists"
    else
        test_fail "VM storage cleanup cronjob does not exist"
        return 1
    fi
    
    # Test manual cleanup job creation
    if kubectl create job --from=cronjob/storage-cleanup storage-cleanup-test -n shared-storage-system --dry-run=client >/dev/null 2>&1; then
        log_info "Storage cleanup job can be created manually"
    else
        test_fail "Storage cleanup job cannot be created manually"
        return 1
    fi
    
    test_pass "Storage cleanup is configured correctly"
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
  storageClassName: shared-storage-fast
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

# Test storage health
test_storage_health() {
    test_start "Testing storage health"
    
    # Get storage health information
    local health_output=$(kubectl exec -n shared-storage-system deployment/enhanced-local-path-provisioner -- /shared-storage/monitor-storage.sh health 2>/dev/null)
    
    if [[ -n "$health_output" ]]; then
        log_info "Storage health check output received"
        echo "$health_output"
    else
        test_fail "Storage health check failed"
        return 1
    fi
    
    # Check for critical errors
    if echo "$health_output" | grep -q "CRITICAL"; then
        test_fail "Critical storage issues detected"
        return 1
    fi
    
    # Check for warnings
    if echo "$health_output" | grep -q "WARNING"; then
        log_warning "Storage warnings detected (this may be normal)"
    fi
    
    test_pass "Storage health check passed"
    return 0
}

# Display test summary
display_test_summary() {
    echo ""
    echo "=========================================="
    echo "STORAGE CONFIGURATION TEST SUMMARY"
    echo "=========================================="
    echo ""
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed! Storage configuration is working correctly."
        echo ""
        echo "Storage is ready for:"
        echo "  - Kubernetes persistent volumes"
        echo "  - VM provisioning"
        echo "  - Monitoring and logging"
        echo "  - Backup and recovery"
        echo ""
        echo "Next steps:"
        echo "  1. Deploy your applications using the storage classes"
        echo "  2. Create VMs using the VM provisioning API"
        echo "  3. Monitor storage usage regularly"
        echo "  4. Set up backup procedures"
        return 0
    else
        log_error "Some tests failed. Please review the errors above."
        echo ""
        echo "Common issues:"
        echo "  - Storage not properly mounted on nodes"
        echo "  - Permissions not set correctly"
        echo "  - Kubernetes resources not deployed"
        echo "  - Network connectivity issues"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting storage configuration tests..."
    echo "=========================================="
    
    # Run all tests
    check_prerequisites
    test_storage_namespaces
    test_storage_classes
    test_persistent_volume_creation
    test_storage_monitoring
    test_vm_provisioning
    test_storage_cleanup
    test_storage_performance
    test_storage_health
    
    # Display summary
    display_test_summary
}

# Run main function
main "$@"