# Certificate Management (Simplified)

## Overview
Dead simple Let's Encrypt SSL certificates. Just provide your email and you're done!

## Configuration (Only 3 Settings!)

### Required Settings
- `clusterIssuer.enabled` - Enable/disable certificate issuer (true/false)
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
- cert-manager installed in cluster
- Domain must be publicly accessible
- That's it!

## How It Works
1. You deploy the chart
2. ClusterIssuer gets created
3. Ingress requests certificate automatically
4. Let's Encrypt validates via HTTP challenge
5. Certificate gets issued and installed
6. Auto-renewal happens in background

No complex configuration, no multiple certificate types, just simple Let's Encrypt that works!
