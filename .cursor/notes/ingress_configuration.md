# Ingress Configuration (Simplified with Multiple Services)

## Overview
Simple ingress template that supports multiple services with easy path-based routing. Just list your services and their paths!

## Configuration

### Required Settings
- `ingress.enabled` - Enable/disable ingress (true/false)
- `ingress.host` - Your domain name
- `ingress.tlsSecret` - Name for the TLS certificate secret
- `ingress.services[]` - Array of services to route to

### Service Configuration
Each service needs:
- `path` - URL path (e.g., `/`, `/api`, `/docs`)
- `name` - Kubernetes service name
- `port` - Service port number
- `pathType` - Optional, defaults to "Prefix"

## What You Get
- ✅ **Automatic HTTPS** via Let's Encrypt
- ✅ **SSL redirect** (HTTP → HTTPS)
- ✅ **Multiple service routing** with different paths
- ✅ **Nginx ingress controller**
- ✅ **Certificate auto-renewal**

## Examples

### Single Service
```yaml
ingress:
  enabled: true
  host: my-app.example.com
  tlsSecret: my-app-tls
  services:
    - path: /
      name: my-app-service
      port: 3000
```

### Multiple Services
```yaml
ingress:
  enabled: true
  host: my-app.example.com
  tlsSecret: my-app-tls
  services:
    - path: /
      name: frontend-service
      port: 80
    - path: /api
      name: backend-service
      port: 8080
    - path: /docs
      name: docs-service
      port: 3000
```

### Custom Path Types
```yaml
ingress:
  services:
    - path: /exact-match
      pathType: Exact
      name: exact-service
      port: 9000
    - path: /prefix
      pathType: Prefix  # Default
      name: prefix-service
      port: 8000
```

Simple list-based configuration - add as many services as you need!
