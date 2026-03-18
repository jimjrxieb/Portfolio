# Playbook: Compliance Report

> Generate the final compliance coverage report and client deliverable.
>
> **When:** After enforcement is active. End of engagement deliverable.
> **Time:** ~10 min

---

## Step 1: Generate Coverage Report

```bash
PKG=~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING
REPORTS=~/GP-copilot/GP-S3/5-consulting-reports/<client>

# All frameworks
python3 $PKG/tools/admission/policy-coverage-report.py \
  --framework all \
  --format markdown \
  --output $REPORTS/final-compliance-$(date +%Y%m%d).md

# Specific framework
python3 $PKG/tools/admission/policy-coverage-report.py --framework cis
python3 $PKG/tools/admission/policy-coverage-report.py --framework nist
python3 $PKG/tools/admission/policy-coverage-report.py --framework soc2
python3 $PKG/tools/admission/policy-coverage-report.py --framework pci-dss
python3 $PKG/tools/admission/policy-coverage-report.py --framework cks
```

**What it generates:**
```
Compliance Coverage Report — CIS Kubernetes Benchmark v1.8

Overall Coverage: 62/100 controls (62%)

Section 5: Kubernetes Policies
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
5.2.1 Privileged containers         ✓ ENFORCED  disallow-privileged
5.2.6 Run as non-root               ✓ ENFORCED  require-run-as-nonroot
5.2.7 Privilege escalation           ✓ ENFORCED  disallow-privilege-escalation
5.2.8 Resource limits                ⚠ AUDIT     require-resource-limits

Legend:
✓ ENFORCED - Policy active and enforcing
⚠ AUDIT    - Policy active but not enforcing
✗ MISSING  - No policy for this control
```

---

## Step 2: Run Final Cluster Audit

```bash
bash $PKG/tools/hardening/run-cluster-audit.sh \
  --output $REPORTS/k8s-audit-final-$(date +%Y%m%d).md
```

Compare against the baseline from [01-cluster-audit](01-cluster-audit.md).

---

## Step 3: Before/After Comparison

```bash
# Quick comparison
echo "=== Baseline ==="
head -50 $REPORTS/cluster-audit-BASELINE/k8s-audit.md

echo "=== Final ==="
head -50 $REPORTS/k8s-audit-final-$(date +%Y%m%d).md
```

---

## Step 4: Client Deliverable

### Final Report Template

```markdown
# Cluster Hardening Report — {{CLIENT_NAME}}
Date: {{DATE}}

## Before / After

| Metric | Baseline | Final | Change |
|--------|----------|-------|--------|
| Polaris Score | {{BEFORE}}/100 | {{AFTER}}/100 | +{{DIFF}} |
| kube-bench PASS | {{BEFORE}} | {{AFTER}} | +{{DIFF}} |
| Pods without limits | {{BEFORE}} | {{AFTER}} | -{{DIFF}} |
| Pods running as root | {{BEFORE}} | {{AFTER}} | -{{DIFF}} |
| Namespaces without NetworkPolicy | {{BEFORE}} | {{AFTER}} | -{{DIFF}} |
| cluster-admin bindings | {{BEFORE}} | {{AFTER}} | -{{DIFF}} |

## What Was Deployed
- {{POLICY_COUNT}} admission policies (Kyverno) — {{ENFORCE_COUNT}} enforcing, {{AUDIT_COUNT}} auditing
- NetworkPolicies on all application namespaces
- LimitRange + ResourceQuota on all application namespaces
- PSS labels on all namespaces
- CI/CD policy checks on all PRs
- Prometheus alerts for policy violations

## Compliance Coverage
- CIS Kubernetes Benchmark: {{CIS_PCT}}%
- NIST 800-53 (K8s controls): {{NIST_PCT}}%
- CKS Exam Domains: {{CKS_PCT}}%

## Exceptions Documented
{{EXCEPTION_COUNT}} PolicyExceptions created for legitimate system components.
See attached POA&M for details.
```

---

## Step 5: Parse Into SQL (Track Over Time)

```bash
cd ~/GP-copilot/GP-S3/4-sql
python3 parse_findings.py parse \
  --scan-dir $REPORTS/k8s-audit-final-$(date +%Y%m%d) \
  --project <client-slug>-cluster-final-$(date +%Y%m%d)
```

---

## What "Done" Looks Like

- All critical/high policies enforcing
- 0 violations in PolicyReports (exceptions documented)
- CI pipeline blocking non-compliant manifests
- Prometheus alerts deployed
- Final compliance report delivered to client
- Before/after audit reports in GP-S3

---

## Next Steps

- Move to runtime defense? → [03-DEPLOY-RUNTIME](../../03-DEPLOY-RUNTIME/ENGAGEMENT-GUIDE.md)
- Deploy autonomous agents? → [04-JSA-AUTONOMOUS](../../04-JSA-AUTONOMOUS/ENGAGEMENT-GUIDE.md)
- Back to engagement overview? → [ENGAGEMENT-GUIDE.md](../ENGAGEMENT-GUIDE.md)

---

*Ghost Protocol — K8s Hardening Package (CKA + CKS)*
