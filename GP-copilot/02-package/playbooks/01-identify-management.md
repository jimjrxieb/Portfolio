# Playbook 01 — Identify Resource Management

## Purpose

Before fixing anything, know **who owns the resource**. Applying kubectl patches to ArgoCD-managed resources causes drift wars — ArgoCD reverts your fix on the next sync. This playbook is the first step in every 02-CLUSTER-HARDENING engagement.

## Hard Rules

These are non-negotiable. We learned them the hard way.

1. **ArgoCD-managed resource? Fix in git. Period.** Never `kubectl patch`, `kubectl edit`, or `kubectl apply` on a Deployment, Service, ConfigMap, or any resource that ArgoCD owns. Push to git, let ArgoCD sync. This includes securityContext, resource limits, labels, annotations — everything.

2. **Never run `argocd app sync --replace`.** It deletes and recreates resources including PVCs. Data loss. Use `argocd app sync --force` if needed, but prefer letting auto-sync handle it.

3. **Never kubectl label a namespace that ArgoCD manages.** ArgoCD self-heal reverts the label on the next sync. If you need to change PSA labels, change the Helm chart's namespace template and push to git.

4. **kubectl is only for resources ArgoCD doesn't manage.** Gatekeeper constraints, LimitRanges in non-ArgoCD namespaces, ClusterRoleBindings, CIS benchmark remediations — these are fair game for kubectl.

5. **Check before you patch.** Run the ownership check command below. If it returns an ArgoCD app name, stop — go to git.

6. **One Helm chart commit, one ArgoCD sync.** Don't batch unrelated fixes in one commit. If a fix breaks something, you want to revert one thing, not five.

## Decision Tree

```
Is the resource managed by a GitOps controller (ArgoCD, Flux, etc.)?
│
├── YES → Fix in git, push, let the controller sync
│   │
│   ├── ArgoCD Application?
│   │   └── Check: kubectl get applications -n argocd
│   │         → spec.source.path tells you which repo/directory owns it
│   │         → Fix in that repo's Helm chart / manifests, push, sync
│   │
│   └── Flux Kustomization?
│       └── Check: kubectl get kustomizations -A
│             → spec.sourceRef + spec.path tells you the source
│             → Fix there, push, reconcile
│
└── NO → Fix with kubectl directly
    │
    ├── Cluster-scoped resources (not in any Application)
    │   ├── Gatekeeper constraints/templates
    │   ├── PSA namespace labels
    │   ├── ClusterRoles / ClusterRoleBindings
    │   ├── NetworkPolicies (unless templated in a chart)
    │   ├── CIS benchmark remediations (API server flags, kubelet config)
    │   └── Monitoring stack config (Prometheus rules, Grafana dashboards)
    │
    └── Namespace-scoped resources not in any Application
        ├── ResourceQuotas / LimitRanges
        ├── ServiceAccounts (unless chart-created)
        └── Secrets (external-secrets-operator managed? check annotations)
```

## Quick Check Commands

### Who manages this resource?

```bash
# Check if a resource has ArgoCD tracking labels
kubectl get <resource> <name> -n <ns> -o jsonpath='{.metadata.labels.app\.kubernetes\.io/instance}'

# If it returns an ArgoCD app name → git-managed
# If empty → kubectl-owned

# Check all ArgoCD applications and what they manage
kubectl get applications -n argocd -o custom-columns='APP:.metadata.name,PATH:.spec.source.path,SYNC:.status.sync.status'

# Check all Flux kustomizations
kubectl get kustomizations -A -o custom-columns='NAME:.metadata.name,PATH:.spec.path,READY:.status.conditions[0].status'
```

### Portfolio Cluster Ownership Map (Mar 2026)

| Resource | Owner | Fix Location |
|----------|-------|-------------|
| Portfolio app (Deployment, Service, Ingress, ConfigMaps) | ArgoCD | `jimjrxieb/Portfolio.git` → `infrastructure/charts/portfolio/` |
| Gatekeeper constraints + templates | kubectl | Direct `kubectl apply` |
| PSA namespace labels (ArgoCD namespaces) | ArgoCD | Change in Helm chart `namespace.yaml`, push to git |
| PSA namespace labels (non-ArgoCD namespaces) | kubectl | `kubectl label ns` |
| ClusterRoleBindings (traefik, gatekeeper) | k3s / Helm install | kubectl (or Helm upgrade) |
| NetworkPolicies in portfolio ns | ArgoCD (if in chart) or kubectl | Check labels first |
| Falco DaemonSet | Helm (not ArgoCD) | `helm upgrade` in falco ns |
| cert-manager, external-secrets, vault | Helm (not ArgoCD) | `helm upgrade` in respective ns |
| monitoring (Prometheus, Grafana) | Helm (not ArgoCD) | `helm upgrade` in monitoring ns |

## Why This Matters

1. **Drift wars**: kubectl edit on ArgoCD resource → ArgoCD reverts on next sync → finding reappears
2. **Audit trail**: Git changes are auditable. kubectl patches are not (unless audit logging catches them)
3. **Reproducibility**: If the cluster dies, ArgoCD rebuilds from git. kubectl patches are lost
4. **Blast radius**: Knowing the owner prevents accidentally breaking a GitOps sync loop

## Lessons Learned (Portfolio Engagement, Mar 2026)

These cost us hours. Don't repeat them.

| What We Did Wrong | What Happened | Correct Approach |
|-------------------|---------------|-----------------|
| `kubectl patch deployment` to add seccompProfile | ArgoCD reverted on next sync, pods kept old spec | Push seccompProfile to Helm chart values.yaml |
| `kubectl label ns portfolio enforce=restricted` | ArgoCD self-heal reverted to `enforce=baseline` from chart | Change `namespace.yaml` template in Helm chart |
| `argocd app sync --replace` | Deleted PVCs, lost data, provisioner couldn't recreate due to PSA | Never use `--replace`. Use `--force` or let auto-sync handle it |
| kubectl patch to add resource limits on ArgoCD deployments | ArgoCD reverted fsGroup, broke ChromaDB | Push resource limits via Helm chart values |
| Multiple kubectl patches in one session | ArgoCD sync state got confused, OutOfSync on every resource | One git commit per fix, verify sync between each |

## Agent Integration

`jsa-infrasec` reads this playbook before executing any fix:
1. Check resource ownership (ArgoCD label check)
2. If git-managed → log finding, skip fix, escalate to human (B-rank)
3. If kubectl-owned → apply fix directly (E/D-rank)
4. Always verify post-fix that no ArgoCD sync conflict exists
5. **Never kubectl patch an ArgoCD-managed resource** — this is a hard stop, not a suggestion
