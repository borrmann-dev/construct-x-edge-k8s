#!/bin/bash

# Construct-X Edge Deployment Test Script
# This script tests all deployed services to verify they're working correctly

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
TIMEOUT=30

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

# Function to test HTTP endpoint
test_endpoint() {
    local url=$1
    local expected_status=${2:-200}
    local description=$3
    
    print_info "Testing $description: $url"
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "$url" 2>/dev/null || echo "000")
    
    if [[ "$response" == "$expected_status" ]]; then
        print_success "$description is responding (HTTP $response)"
        return 0
    else
        print_error "$description failed (HTTP $response, expected $expected_status)"
        return 1
    fi
}

# Function to test HTTPS endpoint
test_https_endpoint() {
    local url=$1
    local expected_status=${2:-200}
    local description=$3
    
    print_info "Testing $description (HTTPS): $url"
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT -k "$url" 2>/dev/null || echo "000")
    
    if [[ "$response" == "$expected_status" ]]; then
        print_success "$description HTTPS is responding (HTTP $response)"
        return 0
    else
        print_error "$description HTTPS failed (HTTP $response, expected $expected_status)"
        return 1
    fi
}

# Function to check SSL certificate
check_ssl_cert() {
    local domain=$1
    local description=$2
    
    print_info "Checking SSL certificate for $description: $domain"
    
    local cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")
    
    if [[ -n "$cert_info" ]]; then
        print_success "$description has valid SSL certificate"
        echo "  $cert_info"
        return 0
    else
        print_error "$description SSL certificate check failed"
        return 1
    fi
}

# Function to test Kubernetes resources
test_k8s_resources() {
    print_info "Testing Kubernetes resources..."
    
    # Check if namespace exists
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_success "Namespace '$NAMESPACE' exists"
    else
        print_error "Namespace '$NAMESPACE' not found"
        return 1
    fi
    
    # Check Helm release
    if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        print_success "Helm release '$RELEASE_NAME' is deployed"
    else
        print_error "Helm release '$RELEASE_NAME' not found"
        return 1
    fi
    
    # Check pod status
    local failed_pods=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    local total_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    
    if [[ $failed_pods -eq 0 ]]; then
        print_success "All $total_pods pods are running"
    else
        print_error "$failed_pods out of $total_pods pods are not running"
        kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running
        return 1
    fi
    
    # Check ingresses
    local ingress_count=$(kubectl get ingress -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [[ $ingress_count -gt 0 ]]; then
        print_success "$ingress_count ingresses are configured"
    else
        print_error "No ingresses found"
        return 1
    fi
    
    # Check certificates
    if kubectl get certificates -n "$NAMESPACE" &> /dev/null; then
        local ready_certs=$(kubectl get certificates -n "$NAMESPACE" -o jsonpath='{.items[?(@.status.conditions[0].type=="Ready")].metadata.name}' 2>/dev/null | wc -w)
        local total_certs=$(kubectl get certificates -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
        
        if [[ $ready_certs -eq $total_certs ]] && [[ $total_certs -gt 0 ]]; then
            print_success "All $total_certs SSL certificates are ready"
        else
            print_warning "$ready_certs out of $total_certs SSL certificates are ready"
        fi
    fi
}

# Function to test EDC Control Plane
test_edc_controlplane() {
    local base_url="https://dataprovider-x-controlplane.construct-x.borrmann.dev"
    
    print_info "Testing EDC Control Plane..."
    
    # Test health endpoint
    test_https_endpoint "$base_url/api/check/health" 200 "EDC Control Plane Health"
    
    # Test management API (might require auth)
    test_https_endpoint "$base_url/management/v2/assets" 401 "EDC Management API (expecting 401 without auth)"
    
    # Test DSP protocol endpoint
    test_https_endpoint "$base_url/api/v1/dsp" 404 "EDC DSP Protocol (expecting 404 for root)"
}

# Function to test EDC Data Plane
test_edc_dataplane() {
    local base_url="https://dataprovider-x-dataplane.construct-x.borrmann.dev"
    
    print_info "Testing EDC Data Plane..."
    
    # Test health endpoint
    test_https_endpoint "$base_url/api/check/health" 200 "EDC Data Plane Health"
    
    # Test public API
    test_https_endpoint "$base_url/api/public" 404 "EDC Data Plane Public API (expecting 404 for root)"
}

# Function to test Digital Twin Registry
test_digital_twin_registry() {
    local base_url="https://dataprovider-x-dtr.construct-x.borrmann.dev"
    
    print_info "Testing Digital Twin Registry..."
    
    # Test registry API
    test_https_endpoint "$base_url/semantics/registry" 404 "Digital Twin Registry API (expecting 404 for root)"
    
    # Test specific registry endpoints
    test_https_endpoint "$base_url/semantics/registry/api/v3.0/shell-descriptors" 200 "DTR Shell Descriptors"
}

# Function to test Submodel Server
test_submodel_server() {
    local base_url="https://dataprovider-x-submodelserver.construct-x.borrmann.dev"
    
    print_info "Testing Submodel Server..."
    
    # Test root endpoint
    test_https_endpoint "$base_url/" 200 "Submodel Server Root"
    
    # Test API endpoints
    test_https_endpoint "$base_url/api" 404 "Submodel Server API (expecting 404 for root)"
}

# Function to test SSL certificates
test_ssl_certificates() {
    print_info "Testing SSL certificates..."
    
    check_ssl_cert "dataprovider-x-controlplane.construct-x.borrmann.dev" "EDC Control Plane"
    check_ssl_cert "dataprovider-x-dataplane.construct-x.borrmann.dev" "EDC Data Plane"
    check_ssl_cert "dataprovider-x-dtr.construct-x.borrmann.dev" "Digital Twin Registry"
    check_ssl_cert "dataprovider-x-submodelserver.construct-x.borrmann.dev" "Submodel Server"
}

# Function to test internal services
test_internal_services() {
    print_info "Testing internal services..."
    
    # Test Vault (internal)
    if kubectl exec -n "$NAMESPACE" edc-dataprovider-x-vault-0 -- vault status &> /dev/null; then
        print_success "Vault is accessible and responding"
    else
        print_error "Vault is not responding"
    fi
    
    # Test PostgreSQL (EDC database)
    if kubectl exec -n "$NAMESPACE" eecc-edc-dataprovider-x-db-0 -- pg_isready -U testuser &> /dev/null; then
        print_success "EDC PostgreSQL database is ready"
    else
        print_error "EDC PostgreSQL database is not ready"
    fi
    
    # Test PostgreSQL (DTR database)
    if kubectl exec -n "$NAMESPACE" eecc-edc-dataprovider-x-dtr-db-0 -- pg_isready &> /dev/null; then
        print_success "DTR PostgreSQL database is ready"
    else
        print_error "DTR PostgreSQL database is not ready"
    fi
}

# Function to run comprehensive tests
run_comprehensive_tests() {
    local failed_tests=0
    
    print_info "Starting comprehensive deployment tests..."
    echo
    
    # Test Kubernetes resources
    if ! test_k8s_resources; then
        ((failed_tests++))
    fi
    echo
    
    # Test internal services
    if ! test_internal_services; then
        ((failed_tests++))
    fi
    echo
    
    # Test external endpoints
    if ! test_edc_controlplane; then
        ((failed_tests++))
    fi
    echo
    
    if ! test_edc_dataplane; then
        ((failed_tests++))
    fi
    echo
    
    if ! test_digital_twin_registry; then
        ((failed_tests++))
    fi
    echo
    
    if ! test_submodel_server; then
        ((failed_tests++))
    fi
    echo
    
    # Test SSL certificates
    if ! test_ssl_certificates; then
        ((failed_tests++))
    fi
    echo
    
    # Summary
    if [[ $failed_tests -eq 0 ]]; then
        print_success "🎉 All tests passed! Deployment is working correctly."
        return 0
    else
        print_error "❌ $failed_tests test(s) failed. Please check the issues above."
        return 1
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Test construct-x edge deployment

OPTIONS:
    -n, --namespace NAMESPACE    Kubernetes namespace (default: edc)
    -r, --release RELEASE_NAME   Helm release name (default: eecc-edc)
    -t, --timeout TIMEOUT        HTTP timeout in seconds (default: 30)
    --k8s-only                   Test only Kubernetes resources
    --endpoints-only             Test only HTTP endpoints
    --ssl-only                   Test only SSL certificates
    -h, --help                   Show this help message

EXAMPLES:
    $0                          # Run all tests
    $0 --k8s-only              # Test only Kubernetes resources
    $0 --endpoints-only        # Test only HTTP endpoints
    $0 -t 60                   # Use 60 second timeout

EOF
}

# Parse command line arguments
TEST_TYPE="all"

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
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --k8s-only)
            TEST_TYPE="k8s"
            shift
            ;;
        --endpoints-only)
            TEST_TYPE="endpoints"
            shift
            ;;
        --ssl-only)
            TEST_TYPE="ssl"
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

# Main execution
echo "========================================="
echo "  Construct-X Edge Deployment Tester"
echo "========================================="
echo

case $TEST_TYPE in
    "k8s")
        test_k8s_resources
        ;;
    "endpoints")
        test_edc_controlplane
        echo
        test_edc_dataplane
        echo
        test_digital_twin_registry
        echo
        test_submodel_server
        ;;
    "ssl")
        test_ssl_certificates
        ;;
    "all")
        run_comprehensive_tests
        ;;
esac
