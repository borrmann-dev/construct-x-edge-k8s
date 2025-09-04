#!/bin/bash

# Construct-X Edge Deployment Uninstall Script
# This script uninstalls the construct-x edge deployment using Helm
# Default namespace: edc, Default release: eecc-edc

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
DELETE_NAMESPACE=false
REMOVE_CERT_MANAGER=false
FORCE=false
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

Uninstall construct-x edge deployment using Helm

OPTIONS:
    -n, --namespace NAMESPACE    Kubernetes namespace (default: edc)
    -r, --release RELEASE_NAME   Helm release name (default: eecc-edc)
    --delete-namespace          Delete the namespace after uninstalling
    --remove-cert-manager      Also remove cert-manager (use with caution!)
    --force                     Skip confirmation prompts
    --dry-run                   Show what would be deleted without actually deleting
    -v, --verbose              Enable verbose output
    -h, --help                 Show this help message

EXAMPLES:
    $0                         # Uninstall with defaults (release: eecc-edc, namespace: edc)
    $0 -n production           # Uninstall from production namespace
    $0 --delete-namespace      # Uninstall and delete the namespace
    $0 --dry-run               # Show what would be deleted
    $0 --force                 # Skip confirmation prompts

SAFETY:
    By default, this script will ask for confirmation before uninstalling.
    Use --force to skip confirmations (useful for automation).
    Use --dry-run to see what would be deleted without actually deleting.

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
        --delete-namespace)
            DELETE_NAMESPACE=true
            shift
            ;;
        --remove-cert-manager)
            REMOVE_CERT_MANAGER=true
            shift
            ;;
        --force)
            FORCE=true
            shift
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
    
    print_success "Prerequisites check passed"
}

# Function to check if release exists
check_release_exists() {
    print_info "Checking if release '$RELEASE_NAME' exists in namespace '$NAMESPACE'..."
    
    if helm list -n "$NAMESPACE" | grep -q "^$RELEASE_NAME"; then
        print_info "Release '$RELEASE_NAME' found in namespace '$NAMESPACE'"
        return 0
    else
        print_warning "Release '$RELEASE_NAME' not found in namespace '$NAMESPACE'"
        
        # List available releases in the namespace
        local releases=$(helm list -n "$NAMESPACE" --short)
        if [[ -n "$releases" ]]; then
            print_info "Available releases in namespace '$NAMESPACE':"
            echo "$releases" | sed 's/^/  - /'
        else
            print_info "No releases found in namespace '$NAMESPACE'"
        fi
        
        return 1
    fi
}

# Function to show what will be deleted
show_deletion_preview() {
    print_info "The following resources will be deleted:"
    echo
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN MODE - Nothing will actually be deleted"
        echo
    fi
    
    print_info "Helm Release:"
    echo "  - Release: $RELEASE_NAME"
    echo "  - Namespace: $NAMESPACE"
    
    # Show release resources
    if helm list -n "$NAMESPACE" | grep -q "^$RELEASE_NAME"; then
        print_info "Release Resources:"
        if [[ "$VERBOSE" == true ]]; then
            helm get manifest "$RELEASE_NAME" -n "$NAMESPACE" | grep "^kind:" | sort | uniq -c | sed 's/^/  /'
        else
            echo "  - All Kubernetes resources managed by this Helm release"
        fi
    fi
    
    if [[ "$DELETE_NAMESPACE" == true ]]; then
        print_warning "Namespace Deletion:"
        echo "  - Namespace: $NAMESPACE (and ALL resources within it)"
        echo "  - This will delete ALL resources in the namespace, not just this release!"
    fi
    
    echo
}

# Function to confirm deletion
confirm_deletion() {
    if [[ "$FORCE" == true ]]; then
        print_info "Force mode enabled, skipping confirmation"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi
    
    echo -n "Are you sure you want to proceed with the uninstallation? (yes/no): "
    read -r response
    
    case "$response" in
        yes|YES|y|Y)
            print_info "Proceeding with uninstallation..."
            return 0
            ;;
        *)
            print_info "Uninstallation cancelled"
            exit 0
            ;;
    esac
}

# Function to uninstall the release
uninstall_release() {
    if ! check_release_exists; then
        if [[ "$FORCE" == false ]]; then
            print_error "Release not found. Use --force to continue anyway."
            exit 1
        else
            print_warning "Release not found, but continuing due to --force flag"
        fi
        return 0
    fi
    
    print_info "Uninstalling Helm release '$RELEASE_NAME' from namespace '$NAMESPACE'..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN: Would uninstall release '$RELEASE_NAME' from namespace '$NAMESPACE'"
        return 0
    fi
    
    local helm_cmd="helm uninstall $RELEASE_NAME --namespace $NAMESPACE"
    
    if [[ "$VERBOSE" == true ]]; then
        helm_cmd="$helm_cmd --debug"
        print_info "Running: $helm_cmd"
    fi
    
    if $helm_cmd; then
        print_success "Release '$RELEASE_NAME' uninstalled successfully"
    else
        print_error "Failed to uninstall release '$RELEASE_NAME'"
        exit 1
    fi
}

# Function to delete namespace
delete_namespace() {
    if [[ "$DELETE_NAMESPACE" == false ]]; then
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN: Would delete namespace '$NAMESPACE'"
        return 0
    fi
    
    print_info "Checking if namespace '$NAMESPACE' exists..."
    
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_info "Namespace '$NAMESPACE' does not exist"
        return 0
    fi
    
    # Check if namespace has other resources
    local resource_count=$(kubectl get all -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [[ $resource_count -gt 0 ]]; then
        print_warning "Namespace '$NAMESPACE' contains $resource_count other resources"
        if [[ "$FORCE" == false ]]; then
            echo -n "Delete namespace anyway? This will delete ALL resources in it! (yes/no): "
            read -r response
            case "$response" in
                yes|YES|y|Y)
                    ;;
                *)
                    print_info "Namespace deletion cancelled"
                    return 0
                    ;;
            esac
        fi
    fi
    
    print_info "Deleting namespace '$NAMESPACE'..."
    
    if kubectl delete namespace "$NAMESPACE"; then
        print_success "Namespace '$NAMESPACE' deleted successfully"
    else
        print_error "Failed to delete namespace '$NAMESPACE'"
        exit 1
    fi
}

# Function to show post-uninstall information
show_post_uninstall_info() {
    if [[ "$DRY_RUN" == true ]]; then
        print_success "Dry run completed successfully"
        return 0
    fi
    
    print_success "Uninstallation completed successfully!"
    echo
    
    print_info "What was removed:"
    echo "  - Helm release: $RELEASE_NAME"
    echo "  - Namespace: $NAMESPACE"
    
    if [[ "$DELETE_NAMESPACE" == true ]]; then
        echo "  - Namespace '$NAMESPACE' was deleted"
    else
        echo "  - Namespace '$NAMESPACE' was preserved"
    fi
    
    echo
    print_info "To reinstall the deployment:"
    echo "  ./install.sh -n $NAMESPACE -r $RELEASE_NAME"
    echo
    
    if [[ "$DELETE_NAMESPACE" == false ]]; then
        print_info "To check remaining resources in namespace:"
        echo "  kubectl get all -n $NAMESPACE"
        echo
        
        print_info "To delete the namespace manually:"
        echo "  kubectl delete namespace $NAMESPACE"
        echo
    fi
}

# Main execution
main() {
    echo "==========================================="
    echo "  Construct-X Edge Deployment Uninstaller"
    echo "==========================================="
    echo
    
    check_prerequisites
    show_deletion_preview
    confirm_deletion
    uninstall_release
    delete_namespace
    show_post_uninstall_info
}

# Run main function
main
