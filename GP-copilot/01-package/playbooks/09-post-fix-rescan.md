# Playbook: Post-Fix Rescan

> Re-run all scanners after fixes, compare before/after, and produce the client deliverable.
>
> **When:** After completing fix playbooks (02-06). This proves the work.
> **Time:** ~15 min (same as baseline scan + comparison)

---

## The Rule

Every fix needs proof. "We fixed it" means nothing without a rescan showing the finding is gone. The before/after comparison is the deliverable.

---

## Step 1: Re-Run All Scanners

```bash
# Same command as baseline, but with --label post-fix
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/tools/run-all-scanners.sh \
  --target-dir ~/linkops-industries/GP-copilot/GP-PROJECTS/01-instance/slot-1/<client-repo> \
  --label post-fix
```

Output lands in `GP-S3/5-consulting-reports/<instance>/<slot>/post-fix-YYYYMMDD/`.

If you ran DAST in the baseline, include it again:
```bash
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/tools/run-all-scanners.sh \
  --target-dir ~/linkops-industries/GP-copilot/GP-PROJECTS/01-instance/slot-1/<client-repo> \
  --label post-fix \
  --dast --target-url https://staging.example.com
```

---

## Step 2: Triage the Post-Fix Results

```bash
python3 ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/tools/triage.py \
  --scan-dir ~/linkops-industries/GP-copilot/GP-S3/5-consulting-reports/01-instance/slot-1/post-fix-$(date +%Y%m%d) \
  --project <client-slug>
```

---

## Step 3: Compare Before and After

### Quick Count Comparison

```bash
BASELINE=~/linkops-industries/GP-copilot/GP-S3/5-consulting-reports/01-instance/slot-1/baseline-YYYYMMDD
POSTFIX=~/linkops-industries/GP-copilot/GP-S3/5-consulting-reports/01-instance/slot-1/post-fix-YYYYMMDD

echo "=== Secrets ==="
echo "Before: $(jq 'length' $BASELINE/gitleaks.json 2>/dev/null || echo 0)"
echo "After:  $(jq 'length' $POSTFIX/gitleaks.json 2>/dev/null || echo 0)"

echo "=== Python SAST (HIGH) ==="
echo "Before: $(jq '[.results[] | select(.issue_severity=="HIGH")] | length' $BASELINE/bandit.json 2>/dev/null || echo 0)"
echo "After:  $(jq '[.results[] | select(.issue_severity=="HIGH")] | length' $POSTFIX/bandit.json 2>/dev/null || echo 0)"

echo "=== Dependency CVEs (CRITICAL) ==="
echo "Before: $(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' $BASELINE/trivy-fs.json 2>/dev/null || echo 0)"
echo "After:  $(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' $POSTFIX/trivy-fs.json 2>/dev/null || echo 0)"

echo "=== IaC Failed Checks ==="
echo "Before: $(jq '.results.failed_checks | length' $BASELINE/results_json.json 2>/dev/null || echo 0)"
echo "After:  $(jq '.results.failed_checks | length' $POSTFIX/results_json.json 2>/dev/null || echo 0)"
```

### Detailed Diff (What Findings Were Resolved)

```bash
# Gitleaks: which secrets were removed?
diff <(jq -r '.[].RuleID' $BASELINE/gitleaks.json 2>/dev/null | sort) \
     <(jq -r '.[].RuleID' $POSTFIX/gitleaks.json 2>/dev/null | sort)

# Bandit: which SAST findings were fixed?
diff <(jq -r '.results[] | "\(.test_id) \(.filename):\(.line_number)"' $BASELINE/bandit.json 2>/dev/null | sort) \
     <(jq -r '.results[] | "\(.test_id) \(.filename):\(.line_number)"' $POSTFIX/bandit.json 2>/dev/null | sort)
```

---

## Step 4: Parse Into SQL (Track Over Time)

```bash
cd ~/linkops-industries/GP-copilot/GP-S3/4-sql
python3 parse_findings.py parse \
  --scan-dir ../5-consulting-reports/01-instance/slot-1/post-fix-$(date +%Y%m%d) \
  --project <client-slug>-postfix-$(date +%Y%m%d)

# Compare in SQL
python3 parse_findings.py query --db code \
  "SELECT project, severity, COUNT(*) FROM findings GROUP BY project, severity ORDER BY project, severity"
```

---

## Step 5: Produce the Client Report

### Progress Report Template

```markdown
# Security Remediation Report — {{CLIENT_NAME}}
Date: {{DATE}}

## Before / After

| Category | Baseline | Post-Fix | Reduction |
|----------|----------|----------|-----------|
| Hardcoded Secrets | {{BEFORE_SECRETS}} | {{AFTER_SECRETS}} | {{PCT}}% |
| Critical CVEs | {{BEFORE_CRIT}} | {{AFTER_CRIT}} | {{PCT}}% |
| High SAST Findings | {{BEFORE_HIGH}} | {{AFTER_HIGH}} | {{PCT}}% |
| Dockerfile Issues | {{BEFORE_DOCKER}} | {{AFTER_DOCKER}} | {{PCT}}% |
| IaC Misconfigs | {{BEFORE_IAC}} | {{AFTER_IAC}} | {{PCT}}% |

## What Was Fixed
- {{SECRET_COUNT}} hardcoded secrets removed and rotated
- {{DEP_COUNT}} vulnerable dependencies upgraded
- {{SAST_COUNT}} code vulnerabilities fixed
- {{CONTAINER_COUNT}} Dockerfiles hardened
- {{WEB_COUNT}} web security headers added

## Remaining Findings
- {{C_COUNT}} medium findings (documented, require architecture review)
- {{B_COUNT}} low findings (accepted risk, in POA&M)
- {{NOPATCH}} dependencies with no fix available (monitoring monthly)

## Continuous Monitoring Deployed
- [x] Pre-commit hooks installed
- [x] CI/CD pipeline deployed
- [x] Nightly scan scheduled
- [ ] Weekly trend report configured
```

---

## Step 6: Set Up Ongoing Monitoring

```bash
# Weekly rescan (add to crontab or GHA schedule)
# The CI pipeline already handles per-PR and nightly scans.
# For weekly trend reports:

bash ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/tools/run-all-scanners.sh \
  --target-dir <client-repo> \
  --label weekly
```

---

## What "Done" Looks Like

- 0 hardcoded secrets
- 0 critical CVEs
- 80%+ reduction in HIGH findings
- All Dockerfiles have USER + HEALTHCHECK
- CI pipeline passing and required for merge
- Pre-commit hooks installed
- Remaining findings documented in POA&M

---

## Next Steps

- Back to engagement overview? → [ENGAGEMENT-GUIDE.md](../ENGAGEMENT-GUIDE.md)
- Move to cluster hardening? → [02-CLUSTER-HARDENING](../../02-CLUSTER-HARDENING/ENGAGEMENT-GUIDE.md)
- Deploy runtime defense? → [03-DEPLOY-RUNTIME](../../03-DEPLOY-RUNTIME/ENGAGEMENT-GUIDE.md)

---

*Ghost Protocol — Pre-Deployment Security Package*
