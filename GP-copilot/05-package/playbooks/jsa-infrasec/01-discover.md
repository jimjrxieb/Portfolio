# Phase 1: Autonomous Discovery

Source playbooks: `02-CLUSTER-HARDENING/playbooks/01-identify-management.md`, `01a-platform-quirks.md`
Automation level: **80% autonomous (E/D-rank)**, 20% human (B-rank for ArgoCD conflicts)

## What the Agent Does

```
1. Detect all ArgoCD-managed applications and namespaces
2. Build ownership map: which resources are git-managed vs kubectl-managed
3. Detect cluster platform and document constraints
4. Flag ArgoCD conflicts that block hardening
```

## Step-by-Step

### 1. ArgoCD Application Discovery

```bash
# List all ArgoCD apps
kubectl get applications.argoproj.io -A -o json \
  | jq '[.items[] | {
      name: .metadata.name,
      namespace: .spec.destination.namespace,
      repo: .spec.source.repoURL,
      path: .spec.source.path,
      sync_policy: .spec.syncPolicy
    }]' > ${OUTPUT_DIR}/argocd-apps.json
```

### 2. Ownership Map

```bash
# For every namespace:
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  argocd_app=$(kubectl get ns $ns -o jsonpath='{.metadata.labels.app\.kubernetes\.io/instance}' 2>/dev/null)
  managed=$([ -n "$argocd_app" ] && echo "true" || echo "false")
  echo "{\"namespace\": \"$ns\", \"argocd_managed\": $managed, \"argocd_app\": \"${argocd_app:-none}\"}"
done | jq -s '.' > ${OUTPUT_DIR}/ownership-map.json
```

Classification:
| Managed By | Fix Method | Example Resources |
|-----------|-----------|-------------------|
| ArgoCD | Git commit → ArgoCD sync | Deployments, Services, ConfigMaps in managed ns |
| kubectl | Direct kubectl apply | LimitRange, ResourceQuota, NetworkPolicy, Gatekeeper |
| Helm (non-ArgoCD) | helm upgrade | Standalone Helm releases |

### 3. Platform Detection

```bash
02-CLUSTER-HARDENING/tools/hardening/pre-flight-check.sh --platform-only
```

Known platforms and quirks:

| Platform | Detection | Key Constraints |
|----------|-----------|----------------|
| **k3s** | `/etc/rancher/k3s/` exists | config.yaml NOT KubeletConfiguration. local-path-provisioner needs `enforce=privileged`. |
| **EKS** | `aws-auth` ConfigMap exists | Managed node groups limit kubelet config. IRSA for service auth. |
| **AKS** | Azure labels on nodes | Limited kernel parameter access. AAD integration. |
| **kubeadm** | `/etc/kubernetes/admin.conf` | Full control but manual upgrade path. |
| **GKE** | `gke-metadata-server` daemonset | Workload Identity. GKE-specific NetworkPolicy. |

### 4. ArgoCD Conflict Detection — B-rank

If ArgoCD manages namespaces that need hardening:

```
ESCALATE to human:
  "These namespaces are ArgoCD-managed. Hardening changes must go through git."

  Provide:
  - Namespace → ArgoCD app → Git repo mapping
  - Required changes (PSS labels, securityContext, NetworkPolicy)
  - Suggested diffs for each repo
  - Option to create PRs automatically
```

## Outputs

```
${OUTPUT_DIR}/
├── argocd-apps.json       ← All ArgoCD applications
├── ownership-map.json     ← Namespace ownership (ArgoCD vs kubectl)
├── fix-strategy.json      ← Per-resource: git-fix vs kubectl-fix
└── platform-quirks.md     ← Platform constraints document
```

## Phase 1 Gate

```
PASS if: ownership map generated AND platform detected
FAIL: Cannot harden what we can't identify. Abort.
```
