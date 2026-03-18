# Vendor Integration Quickstart
### Connect Any Security Vendor to GP-Copilot in Half a Day

---

## WHAT THIS IS

Third-party security vendors (CrowdStrike Falcon, Wiz, Prisma Cloud, Aqua, etc.) produce findings. Those findings sit in their consoles. Nobody correlates them. Nobody deduplicates them against your own scans. Nobody ranks them.

This package fixes that. Every vendor's findings flow through one pipeline:

```
VENDOR API → Adapter (ingester + mapper) → Normalize to GPFinding → Dedup → Rank → FindingsStore
                                                                                    ↓
                                                                              JADE / Human
                                                                                    ↓
                                                                              Writeback → Vendor Console
```

**Result:** One pane of glass. JADE sees everything. Duplicates eliminated. Remediation status syncs back.

---

## THE ADAPTER PATTERN

Every vendor integration follows the same 3-file pattern:

```
vendors/<vendor-name>/
├── ingester.py       # OAuth2/API client — pulls raw findings
├── mapper.py         # Translates vendor schema → GPFinding
└── config.example.yaml  # Connection config template
```

Plus a registry entry in `shared/registry.py`.

Everything else is shared infrastructure — you don't rewrite it per vendor:
- `shared/normalizer.py` — GPFinding schema + severity mapping
- `shared/deduplicator.py` — Cross-source dedup engine
- `shared/store.py` — Dual-write to FindingsStore + JSONL
- `shared/writeback.py` — Push remediation status back to vendor
- `shared/registry.py` — Adapter discovery + lazy loading

---

## PLAYBOOK INDEX

| Playbook | What it covers |
|----------|---------------|
| `00-vendor-integration-quickstart.md` | This file — overview and architecture |
| `01-falcon-crowdstrike.md` | CrowdStrike Falcon: EDR, Spotlight, IoM |
| `02-wiz-cloud-security.md` | Wiz: cloud misconfigs, vulnerabilities, attack paths |
| `03-prisma-cloud.md` | Prisma Cloud: CSPM, CWPP, code security |
| `04-aqua-security.md` | Aqua: container runtime, image scanning, KSPM |
| `05-adding-new-vendor.md` | Step-by-step guide to build a new adapter |
| `06-dedup-and-correlation.md` | Cross-source dedup tuning and correlation |
| `07-writeback-and-sync.md` | Pushing remediation status back to vendors |
| `08-production-operations.md` | CronJob deployment, monitoring, troubleshooting |

---

## SUPPORTED VENDORS

| Vendor | Adapter Status | Data Sources | Priority |
|--------|---------------|-------------|----------|
| **CrowdStrike Falcon** | Done | EDR detections, Spotlight CVEs, IoM | 1 — primary |
| **Wiz** | Planned | Cloud misconfigs, vulns, attack paths, DSPM | 2 |
| **Prisma Cloud** | Planned | CSPM, CWPP, IaC scanning, code security | 3 |
| **Aqua Security** | Planned | Container runtime, image scanning, KSPM | 4 |
| **Lacework** | Planned | Cloud activity anomalies, compliance | 5 |
| **Snyk** | Planned | SCA, container, IaC, code | 6 |
| **Qualys** | Planned | VM scanning, web app scanning | 7 |
| **Tenable** | Planned | Nessus vulns, cloud security | 8 |

---

## QUICK START (FALCON — 30 MINUTES)

```bash
# 1. Copy config template
cp falcon/config.example.yaml falcon/config.yaml

# 2. Set credentials (NEVER put in config file — use env vars)
export FALCON_CLIENT_ID="your-client-id"
export FALCON_CLIENT_SECRET="your-client-secret"

# 3. Test connectivity
bash tools/test-connection.sh --adapter falcon

# 4. Run initial backfill (last 30 days)
bash tools/ingest.sh --adapter falcon --mode backfill --since 30d

# 5. Check results
bash tools/list-findings.sh --source falcon --format count

# 6. Start continuous polling
bash tools/ingest.sh --adapter falcon --mode poll --daemon
```

**Full Falcon setup:** See `playbooks/01-falcon-crowdstrike.md`

---

## HOW THE PIPELINE WORKS

### Step 1: Ingest (vendor-specific)
```
Adapter calls vendor API with OAuth2
  → Paginates through results
  → Respects rate limits
  → Stores raw response for audit
```

### Step 2: Map (vendor-specific)
```
Vendor finding → mapper.py → GPFinding
  → Severity normalized (vendor scale → CRITICAL/HIGH/MEDIUM/LOW/INFO)
  → Finding type classified (VULNERABILITY, MISCONFIGURATION, RUNTIME_DETECTION, etc.)
  → Asset identified (node, pod, image, package, IAM role, etc.)
  → Dedup key computed (CVE+asset, resource+rule, etc.)
  → MITRE ATT&CK mapped (if applicable)
```

### Step 3: Deduplicate (shared)
```
GPFinding enters deduplicator
  → Phase 1: Exact dedup_key match (same finding from same source)
  → Phase 2: Fuzzy cross-source match (Falcon CVE + Trivy CVE on same image)
  → Merge: keep highest severity, richest metadata, earliest first_seen
  → Tag: "cross_source_dedup" with list of sources
```

### Step 4: Store (shared)
```
Deduplicated GPFinding → VendorStore
  → FindingsStore (SQLite) for JADE/agent queries
  → JSONL audit trail for compliance evidence
  → Both writes must succeed (or fallback to JSONL-only)
```

### Step 5: Rank (shared)
```
FindingsStore → RankClassifier
  → E-rank: pattern fix, auto-remediate
  → D-rank: pattern fix, log
  → C-rank: JADE/Katie review
  → B-rank: human decision, JADE intel
  → S-rank: human only
```

### Step 6: Writeback (vendor-specific)
```
After remediation:
  → Writeback client pushes status to vendor API
  → Tags: gp:remediated, gp:accepted_risk, gp:false_positive
  → Vendor console reflects GP-Copilot's triage decisions
  → Client SOC sees unified view
```

---

## TEMPLATE INDEX

| Template | What it's for |
|----------|--------------|
| `templates/adapter-scaffold/` | Boilerplate for a new vendor adapter |
| `templates/config-template.yaml` | Generic vendor config with all common fields |
| `templates/cronjob-template.yaml` | K8s CronJob for any vendor's polling |
| `templates/alert-rules-template.yaml` | Prometheus alerts for any vendor ingestion |
| `templates/onboarding-checklist.md` | Client-facing checklist for vendor onboarding |
