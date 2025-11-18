# S1: Simple Kubernetes Deployment

**Self-contained Terraform deployment** - Everything you need in one command.

## What Gets Deployed

### Stage 1: OPA Gatekeeper (Security Foundation)
- Gatekeeper namespace
- 3 Gatekeeper controller pods
- 1 Gatekeeper audit pod
- ValidatingWebhookConfiguration

### Stage 2: Security Policies
- 4 ConstraintTemplates (container, image, pod, resource policies)
- 4 Constraints applied to portfolio namespace

### Stage 3: Portfolio Application
- Portfolio namespace
- 3 Deployments (portfolio-api, portfolio-ui, chroma)
- 3 Services (ClusterIP)
- 1 PersistentVolumeClaim (chroma-data)
- 1 Ingress (portfolio.localtest.me, linksmlm.com)
- 3 Network Policies (security)

**Total Resources**: ~25 Kubernetes objects

## Prerequisites

- Docker Desktop with Kubernetes enabled
- kubectl configured
- Helm installed (for Gatekeeper)
- NGINX Ingress Controller installed

## Deploy

```bash
# One command deploys everything
terraform init
terraform apply

# Takes ~5 minutes
# 1. Installs Gatekeeper (2 min)
# 2. Deploys OPA policies (30 sec)
# 3. Deploys Portfolio app (2 min)
```

## Verify

```bash
# Check Gatekeeper is running
kubectl get pods -n gatekeeper-system

# Check OPA policies deployed
kubectl get constrainttemplates
kubectl get constraints -n portfolio

# Check Portfolio app
kubectl get pods -n portfolio
kubectl get ingress -n portfolio
```

## Access

- UI: http://portfolio.localtest.me
- UI: http://linksmlm.com (add to /etc/hosts)
- API: http://portfolio.localtest.me/api

## Clean Up

```bash
# Removes everything
terraform destroy

# This deletes:
# - Portfolio app + namespace
# - OPA policies + constraints
# - Gatekeeper + namespace
```

## What Makes S1 Special

✅ **Fully Self-Contained** - No manual prerequisites
✅ **Infrastructure-as-Code** - Reproducible deployment
✅ **Security First** - OPA policies enforce best practices
✅ **Production Ready** - Same as Method 1 but with Terraform

## Deployment Order

```
1. Gatekeeper → 2. OPA Policies → 3. Portfolio App
   (security)      (enforcement)      (validated)
```

Dependencies are managed automatically - you just run `terraform apply`!
