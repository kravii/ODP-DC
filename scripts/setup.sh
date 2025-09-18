#!/bin/bash

# Hetzner DC & Kubernetes Cluster Setup Script
# This script automates the complete setup process

set -e

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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check required commands
    local required_commands=("terraform" "ansible" "kubectl" "helm" "docker")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "$cmd is not installed. Please install it first."
            exit 1
        fi
    done
    
    # Check if .env file exists
    if [[ ! -f ".env" ]]; then
        log_error ".env file not found. Please copy .env.example to .env and configure it."
        exit 1
    fi
    
    # Source environment variables
    source .env
    
    # Check required environment variables
    local required_vars=("HETZNER_API_TOKEN" "CLUSTER_NAME")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            log_error "Required environment variable $var is not set in .env file"
            exit 1
        fi
    done
    
    log_success "Prerequisites check passed"
}

# Install required packages
install_packages() {
    log_info "Installing required packages..."
    
    # Update package list
    sudo apt-get update
    
    # Install required packages
    sudo apt-get install -y \
        curl \
        wget \
        git \
        vim \
        htop \
        net-tools \
        bridge-utils \
        iptables \
        conntrack \
        socat \
        ipvsadm \
        python3 \
        python3-pip \
        python3-venv \
        jq \
        unzip
    
    log_success "Required packages installed"
}

# Install Terraform
install_terraform() {
    log_info "Installing Terraform..."
    
    if command -v terraform &> /dev/null; then
        log_info "Terraform is already installed"
        return
    fi
    
    # Download and install Terraform
    local terraform_version="1.5.7"
    wget "https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_amd64.zip"
    unzip "terraform_${terraform_version}_linux_amd64.zip"
    sudo mv terraform /usr/local/bin/
    rm "terraform_${terraform_version}_linux_amd64.zip"
    
    log_success "Terraform installed"
}

# Install Ansible
install_ansible() {
    log_info "Installing Ansible..."
    
    if command -v ansible &> /dev/null; then
        log_info "Ansible is already installed"
        return
    fi
    
    # Install Ansible via pip
    pip3 install ansible
    
    log_success "Ansible installed"
}

# Install kubectl
install_kubectl() {
    log_info "Installing kubectl..."
    
    if command -v kubectl &> /dev/null; then
        log_info "kubectl is already installed"
        return
    fi
    
    # Download and install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    
    log_success "kubectl installed"
}

# Install Helm
install_helm() {
    log_info "Installing Helm..."
    
    if command -v helm &> /dev/null; then
        log_info "Helm is already installed"
        return
    fi
    
    # Download and install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    log_success "Helm installed"
}

# Install Docker
install_docker() {
    log_info "Installing Docker..."
    
    if command -v docker &> /dev/null; then
        log_info "Docker is already installed"
        return
    fi
    
    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    sudo usermod -aG docker $USER
    
    log_success "Docker installed"
}

# Setup Python virtual environment
setup_python_env() {
    log_info "Setting up Python virtual environment..."
    
    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate
    
    # Install Python dependencies
    pip install --upgrade pip
    pip install -r vm-provisioning/api/requirements.txt
    
    log_success "Python virtual environment setup complete"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    log_info "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    # Initialize Terraform
    terraform init
    
    # Plan deployment
    terraform plan -var="hetzner_token=$HETZNER_API_TOKEN" \
                   -var="cluster_name=$CLUSTER_NAME" \
                   -var="control_plane_count=$CONTROL_PLANE_COUNT" \
                   -var="worker_node_count=$WORKER_NODE_COUNT"
    
    # Apply deployment
    terraform apply -auto-approve \
                    -var="hetzner_token=$HETZNER_API_TOKEN" \
                    -var="cluster_name=$CLUSTER_NAME" \
                    -var="control_plane_count=$CONTROL_PLANE_COUNT" \
                    -var="worker_node_count=$WORKER_NODE_COUNT"
    
    cd ..
    
    log_success "Infrastructure deployed successfully"
}

# Setup Kubernetes cluster with Ansible
setup_kubernetes() {
    log_info "Setting up Kubernetes cluster with Ansible..."
    
    cd ansible
    
    # Run Kubernetes setup playbook
    ansible-playbook -i inventory/hosts.yml playbooks/setup-k8s-cluster.yml
    
    cd ..
    
    log_success "Kubernetes cluster setup complete"
}

# Install monitoring stack
install_monitoring() {
    log_info "Installing monitoring stack..."
    
    cd ansible
    
    # Run monitoring installation playbook
    ansible-playbook -i inventory/hosts.yml playbooks/install-monitoring.yml
    
    cd ..
    
    log_success "Monitoring stack installed"
}

# Install Rancher
install_rancher() {
    log_info "Installing Rancher..."
    
    cd ansible
    
    # Run Rancher installation playbook
    ansible-playbook -i inventory/hosts.yml playbooks/install-rancher.yml
    
    cd ..
    
    log_success "Rancher installed"
}

# Deploy VM provisioning system
deploy_vm_provisioning() {
    log_info "Deploying VM provisioning system..."
    
    # Create namespace
    kubectl create namespace vm-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy VM provisioning components
    kubectl apply -f kubernetes/vm-provisioning/
    
    log_success "VM provisioning system deployed"
}

# Setup database
setup_database() {
    log_info "Setting up database..."
    
    # Deploy PostgreSQL
    kubectl apply -f kubernetes/database/
    
    # Wait for database to be ready
    kubectl wait --for=condition=ready pod -l app=postgresql -n vm-system --timeout=300s
    
    log_success "Database setup complete"
}

# Deploy frontend
deploy_frontend() {
    log_info "Deploying frontend..."
    
    # Build frontend Docker image
    cd vm-provisioning/frontend
    docker build -t vm-provisioning-frontend .
    cd ../..
    
    # Deploy frontend
    kubectl apply -f kubernetes/frontend/
    
    log_success "Frontend deployed"
}

# Configure notifications
configure_notifications() {
    log_info "Configuring notifications..."
    
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        log_info "Slack notifications configured"
    fi
    
    if [[ -n "$JIRA_WEBHOOK_URL" ]]; then
        log_info "JIRA notifications configured"
    fi
    
    log_success "Notifications configured"
}

# Display access information
display_access_info() {
    log_info "Setup complete! Access information:"
    echo ""
    echo "=== Kubernetes Cluster ==="
    echo "API Server: $(terraform -chdir=terraform output -raw api_server_endpoint)"
    echo "Kubeconfig: ~/.kube/config"
    echo ""
    echo "=== Rancher ==="
    echo "URL: https://rancher.$CLUSTER_NAME.local"
    echo "Username: admin"
    echo "Password: $RANCHER_ADMIN_PASSWORD"
    echo ""
    echo "=== Grafana ==="
    echo "URL: http://$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
    echo "Username: $GRAFANA_ADMIN_USER"
    echo "Password: $GRAFANA_ADMIN_PASSWORD"
    echo ""
    echo "=== VM Provisioning API ==="
    echo "URL: http://$(kubectl get svc vm-provisioner-service -n vm-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
    echo ""
    echo "=== Frontend ==="
    echo "URL: http://$(kubectl get svc vm-provisioning-frontend -n vm-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
    echo ""
    echo "=== Management Tools ==="
    echo "kubectl: Command-line Kubernetes management"
    echo "k9s: Terminal-based UI (install with: brew install k9s)"
    echo "Telepresence: Local development (install with: brew install telepresence)"
    echo ""
    echo "=== Next Steps ==="
    echo "1. Update your /etc/hosts file with the cluster IPs"
    echo "2. Access Rancher to manage your cluster"
    echo "3. Use the VM provisioning frontend to create VMs"
    echo "4. Monitor your infrastructure with Grafana"
    echo ""
}

# Main setup function
main() {
    log_info "Starting Hetzner DC & Kubernetes Cluster Setup"
    echo ""
    
    # Check if running as root
    check_root
    
    # Check prerequisites
    check_prerequisites
    
    # Install required packages
    install_packages
    
    # Install tools
    install_terraform
    install_ansible
    install_kubectl
    install_helm
    install_docker
    
    # Setup Python environment
    setup_python_env
    
    # Deploy infrastructure
    deploy_infrastructure
    
    # Setup Kubernetes
    setup_kubernetes
    
    # Install monitoring
    install_monitoring
    
    # Install Rancher
    install_rancher
    
    # Setup database
    setup_database
    
    # Deploy VM provisioning
    deploy_vm_provisioning
    
    # Deploy frontend
    deploy_frontend
    
    # Configure notifications
    configure_notifications
    
    # Display access information
    display_access_info
    
    log_success "Setup completed successfully!"
    echo ""
    log_info "Please log out and log back in to use Docker without sudo"
}

# Run main function
main "$@"