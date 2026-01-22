# Day 1 - JADE v0.9 Responses
**Model:** jade:v0.9
**Date:** 2026-01-08
**Mode:** RAG-enabled

---

## TICKET-001 | Kubernetes OOMKilled

**JADE's Analysis:**

**What We Know:**
- Pod crashing with OOMKilled (out of memory)
- Last known state: Terminated with exit code 137
- Resource limits not configured

**Root Cause:** Exit code 137 = SIGKILL from OOM killer. Pod exceeded memory limits (which weren't set).

**Recommended Fix:**
```yaml
spec:
  containers:
    - name: app
      resources:
        requests:
          memory: "256Mi"
          cpu: "500m"
        limits:
          memory: "512Mi"
          cpu: "1000m"
```

**Why This Works:**
- Memory request: Matches average usage during working pods (70% of limit)
- CPU request: Slightly higher than working pods to allow burst
- Limits prevent future OOM (10x memory of requests)

**Bullet Points for Sarah:**
- "The pod is running out of memory because no limits were set"
- "We'll add resource limits to prevent this immediately"
- "We'll monitor with VPA to right-size long-term"

**Risk Analysis:**
- Current state (no resource limits): Likely causing periodic crashes
- My fix: Prevents future OOM kills (90% reduction)
- Service disruption risk: Medium (24-hour test period recommended)

---

## TICKET-002 | Terraform S3 Security

**JADE's Analysis:**

**Finding Summary:**
1. **CKV_AWS_145**: S3 encryption missing - data can be intercepted in transit
2. **CKV_AWS_21**: Versioning not enabled - no recovery if objects deleted

**Risk Assessment:**
- Exploitable paths: 2
- Average effort per path: MEDIUM
- Total effort: 1 hour
- Risk reduction: 60%

**Compliance Impact:**
- SOC2 CC6.1: Logical access controls → Fixed
- PCI-DSS 7.1: Encryption of sensitive data → Fixed
- HIPAA 164.308(a)(6): Access control → Fixed

**Priority:** HIGH (fix encryption, assess versioning)

**Note:** JADE focused on risk assessment rather than providing the Terraform code directly. This is a training gap - should provide working code snippets.

---

## TICKET-003 | OPA/Gatekeeper Labels

**JADE's Analysis:**

**Finding:** Missing required metadata labels (app, environment)

**Risk:** Low - Non-compliance only

**Remediation:**
```yaml
metadata:
  labels:
    app: my-app
    environment: dev
```

**Priority:** HIGH (enforce for compliance)
**Estimated Fix:** 30 minutes

**Related Controls:**
- PCI-DSS 7.2.1 (encryption of sensitive data)
- SOC2 CC6.1 (logical access controls)

**Note:** JADE did not provide the full ConstraintTemplate and Constraint YAML as requested. This is a training gap - should provide complete policy YAML.

---

## TICKET-004 | GitHub Actions Security

**JADE's Analysis:**

**Security Issues Found:**

1. **Secrets Exposure Risk** (CRITICAL):
   - `AWS_ACCESS_KEY_ID` hardcoded in workflow
   - Attack Vector: Attacker gains access → can assume IAM role → admin privileges
   - Real-World Risk: HIGH (Capital One breach, Epsilon breach patterns)

2. **Missing Permissions to Break Glass** (HIGH):
   - Workflow has no permission to modify IAM roles
   - Defense-in-Depth: Prevents lateral movement if compromised

3. **Secrets Management Weakness** (MEDIUM):
   - Long-lived credentials should be temporary STS tokens
   - Should use 6-hour session duration + automatic rotation

4. **Logging and Monitoring Gaps** (LOW):
   - No pre-deployment approval gate
   - Should have human review or second set of eyes

**Priority Order:**
1. Fix Secrets Exposure (CRITICAL) - Immediate
2. Add Permissions to Prevent Lateral Movement (HIGH) - Today
3. Improve Secrets Management (MEDIUM) - This week
4. Logging and Alerts (LOW) - This month

**Effort Estimate:**
- Secrets exposure: 30 minutes
- Permission addition: 15 minutes
- Secrets tuning: 45 minutes
- Logging: 2 hours

**Compliance Impact:** Fixes SOC2 CC6.1, PCI-DSS 7.1, HIPAA 164.308(a)(6)

---

## TICKET-005 | IAM Key Rotation Runbook

**JADE's Runbook:**

**SERVICE:** Production App
**ISSUE:** Outdated IAM keys requiring rotation
**SEVERITY:** MEDIUM
**COMPLIANCE:** SOC2 CC6.1, PCI 7.1

### Procedure

**1. Preparation**
- [ ] Sync secrets to temporary vault (if rotation fails)
- [ ] Generate audit log before changes
- [ ] Collect approval signatures if changing permissions

**2. Step-by-Step Remediation**

Identify old keys:
```bash
aws iam list-access-keys --user-name app-portal \
  | jq '.AccessKeyList[] | select(.CreateDate < "2024-03-01T00:00:00Z")'
```

Revoke old keys:
```bash
aws iam update-access-key --user-name app-portal \
  --access-key-id AKIA... --status Inactive
```

Create new rotation strategy with OIDC:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "sts.amazonaws.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "oidc-provider/*.amazonaws.com/idp": "kubernetes"
      }
    }
  }]
}
```

**3. Validation**
- [ ] Verify all old keys revoked
- [ ] Validate new multi-factor setup
- [ ] Check application logs
- [ ] Test failover

**4. Cleanup**
- [ ] Remove temporary secret sync
- [ ] Delete audit log
- [ ] Update change management record

### Rollback Plan
```bash
aws iam update-access-key --user-name app-portal \
  --access-key-id AKIA... --status Active
kubectl rollout undo deployment/app-portal -n production
```

### Common Mistakes
1. **Forgetting the service account**: Keys belong to IAM user, not EC2 instance role
2. **Using wrong OIDC provider**: SAML app vs actual OIDC provider
3. **Not updating application**: Some keys used for long-term storage

**Estimated Duration:** 4 hours (including testing)

---

## JADE Performance Notes

### Strengths:
- Risk assessment and compliance mapping (SOC2, PCI, HIPAA)
- Security-first thinking with attack vector analysis
- Good priority ordering
- Runbook structure for TICKET-005

### Training Gaps Identified:
1. **TICKET-002**: Did not provide actual Terraform code
2. **TICKET-003**: Did not provide ConstraintTemplate/Constraint YAML
3. **TICKET-004**: Did not provide corrected workflow YAML
4. Tends to over-explain risk rather than providing working code

### Recommendation for JADE v0.10:
- Add more "code first, explain second" training examples
- Ensure deliverables include working code snippets
- Balance risk assessment with actionable fixes
