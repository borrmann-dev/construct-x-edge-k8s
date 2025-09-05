# Construct-X Edge Helm Chart Notes

## Project Overview
This is a Helm chart for the construct-x edge deployment, which includes EDC (Eclipse Dataspace Connector) and weather application components.

## Files and Structure
- `charts/base/Chart.yaml` - Base infrastructure chart metadata and dependencies (ingress-nginx, cert-manager)
- `charts/base/values.yaml` - Infrastructure configuration (ingress controller, cert-manager, ClusterIssuer)
- `charts/base/templates/clusterissuer.yaml` - ClusterIssuer template for SSL certificate management
- `charts/edc/` - EDC application chart with its own ingress configurations

## Key Components

### Ingress Configuration
- **File**: [ingress_configuration.md](ingress_configuration.md)
- Simple ingress template supporting multiple services
- Path-based routing with automatic HTTPS
- Easy list-based service configuration

### Certificate Management
- **File**: [certificate_management.md](certificate_management.md)
- Dead simple Let's Encrypt SSL certificates
- Just provide your email and domain
- Automatic certificate provisioning and renewal

### Installation & Uninstallation Scripts

#### Base Infrastructure Scripts
- **Install**: `charts/base/install.sh` - Base infrastructure Helm installation script
  - Default namespace: `base-infrastructure`, Default release: `base-infra`
  - Features: dependency management (ingress-nginx, cert-manager), namespace creation, error handling, dry-run support
  - Prerequisites: kubectl, helm, Kubernetes cluster access
  - Usage: `./install.sh [OPTIONS]` - run with `--help` for full options

- **Uninstall**: `charts/base/uninstall.sh` - Safe base infrastructure uninstallation script
  - Default namespace: `base-infrastructure`, Default release: `base-infra`
  - Features: safety checks, confirmation prompts, optional namespace deletion, optional CRD purging, dry-run support
  - Usage: `./uninstall.sh [OPTIONS]` - run with `--help` for full options
  - Safety: Requires confirmation by default, use `--force` to skip prompts

#### EDC Application Scripts
- **Install**: `install.sh` - Comprehensive Helm installation script
  - Default namespace: `edc`, Default release: `eecc-edc`
  - Features: cert-manager auto-install, dependency management, namespace creation, error handling, dry-run support
  - Prerequisites: Automatically installs cert-manager if not present
  - Usage: `./install.sh [OPTIONS]` - run with `--help` for full options

- **Uninstall**: `uninstall.sh` - Safe Helm uninstallation script
  - Default namespace: `edc`, Default release: `eecc-edc`
  - Features: safety checks, confirmation prompts, optional namespace deletion, optional cert-manager removal, dry-run support
  - Usage: `./uninstall.sh [OPTIONS]` - run with `--help` for full options
  - Safety: Requires confirmation by default, use `--force` to skip prompts

## Related Files
- [ingress_configuration.md](ingress_configuration.md) - Details about ingress setup and configuration options
- [certificate_management.md](certificate_management.md) - ClusterIssuer and SSL certificate configuration
