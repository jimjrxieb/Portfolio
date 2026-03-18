# Runtime Security Engagement Guide

> Deploy Falco + falco-exporter for runtime threat detection on a client Kubernetes cluster.
> This is the continuous monitoring layer — runs 24/7 after 02-CLUSTER-HARDENING hardens the cluster config.
> jsa-infrasec autonomous agent is opt-in via `--with-jsa` (see package 04-JSA-AUTONOMOUS).

---

## What This Package Does

```
┌──────────────────────────────────────────────────────────────────┐
│               RUNTIME SECURITY STACK                              │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Falco (DaemonSet on every node)                                 │
│  └─ Watches syscalls, K8s audit, container activity              │
│  └─ JSON output → kubectl logs + falco-exporter                  │
│                                                                   │
│  falco-exporter (Deployment in falco namespace)                  │
│  └─ Scrapes Falco gRPC → exposes falco_alerts_total metric       │
│  └─ Prometheus scrapes → Grafana dashboards + alerting           │
│                                                                   │
│  [OPTIONAL] jsa-infrasec (--with-jsa, package 04)                │
│  └─ Receives Falco alerts via httpOutput webhook                 │
│  └─ Classifies E/D/C/B rank, auto-fixes E/D, JADE approves C   │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

**Engagement flow:** Prerequisites → Deploy Falco → Verify → Tune → Monitor → (Optional) Autonomous Agent → 24/7 Ops

**Relationship to other packages:**
- **01-APP-SEC** already ran → code is clean before deploy
- **02-CLUSTER-HARDENING** already ran → cluster is hardened (Kyverno + CIS)
- **03-DEPLOY-RUNTIME** = the always-on watchdog that catches what slips through
- **04-JSA-AUTONOMOUS** (optional) = autonomous agent that acts on Falco alerts

---

## Engagement Timeline

| Phase | Playbook | When | What Happens |
|-------|----------|------|-------------|
| 0 | [01-install-prerequisites](playbooks/01-install-prerequisites.md) | Pre | Install kubectl, helm, jq, yq |
| 1 | [02-deploy-falco](playbooks/02-deploy-falco.md) | Day 1 | Deploy Falco + falco-exporter, observe-only |
| 1b | [03-verify-container-hardening](playbooks/03-verify-container-hardening.md) | Day 1 | Verify 01/02 hardening on running containers |
| 2 | [04-tune-falco](playbooks/04-tune-falco.md) | Week 2 | Reduce false positives, load detection rules |
| 3 | [05-deploy-monitoring](playbooks/05-deploy-monitoring.md) | Week 2-3 | Dashboards + Prometheus alerts |
| 4 | [06-enable-autonomous-agent](playbooks/06-enable-autonomous-agent.md) | Week 3-4 | Progressive E → D → C auto-fix (optional) |
| 5 | [07-operations](playbooks/07-operations.md) | Week 5+ | Weekly reports, investigating, snapshots |

---

## The 4 C's — Where This Package Fits

```
┌─────────────────────────────────────────────────────────────────────┐
│  CLOUD        06-CLOUD-SECURITY                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  CLUSTER   02-CLUSTER-HARDENING                              │    │
│  │  ┌─────────────────────────────────────────────────────┐     │    │
│  │  │  CONTAINER  01 (image) + 02 (contexts) + 03 (verify) │     │    │
│  │  │  ┌─────────────────────────────────────────────┐    │     │    │
│  │  │  │  CODE      01-APP-SEC (SAST, secrets, SCA)  │    │     │    │
│  │  │  └─────────────────────────────────────────────┘    │     │    │
│  │  └─────────────────────────────────────────────────────┘     │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

| Concern | Defined In | Verified By |
|---------|-----------|-------------|
| Image scanning (CVEs) | 01-APP-SEC | CI pipeline |
| Dockerfile best practices | 01-APP-SEC/fixers/dockerfile/ | CI pipeline |
| Security contexts | 02-CLUSTER-HARDENING/tools/hardening/ | **03** `verify-container-hardening.sh` |
| Admission control | 02-CLUSTER-HARDENING/templates/policies/ | Kyverno/Gatekeeper |
| Runtime threat detection | **03-DEPLOY-RUNTIME** (Falco) | Falco + dashboards |

---

## Quick Reference — All Commands

```bash
PKG=~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME

# Prerequisites
bash $PKG/tools/install-prerequisites.sh

# Deploy
bash $PKG/tools/deploy.sh                                                    # Falco only
bash $PKG/tools/deploy.sh --with-jsa --values $PKG/templates/deployment-configs/aws-eks.yaml
bash $PKG/tools/deploy.sh --dry-run

# Verify
bash $PKG/tools/health-check.sh
bash $PKG/tools/verify-container-hardening.sh --skip-system --fix-hints

# Tune Falco
bash $PKG/tools/tune-falco.sh --show-top
bash $PKG/tools/tune-falco.sh --add-allowlist $PKG/templates/falco-rules/allowlist.yaml
for rule in mitre-mappings crypto-mining data-exfiltration privilege-escalation persistence; do
  bash $PKG/tools/tune-falco.sh --add-allowlist $PKG/templates/falco-rules/${rule}.yaml
done

# Monitoring
kubectl apply -f $PKG/templates/monitoring/falco-alerts.yaml
kubectl apply -f $PKG/templates/monitoring/jsa-infrasec-alerts.yaml       # if --with-jsa
kubectl apply -f $PKG/templates/monitoring/jade-alerts.yaml               # if package 05

# Test & debug
bash $PKG/tools/test-rollback.sh
bash $PKG/tools/replay-alert.sh --type shell-spawn
bash $PKG/tools/debug-finding.sh --latest

# Reports
python3 $PKG/tools/generate-report.py --format markdown --output weekly.md

# Container toolkit
kubectl apply -f $PKG/templates/deployment-configs/toolbox-pod.yaml
kubectl exec -it runtime-toolkit -n gp-security -- bash
```

---

## All Tools

| Tool | Purpose | JSA Required? |
|------|---------|---------------|
| `install-prerequisites.sh` | Install kubectl, helm, jq, yq, Python | No |
| `deploy.sh` | Deploy Falco + falco-exporter (+ jsa with --with-jsa) | No |
| `health-check.sh` | Verify all components healthy | No |
| `verify-container-hardening.sh` | Verify 01/02 hardening on running containers | No |
| `tune-falco.sh` | Show noisy rules, apply allowlists, load rules | No |
| `generate-report.py` | Weekly security reports from Prometheus | No |
| `test-rollback.sh` | Verify snapshot/rollback safety net | No |
| `replay-alert.sh` | Send test alerts through pipeline | Yes |
| `debug-finding.sh` | Investigate specific findings | Yes |
| `snapshot-browser.sh` | List, restore, cleanup snapshots | Yes |
| `docker-build.sh` | Build + tag + push container image | No |

---

*Ghost Protocol — Runtime Security Package (CKS)*
