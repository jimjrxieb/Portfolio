# Playbook: Admission Control Perfection

> Perfect what 02-CLUSTER-HARDENING deployed. Move policies from audit to enforce. Add ImagePolicyWebhook if needed. Verify zero violations before enforcement.
>
> **When:** After RBAC locked down. Admission control is the gatekeeper — it must be tight.
> **Time:** ~25 min

---

## Prerequisites

- 02-CLUSTER-HARDENING playbooks 06 (deploy admission) and 07 (audit-to-enforce) completed
- Kyverno or Gatekeeper running

---

## Step 1: Audit Current Policy State

```bash
# What policies exist?
echo "=== Kyverno Policies ==="
kubectl get clusterpolicy --no-headers 2>/dev/null
kubectl get policy -A --no-headers 2>/dev/null

echo ""
echo "=== Gatekeeper Constraints ==="
kubectl get constraints 2>/dev/null

echo ""
echo "=== Current Violations ==="
kubectl get policyreport -A --no-headers 2>/dev/null | wc -l
kubectl get clusterpolicyreport --no-headers 2>/dev/null
```

---

## Step 2: Check Policy Modes

02-CLUSTER-HARDENING may have left policies in audit mode. Check each:

```bash
# Kyverno — check validationFailureAction
kubectl get clusterpolicy -o json | jq -r '
  .items[] | "\(.metadata.name): \(.spec.validationFailureAction // "Audit")"'

# Policies still in Audit mode need to graduate to Enforce
# But ONLY if there are zero violations for that policy
```

For each policy in Audit mode:

```bash
POLICY_NAME="disallow-privileged"  # Change per policy

# Count current violations
kubectl get policyreport -A -o json | jq -r "
  [.items[].results[]? | select(.policy == \"$POLICY_NAME\" and .result == \"fail\")] | length"

# If 0 violations → safe to enforce
# If >0 violations → fix the violating workloads first
```

### Move to Enforce

```bash
# Use the tool from 02-CLUSTER-HARDENING
bash ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/admission/audit-to-enforce.sh

# Or manually per policy
kubectl patch clusterpolicy $POLICY_NAME --type merge -p '{"spec":{"validationFailureAction":"Enforce"}}'
```

> **Reference:** `02-CLUSTER-HARDENING/playbooks/07-audit-to-enforce.md` for the progressive enforcement workflow.

---

## Step 3: Add Missing Policies

Compare deployed policies against the full set available:

```bash
# Available policies (source of truth)
ls ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/templates/policies/kyverno/

# Deployed policies
kubectl get clusterpolicy --no-headers | awk '{print $1}'

# Diff
echo "=== Not yet deployed ==="
comm -23 \
  <(ls ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/templates/policies/kyverno/ | sed 's/\.yaml//' | sort) \
  <(kubectl get clusterpolicy --no-headers | awk '{print $1}' | sort)
```

Deploy missing policies in audit mode first:

```bash
# Deploy individual policy
kubectl apply -f ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/templates/policies/kyverno/<missing-policy>.yaml
```

---

## Step 4: ImagePolicyWebhook (If Required)

If the engagement requires native image admission (beyond Kyverno's image verification):

```bash
# Check if ImagePolicyWebhook is enabled
kubectl -n kube-system get pod -l component=kube-apiserver \
  -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep ImagePolicyWebhook
```

If not enabled and required:

> **Follow:** `04-KUBESTER/reference/cks/08-image-policy-webhook.md` for the full setup procedure.

This requires:
1. An external webhook server (or deploy one)
2. Kubeconfig for the webhook
3. AdmissionConfiguration
4. API server manifest edit

**Most engagements use Kyverno for image policies instead** — it's easier to manage and doesn't require API server changes.

---

## Step 5: Test Enforcement

```bash
# Test: Try to create a privileged pod (should be denied)
kubectl run test-privileged --image=nginx:1.25 --overrides='{"spec":{"containers":[{"name":"test","image":"nginx:1.25","securityContext":{"privileged":true}}]}}' --dry-run=server 2>&1
# Expected: admission webhook denied the request

# Test: Try to create a pod with :latest tag (should be denied)
kubectl run test-latest --image=nginx:latest --dry-run=server 2>&1
# Expected: denied by disallow-latest-tag policy

# Test: Create a compliant pod (should work)
kubectl run test-compliant --image=nginx:1.25 --dry-run=server \
  --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"test","image":"nginx:1.25","securityContext":{"allowPrivilegeEscalation":false,"readOnlyRootFilesystem":true,"capabilities":{"drop":["ALL"]}}}]}}' 2>&1
# Expected: pod/test-compliant created (server dry run)

# Clean up
kubectl delete pod test-compliant --ignore-not-found
```

---

## Outputs

- All policies reviewed: audit vs enforce mode
- Zero-violation policies: moved to enforce
- Missing policies: deployed in audit mode
- ImagePolicyWebhook: configured if required
- Enforcement tested: privileged/latest denied, compliant pods allowed

---

## Next

→ [06-pod-security-perfection.md](06-pod-security-perfection.md) — Seccomp, AppArmor, RuntimeClass
