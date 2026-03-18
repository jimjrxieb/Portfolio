# Playbook 12 — Namespace-as-a-Service

> Self-service namespace provisioning via K8s CRD + Operator.
> Dev applies a TeamNamespace manifest → operator provisions a fully hardened namespace.
> No tickets, no waiting, no manual kubectl.

---

## Why Namespace-as-a-Service

| Without NaaS | With NaaS |
|-------------|-----------|
| Dev files ticket → platform team creates namespace manually | Dev applies a YAML → namespace provisioned in seconds |
| Inconsistent setup (some miss NetworkPolicy, others miss quotas) | Every namespace gets the same hardening automatically |
| Platform team bottleneck | Self-service, zero bottleneck |
| No audit trail | CRD is the audit trail — GitOps-friendly |

**CNPA exam**: "Dev needs a namespace" → Namespace-as-a-Service via CRD + Operator.

---

## What Gets Provisioned

When a dev creates a TeamNamespace, the operator provisions:

| Resource | What | Config Source |
|----------|------|--------------|
| Namespace | PSS labels (restricted for prod, baseline for dev) | `spec.environment` |
| NetworkPolicy | Default-deny ingress + egress, allow DNS | Always |
| LimitRange | Per-container defaults and maximums | `spec.resourceTier` |
| ResourceQuota | Namespace-wide resource caps | `spec.resourceTier` |
| RoleBinding (team) | Team group gets `edit` | `spec.teamName` |
| RoleBinding (platform) | Platform team gets `admin` | Always |
| SecretStore (optional) | ESO backend for secrets | `spec.enableExternalSecrets` |

### Resource Tiers

| Tier | CPU Requests | Memory Requests | Max Deployments | Max Secrets |
|------|-------------|----------------|----------------|-------------|
| `small` | 2 cores | 4Gi | 10 | 20 |
| `medium` | 8 cores | 16Gi | 25 | 50 |
| `large` | 32 cores | 64Gi | 50 | 100 |

---

## Prerequisites

- Cluster running (02 hardening complete)
- `kubectl` with cluster-admin access
- `gp-security` namespace (or operator will create it)
- For ESO integration: External Secrets Operator installed (playbook 10)

---

## Step 1: Deploy the Operator

```bash
PKG=~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING

# Full deploy (CRD + RBAC + operator)
bash $PKG/tools/platform/deploy-namespace-operator.sh

# With test validation
bash $PKG/tools/platform/deploy-namespace-operator.sh --test

# Dry-run
bash $PKG/tools/platform/deploy-namespace-operator.sh --dry-run
```

### Verify

```bash
# CRD registered
kubectl get crd teamnamespaces.platform.gp-copilot.io
# NAME                                     CREATED AT
# teamnamespaces.platform.gp-copilot.io    2026-03-11T...

# Operator running
kubectl get pods -n gp-security -l app=namespace-operator
# NAME                                  READY   STATUS    RESTARTS   AGE
# namespace-operator-xxxxx              1/1     Running   0          1m

# Operator logs
kubectl logs -n gp-security -l app=namespace-operator --tail=20
```

---

## Step 2: Create a TeamNamespace

```yaml
# payments-dev.yaml
apiVersion: platform.gp-copilot.io/v1alpha1
kind: TeamNamespace
metadata:
  name: payments-dev
spec:
  teamName: payments
  environment: dev
  resourceTier: small
```

```bash
kubectl apply -f payments-dev.yaml

# Check status
kubectl get tns
# NAME            TEAM       ENV    TIER    PHASE   AGE
# payments-dev    payments   dev    small   Ready   5s

# Verify provisioned resources
kubectl get ns payments-dev --show-labels
kubectl get netpol,limitrange,quota -n payments-dev
kubectl get rolebinding -n payments-dev
```

---

## Step 3: Production Namespace (Full Featured)

```yaml
apiVersion: platform.gp-copilot.io/v1alpha1
kind: TeamNamespace
metadata:
  name: payments-prod
spec:
  teamName: payments
  environment: prod
  resourceTier: large
  enableExternalSecrets: true
  additionalAdmins:
    - system:serviceaccount:argocd:argocd-application-controller
```

Production differences:
- PSS label: `restricted` (enforces non-root, drop ALL, read-only rootfs)
- Large quota (32 CPU, 64Gi memory)
- ESO SecretStore provisioned
- ArgoCD SA gets admin (for GitOps deployments)

---

## Step 4: Use with Backstage (Optional)

Wire TeamNamespace into a Backstage software template so devs get a namespace when they scaffold a new service:

```yaml
# In Backstage software template steps:
- id: create-namespace
  name: Create Namespace
  action: kubernetes:apply
  input:
    manifest:
      apiVersion: platform.gp-copilot.io/v1alpha1
      kind: TeamNamespace
      metadata:
        name: ${{ parameters.appName }}-${{ parameters.environment }}
      spec:
        teamName: ${{ parameters.teamName }}
        environment: ${{ parameters.environment }}
        resourceTier: small
        enableExternalSecrets: true
```

---

## Troubleshooting

### TeamNamespace stuck in no status

```bash
# Check operator logs
kubectl logs -n gp-security -l app=namespace-operator --tail=50

# Common causes:
# - Operator pod not running (check deploy)
# - RBAC missing (check ClusterRoleBinding)
# - CRD not applied (check kubectl get crd)
```

### Namespace exists but missing resources

```bash
# Force re-reconcile by touching the CR
kubectl annotate tns payments-dev reconcile=$(date +%s) --overwrite

# Check operator logs for errors
```

### Cleanup

```bash
# Delete TeamNamespace (namespace is preserved — manual cleanup required)
kubectl delete tns payments-dev

# To also delete the namespace:
kubectl delete ns payments-dev
```

---

## Templates Reference

| File | What | Who |
|------|------|-----|
| `crd.yaml` | TeamNamespace CRD definition | Platform team (one-time) |
| `rbac.yaml` | Operator ServiceAccount + ClusterRole | Platform team (one-time) |
| `operator-deployment.yaml` | Operator pod spec | Platform team |
| `example-teamnamespace.yaml` | Example CRs (dev/staging/prod) | Dev team (self-service) |
| `namespace-operator.py` | Reconciliation logic | Platform team |
| `deploy-namespace-operator.sh` | Automated deployment | Platform team |

---

*Ghost Protocol — Namespace-as-a-Service (CKA + CNPA)*
