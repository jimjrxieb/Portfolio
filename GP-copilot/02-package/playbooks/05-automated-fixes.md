# Playbook: Automated Cluster Fixes

> Run fix-cluster-security.sh to remediate the most common cluster findings in one shot.
>
> **When:** After the initial cluster audit (01-cluster-audit). Before manual manifest fixes.
> **Time:** ~10 min (dry-run + apply + verify)

---

## The Rule

This script fixes cluster-wide issues that don't require per-manifest changes: missing NetworkPolicies, missing LimitRanges/ResourceQuotas, and missing PSS labels. One command, all namespaces.

**Critical improvement (Mar 2026):** The script now auto-detects cluster services before applying NetworkPolicies. It discovers Vault, Prometheus, Grafana, ArgoCD, External Secrets, and ingress controllers, then generates service-aware allow rules alongside the default-deny. This prevents the script from breaking cross-namespace service communication.

---

## Step 1: Dry Run

Always preview before applying:

```bash
PKG=~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING

# Scenario A (from your rig):
bash $PKG/tools/hardening/fix-cluster-security.sh --dry-run

# Scenario C (from toolkit pod):
kubectl exec cluster-toolkit -n gp-security -- fix-cluster-security.sh --dry-run
```

Review the output. It shows:
- Every namespace and what would be applied
- **Discovered services** and what allow rules will be generated
- Which namespaces are skipped and why

---

## Step 2: Apply

```bash
bash $PKG/tools/hardening/fix-cluster-security.sh
```

### How It Works

The script runs in phases:

#### Section 0: Service Discovery (read-only)

Before touching any NetworkPolicies, the script scans the cluster for known services:

| Service | Detection Method | Why It Matters |
|---------|-----------------|----------------|
| **Vault** | Label `app.kubernetes.io/name=vault` or service named `vault` | Other namespaces need egress to Vault for secret injection |
| **Prometheus** | Label `app.kubernetes.io/name=prometheus` or `app=prometheus` | Needs egress to scrape metrics from all namespaces |
| **Grafana** | Label `app.kubernetes.io/name=grafana` | Needs egress to query Prometheus |
| **ArgoCD** | Label `app.kubernetes.io/part-of=argocd` or `argocd-server` service | Needs egress to Git repos, registries, K8s API |
| **External Secrets** | Label `app.kubernetes.io/name=external-secrets` | Needs egress to Vault + K8s API for token review |
| **Ingress Controller** | Labels for Traefik, Nginx, or Envoy | Identified for documentation |

Discovery is best-effort — if a service uses non-standard labels, it may not be detected. The `--dry-run` output shows exactly what was found.

#### Section 1: NetworkPolicy (4 phases)

| Phase | What It Does | Skips |
|-------|-------------|-------|
| **1A: Default-deny + DNS** | `default-deny-all` + `allow-dns-egress` on every namespace missing policies | kube-system (CNI manages its own) |
| **1B: Webhook policies** | Ingress on 443/8443/9443 + API server egress for admission controllers | Only applies to gatekeeper-system and cert-manager |
| **1C: Service-aware rules** | Allow rules for discovered services (vault ingress, prometheus scraping, argocd git egress, etc.) | Only applies when services are detected |
| **1D: Same-namespace** | `allow-same-namespace` ingress + egress for pods within the same namespace | Only applies to namespaces that got default-deny |

**Why this order matters:** Default-deny goes first (zero-trust baseline), then service-specific allow rules open exactly what's needed. Without Phase 1C, default-deny breaks Vault, Prometheus, ArgoCD, and External Secrets.

#### Section 2-4: Resource Management + PSS + cert-manager

| Category | What It Does | Skips |
|----------|-------------|-------|
| **Resource limits** | LimitRange + ResourceQuota on application namespaces | System namespaces (kube-system, kube-public, kube-node-lease, gatekeeper-system) |
| **PSS labels** | `baseline` on infrastructure namespaces, `restricted` on application namespaces | Falco (requires host access) |
| **cert-manager** | Resource limits on cert-manager deployments | — |

### What It Documents (No Changes)

These get logged but not modified — they're legitimate and would break the cluster:
- RBAC wildcard ClusterRoles (CAPI, EKS-A, etcdadm controllers)
- kube-system static pods (etcd, apiserver, scheduler — managed by kubelet)
- CNI pods (cilium — requires host network + privileges by design)

### Selective Application

```bash
# Skip sections that don't apply
bash $PKG/tools/hardening/fix-cluster-security.sh --skip-netpol       # No NetworkPolicy
bash $PKG/tools/hardening/fix-cluster-security.sh --skip-limits       # No LimitRange/ResourceQuota
bash $PKG/tools/hardening/fix-cluster-security.sh --skip-pss          # No PSS labels
bash $PKG/tools/hardening/fix-cluster-security.sh --skip-certmgr      # No cert-manager patches
```

---

## Step 3: Verify

```bash
# Re-run the cluster audit
bash $PKG/tools/hardening/run-cluster-audit.sh \
  --output ~/GP-copilot/GP-S3/5-consulting-reports/<client>/k8s-audit-post-fix-$(date +%Y%m%d).md
```

**Expected improvements (real example — portfolioserver):**

| Metric | Before | After |
|--------|--------|-------|
| NetworkPolicies | 8 | 30+ |
| LimitRanges | 0 | 7 |
| ResourceQuotas | 1 | 8 |
| PSS-labeled namespaces | 2 | 11 |
| Namespaces without NetworkPolicy | 9 | 1 |
| Cross-namespace services broken | N/A | 0 |

Note: Existing pods need restart to pick up LimitRange defaults. New pods get them automatically.

---

## Step 4: Profile and Set Right-Sized Limits

LimitRange gives defaults to NEW pods. Existing pods (Helm-installed workloads like ArgoCD, monitoring, vault) need explicit patches. Use the profiler:

```bash
PKG=~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING

# Dry run — shows actual usage vs current limits, calculates right-sized values
bash $PKG/tools/hardening/profile-and-set-limits.sh --dry-run

# Apply — patches workloads with 2x headroom over observed usage
bash $PKG/tools/hardening/profile-and-set-limits.sh

# Custom headroom (3x for bursty workloads)
bash $PKG/tools/hardening/profile-and-set-limits.sh --headroom 3

# Single namespace
bash $PKG/tools/hardening/profile-and-set-limits.sh --namespace monitoring
```

The profiler:
1. Reads `kubectl top pods` for actual CPU/memory usage
2. Sets **requests** = observed usage (floor: 50m/64Mi)
3. Sets **limits** = observed x headroom multiplier (floor: 100m/128Mi)
4. Applies LimitRange to namespaces missing one
5. Patches Deployment/StatefulSet/DaemonSet workloads without limits

---

## Step 5: Restart Pods to Pick Up Defaults

LimitRange only applies to new pods. Existing pods keep their current (missing) limits until restarted:

```bash
# Restart deployments in a namespace to pick up LimitRange defaults
kubectl rollout restart deployment -n <namespace>

# Or restart all non-system deployments
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v kube-); do
  kubectl rollout restart deployment -n "$ns" 2>/dev/null
done
```

---

## Troubleshooting

### Service not detected

If a service uses non-standard labels, the auto-detection won't find it. Check what was discovered in the `--dry-run` output. If a service is missing, you have two options:

1. **Add standard labels** to the service (preferred):
   ```bash
   kubectl label svc <name> -n <ns> app.kubernetes.io/name=<service-name>
   ```

2. **Manually add allow rules** after the script runs:
   ```bash
   # Example: custom service on port 9200 needs ingress from all namespaces
   kubectl apply -n <ns> -f - <<EOF
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: allow-custom-service-ingress
   spec:
     podSelector:
       matchLabels:
         app: <service-label>
     policyTypes: [Ingress]
     ingress:
     - from:
       - namespaceSelector: {}
       ports:
       - port: 9200
         protocol: TCP
   EOF
   ```

### Service broken after script ran

If a service stops working after applying policies, check which namespace it's in and what rules were applied:

```bash
# List all policies in the affected namespace
kubectl get networkpolicy -n <namespace>

# Check if the service needs cross-namespace access that wasn't detected
kubectl describe networkpolicy -n <namespace>

# Quick fix: add egress to the specific service
kubectl apply -n <source-namespace> -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-<service>-egress
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: <target-namespace>
    ports:
    - port: <port>
      protocol: TCP
EOF
```

### Rollback all NetworkPolicies

If things go sideways, remove all policies applied by this script:

```bash
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  kubectl get networkpolicy -n "$ns" -o json 2>/dev/null | \
    jq -r '.items[] | select(.metadata.annotations["applied-by"] == "fix-cluster-security.sh") | .metadata.name' | \
    while read name; do
      kubectl delete networkpolicy "$name" -n "$ns"
    done
done
```

All policies applied by this script have the annotation `applied-by: fix-cluster-security.sh`, making targeted rollback possible.

---

## Next Steps

- Fix individual manifests? → [04-fix-manifests.md](04-fix-manifests.md)
- Deploy admission control? → [05-deploy-admission-control.md](05-deploy-admission-control.md)
- Wire CI/CD? → [06-wire-cicd.md](06-wire-cicd.md)

---

*Ghost Protocol — K8s Hardening Package (CKA + CKS)*
