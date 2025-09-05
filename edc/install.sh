#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_NAMESPACE="edc"
DEFAULT_RELEASE_NAME="eecc-edc"
DEFAULT_VALUES_FILE="values.yaml"

# Configuration
NAMESPACE="${NAMESPACE:-$DEFAULT_NAMESPACE}"
RELEASE_NAME="${RELEASE_NAME:-$DEFAULT_RELEASE_NAME}"
VALUES_FILE="${VALUES_FILE:-$DEFAULT_VALUES_FILE}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_DEPS="${SKIP_DEPS:-false}"
TIMEOUT="${TIMEOUT:-600s}"

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

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Install Eclipse Dataspace Connector (EDC) using Helm

OPTIONS:
    -n, --namespace NAMESPACE       Kubernetes namespace (default: $DEFAULT_NAMESPACE)
    -r, --release RELEASE_NAME      Helm release name (default: $DEFAULT_RELEASE_NAME)
    -f, --values VALUES_FILE        Values file path (default: $DEFAULT_VALUES_FILE)
    -d, --dry-run                   Perform a dry run without installing
    -s, --skip-deps                 Skip dependency installation
    -t, --timeout TIMEOUT          Timeout for Helm operations (default: $TIMEOUT)
    -h, --help                      Show this help message

ENVIRONMENT VARIABLES:
    NAMESPACE                       Override default namespace
    RELEASE_NAME                    Override default release name
    VALUES_FILE                     Override default values file
    DRY_RUN                         Set to 'true' for dry run
    SKIP_DEPS                       Set to 'true' to skip dependencies
    TIMEOUT                         Override default timeout

PREREQUISITES:
    - kubectl configured and connected to cluster
    - helm installed
    - cert-manager installed (for SSL certificates, optional)
    - ingress controller installed (if using ingresses)

EXAMPLES:
    # Basic installation
    ./install.sh

    # Install with custom namespace and release name
    ./install.sh -n my-edc -r my-edc-release

    # Dry run to see what would be installed
    ./install.sh --dry-run

    # Skip dependency installation (if already installed)
    ./install.sh --skip-deps

EOF
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -r|--release)
                RELEASE_NAME="$2"
                shift 2
                ;;
            -f|--values)
                VALUES_FILE="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -s|--skip-deps)
                SKIP_DEPS="true"
                shift
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "kubectl cannot connect to cluster"
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed or not in PATH"
        exit 1
    fi
    
    # Check values file exists
    if [[ ! -f "$VALUES_FILE" ]]; then
        print_error "Values file not found: $VALUES_FILE"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to check if cert-manager is available (optional check)
check_certmanager_available() {
    print_status "Checking if cert-manager is available..."
    
    if kubectl get namespace cert-manager &> /dev/null; then
        if kubectl get deployment -n cert-manager cert-manager &> /dev/null; then
            print_success "cert-manager is available"
            return 0
        fi
    fi
    
    print_warning "cert-manager not found - SSL certificates may not work properly"
    print_warning "Consider installing cert-manager first if you need SSL certificates"
    return 1
}

# Function to add required Helm repositories
add_helm_repositories() {
    print_status "Adding required Helm repositories..."
    
    # Add Eclipse Tractus-X repository
    helm repo add tractusx-dev https://eclipse-tractusx.github.io/charts/dev
    
    # Add HashiCorp Vault repository
    helm repo add hashicorp https://helm.releases.hashicorp.com
    
    # Update repositories
    helm repo update
    
    print_success "Helm repositories added and updated"
}

# Function to create namespace
create_namespace() {
    print_status "Creating namespace: $NAMESPACE"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml
    else
        kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    fi
    
    print_success "Namespace $NAMESPACE is ready"
}

# Function to update Helm dependencies
update_dependencies() {
    if [[ "$SKIP_DEPS" == "true" ]]; then
        print_warning "Skipping dependency update as requested"
        return 0
    fi
    
    print_status "Updating Helm dependencies..."
    
    # Get current directory
    local current_dir=$(pwd)
    local chart_dir=$(dirname "$0")
    
    # Change to chart directory
    cd "$chart_dir"
    
    # Update dependencies
    helm dependency update
    
    # Return to original directory
    cd "$current_dir"
    
    print_success "Helm dependencies updated"
}

# Function to install EDC
install_edc() {
    print_status "Installing EDC with Helm..."
    print_status "Release name: $RELEASE_NAME"
    print_status "Namespace: $NAMESPACE"
    print_status "Values file: $VALUES_FILE"
    print_status "Timeout: $TIMEOUT"
    
    local dry_run_flag=""
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_flag="--dry-run"
        print_warning "Performing dry run - no actual installation will occur"
    fi
    
    # Get chart directory
    local chart_dir=$(dirname "$0")
    
    # Install or upgrade the release
    helm upgrade --install \
        "$RELEASE_NAME" \
        "$chart_dir" \
        --namespace "$NAMESPACE" \
        --values "$VALUES_FILE" \
        --wait \
        --timeout="$TIMEOUT" \
        $dry_run_flag
    
    if [[ "$DRY_RUN" != "true" ]]; then
        print_success "EDC installation completed successfully"
    else
        print_success "Dry run completed successfully"
    fi
}

# Function to verify installation
verify_installation() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "Skipping verification for dry run"
        return 0
    fi
    
    print_status "Verifying EDC installation..."
    
    # Check if release exists
    if ! helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        print_error "Release $RELEASE_NAME not found in namespace $NAMESPACE"
        return 1
    fi
    
    # Check pod status
    print_status "Checking pod status..."
    kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME"
    
    # Wait for pods to be ready
    print_status "Waiting for pods to be ready..."
    if ! kubectl wait --for=condition=ready pod -l "app.kubernetes.io/instance=$RELEASE_NAME" -n "$NAMESPACE" --timeout=300s; then
        print_warning "Some pods may not be ready yet. Check with: kubectl get pods -n $NAMESPACE"
    fi
    
    # Show services
    print_status "Services in namespace $NAMESPACE:"
    kubectl get svc -n "$NAMESPACE"
    
    # Show ingresses if any
    if kubectl get ingress -n "$NAMESPACE" &> /dev/null; then
        print_status "Ingresses in namespace $NAMESPACE:"
        kubectl get ingress -n "$NAMESPACE"
    fi
    
    print_success "Installation verification completed"
}

# Function to show post-installation information
show_post_install_info() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    cat << EOF

${GREEN}=== EDC Installation Complete ===${NC}

Release Name: $RELEASE_NAME
Namespace: $NAMESPACE

${BLUE}Next Steps:${NC}
1. Check the status of your deployment:
   kubectl get pods -n $NAMESPACE

2. View logs if needed:
   kubectl logs -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME

3. Access the EDC services through the configured ingresses or port-forward:
   kubectl port-forward -n $NAMESPACE svc/<service-name> <local-port>:<service-port>

4. Check the Helm release status:
   helm status $RELEASE_NAME -n $NAMESPACE

${YELLOW}Important Notes:${NC}
- The EDC includes multiple components: controlplane, dataplane, vault, and databases
- SSL certificates require cert-manager to be installed separately
- Ingress access requires an ingress controller to be installed separately
- Check the ingress hostnames in your values.yaml for external access URLs

EOF
}

# Main execution function
main() {
    print_status "Starting EDC installation..."
    
    # Parse command line arguments
    parse_args "$@"
    
    # Check prerequisites
    check_prerequisites
    
    # Check if cert-manager is available (optional)
    check_certmanager_available
    
    # Add required Helm repositories
    add_helm_repositories
    
    # Create namespace
    create_namespace
    
    # Update Helm dependencies
    update_dependencies
    
    # Install EDC
    install_edc
    
    # Verify installation
    verify_installation
    
    # Show post-installation information
    show_post_install_info
    
    print_success "EDC installation script completed successfully!"
}

# Trap to handle script interruption
trap 'print_error "Installation interrupted"; exit 1' INT TERM

# Run main function with all arguments
main "$@"
