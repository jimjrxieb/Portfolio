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
### What I Tried First:
<!-- Before asking AI, what did YOU think the answer was? Steps taken? -->
Inspect the pod manifest and found bad securityContext: implementations. Checked cheatsheet for best practice securityContext: patches. 
### AI Solution:
<!-- Since alot will be produced using AI, is it correct? -->
1. How Bad Is This?
Severity: CRITICAL

Risk	Impact
Container escape	Root + ALL caps = trivial breakout to node
Lateral movement	Full access to host filesystem, network, processes
Privilege escalation	Can mount host paths, access other containers
SOC2 finding	CC6.1 (Logical Access) violation - guaranteed audit finding
What "capabilities: ALL" actually grants:


CAP_SYS_ADMIN    → Mount filesystems, escape containers
CAP_NET_ADMIN    → Sniff traffic, modify routing
CAP_SYS_PTRACE   → Debug/inject into other processes
CAP_DAC_OVERRIDE → Bypass all file permission checks
... and 30+ more
Auditor perspective: This is a textbook "fail the control" finding. They will ask: "How did this reach production? Where are your preventive controls?"

2. Can We Fix It Without Rewriting the App?
Yes, in most cases. Here's the approach:

Step 1: Determine what the app actually needs

# Check what the container is actually doing
kubectl exec -n production legacy-batch-processor -- cat /proc/1/status | grep Cap

# Or run it locally with tracing
docker run --rm -it --cap-drop=ALL internal/batch:v2.3
# See what fails, add back only what's needed
Step 2: Apply minimal security context
Most batch processors need NONE of these. Start with the restrictive version:


apiVersion: v1
kind: Pod
metadata:
  name: legacy-batch-processor
  namespace: production
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: processor
    image: internal/batch:v2.3
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
        # Add back ONLY if proven necessary:
        # add: ["NET_BIND_SERVICE"]  # If binding to ports < 1024
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: data
      mountPath: /data
  volumes:
  - name: tmp
    emptyDir: {}
  - name: data
    emptyDir: {}
Step 3: If it breaks, iterate
Error	Capability to Add
Can't bind to port 80	NET_BIND_SERVICE (or change to port 8080)
Can't change user	SETUID, SETGID (question why it needs this)
Can't write to /tmp	Mount an emptyDir (not a capability issue)
Step 4: If it truly requires root

# Last resort - document and isolate
securityContext:
  runAsUser: 0  # Documented exception
  capabilities:
    drop: ["ALL"]
    add: ["CHOWN"]  # ONLY what's proven necessary
Plus: Isolate it with NetworkPolicy, dedicated node pool, extra monitoring.

3. Policy Going Forward
Immediate (Before Audit)

# 1. Apply Pod Security Standards to namespace
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted

# 2. Find all other violations
kubectl get pods -A -o json | jq -r '
  .items[] | 
  select(.spec.containers[].securityContext.runAsUser == 0) |
  "\(.metadata.namespace)/\(.metadata.name)"
'
Preventive Controls (Show Auditor These)
A. Admission Control (Gatekeeper/Kyverno)


# Block privileged containers at admission
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sPSPCapabilities
metadata:
  name: prevent-all-capabilities
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces: ["kube-system"]
  parameters:
    requiredDropCapabilities: ["ALL"]
    allowedCapabilities: []
B. CI/CD Gate (Conftest)


# policy/pod-security.rego
deny[msg] {
    input.kind == "Pod"
    container := input.spec.containers[_]
    container.securityContext.runAsUser == 0
    msg := "Containers must not run as root"
}

deny[msg] {
    input.kind == "Pod"
    container := input.spec.containers[_]
    container.securityContext.capabilities.add[_] == "ALL"
    msg := "Adding ALL capabilities is prohibited"
}
C. Runtime Detection (Falco)


- rule: Container Running as Root
  condition: spawned_process and container and user.uid = 0
  output: "Root shell in container (user=%user.name container=%container.name)"
  priority: WARNING
SOC2 Audit Talking Points
When the auditor asks about this finding:


"We identified this legacy workload during our continuous security 
monitoring. We've remediated it by applying least-privilege security 
contexts. Going forward, we've implemented:

1. Pod Security Standards enforced at namespace level
2. Admission controllers blocking privileged containers
3. CI/CD policy checks preventing deployment of non-compliant specs
4. Runtime monitoring alerting on root execution

Here's the evidence: [show policy YAMLs, admission logs, CI pipeline]"
Key phrase: "We found it before you did, and here's our systemic fix."
### Deliverables: 
<!-- Answers to the question -->
1. an attacker could use this config to run harmful code or access anything without limits. 
2. add drop: ["ALL"] to container securitycontext andlong with allowPrivilegeEscalation: false
3. readonly until correct privileges are provided
4. Incorrect pod privileges were allowed. This was an CRIICAL matter so we patched the manifest with the best practice securityContext. we also implemented new OPA to prevent this from being created again. 
      
### How to prevent in the future:
<!-- How do harden application? What should our policy be going forward? -->
write a new opa policy and add Restricted labels to the namespace aswell
### What I Learned:
<!-- One concept I understand better now -->
Still multiple ways to secure a pod. With namespace restrictions , securityContext and OPA policies
### Could I Explain This in an Interview? 
<!-- Yes/No - if No, what's the gap? -->
Somewhat. I understand that the pod was insecure and needed to have better implementations. The different levels above that i did not know. like ->[If it breaks, iterate
Error	Capability to Add
Can't bind to port 80	NET_BIND_SERVICE (or change to port 8080)
Can't change user	SETUID, SETGID (question why it needs this)
Can't write to /tmp	Mount an emptyDir (not a capability issue)
Step 4: If it truly requires root] new error codes i wouldve had to look up. 
### Confidence level: _5_/10
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
### What I Tried First:
<!-- Before asking AI, what did YOU think the answer was? Steps taken? -->
I would add an exception rule to the constraint. 
### AI Solution:
<!-- Since alot will be produced using AI, is it correct? -->
Add namespace exclusions to the constraint:


apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockHostNetwork
metadata:
  name: block-host-network
spec:
  match:
    kinds:

      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces:
      - kube-system
      - calico-system      # If using Calico
      - cilium             # If using Cilium
      - tigera-operator    # Calico Enterprise
Why This Works
excludedNamespaces tells Gatekeeper to skip enforcement for pods in these namespaces
CNI pods live in kube-system (or their own namespace depending on the CNI)
Regular workload namespaces still get blocked from using hostNetwork
Even Better: Label-Based Exclusion
If you want more precision than namespace-wide exceptions:


apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockHostNetwork
metadata:
  name: block-host-network
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces:
      - kube-system
  parameters:
    allowedLabels:
      - "app.kubernetes.io/component: cni"

### Deliverables: 
<!-- Answers to the question -->
1. added excludedNamespaces:
      - kube-system
      - calico-system      # If using Calico
      - cilium             # If using Cilium
      - tigera-operator    # Calico Enterprise 

2. excluded namespaces are hard coded and namespaace selectors are labels given at runtime.
3. I would run create a test pod that would fail apply it > kubectl rollout > verify pods are still working
### How to prevent in the future:
<!-- How do harden application? What would break? -->
Add a gatekeeper contraint with excludednamespace rule. 
### What I Learned:
<!-- One concept I understand better now -->
That this is also can be put into an opa policy. excludedNamespaces: is a rule we can use to make sure core pods stay running and arent affected by security standards or triggering alerts that are real. 
### Could I Explain This in an Interview? 
<!-- Yes/No - if No, what's the gap? -->
yes!
### Confidence level: _6_/10
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
### What I Tried First:
<!-- Before asking AI, what did YOU think the answer was? Steps taken? -->
I would ask AI. Im not confident enough to build AWS arch. 
### AI Solution:
<!-- Since alot will be produced using AI, is it correct? -->

### Deliverables: 
<!-- Answers to the question -->

### How to prevent in the future:
<!-- How do harden application? What would break? -->

### What I Learned:
<!-- One concept I understand better now -->

### Could I Explain This in an Interview? 
<!-- Yes/No - if No, what's the gap? -->

### Confidence level: __/10
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
