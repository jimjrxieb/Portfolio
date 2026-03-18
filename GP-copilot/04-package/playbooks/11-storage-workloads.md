# Playbook: Storage & Workload Perfection

> Verify storage security, health probes, resource limits, and deployment strategies. The developer-facing items that 01-03 may have set generically.
>
> **When:** After runtime perfected. These are the workload-level details.
> **Time:** ~15 min

---

## Prerequisites

- Application running in the cluster
- 02-CLUSTER-HARDENING playbook 04 (fix manifests) completed

---

## Step 1: Resource Limits Audit

```bash
# Pods WITHOUT resource limits (OOM bomb risk)
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.metadata.namespace | test("kube-system|kyverno|gatekeeper|falco") | not) |
  select(.spec.containers[]? | .resources.limits == null) |
  "\(.metadata.namespace)/\(.metadata.name)"'

# Pods WITHOUT resource requests (scheduler can't optimize)
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.metadata.namespace | test("kube-system|kyverno|gatekeeper|falco") | not) |
  select(.spec.containers[]? | .resources.requests == null) |
  "\(.metadata.namespace)/\(.metadata.name)"'
```

Fix with the tools from 02:

```bash
# Auto-add resource limits based on current usage
bash ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/hardening/profile-and-set-limits.sh

# Or add fixed limits
bash ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/hardening/add-resource-limits.sh <manifest.yaml>
```

---

## Step 2: Health Probes Audit

```bash
# Pods WITHOUT liveness probes (won't restart on deadlock)
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.metadata.namespace | test("kube-system|kyverno|gatekeeper|falco") | not) |
  select(.spec.containers[]? | .livenessProbe == null) |
  "\(.metadata.namespace)/\(.metadata.name)"' | head -20

# Pods WITHOUT readiness probes (get traffic before ready)
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.metadata.namespace | test("kube-system|kyverno|gatekeeper|falco") | not) |
  select(.spec.containers[]? | .readinessProbe == null) |
  "\(.metadata.namespace)/\(.metadata.name)"' | head -20
```

Fix:

```bash
bash ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/hardening/add-probes.sh <manifest.yaml>
```

---

## Step 3: Storage Security

```bash
# PVs with Recycle reclaim policy (deprecated, insecure)
kubectl get pv -o json | jq -r '
  .items[] | select(.spec.persistentVolumeReclaimPolicy == "Recycle") |
  "\(.metadata.name): Recycle (DEPRECATED — use Retain or Delete)"'

# PVCs in ReadWriteMany mode (potential data exposure across pods)
kubectl get pvc -A -o json | jq -r '
  .items[] | select(.spec.accessModes[]? == "ReadWriteMany") |
  "\(.metadata.namespace)/\(.metadata.name): RWX"'

# hostPath volumes (bypass all storage security)
kubectl get pods -A -o json | jq -r '
  .items[] | select(.spec.volumes[]?.hostPath != null) |
  "\(.metadata.namespace)/\(.metadata.name): hostPath \(.spec.volumes[] | select(.hostPath != null) | .hostPath.path)"'

# Unbound PVCs (potential misconfiguration)
kubectl get pvc -A --no-headers | grep -v Bound
```

---

## Step 4: LimitRange & ResourceQuota

Verify every application namespace has guardrails:

```bash
# Namespaces WITHOUT LimitRange
for NS in $(kubectl get ns --no-headers | awk '{print $1}' | grep -v -E 'kube-system|kube-public|kube-node-lease'); do
    LR=$(kubectl get limitrange -n "$NS" --no-headers 2>/dev/null | wc -l)
    RQ=$(kubectl get resourcequota -n "$NS" --no-headers 2>/dev/null | wc -l)
    if [ "$LR" -eq 0 ] || [ "$RQ" -eq 0 ]; then
        echo "$NS — LimitRange: $LR, ResourceQuota: $RQ"
    fi
done
```

> **Templates:** `02-CLUSTER-HARDENING/templates/golden-path/base/limitrange.yaml` and `resourcequota.yaml`

---

## Step 5: Deployment Strategy Audit

```bash
# Deployments with Recreate strategy (causes downtime)
kubectl get deployments -A -o json | jq -r '
  .items[] |
  select(.spec.strategy.type == "Recreate") |
  "\(.metadata.namespace)/\(.metadata.name): Recreate (downtime during updates)"'

# Deployments without PodDisruptionBudget
DEPLOYMENTS=$(kubectl get deployments -A --no-headers | awk '{print $1"/"$2}')
PDBS=$(kubectl get pdb -A -o json | jq -r '.items[] | "\(.metadata.namespace)/\(.spec.selector.matchLabels | to_entries | map(.value) | join("-"))"')

echo "=== Deployments without PDB ==="
for DEP in $DEPLOYMENTS; do
    NS=$(echo "$DEP" | cut -d/ -f1)
    echo "$PDBS" | grep -q "^${NS}/" || echo "  $DEP"
done | head -20
```

> **Template:** `02-CLUSTER-HARDENING/templates/golden-path/base/pdb.yaml`
> **Template:** `02-CLUSTER-HARDENING/templates/remediation/availability.yaml`

---

## Outputs

- Resource limits: set on all application pods
- Health probes: liveness + readiness on all application pods
- Storage: no hostPath in production, no Recycle PVs
- LimitRange/ResourceQuota: in all application namespaces
- Deployment strategies: RollingUpdate with PDBs

---

## Next

→ [12-compliance-verification.md](12-compliance-verification.md) — Final CIS pass and compliance report
