*Thursday morning. Sprint is halfway done. Client call at 2 PM.*

---

## DAY 5 - Thursday Morning

*10:15 AM. Coffee #2. The standup ran long because staging is "acting weird."*

**Today's Structure:**
- 🏆 5 Golden Topics (must practice daily)
- 🎲 2 Random Tasks (varied skills)
- 🎤 3 Interview Questions (verbal practice)

**Thursday Focus:** Client communication scenarios - you'll need to explain technical findings to non-technical stakeholders.

---

# 🏆 GOLDEN TOPICS (5)

---

### TICKET-028 | 🔴 URGENT | Kubernetes | D-Rank
**From:** On-call Engineer (Alex)
**Channel:** #incident-medium

> Pods in the `analytics` namespace can't reach the database in `data` namespace. This worked yesterday. Network team says "nothing changed on our end."
>
> ```bash
> $ kubectl exec -n analytics analytics-worker-abc123 -- curl -v db.data.svc.cluster.local:5432
> * Trying 10.96.45.123:5432...
> * connect to 10.96.45.123 port 5432 failed: Connection timed out
> ```
>
> NetworkPolicy in data namespace:
> ```yaml
> apiVersion: networking.k8s.io/v1
> kind: NetworkPolicy
> metadata:
>   name: db-access
>   namespace: data
> spec:
>   podSelector:
>     matchLabels:
>       app: postgres
>   policyTypes:
>     - Ingress
>   ingress:
>     - from:
>         - namespaceSelector:
>             matchLabels:
>               access: database
>       ports:
>         - protocol: TCP
>           port: 5432
> ```
>
> Analytics namespace labels:
> ```yaml
> apiVersion: v1
> kind: Namespace
> metadata:
>   name: analytics
>   labels:
>     team: data-science
>     environment: production
> ```
>
> Data pipeline is down. Analytics team is blocked.

**Deliverable:**
1. What's the root cause? (Be specific about what's missing)
2. Two ways to fix this - one fast, one proper
3. kubectl command to verify the fix
4. How would you document this for the runbook?

---

### TICKET-029 | 🟡 Medium | OPA/Gatekeeper | C-Rank
**From:** Jira (Security Team)
**Project:** SEC-Policy-2026

> **Title:** Create Kyverno policy to inject default network policies
>
> Problem: New namespaces are created without network policies, leaving pods wide open until someone remembers to add one.
>
> Requirements:
> - When a namespace is created, automatically add a "default deny ingress" NetworkPolicy
> - Don't apply to `kube-system`, `kube-public`, or `gatekeeper-system`
> - Policy should be labeled so teams know it was auto-generated
> - Teams can add their own policies on top

**Deliverable:**
1. Kyverno ClusterPolicy YAML with generate rule
2. The NetworkPolicy that gets injected
3. How would you test this works?
4. What happens if someone deletes the auto-generated policy?

---

### TICKET-030 | 🟡 Medium | CI/CD Security | D-Rank
**From:** Senior Consultant (Constant)
**Channel:** #client-cloudsoft-support

> CloudSoft's pipeline is failing. Trivy is blocking their deploy because of a critical CVE:
>
> ```
> nginx:1.21.0 (debian 11.2)
> ========================
> Total: 47 (UNKNOWN: 0, LOW: 12, MEDIUM: 28, HIGH: 5, CRITICAL: 2)
>
> ┌──────────────┬────────────────┬──────────┬────────────────────────────────────┐
> │   Library    │ Vulnerability  │ Severity │             Fixed Version          │
> ├──────────────┼────────────────┼──────────┼────────────────────────────────────┤
> │ libssl1.1    │ CVE-2024-0727  │ CRITICAL │ 1.1.1w-0+deb11u1                   │
> │ openssl      │ CVE-2024-0727  │ CRITICAL │ 1.1.1w-0+deb11u1                   │
> └──────────────┴────────────────┴──────────┴────────────────────────────────────┘
> ```
>
> Developer says: "We can't update nginx, it'll break our config!"
>
> Current Dockerfile:
> ```dockerfile
> FROM nginx:1.21.0
> COPY nginx.conf /etc/nginx/nginx.conf
> COPY static/ /usr/share/nginx/html/
> ```

**Deliverable:**
1. What's the actual risk of CVE-2024-0727? (Research it)
2. Three options to fix this - explain tradeoffs
3. Updated Dockerfile with the recommended fix
4. How do you convince the developer this won't break their config?

---

### TICKET-031 | 🟡 Medium | Scripting/Automation | C-Rank
**From:** Platform Team
**Channel:** #infrastructure

> We need a Python script to validate Kubernetes manifests before they hit the cluster. Should wrap multiple tools:
>
> 1. `kubeval` - validate against K8s schema
> 2. `kubesec` - security scoring
> 3. `conftest` - custom policy checks
>
> Requirements:
> - Accept directory path as input
> - Run all three tools
> - Aggregate results into single JSON report
> - Exit non-zero if ANY tool finds issues
> - Support `--fix` flag for auto-remediation suggestions

**Deliverable:**
1. Python script structure (pseudocode or full implementation)
2. Example JSON output format
3. How would you handle tools that aren't installed?
4. How would you integrate this into a pre-commit hook?

---

### TICKET-032 | 🟡 Medium | Compliance Mapping | C-Rank
**From:** Email from Client (forwarded by Sarah)
**Client:** MedSecure (HIPAA)

> "Our auditor is asking about our encryption strategy. They want documentation showing:
>
> 1. What data is encrypted at rest
> 2. What data is encrypted in transit
> 3. How we manage encryption keys
>
> Can you help us prepare this for HIPAA 164.312(a)(2)(iv) and 164.312(e)(1)?"

**Deliverable:**
1. Map these HIPAA requirements to specific AWS/Kubernetes controls
2. AWS CLI commands to generate evidence for each control
3. Draft response template the client can fill in
4. What compensating controls would you recommend if something isn't encrypted?

---

# 🎲 RANDOM TASKS (2)

---

### TICKET-033 | 🟢 Low | Terraform | D-Rank
**From:** Jira (from Sprint Planning)
**Project:** PLATFORM-Internal

> **Title:** Fix Checkov failures on our S3 module
>
> Checkov output:
> ```
> Check: CKV_AWS_18: "Ensure the S3 bucket has access logging enabled"
> 	FAILED for resource: aws_s3_bucket.this
>
> Check: CKV_AWS_144: "Ensure that S3 bucket has cross-region replication enabled"
> 	FAILED for resource: aws_s3_bucket.this
>
> Check: CKV_AWS_145: "Ensure that S3 bucket lifecycle configuration expires old versions"
> 	FAILED for resource: aws_s3_bucket.this
> ```
>
> Current module:
> ```hcl
> resource "aws_s3_bucket" "this" {
>   bucket = var.bucket_name
>
>   tags = var.tags
> }
>
> resource "aws_s3_bucket_versioning" "this" {
>   bucket = aws_s3_bucket.this.id
>   versioning_configuration {
>     status = "Enabled"
>   }
> }
>
> resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
>   bucket = aws_s3_bucket.this.id
>   rule {
>     apply_server_side_encryption_by_default {
>       sse_algorithm = "aws:kms"
>     }
>   }
> }
>
> resource "aws_s3_bucket_public_access_block" "this" {
>   bucket = aws_s3_bucket.this.id
>   block_public_acls       = true
>   block_public_policy     = true
>   ignore_public_acls      = true
>   restrict_public_buckets = true
> }
> ```

**Deliverable:**
1. Fixed Terraform to pass all three Checkov checks
2. Which of these checks might you legitimately skip and why?
3. How do you add Checkov exceptions for intentional skips?

---

### TICKET-034 | 🟡 Medium | Client Communication | B-Rank
**From:** Senior Consultant (Mike)
**Channel:** #client-securebank-support

> SecureBank's CISO wants to understand our findings from the cloud security assessment. She's not technical.
>
> Finding summary:
> - 12 S3 buckets with public access possible
> - 47 IAM roles with overly permissive policies
> - No CloudTrail in 2 of 4 regions
> - 8 security groups allowing 0.0.0.0/0 on SSH
> - 156 unpatched EC2 instances (30+ days old patches)
>
> She has 15 minutes for you on her call with Mike.
>
> Write the executive summary she needs.

**Deliverable:**
1. Executive summary (5 bullet points max, no jargon)
2. Risk prioritization - what should they fix first and why?
3. Estimated effort per category (hours/days, not exact)
4. One "quick win" she can report to her board this week

---

# 🎤 INTERVIEW QUESTIONS (3)

*Answer these as if you're in an interview. Speak out loud or write as you would explain verbally. Structure matters.*

---

### INTERVIEW-07 | Troubleshooting Scenario
**Interviewer:** "A developer says their deployment works locally but fails in Kubernetes. Where do you start?"

**Your Task:**
- Describe your systematic debugging approach
- What's different between local Docker and Kubernetes?
- What are the top 5 things you'd check?
- How do you explain the findings to the developer?

**Format:** Step-by-step walkthrough with specific commands

---

### INTERVIEW-08 | Architecture Design
**Interviewer:** "How would you design a multi-tenant Kubernetes platform where each tenant's workloads are isolated from each other?"

**Your Task:**
- Cover namespace isolation, RBAC, network policies
- Discuss resource quotas and limit ranges
- Address the "noisy neighbor" problem
- What about secrets isolation?
- When would you recommend separate clusters instead?

**Format:** Structured architecture discussion

---

### INTERVIEW-09 | Security Tradeoffs
**Interviewer:** "What are the tradeoffs between OPA Gatekeeper and Kyverno? When would you choose each?"

**Your Task:**
- Compare the policy languages (Rego vs YAML)
- Discuss mutation capabilities
- Cover the learning curve for teams
- What about performance at scale?
- Give a specific scenario for each

**Format:** Balanced comparison with clear recommendations

---

## ⏱️ Time Budget

| Section | Count | Time Each | Total |
|---------|-------|-----------|-------|
| Golden Topics | 5 | 20 min | 100 min |
| Random Tasks | 2 | 15 min | 30 min |
| Interview Questions | 3 | 10 min | 30 min |
| **Total** | **10** | - | **160 min** |

---

## ✅ Daily Checklist

### Golden Topics
- [ ] Kubernetes (TICKET-028)
- [ ] OPA/Gatekeeper (TICKET-029)
- [ ] CI/CD Security (TICKET-030)
- [ ] Scripting/Automation (TICKET-031)
- [ ] Compliance Mapping (TICKET-032)

### Random Tasks
- [ ] Terraform (TICKET-033)
- [ ] Client Communication (TICKET-034)

### Interview Practice
- [ ] Troubleshooting: Local vs K8s (INTERVIEW-07)
- [ ] Architecture: Multi-tenant K8s (INTERVIEW-08)
- [ ] Tradeoffs: Gatekeeper vs Kyverno (INTERVIEW-09)

---

## Rank Distribution

| Rank | Count | Tickets |
|------|-------|---------|
| E | 0 | - |
| D | 3 | TICKET-028, TICKET-030, TICKET-033 |
| C | 3 | TICKET-029, TICKET-031, TICKET-032 |
| B | 1 | TICKET-034 (Client Communication) |

---

*The NetworkPolicy issue is blocking the data team. Fix that first.*

*The client call at 2 PM - Mike needs that executive summary before he gets on with the CISO.*

*Thursday is about communication. Technical skills get you in the room. Communication skills keep you there.*

*Go.* 🎯
