# Service Testing and Health Checks

## Overview
Comprehensive testing and validation procedures for the construct-x EDC deployment, including service reachability, SSL certificate validation, and Kubernetes resource health checks.

## Testing Approaches

### Manual Testing Commands

#### External HTTPS Endpoints
```bash
# Test EDC Controlplane (Provider)
curl -k https://dataprovider-x-controlplane.construct-x.prod-k8s.eecc.de/api/v1/dsp

# Test EDC Controlplane (Consumer)  
curl -k https://dataprovider-x-controlplane.construct-x.borrmann.dev/api/v1/dsp

# Test EDC Health Check
curl -k https://dataprovider-x-controlplane.construct-x.borrmann.dev/api/check/liveness

# Test Management API (with API Key)
curl -k -H "X-Api-Key: TEST2" https://dataprovider-x-controlplane.construct-x.prod-k8s.eecc.de/management/v3/assets
```

#### Internal Service Testing
```bash
# Port-forward to test internal services
kubectl port-forward -n edc svc/eecc-edc-tractusx-connector-controlplane 8080:8080
curl http://localhost:8080/api/v1/dsp

kubectl port-forward -n edc svc/eecc-edc-digital-twin-registry 8081:8080
curl http://localhost:8081/api/v3

kubectl port-forward -n edc svc/eecc-edc-simple-data-backend 8082:8080
curl http://localhost:8082

kubectl port-forward -n edc svc/eecc-edc-edc-dataprovider-x-vault 8200:8200
curl http://localhost:8200/v1/sys/health
```

## Kubernetes Resource Validation

### Certificate and Ingress Checks
```bash
# Check certificate status
kubectl get certificates -n edc

# Check ingress resources
kubectl get ingress -n edc

# Check ClusterIssuer
kubectl get clusterissuers

# Describe certificate for detailed status
kubectl describe certificate <cert-name> -n edc
```

### Service and Pod Health
```bash
# Check all pods in EDC namespace
kubectl get pods -n edc

# Check services
kubectl get svc -n edc

# Check deployment status
kubectl get deployments -n edc

# View pod logs for troubleshooting
kubectl logs -n edc <pod-name>
```

## SSL Certificate Validation

### Certificate Inspection
```bash
# Check certificate details for external endpoints
echo | openssl s_client -servername dataprovider-x-controlplane.construct-x.borrmann.dev -connect dataprovider-x-controlplane.construct-x.borrmann.dev:443 2>/dev/null | openssl x509 -noout -text

# Check certificate expiration
echo | openssl s_client -servername dataprovider-x-controlplane.construct-x.borrmann.dev -connect dataprovider-x-controlplane.construct-x.borrmann.dev:443 2>/dev/null | openssl x509 -noout -dates
```

### Certificate Validation Checklist
- ✅ **Let's Encrypt certificates**: Proper ACME certificate issuance
- ⚠️ **Self-signed certificates**: Indicates configuration issues
- 📅 **Certificate expiration**: Monitor renewal status
- 🔗 **Certificate chain**: Verify complete SSL/TLS setup

## Health Check Integration

### Post-Installation Validation
After running `./edc/install.sh`, verify:

1. **All pods are running**:
   ```bash
   kubectl get pods -n edc
   ```

2. **Certificates are issued**:
   ```bash
   kubectl get certificates -n edc
   ```

3. **External endpoints respond**:
   ```bash
   # Test DSP endpoint
   curl -k https://dataprovider-x-controlplane.construct-x.prod-k8s.eecc.de/api/v1/dsp
   
   # Test Health Check
   curl -k https://dataprovider-x-controlplane.construct-x.prod-k8s.eecc.de/api/check/liveness
   ```

### Post-Upgrade Validation
After running `./edc/upgrade.sh`, verify:

1. **All services are healthy**
2. **No certificate issues**
3. **Endpoints still respond correctly**
4. **No pod restart loops**

## Troubleshooting Common Issues

### Certificate Problems
- **Pending certificates**: Check DNS resolution and ingress controller
- **Failed challenges**: Verify domain accessibility and firewall rules
- **Expired certificates**: Check cert-manager logs and renewal process

### Service Connectivity
- **503 errors**: Check if backend pods are running
- **Connection refused**: Verify service and ingress configuration
- **SSL errors**: Check certificate status and ingress TLS configuration

### Pod Issues
- **CrashLoopBackOff**: Check pod logs and resource limits
- **ImagePullBackOff**: Verify image availability and registry access
- **Pending**: Check node resources and scheduling constraints

## Bruno Collection Integration

### Automated API Testing
The `bruno/tx-umbrella/` collection provides comprehensive API testing capabilities:

- **Health Checks**: `EDC HealthCheck.bru` for liveness testing
- **Provider Setup**: Complete workflow for Asset, Policy, and Contract creation
- **Consumer Workflow**: Catalog discovery, EDR negotiation, and data access
- **Authentication**: Central IDP and SSI DIM Wallet integration testing

### Running Bruno Tests
```bash
# Install Bruno CLI (if not already installed)
npm install -g @usebruno/cli

# Run specific test collections
bru run bruno/tx-umbrella/Provider/EDC/Assets/
bru run bruno/tx-umbrella/Consumer/
bru run bruno/tx-umbrella/EDC\ HealthCheck.bru
```

### Integration with CI/CD
The Bruno collection can be integrated into automated testing pipelines for:
- Post-deployment validation
- Regression testing after upgrades
- Continuous API health monitoring

## Common Issues and Solutions

### DSP Workflow Script Issues

#### HTTP 415 "Unsupported Media Type" Error
**Problem**: When running `dsp-workflow.sh`, policy creation fails with HTTP 415 error.

**Root Cause**: The curl command in the `api_call` function wasn't properly handling header strings containing single quotes, causing the Content-Type header to be malformed.

**Solution**: Fixed the `api_call` and `resource_exists` functions to use `eval` for proper header expansion:
```bash
# Before (broken):
response=$(curl -s -w "\n%{http_code}" -X "$method" $headers -d "$data" "$url")

# After (fixed):
response=$(eval "curl -s -w \"\\n%{http_code}\" -X \"$method\" $headers -d \"$data\" \"$url\"")
```

#### HTTP 400 JSON Parsing Error
**Problem**: After fixing HTTP 415, getting HTTP 400 with "Unexpected character ('@' (code 64)): was expecting double-quote to start field name".

**Root Cause**: JSON variable substitution using heredoc or inline strings was causing issues with special characters, empty variables, or shell expansion problems.

**Solution**: Replaced all JSON generation with `jq` for proper JSON construction and variable handling:
```bash
# Before (problematic):
local policy_data=$(cat <<EOF
{
    "@id": "$POLICY_ID",
    "field": "$VARIABLE"
}
EOF
)

# After (robust):
local policy_data=$(jq -n \
    --arg policyId "$POLICY_ID" \
    --arg variable "$VARIABLE" \
    '{
        "@id": $policyId,
        "field": $variable
    }')
```

**Benefits**: 
- Proper JSON escaping and validation
- Handles empty/null variables gracefully
- Prevents JSON injection issues
- Ensures valid JSON structure

**Applied to all functions**: `create_asset()`, `create_policy()`, `create_contract_definition()`, `request_catalog()`, `init_edr()`

**Additional Simplification**: Removed `DATA_SOURCE_URL` as an environment variable dependency. The asset creation now uses the hardcoded URL `"https://jsonplaceholder.typicode.com/todos"` matching the Bruno collection, eliminating unnecessary configuration complexity.

#### Shell Interpretation of JSON with @ Characters
**Problem**: Even with correct JSON structure, getting HTTP 400 errors due to shell interpretation of `@` characters in JSON-LD context.

**Root Cause**: Using `eval` with `-d "$data"` caused the shell to interpret `@` characters in JSON fields like `"@id"`, `"@type"`, `"@context"` before passing to curl.

**Solution**: Use temporary file approach to avoid shell interpretation:
```bash
# Before (shell interprets @):
response=$(eval "curl -X POST $headers -d \"$data\" \"$url\"")

# After (no shell interpretation):
local temp_file=$(mktemp)
echo "$data" > "$temp_file"
response=$(eval "curl -X POST $headers -d @\"$temp_file\" \"$url\"")
rm "$temp_file"
```

**Result**: ✅ Provider setup now works completely - Asset, Policy, and Contract Definition creation all successful with HTTP 200 responses.

#### EDR Status Checking Issues
**Problem**: HTTP 405 errors when checking EDR status using GET requests to individual EDR endpoints.

**Root Cause**: The script was using `GET /management/v3/edrs/{id}` which doesn't exist. The correct approach is to query EDRs using a POST request with QuerySpec.

**Solution**: Updated EDR status checking to match Bruno collection:
```bash
# Before (broken):
GET /management/v3/edrs/{negotiationId}

# After (working):
POST /management/v3/edrs/request
{
  "@type": "QuerySpec",
  "filterExpression": [
    {
      "operandLeft": "contractNegotiationId",
      "operator": "=", 
      "operandRight": "{negotiationId}"
    }
  ]
}
```

**Additional Fix**: Authorization code retrieval uses `transferProcessId` (not negotiation ID):
```bash
GET /management/v3/edrs/{transferProcessId}/dataaddress
```

**Result**: ✅ Complete DSP workflow now works end-to-end - from provider setup through consumer data access.

#### HTTP 405 "Method Not Allowed" Error on Resource Checks
**Problem**: When checking if policies, assets, or contract definitions exist, getting HTTP 405 errors.

**Root Cause**: The script was using GET requests to list endpoints (e.g., `/management/v3/policydefinitions`) instead of specific resource endpoints.

**Solution**: Changed resource existence checks to use specific resource ID endpoints:
```bash
# Before (broken):
GET /management/v3/policydefinitions  # Returns HTTP 405

# After (fixed):
GET /management/v3/policydefinitions/$POLICY_ID  # Returns 200 (exists) or 404 (not found)
```

Applied the same fix to assets and contract definitions endpoints.

#### Missing .env File
**Problem**: Script fails with "Error: .env file not found" message.

**Solution**: Create the .env file from the template:
```bash
cd scripts/
cp ../bruno/env.example .env
```

## Prerequisites
- **kubectl** - Kubernetes CLI tool configured for cluster access
- **curl** - HTTP client for endpoint testing
- **openssl** - SSL certificate inspection and validation
- **jq** - JSON parsing (for upgrade script integration)
- **Bruno CLI** - For automated API testing (optional)
