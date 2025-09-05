# Construct-X Edge Deployment Notes

## Project Overview
This is a comprehensive Helm-based deployment for the construct-x edge infrastructure, featuring Eclipse Dataspace Connector (EDC) with complete lifecycle management including installation, upgrade, and uninstallation capabilities.

## Current Project Structure
```
construct-x/
├── edc/                          # EDC Helm chart and lifecycle scripts
│   ├── Chart.yaml               # EDC chart metadata and dependencies
│   ├── values.yaml              # EDC configuration (tractusx-connector, DTR, vault, etc.)
│   ├── install.sh               # EDC installation script
│   ├── upgrade.sh               # EDC upgrade script (NEW)
│   ├── uninstall.sh             # EDC uninstallation script
│   ├── charts/                  # Dependency charts (downloaded)
│   └── templates/               # EDC-specific templates
├── install-ingress.sh           # Standalone ingress controller installation
├── uninstall-ingress.sh         # Standalone ingress controller removal
└── README.md                    # Main documentation

## Architecture Overview

### EDC Components
- **Eclipse Dataspace Connector (tractusx-connector)**: Main EDC implementation with controlplane and dataplane
- **Digital Twin Registry**: Asset registry for digital twins and submodels
- **Simple Data Backend**: Submodel server providing actual data
- **HashiCorp Vault**: Secrets management for EDC keys and certificates
- **PostgreSQL**: Database backend for EDC and DTR

### Infrastructure Components
- **Ingress Controller**: nginx-ingress for external access
- **Certificate Management**: cert-manager with Let's Encrypt for SSL
- **Namespace**: `edc` (default) for all EDC components

### Service Endpoints (External)
- **EDC Controlplane**: `dataprovider-x-controlplane.construct-x.borrmann.dev`
- **EDC Dataplane**: `dataprovider-x-dataplane.construct-x.borrmann.dev`
- **Digital Twin Registry**: `dataprovider-x-dtr.construct-x.borrmann.dev`
- **Submodel Server**: `dataprovider-x-submodelserver.construct-x.borrmann.dev`

## Lifecycle Management Scripts

### Infrastructure Scripts
- **Install Ingress**: `install-ingress.sh` - Standalone ingress controller installation
  - Installs nginx-ingress-controller in `ingress-nginx` namespace
  - Configures LoadBalancer service for external access
  - Independent of EDC installation
  - Usage: `./install-ingress.sh [OPTIONS]`

- **Uninstall Ingress**: `uninstall-ingress.sh` - Safe ingress controller removal
  - Removes nginx-ingress-controller and namespace
  - Confirmation prompts for safety
  - Usage: `./uninstall-ingress.sh [OPTIONS]`

### EDC Application Scripts
- **Install**: `edc/install.sh` - Complete EDC installation with all dependencies
  - **Namespace**: `edc` (default), **Release**: `eecc-edc` (default)
  - **Features**: Dependency management, namespace creation, error handling, dry-run support
  - **Dependencies**: Automatically handles Eclipse Tractus-X and HashiCorp Vault repositories
  - **Configuration**: Uses `edc/values.yaml`, supports custom values files
  - **Prerequisites**: kubectl, helm, Kubernetes cluster access
  - **Usage**: `./edc/install.sh [OPTIONS]` - run with `--help` for full options

- **Upgrade**: `edc/upgrade.sh` - **NEW** - Comprehensive upgrade with backup and rollback
  - **Namespace**: `edc` (default), **Release**: `eecc-edc` (default)
  - **Key Features**:
    - **Automatic Backup**: Creates timestamped backups before upgrade
    - **Version Control**: Optional target version specification (`--version VERSION`)
    - **Rollback Support**: Rollback to any previous revision (`--rollback REVISION`)
    - **Safety Checks**: Confirmation prompts, dry-run support, force mode
    - **Dependency Updates**: Automatic Helm dependency management
  - **Backup Contents**: Helm values, manifests, Kubernetes resources
  - **Backup Location**: `./backups/YYYY-MM-DD_HH-MM-SS_RELEASE_NAME/`
  - **Prerequisites**: Existing EDC installation, jq for JSON parsing
  - **Usage**: `./edc/upgrade.sh [OPTIONS]` - run with `--help` for full options

- **Uninstall**: `edc/uninstall.sh` - Safe EDC removal with advanced cleanup
  - **Namespace**: `edc` (default), **Release**: `eecc-edc` (default)
  - **Features**: Safety checks, confirmation prompts, advanced resource cleanup
  - **Cleanup Options**: PVCs, secrets, configmaps, namespace deletion, CRD purging
  - **Safety**: Requires confirmation by default, use `--force` to skip prompts
  - **Scope**: Removes only EDC components, preserves infrastructure
  - **Usage**: `./edc/uninstall.sh [OPTIONS]` - run with `--help` for full options

## Deployment Strategies

### Complete Fresh Installation
1. **Install Ingress Controller**: `./install-ingress.sh`
2. **Install EDC**: `./edc/install.sh`
3. **Verify**: Check endpoints and certificates

### Upgrade Existing Installation
1. **Backup & Upgrade**: `./edc/upgrade.sh` (automatic backup)
2. **Verify**: Check services are running
3. **Rollback if needed**: `./edc/upgrade.sh --rollback REVISION`

### Safe Removal
1. **Remove EDC**: `./edc/uninstall.sh`
2. **Remove Ingress** (optional): `./uninstall-ingress.sh`

## Configuration Management

### Key Configuration Files
- **`edc/values.yaml`**: Main EDC configuration including:
  - Participant ID and DID configuration
  - Ingress hostnames and SSL settings
  - Database and vault configuration
  - Resource limits and requests
- **`edc/Chart.yaml`**: Dependency versions and metadata

### Environment-Specific Configurations
- **Development**: Use `seedTestdata: true` for test data
- **Production**: Set appropriate resource limits and disable test data
- **Staging**: Mirror production settings with staging domains

## Best Practices

### Security
- Always use SSL/TLS in production (enabled by default)
- Rotate vault tokens and database passwords regularly
- Use proper RBAC and network policies
- Keep dependency versions updated

### Operations
- Always create backups before upgrades (`upgrade.sh` does this automatically)
- Monitor certificate expiration (Let's Encrypt auto-renews)
- Use dry-run mode to test changes
- Keep Helm release history for easy rollbacks

### Troubleshooting
- Check pod logs: `kubectl logs -n edc <pod-name>`
- Verify certificates: `kubectl get certificates -n edc`
- Test endpoints: Use service testing scripts
- Review Helm status: `helm status eecc-edc -n edc`

## Related Files
- **[ingress_configuration.md](ingress_configuration.md)** - Ingress setup and configuration options
- **[certificate_management.md](certificate_management.md)** - SSL certificate and ClusterIssuer configuration
- **[service_testing.md](service_testing.md)** - Service testing and health check procedures
