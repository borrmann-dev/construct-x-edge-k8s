# Construct-X Edge Deployment Notes

## Project Overview
This is a comprehensive Helm-based deployment for the construct-x edge infrastructure, featuring Eclipse Dataspace Connector (EDC) with complete lifecycle management including installation, upgrade, and uninstallation capabilities.

## Current Project Structure
```
construct-x/
├── bruno/                       # API testing collections (Bruno HTTP client)
│   └── tx-umbrella/            # Comprehensive Construct-X EDC API collection
│       ├── Provider/           # Provider-side APIs (Assets, Policies, Contracts)
│       ├── Consumer/           # Consumer-side APIs (Catalog, EDR, Data Access)
│       ├── Authentication/     # Central IDP and SSI integration
│       ├── Portal-Backend/     # Construct-X Portal integration
│       └── SSI DIM Wallet/     # Decentralized Identity Management
├── edc/                        # EDC Helm chart and lifecycle scripts
│   ├── Chart.yaml             # EDC chart metadata and dependencies
│   ├── values.yaml            # EDC configuration (tractusx-connector, vault, etc.)
│   ├── install.sh             # EDC installation script
│   ├── upgrade.sh             # EDC upgrade script
│   ├── uninstall.sh           # EDC uninstallation script
│   ├── charts/                # Dependency charts (downloaded)
│   └── templates/             # EDC-specific templates
├── test-deployment.sh         # Comprehensive deployment testing script
├── ub-edge-one/              # Additional edge testing utilities
└── README.md                 # Main documentation

**NOTE**: install-ingress.sh and uninstall-ingress.sh have been removed from the project.

## Architecture Overview

### Currently Deployed Components (ACTIVE)
- **Eclipse Dataspace Connector (tractusx-connector)**: Main EDC implementation with controlplane and dataplane
- **HashiCorp Vault**: Secrets management for EDC keys and certificates (dev mode)
- **PostgreSQL**: Database backend for EDC (persistence disabled for development)

### Available but DISABLED Components
- **Digital Twin Registry**: Asset registry for digital twins and submodels (enabled: false)
- **Simple Data Backend**: Submodel server providing actual data (enabled: false)

### Infrastructure Components
- **Ingress Controller**: nginx-ingress for external access (managed separately)
- **Certificate Management**: cert-manager with Let's Encrypt for SSL
- **Namespace**: `edc` (default) for all EDC components

### Current Service Endpoints (External)
- **EDC Controlplane**: `dataprovider-x-controlplane.construct-x.prod-k8s.eecc.de`
- **EDC Dataplane**: `dataprovider-x-dataplane.construct-x.prod-k8s.eecc.de`

### Disabled Service Endpoints
- **Digital Twin Registry**: Not deployed (component disabled)
- **Submodel Server**: Not deployed (component disabled)

## Lifecycle Management Scripts

### Infrastructure Scripts
**REMOVED**: `install-ingress.sh` and `uninstall-ingress.sh` are no longer part of the project.
Ingress controller management is now handled separately from this deployment.

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
1. **Ensure Ingress Controller**: Verify nginx-ingress is available in cluster
2. **Install EDC**: `./edc/install.sh`
3. **Verify**: Check endpoints and certificates using `./test-deployment.sh`

### Upgrade Existing Installation
1. **Backup & Upgrade**: `./edc/upgrade.sh` (automatic backup)
2. **Verify**: Check services are running
3. **Rollback if needed**: `./edc/upgrade.sh --rollback REVISION`

### Safe Removal
1. **Remove EDC**: `./edc/uninstall.sh`
2. **Ingress Controller**: Managed separately (not part of this deployment)

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

## Troubleshooting
- **File**: [helm_secret_size_issue.md](helm_secret_size_issue.md)
- Resolution for Helm secret size limit errors (1MB limit)
- Alternative installation approach for large charts

## API Testing and Development Tools

### Bruno HTTP Client Collections
- **`bruno/tx-umbrella/`**: Comprehensive EDC API testing collection for Construct-X
  - **Provider APIs**: Asset, Policy, Contract, Agreement Management (Management API v3)
  - **Consumer APIs**: Catalog Discovery, EDR Negotiation, Data Access
  - **Authentication**: Central IDP integration, SSI DIM Wallet management
  - **Portal Integration**: Connector registration, Clearing House integration
  - **Submodel Server**: Digital Product Passport data upload/retrieval
  - **Complete Workflows**: End-to-end Provider setup and Consumer data access flows
  - **Construct-X Ecosystem**: BPN-based policies, Catena-X data models, Dataspace Protocol HTTP

### DSP Workflow Automation
- **`scripts/dsp-workflow.sh`**: Fully automated DSP workflow script
  - **Complete Automation**: End-to-end workflow from provider setup to successful data retrieval
  - **Smart Resource Management**: Checks and reuses existing resources to avoid conflicts
  - **Dynamic Response Parsing**: Automatically extracts IDs, tokens, and endpoints from API responses
  - **Environment Configuration**: Flexible setup via `.env` file with all required parameters
  - **Comprehensive Error Handling**: User-friendly output with detailed error messages and health checks
  - **Debug Mode**: Optional verbose output with `DEBUG=true` for troubleshooting
  - **Clean Output**: Formatted JSON payloads for requests and responses
  - **Configurable Data Source**: `DATA_SOURCE_URL` can be overridden in `.env` file

### Deployment Testing
- **`test-deployment.sh`**: Comprehensive deployment verification script
  - Tests all deployed endpoints for availability
  - Validates SSL certificates and ingress configuration
  - Checks pod health and resource usage
  - Provides detailed deployment status report

### Current Deployment Status (as of analysis)
- **Deployment**: `eecc-edc` in namespace `edc`
- **Components**: EDC Controlplane + Dataplane, PostgreSQL, HashiCorp Vault
- **Status**: All pods running and healthy
- **Post-install Jobs**: Vault setup and test data upload completed successfully
- **SSL Certificates**: Valid and ready
- **External Access**: Available via nginx-ingress

## Related Files

- **[bruno_api_collection.md](bruno_api_collection.md)** - Comprehensive Bruno API collection documentation for Construct-X EDC workflows
- **[current_deployment.md](current_deployment.md)** - Current deployment status, configuration, and resource usage
- **[ingress_configuration.md](ingress_configuration.md)** - Ingress setup and configuration options
- **[certificate_management.md](certificate_management.md)** - SSL certificate and ClusterIssuer configuration
- **[service_testing.md](service_testing.md)** - Service testing and health check procedures
- **[helm_secret_size_issue.md](helm_secret_size_issue.md)** - Troubleshooting for Helm secret size limitations

