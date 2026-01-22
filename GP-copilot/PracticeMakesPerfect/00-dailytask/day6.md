*Friday morning. End of week 1. You survived. But did you learn?*

---

## DAY 6 - Friday (Chaos Mode + Weekly Review)

*9:30 AM. Standup was quick. Everyone wants to wrap up and get to the weekend. But first...*

**Today's Structure:**
- 🏆 5 Golden Topics (must practice daily)
- 🎲 1 Random Task + 1 🔥 CHAOS MODE (unlabeled, raw triage)
- 🎤 3 Interview Questions (verbal practice)
- 📊 Weekly Review (reflection + gap analysis)

**Friday Focus:** Chaos mode = real consulting life. You get incomplete info and must triage before solving.

---

# 🏆 GOLDEN TOPICS (5)

---

### TICKET-035 | 🔴 URGENT | Kubernetes | D-Rank
**From:** On-call Engineer (Chen)
**Channel:** #incident-high

> Service in production returning 503s. Pods are running but requests aren't reaching them.
>
> ```bash
> $ kubectl get pods -n checkout
> NAME                          READY   STATUS    RESTARTS   AGE
> checkout-api-abc123-x7k9p     1/1     Running   0          3h
> checkout-api-abc123-m3n2q     1/1     Running   0          3h
> checkout-api-abc123-p9r8s     1/1     Running   0          3h
>
> $ kubectl get svc -n checkout
> NAME           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
> checkout-api   ClusterIP   10.96.178.45    <none>        8080/TCP   45d
>
> $ kubectl get endpoints -n checkout
> NAME           ENDPOINTS   AGE
> checkout-api   <none>      45d
> ```
>
> Deployment labels:
> ```yaml
> spec:
>   selector:
>     matchLabels:
>       app: checkout-api
>       version: v2
>   template:
>     metadata:
>       labels:
>         app: checkout
>         version: v2
> ```
>
> Service selector:
> ```yaml
> spec:
>   selector:
>     app: checkout-api
> ```
>
> Payments are failing. Customers are angry. Fix this NOW.

**Deliverable:**
1. What's causing the empty endpoints? (Be specific)
2. The fix - show the corrected YAML
3. kubectl command to verify fix worked
4. What CI/CD check would catch this before deploy?

---

### TICKET-036 | 🟡 Medium | OPA/Gatekeeper | C-Rank
**From:** Security Guild
**Channel:** #security-guild

> We want to enforce that all container images come from our approved registries. But we're not sure how to handle the initial rollout without breaking existing workloads.
>
> Approved registries:
> - `gcr.io/company-approved/`
> - `us-docker.pkg.dev/company-prod/`
> - `registry.internal.company.com/`
>
> Current state: ~200 pods running, some using `docker.io`, `quay.io`, etc.

**Deliverable:**
1. Gatekeeper ConstraintTemplate for registry allowlist
2. Constraint with audit mode first
3. Query to find all current violations
4. Rollout plan: audit → warn → enforce timeline
5. How do you handle the pods that legitimately need external images?

---

### TICKET-037 | 🟡 Medium | CI/CD Security | C-Rank
**From:** Jira (Security Team)
**Project:** SEC-Supply-Chain

> **Title:** Implement SLSA Level 2 for our container builds
>
> After reading about recent supply chain attacks, leadership wants provenance for our container images.
>
> Requirements:
> - Generate SLSA provenance for each build
> - Sign images with Sigstore/Cosign
> - Store signatures in our registry
> - Verify signatures before deployment
>
> Start with one pipeline as a proof of concept.

**Deliverable:**
1. GitHub Actions workflow with Cosign signing
2. Kubernetes admission webhook or policy to verify signatures
3. What's the difference between SLSA Level 1, 2, and 3?
4. What breaks if the signing key is compromised?

---

### TICKET-038 | 🟢 Low | Scripting/Automation | D-Rank
**From:** Peer Engineer (Jamie)
**Channel:** #devsecops

> This script is supposed to find AWS security groups with overly permissive rules, but it's not working right. Can you debug it?
>
> ```python
> #!/usr/bin/env python3
> import boto3
> import json
>
> def find_open_security_groups():
>     ec2 = boto3.client('ec2')
>
>     response = ec2.describe_security_groups()
>
>     open_sgs = []
>     for sg in response['SecurityGroups']:
>         for rule in sg['IpPermissions']:
>             for ip_range in rule['IpRanges']:
>                 if ip_range['CidrIp'] == '0.0.0.0/0':
>                     open_sgs.append({
>                         'GroupId': sg['GroupId'],
>                         'GroupName': sg['GroupName'],
>                         'Port': rule['FromPort'],
>                         'Protocol': rule['IpProtocol']
>                     })
>
>     print(json.dumps(open_sgs, indent=2))
>
> if __name__ == '__main__':
>     find_open_security_groups()
> ```
>
> Error when running:
> ```
> Traceback (most recent call last):
>   File "scan_sgs.py", line 18, in find_open_security_groups
>     'Port': rule['FromPort'],
> KeyError: 'FromPort'
> ```
>
> Also, it's missing some open security groups that I know exist.

**Deliverable:**
1. What's causing the KeyError?
2. Why is it missing some open security groups?
3. Fixed script that handles all edge cases
4. How would you extend this to check IPv6 ranges too?

---

### TICKET-039 | 🟡 Medium | Compliance Mapping | D-Rank
**From:** Jira (Compliance Team)
**Project:** SOC2-Annual

> **Title:** Generate evidence for SOC2 CC7.1 (System Monitoring)
>
> Auditor needs proof that we:
> 1. Monitor system components for anomalies
> 2. Have alerting configured
> 3. Retain logs for the required period
>
> Generate the evidence package for our AWS environment.

**Deliverable:**
1. AWS CLI commands to pull evidence for each requirement
2. What services demonstrate system monitoring? (CloudWatch, GuardDuty, etc.)
3. How do you show log retention configuration?
4. Format this as an evidence document with timestamps

---

# 🎲 RANDOM TASKS (2)

---

### TICKET-040 | 🟢 Low | Secrets Management | E-Rank
**From:** Jira (from Sprint Planning)
**Project:** PLATFORM-Internal

> **Title:** Rotate the database password for staging
>
> Steps:
> 1. Generate new password in AWS Secrets Manager
> 2. Update the Kubernetes secret
> 3. Restart the pods that use it
> 4. Verify database connectivity
>
> Current secret:
> ```bash
> $ kubectl get secret db-credentials -n staging -o jsonpath='{.data.password}' | base64 -d
> oldpassword123
> ```

**Deliverable:**
1. AWS CLI command to rotate the secret
2. kubectl command to update the K8s secret
3. How do you restart pods without downtime?
4. How would you automate this for next time?

---

### 🔥 CHAOS MODE | 🔴 UNKNOWN | Triage Required
**From:** Slack DM from Constant (your mentor)
**Channel:** Direct Message

> hey
>
> client just pinged me, something about their stuff not working after we did that thing yesterday
>
> can you look? im in another meeting
>
> they said "the API returns forbidden now"
>
> its the fintech client i think

**Your Task (BEFORE solving):**
1. What domain is this? (K8s? AWS? CI/CD? IAM?)
2. What rank would you assign this?
3. What's the first thing you'd check?
4. What questions would you ask to clarify?

**Then:** Form a hypothesis and describe your debugging approach.

---

# 🎤 INTERVIEW QUESTIONS (3)

*Answer these as if you're in an interview. Speak out loud or write as you would explain verbally. Structure matters.*

---

### INTERVIEW-10 | Explain a Concept
**Interviewer:** "Explain Zero Trust architecture to me. How would you implement it in a Kubernetes environment?"

**Your Task:**
- Define Zero Trust principles (never trust, always verify)
- Map to K8s: NetworkPolicies, RBAC, mutual TLS
- Discuss service mesh (Istio/Linkerd) role
- What's the difference between perimeter security and Zero Trust?

**Format:** 2-3 minute explanation with K8s specifics

---

### INTERVIEW-11 | Troubleshooting Scenario
**Interviewer:** "An application that worked fine for months suddenly starts failing with 'permission denied' errors. Nothing was deployed. What do you check?"

**Your Task:**
- Consider: certificate expiration, token expiration, key rotation
- Cloud-specific: IAM policy changes, SCP changes, credential rotation
- K8s-specific: ServiceAccount token, RBAC changes, secret expiration
- How do you prove "nothing changed" is wrong?

**Format:** Systematic debugging walkthrough

---

### INTERVIEW-12 | Past Experience
**Interviewer:** "Tell me about a time you had to learn a new technology quickly to solve a problem."

**Your Task:**
- Use GP-Copilot or another real project
- STAR format: Situation, Task, Action, Result
- Emphasize your learning approach
- What resources did you use?
- What would you do differently next time?

**Format:** 3-4 minute story with clear structure

---

## ⏱️ Time Budget

| Section | Count | Time Each | Total |
|---------|-------|-----------|-------|
| Golden Topics | 5 | 20 min | 100 min |
| Random Tasks | 2 | 15 min | 30 min |
| Interview Questions | 3 | 10 min | 30 min |
| Weekly Review | 1 | 20 min | 20 min |
| **Total** | **11** | - | **180 min** |

---

## ✅ Daily Checklist

### Golden Topics
- [ ] Kubernetes (TICKET-035)
- [ ] OPA/Gatekeeper (TICKET-036)
- [ ] CI/CD Security (TICKET-037)
- [ ] Scripting/Automation (TICKET-038)
- [ ] Compliance Mapping (TICKET-039)

### Random Tasks
- [ ] Secrets Management (TICKET-040)
- [ ] 🔥 Chaos Mode (Triage Exercise)

### Interview Practice
- [ ] Explain: Zero Trust in K8s (INTERVIEW-10)
- [ ] Troubleshooting: Permission denied mystery (INTERVIEW-11)
- [ ] Past Experience: Learning quickly (INTERVIEW-12)

### Weekly Review
- [ ] Complete reflection below

---

## Rank Distribution

| Rank | Count | Tickets |
|------|-------|---------|
| E | 1 | TICKET-040 |
| D | 3 | TICKET-035, TICKET-038, TICKET-039 |
| C | 3 | TICKET-036, TICKET-037 |
| ? | 1 | Chaos Mode (you decide) |

---

# 📊 WEEKLY REVIEW

*Complete this at the end of Day 6*

## Confidence Tracker

| Domain | Day 1 | Day 2 | Day 3 | Day 4 | Day 5 | Day 6 | Trend |
|--------|-------|-------|-------|-------|-------|-------|-------|
| Kubernetes | /10 | /10 | /10 | /10 | /10 | /10 | ↑↓→ |
| Policy-as-Code | /10 | /10 | /10 | /10 | /10 | /10 | ↑↓→ |
| CI/CD Security | /10 | /10 | /10 | /10 | /10 | /10 | ↑↓→ |
| Scripting | /10 | /10 | /10 | /10 | /10 | /10 | ↑↓→ |
| Compliance | /10 | /10 | /10 | /10 | /10 | /10 | ↑↓→ |

## Reflection Questions

### 1. What clicked this week?
*What concept or skill finally made sense?*

```
[Your answer]
```

### 2. What's still fuzzy?
*What do you understand conceptually but couldn't implement without help?*

```
[Your answer]
```

### 3. Most valuable ticket
*Which ticket taught you the most? Why?*

```
[Your answer]
```

### 4. Interview readiness
*Could you explain each golden topic for 5 minutes in an interview?*

| Topic | Ready? | Gap |
|-------|--------|-----|
| Kubernetes troubleshooting | Y/N | |
| OPA/Gatekeeper policies | Y/N | |
| CI/CD security patterns | Y/N | |
| Python/Bash scripting | Y/N | |
| Compliance mapping | Y/N | |

### 5. AI dependency check
*How many tickets did you solve yourself vs relying on AI?*

| Category | Count |
|----------|-------|
| Solved independently | |
| Solved with AI assistance | |
| Couldn't solve without AI | |

### 6. What to practice next week
*Based on your gaps, what should you focus on?*

1.
2.
3.

---

## 🎯 Week 1 Complete

**You've completed 60 exercises:**
- 30 Golden Topic tickets
- 12 Random tasks
- 18 Interview questions

**Next week focus areas** (based on common junior gaps):
- More live debugging (less reading, more `kubectl exec`)
- Policy writing without AI (internalize the patterns)
- Explaining technical concepts to non-technical people
- Time pressure scenarios (can you solve it in 10 min?)

---

*The 503 issue is impacting revenue. Handle that first.*

*Chaos mode: Show me you can triage when no one gives you a clean problem statement.*

*Then do your weekly review honestly. The gaps you identify today become next week's focus.*

*Week 1 is done. Week 2 will be harder. That's the point.* 🎯
