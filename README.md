# Construct-X Edge Deployment

A comprehensive Helm-based deployment for Eclipse Dataspace Connector (EDC) with complete lifecycle management including installation, upgrade, and uninstallation capabilities.

## 🚀 Quick Start

### Prerequisites

- **Kubernetes cluster** (1.24+)
- **Helm** 3.8+
- **kubectl** configured for your cluster
- **jq** (for upgrade script JSON parsing)
- **Domain** with DNS pointing to your cluster

### Complete Installation

```bash
# 1. Clone the repository
git clone <repository-url>
cd construct-x

# 2. Ensure ingress controller is available (managed separately)
# Verify: kubectl get pods -n ingress-nginx

# 3. Configure EDC settings
vim edc/values.yaml  # Update domains and configuration

# 4. Install EDC with all components
cd edc
./install.sh

# 5. Verify installation
kubectl get pods -n edc
kubectl get ingress -n edc
./test-deployment.sh  # Comprehensive deployment verification
```

## 📋 What Gets Deployed

### 🔗 Eclipse Dataspace Connector (EDC) Components

| Component | Purpose | Status | External URL |
|-----------|---------|--------|---------------|
| **EDC Controlplane** | DSP Protocol, Management API | ✅ Active | `dataprovider-x-controlplane.construct-x.borrmann.dev` |
| **EDC Dataplane** | Data Transfer, Public API | ✅ Active | `dataprovider-x-dataplane.construct-x.borrmann.dev` |
| **Digital Twin Registry** | Asset Registry | ⚠️ Disabled | `dataprovider-x-dtr.construct-x.borrmann.dev` |
| **Submodel Server** | Data Backend | ⚠️ Disabled | `dataprovider-x-submodelserver.construct-x.borrmann.dev` |

### 🏗️ Supporting Infrastructure

- **🔐 HashiCorp Vault** - Secrets management for EDC keys (dev mode)
- **🐘 PostgreSQL** - Database for EDC (persistence disabled for development)
- **🌐 Ingress Controller** - nginx-ingress for external access (managed separately)
- **🔒 cert-manager** - Automatic SSL certificates via Let's Encrypt

## ⚙️ Configuration

### Main Configuration (`edc/values.yaml`)

Key settings to customize before deployment:

```yaml
# EDC Participant Configuration
tractusx-connector:
  participant:
    id: BPNL00000000080L  # Your Business Partner Number
  
  # Ingress hostnames (update these!)
  controlplane:
    ingresses:
      - hostname: "dataprovider-x-controlplane.construct-x.borrmann.dev"
  
  dataplane:
    ingresses:
      - hostname: "dataprovider-x-dataplane.construct-x.borrmann.dev"

# Digital Twin Registry (currently disabled)
digital-twin-registry:
  enabled: false  # Set to true to enable
  registry:
    host: dataprovider-x-dtr.construct-x.borrmann.dev

# Submodel Server (currently disabled)
simple-data-backend:
  enabled: false  # Set to true to enable
  ingress:
    hosts:
      - host: "dataprovider-x-submodelserver.construct-x.borrmann.dev"

# Test data seeding (disable in production)
seedTestdata: true
```

## 🛠️ Lifecycle Management

### Installation (`edc/install.sh`)

Complete EDC installation with automatic dependency management:

```bash
# Basic installation
./edc/install.sh

# Custom namespace and release name
./edc/install.sh -n production -r prod-edc

# Dry run to preview changes
./edc/install.sh --dry-run

# Skip dependency updates (if already current)
./edc/install.sh --skip-deps

# Show all options
./edc/install.sh --help
```

**Features:**
- ✅ Automatic Helm repository management
- ✅ Dependency resolution and updates
- ✅ Namespace creation
- ✅ Error handling and validation
- ✅ Dry-run support for testing

### Upgrade (`edc/upgrade.sh`) 🆕

**NEW**: Comprehensive upgrade system with backup and rollback capabilities:

```bash
# Basic upgrade with automatic backup
./edc/upgrade.sh

# Upgrade to specific version
./edc/upgrade.sh --version 0.2.0

# Dry run to preview upgrade
./edc/upgrade.sh --dry-run

# Force upgrade without confirmation (for automation)
./edc/upgrade.sh --force

# Rollback to previous version
./edc/upgrade.sh --rollback 1

# Custom backup directory
./edc/upgrade.sh --backup-dir /path/to/backups
```

**Key Features:**
- 🔄 **Automatic Backup**: Creates timestamped backups before upgrade
- 📦 **Version Control**: Optional target version specification
- ↩️ **Easy Rollback**: Rollback to any previous revision
- 🛡️ **Safety Checks**: Confirmation prompts and dry-run mode
- 📊 **Comprehensive Backup**: Helm values, manifests, and K8s resources

**Backup Structure:**
```
./backups/YYYY-MM-DD_HH-MM-SS_eecc-edc/
├── backup_info.txt           # Backup metadata
├── helm_release_all.yaml     # Complete Helm release info
├── helm_values.yaml          # Current values
├── helm_manifest.yaml        # Deployed manifests
├── helm_history.json         # Release history
├── k8s_resources.yaml        # All Kubernetes resources
├── k8s_configmaps.yaml       # ConfigMaps
├── k8s_secrets.yaml          # Secrets
├── k8s_pvcs.yaml            # Persistent Volume Claims
└── k8s_ingress.yaml         # Ingress resources
```

### Uninstallation (`edc/uninstall.sh`)

Safe removal with advanced cleanup options:

```bash
# Basic uninstallation (with confirmation)
./edc/uninstall.sh

# Remove namespace as well
./edc/uninstall.sh --delete-namespace

# Force removal without prompts
./edc/uninstall.sh --force

# Advanced cleanup including CRDs (use with caution!)
./edc/uninstall.sh --purge-crds

# Dry run to see what would be removed
./edc/uninstall.sh --dry-run
```

## 🌐 Infrastructure Management

### Ingress Controller

**Note**: Ingress controller management scripts have been removed from this project. The nginx-ingress controller should be managed separately.

```bash
# Verify ingress controller is available
kubectl get pods -n ingress-nginx

# If not installed, install via Helm:
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
```

The ingress controller is managed independently to allow separate lifecycle management.

## 🏗️ Architecture

### Project Structure

```
construct-x/
├── bruno/                       # API testing collections (Bruno HTTP client)
│   └── tx-umbrella/            # Comprehensive Construct-X EDC API collection
│       ├── Provider/EDC/       # Provider APIs (Assets, Policies, Contracts, Agreements)
│       ├── Consumer/           # Consumer APIs (Catalog, EDR, Data Access)
│       └── environments/       # Environment configurations
├── edc/                        # EDC Helm chart and lifecycle scripts
│   ├── Chart.yaml             # Chart metadata and dependencies
│   ├── values.yaml            # EDC configuration
│   ├── install.sh             # Installation script
│   ├── upgrade.sh             # Upgrade script
│   ├── uninstall.sh           # Uninstallation script
│   ├── charts/                # Downloaded dependency charts
│   └── templates/             # EDC-specific templates
├── scripts/                    # Utility scripts for deployment and testing
│   ├── dsp-workflow.sh        # Automated DSP workflow script
│   ├── cleanup.sh             # Cleanup utilities
│   └── README.md              # Scripts documentation
├── install-ingress.sh          # Ingress controller installation script
├── uninstall-ingress.sh        # Ingress controller uninstallation script
├── test-deployment.sh          # Comprehensive deployment testing script
└── README.md                   # This documentation
```

### Dependency Chain

```
EDC Deployment (eecc-edc)
├── tractusx-connector (Eclipse Tractus-X) ✅ Active
│   ├── PostgreSQL database
│   └── Controlplane + Dataplane
├── digital-twin-registry (Eclipse Tractus-X) ⚠️ Disabled
│   └── PostgreSQL database
├── simple-data-backend (Eclipse Tractus-X) ⚠️ Disabled
└── vault (HashiCorp) ✅ Active (dev mode)
```

### Network Architecture

```
Internet
    ↓
LoadBalancer (nginx-ingress)
    ↓
Ingress Resources (with SSL termination)
    ↓
┌─────────────────────────────────────────┐
│ Kubernetes Cluster (namespace: edc)     │
│                                         │
│ ┌─────────────┐  ┌─────────────────────┐│
│ │ EDC         │  │ Digital Twin        ││
│ │ Controlplane│  │ Registry (DISABLED) ││
│ └─────────────┘  └─────────────────────┘│
│                                         │
│ ┌─────────────┐  ┌─────────────────────┐│
│ │ EDC         │  │ Submodel            ││
│ │ Dataplane   │  │ Server (DISABLED)   ││
│ └─────────────┘  └─────────────────────┘│
│                                         │
│ ┌─────────────┐  ┌─────────────────────┐│
│ │ HashiCorp   │  │ PostgreSQL          ││
│ │ Vault       │  │ Databases           ││
│ └─────────────┘  └─────────────────────┘│
└─────────────────────────────────────────┘
```

## 🧪 API Testing and Development Tools

### Bruno HTTP Client Collections

The project includes comprehensive API testing collections for the Bruno HTTP client:

#### Comprehensive EDC Testing (`bruno/tx-umbrella/`)
- **Provider APIs**: Asset, Policy, Contract, Agreement Management (Management API v3)
- **Consumer APIs**: Catalog Discovery, EDR Negotiation, Data Access
- **Complete Workflows**: End-to-end Provider setup and Consumer data access flows
- **Environment configurations**: Flexible setup for different deployments

### Deployment Testing

```bash
# Comprehensive deployment verification
./test-deployment.sh

# Test specific endpoints
curl -k https://dataprovider-x-controlplane.construct-x.borrmann.dev/api/v1/management/health

# Check all deployed services
kubectl get all -n edc
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Certificate Issues
```bash
# Check certificate status
kubectl get certificates -n edc

# Check ClusterIssuer
kubectl get clusterissuers

# View certificate events
kubectl describe certificate <cert-name> -n edc
```

#### 2. Pod Startup Issues
```bash
# Check pod status
kubectl get pods -n edc

# View pod logs
kubectl logs <pod-name> -n edc

# Describe pod for events
kubectl describe pod <pod-name> -n edc
```

#### 3. Helm Issues
```bash
# Check Helm release status
helm status eecc-edc -n edc

# View Helm release history
helm history eecc-edc -n edc

# Debug Helm template rendering
helm template eecc-edc ./edc --debug
```

#### 4. Dependency Problems
```bash
# Update dependencies manually
cd edc
helm dependency update

# Check dependency status
helm dependency list
```

### Debugging Commands

```bash
# Complete cluster overview
kubectl get all -n edc

# Check ingress and certificates
kubectl get ingress,certificates -n edc

# View all events in namespace
kubectl get events -n edc --sort-by='.lastTimestamp'

# Check persistent volumes
kubectl get pv,pvc -n edc

# Test internal connectivity
kubectl run debug --image=busybox -it --rm -- sh
```

## 🔄 Upgrade Scenarios

### Version Upgrade

```bash
# Check current version
helm list -n edc

# Upgrade to latest version
./edc/upgrade.sh

# Upgrade to specific version
./edc/upgrade.sh --version 0.2.0
```

### Configuration Changes

```bash
# Edit configuration
vim edc/values.yaml

# Apply changes with backup
./edc/upgrade.sh
```

### Rollback After Issues

```bash
# Check available revisions
helm history eecc-edc -n edc

# Rollback to previous revision
./edc/upgrade.sh --rollback 2

# Or use Helm directly
helm rollback eecc-edc 2 -n edc
```

## 🚀 Deployment Strategies

### Current Development Configuration

The default configuration is optimized for development and testing:

```yaml
# Current active configuration
seedTestdata: true                    # Test data seeding enabled
vault.server.dev.enabled: true       # Vault in dev mode
postgresql.primary.persistence.enabled: false  # Non-persistent storage
digital-twin-registry.enabled: false # DTR disabled
simple-data-backend.enabled: false   # Submodel server disabled
```

**Active Components:**
- ✅ EDC Controlplane + Dataplane
- ✅ HashiCorp Vault (dev mode)
- ✅ PostgreSQL (non-persistent)

### Development Environment

```bash
# 1. Install with current development settings
./edc/install.sh

# 2. Verify deployment
./test-deployment.sh

# Configuration includes:
# - seedTestdata: true
# - Non-persistent storage
# - Development-friendly resource limits
# - SSL certificates with current domains
```

### Production Environment

```bash
# 1. Update configuration for production
vim edc/values.yaml
# Set:
# - seedTestdata: false
# - vault.server.dev.enabled: false
# - postgresql.primary.persistence.enabled: true
# - digital-twin-registry.enabled: true (if needed)
# - simple-data-backend.enabled: true (if needed)
# - Production domains
# - Appropriate resource limits
# - Secure passwords and secrets

# 2. Install with production settings
./edc/install.sh
```

### Staging Environment

```bash
# Use production-like configuration with staging domains
# Test upgrade procedures before production
./edc/upgrade.sh --dry-run
```

### Enabling Additional Components

To enable the currently disabled components:

```yaml
# Enable Digital Twin Registry
digital-twin-registry:
  enabled: true

# Enable Submodel Server
simple-data-backend:
  enabled: true
```

## 📚 Additional Resources

- **[Eclipse Dataspace Connector](https://github.com/eclipse-edc/Connector)** - Main EDC project
- **[Eclipse Tractus-X Charts](https://github.com/eclipse-tractusx/charts)** - Helm charts repository
- **[cert-manager Documentation](https://cert-manager.io/docs/)** - Certificate management
- **[nginx-ingress Documentation](https://kubernetes.github.io/ingress-nginx/)** - Ingress controller

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `./edc/install.sh --dry-run`
5. Submit a pull request

## 📄 License

This project is licensed under the Apache License 2.0.

## 🆘 Support

For issues and questions:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Review pod logs: `kubectl logs <pod-name> -n edc`
3. Check Helm status: `helm status eecc-edc -n edc`
4. Open an issue in the repository

---

**⚠️ Important Notes**:
- Update all domain names in `edc/values.yaml` to match your actual domains before deployment!
- Current configuration uses `construct-x.borrmann.dev` - replace with your domain
- For production: Enable persistence, disable dev mode, and configure proper secrets
- Digital Twin Registry and Submodel Server are currently disabled - enable if needed