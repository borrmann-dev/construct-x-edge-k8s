#!/bin/bash

# Install script for construct-x base infrastructure chart
# This script installs the base Helm chart with ingress-nginx and cert-manager dependencies

set -euo pipefail

# Default configuration
DEFAULT_NAMESPACE="ingress"
DEFAULT_RELEASE="base-infrastructure"
CHART_PATH="$(dirname "$0")"
HELM_TIMEOUT="10m"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
NAMESPACE="${DEFAULT_NAMESPACE}"
RELEASE="${DEFAULT_RELEASE}"
DRY_RUN=false
SKIP_DEPS=false
VALUES_FILE=""
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
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Install the construct-x base infrastructure Helm chart.

OPTIONS:
    -n, --namespace NAMESPACE    Kubernetes namespace (default: ${DEFAULT_NAMESPACE})
    -r, --release RELEASE        Helm release name (default: ${DEFAULT_RELEASE})
    -f, --values FILE           Values file to use
    --dry-run                   Perform a dry run without installing
    --skip-deps                 Skip dependency update
    --timeout DURATION          Helm timeout (default: ${HELM_TIMEOUT})
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

EXAMPLES:
    $0                                          # Install with defaults
    $0 -n production -r prod-base               # Install to production namespace
    $0 -f custom-values.yaml --dry-run         # Dry run with custom values
    $0 --skip-deps -v                          # Skip deps update with verbose output

DESCRIPTION:
    This script installs the base infrastructure chart which includes:
    - ingress-nginx controller
    - cert-manager for SSL certificates
    - ClusterIssuer for Let's Encrypt certificates

    The script will:
    1. Check prerequisites (kubectl, helm)
    2. Create namespace if it doesn't exist
    3. Update Helm dependencies (unless --skip-deps)
    4. Install the chart with specified configuration

EOF
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we can connect to Kubernetes cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to create namespace if it doesn't exist
create_namespace() {
    print_info "Checking namespace '${NAMESPACE}'..."
    
    if kubectl get namespace "${NAMESPACE}" &> /dev/null; then
        print_info "Namespace '${NAMESPACE}' already exists"
    else
        print_info "Creating namespace '${NAMESPACE}'..."
        if [[ "${DRY_RUN}" == "true" ]]; then
            print_info "[DRY RUN] Would create namespace: ${NAMESPACE}"
        else
            kubectl create namespace "${NAMESPACE}"
            print_success "Namespace '${NAMESPACE}' created"
        fi
    fi
}

# Function to update Helm dependencies
update_dependencies() {
    if [[ "${SKIP_DEPS}" == "true" ]]; then
        print_info "Skipping dependency update"
        return
    fi
    
    print_info "Updating Helm dependencies..."
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        print_info "[DRY RUN] Would update dependencies for chart: ${CHART_PATH}"
    else
        cd "${CHART_PATH}"
        helm dependency update
        print_success "Dependencies updated"
    fi
}

# Function to install the chart
install_chart() {
    print_info "Installing base infrastructure chart..."
    
    local helm_cmd="helm install ${RELEASE} ${CHART_PATH} --namespace ${NAMESPACE} --timeout ${HELM_TIMEOUT}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        helm_cmd="${helm_cmd} --dry-run"
    fi
    
    if [[ -n "${VALUES_FILE}" ]]; then
        if [[ ! -f "${VALUES_FILE}" ]]; then
            print_error "Values file not found: ${VALUES_FILE}"
            exit 1
        fi
        helm_cmd="${helm_cmd} -f ${VALUES_FILE}"
    fi
    
    if [[ "${VERBOSE}" == "true" ]]; then
        helm_cmd="${helm_cmd} --debug"
    fi
    
    print_info "Executing: ${helm_cmd}"
    
    if eval "${helm_cmd}"; then
        if [[ "${DRY_RUN}" == "true" ]]; then
            print_success "Dry run completed successfully"
        else
            print_success "Base infrastructure chart installed successfully"
            print_info "Release: ${RELEASE}"
            print_info "Namespace: ${NAMESPACE}"
            print_info ""
            print_info "To check the status, run:"
            print_info "  helm status ${RELEASE} -n ${NAMESPACE}"
            print_info ""
            print_info "To see the deployed resources, run:"
            print_info "  kubectl get all -n ${NAMESPACE}"
        fi
    else
        print_error "Failed to install base infrastructure chart"
        exit 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE="$2"
            shift 2
            ;;
        -f|--values)
            VALUES_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        --timeout)
            HELM_TIMEOUT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_info "Starting base infrastructure installation..."
    print_info "Namespace: ${NAMESPACE}"
    print_info "Release: ${RELEASE}"
    print_info "Chart path: ${CHART_PATH}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        print_warning "DRY RUN MODE - No actual changes will be made"
    fi
    
    check_prerequisites
    create_namespace
    update_dependencies
    install_chart
    
    print_success "Installation process completed!"
}

# Run main function
main "$@"
