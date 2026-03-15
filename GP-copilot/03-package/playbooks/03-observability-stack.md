# Playbook 03: Observability Stack

> Derived from [GP-CONSULTING/03-DEPLOY-RUNTIME/playbooks/05-deploy-monitoring.md + 09-deploy-tracing.md + 10-deploy-logging.md](https://github.com/jimjrxieb/GP-copilot)
> Tailored for the Portfolio k3s cluster (portfolioserver)

## What This Does

Deploys the three pillars of observability: metrics (Prometheus + Grafana), logs (Fluent Bit + Loki), and traces (OTel + Jaeger/Tempo). Combined with Falco alerts, this gives full visibility into what's happening at every layer.

## What's Already Running on Portfolio

| Component | Namespace | Status | Purpose |
|-----------|-----------|--------|---------|
| **Prometheus** | monitoring | Deployed | Metrics collection + alerting |
| **Grafana** | monitoring | Deployed | Dashboards + visualization |
| **Falco** | — | Planned (this package) | Runtime syscall monitoring |
| **Loki** | — | Not deployed | Log aggregation |
| **OTel/Jaeger** | — | Not deployed | Distributed tracing |

## Metrics (Prometheus + Grafana)

Already operational. Key metrics for security:

```promql
# Falco alert rate (after deployment)
rate(falco_alerts_total[5m])

# ArgoCD sync failures
argocd_app_sync_total{phase="Error"}

# Pod restart rate (crash loops indicate issues)
rate(kube_pod_container_status_restarts_total[1h]) > 3

# OOM kills
kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}
```

### Grafana Dashboards (GP-Enhanced)

| Dashboard | Panels | What It Shows |
|-----------|--------|-------------|
| Runtime Security | 12 | Falco findings by namespace, severity, MITRE tactic |
| Falco Alerts | 10 | Top noisy rules, alert trends, namespace heatmap |
| Response Metrics | 6 | Auto-fix success rate, rollback rate, response time |

## Logs (Fluent Bit + Loki)

```
Container stdout/stderr → Fluent Bit (DaemonSet, 30MB/node)
  → Enriches with K8s labels (namespace, pod, container)
  → Ships to Loki (label-indexed storage)
  → Query via Grafana (LogQL)
```

**Why Loki over Elasticsearch:** 10x cheaper, label-indexed (no full-text), integrates natively with Grafana. Good enough for security log correlation.

**LogQL examples for Portfolio:**
```logql
{namespace="portfolio"} |= "error"                    # All errors
{namespace="portfolio", container="api"} | json        # Parsed API logs
{source="falco"} | json | priority="Critical"         # Falco critical events
rate({namespace="portfolio"} |= "error" [1m])          # Error rate/min
```

## Traces (OTel + Jaeger)

```
FastAPI (auto-instrumented) → OTel Collector (DaemonSet)
  → Jaeger (trace storage) → Grafana (visualization)
```

**What tracing shows for Portfolio:**
- User query → API receives → RAG lookup (ChromaDB) → LLM call (Claude) → response
- Latency breakdown per hop
- Where errors occur in the chain

## NIST Alignment

| Control | What Observability Provides |
|---------|---------------------------|
| AU-2 (Audit Events) | Falco + K8s audit logs capture security-relevant events |
| AU-6 (Audit Review) | Grafana dashboards for weekly review |
| SI-4 (System Monitoring) | Falco + Prometheus alerts for real-time detection |
| CA-7 (Continuous Monitoring) | Always-on metrics, logs, traces |
