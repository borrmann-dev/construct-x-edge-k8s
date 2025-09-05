# Service Testing and Health Checks

## Test Script: test-services.sh

A comprehensive script to test all construct-x services for reachability and SSL certificate validity.

### Features
- **External Service Testing**: Tests all public HTTPS endpoints
- **Internal Service Testing**: Tests cluster-internal HTTP services (with `--internal` flag)
- **SSL Certificate Validation**: Checks certificate issuer, expiration, and Let's Encrypt status
- **Kubernetes Resource Checks**: Verifies ingresses, certificates, and ClusterIssuer
- **Detailed Reporting**: Color-coded output with success/failure summary

### Usage Examples
```bash
# Test external services only
./test-services.sh

# Test with verbose output
./test-services.sh --verbose

# Test both external and internal services
./test-services.sh --internal

# Use custom timeout
./test-services.sh --timeout 30
```

### Tested Services

#### External HTTPS Services
- **Digital Twin Registry**: `https://dataprovider-x-dtr.construct-x.borrmann.dev/semantics/registry`
- **Simple Data Backend**: `https://dataprovider-x-submodelserver.construct-x.borrmann.dev`
- **EDC Controlplane Protocol**: `https://dataprovider-x-controlplane.construct-x.borrmann.dev/api/v1/dsp`
- **EDC Controlplane Management**: `https://dataprovider-x-controlplane.construct-x.borrmann.dev/management`
- **EDC Dataplane Public**: `https://dataprovider-x-dataplane.construct-x.borrmann.dev/api/public`

#### Internal HTTP Services (with --internal flag)
- **EDC Controlplane Internal**: `http://eecc-edc-tractusx-connector-controlplane.edc.svc.cluster.local:8080`
- **EDC Dataplane Internal**: `http://eecc-edc-tractusx-connector-dataplane.edc.svc.cluster.local:8080`
- **Digital Twin Registry Internal**: `http://eecc-edc-digital-twin-registry.edc.svc.cluster.local:8080`
- **Simple Data Backend Internal**: `http://eecc-edc-simple-data-backend.edc.svc.cluster.local:8080`
- **Vault Internal**: `http://eecc-edc-edc-provider-vault.edc.svc.cluster.local:8200`

### Certificate Validation
The script specifically checks for:
- **Let's Encrypt certificates**: Indicates proper ACME certificate issuance
- **Fake certificates**: Warns when ingress controller is using self-signed certificates
- **Certificate expiration**: Shows when certificates will expire
- **Certificate chain validation**: Verifies SSL/TLS setup

### Prerequisites
- `kubectl` - Kubernetes CLI tool
- `curl` - HTTP client for testing endpoints
- `openssl` - SSL certificate inspection
- Access to the Kubernetes cluster

### Integration with Install Script
The test script complements the updated `install.sh` which now:
1. Installs cert-manager
2. Creates ClusterIssuer for Let's Encrypt
3. Installs ingress-nginx separately
4. Installs EDC chart with proper TLS configuration

This multi-step approach avoids the Helm secret size limit while ensuring proper certificate management.
