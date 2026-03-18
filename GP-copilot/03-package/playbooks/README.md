# Playbooks — Runtime Security

> Step-by-step guides for deploying and operating runtime security.
> Each playbook references the automation in `tools/`, templates in `templates/`, and watchers in `watchers/`.

---

## Engagement Flow

```
01-install-prerequisites
    ↓
02-deploy-falco ──→ 03-verify-container-hardening
    ↓                     ↓
04-tune-falco        12-dast-scan-and-fix (app is running — hit it from outside)
    ↓
05-deploy-monitoring (dashboards + alerts)
    ↓
06-enable-autonomous-agent (optional — package 04)
    ↓
07-operations (reports, dataplane health, investigating, runbooks)
    ↓
08-11: service mesh, tracing, logging, ArgoCD (as needed)
```

---

## Playbooks

### Core Runtime (every engagement)

| # | Playbook | When | Time | Type |
|---|----------|------|------|------|
| 01 | [Install Prerequisites](01-install-prerequisites.md) | Pre-engagement | ~5 min | Industry Standard |
| 02 | [Deploy Falco](02-deploy-falco.md) | Day 1 | ~10 min | Industry Standard |
| 03 | [Verify Container Hardening](03-verify-container-hardening.md) | Day 1 | ~5 min | **GP-Copilot** |
| 04 | [Tune Falco](04-tune-falco.md) | Week 2 | ~30 min | **GP-Copilot** |
| 05 | [Deploy Monitoring](05-deploy-monitoring.md) | Week 2-3 | ~10 min | Industry Standard |

### Autonomous Operations (GP-Copilot differentiator)

| # | Playbook | When | Time | Type |
|---|----------|------|------|------|
| 06 | [Enable Autonomous Agent](06-enable-autonomous-agent.md) | Week 3-4 (optional) | ~15 min | **GP-Copilot** |
| 07 | [Operations](07-operations.md) | Week 5+ | Ongoing | **GP-Copilot** |

### Observability Stack (as needed)

| # | Playbook | When | Time | Type |
|---|----------|------|------|------|
| 08 | [Deploy Service Mesh](08-deploy-service-mesh.md) | As needed | ~20 min | Industry Standard |
| 09 | [Deploy Tracing](09-deploy-tracing.md) | As needed | ~15 min | Industry Standard |
| 10 | [Deploy Logging](10-deploy-logging.md) | As needed | ~15 min | Industry Standard |
| 11 | [ArgoCD Integration](11-argocd-integration.md) | As needed | ~10 min | Industry Standard |

### Active Defense (app is running — test it)

| # | Playbook | When | Time | Type |
|---|----------|------|------|------|
| 12 | [DAST Scan and Fix](12-dast-scan-and-fix.md) | After app deploys | ~50 min | **GP-Copilot** |

### What's the difference?

**Industry Standard** = Installing Falco, deploying Prometheus dashboards, setting up Istio, EFK logging, Jaeger tracing. Any SRE team does this. We make it faster with scripts and playbooks, but the tools are commodity.

**GP-Copilot Value-Add:**

- **03 — Verify Container Hardening**: 10 watchers that cross-check 01/02 hardening against live running containers. Not just "did you set seccomp?" but "is every container in every namespace actually running with it?"
- **04 — Tune Falco**: Not just "install Falco and hope." Week 2 tuning with allowlists, custom detection rules, and noise reduction. The difference between 10,000 alerts/day (useless) and 10 alerts/day (actionable).
- **06 — Autonomous Agent**: jsa-infrasec watches Falco alerts 24/7. E/D rank incidents auto-remediated. C rank escalated to JADE for approval. No human needed for 80% of runtime threats.
- **07 — Operations**: Weekly security reports generated from Prometheus. Drift detection. Snapshot management. Not "set it and forget it" — active platform operations.
- **12 — DAST Scan and Fix**: After the app is deployed, hit it from outside. ZAP/Nuclei find runtime vulnerabilities that SAST can't see (CORS misconfig, missing headers, exposed endpoints). Then fixer scripts patch them.

---

## Prerequisites

- 01-APP-SEC already ran (code is clean)
- 02-CLUSTER-HARDENING already ran (cluster is hardened)
- kubectl configured with cluster access

---

*Ghost Protocol — Runtime Security Package (CKS)*
