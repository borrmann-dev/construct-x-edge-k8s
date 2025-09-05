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
DEFAULT_BACKUP_DIR="./backups"

# Configuration
NAMESPACE="${NAMESPACE:-$DEFAULT_NAMESPACE}"
RELEASE_NAME="${RELEASE_NAME:-$DEFAULT_RELEASE_NAME}"
VALUES_FILE="${VALUES_FILE:-$DEFAULT_VALUES_FILE}"
BACKUP_DIR="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_BACKUP="${SKIP_BACKUP:-false}"
SKIP_DEPS="${SKIP_DEPS:-false}"
FORCE_UPGRADE="${FORCE_UPGRADE:-false}"
TIMEOUT="${TIMEOUT:-600s}"
TARGET_VERSION="${TARGET_VERSION:-}"
ROLLBACK_VERSION="${ROLLBACK_VERSION:-}"

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

Upgrade Eclipse Dataspace Connector (EDC) using Helm with backup and rollback capabilities

OPTIONS:
    -n, --namespace NAMESPACE       Kubernetes namespace (default: $DEFAULT_NAMESPACE)
    -r, --release RELEASE_NAME      Helm release name (default: $DEFAULT_RELEASE_NAME)
    -f, --values VALUES_FILE        Values file path (default: $DEFAULT_VALUES_FILE)
    -b, --backup-dir BACKUP_DIR     Backup directory (default: $DEFAULT_BACKUP_DIR)
    -v, --version TARGET_VERSION    Target version to upgrade to (optional)
    --rollback ROLLBACK_VERSION     Rollback to specific version
    -d, --dry-run                   Perform a dry run without upgrading
    --skip-backup                   Skip backup creation (not recommended)
    --skip-deps                     Skip dependency update
    --force                         Force upgrade without confirmation
    -t, --timeout TIMEOUT          Timeout for Helm operations (default: $TIMEOUT)
    -h, --help                      Show this help message

ENVIRONMENT VARIABLES:
    NAMESPACE                       Override default namespace
    RELEASE_NAME                    Override default release name
    VALUES_FILE                     Override default values file
    BACKUP_DIR                      Override default backup directory
    DRY_RUN                         Set to 'true' for dry run
    SKIP_BACKUP                     Set to 'true' to skip backup
    SKIP_DEPS                       Set to 'true' to skip dependencies
    FORCE_UPGRADE                   Set to 'true' to skip confirmations
    TIMEOUT                         Override default timeout
    TARGET_VERSION                  Target version to upgrade to
    ROLLBACK_VERSION                Version to rollback to

PREREQUISITES:
    - kubectl configured and connected to cluster
    - helm installed
    - Existing EDC installation to upgrade

EXAMPLES:
    # Basic upgrade (will prompt for confirmation)
    ./upgrade.sh

    # Upgrade to specific version
    ./upgrade.sh --version 0.2.0

    # Dry run to see what would be upgraded
    ./upgrade.sh --dry-run

    # Force upgrade without confirmation
    ./upgrade.sh --force

    # Rollback to previous version
    ./upgrade.sh --rollback 1

    # Upgrade with custom backup directory
    ./upgrade.sh --backup-dir /path/to/backups

BACKUP AND ROLLBACK:
    - Backups are created automatically before upgrades
    - Backups include: Helm values, release info, and Kubernetes resources
    - Use --rollback option to rollback to a previous release revision
    - Backup directory structure: backups/YYYY-MM-DD_HH-MM-SS_RELEASE_NAME/

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
            -b|--backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -v|--version)
                TARGET_VERSION="$2"
                shift 2
                ;;
            --rollback)
                ROLLBACK_VERSION="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP="true"
                shift
                ;;
            --skip-deps)
                SKIP_DEPS="true"
                shift
                ;;
            --force)
                FORCE_UPGRADE="true"
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
    
    # Check if release exists
    if ! helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        print_error "Release $RELEASE_NAME not found in namespace $NAMESPACE"
        print_error "Use install.sh to install EDC first"
        exit 1
    fi
    
    # Check values file exists (only if not doing rollback)
    if [[ -z "$ROLLBACK_VERSION" && ! -f "$VALUES_FILE" ]]; then
        print_error "Values file not found: $VALUES_FILE"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to get current release information
get_current_release_info() {
    print_status "Getting current release information..."
    
    # Get current release info
    CURRENT_REVISION=$(helm list -n "$NAMESPACE" -o json | jq -r ".[] | select(.name==\"$RELEASE_NAME\") | .revision")
    CURRENT_STATUS=$(helm list -n "$NAMESPACE" -o json | jq -r ".[] | select(.name==\"$RELEASE_NAME\") | .status")
    CURRENT_CHART=$(helm list -n "$NAMESPACE" -o json | jq -r ".[] | select(.name==\"$RELEASE_NAME\") | .chart")
    
    print_status "Current release: $RELEASE_NAME"
    print_status "Current revision: $CURRENT_REVISION"
    print_status "Current status: $CURRENT_STATUS"
    print_status "Current chart: $CURRENT_CHART"
    
    # Check if release is in a good state
    if [[ "$CURRENT_STATUS" != "deployed" ]]; then
        print_warning "Current release status is '$CURRENT_STATUS', not 'deployed'"
        if [[ "$FORCE_UPGRADE" != "true" ]]; then
            read -p "Do you want to continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_error "Upgrade cancelled"
                exit 1
            fi
        fi
    fi
}

# Function to create backup
create_backup() {
    if [[ "$SKIP_BACKUP" == "true" ]]; then
        print_warning "Skipping backup as requested"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "Skipping backup for dry run"
        return 0
    fi
    
    print_status "Creating backup..."
    
    # Create backup directory with timestamp
    local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    local backup_path="$BACKUP_DIR/${timestamp}_${RELEASE_NAME}"
    
    mkdir -p "$backup_path"
    
    # Backup Helm release information
    print_status "Backing up Helm release information..."
    helm get all "$RELEASE_NAME" -n "$NAMESPACE" > "$backup_path/helm_release_all.yaml"
    helm get values "$RELEASE_NAME" -n "$NAMESPACE" > "$backup_path/helm_values.yaml"
    helm get manifest "$RELEASE_NAME" -n "$NAMESPACE" > "$backup_path/helm_manifest.yaml"
    helm history "$RELEASE_NAME" -n "$NAMESPACE" -o json > "$backup_path/helm_history.json"
    
    # Backup Kubernetes resources
    print_status "Backing up Kubernetes resources..."
    kubectl get all -n "$NAMESPACE" -o yaml > "$backup_path/k8s_resources.yaml"
    kubectl get configmaps -n "$NAMESPACE" -o yaml > "$backup_path/k8s_configmaps.yaml"
    kubectl get secrets -n "$NAMESPACE" -o yaml > "$backup_path/k8s_secrets.yaml"
    kubectl get pvc -n "$NAMESPACE" -o yaml > "$backup_path/k8s_pvcs.yaml" 2>/dev/null || true
    kubectl get ingress -n "$NAMESPACE" -o yaml > "$backup_path/k8s_ingress.yaml" 2>/dev/null || true
    
    # Create backup info file
    cat > "$backup_path/backup_info.txt" << EOF
Backup created: $timestamp
Release name: $RELEASE_NAME
Namespace: $NAMESPACE
Current revision: $CURRENT_REVISION
Current status: $CURRENT_STATUS
Current chart: $CURRENT_CHART
Backup path: $backup_path
EOF
    
    # Store backup path for potential rollback
    echo "$backup_path" > "/tmp/edc_last_backup_path"
    
    print_success "Backup created at: $backup_path"
}

# Function to add required Helm repositories
add_helm_repositories() {
    print_status "Adding/updating required Helm repositories..."
    
    # Add Eclipse Tractus-X repository
    helm repo add tractusx-dev https://eclipse-tractusx.github.io/charts/dev 2>/dev/null || true
    
    # Add HashiCorp Vault repository
    helm repo add hashicorp https://helm.releases.hashicorp.com 2>/dev/null || true
    
    # Update repositories
    helm repo update
    
    print_success "Helm repositories updated"
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

# Function to perform rollback
perform_rollback() {
    print_status "Performing rollback to revision $ROLLBACK_VERSION..."
    
    local dry_run_flag=""
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_flag="--dry-run"
        print_warning "Performing dry run - no actual rollback will occur"
    fi
    
    # Perform rollback
    helm rollback "$RELEASE_NAME" "$ROLLBACK_VERSION" \
        --namespace "$NAMESPACE" \
        --wait \
        --timeout="$TIMEOUT" \
        $dry_run_flag
    
    if [[ "$DRY_RUN" != "true" ]]; then
        print_success "Rollback to revision $ROLLBACK_VERSION completed successfully"
    else
        print_success "Rollback dry run completed successfully"
    fi
}

# Function to upgrade EDC
upgrade_edc() {
    print_status "Upgrading EDC with Helm..."
    print_status "Release name: $RELEASE_NAME"
    print_status "Namespace: $NAMESPACE"
    print_status "Values file: $VALUES_FILE"
    print_status "Timeout: $TIMEOUT"
    
    if [[ -n "$TARGET_VERSION" ]]; then
        print_status "Target version: $TARGET_VERSION"
    fi
    
    local dry_run_flag=""
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_flag="--dry-run"
        print_warning "Performing dry run - no actual upgrade will occur"
    fi
    
    # Get chart directory
    local chart_dir=$(dirname "$0")
    
    # Prepare upgrade command
    local upgrade_cmd="helm upgrade"
    upgrade_cmd="$upgrade_cmd $RELEASE_NAME"
    upgrade_cmd="$upgrade_cmd $chart_dir"
    upgrade_cmd="$upgrade_cmd --namespace $NAMESPACE"
    upgrade_cmd="$upgrade_cmd --values $VALUES_FILE"
    upgrade_cmd="$upgrade_cmd --wait"
    upgrade_cmd="$upgrade_cmd --timeout=$TIMEOUT"
    
    # Add version if specified
    if [[ -n "$TARGET_VERSION" ]]; then
        upgrade_cmd="$upgrade_cmd --version $TARGET_VERSION"
    fi
    
    # Add dry run flag if needed
    if [[ -n "$dry_run_flag" ]]; then
        upgrade_cmd="$upgrade_cmd $dry_run_flag"
    fi
    
    # Execute upgrade
    eval "$upgrade_cmd"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        print_success "EDC upgrade completed successfully"
    else
        print_success "Upgrade dry run completed successfully"
    fi
}

# Function to verify upgrade
verify_upgrade() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "Skipping verification for dry run"
        return 0
    fi
    
    print_status "Verifying EDC upgrade..."
    
    # Get new release info
    local new_revision=$(helm list -n "$NAMESPACE" -o json | jq -r ".[] | select(.name==\"$RELEASE_NAME\") | .revision")
    local new_status=$(helm list -n "$NAMESPACE" -o json | jq -r ".[] | select(.name==\"$RELEASE_NAME\") | .status")
    local new_chart=$(helm list -n "$NAMESPACE" -o json | jq -r ".[] | select(.name==\"$RELEASE_NAME\") | .chart")
    
    print_status "New revision: $new_revision"
    print_status "New status: $new_status"
    print_status "New chart: $new_chart"
    
    # Check if upgrade was successful
    if [[ "$new_status" != "deployed" ]]; then
        print_error "Upgrade failed - status is '$new_status'"
        return 1
    fi
    
    if [[ -z "$ROLLBACK_VERSION" && "$new_revision" == "$CURRENT_REVISION" ]]; then
        print_warning "Revision number unchanged - no upgrade may have occurred"
    fi
    
    # Check pod status
    print_status "Checking pod status..."
    kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME"
    
    # Wait for pods to be ready
    print_status "Waiting for pods to be ready..."
    if ! kubectl wait --for=condition=ready pod -l "app.kubernetes.io/instance=$RELEASE_NAME" -n "$NAMESPACE" --timeout=300s; then
        print_warning "Some pods may not be ready yet. Check with: kubectl get pods -n $NAMESPACE"
        return 1
    fi
    
    print_success "Upgrade verification completed successfully"
}

# Function to show upgrade confirmation
show_upgrade_confirmation() {
    if [[ "$FORCE_UPGRADE" == "true" || "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    cat << EOF

${YELLOW}=== EDC Upgrade Confirmation ===${NC}

Current Release: $RELEASE_NAME (revision $CURRENT_REVISION)
Namespace: $NAMESPACE
Current Chart: $CURRENT_CHART
Values File: $VALUES_FILE
EOF
    
    if [[ -n "$TARGET_VERSION" ]]; then
        echo "Target Version: $TARGET_VERSION"
    fi
    
    if [[ "$SKIP_BACKUP" != "true" ]]; then
        echo "Backup Directory: $BACKUP_DIR"
    else
        echo -e "${RED}WARNING: Backup will be skipped!${NC}"
    fi
    
    echo
    read -p "Do you want to proceed with the upgrade? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Upgrade cancelled by user"
        exit 0
    fi
}

# Function to show rollback confirmation
show_rollback_confirmation() {
    if [[ "$FORCE_UPGRADE" == "true" || "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    cat << EOF

${YELLOW}=== EDC Rollback Confirmation ===${NC}

Current Release: $RELEASE_NAME (revision $CURRENT_REVISION)
Namespace: $NAMESPACE
Rollback to Revision: $ROLLBACK_VERSION

EOF
    
    read -p "Do you want to proceed with the rollback? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Rollback cancelled by user"
        exit 0
    fi
}

# Function to show post-upgrade information
show_post_upgrade_info() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    local operation="Upgrade"
    if [[ -n "$ROLLBACK_VERSION" ]]; then
        operation="Rollback"
    fi
    
    cat << EOF

${GREEN}=== EDC $operation Complete ===${NC}

Release Name: $RELEASE_NAME
Namespace: $NAMESPACE

${BLUE}Next Steps:${NC}
1. Check the status of your deployment:
   kubectl get pods -n $NAMESPACE

2. View logs if needed:
   kubectl logs -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME

3. Check the Helm release status:
   helm status $RELEASE_NAME -n $NAMESPACE

4. View upgrade history:
   helm history $RELEASE_NAME -n $NAMESPACE

${BLUE}Rollback Information:${NC}
- If issues occur, you can rollback using:
  ./upgrade.sh --rollback $CURRENT_REVISION
- Or use Helm directly:
  helm rollback $RELEASE_NAME $CURRENT_REVISION -n $NAMESPACE

EOF

    if [[ "$SKIP_BACKUP" != "true" && -f "/tmp/edc_last_backup_path" ]]; then
        local backup_path=$(cat "/tmp/edc_last_backup_path")
        echo -e "${BLUE}Backup Location:${NC}"
        echo "- Backup created at: $backup_path"
        echo
    fi
}

# Function to cleanup temporary files
cleanup() {
    rm -f "/tmp/edc_last_backup_path" 2>/dev/null || true
}

# Main execution function
main() {
    local operation="upgrade"
    if [[ -n "$ROLLBACK_VERSION" ]]; then
        operation="rollback"
    fi
    
    print_status "Starting EDC $operation..."
    
    # Parse command line arguments
    parse_args "$@"
    
    # Check prerequisites
    check_prerequisites
    
    # Get current release information
    get_current_release_info
    
    if [[ -n "$ROLLBACK_VERSION" ]]; then
        # Rollback operation
        show_rollback_confirmation
        perform_rollback
    else
        # Upgrade operation
        show_upgrade_confirmation
        
        # Create backup
        create_backup
        
        # Add required Helm repositories
        add_helm_repositories
        
        # Update Helm dependencies
        update_dependencies
        
        # Upgrade EDC
        upgrade_edc
    fi
    
    # Verify operation
    verify_upgrade
    
    # Show post-operation information
    show_post_upgrade_info
    
    # Cleanup
    cleanup
    
    print_success "EDC $operation script completed successfully!"
}

# Trap to handle script interruption
trap 'print_error "Operation interrupted"; cleanup; exit 1' INT TERM

# Check if jq is available (needed for JSON parsing)
if ! command -v jq &> /dev/null; then
    print_error "jq is required but not installed. Please install jq first."
    exit 1
fi

# Run main function with all arguments
main "$@"
