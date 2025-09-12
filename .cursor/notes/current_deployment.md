# Current Deployment Configuration

## Deployment Overview
- **Release Name**: `eecc-edc`
- **Namespace**: `edc`
- **Chart Version**: 0.1.0
- **Deployment Date**: 2025-09-10 09:58:40
- **Status**: Successfully deployed and operational

## Active Components

### EDC Core Components
- **tractusx-connector**: 0.9.0
  - **Controlplane**: `tractusx/edc-controlplane-postgresql-hashicorp-vault:0.9.0`
  - **Dataplane**: `tractusx/edc-dataplane-hashicorp-vault:0.9.0`
  - **Participant ID**: `BPNL00000000080L`
  - **DID**: `did:web:ssi-dim-wallet-stub.construct-x.net:BPNL00000000080L`

### Supporting Infrastructure
- **HashiCorp Vault**: 1.10.3 (dev mode, root token: "root")
- **PostgreSQL**: 16.2.0-debian-12-r10 (persistence disabled)

### Configuration Details
- **Test Data Seeding**: Enabled (`seedTestdata: true`)
- **Vault Integration**: Configured with EDC secrets
- **Database**: Non-persistent (development configuration)
- **Resource Limits**: 
  - Controlplane: 1.5 CPU, 1024Mi memory
  - Dataplane: 1.5 CPU, 1024Mi memory

## Disabled Components
- **Digital Twin Registry**: `enabled: false`
- **Simple Data Backend**: `enabled: false`
- **Vault Injector**: `enabled: false`
- **PostgreSQL Persistence**: `enabled: false`

## External Access Configuration

### Ingress Endpoints
- **Controlplane**: `dataprovider-x-controlplane.construct-x.prod-k8s.eecc.de`
- **Dataplane**: `dataprovider-x-dataplane.construct-x.prod-k8s.eecc.de`

### SSL Configuration
- **Certificate Issuer**: `prod-eecc` (Let's Encrypt)
- **SSL Redirect**: Disabled (`nginx.ingress.kubernetes.io/ssl-redirect: "false"`)
- **Certificate Status**: Ready and valid

### Load Balancer IPs
- `135.181.220.227`
- `85.10.206.50` 
- `94.130.221.225`

## Post-Install Jobs Status

### Vault Setup Job
- **Job Name**: `eecc-edc-dataprovider-x-post-install-vault-setup`
- **Status**: Completed successfully
- **Runtime**: ~2 minutes
- **Actions**: 
  - Configured vault secrets (tokenSignerPublicKey, tokenSignerPrivateKey, tokenEncryptionAesKey, edc-wallet-secret)
  - Used configmap: `eecc-edc-dataprovider-x-vault-edc-configmap`

### Test Data Upload Job
- **Job Name**: `eecc-edc-dataprovider-x-post-install-testdata`
- **Status**: Completed (but no actual data uploaded)
- **Runtime**: ~93 seconds
- **Issue**: Missing resource files in `resources/` directory
- **Impact**: Job ran successfully but no test data was actually uploaded

## Current Resource Usage
- **Vault**: 19m CPU, 37Mi memory
- **Database**: 17m CPU, 47Mi memory  
- **Controlplane**: 14m CPU, 153Mi memory
- **Dataplane**: 4m CPU, 136Mi memory

## Security Configuration

### IATP (Identity and Trust Protocol)
- **STS DIM URL**: `https://ssi-dim-wallet-stub.construct-x.net/api/sts`
- **OAuth Token URL**: `https://ssi-dim-wallet-stub.construct-x.net/oauth/token`
- **Client ID**: `BPNL00000000080L`
- **Trusted Issuers**: `did:web:ssi-dim-wallet-stub.construct-x.net:BPNL00000003CRHK`
- **BDRS Server**: `https://ssi-dim-wallet-stub.construct-x.net/api/v1/directory`

### Vault Secrets
- **tokenSignerPublicKey**: RSA public key for token verification
- **tokenSignerPrivateKey**: RSA private key for token signing
- **tokenEncryptionAesKey**: AES key for token encryption
- **edc-wallet-secret**: Wallet secret (currently: "changeme")

## Known Issues

### Missing Test Data Resources
The post-install test data job references files that don't exist:
- `resources/requirements.txt`
- `resources/transform-and-upload.py`
- `resources/Testdata_AsBuilt-combustion.json`
- `resources/upload-data.sh`

**Impact**: Test data seeding is not functional, but core EDC functionality is unaffected.

### Development Configuration Warnings
- Vault is running in dev mode (not suitable for production)
- PostgreSQL persistence is disabled (data will be lost on pod restart)
- SSL redirect is disabled (HTTP traffic allowed)

## Recommendations

### For Production Deployment
1. Enable PostgreSQL persistence
2. Configure Vault for production mode
3. Enable SSL redirect
4. Update resource limits based on load testing
5. Disable test data seeding
6. Use production-grade secrets

### For Development Enhancement
1. Add missing test data resource files
2. Enable Digital Twin Registry and Simple Data Backend if needed
3. Configure proper test data for development scenarios
