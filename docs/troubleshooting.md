# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the Hetzner DC & Kubernetes cluster setup.

## Table of Contents

1. [Common Issues](#common-issues)
2. [Infrastructure Issues](#infrastructure-issues)
3. [Kubernetes Issues](#kubernetes-issues)
4. [Monitoring Issues](#monitoring-issues)
5. [VM Provisioning Issues](#vm-provisioning-issues)
6. [Network Issues](#network-issues)
7. [Performance Issues](#performance-issues)
8. [Log Collection](#log-collection)
9. [Health Checks](#health-checks)
10. [Recovery Procedures](#recovery-procedures)

## Common Issues

### Setup Script Failures

#### Problem: Setup script fails with permission errors

**Symptoms:**
- Permission denied errors
- Cannot create directories or files
- SSH key generation fails

**Solutions:**
```bash
# Check if running as root (should not be)
whoami

# Fix file permissions
chmod +x scripts/setup.sh
chmod 600 ~/.ssh/id_rsa

# Check sudo access
sudo -l
```

#### Problem: Environment variables not loaded

**Symptoms:**
- "Required environment variable not set" errors
- Terraform/Ansible fails with missing variables

**Solutions:**
```bash
# Check .env file exists and is readable
ls -la .env
cat .env

# Source environment variables
source .env

# Verify variables are set
echo $HETZNER_API_TOKEN
echo $CLUSTER_NAME
```

### Dependency Installation Issues

#### Problem: Package installation fails

**Symptoms:**
- apt-get update fails
- Package not found errors
- Dependency conflicts

**Solutions:**
```bash
# Update package lists
sudo apt-get update

# Fix broken packages
sudo apt-get --fix-broken install

# Clean package cache
sudo apt-get clean
sudo apt-get autoclean

# Install packages individually
sudo apt-get install -y curl wget git
```

#### Problem: Python/pip installation issues

**Symptoms:**
- Python version conflicts
- pip installation fails
- Virtual environment creation fails

**Solutions:**
```bash
# Check Python version
python3 --version

# Install pip if missing
sudo apt-get install -y python3-pip

# Upgrade pip
python3 -m pip install --upgrade pip

# Create virtual environment
python3 -m venv venv
source venv/bin/activate
```

## Infrastructure Issues

### Terraform Deployment Failures

#### Problem: Hetzner API authentication fails

**Symptoms:**
- "Invalid API token" errors
- 401 Unauthorized responses
- Resource creation fails

**Solutions:**
```bash
# Verify API token
curl -H "Authorization: Bearer $HETZNER_API_TOKEN" \
     https://api.hetzner.cloud/v1/servers

# Check token permissions in Hetzner Cloud Console
# Ensure token has read/write permissions

# Regenerate token if needed
# Update .env file with new token
```

#### Problem: Resource creation fails due to limits

**Symptoms:**
- "Resource limit exceeded" errors
- Server creation fails
- Insufficient quota errors

**Solutions:**
```bash
# Check Hetzner account limits
curl -H "Authorization: Bearer $HETZNER_API_TOKEN" \
     https://api.hetzner.cloud/v1/limits

# Reduce server count in terraform/variables.tf
# Use smaller server types
# Check available regions
```

#### Problem: Network configuration issues

**Symptoms:**
- Load balancer creation fails
- Network connectivity issues
- DNS resolution problems

**Solutions:**
```bash
# Check network configuration
terraform plan -var="hetzner_token=$HETZNER_API_TOKEN"

# Verify region availability
curl -H "Authorization: Bearer $HETZNER_API_TOKEN" \
     https://api.hetzner.cloud/v1/locations

# Check firewall rules
# Ensure ports 22, 6443, 80, 443 are open
```

### Server Provisioning Issues

#### Problem: Servers fail to boot

**Symptoms:**
- Servers stuck in "starting" state
- SSH connection fails
- Cloud-init errors

**Solutions:**
```bash
# Check server status in Hetzner Console
# Review server console output
# Check cloud-init logs
ssh root@<server-ip> "journalctl -u cloud-init"

# Verify SSH key is correct
ssh-keygen -l -f ~/.ssh/id_rsa.pub
```

#### Problem: Disk mounting issues

**Symptoms:**
- Additional volumes not mounted
- Disk space errors
- Storage not accessible

**Solutions:**
```bash
# Check disk availability
ssh root@<server-ip> "lsblk"

# Format and mount disk
ssh root@<server-ip> "mkfs.ext4 /dev/sdb"
ssh root@<server-ip> "mkdir -p /mnt/data"
ssh root@<server-ip> "mount /dev/sdb /mnt/data"

# Add to fstab
ssh root@<server-ip> "echo '/dev/sdb /mnt/data ext4 defaults 0 0' >> /etc/fstab"
```

## Kubernetes Issues

### Cluster Initialization Failures

#### Problem: kubeadm init fails

**Symptoms:**
- Control plane initialization fails
- API server not accessible
- Certificate generation errors

**Solutions:**
```bash
# Check system requirements
ssh root@<control-plane-ip> "kubeadm config images list"

# Reset cluster if needed
ssh root@<control-plane-ip> "kubeadm reset --force"

# Check network connectivity
ssh root@<control-plane-ip> "ping <worker-ip>"

# Verify firewall rules
ssh root@<control-plane-ip> "ufw status"
```

#### Problem: Worker nodes fail to join

**Symptoms:**
- Worker nodes not appearing in cluster
- Join command fails
- Network connectivity issues

**Solutions:**
```bash
# Get join command from control plane
ssh root@<control-plane-ip> "kubeadm token create --print-join-command"

# Check worker node connectivity
ssh root@<worker-ip> "ping <control-plane-ip>"

# Verify worker node prerequisites
ssh root@<worker-ip> "systemctl status docker"
ssh root@<worker-ip> "systemctl status kubelet"
```

### Pod and Service Issues

#### Problem: Pods stuck in Pending state

**Symptoms:**
- Pods not starting
- Resource allocation errors
- Node scheduling issues

**Solutions:**
```bash
# Check pod status
kubectl get pods --all-namespaces

# Describe pod for details
kubectl describe pod <pod-name> -n <namespace>

# Check node resources
kubectl top nodes
kubectl describe nodes

# Check resource quotas
kubectl get resourcequota -n <namespace>
```

#### Problem: Services not accessible

**Symptoms:**
- Service endpoints not working
- Load balancer not created
- DNS resolution fails

**Solutions:**
```bash
# Check service status
kubectl get svc --all-namespaces

# Check endpoints
kubectl get endpoints

# Check ingress
kubectl get ingress --all-namespaces

# Check DNS
kubectl run test-dns --image=busybox --rm -it -- nslookup kubernetes.default
```

## Monitoring Issues

### Prometheus Issues

#### Problem: Prometheus not collecting metrics

**Symptoms:**
- No metrics in Prometheus UI
- Targets showing as down
- Scrape errors

**Solutions:**
```bash
# Check Prometheus pod status
kubectl get pods -n monitoring -l app=prometheus

# Check Prometheus logs
kubectl logs -n monitoring -l app=prometheus

# Check service discovery
kubectl get svc -n monitoring

# Verify RBAC permissions
kubectl get clusterrole prometheus
kubectl get clusterrolebinding prometheus
```

#### Problem: Grafana not accessible

**Symptoms:**
- Grafana UI not loading
- Authentication failures
- Dashboard errors

**Solutions:**
```bash
# Check Grafana pod status
kubectl get pods -n monitoring -l app=grafana

# Check Grafana logs
kubectl logs -n monitoring -l app=grafana

# Check service
kubectl get svc -n monitoring prometheus-grafana

# Port forward for testing
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

### Alerting Issues

#### Problem: Alerts not firing

**Symptoms:**
- No alerts in AlertManager
- Notification channels not working
- Alert rules not evaluated

**Solutions:**
```bash
# Check AlertManager status
kubectl get pods -n monitoring -l app=alertmanager

# Check alert rules
kubectl get configmap -n monitoring prometheus-alert-rules

# Check notification configuration
kubectl get configmap -n monitoring alertmanager-config

# Test alert rules
curl -X POST http://<prometheus-ip>:9090/api/v1/rules
```

## VM Provisioning Issues

### API Issues

#### Problem: VM provisioning API not responding

**Symptoms:**
- API endpoints return errors
- VM creation fails
- Database connection errors

**Solutions:**
```bash
# Check API pod status
kubectl get pods -n vm-system -l app=vm-provisioner

# Check API logs
kubectl logs -n vm-system -l app=vm-provisioner

# Check database connectivity
kubectl get pods -n vm-system -l app=postgresql

# Test API endpoints
curl http://<api-service-ip>:8080/health
```

#### Problem: VM creation fails

**Symptoms:**
- VM creation returns errors
- Resource allocation failures
- Hetzner API errors

**Solutions:**
```bash
# Check Hetzner API token
curl -H "Authorization: Bearer $HETZNER_API_TOKEN" \
     https://api.hetzner.cloud/v1/server_types

# Check available resources
curl http://<api-service-ip>:8080/api/v1/resources

# Check VM creation logs
kubectl logs -n vm-system -l app=vm-provisioner | grep "VM creation"
```

### Frontend Issues

#### Problem: Frontend not loading

**Symptoms:**
- Web UI not accessible
- API connection errors
- Authentication failures

**Solutions:**
```bash
# Check frontend pod status
kubectl get pods -n vm-system -l app=vm-provisioning-frontend

# Check frontend logs
kubectl logs -n vm-system -l app=vm-provisioning-frontend

# Check service
kubectl get svc -n vm-system vm-provisioning-frontend-service

# Test frontend
curl http://<frontend-service-ip>:80
```

## Network Issues

### Connectivity Issues

#### Problem: Nodes cannot communicate

**Symptoms:**
- Pods cannot reach each other
- Service discovery fails
- Network policies blocking traffic

**Solutions:**
```bash
# Check CNI status
kubectl get pods -n kube-system -l app=flannel

# Check network policies
kubectl get networkpolicies --all-namespaces

# Test pod-to-pod communication
kubectl run test-pod --image=busybox --rm -it -- ping <other-pod-ip>

# Check iptables rules
ssh root@<node-ip> "iptables -L"
```

#### Problem: External connectivity issues

**Symptoms:**
- Cannot reach external services
- DNS resolution fails
- Internet connectivity problems

**Solutions:**
```bash
# Check DNS configuration
kubectl get svc -n kube-system kube-dns

# Test DNS resolution
kubectl run test-dns --image=busybox --rm -it -- nslookup google.com

# Check node connectivity
ssh root@<node-ip> "ping google.com"

# Check firewall rules
ssh root@<node-ip> "ufw status"
```

## Performance Issues

### Resource Exhaustion

#### Problem: High CPU usage

**Symptoms:**
- Slow response times
- Pod evictions
- Node pressure

**Solutions:**
```bash
# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check resource limits
kubectl describe nodes

# Scale down resource-intensive pods
kubectl scale deployment <deployment-name> --replicas=1

# Add more worker nodes
# Update terraform configuration
```

#### Problem: Memory pressure

**Symptoms:**
- OOMKilled pods
- Swap usage
- Performance degradation

**Solutions:**
```bash
# Check memory usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check memory limits
kubectl describe pods

# Adjust resource requests/limits
kubectl edit deployment <deployment-name>

# Add more memory to nodes
# Upgrade server types in terraform
```

### Storage Issues

#### Problem: Storage space issues

**Symptoms:**
- Pod creation fails
- Volume mounting errors
- Disk space warnings

**Solutions:**
```bash
# Check disk usage
kubectl get pv
kubectl get pvc --all-namespaces

# Check node disk usage
ssh root@<node-ip> "df -h"

# Clean up unused resources
kubectl delete pvc --field-selector=status.phase=Released

# Expand storage
# Add more storage to nodes
```

## Log Collection

### System Logs

```bash
# Collect system logs
journalctl -u kubelet > kubelet.log
journalctl -u docker > docker.log
journalctl -u containerd > containerd.log

# Collect kernel logs
dmesg > kernel.log

# Collect network logs
ip addr show > network.log
iptables -L > iptables.log
```

### Kubernetes Logs

```bash
# Collect cluster logs
kubectl get events --all-namespaces > events.log
kubectl get pods --all-namespaces -o wide > pods.log
kubectl get nodes -o wide > nodes.log

# Collect component logs
kubectl logs -n kube-system -l component=kube-apiserver > apiserver.log
kubectl logs -n kube-system -l component=kube-controller-manager > controller.log
kubectl logs -n kube-system -l component=kube-scheduler > scheduler.log
```

### Application Logs

```bash
# Collect application logs
kubectl logs -n monitoring -l app=prometheus > prometheus.log
kubectl logs -n monitoring -l app=grafana > grafana.log
kubectl logs -n vm-system -l app=vm-provisioner > vm-provisioner.log
```

## Health Checks

### Cluster Health

```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get svc --all-namespaces

# Check cluster health
kubectl cluster-info
kubectl version

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

### Service Health

```bash
# Check service endpoints
kubectl get endpoints

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it -- wget -qO- <service-url>

# Check ingress
kubectl get ingress --all-namespaces
```

### Monitoring Health

```bash
# Check monitoring stack
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# Test Prometheus
curl http://<prometheus-ip>:9090/api/v1/query?query=up

# Test Grafana
curl http://<grafana-ip>:3000/api/health
```

## Recovery Procedures

### Cluster Recovery

#### Problem: Control plane failure

**Solutions:**
```bash
# Check control plane status
kubectl get nodes

# Restart control plane services
ssh root@<control-plane-ip> "systemctl restart kubelet"
ssh root@<control-plane-ip> "systemctl restart docker"

# Recover from backup
# Restore etcd data
# Rejoin worker nodes
```

#### Problem: Worker node failure

**Solutions:**
```bash
# Drain failed node
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Remove node from cluster
kubectl delete node <node-name>

# Provision new node
# Run terraform apply
# Join new node to cluster
```

### Data Recovery

#### Problem: Database corruption

**Solutions:**
```bash
# Check database status
kubectl get pods -n vm-system -l app=postgresql

# Restore from backup
kubectl exec -it <postgres-pod> -- pg_restore -d <database> <backup-file>

# Recreate database if needed
kubectl delete pvc postgresql-pvc -n vm-system
kubectl apply -f kubernetes/database/
```

#### Problem: Configuration loss

**Solutions:**
```bash
# Restore from git
git checkout HEAD -- terraform/
git checkout HEAD -- ansible/
git checkout HEAD -- kubernetes/

# Reapply configurations
terraform apply
kubectl apply -f kubernetes/
```

### Service Recovery

#### Problem: Service not responding

**Solutions:**
```bash
# Restart service
kubectl rollout restart deployment/<deployment-name>

# Scale down and up
kubectl scale deployment <deployment-name> --replicas=0
kubectl scale deployment <deployment-name> --replicas=1

# Check service configuration
kubectl describe svc <service-name>
kubectl describe deployment <deployment-name>
```

This troubleshooting guide provides comprehensive solutions for common issues. For additional support, check the logs, review the configuration, and consult the official documentation for each component.