# Rendered Kubernetes Manifests

This directory contains generated/rendered Kubernetes manifests.

## Files

### rendered-manifests.yaml
- **Source**: Generated from Helm chart templates (`/charts/portfolio/templates/*`)
- **Size**: 1,325 lines, 34 Kubernetes resources
- **Purpose**: Complete rendered manifests for Portfolio application deployment

## Content Includes
- Namespace with Pod Security Standards enforcement
- Network policies (default deny, allow ingress/egress rules)
- Resource quotas and limits
- Service accounts and secrets
- Application deployments and services
- Security policies and admission controllers

## Usage

```bash
# Apply all rendered manifests
kubectl apply -f rendered-manifests.yaml

# Preview what would be applied
kubectl apply -f rendered-manifests.yaml --dry-run=client

# Apply with server-side dry run
kubectl apply -f rendered-manifests.yaml --dry-run=server
```

## GitOps Integration

This file is a **generated artifact** from:
1. **Source Templates**: `/charts/portfolio/templates/`
2. **Helm Values**: `/charts/portfolio/values.yaml`
3. **Render Command**: `helm template portfolio ./charts/portfolio/ > k8s/rendered/rendered-manifests.yaml`

## Maintenance

- **Do NOT edit manually** - regenerate from Helm templates
- **Regenerate after** template or values changes
- **Version control** for deployment history
- **Use for GitOps** deployment automation