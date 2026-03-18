# Phase 5: Autonomous Validation

Source playbooks: `02-CLUSTER-HARDENING/playbooks/08-wire-cicd.md`, `09-compliance-report.md`
Automation level: **100% autonomous (E/D-rank)**

This is the only fully autonomous phase — no JADE or human decisions needed.

## What the Agent Does

```
1. Wire conftest policies into CI/CD pipeline
2. Generate compliance matrix (CIS, NIST, CKS mapping)
3. Post-hardening rescan (Kubescape, kube-bench, Polaris)
4. Before/after comparison
5. Generate final hardening report
```

## Step-by-Step

### 1. Wire CI/CD — D-rank

```bash
# Copy conftest policies to client repo
mkdir -p ${TARGET_REPO}/policy/
cp 02-CLUSTER-HARDENING/templates/policies/conftest/*.rego ${TARGET_REPO}/policy/

# Set up CI gate
02-CLUSTER-HARDENING/tools/platform/setup-cicd.sh \
  --repo ${TARGET_REPO} \
  --ci-system ${CI_SYSTEM}

# Test gate
conftest test ${TARGET_REPO}/k8s/ --policy ${TARGET_REPO}/policy/ --output json \
  > ${OUTPUT_DIR}/conftest-test.json
```

### 2. Compliance Matrix — E-rank

```bash
python3 02-CLUSTER-HARDENING/tools/admission/policy-coverage-report.py \
  --output ${OUTPUT_DIR}/compliance/

# Generates:
# compliance-matrix.md — human-readable coverage table
# cis-coverage.json — CIS benchmark control mapping
# nist-mapping.json — NIST 800-53 control mapping
# cks-coverage.json — CKS exam domain mapping
```

### 3. Post-Hardening Rescan — E-rank

```bash
# Same scanners as Phase 2, new output
kubescape scan --format json --output ${OUTPUT_DIR}/audit/kubescape-post.json
kube-bench run --json > ${OUTPUT_DIR}/audit/kube-bench-post.json 2>/dev/null
polaris audit --format json > ${OUTPUT_DIR}/audit/polaris-post.json
```

### 4. Score Comparison — D-rank

```bash
BEFORE=$(jq '.summaryDetails.complianceScore' ${OUTPUT_DIR}/audit/kubescape.json)
AFTER=$(jq '.summaryDetails.complianceScore' ${OUTPUT_DIR}/audit/kubescape-post.json)
DELTA=$(echo "$AFTER - $BEFORE" | bc)

echo "Kubescape: ${BEFORE}% → ${AFTER}% (+${DELTA}%)"

# Same for kube-bench pass rate and Polaris score
```

### 5. Final Report — D-rank

Generate `${OUTPUT_DIR}/HARDENING-REPORT.md`:

```markdown
# Cluster Hardening Report — ${CLUSTER_NAME}

## Score Delta
| Scanner | Before | After | Change |
|---------|--------|-------|--------|
| Kubescape | ${BEFORE}% | ${AFTER}% | +${DELTA}% |
| kube-bench | ${KB_BEFORE} pass | ${KB_AFTER} pass | +${KB_DELTA} |
| Polaris | ${POL_BEFORE}% | ${POL_AFTER}% | +${POL_DELTA}% |

## Changes Applied
- NetworkPolicies: ${NP_COUNT} created
- LimitRanges: ${LR_COUNT} created
- ResourceQuotas: ${RQ_COUNT} created
- PSS labels: ${PSS_COUNT} namespaces labeled
- SecurityContext: ${SC_COUNT} workloads patched
- automountServiceAccountToken: ${AM_COUNT} disabled
- Admission policies: ${POL_COUNT} deployed (${POL_MODE} mode)

## RBAC Status
- cluster-admin bindings: ${CA_TOTAL} (${CA_SYSTEM} system, ${CA_USER} user)
- Wildcard permissions: ${WC_COUNT}
- automount disabled: ${AM_DISABLED}/${AM_TOTAL}

## Compliance Coverage
- CIS Benchmark: ${CIS_COVERAGE}%
- NIST 800-53: ${NIST_CONTROLS} controls mapped
- CKS Domains: ${CKS_COVERAGE}%

## CI/CD Gate
- Conftest policies deployed: ${CONFTEST_COUNT}
- CI pipeline wired: ${CI_STATUS}

## Pending Decisions
${B_RANK_LIST}
${S_RANK_LIST}
```

## Outputs

```
${OUTPUT_DIR}/
├── audit/
│   ├── kubescape-post.json
│   ├── kube-bench-post.json
│   └── polaris-post.json
├── compliance/
│   ├── compliance-matrix.md
│   ├── cis-coverage.json
│   ├── nist-mapping.json
│   └── score-delta.json
├── conftest-test.json
└── HARDENING-REPORT.md
```

## Phase 5 Gate

```
PASS if: report generated AND CI gate wired
Continue to Phase 6 (optional platform services)
```
