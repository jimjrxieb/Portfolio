# Phase 3: Compliance Verification

Source: `04-KUBESTER/playbooks/12-compliance-verification.md`
Automation: **80% autonomous (E/D-rank)**, 20% human (B-rank for accepted risks)

## What the Agent Does

```
1. Rescan everything (same tools as Phase 1)
2. Compare before vs after
3. Document remaining failures as accepted risks (human decides)
4. Optional: FedRAMP gap analysis
5. Generate SPECIALIST-REPORT.md
```

## Step-by-Step

### 1. Final Scan — E-rank

```bash
mkdir -p ${OUTPUT_DIR}/kubester/final/

kubescape scan --format json --output ${OUTPUT_DIR}/kubester/final/kubescape.json
kube-bench run --json > ${OUTPUT_DIR}/kubester/final/kube-bench.json
polaris audit --format json > ${OUTPUT_DIR}/kubester/final/polaris.json
04-KUBESTER/tools/domain-audit.sh --all > ${OUTPUT_DIR}/kubester/final/domain-audit.txt
```

### 2. Before vs After — D-rank

```bash
BEFORE=$(jq '.summaryDetails.complianceScore' ${OUTPUT_DIR}/kubester/kubescape.json)
AFTER=$(jq '.summaryDetails.complianceScore' ${OUTPUT_DIR}/kubester/final/kubescape.json)
echo "Kubescape: ${BEFORE}% → ${AFTER}% (+$(echo "$AFTER - $BEFORE" | bc)%)"

BEFORE_FAIL=$(grep -c '\[FAIL\]' ${OUTPUT_DIR}/kubester/domain-audit.txt)
AFTER_FAIL=$(grep -c '\[FAIL\]' ${OUTPUT_DIR}/kubester/final/domain-audit.txt)
echo "Domain audit [FAIL]: ${BEFORE_FAIL} → ${AFTER_FAIL}"
```

### 3. Accepted Risks — B-rank

```
ESCALATE to human:
  "These findings remain after perfection. Accept or fix?"

  For each remaining [FAIL]:
  - Finding description
  - CKS/CKA domain
  - Why it couldn't be auto-fixed
  - Risk level
  - Suggested justification template:

  | Finding | Justification | Owner | Review Date |
  |---------|--------------|-------|-------------|
  | k3s helm cluster-admin | System dependency, k3s requires | Platform team | 2026-06-17 |
  | local-path-provisioner PSA=privileged | k3s storage, no alternative | Platform team | 2026-06-17 |
```

### 4. FedRAMP (Optional) — D-rank

```bash
# Only if engagement requires FedRAMP
07-FEDRAMP-READY/tools/run-fedramp-scan.sh
python3 07-FEDRAMP-READY/tools/gap-analysis.py
```

### 5. Specialist Report — D-rank

```markdown
# Kubernetes Specialist Report — ${CLUSTER_NAME}

## Executive Summary
Kubescape: ${BEFORE}% → ${AFTER}% (+${DELTA}%)
CIS Benchmark: ${KB_BEFORE} → ${KB_AFTER} pass
Domain audit: ${FAIL_BEFORE} → ${FAIL_AFTER} failures

## CKS Domain Coverage
| Domain | Weight | Before | After | Status |
|--------|--------|--------|-------|--------|
| Cluster Setup | 10% | ${B} | ${A} | ${S} |
| Cluster Hardening | 15% | ${B} | ${A} | ${S} |
| System Hardening | 15% | ${B} | ${A} | ${S} |
| Microservice Vulns | 20% | ${B} | ${A} | ${S} |
| Supply Chain | 20% | ${B} | ${A} | ${S} |
| Monitoring/Runtime | 20% | ${B} | ${A} | ${S} |

## CKA Domain Coverage
(similar table)

## Changes Made
(list of fixes applied per playbook)

## Accepted Risks
(human-approved items with justification)

## Recommendations
(what to do next: ongoing monitoring, cert rotation, etc.)
```
