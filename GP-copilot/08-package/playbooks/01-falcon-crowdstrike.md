# Playbook 01: CrowdStrike Falcon Integration
### EDR Detections + Spotlight Vulnerabilities + Indicators of Misconfiguration

---

## WHAT FALCON GIVES US

| Data source | API endpoint | What it contains | Finding type |
|-------------|-------------|-----------------|-------------|
| **EDR Detections** | `/detects/queries/detects/v1` | Runtime threats on endpoints/nodes | RUNTIME_DETECTION |
| **Spotlight Vulnerabilities** | `/spotlight/combined/vulnerabilities/v1` | CVEs on hosts/containers | VULNERABILITY |
| **IoM (Indicators of Misconfiguration)** | `/iom/combined/findings/v1` | Cloud/host misconfigurations | MISCONFIGURATION |

### Why Falcon is Priority 1

- Most enterprise clients already run Falcon on their nodes
- Falcon sees what our scanners can't: runtime behavior, lateral movement, credential theft
- Spotlight CVEs overlap with Trivy — perfect dedup test case
- IoM findings overlap with Checkov/Kubescape — more dedup value
- MITRE ATT&CK mapping correlates with Falco runtime detections

---

## PREREQUISITES

### Create Falcon API Client

1. Go to: **Falcon Console → Support and resources → API Clients and Keys**
2. Click **Create API Client**
3. Set scopes:

| Scope | Permission | Why |
|-------|-----------|-----|
| Detections | Read | Pull EDR detections |
| Spotlight Vulnerabilities | Read | Pull CVEs |
| IOA Exclusions | Read | Pull IoM findings |
| Hosts | Read | Resolve host details for asset mapping |
| Detections | Write | Writeback remediation tags (optional) |

4. Note the **Client ID** and **Client Secret**
5. Note your **Cloud region**:

| Cloud | Base URL |
|-------|---------|
| US-1 | `api.crowdstrike.com` |
| US-2 | `api.us-2.crowdstrike.com` |
| EU-1 | `api.eu-1.crowdstrike.com` |
| US-GOV-1 | `api.laggar.gcw.crowdstrike.com` |

---

## STEP 1: CONFIGURE

```bash
cd /path/to/GP-CONSULTING/08-VENDOR-INTEGRATION

# Copy template
cp falcon/config.example.yaml falcon/config.yaml
```

Edit `falcon/config.yaml`:
```yaml
api:
  client_id: "${FALCON_CLIENT_ID}"      # NEVER hardcode — use env var
  client_secret: "${FALCON_CLIENT_SECRET}"
  cloud: "us-1"                          # your region

ingestion:
  poll_interval_seconds: 300             # 5 minutes
  categories:
    - detections                         # EDR alerts
    - spotlight_vulnerabilities          # CVEs
    - iom_findings                       # Misconfigs
  severity_floor: "medium"               # skip low/info noise
  deduplicate_by_id: true                # dedup within Falcon

writeback:
  enabled: true
  method: "tags"                         # tag findings in Falcon
  tag_prefix: "gp"
  status_tags:
    remediated: "gp:remediated"
    in_progress: "gp:in-progress"
    accepted_risk: "gp:accepted-risk"
    false_positive: "gp:false-positive"

logging:
  level: "INFO"
  audit_log: "/tmp/gp-vendor/falcon-audit.jsonl"
```

Set environment variables:
```bash
# Store in AWS Secrets Manager (recommended)
aws secretsmanager create-secret \
  --name platform/vendor-integration/falcon \
  --secret-string '{"client_id":"xxx","client_secret":"xxx"}'

# Or for testing — export directly (NEVER commit these)
export FALCON_CLIENT_ID="your-client-id"
export FALCON_CLIENT_SECRET="your-client-secret"
```

---

## STEP 2: TEST CONNECTIVITY

```bash
bash tools/test-connection.sh --adapter falcon
```

Expected output:
```
[OK] Config file found: falcon/config.yaml
[OK] Python3 available
[OK] Required packages: requests, pyyaml
[OK] Falcon API authentication successful
[OK] Detections endpoint: 200 OK (12,847 findings available)
[OK] Spotlight endpoint: 200 OK (4,210 vulnerabilities available)
[OK] IoM endpoint: 200 OK (892 misconfigurations available)

Falcon integration ready. Run: bash tools/ingest.sh --adapter falcon --mode backfill
```

### Troubleshooting connection failures

| Error | Cause | Fix |
|-------|-------|-----|
| `401 Unauthorized` | Bad client ID or secret | Regenerate API client in Falcon console |
| `403 Forbidden` | Missing API scope | Add required scopes to API client |
| `Connection refused` | Wrong cloud region | Check `api.cloud` in config matches your Falcon tenant |
| `SSL Error` | Proxy/firewall intercepting | Add proxy config or whitelist Falcon API domain |
| `429 Too Many Requests` | Rate limited | Reduce `poll_interval_seconds`, add backoff |

---

## STEP 3: INITIAL BACKFILL

Pull historical findings to establish a baseline:

```bash
# Last 30 days (recommended for first sync)
bash tools/ingest.sh --adapter falcon --mode backfill --since 30d

# Or dry-run first to see what it will pull
bash tools/ingest.sh --adapter falcon --mode backfill --since 30d --dry-run
```

Expected output:
```
=== Falcon Backfill: last 30 days ===
Authenticating... OK
Ingesting detections... 847 findings
Ingesting spotlight vulnerabilities... 4,210 findings
Ingesting IoM findings... 892 findings
---
Total raw: 5,949
After dedup (within source): 5,412
Written to FindingsStore: 5,412
Written to JSONL: 5,412
Audit log: /tmp/gp-vendor/falcon-audit.jsonl
```

### Check results

```bash
# Summary by severity
bash tools/list-findings.sh --source falcon --format count

# Severity breakdown:
#   CRITICAL:   42
#   HIGH:       387
#   MEDIUM:     2,891
#   LOW:        1,847
#   INFO:       245
#   Total:      5,412

# View critical findings
bash tools/list-findings.sh --source falcon --severity critical --format table

# View as JSON (for JADE or scripting)
bash tools/list-findings.sh --source falcon --severity critical --format json
```

---

## STEP 4: CROSS-SOURCE DEDUPLICATION

This is where the real value is. Falcon's Spotlight CVEs overlap with your Trivy scans. IoM findings overlap with Checkov/Kubescape.

```bash
# Run dedup report
bash tools/dedup-report.sh --source falcon

# Expected output:
# === Dedup Report: falcon ===
# Total findings:        5,412
# Unique dedup keys:     4,891
# Duplicated (internal): 521 (9.6%)
#
# Cross-source matches:
#   falcon + trivy:      1,247 matches (Spotlight CVEs ↔ Trivy image CVEs)
#   falcon + checkov:    312 matches (IoM ↔ Checkov IaC findings)
#   falcon + kubescape:  89 matches (IoM ↔ Kubescape cluster findings)
#
# Net new findings:      3,243 (findings ONLY Falcon sees)
# Dedup rate:            40.1%
```

**The 3,243 net new findings** are what Falcon brings to the table that your internal scanners missed. That's the value pitch to the client.

### Tune dedup accuracy

```bash
# Verbose mode: see individual matches
bash tools/dedup-report.sh --source falcon --verbose

# If false positives:
# - Increase dedup threshold in shared/deduplicator.py (default 0.8 → 0.9)
# - Add asset normalization rules (hostname formats differ between vendors)

# If false negatives (missed matches):
# - Lower threshold (0.8 → 0.7)
# - Improve dedup key computation in mapper
```

---

## STEP 5: ENABLE CONTINUOUS POLLING

```bash
# Foreground (for testing)
bash tools/ingest.sh --adapter falcon --mode poll

# Daemon mode (background)
bash tools/ingest.sh --adapter falcon --mode poll --daemon

# Check daemon
cat /tmp/gp-vendor/falcon-poll.pid
tail -f /tmp/gp-vendor/falcon-poll.log
```

### Production: Deploy as K8s CronJob

```bash
# Create the credentials secret
kubectl create secret generic vendor-credentials \
  -n vendor-integration \
  --from-literal=falcon-client-id="$FALCON_CLIENT_ID" \
  --from-literal=falcon-client-secret="$FALCON_CLIENT_SECRET"

# Deploy CronJob
kubectl apply -f deployment-configs/cronjob.yaml
```

See `playbooks/08-production-operations.md` for full deployment guide.

---

## STEP 6: ENABLE WRITEBACK

After GP-Copilot triages and remediates findings, push status back to Falcon:

```bash
# Dry-run: see what would be written
bash tools/writeback.sh --adapter falcon --dry-run

# Expected:
# Would update 847 findings in Falcon:
#   gp:remediated:     612 (E/D-rank auto-fixed)
#   gp:in-progress:    180 (C-rank pending)
#   gp:accepted-risk:  42 (documented exceptions)
#   gp:false-positive: 13 (confirmed false positives)

# Execute writeback
bash tools/writeback.sh --adapter falcon

# Verify in Falcon console:
# Detections → filter by tag "gp:remediated" → should see tagged findings
```

### What writeback gives the client
- SOC team sees GP-Copilot's triage decisions in Falcon console
- No context switching between platforms
- Automated remediation is visible to the security team
- Audit trail for compliance (who fixed what, when)

---

## SEVERITY MAPPING

| Falcon Severity | Falcon Numeric | GP Severity | Rank |
|----------------|---------------|-------------|------|
| Critical | 5 | CRITICAL | B-rank (human review) |
| High | 4 | HIGH | C-rank (JADE review) |
| Medium | 3 | MEDIUM | D-rank (auto + log) |
| Low | 2 | LOW | E-rank (auto) |
| Informational | 1 | INFORMATIONAL | E-rank (auto) |

---

## MITRE ATT&CK CORRELATION

Falcon EDR detections include MITRE tactic/technique. We correlate with Falco runtime detections:

| MITRE Tactic | Falcon Sees | Falco Sees | Correlation |
|-------------|-------------|------------|-------------|
| Initial Access | Exploit public-facing app | Unexpected inbound connection | Same event, different perspective |
| Execution | Suspicious process | Shell spawned in container | Same event, different perspective |
| Persistence | Scheduled task created | Write to /etc/crontab | Same event, different perspective |
| Credential Access | Credential dumping | Read /etc/shadow | Same event, different perspective |
| Lateral Movement | RDP/SSH to new host | Outbound connection to internal IP | Same event, different perspective |

**When both fire on the same event:** The deduplicator merges them into one finding with evidence from both sources. JADE gets a richer picture.

---

## REAL-WORLD RESULTS (GHOST PROTOCOL CASE STUDY)

```
Environment: 3 EKS clusters, 200+ nodes
Falcon findings:    12,847
Internal findings:   4,210 (Trivy + Semgrep + Kubescape)
---
Cross-source dedup:  2,134 matches (16.6%)
Net new from Falcon: 10,713
---
Rank distribution:
  E-rank: 6,415 (59.9%) — auto-remediated
  D-rank: 2,153 (20.1%) — auto + logged
  C-rank: 1,929 (18.0%) — JADE reviewed
  B-rank:   193 (1.8%)  — human decision
  S-rank:    23 (0.2%)  — human only
---
Before integration: 40 hours/week manual triage
After integration:   8 hours/week manual triage (B+S rank only)
Auto-remediation:   80% of findings fixed without human touch
```

---

## COMPLETION CHECKLIST

```
[ ] Falcon API client created with correct scopes
[ ] Credentials stored securely (AWS SM or K8s Secret — NOT in config file)
[ ] Config.yaml created from template
[ ] Connectivity test passes (all 3 endpoints)
[ ] Initial backfill completed (30 days)
[ ] Findings visible in list-findings.sh
[ ] Cross-source dedup report reviewed
[ ] Dedup accuracy acceptable (false positive rate < 1%)
[ ] Continuous polling enabled (daemon or CronJob)
[ ] Writeback tested (dry-run + actual)
[ ] Monitoring alerts deployed (vendor-alerts.yaml)
[ ] Grafana dashboard deployed (vendor-ingestion.json)
[ ] Client SOC team briefed on writeback tags
```
