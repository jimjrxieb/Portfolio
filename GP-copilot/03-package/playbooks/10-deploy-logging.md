# Playbook: Deploy Log Aggregation

> Collect, store, and search all container logs + Falco security events.
>
> **When:** After monitoring (05). Pairs with tracing (09).
> **Time:** ~15 min

---

## Architecture

```
Container stdout/stderr → /var/log/containers/*.log
Falco events            → /var/log/falco/events.log
                              ↓
                        Fluent Bit (DaemonSet)
                        ├── Parse (CRI, JSON, Docker format)
                        ├── Enrich (K8s namespace, pod, labels)
                        ├── Filter (drop health checks, noisy namespaces)
                        └── Ship → Loki
                                    ↓
                              Grafana (LogQL)
```

**Why Fluent Bit + Loki:**
- Fluent Bit: 30MB memory per node (vs Fluentd 300MB). Handles 95% of log collection use cases.
- Loki: label-indexed (cheap storage). Not full-text indexed (slower grep, but 10x cheaper than Elasticsearch).
- Both are Grafana ecosystem — same UI for metrics, traces, AND logs.

---

## Step 1: Deploy

```bash
PKG=~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME

# Full stack: Fluent Bit + Loki
bash $PKG/tools/deploy-logging.sh

# What gets deployed:
#   1. logging namespace
#   2. Loki (log storage + query engine)
#   3. Fluent Bit DaemonSet (log collection on every node)
#   4. Prometheus alerts (log-alerts.yaml)
#   5. Grafana dashboard (log-dashboard.json)
```

### Alternative: Fluent Bit only (BYO backend)

If you already have Elasticsearch, CloudWatch, or Splunk:

```bash
# Deploy collector only — edit fluent-bit-values.yaml OUTPUT section
bash $PKG/tools/deploy-logging.sh --collector-only

# Then update the output in fluent-bit-values.yaml:
# - Elasticsearch: uncomment the [OUTPUT] es block
# - CloudWatch: uncomment the [OUTPUT] cloudwatch_logs block
# - Splunk: add [OUTPUT] splunk block
```

---

## Step 2: Verify

```bash
# Check Fluent Bit runs on every node
kubectl get ds fluent-bit -n logging

# Expected: DESIRED = READY = number of nodes

# Check Loki is running
kubectl get pods -n logging -l app.kubernetes.io/name=loki

# Check Fluent Bit is shipping logs
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=10

# Should see: [output:loki:loki.0] ... (no errors)
```

---

## Step 3: Add Loki to Grafana

```bash
# If Grafana is in the cluster:
# → Settings → Data Sources → Add → Loki
# → URL: http://loki.logging:3100
# → Save & Test

# Via API:
curl -X POST http://admin:admin@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Loki",
    "type": "loki",
    "url": "http://loki.logging:3100",
    "access": "proxy",
    "isDefault": false
  }'
```

---

## Step 4: Query Logs

### LogQL basics (in Grafana → Explore → Loki)

```logql
# All logs from a namespace
{namespace="payments"}

# Error logs only
{namespace="payments"} |= "error"

# Exclude health checks
{namespace="payments"} != "healthz" != "readyz"

# JSON parsing + field filter
{namespace="payments"} | json | level="error"

# Falco security events
{source="falco"}

# Critical Falco events only
{source="falco"} | json | priority="Critical"

# Log rate (errors per minute)
rate({namespace="payments"} |= "error" [1m])

# Top error-producing pods
topk(5, sum by (pod) (rate({namespace="payments"} |= "error" [5m])))
```

### Useful queries for security

```logql
# Failed authentication attempts
{namespace="api"} |= "401" or {namespace="api"} |= "authentication failed"

# Privilege escalation attempts (from Falco)
{source="falco"} | json | rule=~".*privilege.*"

# Pod exec events (shell access)
{source="falco"} | json | rule="Terminal shell in container"

# Network policy violations
{namespace="kube-system"} |= "NetworkPolicy" |= "denied"

# OOM kills
{namespace="kube-system"} |= "OOMKilled"
```

---

## Step 5: Falco Integration

Fluent Bit reads Falco events from `/var/log/falco/events.log` and ships them to Loki with `source=falco` label.

This means you can:
1. **Search Falco events** in Grafana alongside application logs
2. **Correlate**: see what the pod was doing (app logs) when Falco fired (security event)
3. **Alert** on Falco events via LogQL alerting rules in Grafana

```logql
# Falco events timeline for a specific pod
{source="falco"} | json | output_fields_k8s_pod_name="payments-api-7d8f9"

# Correlate: app logs + falco events for same pod
{pod="payments-api-7d8f9"}  # shows both app logs and falco events
```

### Enable Falco JSON logging (if not already)

```bash
# Falco must log to /var/log/falco/events.log in JSON format
# This is set in deploy.sh:
#   --set falco.jsonOutput=true
#   --set falco.fileOutput.enabled=true
#   --set falco.fileOutput.filename=/var/log/falco/events.log

# If Falco was installed without file output:
helm upgrade falco falcosecurity/falco -n falco \
  --reuse-values \
  --set falco.fileOutput.enabled=true \
  --set falco.fileOutput.filename=/var/log/falco/events.log
```

---

## Step 6: Check Monitoring

```bash
# Verify alerts loaded
kubectl get prometheusrules -n monitoring | grep log

# Verify dashboard loaded
kubectl get configmaps -n monitoring -l grafana_dashboard=1 | grep log

# Key alerts:
#   FluentBitDown         — not running on all nodes
#   FluentBitOutputErrors — can't ship logs to Loki
#   LokiIngesterDown      — Loki not accepting writes
#   NoLogsReceived        — pipeline is dead
```

---

## Tuning

### Reduce log volume (filter noisy namespaces)

Add to `fluent-bit-values.yaml` filters:

```ini
[FILTER]
    Name    grep
    Match   kube.*
    Exclude $kubernetes['namespace_name'] kube-system

# Or exclude specific pods
[FILTER]
    Name    grep
    Match   kube.*
    Exclude $kubernetes['pod_name'] ingress-nginx
```

### Increase Loki retention

Edit `loki-values.yaml`:

```yaml
limits_config:
  retention_period: 720h    # 30 days (was 14)
```

### Scale for high volume (>50GB/day)

Switch Loki from SingleBinary to distributed mode:

```yaml
deploymentMode: SimpleScalable    # or Distributed for >500GB/day
read:
  replicas: 3
write:
  replicas: 3
backend:
  replicas: 2
```

---

## Troubleshooting

### Fluent Bit not collecting logs

```bash
# Check DaemonSet status
kubectl get ds fluent-bit -n logging

# Check pod logs for errors
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=50

# Common cause: /var/log/containers not mounted
# Fix: check volumeMounts in fluent-bit-values.yaml

# Common cause: permission denied on log files
# Fix: Fluent Bit needs to run as root (or use DAC_READ_SEARCH capability)
```

### Logs not appearing in Loki

```bash
# Check Fluent Bit output metrics
kubectl port-forward -n logging svc/fluent-bit 2020:2020
curl -s localhost:2020/api/v1/metrics | grep output

# If output_errors > 0:
# → Check Loki endpoint in fluent-bit config
# → Should be: loki.logging.svc.cluster.local:3100

# If output_proc_records > 0 but Loki is empty:
# → Check Loki ingestion rate limit
# → Increase limits_config.ingestion_rate_mb
```

### Loki disk full

```bash
# Check PVC usage
kubectl exec -n logging deploy/loki -- df -h /var/loki

# Fix: increase PVC size
kubectl edit pvc -n logging loki

# Or: reduce retention
# limits_config.retention_period: 168h  # 7 days instead of 14

# Or: switch to S3/GCS backend (unlimited storage)
```

---

## Completion Checklist

```
[ ] Fluent Bit DaemonSet running on all nodes
[ ] Loki deployed and accepting writes
[ ] Loki added as Grafana datasource
[ ] Container logs visible in Grafana (LogQL query works)
[ ] Falco events visible in Grafana ({source="falco"})
[ ] Prometheus alerts deployed (log-alerts.yaml)
[ ] Grafana dashboard imported (log-dashboard.json)
[ ] Log retention configured appropriately
[ ] Health check logs filtered out (reduce noise)
```

---

## Next Steps

- Operations → [07-operations.md](07-operations.md)
- Service mesh → [08-deploy-service-mesh.md](08-deploy-service-mesh.md) (if not done)
- Tracing → [09-deploy-tracing.md](09-deploy-tracing.md) (if not done)

---

*Ghost Protocol — Runtime Security Package (CKS)*
