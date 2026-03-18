# Playbook 10: Continuous Compliance
### Controls: CA-7, SI-4 (ongoing)

---

## WHAT THIS IS

FedRAMP authorization is not a one-time event. After ATO, you must maintain continuous compliance or lose authorization. This playbook defines the ongoing operational cadence.

---

## THE COMPLIANCE CALENDAR

| Frequency | Activity | Control |
|-----------|----------|---------|
| **Every commit** | SAST + SCA + secret scan in CI | RA-5, SI-2 |
| **Every deploy** | Container scan + policy check | CM-6, SI-2 |
| **Daily** | Review Falco/Prometheus alerts | SI-4 |
| **Weekly** | Audit log review | AU-6 |
| **Monthly** | Compliance scan + report | CA-7 |
| **Quarterly** | Account review | AC-2 |
| **Quarterly** | POA&M review with remediation status | CA-2 |
| **Annually** | IR tabletop exercise | IR-4 |
| **Annually** | Full re-assessment by 3PAO | CA-2 |
| **On change** | SSP update for significant changes | CM-2 |

---

## CI/CD COMPLIANCE PIPELINE

Every code change automatically generates compliance evidence.

### On every commit (PR scan)

```yaml
# .github/workflows/pr-compliance.yml
name: PR Compliance Check
on: pull_request

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Secret scan
        run: gitleaks detect --source . --exit-code 1

      - name: SAST
        run: semgrep --config auto --error --severity ERROR .

      - name: Dependency scan
        run: trivy fs --exit-code 1 --severity CRITICAL .

      - name: IaC scan
        run: checkov -d k8s/ --framework kubernetes --compact --hard-fail-on CRITICAL
```

### On merge to main (deploy pipeline)

```yaml
# .github/workflows/deploy-compliance.yml
name: Deploy with Compliance Evidence
on:
  push:
    branches: [main]

jobs:
  build-scan-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t $IMAGE:${{ github.sha }} .

      - name: Scan image
        run: |
          trivy image --format json --output trivy-image.json $IMAGE:${{ github.sha }}
          trivy image --exit-code 1 --severity CRITICAL $IMAGE:${{ github.sha }}

      - name: NIST mapping
        run: |
          python3 tools/scan-and-map.py \
            --target . \
            --output evidence/deploy-$(date +%Y%m%d)-${{ github.run_number }}

      - name: Archive evidence
        uses: actions/upload-artifact@v4
        with:
          name: compliance-evidence-${{ github.run_number }}
          path: evidence/
          retention-days: 365

      - name: Deploy via GitOps
        run: |
          # Update image tag in manifests repo
          # ArgoCD picks up the change automatically
```

### Weekly scheduled scan

```yaml
# .github/workflows/weekly-compliance.yml
name: Weekly Compliance Scan
on:
  schedule:
    - cron: '0 6 * * 1'    # Monday 6am UTC

jobs:
  full-compliance-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Full scan suite
        run: |
          /path/to/GP-CONSULTING/07-FEDRAMP-READY/tools/run-fedramp-scan.sh \
            --target . \
            --output evidence/weekly-$(date +%Y%m%d) \
            --project "weekly-compliance-$(date +%Y%m%d)"

      - name: Compare to last week
        run: |
          # Diff this week's control matrix against last week's
          # Alert if any control status degraded (MET → PARTIAL or MISSING)

      - name: Archive
        uses: actions/upload-artifact@v4
        with:
          name: weekly-compliance-$(date +%Y%m%d)
          path: evidence/
          retention-days: 365
```

---

## MONTHLY COMPLIANCE REPORT

Generate and file this every month. The FedRAMP PMO expects it.

```bash
#!/bin/bash
# monthly-compliance-report.sh
# Run on the 1st of every month

MONTH=$(date -d "last month" +%B\ %Y)
OUTPUT="evidence/monthly-reports/compliance-$(date -d 'last month' +%Y%m).md"
mkdir -p "$(dirname "$OUTPUT")"

cat > "$OUTPUT" << HEADER
# Monthly Continuous Monitoring Report
## $MONTH

### 1. Vulnerability Status
HEADER

# Current vulnerability counts
echo "| Severity | Count |" >> "$OUTPUT"
echo "|----------|-------|" >> "$OUTPUT"
trivy fs --format json . 2>/dev/null | \
  jq -r '[.Results[]?.Vulnerabilities[]?.Severity] | group_by(.) | .[] | "| \(.[0]) | \(length) |"' >> "$OUTPUT"

echo "" >> "$OUTPUT"
echo "### 2. Control Status" >> "$OUTPUT"
echo "See attached control-matrix.md from latest scan." >> "$OUTPUT"

echo "" >> "$OUTPUT"
echo "### 3. POA&M Updates" >> "$OUTPUT"
echo "| Status | Count |" >> "$OUTPUT"
echo "|--------|-------|" >> "$OUTPUT"
echo "| Open | $(grep -c 'In Progress\|Planned' poam.md 2>/dev/null || echo 0) |" >> "$OUTPUT"
echo "| Closed this month | (manually fill) |" >> "$OUTPUT"
echo "| Overdue | (manually fill) |" >> "$OUTPUT"

echo "" >> "$OUTPUT"
echo "### 4. Incidents" >> "$OUTPUT"
echo "| Metric | Value |" >> "$OUTPUT"
echo "|--------|-------|" >> "$OUTPUT"
echo "| Total incidents | (fill) |" >> "$OUTPUT"
echo "| P1/P2 incidents | (fill) |" >> "$OUTPUT"
echo "| Average MTTR | (fill) |" >> "$OUTPUT"

echo "" >> "$OUTPUT"
echo "### 5. Significant Changes" >> "$OUTPUT"
echo "- (List any architecture changes, new components, or control modifications)" >> "$OUTPUT"

echo "" >> "$OUTPUT"
echo "### 6. Scan Evidence" >> "$OUTPUT"
echo "Weekly scans attached: $(ls evidence/weekly-* 2>/dev/null | wc -l) scans this month" >> "$OUTPUT"

echo "Report generated: $OUTPUT"
```

---

## QUARTERLY ACTIVITIES

### Account review (AC-2)

```bash
# Run the quarterly review script
./scripts/quarterly-account-review.sh > evidence/account-review-Q$(date +%q)-$(date +%Y).txt

# Review output for:
# - Inactive users (disable or justify)
# - Missing MFA (enforce)
# - Over-privileged RBAC (tighten)
# - Stale access keys (rotate or deactivate)
```

### POA&M review

```bash
# Regenerate gap analysis to see current state
python3 tools/gap-analysis.py \
  --evidence-dir evidence/weekly-$(date +%Y%m%d) \
  --output evidence/quarterly-poam-$(date +%Y%m%d)

# Compare with previous POA&M:
# - Which items were fixed?
# - Which are overdue?
# - Any new findings?
# Update POA&M with current status
```

---

## SIGNIFICANT CHANGE TRIGGERS

When any of these happen, update the SSP and notify the FedRAMP PMO:

```
[ ] New service or component added to the system boundary
[ ] Change in data classification or data types processed
[ ] Change in external interconnections
[ ] Change in authentication mechanism
[ ] Change in encryption approach
[ ] Major infrastructure change (new VPC, region, etc.)
[ ] Change in CSP (moving services between AWS accounts)
[ ] Security incident (P1/P2)
[ ] New vulnerability that affects a control
```

For each change:
1. Update the SSP to reflect the new state
2. Run a targeted scan on the affected area
3. Update the control matrix if status changed
4. Notify the FedRAMP PMO within 30 days (for significant changes)

---

## EVIDENCE RETENTION

| Evidence type | Retention | Storage |
|--------------|-----------|---------|
| CI/CD scan artifacts | 1 year minimum | GitHub Actions artifact retention |
| Weekly scan results | 3 years | S3 (encrypted, versioned) |
| Monthly reports | 3 years | S3 + Git |
| Audit logs | 3 years | CloudWatch + S3 archive |
| Incident records | 3 years | Git + ticketing system |
| Account reviews | 3 years | Git |
| POA&M history | 3 years | Git (version history) |
| SSP versions | 3 years | Git (version history) |

```bash
# S3 lifecycle policy for evidence archival
aws s3api put-bucket-lifecycle-configuration \
  --bucket fedramp-evidence \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "ArchiveOldEvidence",
      "Status": "Enabled",
      "Transitions": [
        {"Days": 90, "StorageClass": "STANDARD_IA"},
        {"Days": 365, "StorageClass": "GLACIER"}
      ],
      "Expiration": {"Days": 1095}
    }]
  }'
```

---

## AUTOMATION SUMMARY

| What | Tool | Frequency |
|------|------|-----------|
| Code scanning | Trivy + Semgrep + Gitleaks | Every commit |
| Container scanning | Trivy image | Every build |
| Policy validation | Conftest + Kyverno | Every deploy |
| NIST mapping | scan-and-map.py | Every build |
| Gap analysis | gap-analysis.py | Weekly + on demand |
| Runtime monitoring | Falco + Prometheus | Continuous |
| Audit log review | Automated alerts + weekly manual | Continuous + weekly |
| Component inventory | generate-inventory.sh | Weekly |
| Account review | quarterly-account-review.sh | Quarterly |
| Monthly report | monthly-compliance-report.sh | Monthly |
| Full re-assessment | run-fedramp-scan.sh | Annually (+ weekly) |

---

## COMPLETION CHECKLIST

```
[ ] CI pipeline scans every commit (SAST, SCA, secrets)
[ ] Deploy pipeline scans every image
[ ] Weekly compliance scan scheduled
[ ] Monthly report template ready and generating
[ ] Quarterly account review process active
[ ] Quarterly POA&M review process active
[ ] Evidence retention configured (1-3 years)
[ ] S3 lifecycle policy for evidence archival
[ ] Significant change notification process documented
[ ] Annual 3PAO re-assessment scheduled
[ ] All scan evidence uploading to artifact storage
[ ] Alerting pipeline active (Falco → Slack, Prometheus → PagerDuty)
```
