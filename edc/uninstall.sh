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

# Configuration
NAMESPACE="${NAMESPACE:-$DEFAULT_NAMESPACE}"
RELEASE_NAME="${RELEASE_NAME:-$DEFAULT_RELEASE_NAME}"
DRY_RUN="${DRY_RUN:-false}"
FORCE="${FORCE:-false}"
DELETE_NAMESPACE="${DELETE_NAMESPACE:-false}"
PURGE_CRDS="${PURGE_CRDS:-false}"
TIMEOUT="${TIMEOUT:-300s}"

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

Uninstall Eclipse Dataspace Connector (EDC) Helm release

OPTIONS:
    -n, --namespace NAMESPACE       Kubernetes namespace (default: $DEFAULT_NAMESPACE)
    -r, --release RELEASE_NAME      Helm release name (default: $DEFAULT_RELEASE_NAME)
    -d, --dry-run                   Perform a dry run without uninstalling
    -f, --force                     Skip confirmation prompts
    --delete-namespace              Delete the namespace after uninstalling
    --purge-crds                    Remove Custom Resource Definitions (use with caution)
    -t, --timeout TIMEOUT          Timeout for operations (default: $TIMEOUT)
    -h, --help                      Show this help message

ENVIRONMENT VARIABLES:
    NAMESPACE                       Override default namespace
    RELEASE_NAME                    Override default release name
    DRY_RUN                         Set to 'true' for dry run
    FORCE                           Set to 'true' to skip confirmations
    DELETE_NAMESPACE                Set to 'true' to delete namespace
    PURGE_CRDS                      Set to 'true' to remove CRDs
    TIMEOUT                         Override default timeout

EXAMPLES:
    # Basic uninstallation with confirmation
    ./uninstall.sh

    # Force uninstall without prompts
    ./uninstall.sh --force

    # Dry run to see what would be uninstalled
    ./uninstall.sh --dry-run

    # Uninstall and delete namespace
    ./uninstall.sh --delete-namespace

    # Complete cleanup including CRDs (dangerous!)
    ./uninstall.sh --force --delete-namespace --purge-crds

WARNING:
    Using --purge-crds can affect other applications in your cluster that depend 
    on these resources. Use with extreme caution!

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
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -f|--force)
                FORCE="true"
                shift
                ;;
            --delete-namespace)
                DELETE_NAMESPACE="true"
                shift
                ;;
            --purge-crds)
                PURGE_CRDS="true"
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
    
    print_success "Prerequisites check passed"
}

# Function to confirm action
confirm_action() {
    if [[ "$FORCE" == "true" || "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    local message="$1"
    echo -e "${YELLOW}$message${NC}"
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Operation cancelled by user"
        exit 0
    fi
}

# Function to check if release exists
check_release_exists() {
    print_status "Checking if release $RELEASE_NAME exists in namespace $NAMESPACE..."
    
    if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        print_success "Release $RELEASE_NAME found"
        return 0
    else
        print_warning "Release $RELEASE_NAME not found in namespace $NAMESPACE"
        return 1
    fi
}

# Function to show what will be uninstalled
show_uninstall_preview() {
    print_status "=== UNINSTALL PREVIEW ==="
    print_status "Release: $RELEASE_NAME"
    print_status "Namespace: $NAMESPACE"
    
    if [[ "$DELETE_NAMESPACE" == "true" ]]; then
        print_warning "Namespace $NAMESPACE will be DELETED"
    fi
    
    if [[ "$PURGE_CRDS" == "true" ]]; then
        print_warning "Custom Resource Definitions will be PURGED"
    fi
    
    # Show current resources
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_status "Current resources in namespace $NAMESPACE:"
        kubectl get all -n "$NAMESPACE" 2>/dev/null || print_warning "No resources found or access denied"
        
        # Show PVCs
        if kubectl get pvc -n "$NAMESPACE" &> /dev/null 2>&1; then
            print_status "Persistent Volume Claims:"
            kubectl get pvc -n "$NAMESPACE"
        fi
        
        # Show secrets
        if kubectl get secrets -n "$NAMESPACE" &> /dev/null 2>&1; then
            print_status "Secrets (first 10):"
            kubectl get secrets -n "$NAMESPACE" | head -10
        fi
    fi
}

# Function to uninstall EDC release
uninstall_edc() {
    if ! check_release_exists; then
        print_warning "Release $RELEASE_NAME not found, skipping Helm uninstall"
        return 0
    fi
    
    print_status "Uninstalling EDC release: $RELEASE_NAME"
    
    local dry_run_flag=""
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_flag="--dry-run"
        print_warning "Performing dry run - no actual uninstallation will occur"
    fi
    
    # Uninstall the Helm release
    helm uninstall "$RELEASE_NAME" \
        --namespace "$NAMESPACE" \
        --timeout="$TIMEOUT" \
        $dry_run_flag
    
    if [[ "$DRY_RUN" != "true" ]]; then
        print_success "EDC release $RELEASE_NAME uninstalled successfully"
    else
        print_success "Dry run: EDC release $RELEASE_NAME would be uninstalled"
    fi
}

# Function to clean up remaining resources
cleanup_remaining_resources() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "Dry run: Would clean up remaining resources"
        return 0
    fi
    
    print_status "Cleaning up remaining resources..."
    
    # Clean up PVCs that might not be deleted automatically
    if kubectl get pvc -n "$NAMESPACE" &> /dev/null; then
        print_status "Cleaning up Persistent Volume Claims..."
        kubectl delete pvc --all -n "$NAMESPACE" --timeout="$TIMEOUT" || print_warning "Failed to delete some PVCs"
    fi
    
    # Clean up secrets created by the chart
    if kubectl get secrets -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME" &> /dev/null; then
        print_status "Cleaning up release-specific secrets..."
        kubectl delete secrets -l "app.kubernetes.io/instance=$RELEASE_NAME" -n "$NAMESPACE" || print_warning "Failed to delete some secrets"
    fi
    
    # Clean up configmaps created by the chart
    if kubectl get configmaps -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME" &> /dev/null; then
        print_status "Cleaning up release-specific configmaps..."
        kubectl delete configmaps -l "app.kubernetes.io/instance=$RELEASE_NAME" -n "$NAMESPACE" || print_warning "Failed to delete some configmaps"
    fi
    
    print_success "Resource cleanup completed"
}

# Function to delete namespace
delete_namespace() {
    if [[ "$DELETE_NAMESPACE" != "true" ]]; then
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "Dry run: Would delete namespace $NAMESPACE"
        return 0
    fi
    
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_warning "Namespace $NAMESPACE does not exist"
        return 0
    fi
    
    confirm_action "This will DELETE the entire namespace '$NAMESPACE' and ALL its contents!"
    
    print_status "Deleting namespace: $NAMESPACE"
    kubectl delete namespace "$NAMESPACE" --timeout="$TIMEOUT"
    
    print_success "Namespace $NAMESPACE deleted successfully"
}


# Function to purge CRDs
purge_crds() {
    if [[ "$PURGE_CRDS" != "true" ]]; then
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "Dry run: Would purge CRDs"
        return 0
    fi
    
    confirm_action "This will PURGE Custom Resource Definitions! This is DANGEROUS and may break other applications in your cluster!"
    
    print_status "Purging CRDs..."
    
    # Remove EDC/Tractus-X related CRDs
    print_status "Removing EDC/Tractus-X CRDs..."
    kubectl get crd | grep -E "(edc|tractus)" | awk '{print $1}' | xargs -r kubectl delete crd || print_warning "Failed to delete some EDC CRDs"
    
    print_success "CRD purge completed"
}

# Function to show post-uninstall information
show_post_uninstall_info() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_success "Dry run completed successfully"
        return 0
    fi
    
    cat << EOF

${GREEN}=== EDC Uninstallation Complete ===${NC}

Release Name: $RELEASE_NAME
Namespace: $NAMESPACE

${BLUE}What was removed:${NC}
- Helm release: $RELEASE_NAME
- EDC components (controlplane, dataplane, vault, databases)
- Associated services, ingresses, and configmaps

EOF

    if [[ "$DELETE_NAMESPACE" == "true" ]]; then
        echo -e "${YELLOW}- Namespace: $NAMESPACE${NC}"
    fi
    
    if [[ "$PURGE_CRDS" == "true" ]]; then
        echo -e "${YELLOW}- Custom Resource Definitions${NC}"
    fi
    
    cat << EOF

${BLUE}Verification:${NC}
Check that resources are gone:
- helm list -n $NAMESPACE
- kubectl get all -n $NAMESPACE

${YELLOW}Note:${NC}
- Persistent volumes may still exist if they were created with a retain policy
- Some cluster-wide resources may remain if not explicitly removed
- cert-manager and ingress controller are not affected by this uninstallation

EOF
}

# Main execution function
main() {
    print_status "Starting EDC uninstallation..."
    
    # Parse command line arguments
    parse_args "$@"
    
    # Check prerequisites
    check_prerequisites
    
    # Show what will be uninstalled
    show_uninstall_preview
    
    # Confirm the uninstallation
    if [[ "$DRY_RUN" != "true" ]]; then
        confirm_action "This will uninstall the EDC release '$RELEASE_NAME' from namespace '$NAMESPACE'."
    fi
    
    # Uninstall EDC release
    uninstall_edc
    
    # Clean up remaining resources
    cleanup_remaining_resources
    
    # Delete namespace if requested
    delete_namespace
    
    # Purge CRDs if requested
    purge_crds
    
    # Show post-uninstall information
    show_post_uninstall_info
    
    print_success "EDC uninstallation script completed successfully!"
}

# Trap to handle script interruption
trap 'print_error "Uninstallation interrupted"; exit 1' INT TERM

# Run main function with all arguments
main "$@"
