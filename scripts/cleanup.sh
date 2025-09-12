#!/bin/bash

# EDC Asset Cleanup Script
# Removes assets, contract definitions, and policies from Eclipse Dataspace Connector
# Usage: ./cleanup.sh <assetId> [options]

set -euo pipefail

# Default configuration
DEFAULT_BASE_URL="https://dataprovider-x-controlplane.construct-x.prod-k8s.eecc.de"
DEFAULT_API_KEY="TEST2"

# Configuration from environment variables or defaults
EDC_BASE_URL="${EDC_BASE_URL:-$DEFAULT_BASE_URL}"
EDC_API_KEY="${EDC_API_KEY:-$DEFAULT_API_KEY}"

# Script options
VERBOSE=false
DRY_RUN=false
FORCE=false
SKIP_CONFIRMATION=false

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

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Help function
show_help() {
    cat << EOF
EDC Asset Cleanup Script

USAGE:
    $0 <assetId> [OPTIONS]

DESCRIPTION:
    Removes an asset and its associated contract definition and policy from 
    Eclipse Dataspace Connector (EDC). The script follows the proper cleanup 
    order: contract definition -> policy -> asset.

ARGUMENTS:
    assetId         The ID of the asset to remove (required)

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -n, --dry-run   Show what would be deleted without actually deleting
    -f, --force     Skip confirmation prompts
    -y, --yes       Skip confirmation prompts (alias for --force)
    
ENVIRONMENT VARIABLES:
    EDC_BASE_URL    Base URL for EDC Management API 
                    (default: $DEFAULT_BASE_URL)
    EDC_API_KEY     API key for authentication
                    (default: $DEFAULT_API_KEY)

EXAMPLES:
    # Remove asset with confirmation
    $0 my-asset-1
    
    # Remove asset without confirmation
    $0 my-asset-1 --force
    
    # Dry run to see what would be deleted
    $0 my-asset-1 --dry-run
    
    # Verbose output
    $0 my-asset-1 --verbose
    
    # Custom EDC endpoint
    EDC_BASE_URL=https://my-edc.example.com $0 my-asset-1

EXIT CODES:
    0    Success
    1    General error
    2    Invalid arguments
    3    API request failed
    4    User cancelled operation

EOF
}

# Parse command line arguments
parse_args() {
    if [[ $# -eq 0 ]]; then
        log_error "Asset ID is required"
        echo
        show_help
        exit 2
    fi
    
    ASSET_ID="$1"
    shift
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force|-y|--yes)
                FORCE=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo
                show_help
                exit 2
                ;;
        esac
    done
}

# Validate inputs
validate_inputs() {
    if [[ -z "$ASSET_ID" ]]; then
        log_error "Asset ID cannot be empty"
        exit 2
    fi
    
    if [[ -z "$EDC_BASE_URL" ]]; then
        log_error "EDC_BASE_URL cannot be empty"
        exit 2
    fi
    
    if [[ -z "$EDC_API_KEY" ]]; then
        log_error "EDC_API_KEY cannot be empty"
        exit 2
    fi
    
    # Validate URL format
    if ! [[ "$EDC_BASE_URL" =~ ^https?:// ]]; then
        log_error "EDC_BASE_URL must start with http:// or https://"
        exit 2
    fi
    
    log_verbose "Asset ID: $ASSET_ID"
    log_verbose "EDC Base URL: $EDC_BASE_URL"
    log_verbose "API Key: ${EDC_API_KEY:0:4}****"
}

# Make HTTP DELETE request with proper error handling
make_delete_request() {
    local url="$1"
    local resource_type="$2"
    local resource_id="$3"
    
    log_verbose "Making DELETE request to: $url"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would delete $resource_type: $resource_id"
        return 0
    fi
    
    local http_code
    local response
    
    # Make the request and capture both response and HTTP status code
    response=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" \
        --request DELETE \
        --url "$url" \
        --header "X-Api-Key: $EDC_API_KEY" \
        --header "Content-Type: application/json" \
        --max-time 30)
    
    http_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    body=$(echo "$response" | sed -E 's/HTTPSTATUS:[0-9]*$//')
    
    log_verbose "HTTP Status Code: $http_code"
    log_verbose "Response Body: $body"
    
    case "$http_code" in
        200|204)
            log_success "Successfully deleted $resource_type: $resource_id"
            return 0
            ;;
        404)
            log_warning "$resource_type not found: $resource_id (may have been already deleted)"
            return 0
            ;;
        401)
            log_error "Authentication failed. Check your EDC_API_KEY."
            return 3
            ;;
        403)
            log_error "Access forbidden. Check your permissions."
            return 3
            ;;
        *)
            log_error "Failed to delete $resource_type: $resource_id (HTTP $http_code)"
            if [[ -n "$body" ]]; then
                log_error "Response: $body"
            fi
            return 3
            ;;
    esac
}

# Confirm deletion with user
confirm_deletion() {
    if [[ "$FORCE" == "true" || "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    echo
    log_warning "This will delete the following resources:"
    echo "  - Asset: $ASSET_ID"
    echo "  - Contract Definition: $CONTRACT_DEFINITION_ID"
    echo "  - Policy: $POLICY_ID"
    echo "  - EDC Endpoint: $EDC_BASE_URL"
    echo
    
    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled by user"
        exit 4
    fi
}

# Main cleanup function
cleanup_resources() {
    local exit_code=0
    
    log_info "Starting cleanup for asset: $ASSET_ID"
    
    # Step 1: Remove Contract Definition
    log_info "Removing contract definition: $CONTRACT_DEFINITION_ID"
    if ! make_delete_request "$EDC_BASE_URL/management/v3/contractdefinitions/$CONTRACT_DEFINITION_ID" \
                            "contract definition" "$CONTRACT_DEFINITION_ID"; then
        exit_code=3
    fi
    
    # Step 2: Remove Policy
    log_info "Removing policy: $POLICY_ID"
    if ! make_delete_request "$EDC_BASE_URL/management/v3/policydefinitions/$POLICY_ID" \
                            "policy" "$POLICY_ID"; then
        exit_code=3
    fi
    
    # Step 3: Remove Asset
    log_info "Removing asset: $ASSET_ID"
    if ! make_delete_request "$EDC_BASE_URL/management/v3/assets/$ASSET_ID" \
                            "asset" "$ASSET_ID"; then
        exit_code=3
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_success "Dry run completed successfully"
        else
            log_success "Cleanup completed successfully"
        fi
    else
        log_error "Cleanup completed with errors"
    fi
    
    return $exit_code
}

# Main execution
main() {
    parse_args "$@"
    validate_inputs
    
    # Derive resource IDs from asset ID
    CONTRACT_DEFINITION_ID="${ASSET_ID}-contract"
    POLICY_ID="${ASSET_ID}-policy"
    
    log_verbose "Derived Contract Definition ID: $CONTRACT_DEFINITION_ID"
    log_verbose "Derived Policy ID: $POLICY_ID"
    
    confirm_deletion
    cleanup_resources
}

# Execute main function with all arguments
main "$@"