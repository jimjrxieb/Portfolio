# Day 1 Validation Report

**Reviewed by:** Claude Code
**Date:** 2026-01-08

---

## Grading Rubric

| Category | Weight |
|----------|--------|
| Technical Accuracy | 40% |
| Completeness | 25% |
| Communication | 20% |
| Security Awareness | 15% |

**Passing threshold:** 70/100

---

## TICKET-001 | Kubernetes OOMKilled

### Score: 68/100

**Checklist:**
- [x] Correctly identified OOMKilled cause
- [ ] Provided immediate fix (resource limits YAML)
- [x] Understood memory issue
- [ ] Gave Sarah talking points

**What you got right:**
- Correct diagnosis: OOMKilled = pod exceeding memory limits
- Good instinct to check Grafana metrics
- Understanding that K8s is "doing its job" killing the pod

**What you missed:**
1. **The ticket asked for a YAML snippet with resource limits** - you gave a VPA instead. VPA is great for long-term optimization, but Sarah needs something to apply *right now* in 30 minutes.

2. **Missing the immediate fix:**
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

3. **Bullet points for Sarah were vague** - she needs client-ready language like:
   - "The pod is running out of memory because no limits were set"
   - "We'll add resource limits to prevent this"
   - "We'll monitor with VPA to right-size long-term"

**Real-world tip:**
When it's URGENT, give the 5-minute fix first, then mention the VPA as phase 2. Clients don't want to hear about monitoring when prod is down.

**Grade:** Needs Work

---

## TICKET-002 | Terraform S3 Security

### Score: 85/100

**Checklist:**
- [x] Versioning resource correct
- [x] Encryption resource correct
- [x] Explained both Checkov rules
- [x] Addressed existing bucket concerns

**What you got right:**
- Clean, correct Terraform code
- Proper resource separation (bucket, versioning, encryption)
- Good explanation of both flags
- Correct about encryption only applying to new objects

**What you missed:**
1. **CKV_AWS_145 actually prefers KMS over AES256** - your code uses AES256 which technically passes but KMS gives you key rotation and audit trails. For a finance client, KMS is the right call.

2. Minor: Your explanation "Do I control the encryption keys" is good intuition but the precise answer is:
   - AES256 = AWS-managed, no control
   - aws:kms = customer-managed OR AWS-managed CMK

**Better approach:**
```hcl
sse_algorithm     = "aws:kms"
kms_master_key_id = aws_kms_key.s3.arn  # For full audit trail
```

**Grade:** Pass

---

## TICKET-003 | OPA/Gatekeeper Labels

### Score: 92/100

**Checklist:**
- [x] ConstraintTemplate YAML correct
- [x] Constraint YAML correct (default namespace)
- [x] Pass example correct
- [x] Fail example correct
- [x] Educational violation message

**What you got right:**
- Excellent Rego logic with `object.get` for safe label access
- Great violation message explaining WHY labels matter
- Proper constraint scoped to `default` namespace
- Clean pass/fail examples

**What you missed:**
1. You said "JADE writes better YAMLs than I can" - that's fine for execution, but in an interview you need to be able to explain the Rego logic. Can you walk through:
   - What does `required := input.parameters.requiredLabels` do?
   - What does `count(missing) > 0` check?

**Honesty appreciated:**
Using JADE/Claude for this is fine in practice - but flag your confidence level when you do. You left it blank.

**Grade:** Pass (Excellent work)

---

## TICKET-004 | GitHub Actions Security

### Score: 72/100

**Checklist:**
- [x] Found hardcoded AWS_ACCESS_KEY_ID
- [ ] Found unpinned action version
- [x] Fixed branch protection
- [x] Used OIDC (excellent)
- [ ] Listed all 4+ issues

**What you got right:**
- Spotted the exposed secret immediately
- Excellent corrected YAML with OIDC
- Added `environment: production` for approval gates
- Good priority call: secrets > branch protection

**What you missed:**
The ticket asked for **4+ security issues** - you only listed 2:
1. Hardcoded secret ✅
2. Push to prod without branching ✅

**Missing issues:**
3. **Unpinned action version** - `@v2` should be `@v4` or pinned to SHA
4. **No `persist-credentials: false`** on checkout
5. **Missing `permissions` block** (you added it in fix, but didn't call it out)
6. **`ubuntu-latest` is unpinned** - could change unexpectedly

**Priority order should be explicit:**
1. Rotate the exposed key IMMEDIATELY (it's in git history)
2. Switch to OIDC
3. Add branch protection
4. Pin action versions

**Grade:** Pass (but incomplete)

---

## TICKET-005 | IAM Key Rotation Runbook

### Score: 95/100

**Checklist:**
- [x] Step-by-step numbered procedure
- [x] Rollback procedure
- [x] Common mistakes section
- [x] Junior-friendly language
- [x] Security recommendations

**What you got right:**
- Comprehensive, production-quality runbook
- Excellent structure with preconditions
- Clear rollback procedure
- Great common failure modes table
- Future state recommendation (OIDC > static keys)

**What you missed:**
1. The "Validation Checklist" uses empty checkboxes that render as unformatted text - minor formatting issue

**Real-world tip:**
This is exactly what a senior engineer would produce. The "Future State" section shows you're thinking beyond the immediate ask. Excellent.

**Grade:** Pass (Excellent)

---

## Overall Assessment

### Final Score: 82/100

### Strengths:
1. **Strong Terraform/IaC knowledge** - CKV rules, resource structure
2. **Excellent documentation skills** - TICKET-005 was production-quality
3. **Good security instincts** - spotted secrets, recommended OIDC
4. **Honest about tool usage** - said when you used JADE/Claude

### Areas for Improvement:
1. **Urgent tickets need immediate fixes** - don't over-engineer when prod is down
2. **Read deliverables carefully** - TICKET-004 asked for 4+ issues, you gave 2
3. **Fill out ALL metadata** - confidence levels were often blank
4. **Know your Rego** - even if JADE writes it, you need to explain it

### Study Recommendations:
- [ ] Practice K8s resource limits (requests vs limits, QoS classes)
- [ ] Memorize top 5 GHA security issues for interviews
- [ ] Walk through Rego logic without AI assistance

### Pattern Observations:

| Domain | Strength |
|--------|----------|
| Terraform | Strong |
| Documentation | Excellent |
| K8s troubleshooting | Needs work |
| GHA security | Good but incomplete |
| OPA/Gatekeeper | Strong (with tooling) |

---

## Next Steps

**For Day 2, focus on:**
- Completing ALL deliverables before moving on
- Filling out confidence levels honestly
- For urgent tickets: give the fast fix first, optimization second

**Resources to review:**
- [K8s Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [GHA Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
