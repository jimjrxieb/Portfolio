# Phase 3: Deploy Observability

Source playbooks: `03-DEPLOY-RUNTIME/playbooks/05-deploy-monitoring.md`, `09-deploy-tracing.md`
Automation level: **88% autonomous (E/D-rank)**, 12% JADE (C-rank)

## What the Agent Does

```
1. Deploy Prometheus + Alertmanager (if not present)
2. Deploy Grafana (if not present)
3. Import 6 security dashboards
4. Deploy 30 alert rules
5. Optional: OTel Collector + tracing backend
```

## Monitoring Stack — D-rank

```bash
# Check if already installed
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus 2>/dev/null
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana 2>/dev/null

# Deploy if missing
03-DEPLOY-RUNTIME/tools/deploy.sh --component prometheus  # kube-prometheus-stack
03-DEPLOY-RUNTIME/tools/deploy.sh --component grafana
```

## Dashboards — E-rank

6 dashboards, each ConfigMap-loaded into Grafana:

| Dashboard | What It Shows |
|-----------|--------------|
| `runtime-security.json` | Findings over time, MTTD, MTTF, fix success rate |
| `falco-alerts.json` | MITRE tactics pie chart, rule heatmap, alert volume |
| `jade-decisions.json` | JADE approval rate, decision latency, C-rank breakdown |
| `response-metrics.json` | Auto-fixes vs rollbacks, response time distribution |
| `log-dashboard.json` | Log volume, error rate, pipeline health |
| `tracing-dashboard.json` | Request latency, trace count, error traces |

```bash
for dashboard in runtime-security falco-alerts jade-decisions response-metrics log-dashboard tracing-dashboard; do
  kubectl create configmap grafana-dashboard-${dashboard} -n monitoring \
    --from-file=03-DEPLOY-RUNTIME/templates/monitoring/${dashboard}.json \
    --dry-run=client -o yaml | kubectl apply -f -
done
```

## Alert Rules — D-rank

30 Prometheus alert rules across 4 files:

```bash
kubectl apply -f 03-DEPLOY-RUNTIME/templates/monitoring/jsa-infrasec-alerts.yaml
kubectl apply -f 03-DEPLOY-RUNTIME/templates/monitoring/falco-alerts.yaml
kubectl apply -f 03-DEPLOY-RUNTIME/templates/monitoring/jade-alerts.yaml
kubectl apply -f 03-DEPLOY-RUNTIME/templates/monitoring/log-alerts.yaml
```

Key alerts:
| Alert | Fires When | Severity |
|-------|-----------|----------|
| FalcoSilent | Falco produces 0 events for 15 min | CRITICAL |
| CriticalMITRETactic | MITRE Impact/Exfiltration detected | CRITICAL |
| AutoFixFailureRateHigh | >20% of auto-fixes fail | HIGH |
| WatcherDown | Any watcher stops producing data | HIGH |
| RollbackRateSpike | >3 rollbacks in 1 hour | HIGH |
| JADEDown | JADE API unreachable | HIGH |
| HighEscalationRate | >50% findings escalate (tuning needed) | MEDIUM |
| LogPipelineDown | Fluent Bit not forwarding | HIGH |
| ErrorRateSpike | >5% 5xx in any service | HIGH |

## Tracing (Optional) — C-rank

```
ESCALATE to JADE:
  "Select tracing backend."
  Jaeger: standalone, good UI, mature.
  Tempo: Grafana-native, cheaper storage.
  Default: Tempo if Grafana present.
```

```bash
03-DEPLOY-RUNTIME/tools/deploy.sh --component otel-collector
03-DEPLOY-RUNTIME/tools/deploy.sh --component ${TRACING_BACKEND}
```

## Verify — D-rank

```bash
03-DEPLOY-RUNTIME/tools/health-check.sh --component monitoring

# Prometheus scraping targets
kubectl port-forward svc/prometheus -n monitoring 9090:9090 &
curl -s localhost:9090/api/v1/targets | jq '.data.activeTargets | length'

# Grafana accessible
kubectl port-forward svc/grafana -n monitoring 3000:3000 &
curl -s localhost:3000/api/health

# Alerts loaded
curl -s localhost:9090/api/v1/rules | jq '.data.groups | length'
```

## Phase 3 Gate

```
PASS if: Prometheus + Grafana + dashboards + alerts active
```
