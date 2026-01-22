*Friday afternoon. You're about to head out when Slack lights up. Classic.*

---

## DAY 4 - Friday Afternoon

*3:47 PM. Weekend is 73 minutes away. But the backlog doesn't care.*

**Today's Structure:**
- 🏆 5 Golden Topics (must practice daily)
- 🎲 2 Random Tasks (varied skills)
- 🎤 3 Interview Questions (verbal practice)

---

# 🏆 GOLDEN TOPICS (5)

---

### TICKET-021 | 🔴 URGENT | Kubernetes | C-Rank
**From:** Senior Consultant (Sarah)
**Channel:** #client-fintech-prod

> Client's security team just discovered a pod in production running as root with full capabilities. They're panicking about their SOC2 audit next week.
>
> ```yaml
> # Current pod spec (discovered in prod)
> apiVersion: v1
> kind: Pod
> metadata:
>   name: legacy-batch-processor
>   namespace: production
> spec:
>   containers:
>   - name: processor
>     image: internal/batch:v2.3
>     securityContext:
>       runAsUser: 0
>       capabilities:
>         add: ["ALL"]
> ```
>
> They're asking:
> 1. How bad is this?
> 2. Can we fix it without rewriting the app?
> 3. What should our policy be going forward?
>
> Call with their CISO in 45 minutes.

**Deliverable:**
1. Risk assessment - what could an attacker do with this config?
2. Hardened pod spec (assume app needs to bind to port 80)
3. Recommended Pod Security Standard level for production
4. Talking points for Sarah's CISO call (non-technical language)

---

### TICKET-022 | 🟡 Medium | OPA/Gatekeeper | D-Rank
**From:** Platform Team
**Channel:** #platform-alerts

> Our Gatekeeper constraint for blocking `hostNetwork: true` is causing false positives. CNI pods in `kube-system` legitimately need host networking.
>
> Current constraint:
> ```yaml
> apiVersion: constraints.gatekeeper.sh/v1beta1
> kind: K8sBlockHostNetwork
> metadata:
>   name: block-host-network
> spec:
>   match:
>     kinds:
>       - apiGroups: [""]
>         kinds: ["Pod"]
> ```
>
> DevOps is complaining they can't upgrade their CNI plugin. Fix it.

**Deliverable:**
1. Updated constraint YAML with proper exclusions
2. What's the difference between `excludedNamespaces` and namespace selectors?
3. How would you test this doesn't break CNI pods?
4. Should system pods be excluded by namespace or by label?

---

### TICKET-023 | 🟡 Medium | CI/CD Security | C-Rank
**From:** Jira (Security Team)
**Project:** SEC-Audit-2026

> **Title:** Implement OIDC authentication for GitHub Actions to AWS
>
> We're eliminating long-lived AWS credentials from all pipelines. Current state: 47 repos use `AWS_ACCESS_KEY_ID` secrets.
>
> Requirements:
> - Create reusable workflow for AWS OIDC auth
> - Document migration path for teams
> - Handle multi-account (dev, staging, prod)
> - Must work with existing role naming convention: `github-actions-{repo-name}`

**Deliverable:**
1. Reusable workflow YAML (`.github/workflows/aws-oidc-auth.yml`)
2. Example Terraform for IAM OIDC provider + role
3. Migration guide: 5-step process for teams to follow
4. How do you handle repos that deploy to multiple AWS accounts?

---

### TICKET-024 | 🟢 Low | Scripting/Automation | D-Rank
**From:** Internal Slack
**Channel:** #devsecops

> Our compliance team needs a weekly report of all S3 buckets without encryption. Currently someone runs this manually and pastes into Confluence.
>
> Write a Bash script that:
> 1. Lists all S3 buckets
> 2. Checks encryption status of each
> 3. Outputs unencrypted buckets in markdown table format
> 4. Optionally sends to Slack webhook
>
> Should run as a cron job.

**Deliverable:**
1. Bash script with proper error handling
2. Example cron entry
3. How would you handle AWS credentials for the cron job?
4. What would you add for multi-account scenarios?

---

### TICKET-025 | 🟡 Medium | API Integration | C-Rank
**From:** Platform Team
**Channel:** #infrastructure

> We need to build a webhook receiver for GitHub to trigger our security scans. When a PR is opened, it should:
>
> 1. Receive the webhook payload
> 2. Validate the signature (HMAC-SHA256)
> 3. Extract repo/branch info
> 4. Queue a scan job
> 5. Return 200 OK quickly (don't block)
>
> Build this in Python with Flask. Must be production-ready.

**Deliverable:**
1. Flask app with webhook endpoint
2. Signature validation function
3. How would you deploy this securely in Kubernetes?
4. What monitoring/alerting would you add?

---

# 🎲 RANDOM TASKS (2)

---

### TICKET-026 | 🟢 Low | Docker Security | E-Rank
**From:** Jira (from Sprint Planning)
**Project:** PLATFORM-Internal

> **Title:** Fix Hadolint findings on our base Dockerfile
>
> ```
> DL3007 - Using latest is prone to errors
> DL3008 - Pin versions in apt-get install
> DL3009 - Delete apt-get lists after installing
> DL3018 - Pin versions in pip install
> DL4006 - Set SHELL option -o pipefail
> ```
>
> Current Dockerfile:
> ```dockerfile
> FROM python:latest
> RUN apt-get update && apt-get install -y curl jq
> RUN pip install requests boto3 pyyaml
> COPY . /app
> CMD ["python", "/app/main.py"]
> ```

**Deliverable:**
1. Fixed Dockerfile addressing all findings
2. What does `-o pipefail` do and why does it matter?
3. How do you find the right version pins for apt packages?

---

### TICKET-027 | 🟡 Medium | Client Reporting | B-Rank
**From:** Email from Client (forwarded by Mike)
**Client:** HealthVault (HIPAA)

> "We need a weekly security status report for our board. They want to see:
>
> - Number of vulnerabilities by severity
> - Trend over last 4 weeks
> - Top 5 issues and remediation status
> - Compliance score (if available)
>
> Can you design a report template and explain what data sources we'd need?"

**Deliverable:**
1. Report template (markdown or HTML structure)
2. What data sources would feed this report?
3. How would you automate report generation?
4. What would make this report useful vs just noise?

---

# 🎤 INTERVIEW QUESTIONS (3)

*Answer these as if you're in an interview. Speak out loud or write as you would explain verbally. Structure matters.*

---

### INTERVIEW-04 | Explain a Concept
**Interviewer:** "Explain the difference between authentication and authorization, and give examples from AWS and Kubernetes."

**Your Task:**
- Define both terms clearly
- AWS examples: IAM users vs IAM policies, STS AssumeRole
- Kubernetes examples: ServiceAccounts vs RBAC
- Common mistakes you've seen

**Format:** 2-3 minute verbal explanation

---

### INTERVIEW-05 | Past Experience
**Interviewer:** "Tell me about a time you had to debug a difficult production issue. What was your approach?"

**Your Task:**
- Pick a real or realistic scenario (K8s, AWS, CI/CD)
- Use STAR format: Situation, Task, Action, Result
- Emphasize your systematic debugging approach
- Include what you learned

**Format:** 3-4 minute structured story

---

### INTERVIEW-06 | Security Tradeoffs
**Interviewer:** "A development team says your security policies are slowing them down. How do you handle this?"

**Your Task:**
- Acknowledge the tension (security vs velocity)
- Give specific examples of how you'd investigate
- Propose solutions that address both needs
- Discuss how to build security into the workflow, not bolt it on

**Format:** Structured discussion with examples

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
- [ ] Kubernetes (TICKET-021)
- [ ] OPA/Gatekeeper (TICKET-022)
- [ ] CI/CD Security (TICKET-023)
- [ ] Scripting/Automation (TICKET-024)
- [ ] API Integration (TICKET-025)

### Random Tasks
- [ ] Docker Security (TICKET-026)
- [ ] Client Reporting (TICKET-027)

### Interview Practice
- [ ] Explain: AuthN vs AuthZ (INTERVIEW-04)
- [ ] Past Experience: Production debugging (INTERVIEW-05)
- [ ] Tradeoffs: Security vs Velocity (INTERVIEW-06)

---

## Rank Distribution

| Rank | Count | Tickets |
|------|-------|---------|
| E | 1 | TICKET-026 (Docker) |
| D | 2 | TICKET-022, TICKET-024 |
| C | 3 | TICKET-021, TICKET-023, TICKET-025 |
| B | 1 | TICKET-027 (Client Reporting) |

---

*Sarah needs those CISO talking points before her 4:30 call.*

*The weekend can wait. Handle the security context issue first, then work through the rest.*

*Interview questions? Do them on your commute home - talk through them out loud.*

*Show me you can prioritize under pressure.* 🎯
