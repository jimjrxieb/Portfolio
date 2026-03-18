# Playbook: Audit to Enforce

> Progressive rollout from audit mode to enforcement. Violations = 0 before you flip the switch.
>
> **When:** After all violations are fixed (03 + 04). Week 4+ of engagement.
> **Time:** ~10 min per phase, spread over 2-3 weeks

---

## The Rule

Never go from audit to enforce-all in one step. Progressive rollout: critical policies first, then high, then everything. If something breaks, you only broke one policy group.

---

## Step 1: Confirm Violations Are Zero

```bash
# Check PolicyReport violations
kubectl get policyreports -A -o json | \
  python3 -c "import json,sys; d=json.load(sys.stdin); print('Failures:', sum(r.get('summary',{}).get('fail',0) for r in d['items']))"
```

**If violations > 0:** Go back to [03-automated-fixes.md](03-automated-fixes.md) and [04-fix-manifests.md](04-fix-manifests.md). Don't enforce until violations = 0.

---

## Step 2: Choose Your Strategy

```bash
PKG=~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING

# Preview what would change
bash $PKG/tools/admission/audit-to-enforce.sh --strategy progressive --dry-run
```

### Strategy A: Progressive (Recommended)

```bash
bash $PKG/tools/admission/audit-to-enforce.sh --strategy progressive
```

**Week 1:** Critical policies only
- `disallow-privileged`
- `disallow-privilege-escalation`
- `require-run-as-nonroot`

**Week 2:** High severity
- `disallow-host-namespaces`
- `require-seccomp-strict`
- `require-apparmor-profile`
- `require-drop-all-capabilities`

**Week 3:** All remaining
- `disallow-latest-tag`
- `require-resource-limits`
- `require-readonly-rootfs`
- `require-pss-labels`
- `require-runtime-class-untrusted`

### Strategy B: Critical-First

```bash
bash $PKG/tools/admission/audit-to-enforce.sh --strategy critical-first
```

Immediately enforces all critical policies. After 7 days, enforces everything else.

### Strategy C: All-at-Once (Not Recommended)

```bash
bash $PKG/tools/admission/audit-to-enforce.sh --strategy all-at-once
```

Only use if you've already confirmed zero violations across all policies.

---

## Step 3: Monitor After Each Phase

After enabling enforcement, watch for blocked deployments:

```bash
# Check if anything is being blocked
kubectl get events -A --field-selector reason=PolicyViolation --sort-by='.lastTimestamp' | tail -20

# Check Kyverno admission reports
kubectl get admissionreports -A

# Check PolicyReports for new violations
kubectl get policyreports -A -o json | \
  python3 -c "import json,sys; d=json.load(sys.stdin); [print(f'{r[\"metadata\"][\"namespace\"]}: {r[\"summary\"].get(\"fail\",0)} failures') for r in d['items'] if r['summary'].get('fail',0)>0]"
```

---

## Step 4: Handle Blocked Deployments

If enforcement blocks a legitimate deployment:

```bash
# 1. See what's blocking it
kubectl get policyreport -n <namespace> -o yaml

# 2. Options (in order of preference):
#    a) Fix the workload — see templates/remediation/
#    b) Create a PolicyException for this specific case
#    c) Temporarily revert to audit (last resort):
kubectl patch clusterpolicy <policy-name> \
  --type merge -p '{"spec":{"validationFailureAction":"Audit"}}'
```

---

## Step 5: Deploy Monitoring

```bash
# Prometheus alerts for policy violations
kubectl apply -f ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/monitoring/policy-alerts.yaml

# Import Grafana dashboards
# policy-governance.json    → policy overview, enforcement mode, violation rate
# policy-violations.json    → violations by namespace/severity, fix rate
# compliance-coverage.json  → CIS / NIST / SOC2 / PCI-DSS / CKS coverage %
```

---

## Next Steps

- Generate the final compliance report? → [08-compliance-report.md](08-compliance-report.md)
- Move to runtime defense? → [03-DEPLOY-RUNTIME](../../03-DEPLOY-RUNTIME/ENGAGEMENT-GUIDE.md)

---

*Ghost Protocol — K8s Hardening Package (CKA + CKS)*
