#!/bin/bash

# Uninstall script for construct-x base infrastructure chart
# This script safely uninstalls the base Helm chart and optionally cleans up resources

set -euo pipefail

# Default configuration
DEFAULT_NAMESPACE="ingress"
DEFAULT_RELEASE="base-infrastructure"
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
FORCE=false
DELETE_NAMESPACE=false
PURGE_CRDS=false
VERBOSE=false
SKIP_CONFIRMATION=false

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

Uninstall the construct-x base infrastructure Helm chart.

OPTIONS:
    -n, --namespace NAMESPACE    Kubernetes namespace (default: ${DEFAULT_NAMESPACE})
    -r, --release RELEASE        Helm release name (default: ${DEFAULT_RELEASE})
    --dry-run                   Perform a dry run without uninstalling
    --force                     Skip confirmation prompts
    --delete-namespace          Delete the namespace after uninstalling
    --purge-crds               Remove cert-manager CRDs (DANGEROUS - affects other cert-manager instances)
    --timeout DURATION          Helm timeout (default: ${HELM_TIMEOUT})
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

EXAMPLES:
    $0                                          # Uninstall with confirmation
    $0 --force                                  # Uninstall without confirmation
    $0 -n production -r prod-base --force       # Uninstall from production
    $0 --dry-run                               # See what would be uninstalled
    $0 --delete-namespace --force              # Uninstall and delete namespace

DESCRIPTION:
    This script uninstalls the base infrastructure chart which includes:
    - ingress-nginx controller
    - cert-manager
    - ClusterIssuer resources

    The script will:
    1. Check if the release exists
    2. Show what will be uninstalled (unless --force)
    3. Uninstall the Helm release
    4. Optionally delete the namespace
    5. Optionally purge cert-manager CRDs (use with caution)

WARNING:
    - Using --purge-crds will remove cert-manager CRDs which may affect other
      cert-manager installations in the cluster
    - Using --delete-namespace will remove the entire namespace and all resources in it
    - Always use --dry-run first to see what will be affected

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

# Function to check if release exists
check_release_exists() {
    print_info "Checking if release '${RELEASE}' exists in namespace '${NAMESPACE}'..."
    
    if helm list -n "${NAMESPACE}" | grep -q "^${RELEASE}"; then
        print_info "Release '${RELEASE}' found in namespace '${NAMESPACE}'"
        return 0
    else
        print_warning "Release '${RELEASE}' not found in namespace '${NAMESPACE}'"
        
        # Check if it exists in other namespaces
        local other_namespaces
        other_namespaces=$(helm list -A | grep "^${RELEASE}" | awk '{print $2}' || true)
        
        if [[ -n "${other_namespaces}" ]]; then
            print_warning "Release '${RELEASE}' found in other namespace(s): ${other_namespaces}"
            print_info "Use -n option to specify the correct namespace"
        fi
        
        return 1
    fi
}

# Function to show what will be uninstalled
show_release_info() {
    print_info "Release information:"
    helm list -n "${NAMESPACE}" | grep "^${RELEASE}" || true
    
    print_info ""
    print_info "Resources that will be affected:"
    kubectl get all -n "${NAMESPACE}" -l "app.kubernetes.io/managed-by=Helm" 2>/dev/null || true
    
    # Show ClusterIssuer resources (cluster-wide)
    print_info ""
    print_info "ClusterIssuer resources (cluster-wide):"
    kubectl get clusterissuer 2>/dev/null || print_info "No ClusterIssuer resources found"
}

# Function to confirm uninstallation
confirm_uninstall() {
    if [[ "${FORCE}" == "true" ]] || [[ "${DRY_RUN}" == "true" ]]; then
        return 0
    fi
    
    print_warning "You are about to uninstall the base infrastructure chart."
    print_warning "This will remove ingress-nginx, cert-manager, and related resources."
    
    if [[ "${DELETE_NAMESPACE}" == "true" ]]; then
        print_warning "The namespace '${NAMESPACE}' will also be DELETED!"
    fi
    
    if [[ "${PURGE_CRDS}" == "true" ]]; then
        print_warning "cert-manager CRDs will be PURGED! This affects ALL cert-manager instances in the cluster!"
    fi
    
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
}

# Function to uninstall the chart
uninstall_chart() {
    print_info "Uninstalling base infrastructure chart..."
    
    local helm_cmd="helm uninstall ${RELEASE} --namespace ${NAMESPACE} --timeout ${HELM_TIMEOUT}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        helm_cmd="${helm_cmd} --dry-run"
    fi
    
    if [[ "${VERBOSE}" == "true" ]]; then
        helm_cmd="${helm_cmd} --debug"
    fi
    
    print_info "Executing: ${helm_cmd}"
    
    if eval "${helm_cmd}"; then
        if [[ "${DRY_RUN}" == "true" ]]; then
            print_success "Dry run completed - chart would be uninstalled"
        else
            print_success "Base infrastructure chart uninstalled successfully"
        fi
    else
        print_error "Failed to uninstall base infrastructure chart"
        exit 1
    fi
}

# Function to delete namespace
delete_namespace() {
    if [[ "${DELETE_NAMESPACE}" != "true" ]]; then
        return 0
    fi
    
    print_info "Deleting namespace '${NAMESPACE}'..."
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        print_info "[DRY RUN] Would delete namespace: ${NAMESPACE}"
        return 0
    fi
    
    if kubectl get namespace "${NAMESPACE}" &> /dev/null; then
        kubectl delete namespace "${NAMESPACE}" --timeout="${HELM_TIMEOUT}"
        print_success "Namespace '${NAMESPACE}' deleted"
    else
        print_info "Namespace '${NAMESPACE}' does not exist"
    fi
}

# Function to purge cert-manager CRDs
purge_crds() {
    if [[ "${PURGE_CRDS}" != "true" ]]; then
        return 0
    fi
    
    print_warning "Purging cert-manager CRDs..."
    print_warning "This will affect ALL cert-manager instances in the cluster!"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        print_info "[DRY RUN] Would delete cert-manager CRDs"
        kubectl get crd | grep cert-manager || print_info "No cert-manager CRDs found"
        return 0
    fi
    
    # Delete cert-manager CRDs
    local crds
    crds=$(kubectl get crd | grep cert-manager | awk '{print $1}' || true)
    
    if [[ -n "${crds}" ]]; then
        echo "${crds}" | xargs kubectl delete crd
        print_success "cert-manager CRDs purged"
    else
        print_info "No cert-manager CRDs found"
    fi
}

# Function to cleanup remaining resources
cleanup_remaining_resources() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        print_info "[DRY RUN] Would check for remaining resources"
        return 0
    fi
    
    print_info "Checking for remaining resources..."
    
    # Check for any remaining resources in the namespace
    local remaining_resources
    remaining_resources=$(kubectl get all -n "${NAMESPACE}" 2>/dev/null || true)
    
    if [[ -n "${remaining_resources}" ]] && [[ "${remaining_resources}" != "No resources found in ${NAMESPACE} namespace." ]]; then
        print_warning "Some resources may still exist in namespace '${NAMESPACE}':"
        echo "${remaining_resources}"
        print_info "You may need to manually clean these up"
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
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --delete-namespace)
            DELETE_NAMESPACE=true
            shift
            ;;
        --purge-crds)
            PURGE_CRDS=true
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
    print_info "Starting base infrastructure uninstallation..."
    print_info "Namespace: ${NAMESPACE}"
    print_info "Release: ${RELEASE}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        print_warning "DRY RUN MODE - No actual changes will be made"
    fi
    
    check_prerequisites
    
    if check_release_exists; then
        show_release_info
        confirm_uninstall
        uninstall_chart
        cleanup_remaining_resources
        delete_namespace
        purge_crds
        
        if [[ "${DRY_RUN}" != "true" ]]; then
            print_success "Uninstallation process completed!"
            print_info ""
            print_info "To verify removal, run:"
            print_info "  helm list -n ${NAMESPACE}"
            print_info "  kubectl get all -n ${NAMESPACE}"
        fi
    else
        print_error "Release '${RELEASE}' not found in namespace '${NAMESPACE}'"
        print_info "Nothing to uninstall"
        exit 1
    fi
}

# Run main function
main "$@"
