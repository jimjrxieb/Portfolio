# CKS Domain 2: Cluster Hardening (15%)

Restrict access to the Kubernetes API. Use RBAC to minimize exposure. Exercise caution in using service accounts. Restrict access to the GUI. Verify platform binaries before deploying.

## What You Need to Know

- RBAC (Role, ClusterRole, RoleBinding, ClusterRoleBinding)
- Service account security (automountServiceAccountToken)
- API server access restrictions
- Admission controllers (Kyverno, Gatekeeper, OPA)
- Binary verification (sha512sum)

## Pre-Built Tools (Already in GP-CONSULTING)

### Admission Control
| Resource | Location | What It Provides |
|----------|----------|-----------------|
| 13 Kyverno policies | `02-CLUSTER-HARDENING/templates/policies/kyverno/` | Production-ready ClusterPolicies |
| Gatekeeper constraints | `02-CLUSTER-HARDENING/templates/policies/gatekeeper/` | OPA-based admission control |
| Conftest policies (8+) | `02-CLUSTER-HARDENING/templates/policies/conftest/` | CI-time policy validation |
| `deploy-policies.sh` | `02-CLUSTER-HARDENING/tools/admission/` | Deploy Kyverno/Gatekeeper in audit mode |
| `test-policies.sh` | `02-CLUSTER-HARDENING/tools/admission/` | Smoke-test deployed policies |
| `audit-to-enforce.sh` | `02-CLUSTER-HARDENING/tools/admission/` | Progressive enforcement transition |

### RBAC
| Resource | Location | What It Provides |
|----------|----------|-----------------|
| RBAC templates | `02-CLUSTER-HARDENING/templates/remediation/rbac-templates.yaml` | Role, ClusterRole, RoleBinding scaffolds |
| RBAC audit playbook | `02-CLUSTER-HARDENING/playbooks/07a-rbac-audit.md` | Full RBAC review process |
| `scope-rbac.sh` | `03-DEPLOY-RUNTIME/responders/` | Audit + generate scoped replacements |
| RBAC watcher | `03-DEPLOY-RUNTIME/watchers/watch-audit.sh` | Live cluster-admin binding detection |

### Playbooks
| Playbook | Location | When to Use |
|----------|----------|-------------|
| `06-deploy-admission-control.md` | `02-CLUSTER-HARDENING/playbooks/` | Deploy Kyverno/Gatekeeper |
| `07-audit-to-enforce.md` | `02-CLUSTER-HARDENING/playbooks/` | Progressive: warn -> audit -> deny |
| `07a-rbac-audit.md` | `02-CLUSTER-HARDENING/playbooks/` | Review all RBAC bindings |

## CKS Exam Quick Reference

### RBAC — Create Scoped Role
```bash
# Imperative (exam speed)
kubectl create role pod-reader --verb=get,list,watch --resource=pods -n target-ns
kubectl create rolebinding pod-reader-binding --role=pod-reader --user=jane -n target-ns

# Verify
kubectl auth can-i get pods -n target-ns --as=jane   # yes
kubectl auth can-i delete pods -n target-ns --as=jane  # no
```

### RBAC — Audit Dangerous Bindings
```bash
# Find all cluster-admin bindings
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | select(.roleRef.name=="cluster-admin") |
  "\(.metadata.name) -> \(.subjects[]?.name // "unknown") (\(.subjects[]?.kind // "unknown"))"'

# Find all wildcard permissions
kubectl get clusterroles -o json | jq -r '
  .items[] | select(.rules[]?.verbs[]? == "*") |
  .metadata.name'

# Find service accounts with secrets access
kubectl get clusterroles -o json | jq -r '
  .items[] | select(.rules[]? | .resources[]? == "secrets") |
  .metadata.name'
```

### Disable automountServiceAccountToken
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: target-ns
automountServiceAccountToken: false
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    spec:
      serviceAccountName: app-sa
      automountServiceAccountToken: false
```

### Admission Control — Kyverno Quick Deploy
```bash
# Install Kyverno
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace

# Apply a policy (audit mode first)
kubectl apply -f 02-CLUSTER-HARDENING/templates/policies/kyverno/disallow-privileged.yaml

# Check violations
kubectl get policyreport -A
kubectl get clusterpolicyreport
```

### Verify Kubernetes Binaries
```bash
# Download and verify
VERSION=$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')
curl -LO "https://dl.k8s.io/${VERSION}/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/${VERSION}/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256) kubectl" | sha256sum --check
# Expected: kubectl: OK
```

## Practice Scenarios

1. **RBAC lockdown**: Remove cluster-admin from all service accounts except kube-system
2. **Admission control**: Deploy Kyverno, block privileged containers, verify enforcement
3. **Service account audit**: Find pods with automountServiceAccountToken, disable it
4. **Binary verification**: Download kubectl, verify sha256, replace existing binary
5. **API access restriction**: Configure API server to only accept requests from known CIDRs
