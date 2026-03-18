# Phase 4: Autonomous Verification

Source playbook: `01-APP-SEC/playbooks/09-post-fix-rescan.md`
Automation level: **83% autonomous (E/D-rank)**, 17% human (B-rank for report)

## What the Agent Does

```
1. Re-run all scanners (same as Phase 1, different label)
2. Triage post-fix results
3. Compare baseline vs post-fix (delta analysis)
4. Update FindingsStore with verification results
5. Generate cascade prevention policies
6. Produce engagement summary (B-rank: human reviews)
```

## Step-by-Step

### 1. Post-Fix Rescan

```bash
01-APP-SEC/tools/run-all-scanners.sh \
  --target ${TARGET_REPO} \
  --label post-fix \
  --output ${OUTPUT_DIR}/post-fix \
  --parallel
```

Same scanners as Phase 1. Same configs. Different output directory.

### 2. Triage Post-Fix

```bash
python3 01-APP-SEC/tools/triage.py \
  --scan-dir ${OUTPUT_DIR}/post-fix \
  --project ${PROJECT_ID}
```

### 3. Delta Analysis

```bash
# Compare finding counts per scanner
for scanner in gitleaks bandit semgrep trivy-fs grype hadolint checkov kubescape; do
  baseline_count=$(jq '. | length' ${OUTPUT_DIR}/baseline/${scanner}.json 2>/dev/null || echo 0)
  postfix_count=$(jq '. | length' ${OUTPUT_DIR}/post-fix/${scanner}.json 2>/dev/null || echo 0)
  delta=$((baseline_count - postfix_count))
  echo "${scanner}: ${baseline_count} → ${postfix_count} (${delta} fixed)"
done
```

Produce `${OUTPUT_DIR}/comparison/delta.json`:
```json
{
  "baseline_total": 147,
  "postfix_total": 43,
  "fixed": 104,
  "fix_rate": 0.71,
  "new_findings": 0,
  "by_scanner": {
    "gitleaks": {"before": 12, "after": 0, "fixed": 12},
    "bandit": {"before": 34, "after": 8, "fixed": 26},
    "...": "..."
  },
  "by_severity": {
    "critical": {"before": 5, "after": 1, "fixed": 4},
    "high": {"before": 42, "after": 12, "fixed": 30},
    "medium": {"before": 67, "after": 22, "fixed": 45},
    "low": {"before": 33, "after": 8, "fixed": 25}
  },
  "by_rank": {
    "E": {"attempted": 13, "verified": 13, "rate": 1.0},
    "D": {"attempted": 35, "verified": 31, "rate": 0.89},
    "C": {"attempted": 8, "verified": 6, "rate": 0.75},
    "B": {"escalated": 11, "resolved": 0, "pending": 11}
  }
}
```

### 4. Update FindingsStore

```python
store = FindingsStore()

# Mark verified fixes
for finding in delta["fixed_findings"]:
    store.update_status(finding["id"], "verified")

# Mark remaining findings
for finding in delta["remaining_findings"]:
    store.update_status(finding["id"], "detected")  # stays detected

# Check for regressions (new findings not in baseline)
for finding in delta["new_findings"]:
    store.upsert_finding(finding, agent="jsa-devsec", status="regression")
```

### 5. Generate Cascade Prevention Policies

For every verified fix, generate admission control policies to prevent recurrence:

```python
from cascade_generator import CascadeGenerator

cascade = CascadeGenerator()
for finding in verified_fixes:
    artifacts = cascade.generate(finding)
    # Output: /tmp/jsa-cascade/kyverno-*.yaml
    #         /tmp/jsa-cascade/gatekeeper-*.yaml
    #         /tmp/jsa-cascade/conftest-*.rego
    store.upsert_cascade_artifacts(finding["id"], artifacts)
```

Cascade artifacts go to `/tmp/jsa-cascade/` for human review.
**Never auto-apply admission policies.** That's jsa-infrasec's domain.

### 6. Engagement Summary

Generate `${OUTPUT_DIR}/ENGAGEMENT-SUMMARY.md`:

```markdown
# Security Engagement Summary — ${PROJECT_ID}

## Results

| Metric | Value |
|--------|-------|
| Findings detected | ${baseline_total} |
| Auto-fixed (E/D) | ${fixed_ed} |
| JADE-approved (C) | ${fixed_c} |
| Escalated to human (B) | ${escalated_b} |
| Remaining | ${remaining} |
| Fix rate | ${fix_rate}% |
| New findings (regression) | ${new_count} |

## By Category

| Category | Before | After | Fixed |
|----------|--------|-------|-------|
| Secrets | ... | ... | ... |
| Dependencies | ... | ... | ... |
| Python SAST | ... | ... | ... |
| Dockerfiles | ... | ... | ... |
| Web Security | ... | ... | ... |
| K8s Manifests | ... | ... | ... |
| Supply Chain | ... | ... | ... |

## Prevention Deployed

- [ ] CI security pipeline
- [ ] Scanner configs (${config_count} configs)
- [ ] Pre-commit hooks
- [ ] OPA/Conftest policy (${rule_count} rules)
- [ ] Cascade policies generated (${cascade_count} artifacts)

## Pending Human Decisions

${list of B-rank escalations with context}

## Recommended Next Steps

1. Review and apply cascade policies (jsa-infrasec domain)
2. Resolve B-rank escalations
3. Schedule monthly rescan
```

### B-rank escalation: Report Review

Agent presents the summary to human for:
- Report language and framing for client
- POA&M decisions for remaining findings
- Accepted risk documentation

## Phase 4 Gate

```
IF fix_rate >= 0.7:
  Continue to Phase 5 (if K8s project)
ELIF fix_rate >= 0.5:
  Log warning, continue to Phase 5
ELSE:
  Escalate to human: "Fix rate below 50% — review needed"
  Include failure analysis: which categories underperformed and why
```
