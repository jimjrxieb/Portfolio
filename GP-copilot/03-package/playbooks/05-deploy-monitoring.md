# Playbook: Deploy Monitoring

> Dashboards + alerts so you can see what Falco is catching.
>
> **When:** Week 2-3, after Falco is tuned.
> **Time:** ~10 min

---

## Step 1: Deploy Prometheus Alert Rules

```bash
PKG=~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME

# Falco alerts (core — always deploy)
kubectl apply -f $PKG/templates/monitoring/falco-alerts.yaml           # 5 alerts

# jsa-infrasec alerts (only if --with-jsa was used)
kubectl apply -f $PKG/templates/monitoring/jsa-infrasec-alerts.yaml   # 8 alerts

# JADE alerts (only if package 05-JADE-SRE is deployed)
kubectl apply -f $PKG/templates/monitoring/jade-alerts.yaml            # 4 alerts
```

| Alert Rule File | Alerts | When to Deploy | Examples |
|-----------------|--------|----------------|----------|
| `falco-alerts.yaml` | 5 | Always | FalcoSilent, CriticalMITRETactic, FalcoPodNotRunning |
| `jsa-infrasec-alerts.yaml` | 8 | With `--with-jsa` | AutoFixFailureRateHigh, WatcherDown, RollbackRateSpike |
| `jade-alerts.yaml` | 4 | With package 05 | JADEDown, HighEscalationRate, JADEDecisionTimeout |

**Note:** `falco-alerts.yaml` references the `falco_alerts_total` metric from falco-exporter.

---

## Step 2: Import Grafana Dashboards

### Via ConfigMap (auto-discovery)

```bash
# Core dashboards (always)
kubectl create configmap grafana-dashboards \
  --from-file=$PKG/templates/monitoring/runtime-security.json \
  --from-file=$PKG/templates/monitoring/falco-alerts.json \
  --namespace monitoring

kubectl label configmap grafana-dashboards grafana_dashboard=1 --namespace monitoring

# JSA + JADE dashboards (if those packages are deployed)
kubectl create configmap grafana-dashboards-jsa \
  --from-file=$PKG/templates/monitoring/jade-decisions.json \
  --from-file=$PKG/templates/monitoring/response-metrics.json \
  --namespace monitoring

kubectl label configmap grafana-dashboards-jsa grafana_dashboard=1 --namespace monitoring
```

### Via Grafana API

```bash
for dash in $PKG/templates/monitoring/*.json; do
  curl -s -X POST http://localhost:3000/api/dashboards/import \
    -H "Content-Type: application/json" \
    -u admin:admin \
    -d "{\"dashboard\": $(cat $dash), \"overwrite\": true}"
done
```

| Dashboard | Panels | Purpose |
|-----------|--------|---------|
| `runtime-security.json` | 12 | Findings, alert trends, response metrics |
| `falco-alerts.json` | 10 | MITRE heatmap, top rules, alert trends |
| `jade-decisions.json` | 8 | JADE approval tracking (requires 05) |
| `response-metrics.json` | 6 | Fix/rollback tracking (requires --with-jsa) |

---

## Step 3: Verify

```bash
# Check alert rules loaded
kubectl get prometheusrules -n monitoring

# Check dashboards loaded
kubectl get configmaps -n monitoring -l grafana_dashboard=1
```

---

## Next Steps

- Enable autonomous agent → [06-enable-autonomous-agent.md](06-enable-autonomous-agent.md)
- Skip to operations → [07-operations.md](07-operations.md)

---

*Ghost Protocol — Runtime Security Package (CKS)*
