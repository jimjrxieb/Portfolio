# Vendor Integration Engagement Guide

> Ingest findings from a client's existing security platform and feed them into GP-Copilot's rank system for autonomous remediation.
> This is the external data layer — it enriches the pipeline without replacing any internal scanner.

---

## What This Package Does

```
┌──────────────────────────────────────────────────────────────────┐
│               VENDOR INTEGRATION PIPELINE                        │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Client's Vendor Platform (Falcon, Wiz, Prisma, Aqua)           │
│  └─ Produces detections/findings via API                         │
│                                                                   │
│  08-VENDOR-INTEGRATION (Adapter Layer)                           │
│  └─ Polls vendor API on schedule (or receives webhooks)          │
│  └─ Maps vendor severity/category → GP universal schema          │
│  └─ Deduplicates against internal findings (01/02/03)            │
│  └─ Routes to RankClassifier → E/D/C/B/S                        │
│  └─ Writes remediation status back to vendor platform            │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

**Engagement flow:** Identify vendor → Configure adapter → Test connectivity → Initial sync → Dedup tuning → Production polling → Writeback

**Relationship to other packages:**
- **01-APP-SEC** through **03-DEPLOY-RUNTIME** already ran → internal findings exist
- **08-VENDOR-INTEGRATION** adds external findings to the same pipeline
- **04-JSA-AUTONOMOUS** consumes all findings regardless of source

---

## Phase 1: Vendor Discovery

**Goal:** Identify which security platforms the client runs and what API access is available.

### Client questions

| Question | Why It Matters |
|----------|---------------|
| What CNAPP/EDR/CSPM do you run? | Determines which adapter to configure |
| Do you have API credentials (read + write)? | Read = ingest. Write = status writeback |
| What finding categories matter most? | Filter noisy categories on ingestion |
| Do you already export findings somewhere? | May have SIEM/SOAR that simplifies integration |
| What's your detection volume? | Sizing: 100/day vs 10,000/day changes architecture |

### Expected outcome

```
Vendor: CrowdStrike Falcon
API access: OAuth2 client credentials (read: detections, vulnerabilities; write: status)
Volume: ~500 findings/day
Priority categories: container vulnerabilities, K8s misconfigurations, runtime detections
```

---

## Phase 2: Adapter Configuration

**Goal:** Configure the vendor adapter and validate API connectivity.

### Step 1: Copy example config

```bash
cp 08-VENDOR-INTEGRATION/falcon/config.example.yaml \
   08-VENDOR-INTEGRATION/falcon/config.yaml
```

### Step 2: Fill in credentials

```yaml
# falcon/config.yaml (NEVER COMMIT)
api:
  client_id: "${FALCON_CLIENT_ID}"       # From env var
  client_secret: "${FALCON_CLIENT_SECRET}" # From env var
  base_url: "https://api.crowdstrike.com"
  cloud: "us-1"                            # us-1, us-2, eu-1, us-gov-1

ingestion:
  poll_interval_seconds: 300               # 5 minutes
  categories:
    - container_vulnerabilities
    - kubernetes_misconfigurations
    - runtime_detections
    - iom_findings                         # Indicators of Misconfiguration
  severity_floor: "medium"                 # Ignore informational/low

writeback:
  enabled: true
  status_field: "tags"                     # Where to write remediation status
```

### Step 3: Test connectivity

```bash
bash 08-VENDOR-INTEGRATION/tools/test-connection.sh --adapter falcon
```

Expected output:
```
[OK] API authentication successful
[OK] Detections endpoint accessible (found 1,247 detections)
[OK] Vulnerabilities endpoint accessible (found 3,891 vulnerabilities)
[OK] Write access confirmed (test tag applied and removed)
```

---

## Phase 3: Initial Sync and Mapping

**Goal:** Pull all existing findings, normalize them, and verify the mapping is accurate.

### Step 1: Run initial ingestion

```bash
bash 08-VENDOR-INTEGRATION/tools/ingest.sh \
  --adapter falcon \
  --mode backfill \
  --since "30d"
```

### Step 2: Review mapping quality

```bash
bash 08-VENDOR-INTEGRATION/tools/list-findings.sh \
  --source falcon \
  --format table \
  --limit 20
```

Check that:
- Severity mapping makes sense (Falcon "Critical" → GP "critical")
- Categories map to correct GP finding types
- Asset identifiers resolve (container image, namespace, pod)

### Step 3: Review deduplication

```bash
bash 08-VENDOR-INTEGRATION/tools/dedup-report.sh --source falcon
```

Expected output:
```
Total Falcon findings:    3,891
Matched to internal:        847  (21.8%)
Net new findings:         3,044
Dedup method breakdown:
  CVE + image match:        612
  Resource + rule match:    235
```

---

## Phase 4: Production Polling

**Goal:** Enable continuous ingestion with proper monitoring.

### Step 1: Deploy polling schedule

```bash
bash 08-VENDOR-INTEGRATION/tools/ingest.sh \
  --adapter falcon \
  --mode poll \
  --daemon
```

### Step 2: Verify rank routing

New vendor findings should flow through the rank system:

```bash
# Check that Falcon findings are being classified
bash 08-VENDOR-INTEGRATION/tools/list-findings.sh \
  --source falcon \
  --status unranked \
  --format count
# Should be 0 after a few minutes (all findings get ranked)
```

### Step 3: Enable writeback

Once findings are being remediated, write status back to the vendor platform:

```bash
bash 08-VENDOR-INTEGRATION/tools/writeback.sh \
  --adapter falcon \
  --dry-run
# Review what would be written, then:
bash 08-VENDOR-INTEGRATION/tools/writeback.sh \
  --adapter falcon
```

---

## Phase 5: Tuning

**Goal:** Reduce noise and improve dedup accuracy.

### Common tuning tasks

| Issue | Solution |
|-------|----------|
| Too many low-value findings | Raise `severity_floor` in config.yaml |
| False dedup matches | Tighten dedup rules in `shared/deduplicator.py` |
| Missing dedup matches | Add asset identifier mappings to adapter's `mapper.py` |
| Stale findings re-ingested | Enable `ingestion.deduplicate_by_id: true` |
| Writeback too aggressive | Set `writeback.require_verification: true` |

### Verify tuning

```bash
# Before/after comparison
bash 08-VENDOR-INTEGRATION/tools/dedup-report.sh --source falcon --compare-last
```

---

## Phase 6: Operational Handoff

**Goal:** Client team can operate the integration independently.

### Deliverables

| Deliverable | Description |
|-------------|-------------|
| Configured adapter | `falcon/config.yaml` with client-specific settings |
| Monitoring dashboard | Grafana dashboard showing ingestion rate, dedup rate, rank distribution |
| Runbook | How to restart, tune, and troubleshoot the adapter |
| Alert rules | Prometheus alerts for ingestion failures and backlog |

### Success criteria

- [ ] Polling runs continuously without manual intervention
- [ ] New findings appear in GP-Copilot within poll interval
- [ ] Dedup rate is stable (±5% week over week)
- [ ] Writeback updates vendor platform with remediation status
- [ ] Client team has run the adapter independently for 1 week

---

## FAQ

**Q: Can we run multiple vendor adapters simultaneously?**
A: Yes. Each adapter polls independently. Deduplication works across all sources — a finding from Falcon and the same finding from Wiz = one finding.

**Q: What if the client doesn't have write API access?**
A: Set `writeback.enabled: false`. The integration is read-only. Findings still flow into GP-Copilot, but remediation status won't be reflected in the vendor platform.

**Q: Does this replace our internal scanners (01/02/03)?**
A: No. Internal scanners are the source of truth. Vendor findings supplement them. The deduplicator ensures no double-counting.

**Q: What happens if the vendor API goes down?**
A: The adapter retries with exponential backoff. Existing findings continue to be processed. An alert fires if ingestion is down for > 15 minutes.
