#!/bin/bash

# Construct-X Eclipse Dataspace Connector - Complete DSP Workflow Script
# This script automates the full dataspace protocol workflow from provider setup to consumer data access

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
ENV_FILE="${SCRIPT_DIR}/.env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}Error: .env file not found. Please copy env.example to .env and configure it.${NC}"
    exit 1
fi

# Source environment variables
set -a
source "$ENV_FILE"
set +a

# Validate required environment variables
required_vars=(
    "ASSET_ID"
    "PROVIDER_URL" 
    "PROVIDER_BPN"
    "PROVIDER_API_KEY"
    "CONSUMER_URL"
    "CONSUMER_BPN" 
    "CONSUMER_API_KEY"
)

for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo -e "${RED}Error: Required environment variable $var is not set${NC}"
        exit 1
    fi
done

# Set defaults
DATA_SOURCE_URL="https://jsonplaceholder.typicode.com/todos"
DEBUG="${DEBUG:-false}"
POLICY_ID="${ASSET_ID}-policy"
CONTRACT_DEFINITION_ID="${ASSET_ID}-contract"

# Global variables for dynamic values
OFFER_ID=""
CONTRACT_PERMISSIONS=""
CONTRACT_PROHIBITIONS=""
CONTRACT_OBLIGATIONS=""
NEGOTIATION_ID=""
CONTRACT_AGREEMENT_ID=""
EDR_NEGOTIATION_ID=""
TRANSFER_PROCESS_ID=""
AUTH_CODE=""
DATAPLANE_PUBLIC_ENDPOINT=""

echo -e "${BLUE}=== Construct-X DSP Workflow Script ===${NC}"
echo "Asset ID: $ASSET_ID"
echo "Provider: $PROVIDER_URL"
echo "Consumer: $CONSUMER_URL"
echo "Data Source: $DATA_SOURCE_URL"
echo ""

# Utility functions
log_step() {
    echo -e "${BLUE}[STEP] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${YELLOW}[DEBUG] $1${NC}" >&2
    fi
}

show_payload() {
    local title="$1"
    local data="$2"
    
    echo -e "${BLUE}  → $title:${NC}"
    echo "$data" | jq . 2>/dev/null || echo "$data"
    echo ""
}

# API call wrapper with error handling
api_call() {
    local method="$1"
    local url="$2"
    local headers="$3"
    local data="$4"
    local description="$5"
    
    echo "  → $description" >&2
    
    # Show request payload for non-GET requests
    if [[ "$method" != "GET" && -n "$data" ]]; then
        show_payload "Request payload" "$data" >&2
    fi
    
    local response
    local http_code
    
    if [[ "$method" == "GET" ]]; then
        response=$(eval "curl -s -w \"\\n%{http_code}\" $headers \"$url\"")
    else
        # Write data to temporary file to avoid shell interpretation issues
        local temp_file=$(mktemp)
        echo "$data" > "$temp_file"
        response=$(eval "curl -s -w \"\\n%{http_code}\" -X \"$method\" $headers -d @\"$temp_file\" \"$url\"")
        rm "$temp_file"
    fi
    
    http_code=$(echo "$response" | tail -n1)
    response=$(echo "$response" | head -n -1)
    
    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        echo "    ✓ HTTP $http_code" >&2
        
        # Show successful response payload nicely formatted
        if [[ -n "$response" ]]; then
            show_payload "Response" "$response" >&2
        fi
        
        echo "$response"
    else
        log_error "HTTP $http_code - $description failed"
        log_debug "Error response: $response"
        echo "$response" >&2
        return 1
    fi
}

# Check if resource exists
resource_exists() {
    local url="$1"
    local headers="$2"
    local resource_id="$3"
    local description="$4"
    
    echo "  → Checking if $description exists"
    
    local response
    local http_code
    
    response=$(eval "curl -s -w \"\\n%{http_code}\" $headers \"$url\"")
    http_code=$(echo "$response" | tail -n1)
    response=$(echo "$response" | head -n -1)
    
    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        # Check if resource_id exists in response
        if echo "$response" | jq -e ".[] | select(.\"@id\" == \"$resource_id\")" > /dev/null 2>&1; then
            echo "    ✓ $description already exists"
            return 0
        else
            echo "    ✗ $description does not exist"
            return 1
        fi
    else
        echo "    ✗ Failed to check $description (HTTP $http_code)"
        return 1
    fi
}

# Wait for resource to be available
wait_for_resource() {
    local check_function="$1"
    local max_attempts="${2:-30}"
    local sleep_interval="${3:-2}"
    local description="$4"
    
    echo "  → Waiting for $description (max ${max_attempts}s)"
    
    for ((i=1; i<=max_attempts; i++)); do
        if $check_function; then
            echo "    ✓ $description is ready"
            return 0
        fi
        
        if [[ $i -lt $max_attempts ]]; then
            echo "    ⏳ Attempt $i/$max_attempts - waiting ${sleep_interval}s..."
            sleep $sleep_interval
        fi
    done
    
    log_error "$description not ready after ${max_attempts} attempts"
    return 1
}

# Provider functions
create_policy() {
    log_step "Creating Policy Definition"
    
    # Check if policy already exists
    echo "  → Checking if policy $POLICY_ID exists"
    local check_response
    local check_http_code
    
    check_response=$(curl -s -w "\n%{http_code}" \
        -H "X-Api-Key: $PROVIDER_API_KEY" \
        "$PROVIDER_URL/management/v3/policydefinitions/$POLICY_ID")
    check_http_code=$(echo "$check_response" | tail -n1)
    
    if [[ "$check_http_code" == "200" ]]; then
        echo "    ✓ Policy $POLICY_ID already exists, skipping creation"
        log_success "Policy $POLICY_ID already exists, skipping creation"
        return 0
    elif [[ "$check_http_code" == "404" ]]; then
        echo "    ✗ Policy $POLICY_ID does not exist, will create"
    else
        echo "    ⚠ Failed to check policy $POLICY_ID (HTTP $check_http_code), will attempt creation"
    fi
    
    local policy_data=$(jq -n \
        --arg policyId "$POLICY_ID" \
        --arg consumerBpn "$CONSUMER_BPN" \
        '{
            "@context": [
                "https://w3id.org/tractusx/edc/v0.0.1",
                "http://www.w3.org/ns/odrl.jsonld",
                {
                    "edc": "https://w3id.org/edc/v0.0.1/ns/",
                    "cx-policy": "https://w3id.org/catenax/policy/"
                }
            ],
            "@type": "PolicyDefinition",
            "@id": $policyId,
            "edc:policy": {
                "@type": "Set",
                "profile": "cx-policy:profile2405",
                "permission": [
                    {
                        "action": "use",
                        "constraint": {
                            "and": [
                                {
                                    "odrl:leftOperand": {
                                        "@id": "BusinessPartnerNumber"
                                    },
                                    "odrl:operator": {
                                        "@id": "odrl:eq"
                                    },
                                    "odrl:rightOperand": $consumerBpn
                                }
                            ]
                        }
                    }
                ]
            }
        }')
    
    
    api_call "POST" \
        "$PROVIDER_URL/management/v3/policydefinitions" \
        "-H 'X-Api-Key: $PROVIDER_API_KEY' -H 'Content-Type: application/json'" \
        "$policy_data" \
        "Creating policy definition"
    
    log_success "Policy $POLICY_ID created successfully"
}

create_asset() {
    log_step "Creating Asset"
    
    # Check if asset already exists
    echo "  → Checking if asset $ASSET_ID exists"
    local check_response
    local check_http_code
    
    check_response=$(curl -s -w "\n%{http_code}" \
        -H "X-Api-Key: $PROVIDER_API_KEY" \
        "$PROVIDER_URL/management/v3/assets/$ASSET_ID")
    check_http_code=$(echo "$check_response" | tail -n1)
    
    if [[ "$check_http_code" == "200" ]]; then
        echo "    ✓ Asset $ASSET_ID already exists, skipping creation"
        log_success "Asset $ASSET_ID already exists, skipping creation"
        return 0
    elif [[ "$check_http_code" == "404" ]]; then
        echo "    ✗ Asset $ASSET_ID does not exist, will create"
    else
        echo "    ⚠ Failed to check asset $ASSET_ID (HTTP $check_http_code), will attempt creation"
    fi
    
    local asset_data=$(jq -n \
        --arg assetId "$ASSET_ID" \
        --arg dataSourceUrl "$DATA_SOURCE_URL" \
        '{
            "@id": $assetId,
            "@type": "Asset",
            "properties": {
                "dct:type": {
                    "@id": "asset.prop.type"
                },
                "id": $assetId
            },
            "dataAddress": {
                "@type": "DataAddress",
                "proxyPath": "true",
                "type": "HttpData",
                "proxyMethod": "true",
                "proxyQueryParams": "true",
                "proxyBody": "true",
                "baseUrl": $dataSourceUrl
            },
            "@context": {
                "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
                "cx-common": "https://w3id.org/catenax/ontology/common#",
                "cx-taxo": "https://w3id.org/catenax/taxonomy#",
                "dct": "http://purl.org/dc/terms/"
            }
        }')
    
    
    api_call "POST" \
        "$PROVIDER_URL/management/v3/assets" \
        "-H 'X-Api-Key: $PROVIDER_API_KEY' -H 'Content-Type: application/json'" \
        "$asset_data" \
        "Creating asset"
    
    log_success "Asset $ASSET_ID created successfully"
}

create_contract_definition() {
    log_step "Creating Contract Definition"
    
    # Check if contract definition already exists
    echo "  → Checking if contract definition $CONTRACT_DEFINITION_ID exists"
    local check_response
    local check_http_code
    
    check_response=$(curl -s -w "\n%{http_code}" \
        -H "X-Api-Key: $PROVIDER_API_KEY" \
        "$PROVIDER_URL/management/v3/contractdefinitions/$CONTRACT_DEFINITION_ID")
    check_http_code=$(echo "$check_response" | tail -n1)
    
    if [[ "$check_http_code" == "200" ]]; then
        echo "    ✓ Contract definition $CONTRACT_DEFINITION_ID already exists, skipping creation"
        log_success "Contract definition $CONTRACT_DEFINITION_ID already exists, skipping creation"
        return 0
    elif [[ "$check_http_code" == "404" ]]; then
        echo "    ✗ Contract definition $CONTRACT_DEFINITION_ID does not exist, will create"
    else
        echo "    ⚠ Failed to check contract definition $CONTRACT_DEFINITION_ID (HTTP $check_http_code), will attempt creation"
    fi
    
    local contract_data=$(jq -n \
        --arg contractId "$CONTRACT_DEFINITION_ID" \
        --arg policyId "$POLICY_ID" \
        --arg assetId "$ASSET_ID" \
        '{
            "@context": {},
            "@id": $contractId,
            "@type": "ContractDefinition",
            "accessPolicyId": $policyId,
            "contractPolicyId": $policyId,
            "assetsSelector": {
                "@type": "CriterionDto",
                "operandLeft": "https://w3id.org/edc/v0.0.1/ns/id",
                "operator": "=",
                "operandRight": $assetId
            }
        }')
    
    api_call "POST" \
        "$PROVIDER_URL/management/v3/contractdefinitions" \
        "-H 'X-Api-Key: $PROVIDER_API_KEY' -H 'Content-Type: application/json'" \
        "$contract_data" \
        "Creating contract definition"
    
    log_success "Contract definition $CONTRACT_DEFINITION_ID created successfully"
}

# Consumer functions
request_catalog() {
    log_step "Requesting Catalog from Provider"
    
    local catalog_request=$(jq -n \
        --arg providerBpn "$PROVIDER_BPN" \
        --arg providerUrl "$PROVIDER_URL" \
        '{
            "@context": {
                "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
                "odrl": "http://www.w3.org/ns/odrl/2/",
                "dct": "http://purl.org/dc/terms/"
            },
            "@type": "CatalogRequest",
            "counterPartyId": $providerBpn,
            "counterPartyAddress": "\($providerUrl)/api/v1/dsp",
            "protocol": "dataspace-protocol-http"
        }')
    
    local response
    response=$(api_call "POST" \
        "$CONSUMER_URL/management/v3/catalog/request" \
        "-H 'X-Api-Key: $CONSUMER_API_KEY' -H 'Content-Type: application/json'" \
        "$catalog_request" \
        "Requesting catalog")
    
    # Parse catalog response to extract offer details
    echo "  → Parsing catalog response"
    echo "  → DEBUG: Response length: ${#response}"
    echo "  → DEBUG: First 100 chars: ${response:0:100}"
    echo "  → DEBUG: Response type: $(echo "$response" | file -)"
    
    # Handle both object and array formats for dcat:dataset
    local datasets
    datasets=$(echo "$response" | jq -r '.["dcat:dataset"]')
    
    # Normalize to array
    if echo "$datasets" | jq -e 'type == "array"' > /dev/null 2>&1; then
        datasets=$(echo "$datasets" | jq '.')
    else
        datasets=$(echo "$datasets" | jq '[.]')
    fi
    
    # Find our asset
    local dataset
    dataset=$(echo "$datasets" | jq -r ".[] | select(.id == \"$ASSET_ID\" or .[\"@id\"] == \"$ASSET_ID\")")
    
    if [[ -z "$dataset" || "$dataset" == "null" ]]; then
        log_error "Asset $ASSET_ID not found in catalog"
        return 1
    fi
    
    # Extract policy information
    local policies
    policies=$(echo "$dataset" | jq -r '.["odrl:hasPolicy"] // []')
    
    # Normalize policies to array
    if echo "$policies" | jq -e 'type == "array"' > /dev/null 2>&1; then
        policies=$(echo "$policies" | jq '.')
    else
        policies=$(echo "$policies" | jq '[.]')
    fi
    
    # Get first policy
    local policy
    policy=$(echo "$policies" | jq -r '.[0] // {}')
    
    OFFER_ID=$(echo "$policy" | jq -r '.["@id"] // ""')
    CONTRACT_PERMISSIONS=$(echo "$policy" | jq -c '.["odrl:permission"] // []')
    CONTRACT_PROHIBITIONS=$(echo "$policy" | jq -c '.["odrl:prohibition"] // []')
    CONTRACT_OBLIGATIONS=$(echo "$policy" | jq -c '.["odrl:obligation"] // []')
    
    echo "    ✓ Offer ID: $OFFER_ID"
    echo "    ✓ Permissions: $CONTRACT_PERMISSIONS"
    echo "    ✓ Prohibitions: $CONTRACT_PROHIBITIONS"
    echo "    ✓ Obligations: $CONTRACT_OBLIGATIONS"
    
    if [[ -z "$OFFER_ID" ]]; then
        log_error "No offer ID found in catalog response"
        return 1
    fi
    
    log_success "Catalog processed successfully"
}

init_edr() {
    log_step "Initiating EDR (Endpoint Data Reference)"
    
    local edr_request=$(jq -n \
        --arg providerUrl "$PROVIDER_URL" \
        --arg offerId "$OFFER_ID" \
        --arg providerBpn "$PROVIDER_BPN" \
        --arg assetId "$ASSET_ID" \
        --argjson permissions "$CONTRACT_PERMISSIONS" \
        --argjson prohibitions "$CONTRACT_PROHIBITIONS" \
        --argjson obligations "$CONTRACT_OBLIGATIONS" \
        '{
            "@context": [
                "https://w3id.org/tractusx/policy/v1.0.0",
                "http://www.w3.org/ns/odrl.jsonld",
                {
                    "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
                }
            ],
            "@type": "ContractRequest",
            "counterPartyAddress": "\($providerUrl)/api/v1/dsp",
            "protocol": "dataspace-protocol-http",
            "policy": {
                "@id": $offerId,
                "@type": "odrl:Offer",
                "assigner": $providerBpn,
                "target": $assetId,
                "odrl:permission": $permissions,
                "odrl:prohibition": $prohibitions,
                "odrl:obligation": $obligations
            },
            "callbackAddresses": []
        }')
    
    local response
    response=$(api_call "POST" \
        "$CONSUMER_URL/management/v3/edrs" \
        "-H 'X-Api-Key: $CONSUMER_API_KEY' -H 'Content-Type: application/json'" \
        "$edr_request" \
        "Initiating EDR negotiation")
    
    EDR_NEGOTIATION_ID=$(echo "$response" | jq -r '.["@id"]')
    
    echo "    ✓ EDR Negotiation ID: $EDR_NEGOTIATION_ID"
    
    if [[ -z "$EDR_NEGOTIATION_ID" || "$EDR_NEGOTIATION_ID" == "null" ]]; then
        log_error "No EDR negotiation ID received"
        return 1
    fi
    
    log_success "EDR negotiation initiated successfully"
}

check_edr_status() {
    local query_data=$(jq -n \
        --arg negotiationId "$EDR_NEGOTIATION_ID" \
        '{
            "@context": {
                "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
            },
            "@type": "QuerySpec",
            "filterExpression": [
                {
                    "operandLeft": "contractNegotiationId",
                    "operator": "=",
                    "operandRight": $negotiationId
                }
            ]
        }')
    
    local temp_file=$(mktemp)
    echo "$query_data" > "$temp_file"
    
    local response
    response=$(curl -s -X POST \
        -H "X-Api-Key: $CONSUMER_API_KEY" \
        -H "Content-Type: application/json" \
        -d @"$temp_file" \
        "$CONSUMER_URL/management/v3/edrs/request")
    rm "$temp_file"
    
    log_debug "EDR query response: $response"
    
    # Check if we got any EDR entries
    local edr_count
    edr_count=$(echo "$response" | jq '. | length' 2>/dev/null || echo "0")
    
    if [[ "$edr_count" -gt 0 ]]; then
        echo "    EDR found: $edr_count entries" >&2
        return 0
    else
        echo "    EDR not ready yet" >&2
        return 1
    fi
}

query_cached_edr() {
    log_step "Waiting for EDR to be cached"
    
    wait_for_resource "check_edr_status" 60 3 "EDR negotiation to complete"
    
    log_step "Retrieving EDR Details"
    
    # Use the same query as check_edr_status to get the EDR details
    local query_data=$(jq -n \
        --arg negotiationId "$EDR_NEGOTIATION_ID" \
        '{
            "@context": {
                "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
            },
            "@type": "QuerySpec",
            "filterExpression": [
                {
                    "operandLeft": "contractNegotiationId",
                    "operator": "=",
                    "operandRight": $negotiationId
                }
            ]
        }')
    
    local response
    response=$(api_call "POST" \
        "$CONSUMER_URL/management/v3/edrs/request" \
        "-H 'X-Api-Key: $CONSUMER_API_KEY' -H 'Content-Type: application/json'" \
        "$query_data" \
        "Retrieving EDR details")
    
    # Extract transferProcessId from the first EDR entry
    TRANSFER_PROCESS_ID=$(echo "$response" | jq -r '.[0].transferProcessId // ""')
    
    echo "    ✓ Transfer Process ID: $TRANSFER_PROCESS_ID"
    
    if [[ -z "$TRANSFER_PROCESS_ID" || "$TRANSFER_PROCESS_ID" == "null" ]]; then
        log_error "No transfer process ID found in EDR response"
        return 1
    fi
    
    log_success "EDR details retrieved successfully"
}

get_auth_code() {
    log_step "Getting Authorization Code"
    
    local response
    response=$(api_call "GET" \
        "$CONSUMER_URL/management/v3/edrs/$TRANSFER_PROCESS_ID/dataaddress" \
        "-H 'X-Api-Key: $CONSUMER_API_KEY'" \
        "" \
        "Getting EDR data address")
    
    AUTH_CODE=$(echo "$response" | jq -r '.authorization // ""')
    DATAPLANE_PUBLIC_ENDPOINT=$(echo "$response" | jq -r '.endpoint // ""')
    
    echo "    ✓ Authorization Code: ${AUTH_CODE:0:20}..."
    echo "    ✓ Dataplane Endpoint: $DATAPLANE_PUBLIC_ENDPOINT"
    
    if [[ -z "$AUTH_CODE" || "$AUTH_CODE" == "null" ]]; then
        log_error "No authorization code received"
        return 1
    fi
    
    if [[ -z "$DATAPLANE_PUBLIC_ENDPOINT" || "$DATAPLANE_PUBLIC_ENDPOINT" == "null" ]]; then
        log_error "No dataplane endpoint received"
        return 1
    fi
    
    log_success "Authorization code obtained successfully"
}

get_data() {
    log_step "Accessing Data via Dataplane"
    
    local response
    response=$(api_call "GET" \
        "$DATAPLANE_PUBLIC_ENDPOINT" \
        "-H 'Authorization: $AUTH_CODE'" \
        "" \
        "Fetching data from dataplane")
    
    echo ""
    echo -e "${GREEN}=== DATA SUCCESSFULLY RETRIEVED ===${NC}"
    echo -e "${BLUE}Data from $DATA_SOURCE_URL:${NC}"
    echo ""
    
    # Pretty print JSON if possible, otherwise show raw data
    if echo "$response" | jq . > /dev/null 2>&1; then
        echo "$response" | jq .
    else
        echo "$response"
    fi
    
    echo ""
    log_success "DSP Workflow completed successfully!"
}

# Health check function
health_check() {
    log_step "Performing Health Checks"
    
    echo "  → Checking Provider health"
    if curl -s -f "$PROVIDER_URL/api/check/liveness" > /dev/null; then
        echo "    ✓ Provider is healthy"
    else
        log_error "Provider health check failed"
        return 1
    fi
    
    echo "  → Checking Consumer health"
    if curl -s -f "$CONSUMER_URL/api/check/liveness" > /dev/null; then
        echo "    ✓ Consumer is healthy"
    else
        log_error "Consumer health check failed"
        return 1
    fi
    
    log_success "Health checks passed"
}

# Main workflow
main() {
    echo -e "${BLUE}Starting Complete DSP Workflow...${NC}"
    echo ""
    
    # Health checks
    health_check
    echo ""
    
    # Provider setup
    echo -e "${BLUE}=== PROVIDER SETUP ===${NC}"
    create_asset
    create_policy
    create_contract_definition
    echo ""
    
    # Consumer workflow
    echo -e "${BLUE}=== CONSUMER WORKFLOW ===${NC}"
    request_catalog
    init_edr
    query_cached_edr
    get_auth_code
    get_data
    
    echo ""
    echo -e "${GREEN}🎉 DSP Workflow completed successfully! 🎉${NC}"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
