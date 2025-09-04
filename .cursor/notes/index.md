# Construct-X Edge Helm Chart Notes

## Project Overview
This is a Helm chart for the construct-x edge deployment, which includes EDC (Eclipse Dataspace Connector) and weather application components.

## Files and Structure
- `Chart.yaml` - Helm chart metadata and dependencies (includes ingress-nginx)
- `values.yaml` - Configuration values for all chart components
- `install.sh` - Automated Helm installation script with proper error handling
- `uninstall.sh` - Safe Helm uninstallation script with confirmation prompts
- `templates/ingress.yaml` - Ingress resource template for routing traffic
- `templates/clusterissuer.yaml` - ClusterIssuer template for SSL certificate management
- `charts/` - Chart dependencies (ingress-nginx)

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

## Troubleshooting
- **File**: [helm_secret_size_issue.md](helm_secret_size_issue.md)
- Resolution for Helm secret size limit errors (1MB limit)
- Alternative installation approach for large charts

## Related Files
- [ingress_configuration.md](ingress_configuration.md) - Details about ingress setup and configuration options
- [certificate_management.md](certificate_management.md) - ClusterIssuer and SSL certificate configuration
- [helm_secret_size_issue.md](helm_secret_size_issue.md) - Helm secret size troubleshooting guide
