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

# Function to confirm uninstall
confirm_uninstall() {
    print_warning "This will uninstall the entire ingress stack including:"
    echo "  - nginx ingress controller (from 'ingress' namespace)"
    echo "  - cert-manager (from 'cert-manager' namespace)"
    echo "  - ClusterIssuer 'letsencrypt-prod'"
    echo "  - All associated CRDs and resources"
    echo ""
    print_warning "This action cannot be undone!"
    echo ""
    
    read -p "Are you sure you want to proceed? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Uninstall cancelled by user"
        exit 0
    fi
}

# Function to check for existing ingress resources
check_existing_ingress_resources() {
    print_status "Checking for existing ingress resources..."
    
    local ingress_count
    ingress_count=$(kubectl get ingress --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
    
    if [[ $ingress_count -gt 0 ]]; then
        print_warning "Found $ingress_count ingress resource(s) in the cluster:"
        kubectl get ingress --all-namespaces
        echo ""
        print_warning "These ingress resources will become non-functional after uninstalling the ingress controller"
        read -p "Continue anyway? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            print_status "Uninstall cancelled by user"
            exit 0
        fi
    fi
}

# Function to check for existing certificates
check_existing_certificates() {
    print_status "Checking for existing cert-manager certificates..."
    
    local cert_count
    cert_count=$(kubectl get certificates --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
    
    if [[ $cert_count -gt 0 ]]; then
        print_warning "Found $cert_count certificate(s) managed by cert-manager:"
        kubectl get certificates --all-namespaces
        echo ""
        print_warning "These certificates will be removed and SSL will stop working"
        read -p "Continue anyway? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            print_status "Uninstall cancelled by user"
            exit 0
        fi
    fi
}

# Function to remove ClusterIssuer
remove_clusterissuer() {
    print_status "Checking for ClusterIssuer 'letsencrypt-prod'..."
    
    if kubectl get clusterissuer letsencrypt-prod &> /dev/null; then
        print_status "Removing ClusterIssuer 'letsencrypt-prod'..."
        kubectl delete clusterissuer letsencrypt-prod --ignore-not-found=true
        print_success "ClusterIssuer 'letsencrypt-prod' removed"
    else
        print_warning "ClusterIssuer 'letsencrypt-prod' not found, skipping"
    fi
    
    # Also remove the associated secret if it exists
    if kubectl get secret letsencrypt-prod -n cert-manager &> /dev/null; then
        print_status "Removing Let's Encrypt private key secret..."
        kubectl delete secret letsencrypt-prod -n cert-manager --ignore-not-found=true
        print_success "Let's Encrypt private key secret removed"
    fi
}

# Function to uninstall nginx ingress controller
uninstall_nginx_ingress() {
    print_status "Checking if nginx ingress controller is installed..."
    
    if ! kubectl get namespace ingress &> /dev/null; then
        print_warning "nginx ingress controller namespace 'ingress' not found, skipping"
        return 0
    fi
    
    if ! helm list -n ingress | grep -q "ingress-nginx"; then
        print_warning "nginx ingress controller helm release not found, skipping"
    else
        print_status "Uninstalling nginx ingress controller..."
        helm uninstall ingress-nginx -n ingress
        print_success "nginx ingress controller uninstalled"
    fi
    
    # Wait for pods to terminate
    print_status "Waiting for nginx ingress controller pods to terminate..."
    kubectl wait --for=delete pod -l app.kubernetes.io/component=controller -n ingress --timeout=120s || true
    
    # Delete namespace
    print_status "Deleting ingress namespace..."
    kubectl delete namespace ingress --ignore-not-found=true
    
    print_success "nginx ingress controller cleanup completed"
}

# Function to uninstall cert-manager
uninstall_certmanager() {
    print_status "Checking if cert-manager is installed..."
    
    if ! kubectl get namespace cert-manager &> /dev/null; then
        print_warning "cert-manager namespace not found, skipping"
        return 0
    fi
    
    if ! helm list -n cert-manager | grep -q "cert-manager"; then
        print_warning "cert-manager helm release not found, skipping"
    else
        print_status "Uninstalling cert-manager..."
        helm uninstall cert-manager -n cert-manager
        print_success "cert-manager uninstalled"
    fi
    
    # Wait for pods to terminate
    print_status "Waiting for cert-manager pods to terminate..."
    kubectl wait --for=delete pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s || true
    
    # Delete namespace
    print_status "Deleting cert-manager namespace..."
    kubectl delete namespace cert-manager --ignore-not-found=true
    
    # Clean up CRDs
    print_status "Cleaning up cert-manager CRDs..."
    kubectl delete crd \
        certificaterequests.cert-manager.io \
        certificates.cert-manager.io \
        challenges.acme.cert-manager.io \
        clusterissuers.cert-manager.io \
        issuers.cert-manager.io \
        orders.acme.cert-manager.io \
        --ignore-not-found=true
    
    print_success "cert-manager cleanup completed"
}

# Function to clean up remaining resources
cleanup_remaining_resources() {
    print_status "Cleaning up any remaining resources..."
    
    # Remove any remaining ingress classes
    kubectl delete ingressclass nginx --ignore-not-found=true
    
    # Remove any remaining validation webhooks
    kubectl delete validatingwebhookconfigurations cert-manager-webhook --ignore-not-found=true
    kubectl delete mutatingwebhookconfigurations cert-manager-webhook --ignore-not-found=true
    
    print_success "Remaining resources cleaned up"
}

# Function to verify uninstall
verify_uninstall() {
    print_status "Verifying uninstall..."
    
    # Check namespaces
    if kubectl get namespace ingress &> /dev/null; then
        print_warning "ingress namespace still exists"
    else
        print_success "ingress namespace removed"
    fi
    
    if kubectl get namespace cert-manager &> /dev/null; then
        print_warning "cert-manager namespace still exists"
    else
        print_success "cert-manager namespace removed"
    fi
    
    # Check helm releases
    local nginx_releases
    local certmanager_releases
    nginx_releases=$(helm list --all-namespaces | grep ingress-nginx | wc -l || echo "0")
    certmanager_releases=$(helm list --all-namespaces | grep cert-manager | wc -l || echo "0")
    
    if [[ $nginx_releases -eq 0 ]]; then
        print_success "nginx ingress controller helm release removed"
    else
        print_warning "nginx ingress controller helm release still exists"
    fi
    
    if [[ $certmanager_releases -eq 0 ]]; then
        print_success "cert-manager helm release removed"
    else
        print_warning "cert-manager helm release still exists"
    fi
    
    # Check ClusterIssuer
    if kubectl get clusterissuer letsencrypt-prod &> /dev/null; then
        print_warning "ClusterIssuer 'letsencrypt-prod' still exists"
    else
        print_success "ClusterIssuer 'letsencrypt-prod' removed"
    fi
}

# Main execution
main() {
    print_status "Starting ingress stack uninstall..."
    
    # Prerequisites check
    check_kubectl
    check_helm
    
    # Safety checks and confirmations
    confirm_uninstall
    check_existing_ingress_resources
    check_existing_certificates
    
    # Uninstall components (order matters: nginx first, then ClusterIssuer, then cert-manager)
    uninstall_nginx_ingress
    remove_clusterissuer
    uninstall_certmanager
    
    # Cleanup
    cleanup_remaining_resources
    
    # Verify uninstall
    verify_uninstall
    
    print_success "Ingress stack uninstall completed!"
    print_status "All ingress and certificate management components have been removed."
}

# Run main function
main "$@"
