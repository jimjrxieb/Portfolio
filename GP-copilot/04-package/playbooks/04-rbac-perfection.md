# Playbook: RBAC Perfection

> Tighten RBAC beyond what 02-CLUSTER-HARDENING set up. Remove over-provisioned bindings, enforce least privilege, lock down service accounts.
>
> **When:** After API server / etcd secured. This is where most privilege escalation paths live.
> **Time:** ~25 min

---

## Prerequisites

- 02-CLUSTER-HARDENING playbook 07a (RBAC audit) completed
- `kubectl` with cluster-admin access
- Know which service accounts are used by your applications

---

## Step 1: Find Dangerous Bindings

02-CLUSTER-HARDENING audited RBAC. Now verify nothing was missed and nothing drifted:

```bash
# cluster-admin bindings (should be minimal — kube-system only)
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | select(.roleRef.name=="cluster-admin") |
  "\(.metadata.name) → \(.subjects[]?.name // "unknown") (\(.subjects[]?.kind // "unknown") in \(.subjects[]?.namespace // "cluster-wide"))"'

# Wildcard verb permissions (dangerous)
kubectl get clusterroles -o json | jq -r '
  .items[] | select(.rules[]? | .verbs[]? == "*") |
  .metadata.name' | sort -u

# Wildcard resource permissions (dangerous)
kubectl get clusterroles -o json | jq -r '
  .items[] | select(.rules[]? | .resources[]? == "*") |
  .metadata.name' | sort -u

# Who can access secrets?
kubectl get clusterroles -o json | jq -r '
  .items[] | select(.rules[]? | .resources[]? == "secrets" and (.verbs[]? == "get" or .verbs[]? == "*")) |
  .metadata.name' | sort -u
```

For each finding, decide: **expected** (system role, leave it) or **over-provisioned** (tighten it).

---

## Step 2: Audit Service Accounts

```bash
# Pods with automountServiceAccountToken (should be false unless needed)
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.automountServiceAccountToken != false and .metadata.namespace != "kube-system") |
  "\(.metadata.namespace)/\(.metadata.name) — SA: \(.spec.serviceAccountName // "default")"'

# Pods using the default service account (red flag)
kubectl get pods -A -o json | jq -r '
  .items[] |
  select((.spec.serviceAccountName == "default" or .spec.serviceAccountName == null) and .metadata.namespace != "kube-system") |
  "\(.metadata.namespace)/\(.metadata.name)"'
```

### Fix: Disable automount on default SA

For every namespace where apps run:

```bash
# List namespaces
kubectl get ns --no-headers | awk '{print $1}' | grep -v -E 'kube-system|kube-public|kube-node-lease'

# For each namespace, disable automount on default SA
for NS in $(kubectl get ns --no-headers | awk '{print $1}' | grep -v -E 'kube-system|kube-public|kube-node-lease'); do
    kubectl patch sa default -n "$NS" -p '{"automountServiceAccountToken": false}' 2>/dev/null
    echo "Patched default SA in $NS"
done
```

### Fix: Create dedicated service accounts

For apps still using `default`:

```bash
# Generate scoped SA + Role + RoleBinding
# Reference template:
cat ~/GP-copilot/GP-CONSULTING/04-KUBESTER/templates/quick-ref/rbac-least-privilege.yaml
```

> **Reference:** `02-CLUSTER-HARDENING/playbooks/07a-rbac-audit.md` for the full RBAC audit process.
> **Tool:** `03-DEPLOY-RUNTIME/responders/scope-rbac.sh` generates scoped replacements.

---

## Step 3: Verify RBAC for Critical Operations

```bash
# Can anonymous users access the API?
kubectl auth can-i --list --as=system:anonymous 2>/dev/null | head -20

# Can the default SA in each namespace do anything dangerous?
for NS in $(kubectl get ns --no-headers | awk '{print $1}' | head -10); do
    SECRETS=$(kubectl auth can-i get secrets -n "$NS" --as=system:serviceaccount:${NS}:default 2>/dev/null)
    EXEC=$(kubectl auth can-i create pods/exec -n "$NS" --as=system:serviceaccount:${NS}:default 2>/dev/null)
    if [ "$SECRETS" = "yes" ] || [ "$EXEC" = "yes" ]; then
        echo "[WARN] $NS/default — secrets: $SECRETS, exec: $EXEC"
    fi
done
```

---

## Step 4: Remove Stale Bindings

```bash
# RoleBindings referencing non-existent subjects
kubectl get rolebindings -A -o json | jq -r '
  .items[] | select(.subjects[]? |
    (.kind == "ServiceAccount" and .name != "default")
  ) | "\(.metadata.namespace)/\(.metadata.name) → \(.subjects[].name)"' | while read line; do
    echo "Verify: $line"
done

# ClusterRoleBindings referencing deleted namespaces
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | select(.subjects[]?.namespace != null) |
  .subjects[] | select(.namespace != null) | .namespace' | sort -u | while read NS; do
    kubectl get ns "$NS" &>/dev/null || echo "[STALE] Namespace $NS referenced in CRB but doesn't exist"
done
```

---

## Step 5: Document RBAC State

```bash
# Export current RBAC state for the audit trail
kubectl get clusterrolebindings -o yaml > /tmp/kubester-audit/clusterrolebindings.yaml
kubectl get rolebindings -A -o yaml > /tmp/kubester-audit/rolebindings.yaml
kubectl get clusterroles -o yaml > /tmp/kubester-audit/clusterroles.yaml
echo "RBAC state exported to /tmp/kubester-audit/"
```

---

## Outputs

- Over-provisioned bindings: removed or documented as accepted risk
- Default SA automount: disabled in all application namespaces
- Dedicated SAs: created for apps that were using default
- Stale bindings: cleaned up
- RBAC state: exported for audit trail

---

## Next

→ [05-admission-perfection.md](05-admission-perfection.md) — Perfect admission control beyond audit mode
