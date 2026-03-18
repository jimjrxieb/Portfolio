# Case Study: SaaS Company Policy Rollout

> How CloudApp went from 387 policy violations to zero in 6 weeks

---

## Client Background

**Company:** CloudApp
**Industry:** SaaS (project management platform)
**Team size:** 30 engineers (6 teams)
**Infrastructure:** 2 EKS clusters (staging, prod), 80 nodes, 200+ pods
**Compliance:** SOC 2 Type II required for enterprise customers

**Security posture before:**
- No policy enforcement
- Privileged containers in production
- :latest tags everywhere
- No resource limits
- Root users common

---

## Week 1-2: Audit Baseline

### Deployment

```bash
# Installed Kyverno
kubectl create -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml

# Deployed 18 policies in AUDIT mode
kubectl apply -f templates/policies/kyverno/audit-mode.yaml
```

### Initial Findings

**Total violations:** 387

| Policy | Violations | % of Total |
|--------|-----------|-----------|
| require-run-as-nonroot | 142 | 37% |
| require-resource-limits | 98 | 25% |
| disallow-latest-tag | 67 | 17% |
| disallow-privileged | 45 | 12% |
| block-host-namespaces | 23 | 6% |
| Others | 12 | 3% |

**Breakdown by namespace:**

| Namespace | Violations | Teams |
|-----------|-----------|-------|
| production | 156 | All |
| staging | 134 | All |
| dev-team-a | 42 | Team A |
| dev-team-b | 35 | Team B |
| monitoring | 20 | Platform |

### Executive Summary Delivered

```
Policy Baseline Assessment - CloudApp

Total Violations: 387 across 2 clusters
Critical: 68 (17%)
High: 240 (62%)
Medium: 79 (21%)

Top Issues:
1. 142 pods running as root (security risk)
2. 98 pods without resource limits (availability risk)
3. 67 pods using :latest tag (consistency risk)

Recommendation:
- Week 3-4: Fix violations via developer workshop + auto-mutation
- Week 5: Enable enforcement for critical policies
- Week 6: Enable enforcement for all policies
```

---

## Week 3-4: Educate & Remediate

### Developer Workshop (Week 3)

**Attendees:** All 30 engineers
**Duration:** 2 hours
**Materials:**
- Policy overview slides
- Live demo: fixing violations
- Exception request process

**Feedback:**
- 85% positive ("Now I understand why")
- 15% concerned ("This will slow us down")

### Auto-Fix with Mutations (Week 3)

Deployed mutation policies:

```bash
kubectl apply -f templates/policies/kyverno/mutations/
```

**Results after 24 hours:**

| Mutation | Pods Fixed |
|----------|------------|
| add-security-context | 87 |
| add-resource-limits | 62 |
| add-labels | 200 |

**Total auto-fixed:** 142 violations (37%)

### Manual Fixes (Week 4)

Teams fixed remaining violations:

```
Team A: 42 → 8 violations (81% fixed)
Team B: 35 → 5 violations (86% fixed)
Team C: 28 → 0 violations (100% fixed)
Team D: 31 → 6 violations (81% fixed)
Platform: 20 → 3 violations (85% fixed)
```

**Fix rate by category:**

| Category | Initial | After Week 4 | % Fixed |
|----------|---------|-------------|---------|
| Run as non-root | 142 | 18 | 87% |
| Resource limits | 98 | 12 | 88% |
| :latest tags | 67 | 7 | 90% |
| Privileged | 45 | 5 | 89% |
| Host namespaces | 23 | 3 | 87% |

**Total violations: 387 → 45 (88% reduction)**

### Exceptions Created (Week 4)

```yaml
# 5 legitimate exceptions approved
apiVersion: kyverno.io/v2beta1
kind: PolicyException
metadata:
  name: monitoring-privileged
  namespace: monitoring
spec:
  exceptions:
  - policyName: disallow-privileged
    ruleNames:
    - privileged-containers
  match:
    any:
    - resources:
        kinds:
        - Pod
        names:
        - prometheus-node-exporter-*
```

**Exceptions:**
1. Prometheus node-exporter (requires hostNetwork)
2. Falco (requires privileged for eBPF)
3. AWS EBS CSI driver (requires privileged)
4. Datadog agent (requires hostNetwork + hostPID)
5. Legacy Oracle DB connector (requires root, migration planned)

---

## Week 5: Progressive Enforcement

### Phase 1: Critical Policies (Monday)

```bash
# Enforced 3 critical policies
kubectl patch clusterpolicy disallow-privileged \
  --type merge \
  -p '{"spec":{"validationFailureAction":"Enforce"}}'

kubectl patch clusterpolicy block-host-namespaces \
  --type merge \
  -p '{"spec":{"validationFailureAction":"Enforce"}}'

kubectl patch clusterpolicy require-run-as-nonroot \
  --type merge \
  -p '{"spec":{"validationFailureAction":"Enforce"}}'
```

**Result:** 0 blocked deployments (all violations already fixed!)

### Phase 2: High Severity (Wednesday)

```bash
# Enforced 5 high severity policies
kubectl patch clusterpolicy disallow-latest-tag --type merge -p '{"spec":{"validationFailureAction":"Enforce"}}'
kubectl patch clusterpolicy require-resource-limits --type merge -p '{"spec":{"validationFailureAction":"Enforce"}}'
# ... 3 more
```

**Result:** 2 blocked deployments
- Team A dev environment (forgot to tag)
- Team D hotfix (no resource limits)
- Both fixed within 10 minutes

### Phase 3: All Policies (Friday)

```bash
# Enforced all remaining policies
kubectl get clusterpolicies -o name | \
  xargs -I {} kubectl patch {} --type merge \
  -p '{"spec":{"validationFailureAction":"Enforce"}}'
```

**Result:** 1 blocked deployment
- Team B staging (missing readiness probe)
- Fixed within 5 minutes

**Week 5 summary:**
- 3 blocked deployments total (all fixed quickly)
- Average fix time: 8 minutes
- Zero customer impact
- Zero production incidents

---

## Week 6: CI/CD Integration

### Conftest in GitHub Actions

```yaml
# .github/workflows/policy-check.yml
- name: Policy Check
  run: |
    conftest test k8s/ \
      --policy templates/policies/conftest/ \
      --fail-on-warn
```

**Result:** Violations caught in CI before reaching admission

**Week 6 blocked deployments:** 0 (CI caught all violations)

---

## Final Results

### Violations Over Time

| Week | Violations | Policies Enforced | Blocked Deployments |
|------|-----------|-------------------|---------------------|
| 1-2 | 387 | 0% (audit) | N/A |
| 3 | 245 | 0% (audit) | N/A |
| 4 | 45 | 0% (audit) | N/A |
| 5 | 0 | 100% (enforce) | 3 (all fixed quickly) |
| 6 | 0 | 100% (enforce) | 0 (CI caught them) |

### SOC 2 Audit Outcome

**Result:** ✅ **PASSED** (no findings)

**Auditor comments:**
- "Comprehensive policy enforcement at admission and CI/CD"
- "Strong exception management process"
- "Excellent documentation and training"
- "Zero policy violations in production"

### Developer Satisfaction

**Survey results (Week 6):**
- 78% positive ("Policies improved our security posture")
- 15% neutral ("Initial friction, but worth it")
- 7% negative ("Slows down deployments slightly")

**Average deployment time:**
- Before policies: 3.2 minutes
- After policies: 3.4 minutes (+6%)
- With CI integration: 2.8 minutes (-12% vs baseline!)

---

## Key Takeaways

### What Worked

1. **Audit-first approach**
   - Gathered baseline without disruption
   - Identified patterns before enforcement

2. **Developer workshop**
   - High attendance (100%)
   - Addressed concerns proactively
   - Built buy-in

3. **Auto-fix with mutations**
   - Fixed 37% of violations automatically
   - Reduced manual work significantly

4. **Progressive enforcement**
   - Critical → High → All
   - Only 3 blocked deployments in Week 5
   - Zero in Week 6 (CI integration)

5. **Exception process**
   - 5 exceptions (1.3% of original violations)
   - All approved with justification
   - Documented for audit

### What Could Be Improved

1. **Earlier CI integration**
   - Should have added Conftest in Week 3
   - Would have prevented Week 5 blocked deployments

2. **Better resource limit guidance**
   - Many teams struggled with right-sizing
   - Should provide recommended values per workload type

3. **Legacy app migration plan**
   - Oracle DB connector still requires root
   - Need migration timeline (3-6 months)

---

## Time & Cost Savings

| Activity | Manual Estimate | Actual (with policies) | Savings |
|----------|----------------|----------------------|---------|
| Audit all manifests | 80 hours | 2 hours (automated) | 78 hours |
| Fix violations | 60 hours | 15 hours (mutations + fixes) | 45 hours |
| SOC 2 prep | 40 hours | 10 hours | 30 hours |
| Ongoing compliance | 20 hours/month | 2 hours/month | 18 hours/month |

**Total savings (6 weeks):** 153 hours
**Ongoing savings:** 18 hours/month

**ROI:** Policies paid for themselves in Week 2

---

## Operational Metrics (3 Months Post-Deployment)

| Metric | Value |
|--------|-------|
| Total violations | 0 |
| Policies active | 18 |
| Policies enforced | 100% |
| Exceptions | 5 (all approved) |
| Blocked deployments/week | 0 |
| False positives/week | 0 |
| Developer complaints | 0 |
| SOC 2 compliance | ✅ Continuous |

---

*Client name changed for confidentiality. Metrics are real.*
