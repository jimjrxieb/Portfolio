# Playbook 04: ArgoCD Security Integration

> Derived from [GP-CONSULTING/03-DEPLOY-RUNTIME/playbooks/11-argocd-integration.md](https://github.com/jimjrxieb/GP-copilot)
> Tailored for the Portfolio k3s cluster (portfolioserver)

## What This Does

Wires runtime security into ArgoCD's sync lifecycle. Before ArgoCD deploys, a PreSync gate validates manifests against OPA policies. After ArgoCD deploys, a PostSync hook verifies Falco is healthy and no critical alerts fired.

## How It Works on Portfolio

```
Developer pushes to main
  → GitHub Actions builds + scans (01-APP-SEC)
  → update-image-tags commits new Helm values
  → ArgoCD detects change
  → PreSync: Conftest validates rendered manifests
  → Sync: Rolling update applies
  → PostSync: Verify Falco healthy, no critical alerts, pods non-root
```

## PreSync Gate (Policy Validation)

Before ArgoCD applies any changes, a PreSync Job runs:

```bash
helm template portfolio charts/portfolio/ | conftest test --policy policies/ -
```

**Blocks deployment if:**
- Privileged container in manifest
- Missing runAsNonRoot
- `:latest` image tag
- Missing resource limits
- HostPath volume mount

## PostSync Verification

After ArgoCD applies, a PostSync Job checks:

| Check | Expected | If Failed |
|-------|----------|-----------|
| Falco DaemonSet | All nodes running | App marked Degraded |
| falco-exporter | 1 pod Running | Metrics gap |
| No critical Falco alerts in last 90s | 0 | Investigate new deployment |
| All pods runAsNonRoot | true | Security context missing |
| No privileged containers | 0 | Policy bypass |

## ArgoCD CLI (Installed on Server)

```bash
# Check current state
argocd app get portfolio

# Force sync (when auto-sync is slow)
argocd app sync portfolio

# View what changed
argocd app diff portfolio

# Rollback if needed
argocd app history portfolio
argocd app rollback portfolio <revision>
```

## Sync Wave Configuration

Falco deploys before application workloads:

```yaml
# Falco: sync-wave -2 (deploys first)
# falco-exporter: sync-wave -1 (metrics ready)
# Application: sync-wave 0 (deploys after Falco healthy)
```

ArgoCD ensures monitoring is running before your app serves traffic.
