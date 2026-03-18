# Phase 3: Autonomous Fix

Source playbooks: `02-CLUSTER-HARDENING/playbooks/02-node-hardening.md`, `04-fix-manifests.md`, `05-automated-fixes.md`
Automation level: **67% autonomous (E/D-rank)**, 8% JADE (C-rank), 17% human (B-rank), 8% human-only (S-rank)

## Execution Order

```
1. Cluster-wide fixes FIRST (NetworkPolicy, LimitRange, ResourceQuota, PSS)
   — These don't modify workloads, they add guardrails around them
2. Manifest fixes SECOND (securityContext, limits, probes)
   — Per-workload changes, ArgoCD ownership check required
3. Node hardening LAST (Ansible)
   — Most dangerous, requires human approval for apply
```

## 3a: Cluster-Wide Fixes (Playbook 05)

### Service Discovery — E-rank (always first)

```bash
# CRITICAL: discover services BEFORE applying NetworkPolicy
02-CLUSTER-HARDENING/tools/hardening/fix-cluster-security.sh --discover-only

# Discovers: Vault, Prometheus, Grafana, ArgoCD, ESO, ingress, cert-manager
# Output: JSON list of services with their namespaces and ports
```

**Rule**: If discovery fails or finds 0 services, STOP. Manual inventory needed.

### NetworkPolicy — D-rank

```bash
# Phase 1A: Default-deny for all app namespaces
for ns in ${APP_NAMESPACES}; do
  # Skip system namespaces: kube-system, kube-public, kube-node-lease
  kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: $ns
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
EOF
done

# Phase 1B: Allow DNS (kube-dns/coredns)
# Phase 1C: Allow webhook servers (kyverno, gatekeeper)
# Phase 1D: Allow discovered services (Vault, Prometheus, etc.)
# Phase 1E: Allow same-namespace pod-to-pod

02-CLUSTER-HARDENING/tools/hardening/fix-cluster-security.sh \
  --phase networkpolicy \
  --namespaces ${APP_NAMESPACES}
```

**Verify**: `kubectl get pods -A | grep -E "CrashLoopBackOff|Error"` — if new crashes appear, rollback.

### LimitRange — D-rank

```bash
02-CLUSTER-HARDENING/tools/hardening/fix-cluster-security.sh \
  --phase limitrange --namespaces ${APP_NAMESPACES}

# Creates per-namespace LimitRange:
# default: cpu=250m, memory=256Mi
# defaultRequest: cpu=100m, memory=128Mi
# max: cpu=2, memory=2Gi
```

### ResourceQuota — D-rank

```bash
02-CLUSTER-HARDENING/tools/hardening/fix-cluster-security.sh \
  --phase resourcequota --namespaces ${APP_NAMESPACES}

# Creates per-namespace ResourceQuota:
# pods: 50, services: 20, count/deployments.apps: 20
# requests.cpu: 8, requests.memory: 16Gi
# limits.cpu: 16, limits.memory: 32Gi
```

### PSS Labels — E-rank

```bash
# System namespaces: enforce=privileged
# k3s: local-path-provisioner MUST be privileged (learned from Portfolio)
kubectl label ns kube-system pod-security.kubernetes.io/enforce=privileged --overwrite
kubectl label ns local-path-storage pod-security.kubernetes.io/enforce=privileged --overwrite 2>/dev/null

# App namespaces: enforce=baseline, warn=restricted
for ns in ${APP_NAMESPACES}; do
  kubectl label ns $ns \
    pod-security.kubernetes.io/enforce=baseline \
    pod-security.kubernetes.io/warn=restricted \
    --overwrite
done
```

### automountServiceAccountToken — E-rank

```bash
# Disable on all app workloads EXCEPT operators/controllers/monitoring
for ns in ${APP_NAMESPACES}; do
  for deploy in $(kubectl get deploy -n $ns -o name); do
    # Check if it's a controller/operator (skip those)
    component=$(kubectl get $deploy -n $ns -o jsonpath='{.metadata.labels.app\.kubernetes\.io/component}' 2>/dev/null)
    [ "$component" = "controller" ] || [ "$component" = "operator" ] && continue

    kubectl patch $deploy -n $ns --type=json \
      -p '[{"op":"add","path":"/spec/template/spec/automountServiceAccountToken","value":false}]'
  done
done
```

### Verify No Breakage — D-rank

```bash
# Wait 30 seconds for rollouts
sleep 30

# Check for new crashes
NEW_CRASHES=$(kubectl get pods -A --no-headers | grep -cE "CrashLoopBackOff|Error|ImagePullBackOff")
if [ "$NEW_CRASHES" -gt 0 ]; then
  echo "WARNING: $NEW_CRASHES pods in error state after cluster-wide fixes"
  kubectl get pods -A | grep -E "CrashLoopBackOff|Error|ImagePullBackOff"
  # S-RANK ESCALATION if services are broken
fi
```

## 3b: Manifest Fixes (Playbook 04)

### ArgoCD Ownership Check — E-rank (mandatory before every patch)

```bash
# For EVERY resource to be patched:
check_ownership() {
  local resource=$1 name=$2 ns=$3
  argocd_app=$(kubectl get $resource $name -n $ns -o jsonpath='{.metadata.labels.app\.kubernetes\.io/instance}' 2>/dev/null)
  if [ -n "$argocd_app" ]; then
    echo "BLOCKED: $resource/$name in $ns is managed by ArgoCD app '$argocd_app'"
    echo "Fix in git: $(kubectl get application $argocd_app -n argocd -o jsonpath='{.spec.source.repoURL}')"
    return 1
  fi
  return 0
}
```

### SecurityContext — D-rank (unmanaged workloads only)

```bash
# add-security-context.sh adds:
# runAsNonRoot: true
# allowPrivilegeEscalation: false
# readOnlyRootFilesystem: true
# capabilities: { drop: [ALL] }
# seccompProfile: { type: RuntimeDefault }

for manifest in $(find ${TARGET_REPO}/k8s -name "*.yaml" -o -name "*.yml"); do
  check_ownership deployment $(basename $manifest .yaml) default || continue
  02-CLUSTER-HARDENING/tools/hardening/add-security-context.sh $manifest
done
```

### Resource Limits — D-rank

```bash
# Profile actual usage first, then set limits
02-CLUSTER-HARDENING/tools/hardening/profile-and-set-limits.sh \
  --namespace ${NAMESPACE}

# Sets: requests = observed p95, limits = observed × 1.5 headroom
```

### Health Probes — C-rank (JADE)

```
ESCALATE to JADE:
  "Workload needs health probes. JADE: inspect service ports,
   Dockerfile EXPOSE, app code for /health endpoints."

  JADE provides: probe_type, path, port, timing values

  Then: 02-CLUSTER-HARDENING/tools/hardening/add-probes.sh \
    --port ${PORT} --path ${PATH} ${MANIFEST}
```

### ArgoCD-Managed Resources — B-rank

```
ESCALATE to human:
  "These resources are ArgoCD-managed. Must fix in git."
  Provide: resource list, ArgoCD app → git repo mapping, suggested diffs.
  Options: create PRs, human commits, accept risk.
```

## 3c: Node Hardening (Playbook 02) — B-rank

### Ansible Dry-Run — D-rank

```bash
02-CLUSTER-HARDENING/tools/hardening/harden-nodes.sh \
  --dry-run --inventory ${OUTPUT_DIR}/node-inventory.json

# Shows what will change:
# - sysctl: net.ipv4.ip_forward, vm.panic_on_oom, etc.
# - auditd: rules for /etc/kubernetes/, container runtimes
# - kubelet: --protect-kernel-defaults, --read-only-port=0, etc.
```

### Apply — B-rank (human approval required)

```
ESCALATE to human:
  "Node hardening dry-run complete. Review changes before apply."
  Provide: dry-run output, affected nodes, rollback commands.
  Recommended: canary one node first, then apply to rest.
```

## Phase 3 Gate

```
IF no new CrashLoopBackOff AND kubescape score improved:
  Continue to Phase 4
ELIF new crashes detected:
  S-rank escalation with rollback commands
ELSE:
  Report partial success, continue to Phase 4
```
