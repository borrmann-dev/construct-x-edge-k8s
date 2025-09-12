# Ingress Configuration for EDC Deployment

## Overview
The EDC deployment uses individual ingress resources for each service, providing dedicated SSL certificates and routing. Each service manages its own ingress configuration within the Helm chart.

## Current EDC Ingress Architecture

### Service-Specific Ingresses
Each EDC component has its own ingress configuration:

#### EDC Controlplane
```yaml
tractusx-connector:
  controlplane:
    ingresses:
      - enabled: true
        hostname: "dataprovider-x-controlplane.construct-x.prod-k8s.eecc.de"
        endpoints: ["default", "protocol", "management"]
        className: "nginx"
        annotations:
          cert-manager.io/cluster-issuer: prod-eecc
          nginx.ingress.kubernetes.io/ssl-redirect: "false"
        tls:
          enabled: true
```

#### EDC Dataplane
```yaml
tractusx-connector:
  dataplane:
    ingresses:
      - enabled: true
        hostname: "dataprovider-x-dataplane.construct-x.prod-k8s.eecc.de"
        endpoints: ["default", "public"]
        className: "nginx"
        annotations:
          cert-manager.io/cluster-issuer: prod-eecc
          nginx.ingress.kubernetes.io/ssl-redirect: "false"
        tls:
          enabled: true
```

#### Digital Twin Registry (DISABLED)
```yaml
digital-twin-registry:
  enabled: false  # Currently disabled in deployment
  registry:
    ingress:
      enabled: true
      className: "nginx"
      host: dataprovider-x-dtr.construct-x.prod-k8s.eecc.de
      tls: true
      annotations:
        cert-manager.io/cluster-issuer: prod-eecc
        nginx.ingress.kubernetes.io/ssl-redirect: "false"
```

#### Submodel Server (DISABLED)
```yaml
simple-data-backend:
  enabled: false  # Currently disabled in deployment
  ingress:
    enabled: true
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: prod-eecc
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
    tls:
      - secretName: "submodelserver.tx.constructx-tls"
        hosts: ["dataprovider-x-submodelserver.construct-x.prod-k8s.eecc.de"]
    hosts:
      - host: "dataprovider-x-submodelserver.construct-x.prod-k8s.eecc.de"
        paths: [{"path": "/", "pathType": "Prefix"}]
```

## What You Get
- ✅ **Dedicated SSL certificates** for each service
- ✅ **Automatic HTTPS** via Let's Encrypt
- ✅ **Service isolation** with separate ingress resources
- ✅ **nginx-ingress controller** compatibility
- ✅ **Automatic certificate renewal**

## Configuration Guidelines

### Domain Configuration
Update all hostnames in `edc/values.yaml` to match your domain:
```yaml
# Replace construct-x.prod-k8s.eecc.de with your domain
hostname: "dataprovider-x-controlplane.your-domain.com"
```

### SSL Configuration
All ingresses automatically get SSL via these annotations:
```yaml
annotations:
  cert-manager.io/cluster-issuer: prod-eecc
  nginx.ingress.kubernetes.io/ssl-redirect: "false"
```

### Path Configuration
- **EDC Controlplane**: Multiple endpoints on same host
- **EDC Dataplane**: Public API endpoints
- **DTR**: Path rewriting for `/semantics/registry`
- **Submodel Server**: Direct root path access

## Troubleshooting Ingress

```bash
# Check all ingress resources
kubectl get ingress -n edc

# Check specific ingress details
kubectl describe ingress <ingress-name> -n edc

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Test ingress connectivity
curl -v https://dataprovider-x-controlplane.construct-x.prod-k8s.eecc.de
```

The ingress configuration is automatically managed by the EDC installation scripts!
