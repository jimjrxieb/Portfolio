# RBAC Hardening — FedRAMP AC-2, AC-3

## The Problem

Over-permissive RBAC (cluster-admin everywhere, default ServiceAccount, wildcard verbs)
violates AC-2 (Account Management) and AC-3 (Access Enforcement).

## Quick Diagnosis

```bash
# cluster-admin bindings (should only be in kube-system)
kubectl get clusterrolebindings -o json | jq -r '
  .items[] |
  select(.roleRef.name == "cluster-admin") |
  "\(.metadata.name) → \(.subjects // [] | map(.name) | join(", "))"
'

# Pods using default ServiceAccount
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.serviceAccountName == "default" or .spec.serviceAccountName == null) |
  "\(.metadata.namespace)/\(.metadata.name)"
'

# Roles with wildcard permissions
kubectl get roles,clusterroles -A -o json | jq -r '
  .items[] |
  select(.rules[]? | .verbs[]? == "*" or .resources[]? == "*") |
  "\(.metadata.namespace // "cluster")/\(.metadata.name)"
'

# Who can exec into pods (privilege escalation vector)
kubectl auth can-i create pods/exec --as=system:serviceaccount:default:default -A
```

## Fix: Create Dedicated ServiceAccount

Every app gets its own SA with `automountServiceAccountToken: false`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{APP_NAME}}-sa
  namespace: {{NAMESPACE}}
automountServiceAccountToken: false
```

Reference in deployment:
```yaml
spec:
  template:
    spec:
      serviceAccountName: {{APP_NAME}}-sa
      automountServiceAccountToken: false
```

## Fix: Scope Roles to Minimum Needed

**Read-only app role (most apps need only this):**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{APP_NAME}}-readonly
  namespace: {{NAMESPACE}}
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get"]
```

**CI/CD deployer role (no secrets access):**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{APP_NAME}}-deployer
  namespace: {{NAMESPACE}}
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "update", "patch"]
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps"]
    verbs: ["get", "list", "create", "update", "patch"]
  # NO secrets, NO delete, NO exec
```

## Fix: Remove Unnecessary cluster-admin Bindings

```bash
# List them first
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | select(.roleRef.name == "cluster-admin") |
  .metadata.name
'

# Replace with scoped role (after creating a proper ClusterRole)
kubectl delete clusterrolebinding {{BINDING_NAME}}
```

## Fix: Security Auditor Role (Read-Only Cluster-Wide)

For compliance scanning, create a read-only auditor role:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fedramp-auditor
rules:
  - apiGroups: [""]
    resources: ["namespaces", "pods", "services", "configmaps", "serviceaccounts"]
    verbs: ["get", "list"]
  - apiGroups: ["apps"]
    resources: ["deployments", "daemonsets", "statefulsets"]
    verbs: ["get", "list"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies"]
    verbs: ["get", "list"]
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
    verbs: ["get", "list"]
```

## Full Templates

See `remediation-templates/rbac-templates.yaml` for complete examples.

## Evidence for 3PAO

- [ ] RBAC audit output: all bindings with subjects
- [ ] No workloads on default ServiceAccount
- [ ] No non-system cluster-admin bindings
- [ ] Role definitions showing least-privilege scoping
- [ ] kube-bench Section 5 results (passing)

## Remediation Priority: C — Security Review

RBAC changes affect system access patterns — security review required for proposed changes,
may need human approval for cluster-wide roles.
