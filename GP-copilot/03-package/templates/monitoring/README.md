# Monitoring & Dashboards

> Grafana dashboards and Prometheus alert rules for jsa-infrasec.

---

## Available Dashboards

| Dashboard | Purpose | Panels |
|-----------|---------|--------|
| `runtime-security.json` | Main operational dashboard | 12 panels |
| `jade-decisions.json` | JADE approval tracking | 8 panels |
| `falco-alerts.json` | Falco alert analysis | 10 panels |
| `response-metrics.json` | Fix/rollback tracking | 6 panels |

---

## Available Alert Rules

| Rule File | Alerts | Criticality |
|-----------|--------|-------------|
| `jsa-infrasec-alerts.yaml` | 8 runtime security alerts | High |
| `falco-alerts.yaml` | 5 Falco integration alerts | Critical |
| `jade-alerts.yaml` | 4 JADE health alerts | Medium |

---

## Quick Start

### 1. Import Grafana Dashboards

```bash
# Import via ConfigMap
kubectl create configmap grafana-dashboards \
  --from-file=templates/monitoring/runtime-security.json \
  --from-file=templates/monitoring/jade-decisions.json \
  --namespace monitoring

# Label for auto-discovery
kubectl label configmap grafana-dashboards \
  grafana_dashboard=1 \
  --namespace monitoring

# Grafana will auto-import within 60s
```

### 2. Deploy Prometheus Alert Rules

```bash
# Create PrometheusRule CRD
kubectl apply -f templates/monitoring/jsa-infrasec-alerts.yaml
kubectl apply -f templates/monitoring/falco-alerts.yaml
kubectl apply -f templates/monitoring/jade-alerts.yaml
```

### 3. Verify

```bash
# Check dashboards loaded
kubectl get configmaps -n monitoring -l grafana_dashboard=1

# Check alert rules loaded
kubectl get prometheusrules -n monitoring
```

---

## Dashboard Details

### Runtime Security Dashboard (runtime-security.json)

**Overview panel:**
- Total findings (last 24h)
- Findings by severity (pie chart)
- Mean time to detect (MTTD)
- Mean time to fix (MTTF)

**Watchers panel:**
- Active watchers (gauge)
- Events per watcher (bar chart)
- Watcher health (status)

**Findings panel:**
- Findings over time (line graph)
- Top findings by type (table)
- Rank distribution (pie chart)

**Response panel:**
- Fixes applied (counter)
- Rollback rate (gauge)
- Success rate (gauge)
- Response latency histogram

**Queries:**

```promql
# Total findings
sum(jsa_infrasec_findings_total)

# Findings by severity
sum by (severity) (jsa_infrasec_findings_total)

# Mean time to detect
avg(jsa_infrasec_detection_latency_seconds)

# Mean time to fix
avg(jsa_infrasec_fix_latency_seconds)

# Rollback rate
rate(jsa_infrasec_fixes_rolled_back_total[5m]) /
rate(jsa_infrasec_fixes_applied_total[5m]) * 100
```

---

### JADE Decisions Dashboard (jade-decisions.json)

**Decision metrics:**
- Approvals by rank (E-S)
- Average decision time
- Approval rate (%)
- Escalation rate (C→B→S)

**Queries:**

```promql
# Approvals by rank
sum by (rank) (jade_approvals_total)

# Average decision time
avg(jade_decision_latency_seconds)

# Approval rate
rate(jade_approvals_total[5m]) /
rate(jade_decisions_total[5m]) * 100

# Escalations
sum by (from_rank, to_rank) (jade_escalations_total)
```

---

### Falco Alerts Dashboard (falco-alerts.json)

**Alert analysis:**
- Alerts per hour (line graph)
- Top rules triggered (table)
- MITRE tactics (pie chart)
- Alert severity distribution

**Queries:**

```promql
# Alerts per hour
rate(falco_alerts_total[1h]) * 3600

# Top rules
topk(10, sum by (rule) (falco_alerts_total))

# MITRE tactics
sum by (mitre_tactic) (falco_alerts_total)

# Severity distribution
sum by (severity) (falco_alerts_total)
```

---

### Response Metrics Dashboard (response-metrics.json)

**Fix tracking:**
- Fixes applied vs rolled back
- Fix success rate by rank
- Snapshot creation time
- Rollback success rate

**Queries:**

```promql
# Fixes applied
sum(jsa_infrasec_fixes_applied_total)

# Rollback count
sum(jsa_infrasec_fixes_rolled_back_total)

# Success rate by rank
sum by (rank) (jsa_infrasec_fixes_successful_total) /
sum by (rank) (jsa_infrasec_fixes_applied_total) * 100

# Snapshot creation time
histogram_quantile(0.95, jsa_infrasec_snapshot_duration_seconds_bucket)
```

---

## Alert Rule Details

### jsa-infrasec-alerts.yaml

**1. High False Positive Rate**
```yaml
- alert: HighFalsePositiveRate
  expr: rate(jsa_infrasec_findings_total[1h]) > 100
  for: 15m
  labels:
    severity: warning
  annotations:
    summary: "High false positive rate detected"
    description: "{{ $value }} findings/hour (threshold: 100)"
```

**2. Auto-Fix Failure**
```yaml
- alert: AutoFixFailureRateHigh
  expr: |
    rate(jsa_infrasec_fixes_rolled_back_total[5m]) /
    rate(jsa_infrasec_fixes_applied_total[5m]) > 0.10
  for: 10m
  labels:
    severity: critical
  annotations:
    summary: "Auto-fix rollback rate >10%"
```

**3. Watcher Down**
```yaml
- alert: WatcherDown
  expr: jsa_infrasec_watchers_active < 5
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Critical watcher is down"
```

---

### falco-alerts.yaml

**1. Falco Not Sending Alerts**
```yaml
- alert: FalcoSilent
  expr: rate(falco_alerts_total[5m]) == 0
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "No Falco alerts received"
```

**2. Critical MITRE Tactic**
```yaml
- alert: CriticalMITRETactic
  expr: |
    sum by (mitre_tactic) (falco_alerts_total{
      mitre_tactic=~"Exfiltration|Impact|Command and Control"
    }) > 0
  labels:
    severity: critical
  annotations:
    summary: "Critical MITRE tactic detected: {{ $labels.mitre_tactic }}"
```

---

### jade-alerts.yaml

**1. JADE Unavailable**
```yaml
- alert: JADEDown
  expr: up{job="jade"} == 0
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "JADE supervisor is down"
```

**2. High Escalation Rate**
```yaml
- alert: HighEscalationRate
  expr: |
    rate(jade_escalations_total[1h]) /
    rate(jade_decisions_total[1h]) > 0.20
  for: 15m
  labels:
    severity: warning
  annotations:
    summary: "JADE escalating >20% of decisions"
```

---

## Grafana Setup

### Prerequisites

```bash
# Install Grafana (if not already)
helm repo add grafana https://grafana.github.io/helm-charts
helm install grafana grafana/grafana \
  --namespace monitoring \
  --create-namespace
```

### Configure Data Sources

```yaml
# Add to Grafana ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  prometheus.yaml: |
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus:9090
        isDefault: true
```

### Enable Dashboard Auto-Import

```yaml
# Add to Grafana deployment
env:
  - name: GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH
    value: /var/lib/grafana/dashboards/runtime-security.json
```

---

## Alertmanager Integration

Route alerts to Slack, PagerDuty, email:

```yaml
# alertmanager-config.yaml
route:
  receiver: 'slack-security'
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty-oncall'

    - match:
        severity: warning
      receiver: 'slack-security'

receivers:
  - name: 'slack-security'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK'
        channel: '#security-alerts'

  - name: 'pagerduty-oncall'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_KEY'
```

---

## SLI/SLO Tracking

### Service Level Indicators (SLIs)

```promql
# Detection latency (95th percentile)
histogram_quantile(0.95, jsa_infrasec_detection_latency_seconds_bucket)

# Fix latency (95th percentile)
histogram_quantile(0.95, jsa_infrasec_fix_latency_seconds_bucket)

# Availability
avg_over_time(up{job="jsa-infrasec"}[30d])

# Fix success rate
sum(jsa_infrasec_fixes_successful_total) /
sum(jsa_infrasec_fixes_applied_total)
```

### Service Level Objectives (SLOs)

| SLI | Target | Threshold |
|-----|--------|-----------|
| Detection latency (p95) | <5s | <10s |
| Fix latency (p95) | <60s | <120s |
| Availability | >99.5% | >99% |
| Fix success rate | >90% | >80% |

---

*Part of the Iron Legion - CKS | CKA | CCSP Certified Standards*
