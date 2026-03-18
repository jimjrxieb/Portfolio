# Observability Templates

> Distributed tracing and log aggregation for runtime workloads.

---

## Tracing Stack

```
Apps (OTLP SDK) → OTel Collector (DaemonSet) → Jaeger or Tempo → Grafana
```

| File | What It Does |
|------|-------------|
| `otel-collector.yaml` | OTel Collector DaemonSet (receives traces + metrics via OTLP) |
| `jaeger-values.yaml` | Jaeger all-in-one (trace storage + query UI) |
| `tempo-values.yaml` | Grafana Tempo (trace storage via S3/GCS, cheaper at scale) |

### Which backend?

| | Jaeger | Tempo |
|---|--------|-------|
| **UI** | Built-in (port 16686) | Grafana only |
| **Storage** | In-memory / Elasticsearch | S3 / GCS / local |
| **Cost at scale** | Higher (needs ES cluster) | Lower (object storage) |
| **Best for** | Dev, small prod | Large prod, Grafana shops |

---

## Logging Stack

```
Container logs → Fluent Bit (DaemonSet) → Loki → Grafana
Falco alerts  → Fluent Bit → Loki → Grafana (searchable security events)
```

| File | What It Does |
|------|-------------|
| `fluent-bit-values.yaml` | Fluent Bit DaemonSet (log collection + K8s enrichment + Falco integration) |
| `loki-values.yaml` | Grafana Loki (log storage, label-indexed, LogQL queries) |

---

## Quick Start

```bash
# Deploy tracing
bash tools/deploy-tracing.sh --backend jaeger

# Deploy logging
bash tools/deploy-logging.sh --backend loki

# Both share Grafana for visualization
```

---

## Monitoring for the Observability Stack

Alert rules and dashboards in `../monitoring/`:

| File | What It Monitors |
|------|-----------------|
| `tracing-alerts.yaml` | OTel Collector health, span drop rate, backend errors |
| `tracing-dashboard.json` | Trace ingestion rate, exporter health, sampling rate |
| `log-alerts.yaml` | Fluent Bit health, log drop rate, Loki errors |
| `log-dashboard.json` | Log ingestion rate, top namespaces, error log rate |

---

*Ghost Protocol — Runtime Security Package (CKS)*
