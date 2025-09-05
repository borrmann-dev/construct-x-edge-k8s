# Certificate Management (Simplified)

## Overview
Dead simple Let's Encrypt SSL certificates. Just provide your email and you're done!

## Configuration (Only 3 Settings!)

### Required Settings
- `clusterIssuer.name` - Name for the issuer (e.g., "letsencrypt-prod")
- `clusterIssuer.email` - Your email for Let's Encrypt notifications

## What You Get
- ✅ **Free SSL certificates** from Let's Encrypt
- ✅ **Automatic renewal** (90 days before expiry)
- ✅ **HTTP-01 challenge** (works with any public domain)
- ✅ **Production-ready** Let's Encrypt server
- ✅ **Zero maintenance** after setup

## Example
```yaml
clusterIssuer:
  enabled: true
  name: letsencrypt-prod
  email: admin@example.com  # Your real email!
```

## Prerequisites
- **cert-manager** installed in cluster (handled by install script)
- **Domain** must be publicly accessible with proper DNS
- **Ingress controller** (nginx-ingress) for HTTP-01 challenge

## How It Works
1. **Install script** ensures cert-manager is available
2. **ClusterIssuer** gets created automatically
3. **Ingress resources** request certificates via annotations
4. **Let's Encrypt** validates domain via HTTP-01 challenge
5. **Certificates** get issued and installed automatically
6. **Auto-renewal** happens 30 days before expiration

## Integration with EDC Installation

The EDC installation process automatically handles certificate management:

```bash
# The install script checks for cert-manager
./edc/install.sh
# - Verifies cert-manager availability
# - Creates ClusterIssuer if needed
# - Configures ingresses with proper annotations
```

## Certificate Annotations

Each ingress automatically gets these annotations:
```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod
  nginx.ingress.kubernetes.io/ssl-redirect: "false"
```

## Troubleshooting Certificates

```bash
# Check certificate status
kubectl get certificates -n edc

# Check certificate details
kubectl describe certificate <cert-name> -n edc

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check ClusterIssuer status
kubectl describe clusterissuer letsencrypt-prod
```

No complex configuration needed - the installation scripts handle everything automatically!
