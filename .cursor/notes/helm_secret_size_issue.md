# Helm Secret Size Issue Resolution

## Problem
The Helm installation was failing with error:
```
Error: INSTALLATION FAILED: create: failed to create: Secret "sh.helm.release.v1.eecc-edc.v1" is invalid: data: Too long: may not be more than 1048576 bytes
```

## Root Cause
- Helm 3 stores release information in Kubernetes secrets with a 1MB size limit
- The EDC chart package (`charts/edc-0.1.0.tgz`) was 384KB+ due to embedded dependencies:
  - `digital-twin-registry-0.6.3.tgz` (192KB)
  - `tractusx-connector-0.9.0.tgz` (144KB)  
  - `vault-0.20.0.tgz` (43KB)
  - `simple-data-backend-0.1.0.tgz`
- When combined with chart templates and values, the total release data exceeded 1MB

## Solution
Instead of using the packaged chart with embedded dependencies, install components separately:

1. **Install ingress-nginx separately:**
   ```bash
   helm install ingress-nginx ingress-nginx/ingress-nginx --namespace edc --create-namespace --set controller.service.type=LoadBalancer
   ```

2. **Install EDC chart directly from source:**
   ```bash
   helm install eecc-edc charts/edc --namespace edc --values values.yaml
   ```

## Key Changes Made
- Modified main `Chart.yaml` to remove the edc dependency
- Install components in separate Helm releases to avoid size limits
- Dependencies are still managed properly through the individual chart's `Chart.yaml`

## Prevention
- Monitor chart package sizes: `ls -lh charts/*.tgz`
- Consider splitting large umbrella charts into separate releases
- Use `helm template` to check rendered size before installation

## Status
✅ **RESOLVED** - Installation now works successfully with pods starting up properly.
