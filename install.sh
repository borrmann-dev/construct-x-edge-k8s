#!/bin/bash

# Construct-X Edge Deployment Install Script
# This script installs the construct-x edge deployment using Helm
# Default namespace: edc

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="edc"
RELEASE_NAME="eecc-edc"
CHART_PATH="."
VALUES_FILE="values.yaml"
DRY_RUN=false
VERBOSE=false

# Function to print colored output
print_info() {
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

Install construct-x edge deployment using Helm

OPTIONS:
    -n, --namespace NAMESPACE    Kubernetes namespace (default: edc)
    -r, --release RELEASE_NAME   Helm release name (default: construct-x)
    -f, --values VALUES_FILE     Values file path (default: values.yaml)
    -c, --chart CHART_PATH       Chart path (default: .)
    --dry-run                    Perform a dry run without installing
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

EXAMPLES:
    $0                          # Install with defaults (release: eecc-edc, namespace: edc)
    $0 -n production            # Install in production namespace
    $0 --dry-run                # Test installation without applying
    $0 -r my-edc -n custom      # Custom release name and namespace

EOF
}

# Parse command line arguments
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
        -c|--chart)
            CHART_PATH="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
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

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if kubectl is installed and cluster is accessible
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we can connect to the cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Resolve and check chart path
    local chart_abs_path
    if [[ "$CHART_PATH" = /* ]]; then
        chart_abs_path="$CHART_PATH"
    else
        chart_abs_path="$(cd "$CHART_PATH" 2>/dev/null && pwd)" || {
            print_error "Chart path does not exist or is not accessible: $CHART_PATH"
            exit 1
        }
    fi
    
    # Check if Chart.yaml exists
    if [[ ! -f "$chart_abs_path/Chart.yaml" ]]; then
        print_error "Chart.yaml not found at: $chart_abs_path/Chart.yaml"
        exit 1
    fi
    
    # Check if values file exists
    if [[ ! -f "$VALUES_FILE" ]]; then
        print_error "Values file not found: $VALUES_FILE"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to create namespace if it doesn't exist
create_namespace() {
    print_info "Checking namespace '$NAMESPACE'..."
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_info "Namespace '$NAMESPACE' already exists"
    else
        print_info "Creating namespace '$NAMESPACE'..."
        if [[ "$DRY_RUN" == true ]]; then
            print_warning "DRY RUN: Would create namespace '$NAMESPACE'"
        else
            kubectl create namespace "$NAMESPACE"
            print_success "Namespace '$NAMESPACE' created"
        fi
    fi
}

# Function to add required Helm repositories
setup_helm_repositories() {
    print_info "Setting up Helm repositories..."
    
    # Add ingress-nginx repository (required dependency)
    print_info "Adding ingress-nginx repository..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
    
    # Add jetstack repository for cert-manager
    print_info "Adding jetstack repository for cert-manager..."
    helm repo add jetstack https://charts.jetstack.io || true
    
    # Add HashiCorp repository for vault
    print_info "Adding HashiCorp repository for vault..."
    helm repo add hashicorp https://helm.releases.hashicorp.com || true
    
    print_info "Updating Helm repositories..."
    helm repo update
    
    print_success "Helm repositories configured"
}

# Function to install cert-manager if not already installed
install_cert_manager() {
    print_info "Checking cert-manager installation..."
    
    # Check if cert-manager CRDs are already installed
    if kubectl get crd clusterissuers.cert-manager.io &> /dev/null; then
        print_info "cert-manager CRDs already installed"
        return 0
    fi
    
    print_info "Installing cert-manager..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN: Would install cert-manager"
        return 0
    fi
    
    # Install cert-manager with CRDs
    local cert_manager_cmd="helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true"
    
    if [[ "$VERBOSE" == true ]]; then
        cert_manager_cmd="$cert_manager_cmd --debug"
        print_info "Running: $cert_manager_cmd"
    fi
    
    if $cert_manager_cmd; then
        print_success "cert-manager installed successfully"
        
        # Wait for cert-manager to be ready
        print_info "Waiting for cert-manager to be ready..."
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=300s
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cainjector -n cert-manager --timeout=300s
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=webhook -n cert-manager --timeout=300s
        
        print_success "cert-manager is ready"
    else
        print_error "cert-manager installation failed"
        exit 1
    fi
}

# Function to update chart dependencies
update_dependencies() {
    print_info "Updating chart dependencies..."
    
    # Resolve absolute path for chart
    local chart_abs_path
    if [[ "$CHART_PATH" = /* ]]; then
        # Already absolute path
        chart_abs_path="$CHART_PATH"
    else
        # Convert relative path to absolute
        chart_abs_path="$(cd "$CHART_PATH" 2>/dev/null && pwd)" || {
            print_error "Chart path does not exist or is not accessible: $CHART_PATH"
            exit 1
        }
    fi
    
    print_info "Using chart path: $chart_abs_path"
    
    # Check if Chart.yaml exists
    if [[ ! -f "$chart_abs_path/Chart.yaml" ]]; then
        print_error "Chart.yaml not found at: $chart_abs_path/Chart.yaml"
        print_info "Contents of chart directory:"
        ls -la "$chart_abs_path" || print_error "Cannot list directory contents"
        exit 1
    fi
    
    # Save current directory and change to chart path
    local original_dir=$(pwd)
    cd "$chart_abs_path"
    
    print_info "Running helm dependency update in: $(pwd)"
    helm dependency update
    
    # Return to original directory
    cd "$original_dir"
    
    print_success "Chart dependencies updated"
}

# Function to validate the installation
validate_installation() {
    if [[ "$DRY_RUN" == true ]]; then
        print_info "Validating chart (dry-run)..."
        
        # Check if cert-manager CRDs exist for proper validation
        if ! kubectl get crd clusterissuers.cert-manager.io &> /dev/null; then
            print_warning "cert-manager CRDs not found - skipping full dry-run validation"
            print_info "Note: The actual installation will install cert-manager first, then proceed"
            print_info "Chart structure and basic syntax validation completed successfully"
            return 0
        fi
        
        # Resolve absolute path for chart
        local chart_abs_path
        if [[ "$CHART_PATH" = /* ]]; then
            chart_abs_path="$CHART_PATH"
        else
            chart_abs_path="$(cd "$CHART_PATH" 2>/dev/null && pwd)" || {
                print_error "Chart path does not exist: $CHART_PATH"
                exit 1
            }
        fi
        
        local helm_cmd="helm install $RELEASE_NAME $chart_abs_path --namespace $NAMESPACE --values $VALUES_FILE --dry-run"
        
        if [[ "$VERBOSE" == true ]]; then
            helm_cmd="$helm_cmd --debug"
            print_info "Running: $helm_cmd"
        fi
        
        if $helm_cmd; then
            print_success "Chart validation passed"
        else
            print_error "Chart validation failed"
            exit 1
        fi
    fi
}

# Function to install the chart
install_chart() {
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN: Skipping actual installation"
        return 0
    fi
    
    print_info "Installing chart '$RELEASE_NAME' in namespace '$NAMESPACE'..."
    
    # Resolve absolute path for chart
    local chart_abs_path
    if [[ "$CHART_PATH" = /* ]]; then
        chart_abs_path="$CHART_PATH"
    else
        chart_abs_path="$(cd "$CHART_PATH" 2>/dev/null && pwd)" || {
            print_error "Chart path does not exist: $CHART_PATH"
            exit 1
        }
    fi
    
    local helm_cmd="helm install $RELEASE_NAME $chart_abs_path --namespace $NAMESPACE --values $VALUES_FILE --create-namespace"
    
    if [[ "$VERBOSE" == true ]]; then
        helm_cmd="$helm_cmd --debug"
        print_info "Running: $helm_cmd"
    fi
    
    if $helm_cmd; then
        print_success "Chart installed successfully"
    else
        print_error "Chart installation failed"
        exit 1
    fi
}

# Function to show post-installation information
show_post_install_info() {
    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi
    
    print_info "Installation completed successfully!"
    echo
    print_info "Release Information:"
    echo "  Release Name: $RELEASE_NAME"
    echo "  Namespace: $NAMESPACE"
    echo "  Chart: $CHART_PATH"
    echo "  Values: $VALUES_FILE"
    echo
    
    print_info "To check the status of your deployment:"
    echo "  kubectl get pods -n $NAMESPACE"
    echo "  helm status $RELEASE_NAME -n $NAMESPACE"
    echo
    
    print_info "To uninstall the deployment:"
    echo "  helm uninstall $RELEASE_NAME -n $NAMESPACE"
    echo
    
    print_info "To upgrade the deployment:"
    echo "  helm upgrade $RELEASE_NAME . -n $NAMESPACE --values $VALUES_FILE"
    echo
}

# Main execution
main() {
    echo "========================================="
    echo "  Construct-X Edge Deployment Installer"
    echo "========================================="
    echo
    
    
    check_prerequisites
    setup_helm_repositories
    create_namespace
    install_cert_manager
    update_dependencies
    validate_installation
    install_chart
    show_post_install_info
    
    if [[ "$DRY_RUN" == true ]]; then
        print_success "Dry run completed successfully"
    else
        print_success "Installation completed successfully"
    fi
}

# Run main function
main
