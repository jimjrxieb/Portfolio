# Playbook: Deploy Distributed Tracing

> See how requests flow through your services. Find latency bottlenecks.
>
> **When:** After monitoring (05) is deployed. Before production traffic.
> **Time:** ~15 min

---

## Architecture

```
Your App (OTel SDK)
  ↓ OTLP (gRPC :4317 or HTTP :4318)
OTel Collector (DaemonSet, every node)
  ↓ exports traces
Jaeger or Tempo (storage + query)
  ↓ visualized in
Grafana (trace search, service map)
```

**OTel Collector is the hub.** Apps send traces to the local collector. The collector enriches with K8s metadata, samples, batches, and exports to the backend. Switch backends without changing app code.

---

## Step 1: Deploy

```bash
PKG=~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME

# Option A: Jaeger (built-in UI, good for dev + small prod)
bash $PKG/tools/deploy-tracing.sh --backend jaeger

# Option B: Tempo (cheaper at scale, uses Grafana for UI)
bash $PKG/tools/deploy-tracing.sh --backend tempo

# What gets deployed:
#   1. observability namespace
#   2. OTel Collector DaemonSet (receives traces on every node)
#   3. Jaeger or Tempo (trace storage + query)
#   4. Prometheus alerts (tracing-alerts.yaml)
#   5. Grafana dashboard (tracing-dashboard.json)
```

---

## Step 2: Instrument Your Apps

Apps need to send traces using the OpenTelemetry SDK. Set these env vars in your Deployment:

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://otel-collector.observability:4317"
  - name: OTEL_SERVICE_NAME
    value: "my-service"
  - name: OTEL_TRACES_SAMPLER
    value: "parentbased_traceidratio"
  - name: OTEL_TRACES_SAMPLER_ARG
    value: "0.1"    # 10% sampling
```

### Language-specific setup

**Python (FastAPI/Flask):**
```bash
pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-bootstrap -a install
```
```python
# Add to startup
from opentelemetry.instrumentation.auto_instrumentation import sitecustomize
# Or: opentelemetry-instrument python app.py
```

**Node.js:**
```bash
npm install @opentelemetry/auto-instrumentations-node
```
```javascript
// tracing.js (require before anything else)
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const sdk = new NodeSDK({ instrumentations: [getNodeAutoInstrumentations()] });
sdk.start();
```

**Go:**
```go
// Use go.opentelemetry.io/otel + contrib packages
// See: https://opentelemetry.io/docs/languages/go/getting-started/
```

**Java (Spring Boot):**
```bash
# Add the OTel Java agent
java -javaagent:opentelemetry-javaagent.jar -jar app.jar
```

---

## Step 3: Verify

```bash
# Check OTel Collector is running on all nodes
kubectl get ds otel-collector -n observability

# Check backend is running
kubectl get pods -n observability

# View traces
# Jaeger:
kubectl port-forward -n observability svc/jaeger-query 16686:16686
# → http://localhost:16686

# Tempo (via Grafana):
# Add Tempo datasource in Grafana → http://tempo.observability:3200
# Explore → Tempo → Search
```

### Generate a test trace

```bash
# Send a test span to the collector
kubectl run otel-test --rm -it --image=curlimages/curl -- \
  curl -X POST http://otel-collector.observability:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"test-service"}}]},"scopeSpans":[{"spans":[{"traceId":"01020304050607080102030405060708","spanId":"0102030405060708","name":"test-span","kind":1,"startTimeUnixNano":"1700000000000000000","endTimeUnixNano":"1700000001000000000"}]}]}]}'
```

---

## Step 4: Check Monitoring

```bash
# Verify alerts loaded
kubectl get prometheusrules -n monitoring | grep tracing

# Verify dashboard loaded
kubectl get configmaps -n monitoring -l grafana_dashboard=1 | grep tracing

# Key alerts:
#   OTelCollectorDown        — collector pods not running
#   OTelCollectorDroppingSpans — backend unreachable
#   NoTracesReceived         — no apps sending traces
#   JaegerQuerySlow          — trace search performance degraded
```

---

## Tuning

### Sampling rate

The collector samples 10% of traces by default. Adjust in `otel-collector.yaml`:

```yaml
# Lower sampling = less storage, less cost
probabilistic_sampler:
  sampling_percentage: 1    # 1% for high-volume production

# Higher sampling = better debugging
probabilistic_sampler:
  sampling_percentage: 100  # 100% for debugging (temporary!)
```

### Retention

**Jaeger:** `--memory.max-traces=50000` in values (in-memory mode). For persistent storage, switch to Elasticsearch or Cassandra.

**Tempo:** `compactor.compaction.block_retention: 336h` (14 days). Increase for compliance, decrease for cost.

---

## Troubleshooting

### No traces appearing

```bash
# 1. Check OTel Collector logs
kubectl logs -n observability -l app=otel-collector --tail=50

# 2. Verify app is sending to the right endpoint
# Should be: otel-collector.observability:4317 (gRPC) or :4318 (HTTP)

# 3. Check the collector received spans
kubectl port-forward -n observability svc/otel-collector 9090:9090
curl -s localhost:9090/metrics | grep otelcol_receiver_accepted_spans

# 4. If receiver shows spans but backend is empty:
# → Check exporter config (jaeger vs tempo endpoint)
# → Check backend is running
```

### High memory on OTel Collector

```bash
# Increase memory limit in otel-collector.yaml:
resources:
  limits:
    memory: 1Gi    # was 512Mi

# Or reduce batch size:
batch:
  send_batch_size: 512    # was 1024
```

---

## Completion Checklist

```
[ ] OTel Collector DaemonSet running on all nodes
[ ] Trace backend deployed (Jaeger or Tempo)
[ ] At least one app instrumented and sending traces
[ ] Test trace visible in Jaeger UI or Grafana
[ ] Prometheus alerts deployed (tracing-alerts.yaml)
[ ] Grafana dashboard imported (tracing-dashboard.json)
[ ] Sampling rate appropriate for environment
```

---

## Next Steps

- Deploy logging → [10-deploy-logging.md](10-deploy-logging.md)
- Operations → [07-operations.md](07-operations.md)

---

*Ghost Protocol — Runtime Security Package (CKS)*
