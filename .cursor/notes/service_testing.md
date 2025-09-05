# Service Testing and Health Checks

## Overview
Comprehensive testing and validation procedures for the construct-x EDC deployment, including service reachability, SSL certificate validation, and Kubernetes resource health checks.

## Testing Approaches

### Manual Testing Commands

#### External HTTPS Endpoints
```bash
# Test EDC Controlplane
curl -k https://dataprovider-x-controlplane.construct-x.borrmann.dev/api/v1/dsp

# Test EDC Dataplane
curl -k https://dataprovider-x-dataplane.construct-x.borrmann.dev/api/public

# Test Digital Twin Registry
curl -k https://dataprovider-x-dtr.construct-x.borrmann.dev/semantics/registry

# Test Submodel Server
curl -k https://dataprovider-x-submodelserver.construct-x.borrmann.dev
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
   curl -k https://dataprovider-x-controlplane.construct-x.borrmann.dev/api/v1/dsp
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

## Prerequisites
- **kubectl** - Kubernetes CLI tool configured for cluster access
- **curl** - HTTP client for endpoint testing
- **openssl** - SSL certificate inspection and validation
- **jq** - JSON parsing (for upgrade script integration)
