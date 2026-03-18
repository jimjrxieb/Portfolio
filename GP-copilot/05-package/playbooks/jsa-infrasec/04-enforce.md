# Phase 4: Autonomous Enforcement

Source playbooks: `02-CLUSTER-HARDENING/playbooks/06-deploy-admission-control.md`, `07-audit-to-enforce.md`
Automation level: **57% autonomous (D-rank)**, 29% JADE (C-rank), 14% human (B-rank)

## What the Agent Does

```
1. Select admission engine (JADE C-rank)
2. Deploy policies in AUDIT mode (D-rank)
3. Test policies against known manifests (D-rank)
4. Observe for 1 week (violations logged, nothing blocked)
5. Classify violations (JADE C-rank)
6. Progressive: audit → warn (D-rank) → enforce (B-rank human approval)
```

This is a MULTI-WEEK phase. The agent deploys in audit mode immediately,
then schedules the audit→enforce progression for later.

## Step-by-Step

### 1. Engine Selection — C-rank (JADE)

```
ESCALATE to JADE:
  "Select admission engine for this cluster."
  Context:
  - Existing tools: ${EXISTING_ADMISSION_TOOLS}
  - Team: ${TEAM_PROFILE}
  - Compliance: ${COMPLIANCE_REQUIREMENTS}

  Decision matrix:
  - Kyverno: simpler, YAML-native, better for K8s-native teams
  - Gatekeeper: more powerful, OPA/Rego, better for compliance/audit
  - Both: defense-in-depth (only for mature teams)

  Default if JADE unavailable: Kyverno (simpler, safer)
```

### 2. Deploy in Audit Mode — D-rank

```bash
02-CLUSTER-HARDENING/tools/admission/deploy-policies.sh \
  --engine ${ENGINE} \
  --mode audit \
  --policies 02-CLUSTER-HARDENING/templates/policies/${ENGINE}/

# Verify deployment:
if [ "$ENGINE" = "kyverno" ]; then
  kubectl get clusterpolicies.kyverno.io
  kubectl get clusterpolicies -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.validationFailureAction}{"\n"}{end}'
  # All should show "Audit"
elif [ "$ENGINE" = "gatekeeper" ]; then
  kubectl get constrainttemplates.templates.gatekeeper.sh
  kubectl get constraints
fi
```

Policy set (20+ policies):
- Pod security: run-as-nonroot, drop-all-caps, disallow-privileged, readonly-rootfs
- Supply chain: disallow-latest-tag, require-semver-tags
- Resource mgmt: require-resource-limits
- Network: require-pss-labels, disallow-external-ips
- RBAC: disallow-cluster-admin-binding

### 3. Test Policies — D-rank

```bash
02-CLUSTER-HARDENING/tools/admission/test-policies.sh --engine ${ENGINE}

# Tests known-good manifests (should pass)
# Tests known-bad manifests (should detect violations)
# Reports: pass/fail per policy
```

### 4. Observation Period — D-rank (passive)

```
Deploy date: ${DEPLOY_DATE}
Observation ends: ${DEPLOY_DATE + 7 days}

During observation:
- Agent monitors policy violation events
- Logs all violations to ${OUTPUT_DIR}/audit/violations.jsonl
- Groups by: policy, resource kind, namespace, frequency
- No enforcement — violations are logged only
```

Collect violations:
```bash
# Kyverno
kubectl get policyreports -A -o json | jq '.items[] | select(.results[].result=="fail")'

# Gatekeeper
kubectl get constraintstatuses -A -o json

# Events
kubectl get events -A --field-selector reason=PolicyViolation -o json
```

### 5. Classify Violations — C-rank (JADE)

After observation period:

```
ESCALATE to JADE:
  "Classify audit-mode violations. For each violation type:"

  1. True positive → workload must be fixed before enforce
     Example: Deployment running as root with no business reason

  2. Legitimate exception → create PolicyException
     Example: DaemonSet needing SYS_ADMIN for node monitoring
     Example: init container running as root for filesystem setup

  Provide: violation list grouped by type, affected workloads, frequency.
  JADE returns: classification per type, PolicyException YAML if needed.
```

### 6. Progressive Enforcement

**Audit → Warn — D-rank (automated)**:
```bash
02-CLUSTER-HARDENING/tools/admission/audit-to-enforce.sh \
  --engine ${ENGINE} --target-mode warn

# Warn mode: violations logged AND users see warnings, but NOT blocked
```

**Warn → Enforce — B-rank (human approval required)**:

```
ESCALATE to human:
  "Ready to move admission policies to ENFORCE mode."
  "This will BLOCK non-compliant deployments."

  Provide:
  - Policies to enforce: ${POLICY_LIST}
  - Exceptions created: ${EXCEPTION_LIST}
  - Current violation count: ${VIOLATION_COUNT} (should be 0)
  - Observation duration: ${DAYS_IN_AUDIT} days
  - CI conftest gate deployed: ${CI_GATE_STATUS}

  Options:
  1. Enforce all policies (recommended if violations = 0)
  2. Enforce critical-only (run-as-nonroot, drop-caps, disallow-privileged)
  3. Extend observation by 1 week

  IMPORTANT: Enforcement without CI gate = developers surprised by blocked deploys.
  Ensure Phase 5 (wire CI/CD) completes first.
```

```bash
# After human approval:
02-CLUSTER-HARDENING/tools/admission/audit-to-enforce.sh \
  --engine ${ENGINE} --target-mode enforce
```

## Phase 4 Gate

```
PASS if: admission control deployed AND at least audit mode active
  → Continue to Phase 5 immediately (don't wait for enforce)
  → Schedule enforce progression after observation period
FAIL: Report deployment failure, continue to Phase 5
```
