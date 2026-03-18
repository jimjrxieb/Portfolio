# Playbook 06: Cross-Source Dedup & Correlation
### Eliminating Noise, Finding Signal

---

## WHY DEDUP MATTERS

Without dedup, a single CVE on a container image shows up as:
- 1 finding from Trivy (our scanner)
- 1 finding from Falcon Spotlight (vendor)
- 1 finding from Aqua (vendor)
- 1 finding from Prisma CWPP (vendor)

That's 4 alerts for 1 problem. Multiply across 500 images = 2,000 alerts instead of 500. Nobody triages that. Alert fatigue → nothing gets fixed.

**With dedup:** 4 findings → 1 merged finding with evidence from all 4 sources. JADE sees one thing to fix.

---

## HOW THE DEDUP ENGINE WORKS

### Phase 1: Exact Match (within source)

Same `dedup_key` from the same `source` = same finding. Keep only the most recent.

```
dedup_key computation (shared/normalizer.py):
  VULNERABILITY:       cve_id + asset_id     → "CVE-2025-1234:nginx:1.25"
  MISCONFIGURATION:    asset_id + hash(title) → "s3://mybucket:a8f3d2"
  RUNTIME_DETECTION:   asset_id + mitre_technique → "payments-pod:T1059"
  COMPLIANCE_VIOLATION: asset_id + hash(title) → "cluster1:CIS-4.1.1"
  SECRET_EXPOSURE:     asset_id + hash(title)
  IAM_RISK:            asset_id + hash(title)
```

### Phase 2: Fuzzy Match (cross-source)

Different sources, same underlying issue. Scored 0.0 → 1.0:

| Score | Match type | Example |
|-------|-----------|---------|
| 1.0 | Exact dedup_key match | Falcon + Trivy: same CVE, same image |
| 0.9 | Same CVE + same asset (different key format) | CVE-2025-1234 on nginx:1.25 (Falcon) vs nginx:latest (Trivy) |
| 0.8 | Same title + same asset type | "S3 bucket public" from Checkov + Wiz |
| 0.7 | Same finding type + same asset | MISCONFIGURATION on same resource |
| 0.3 | Same CVE, different asset | CVE-2025-1234 on image A (Trivy) + image B (Falcon) |
| 0.0 | No match | Unrelated findings |

**Threshold:** 0.8 (configurable). Anything above 0.8 is merged.

### Merge Strategy

When findings match:
- **Severity:** Keep the highest (if Falcon says CRITICAL and Trivy says HIGH → CRITICAL)
- **Metadata:** Keep the richest (MITRE ATT&CK from Falcon + fix version from Trivy)
- **First seen:** Keep the earliest
- **Last seen:** Keep the latest
- **Sources:** Tag with all contributing sources
- **Raw payload:** Keep from the source with most detail

---

## TUNING THE DEDUP ENGINE

### Problem: False positives (merging things that aren't the same)

```bash
# Check dedup quality
bash tools/dedup-report.sh --source all --verbose

# Look for merged findings that don't belong together
# Example false positive:
#   "CVE-2025-1234 in openssl" merged with "CVE-2025-1234 in libssl"
#   These are actually the same CVE in the same library (different package name)
#   → This is a CORRECT merge
#
# Actual false positive:
#   "Pod running as root" merged across different pods
#   → These are different pods, should NOT merge
```

**Fix:** Tighten the threshold:
```python
# shared/deduplicator.py
DEDUP_THRESHOLD = 0.9    # was 0.8 — now requires stronger match
```

**Or:** Improve the dedup key to include more specificity:
```python
# In mapper.py, make asset_id more specific
asset_id = f"{namespace}/{pod_name}"    # instead of just pod_name
```

### Problem: False negatives (missing obvious duplicates)

```bash
# Look for findings that should have been merged but weren't
bash tools/list-findings.sh --source all --severity critical --format json | \
  jq -r '.[] | [.source, .cve_id, .asset_id, .title] | @tsv' | sort -k2,2 -k3,3

# If you see same CVE + same asset from different sources → dedup missed it
```

**Fix:** Loosen the threshold:
```python
DEDUP_THRESHOLD = 0.7    # was 0.8
```

**Or:** Normalize asset names before comparison:
```python
# In normalizer.py, add asset normalization
def normalize_asset(asset_id):
    """Normalize asset identifiers across vendors."""
    # Strip registry prefixes
    asset_id = re.sub(r'^(docker\.io/|ghcr\.io/|ecr\..*\.amazonaws\.com/)', '', asset_id)
    # Normalize image tags
    asset_id = re.sub(r':latest$', '', asset_id)
    # Normalize hostnames
    asset_id = asset_id.lower().split('.')[0]  # just hostname, no FQDN
    return asset_id
```

---

## CORRELATION PATTERNS

Beyond dedup, correlation finds relationships between findings from different sources.

### Pattern 1: CVE + Runtime = Active Exploitation

```
Trivy:  CVE-2025-9999 in payments-api image (VULNERABILITY)
Falco:  Shell spawned in payments-api pod (RUNTIME_DETECTION)
Falcon: Suspicious process in payments-api node (RUNTIME_DETECTION)

Correlation: The CVE may be actively exploited.
  → Escalate to B-rank (human review)
  → Tag: "possible_active_exploitation"
```

### Pattern 2: Misconfiguration + Exposure = Attack Surface

```
Checkov: S3 bucket has public read ACL (MISCONFIGURATION)
Wiz:     S3 bucket contains PII (DATA_FINDING)

Correlation: Public bucket with sensitive data.
  → Escalate to S-rank (human only — data breach risk)
  → Tag: "exposed_sensitive_data"
```

### Pattern 3: IAM + Lateral Movement = Privilege Escalation Path

```
Wiz:    IAM role allows AssumeRole to admin (IAM_RISK)
Falcon: Credential dumping detected on node (RUNTIME_DETECTION)

Correlation: Attacker may pivot from node to cloud admin.
  → Escalate to S-rank
  → Tag: "privilege_escalation_path"
```

### Implementing correlation rules

```python
# correlation_rules.py — future enhancement

def check_active_exploitation(findings):
    """Detect CVE + runtime combo on same asset."""
    vulns = {f.asset_id: f for f in findings if f.finding_type == FindingType.VULNERABILITY}
    runtime = [f for f in findings if f.finding_type == FindingType.RUNTIME_DETECTION]

    for rt in runtime:
        if rt.asset_id in vulns:
            vuln = vulns[rt.asset_id]
            yield {
                "type": "ACTIVE_EXPLOITATION",
                "vulnerability": vuln.source_id,
                "runtime_event": rt.source_id,
                "asset": rt.asset_id,
                "recommended_rank": "B",
                "tag": "possible_active_exploitation",
            }
```

---

## DEDUP METRICS TO TRACK

| Metric | What it tells you | Target |
|--------|------------------|--------|
| **Dedup rate** | % of findings eliminated as duplicates | 15-40% |
| **Cross-source match rate** | % matches between vendors | 10-25% per pair |
| **False positive rate** | % of incorrect merges | < 1% |
| **False negative rate** | % of missed merges | < 5% |
| **Net new per vendor** | Unique findings only that vendor sees | Higher = more value |

```bash
# Generate all metrics
bash tools/dedup-report.sh --source all

# Per-vendor breakdown
for vendor in falcon wiz prisma aqua; do
  echo "=== $vendor ==="
  bash tools/dedup-report.sh --source "$vendor"
done
```

---

## BEST PRACTICES

1. **Start with Falcon** — it has the richest data and most overlap with internal scanners
2. **Add vendors one at a time** — validate dedup after each addition before adding the next
3. **Review dedup report after every new vendor** — check for new false positives
4. **Normalize asset names early** — different vendors call the same image by different names
5. **Don't dedup across asset types** — a CVE on image A and image B are two separate problems
6. **Keep raw payloads** — you may need vendor-specific details during investigation
7. **Log everything** — JSONL audit trail shows exactly which findings were merged and why

---

## COMPLETION CHECKLIST

```
[ ] Dedup threshold set appropriately (default 0.8)
[ ] Asset normalization configured for vendor naming differences
[ ] Dedup report shows acceptable false positive rate (< 1%)
[ ] Dedup report shows acceptable false negative rate (< 5%)
[ ] Cross-source matches validated manually (spot check 10 merges)
[ ] Net new findings per vendor documented
[ ] Correlation rules reviewed (if implemented)
[ ] Dedup metrics included in monthly compliance report
```
