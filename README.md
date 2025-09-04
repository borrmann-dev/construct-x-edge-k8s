# Construct-X Edge Deployment

A comprehensive Helm chart for deploying the construct-x edge infrastructure with Eclipse Dataspace Connector (EDC) and supporting services.

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (1.24+)
- Helm 3.8+
- kubectl configured for your cluster
- Domain with DNS pointing to your cluster

### Installation

1. **Clone and navigate to the repository**
   ```bash
   git clone <repository-url>
   cd construct-x
   ```

2. **Configure your values**
   ```bash
   # Edit values.yaml to match your domain and configuration
   vim values.yaml
   ```

3. **Install with the automated script**
   ```bash
   # Make script executable
   chmod +x install.sh

   # Test installation (dry-run)
   ./install.sh --dry-run

   # Actual installation
   ./install.sh
   ```

## 📋 What Gets Deployed

### Core Components

- **🔗 Eclipse Dataspace Connector (EDC)**
  - Control Plane: `dataprovider-x-controlplane.construct-x.borrmann.dev`
  - Data Plane: `dataprovider-x-dataplane.construct-x.borrmann.dev`

- **🗃️ Digital Twin Registry**
  - Registry API: `dataprovider-x-dtr.construct-x.borrmann.dev/semantics/registry`

- **📊 Simple Data Backend**
  - Submodel Server: `dataprovider-x-submodelserver.construct-x.borrmann.dev`

### Infrastructure Components

- **🔐 HashiCorp Vault** - Secrets management
- **🐘 PostgreSQL** - Database for EDC and DTR
- **🌐 Ingress-nginx** - Load balancer and ingress controller
- **🔒 cert-manager** - Automatic SSL certificates via Let's Encrypt
- **📜 ClusterIssuer** - Let's Encrypt certificate issuer

## ⚙️ Configuration

### Main Configuration (`values.yaml`)

```yaml
# Ingress configuration (disabled - services create their own)
ingress:
  enabled: false
  host: construct-x.borrmann.dev

# SSL Certificate issuer
clusterIssuer:
  enabled: true
  name: letsencrypt-prod
  email: your-email@domain.com

# EDC configuration
edc:
  enabled: true
  seedTestdata: true
  # ... detailed EDC configuration
```

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `clusterIssuer.email` | Email for Let's Encrypt certificates | `dennis@borrmann.dev` |
| `ingress.host` | Base domain for services | `construct-x.borrmann.dev` |
| `edc.enabled` | Enable EDC deployment | `true` |
| `edc.seedTestdata` | Seed with test data | `true` |

## 🛠️ Installation Scripts

### Install Script (`install.sh`)

Comprehensive installation script with the following features:

- **Automatic dependency management**
- **cert-manager installation** if not present
- **Helm repository setup** (ingress-nginx, jetstack, hashicorp, tractusx-dev)
- **Namespace creation** (default: `edc`)
- **Error handling and validation**
- **Dry-run support**

#### Usage

```bash
# Basic installation
./install.sh

# Install in different namespace
./install.sh -n production

# Custom release name
./install.sh -r my-edc-deployment

# Dry run (test without installing)
./install.sh --dry-run

# Verbose output for debugging
./install.sh --verbose

# Show all options
./install.sh --help
```

### Uninstall Script (`uninstall.sh`)

Safe uninstallation with confirmation prompts:

```bash
# Basic uninstallation
./uninstall.sh

# Remove namespace as well
./uninstall.sh --delete-namespace

# Remove cert-manager too (use with caution!)
./uninstall.sh --remove-cert-manager

# Skip confirmation prompts
./uninstall.sh --force

# Show what would be deleted
./uninstall.sh --dry-run
```

## 🏗️ Architecture

### Chart Structure

```
construct-x/
├── Chart.yaml                 # Main umbrella chart
├── values.yaml               # Configuration values
├── install.sh                # Installation script
├── uninstall.sh              # Uninstallation script
├── templates/
│   ├── clusterissuer.yaml    # Let's Encrypt issuer
│   ├── ingress.yaml          # Main ingress (disabled)
│   └── _helpers.tpl          # Template helpers
└── charts/
    └── edc/                  # EDC sub-chart
        ├── Chart.yaml        # EDC chart definition
        ├── values.yaml       # EDC configuration
        └── templates/        # EDC templates
```

### Dependencies

The chart uses a nested structure:

```
eecc-edc (Root Chart)
├── ingress-nginx (External)
└── edc (Local Sub-chart)
    ├── digital-twin-registry (External)
    ├── simple-data-backend (External)
    ├── tractusx-connector (External)
    └── vault (External)
```

## 🌐 Service Endpoints

After successful deployment, the following endpoints will be available:

| Service | URL | Purpose |
|---------|-----|---------|
| EDC Control Plane | `https://dataprovider-x-controlplane.construct-x.borrmann.dev` | DSP Protocol, Management API |
| EDC Data Plane | `https://dataprovider-x-dataplane.construct-x.borrmann.dev` | Data Transfer, Public API |
| Digital Twin Registry | `https://dataprovider-x-dtr.construct-x.borrmann.dev/semantics/registry` | Asset Registry |
| Submodel Server | `https://dataprovider-x-submodelserver.construct-x.borrmann.dev` | Data Backend |

All endpoints automatically get SSL certificates via Let's Encrypt.

## 🔧 Troubleshooting

### Common Issues

1. **cert-manager CRDs missing**
   ```bash
   # The install script automatically handles this
   ./install.sh  # Will install cert-manager if needed
   ```

2. **Dependency resolution errors**
   ```bash
   # Update dependencies manually
   helm dependency update
   cd charts/edc && helm dependency update
   ```

3. **Failed vault setup jobs**
   ```bash
   # Clean up failed jobs
   kubectl delete jobs -n edc --all
   kubectl delete pods -n edc --field-selector=status.phase=Failed
   ```

### Debugging Commands

```bash
# Check all pods
kubectl get pods -n edc

# Check Helm releases
helm list -n edc

# Check ingresses and certificates
kubectl get ingress,certificates -n edc

# View logs of specific pod
kubectl logs <pod-name> -n edc

# Check cert-manager
kubectl get clusterissuers
kubectl get certificates -A
```

## 🔄 Upgrading

To upgrade the deployment:

```bash
# Pull latest changes
git pull

# Upgrade with Helm
helm upgrade eecc-edc . -n edc --values values.yaml

# Or use the install script (it will upgrade if already installed)
./install.sh
```

## 🗑️ Uninstalling

### Complete Removal

```bash
# Remove everything including namespace
./uninstall.sh --delete-namespace

# If you also want to remove cert-manager (affects other apps!)
./uninstall.sh --delete-namespace --remove-cert-manager
```

### Partial Removal

```bash
# Remove only the main deployment
./uninstall.sh

# Manual cleanup if needed
helm uninstall eecc-edc -n edc
kubectl delete namespace edc
```

## 📝 Development

### Local Development

1. **Modify values**
   ```bash
   # Edit configuration
   vim values.yaml
   ```

2. **Test changes**
   ```bash
   # Dry run to validate
   ./install.sh --dry-run --verbose
   ```

3. **Apply changes**
   ```bash
   # Upgrade deployment
   helm upgrade eecc-edc . -n edc --values values.yaml
   ```

### Adding New Services

1. Add dependency to `charts/edc/Chart.yaml`
2. Configure in `values.yaml` under `edc:` section
3. Test with dry-run
4. Update this README

## 📚 Additional Resources

- [Eclipse Dataspace Connector Documentation](https://github.com/eclipse-edc/Connector)
- [Tractus-X Charts Repository](https://github.com/eclipse-tractusx/charts)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `./install.sh --dry-run`
5. Submit a pull request

## 📄 License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## 🆘 Support

For issues and questions:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Review the logs: `kubectl logs <pod-name> -n edc`
3. Open an issue in the repository
4. Contact the construct-x team

---

**Note**: Replace `construct-x.borrmann.dev` with your actual domain in the configuration files before deployment.