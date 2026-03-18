# Playbook 07a — RBAC Audit

## Purpose

Review ClusterRoleBindings, RoleBindings, and ServiceAccounts for over-permissioned access. This runs after admission control is enforced (07) because policy enforcement prevents new violations — this playbook catches existing ones.

## Pre-Check

```bash
# Full RBAC dump
kubectl get clusterrolebindings -o custom-columns='NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name'
kubectl get rolebindings -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name'
```

## What to Look For

### Critical: cluster-admin Bindings

```bash
# Find all cluster-admin bindings
kubectl get clusterrolebindings -o json | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['items']:
    if item['roleRef']['name'] == 'cluster-admin':
        subjects = [f\"{s['kind']}/{s['name']}\" for s in item.get('subjects', [])]
        print(f\"  {item['metadata']['name']}: {', '.join(subjects)}\")
"
```

**Expected cluster-admin bindings (k3s):**
- `cluster-admin` → `system:masters` (built-in, cannot remove)
- `kube-apiserver-kubelet-admin` → `kube-apiserver` (built-in)

**Suspicious cluster-admin bindings:**
- `helm-kube-system-*` → Helm install ServiceAccounts. k3s creates these for Traefik/CoreDNS Helm charts. The SAs only run during install/upgrade jobs, but the binding persists.

### High: Wildcard Permissions

```bash
# Find roles with wildcard verbs or resources
kubectl get clusterroles -o json | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['items']:
    for rule in item.get('rules', []):
        if '*' in rule.get('verbs', []) or '*' in rule.get('resources', []):
            print(f\"  {item['metadata']['name']}: verbs={rule.get('verbs')}, resources={rule.get('resources')}\")
"
```

### Medium: ServiceAccounts with automountServiceAccountToken

```bash
# Find pods that auto-mount SA tokens but don't need K8s API access
kubectl get pods -A -o json | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
for pod in data['items']:
    spec = pod['spec']
    auto = spec.get('automountServiceAccountToken', True)
    if auto:
        ns = pod['metadata']['namespace']
        name = pod['metadata']['name']
        sa = spec.get('serviceAccountName', 'default')
        print(f\"  {ns}/{name} (sa={sa})\")
"
```

## Decision Tree

```
Is this a system binding (system:*, kube-*)?
├── YES → Document, don't touch. These are k3s/K8s internals.
└── NO
    ├── Is it cluster-admin?
    │   ├── Is it a Helm install SA (helm-*)?
    │   │   └── B-rank: Risk-accept with documentation.
    │   │       k3s recreates these on upgrade. Removing causes upgrade failures.
    │   └── Is it a user-created binding?
    │       └── S-rank: Escalate immediately. Create scoped ClusterRole instead.
    ├── Does it have wildcard permissions?
    │   └── C-rank: Propose scoped replacement. JADE reviews.
    └── Is it appropriately scoped?
        └── No action needed.
```

## Remediation

### Scoping a Helm cluster-admin (if client requires it)

```yaml
# Instead of cluster-admin, create a scoped role for Helm
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: helm-traefik-scoped
rules:
  - apiGroups: ["", "apps", "extensions", "networking.k8s.io"]
    resources: ["deployments", "services", "configmaps", "secrets", "ingresses", "ingressclasses"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["traefik.io", "traefik.containo.us"]
    resources: ["*"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

**Warning:** Replacing k3s Helm bindings can break automatic upgrades. Document and risk-accept unless client explicitly requires it.

## Agent Integration

`jsa-infrasec` reads this playbook for RBAC findings:
- E-rank: automountServiceAccountToken on pods that don't need API access → auto-fix
- D-rank: Unused RoleBindings → log + propose removal
- C-rank: Wildcard permissions → JADE reviews proposed scoped replacement
- B-rank: Helm cluster-admin bindings → document for human review
- S-rank: User-created cluster-admin → escalate immediately
