# Playbook: Deploy Falco

> Deploy Falco + falco-exporter for runtime threat detection. Observe-only mode — no auto-fix yet.
>
> **When:** Day 1, after prerequisites installed.
> **Time:** ~10 min

---

## Step 1: Deploy Falco + falco-exporter

```bash
PKG=~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME

# Default (Falco + falco-exporter only)
bash $PKG/tools/deploy.sh

# Preview without applying
bash $PKG/tools/deploy.sh --dry-run
```

This does:
1. `helm install falco` (eBPF driver, JSON output to stdout)
2. `helm install falco-exporter` (exposes `falco_alerts_total` metric for Prometheus)
3. Runs `health-check.sh` to verify

### With jsa-infrasec (optional — requires package 04-JSA-AUTONOMOUS)

```bash
bash $PKG/tools/deploy.sh --with-jsa
bash $PKG/tools/deploy.sh --with-jsa --values $PKG/templates/deployment-configs/aws-eks.yaml
```

When `--with-jsa` is passed, Falco's httpOutput forwards alerts to jsa-infrasec webhook. Without it, alerts go to stdout + Prometheus via falco-exporter.

### Deployment configs (for --with-jsa)

| Config | Cloud | Use Case |
|--------|-------|----------|
| `templates/deployment-configs/aws-eks.yaml` | AWS | EKS production |
| `templates/deployment-configs/azure-aks.yaml` | Azure | AKS production |
| `templates/deployment-configs/gcp-gke.yaml` | GCP | GKE production |
| `templates/deployment-configs/on-prem.yaml` | None | Self-hosted K8s |
| `templates/deployment-configs/minimal.yaml` | Any | Dev/test, PoC |
| `templates/deployment-configs/full-featured.yaml` | Any | Enterprise max |

### Container Toolkit (Scenario C)

```bash
kubectl apply -f $PKG/templates/deployment-configs/toolbox-pod.yaml
kubectl exec -it runtime-toolkit -n gp-security -- deploy.sh
kubectl exec -it runtime-toolkit -n gp-security -- deploy.sh --dry-run
```

---

## Step 2: Verify Deployment

```bash
bash $PKG/tools/health-check.sh
```

Expected output:
```
✓  kubectl — your-cluster-context
✓  daemonset — 3/3 Falco pods Running
✓  rules configmap — 2 Falco configmap(s) found
✓  deployment — 1/1 falco-exporter pods Running
✓  metrics service — service exists (exposes falco_alerts_total)
ℹ  jsa-infrasec — not deployed — this is optional (package 04-JSA-AUTONOMOUS)
```

Manual checks:
```bash
# Check Falco is firing alerts
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=50

# Check falco-exporter is scraping
kubectl logs -n falco -l app.kubernetes.io/name=falco-exporter --tail=20

# Verify Prometheus can scrape falco-exporter
kubectl port-forward -n falco svc/falco-exporter 9376:9376 &
curl -s http://localhost:9376/metrics | grep falco_events
```

---

## Week 1 Goal

Let it run in **observe-only mode**. Collect baseline — how many alerts per day, which rules are noisiest. Read alerts via `kubectl logs` and Grafana dashboards.

---

## Next Steps

- Verify container hardening → [03-verify-container-hardening.md](03-verify-container-hardening.md)
- Tune Falco → [04-tune-falco.md](04-tune-falco.md)

---

*Ghost Protocol — Runtime Security Package (CKS)*
