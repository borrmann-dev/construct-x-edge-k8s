#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "kubectl cannot connect to cluster"
        exit 1
    fi
    
    print_success "kubectl is available and connected to cluster"
}

# Function to check if helm is available
check_helm() {
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed or not in PATH"
        exit 1
    fi
    
    print_success "helm is available"
}

# Function to check if cert-manager is already installed
check_certmanager_installed() {
    print_status "Checking if cert-manager is already installed..."
    
    if kubectl get namespace cert-manager &> /dev/null; then
        if kubectl get deployment -n cert-manager cert-manager &> /dev/null; then
            print_warning "cert-manager is already installed"
            return 0
        fi
    fi
    
    return 1
}

# Function to install cert-manager
install_certmanager() {
    if check_certmanager_installed; then
        return 0
    fi
    
    print_status "Installing cert-manager..."
    
    # Add the Jetstack Helm repository
    print_status "Adding Jetstack Helm repository..."
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    
    # Create cert-manager namespace
    print_status "Creating cert-manager namespace..."
    kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
    
    # Install cert-manager with CRDs
    print_status "Installing cert-manager with Helm..."
    helm upgrade --install \
        cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --set installCRDs=true \
        --wait --timeout=300s
    
    # Wait for cert-manager to be ready
    print_status "Waiting for cert-manager pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
    
    print_success "cert-manager installed successfully"
}

# Function to check if nginx ingress controller is already installed
check_nginx_ingress_installed() {
    print_status "Checking if nginx ingress controller is already installed..."
    
    if kubectl get namespace ingress &> /dev/null; then
        if kubectl get deployment -n ingress ingress-nginx-controller &> /dev/null; then
            print_warning "nginx ingress controller is already installed"
            return 0
        fi
    fi
    
    return 1
}

# Function to install nginx ingress controller
install_nginx_ingress() {
    if check_nginx_ingress_installed; then
        return 0
    fi
    
    print_status "Installing nginx ingress controller..."
    
    # Add the ingress-nginx Helm repository
    print_status "Adding ingress-nginx Helm repository..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    # Create ingress namespace
    print_status "Creating ingress namespace..."
    kubectl create namespace ingress --dry-run=client -o yaml | kubectl apply -f -
    
    # Install nginx ingress controller
    print_status "Installing nginx ingress controller with Helm..."
    helm upgrade --install \
        ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress \
        --wait --timeout=300s
    
    # Wait for nginx ingress controller to be ready
    print_status "Waiting for nginx ingress controller pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller -n ingress --timeout=300s
    
    print_success "nginx ingress controller installed successfully"
}

# Function to verify installations
verify_installations() {
    print_status "Verifying installations..."
    
    # Check cert-manager
    if kubectl get pods -n cert-manager | grep -q "Running"; then
        print_success "cert-manager is running"
    else
        print_error "cert-manager verification failed"
        return 1
    fi
    
    # Check nginx ingress controller
    if kubectl get pods -n ingress | grep -q "Running"; then
        print_success "nginx ingress controller is running"
    else
        print_error "nginx ingress controller verification failed"
        return 1
    fi
    
    # Show service information
    print_status "Nginx ingress controller service information:"
    kubectl get svc -n ingress ingress-nginx-controller
}

# Main execution
main() {
    print_status "Starting ingress stack installation..."
    
    # Prerequisites check
    check_kubectl
    check_helm
    
    # Install components
    install_certmanager
    install_nginx_ingress
    
    # Verify installations
    verify_installations
    
    print_success "Ingress stack installation completed successfully!"
    print_status "You can now create Ingress resources and ClusterIssuers for SSL certificates."
}

# Run main function
main "$@"
