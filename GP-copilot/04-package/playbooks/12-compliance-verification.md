# Playbook: Compliance Verification

> Final CIS benchmark pass. Generate the compliance report showing before/after scores. Map findings to frameworks.
>
> **When:** After all perfection playbooks completed. This is the final validation.
> **Time:** ~20 min

---

## Prerequisites

- Playbooks 02-11 completed
- Initial audit results from [01-specialist-audit](01-specialist-audit.md) saved in `/tmp/kubester-audit/`

---

## Step 1: Final CIS Benchmark

Run the same scanners as playbook 01, now measuring improvement:

```bash
mkdir -p /tmp/kubester-audit/final

# kube-bench
kube-bench run --targets master,node,etcd,policies > /tmp/kubester-audit/final/kube-bench.txt

# Kubescape
kubescape scan framework nsa,cis-v1.23-t1.0.1 -o /tmp/kubester-audit/final/kubescape.json --format json -v

# Polaris
polaris audit --format=json > /tmp/kubester-audit/final/polaris.json
```

---

## Step 2: Compare Before/After

```bash
echo "=== BEFORE (playbook 01) ==="
BEFORE_FAIL=$(grep -c '\[FAIL\]' /tmp/kubester-audit/kube-bench.txt 2>/dev/null || echo "N/A")
echo "kube-bench FAIL: $BEFORE_FAIL"

echo ""
echo "=== AFTER (playbook 12) ==="
AFTER_FAIL=$(grep -c '\[FAIL\]' /tmp/kubester-audit/final/kube-bench.txt)
echo "kube-bench FAIL: $AFTER_FAIL"

echo ""
if [ "$BEFORE_FAIL" != "N/A" ] && [ "$AFTER_FAIL" -lt "$BEFORE_FAIL" ]; then
    echo "Improvement: $((BEFORE_FAIL - AFTER_FAIL)) fewer failures"
else
    echo "Compare manually: /tmp/kubester-audit/ vs /tmp/kubester-audit/final/"
fi
```

```bash
# Kubescape score comparison
BEFORE_SCORE=$(cat /tmp/kubester-audit/kubescape.json 2>/dev/null | jq -r '.summaryDetails.complianceScore // "N/A"')
AFTER_SCORE=$(cat /tmp/kubester-audit/final/kubescape.json | jq -r '.summaryDetails.complianceScore // "N/A"')

echo "Kubescape compliance score:"
echo "  Before: ${BEFORE_SCORE}%"
echo "  After:  ${AFTER_SCORE}%"
```

---

## Step 3: Run the Domain Audit (Final)

```bash
bash ~/GP-copilot/GP-CONSULTING/04-KUBESTER/tools/domain-audit.sh --all 2>&1 | tee /tmp/kubester-audit/final/domain-audit.txt

# Count PASS vs FAIL vs WARN
echo ""
echo "=== Final Domain Audit Summary ==="
echo "PASS: $(grep -c '\[PASS\]' /tmp/kubester-audit/final/domain-audit.txt)"
echo "FAIL: $(grep -c '\[FAIL\]' /tmp/kubester-audit/final/domain-audit.txt)"
echo "WARN: $(grep -c '\[WARN\]' /tmp/kubester-audit/final/domain-audit.txt)"
```

---

## Step 4: Remaining Failures — Accepted Risk

Any remaining `[FAIL]` items need to be documented as accepted risk with justification:

```bash
echo "=== Accepted Risks ===" > /tmp/kubester-audit/final/accepted-risks.md
echo "" >> /tmp/kubester-audit/final/accepted-risks.md
echo "| Finding | Reason | Owner | Review Date |" >> /tmp/kubester-audit/final/accepted-risks.md
echo "|---------|--------|-------|-------------|" >> /tmp/kubester-audit/final/accepted-risks.md

# Add remaining failures
grep '\[FAIL\]' /tmp/kubester-audit/final/kube-bench.txt | while read line; do
    echo "| $line | TODO | TODO | $(date -d '+90 days' +%Y-%m-%d) |" >> /tmp/kubester-audit/final/accepted-risks.md
done

echo "Document accepted risks: /tmp/kubester-audit/final/accepted-risks.md"
```

---

## Step 5: FedRAMP Mapping (If Required)

If the engagement includes FedRAMP compliance:

```bash
# Run the FedRAMP gap analysis
bash ~/GP-copilot/GP-CONSULTING/07-FEDRAMP-READY/tools/run-fedramp-scan.sh 2>/dev/null

# Map K8s findings to NIST 800-53 controls
python3 ~/GP-copilot/GP-CONSULTING/07-FEDRAMP-READY/tools/gap-analysis.py 2>/dev/null
```

> **Reference:** `02-CLUSTER-HARDENING/playbooks/09-compliance-report.md` for CIS/NIST/SOC2 mapping.

---

## Step 6: Generate Final Report

```bash
cat > /tmp/kubester-audit/final/KUBESTER-REPORT.md <<EOF
# KUBESTER Specialist Engagement Report

**Cluster:** $(kubectl config current-context 2>/dev/null)
**Date:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Engineer:** KUBESTER (04-KUBESTER package)

## Score Summary

| Scanner | Before | After |
|---------|--------|-------|
| kube-bench FAIL | ${BEFORE_FAIL} | ${AFTER_FAIL} |
| Kubescape | ${BEFORE_SCORE}% | ${AFTER_SCORE}% |

## Playbooks Executed

| # | Playbook | Status |
|---|----------|--------|
| 01 | Specialist Audit | Complete |
| 02 | Platform Integrity | Complete |
| 03 | API Server & etcd | Complete |
| 04 | RBAC Perfection | Complete |
| 05 | Admission Perfection | Complete |
| 06 | Pod Security Perfection | Complete |
| 07 | Network Perfection | Complete |
| 08 | Secrets Perfection | Complete |
| 09 | Supply Chain Perfection | Complete |
| 10 | Runtime Perfection | Complete |
| 11 | Storage & Workloads | Complete |
| 12 | Compliance Verification | Complete |

## Artifacts

- kube-bench report: /tmp/kubester-audit/final/kube-bench.txt
- Kubescape report: /tmp/kubester-audit/final/kubescape.json
- Polaris report: /tmp/kubester-audit/final/polaris.json
- Domain audit: /tmp/kubester-audit/final/domain-audit.txt
- Accepted risks: /tmp/kubester-audit/final/accepted-risks.md

## Accepted Risks

See: /tmp/kubester-audit/final/accepted-risks.md
EOF

echo ""
echo "Report generated: /tmp/kubester-audit/final/KUBESTER-REPORT.md"
```

---

## Next

→ [13-handoff.md](13-handoff.md) — Document, hand off, ongoing maintenance
