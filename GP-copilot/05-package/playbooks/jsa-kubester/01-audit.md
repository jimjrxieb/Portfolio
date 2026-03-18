# Phase 1: Specialist Audit

Source: `04-KUBESTER/playbooks/01-specialist-audit.md`
Automation: **100% autonomous (E/D-rank)**

## What the Agent Does

Run every scanner, every domain check, every audit tool — then produce a gap
report that maps findings to specific perfection playbooks (02-11).

## Step-by-Step

### 1. Domain Audit — E-rank

```bash
04-KUBESTER/tools/domain-audit.sh --all > ${OUTPUT_DIR}/kubester/domain-audit.txt
```

Checks 11 CKS domains + 5 CKA domains against live cluster:
- [PASS] NetworkPolicy in all app namespaces
- [FAIL] 3 namespaces without NetworkPolicy → Playbook 07
- [WARN] Falco running but 2 rules in alert mode → Playbook 10
- etc.

### 2. Scanner Suite — E-rank

```bash
kubescape scan --format json --output ${OUTPUT_DIR}/kubester/kubescape.json
kube-bench run --json > ${OUTPUT_DIR}/kubester/kube-bench.json
polaris audit --format json > ${OUTPUT_DIR}/kubester/polaris.json
```

### 3. Control Inventory — D-rank

```bash
# Admission control
kubectl get clusterpolicies.kyverno.io -o json 2>/dev/null | jq '[.items[] | {name:.metadata.name, action:.spec.validationFailureAction}]'

# Runtime tools
kubectl get pods -n falco -l app.kubernetes.io/name=falco 2>/dev/null
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus 2>/dev/null

# RBAC state
kubectl get clusterrolebindings -o json | jq '[.items[] | select(.roleRef.name=="cluster-admin")]'
kubectl get pods -A -o json | jq '[.items[] | select(.spec.automountServiceAccountToken != false)] | length'

# PSS labels
kubectl get ns --show-labels | grep pod-security
```

### 4. Gap Report — D-rank

Map every [FAIL] and [WARN] to a playbook:

```markdown
# Specialist Audit Gap Report

## Scores
| Scanner | Score | Target |
|---------|-------|--------|
| Kubescape | ${SCORE}% | 80%+ |
| kube-bench | ${PASS}/${TOTAL} pass | 90%+ |
| Polaris | ${SCORE}% | 80%+ |
| domain-audit [PASS] | ${PASS_COUNT} | — |
| domain-audit [FAIL] | ${FAIL_COUNT} | 0 |

## Findings → Playbook Mapping

### Playbook 02: Platform Integrity
- [ ] Binary checksums not verified

### Playbook 03: API Server & etcd
- [ ] anonymous-auth not disabled
- [ ] Audit logging not configured
- [ ] etcd encryption not verified

### Playbook 04: RBAC
- [x] 4 cluster-admin bindings (2 system, 2 user)
- [ ] 3 wildcard RBAC permissions

... (continue for each playbook 05-11)

## Recommended Execution Order
1. Playbook 04 (RBAC) — highest security impact
2. Playbook 07 (Network) — default-deny missing
3. Playbook 06 (Pod Security) — PSS not restricted
4. ... (sorted by gap severity)
```

## Phase 1 Gate

```
PASS: gap report generated
Continue to Phase 2 with prioritized playbook list.
Only run playbooks where gap report shows findings.
```
