# Gatekeeper Policies - Runtime Enforcement

**Runtime security enforcement using OPA Gatekeeper** - blocks non-compliant pods at deployment time.

## Purpose

This directory contains **Gatekeeper ConstraintTemplates** for runtime policy enforcement in the Kubernetes cluster. These policies use admission webhooks to **prevent** insecure workloads from being deployed.

## Directory Structure

```
gk-policies/
├── security/                  # Security-focused policies
│   ├── container-security.yaml    # Container hardening
│   └── image-security.yaml        # Image validation
├── governance/                # Resource governance
│   └── resource-limits.yaml       # CPU/memory limits
└── compliance/                # Compliance policies
    └── pod-security-standards.yaml  # K8s PSS enforcement
```

## How It Works

### 1. Install Gatekeeper (prerequisite)
```bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace
```

### 2. Apply ConstraintTemplates
```bash
kubectl apply -f infrastructure/gk-policies/security/
kubectl apply -f infrastructure/gk-policies/governance/
kubectl apply -f infrastructure/gk-policies/compliance/
```

### 3. Developer tries to deploy
```bash
kubectl apply -f bad-deployment.yaml
```

### 4. Gatekeeper blocks it ❌
```
Error from server ([block-privileged-containers] Container 'app' cannot run in privileged mode):
error when creating "bad-deployment.yaml": admission webhook "validation.gatekeeper.sh" denied the request
```

---

## vs. Conftest Policies

| Aspect | **Gatekeeper** (This directory) | **Conftest** (`conftest-policies/`) |
|--------|--------------------------------|-------------------------------------|
| **When** | Runtime (admission controller) | CI/CD pipeline (pre-deployment) |
| **Tool** | Gatekeeper webhook | `conftest` command |
| **Format** | ConstraintTemplates (YAML + Rego) | Pure Rego (.rego files) |
| **Speed** | 🐢 Slower (cluster API call) | ⚡ Fast (seconds) |
| **Scope** | Live cluster deployments | Git commits, PRs |
| **Blocking** | Blocks pod creation | Blocks merge/deploy |

**Defense in depth**: Conftest catches issues early, Gatekeeper is the last line of defense!

---

## Policies Included

### Security Policies

**`container-security.yaml`** (PortfolioSecurityContext)
- ✅ No containers running as root (UID 0)
- ✅ Security context required
- ✅ No privileged containers
- ✅ No privilege escalation
- ✅ Read-only root filesystem (where possible)

**`image-security.yaml`** (PortfolioImageSecurity)
- ✅ No `:latest` tags in production
- ✅ Only trusted registries (`ghcr.io/jimjrxieb/`, `chromadb/`)
- ✅ Image tags must be specified
- ✅ ImagePullPolicy required

### Governance Policies

**`resource-limits.yaml`** (PortfolioResourceLimits)
- ✅ CPU limits required
- ✅ Memory limits required
- ✅ CPU requests required
- ✅ Memory requests required
- ✅ Maximum CPU: 2 cores (2000m)

### Compliance Policies

**`pod-security-standards.yaml`** (PortfolioPodSecurity)
- ✅ No hostNetwork
- ✅ No hostPID
- ✅ No hostIPC
- ✅ No privileged containers
- ✅ No dangerous capabilities (SYS_ADMIN, NET_ADMIN, etc.)
- ✅ Non-root filesystem group
- ✅ seccompProfile required

---

## Usage

### Apply All Policies

```bash
# Apply to cluster
kubectl apply -f infrastructure/gk-policies/security/
kubectl apply -f infrastructure/gk-policies/governance/
kubectl apply -f infrastructure/gk-policies/compliance/

# Verify they're active
kubectl get constrainttemplates
kubectl get constraints --all-namespaces
```

### Check Policy Status

```bash
# List constraint templates
kubectl get constrainttemplates

# List active constraints
kubectl get constraints

# Check violations
kubectl get constraints -o json | \
  jq '.items[] | {name: .metadata.name, violations: .status.totalViolations}'
```

### Test a Deployment

```bash
# Try to deploy a bad deployment
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-app
  namespace: portfolio
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bad
  template:
    metadata:
      labels:
        app: bad
    spec:
      containers:
      - name: app
        image: nginx:latest  # ❌ Will be blocked!
        securityContext:
          runAsUser: 0       # ❌ Will be blocked!
EOF

# Gatekeeper rejects it
Error from server: admission webhook denied the request
```

### Audit Mode (Don't Block, Just Warn)

```yaml
# Edit constraint to audit mode
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: PortfolioSecurityContext
metadata:
  name: portfolio-security-context
spec:
  enforcementAction: dryrun  # ← audit only, don't block
  match:
    namespaces: ["portfolio"]
```

---

## Writing New Policies

### 1. Create ConstraintTemplate

```yaml
# infrastructure/gk-policies/custom/my-policy.yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: portfoliocustompolicy
spec:
  crd:
    spec:
      names:
        kind: PortfolioCustomPolicy
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package portfoliocustompolicy

        violation[{"msg": msg}] {
          # Your Rego logic here
          msg := "Custom policy violation"
        }
---
# Create Constraint instance
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: PortfolioCustomPolicy
metadata:
  name: my-custom-policy
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
    namespaces: ["portfolio"]
```

### 2. Apply to Cluster

```bash
kubectl apply -f infrastructure/gk-policies/custom/my-policy.yaml
```

### 3. Test It

```bash
# Try to violate the policy
kubectl apply -f test-deployment.yaml

# Should be blocked by Gatekeeper
```

---

## Debugging

### See why a deployment was blocked

```bash
kubectl describe <resource> <name>
# Look for "Events" section showing Gatekeeper denial
```

### Check Gatekeeper logs

```bash
kubectl logs -n gatekeeper-system -l control-plane=controller-manager
```

### List all violations

```bash
kubectl get constraints -A -o json | \
  jq -r '.items[] | select(.status.totalViolations > 0) |
    "\(.metadata.name): \(.status.totalViolations) violations"'
```

### Dry-run mode (audit without blocking)

```yaml
spec:
  enforcementAction: dryrun  # audit only
```

---

## Integration with Helm

The Helm chart can enable/disable Gatekeeper policies:

```yaml
# values.yaml
gatekeeper:
  enabled: true  # Deploy ConstraintTemplates with Helm

# When enabled, Helm includes policies from:
# charts/portfolio/templates/gatekeeper-constraints.yaml
```

**Note**: The policies in `infrastructure/gk-policies/` are **separate** from Helm and applied cluster-wide via `kubectl`.

---

## Maintenance

### Update a Policy

```bash
# 1. Edit the ConstraintTemplate
vim infrastructure/gk-policies/security/container-security.yaml

# 2. Re-apply
kubectl apply -f infrastructure/gk-policies/security/container-security.yaml

# 3. Verify
kubectl get constrainttemplate portfoliosecuritycontext -o yaml
```

### Remove a Policy

```bash
# 1. Delete the constraint (instances)
kubectl delete portfoliosecuritycontext --all

# 2. Delete the template
kubectl delete constrainttemplate portfoliosecuritycontext
```

### Backup Policies

```bash
# Export all current constraints
kubectl get constrainttemplates -o yaml > gk-policies-backup.yaml
kubectl get constraints --all-namespaces -o yaml >> gk-policies-backup.yaml
```

---

## Common Issues

### Issue: "Constraint has no violations but pods still deploying"
**Solution**: Check if enforcementAction is set to "dryrun"

### Issue: "Template not found"
**Solution**: Apply ConstraintTemplate first, then Constraint

### Issue: "Gatekeeper webhook not responding"
**Solution**: Check Gatekeeper pods are running in gatekeeper-system namespace

---

## Best Practices

1. ✅ **Test in audit mode first** - Set `enforcementAction: dryrun`
2. ✅ **Start with warnings** - Enable blocking after validating
3. ✅ **Use namespaces** - Apply policies per namespace/environment
4. ✅ **Monitor violations** - Regular audits of constraint status
5. ✅ **Version control** - All policies in Git
6. ✅ **Document exceptions** - Explain why certain violations are allowed

---

## Resources

- [Gatekeeper Documentation](https://open-policy-agent.github.io/gatekeeper/)
- [Gatekeeper Library](https://github.com/open-policy-agent/gatekeeper-library)
- [OPA Playground](https://play.openpolicyagent.org/)
- [Constraint Framework](https://open-policy-agent.github.io/gatekeeper/website/docs/howto/)

---

**🛡️ This is your last line of defense - blocks insecure workloads at the cluster level!**
