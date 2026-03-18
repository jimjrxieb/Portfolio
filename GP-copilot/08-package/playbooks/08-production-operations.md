# Playbook 08: Production Operations
### Deploying, Monitoring, and Troubleshooting Vendor Integrations

---

## DEPLOYMENT

### K8s CronJob (recommended)

Each vendor gets its own CronJob for isolation. If one vendor's API is down, the others keep running.

```bash
# Create namespace
kubectl create namespace vendor-integration

# Create credentials secret
kubectl create secret generic vendor-credentials \
  -n vendor-integration \
  --from-literal=falcon-client-id="$FALCON_CLIENT_ID" \
  --from-literal=falcon-client-secret="$FALCON_CLIENT_SECRET" \
  --from-literal=wiz-client-id="$WIZ_CLIENT_ID" \
  --from-literal=wiz-client-secret="$WIZ_CLIENT_SECRET"

# Deploy CronJobs
kubectl apply -f deployment-configs/cronjob.yaml                    # Falcon
# kubectl apply -f deployment-configs/wiz-cronjob.yaml              # Wiz (when ready)
# kubectl apply -f deployment-configs/prisma-cronjob.yaml           # Prisma (when ready)

# Verify
kubectl get cronjobs -n vendor-integration
kubectl get jobs -n vendor-integration --sort-by=.metadata.creationTimestamp
```

### CronJob template for any vendor

```yaml
# templates/cronjob-template.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: vendor-ingest-<VENDOR>
  namespace: vendor-integration
  labels:
    app: vendor-integration
    vendor: <VENDOR>
spec:
  schedule: "*/5 * * * *"           # Every 5 minutes
  concurrencyPolicy: Forbid          # Don't overlap runs
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 5
  jobTemplate:
    spec:
      backoffLimit: 2
      activeDeadlineSeconds: 300      # Kill if running > 5 min
      template:
        metadata:
          labels:
            app: vendor-integration
            vendor: <VENDOR>
        spec:
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            fsGroup: 1000
            seccompProfile:
              type: RuntimeDefault
          containers:
            - name: ingester
              image: ghcr.io/org/vendor-integration:latest
              command:
                - bash
                - tools/ingest.sh
                - --adapter
                - <VENDOR>
                - --mode
                - backfill
                - --since
                - 1d
              env:
                - name: <VENDOR>_CLIENT_ID
                  valueFrom:
                    secretKeyRef:
                      name: vendor-credentials
                      key: <vendor>-client-id
                - name: <VENDOR>_CLIENT_SECRET
                  valueFrom:
                    secretKeyRef:
                      name: vendor-credentials
                      key: <vendor>-client-secret
                - name: GP_VENDOR_OUTPUT
                  value: /data/findings
              securityContext:
                allowPrivilegeEscalation: false
                readOnlyRootFilesystem: true
                capabilities:
                  drop: ["ALL"]
              resources:
                requests:
                  cpu: 100m
                  memory: 128Mi
                limits:
                  cpu: 500m
                  memory: 256Mi
              volumeMounts:
                - name: findings
                  mountPath: /data/findings
          volumes:
            - name: findings
              emptyDir: {}
          restartPolicy: OnFailure
```

---

## MONITORING

### Deploy Prometheus alerts

```bash
kubectl apply -f monitoring/vendor-alerts.yaml -n monitoring
```

### Alert rules

| Alert | Condition | Severity | What to do |
|-------|-----------|----------|------------|
| `VendorIngestionDown` | No successful poll in 15 min | Warning | Check CronJob logs, API status |
| `VendorAPIErrorRate` | >10% error rate for 10 min | Warning | Check API credentials, rate limits |
| `VendorIngestionBacklog` | >1000 findings queued | Warning | Check dedup performance, increase resources |
| `VendorDedupRateAnomaly` | Dedup rate shifted >15% | Info | Review new findings pattern, check mapper |
| `VendorWritebackFailing` | Writeback errors | Warning | Check write permissions, API changes |

### Deploy Grafana dashboard

```bash
# Import the dashboard JSON
kubectl create configmap vendor-ingestion-dashboard \
  -n monitoring \
  --from-file=monitoring/vendor-ingestion.json

# Or import via Grafana UI: + → Import → paste JSON
```

### Dashboard panels

| Panel | What it shows |
|-------|-------------|
| Ingestion rate | Findings per minute over time |
| Findings by source | Pie chart: Falcon vs Wiz vs Prisma etc. |
| Findings by severity | Pie chart: CRITICAL/HIGH/MEDIUM/LOW |
| Dedup rate | Percentage of findings eliminated by dedup |
| API errors | Error rate per vendor over time |
| Last successful poll | Seconds since last successful run |
| Writeback status | Table of recent writeback results |
| Ingestion backlog | Gauge: findings waiting to be processed |

---

## TROUBLESHOOTING

### Problem: CronJob not running

```bash
# Check CronJob status
kubectl get cronjob vendor-ingest-falcon -n vendor-integration

# Check if jobs are being created
kubectl get jobs -n vendor-integration --sort-by=.metadata.creationTimestamp | tail -5

# Check job logs
kubectl logs -n vendor-integration job/$(kubectl get jobs -n vendor-integration -o jsonpath='{.items[-1].metadata.name}')

# Common causes:
# - concurrencyPolicy: Forbid + previous job still running
# - Image pull error (check imagePullSecrets)
# - Secret not found (check secret name matches)
```

### Problem: Authentication failing

```bash
# Run test-connection manually
kubectl exec -it -n vendor-integration $(kubectl get pods -n vendor-integration -l vendor=falcon -o name | head -1) -- \
  bash tools/test-connection.sh --adapter falcon

# If 401: credentials are wrong or expired
# → Regenerate API key in vendor console
# → Update K8s secret:
kubectl create secret generic vendor-credentials \
  -n vendor-integration \
  --from-literal=falcon-client-id="$NEW_ID" \
  --from-literal=falcon-client-secret="$NEW_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Problem: Rate limited (429)

```bash
# Check CronJob schedule — might be polling too frequently
# Falcon: 300 req/min, Wiz: 100 req/min, Prisma: 60 req/min

# Fix: increase poll interval
# In config.yaml: poll_interval_seconds: 600  (10 min instead of 5)

# Fix: reduce batch size in ingester
# In ingester.py: change pagesize from 500 to 100
```

### Problem: Findings not appearing in FindingsStore

```bash
# Check JSONL output (always works even if DB fails)
ls -la /tmp/gp-vendor/*.jsonl
tail -5 /tmp/gp-vendor/falcon-findings.jsonl | jq .

# If JSONL has data but FindingsStore doesn't:
# → VendorStore couldn't connect to FindingsStore
# → Check shared/store.py path to GP-BEDROCK-AGENTS/shared/
# → Check SQLite DB exists and is writable
```

### Problem: Dedup rate suddenly changed

```bash
# Run dedup report to see current state
bash tools/dedup-report.sh --source all

# Common causes:
# - New vendor added (more cross-source matches = higher dedup rate)
# - Vendor changed their API schema (mapper producing different dedup_keys)
# - Asset naming changed (e.g., registry prefix added to image names)
# - Severity floor changed (more/fewer findings entering the pipeline)
```

### Problem: Writeback not updating vendor

```bash
# Test write permissions
bash tools/writeback.sh --adapter falcon --dry-run

# If dry-run works but actual writeback fails:
# → API key may have read-only scope
# → Check vendor console for API key permissions
# → Some vendors require separate write scope (Falcon: Detections Write)
```

---

## SCALING

### Multiple clusters

```bash
# Each cluster runs its own CronJob
# Findings tagged with cluster name in mapper
# Dedup handles cross-cluster merging automatically

# Deploy to each cluster:
kubectl apply -f deployment-configs/cronjob.yaml --context=cluster-a
kubectl apply -f deployment-configs/cronjob.yaml --context=cluster-b
```

### High-volume environments (10k+ findings/day)

```yaml
# Increase resources
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: "1"
    memory: 1Gi

# Increase activeDeadlineSeconds
activeDeadlineSeconds: 900    # 15 minutes

# Reduce poll frequency but increase batch size
# poll_interval_seconds: 900  # 15 min instead of 5
```

---

## OPERATIONAL RUNBOOK

### Daily checks

```bash
# Quick health check
kubectl get cronjobs -n vendor-integration
kubectl get jobs -n vendor-integration --sort-by=.metadata.creationTimestamp | tail -5

# Any failures?
kubectl get jobs -n vendor-integration -o json | \
  jq -r '.items[] | select(.status.failed > 0) | .metadata.name'
```

### Weekly checks

```bash
# Dedup quality
bash tools/dedup-report.sh --source all

# Finding volume trends
bash tools/list-findings.sh --source all --format count

# Writeback status
bash tools/writeback.sh --adapter falcon --dry-run
```

### On vendor API change

```
1. Check vendor changelog/release notes
2. Test connectivity: bash tools/test-connection.sh --adapter <vendor>
3. If broken: update ingester.py for API changes
4. If new fields: update mapper.py to capture new data
5. Run backfill with small window to validate: --since 1d
6. Compare dedup report to previous baseline
```

---

## COMPLETION CHECKLIST

```
[ ] CronJob deployed for each active vendor
[ ] Credentials stored as K8s Secrets (not in config files)
[ ] Prometheus alerts deployed
[ ] Grafana dashboard deployed
[ ] Initial backfill completed and validated
[ ] Continuous polling confirmed working (check last 3 jobs)
[ ] Monitoring shows ingestion rate > 0
[ ] Alerting tested (verify alert fires and routes correctly)
[ ] Writeback scheduled (if applicable)
[ ] Troubleshooting steps documented for on-call
[ ] Vendor API rate limits documented and respected
```
