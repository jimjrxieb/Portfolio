# Day 3 Validation Report

**Reviewed by:** Claude Code
**Date:** 2026-01-14
**Overall Assessment:** Solid fundamentals, gaps in completeness and interview depth

---

## Scoring Summary

| Ticket | Topic | Score | Verdict |
|--------|-------|-------|---------|
| TICKET-014 | Kubernetes | 7/10 | Core answer correct, missing debug commands |
| TICKET-015 | OPA/Gatekeeper | 5/10 | Template good, missing 4 of 5 deliverables |
| TICKET-016 | CI/CD Security | 9/10 | Excellent understanding |
| TICKET-017 | Scripting | 6/10 | Good concepts, can't validate the code |
| TICKET-018 | API Integration | 7/10 | Good hypothesis, missing structured checklist |
| TICKET-019 | Helm Charts | 8/10 | Solid answer |
| TICKET-020 | IAM Roles | 7/10 | Good extraction from AI, needs hands-on practice |
| INTERVIEW-01 | PSS | 4/10 | Too brief, missing structure |
| INTERVIEW-02 | OOMKilled | 3/10 | Too brief, no commands |
| INTERVIEW-03 | Secrets | 4/10 | Too brief, no trade-offs |

---

## TICKET-014 | Kubernetes

### What You Got Right
- **Root cause identification: CORRECT** - Probe on 8080, app on 3000
- **Quick fix approach: CORRECT** - Edit deployment, change port
- **Prevention idea: CORRECT** - Conftest policy is the right tool
- **Understanding the urgency: CORRECT** - This is blocking a release

### What I'd Change

**1. Your kubectl command has a typo:**
```bash
# You wrote:
kubectl get pods get pods -n payments  # <-- "get pods" repeated

# Should be:
kubectl get pods -n payments
```

**2. Missing the debug command that proves the issue:**
```bash
# ALWAYS run this first when probes fail:
kubectl describe pod payment-api-v2-def456-p9r8s -n payments

# Look for:
# - Events section showing "Readiness probe failed"
# - Container port in spec
```

**3. Two fixes were asked - you only gave one:**
```
Quick fix: kubectl edit deployment (you got this)
Proper fix: Fix the Helm chart/manifest at source, redeploy via CI
```

**4. Your Conftest policy has a logic gap:**
```rego
# Your version checks if probe port != container port
# But what if the app listens on MULTIPLE ports?
# Or what if there's no containerPort defined?

# Better version:
deny[msg] {
    container := input.spec.template.spec.containers[_]
    probe := container.readinessProbe.httpGet
    probe.port != container.ports[0].containerPort  # Check primary port
    msg := sprintf("Probe port %v doesn't match container port", [probe.port])
}

# Even better: Check if probe port exists in ANY container port
deny[msg] {
    container := input.spec.template.spec.containers[_]
    probe_port := container.readinessProbe.httpGet.port
    not port_exists(container.ports, probe_port)
    msg := sprintf("Probe port %v not found in container ports", [probe_port])
}

port_exists(ports, target) {
    ports[_].containerPort == target
}
```

### Gap to Study
- **`kubectl describe` output reading** - Learn to parse the Events section
- **Rollback commands** - `kubectl rollout undo deployment/payment-api-v2 -n payments`

---

## TICKET-015 | OPA/Gatekeeper

### What You Got Right
- **ConstraintTemplate structure: CORRECT**
- **Rego logic for privileged + allowPrivilegeEscalation: CORRECT**
- **Helper function for all container types: EXCELLENT** - Including init + ephemeral
- **Clear error messages: CORRECT**

### What's Missing (4 of 5 deliverables)

**1. Constraint YAML with namespace exclusion - NOT PROVIDED:**
```yaml
# k8s-block-privileged-constraint.yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockPrivileged
metadata:
  name: block-privileged-containers
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
      - apiGroups: ["apps"]
        kinds: ["Deployment", "DaemonSet", "StatefulSet"]
    excludedNamespaces:
      - kube-system  # <-- THE EXCLUSION THEY ASKED FOR
```

**2. Example Pod that PASSES - NOT PROVIDED:**
```yaml
# good-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  containers:
    - name: app
      image: nginx:alpine
      securityContext:
        allowPrivilegeEscalation: false
        privileged: false
        runAsNonRoot: true
        capabilities:
          drop: ["ALL"]
```

**3. Example Pod that FAILS - NOT PROVIDED:**
```yaml
# bad-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
spec:
  containers:
    - name: app
      image: nginx
      securityContext:
        privileged: true  # <-- BLOCKED
```

**4. Rollout strategy - NOT PROVIDED:**
```
Safe rollout for existing cluster:
1. Deploy ConstraintTemplate
2. Deploy Constraint with enforcementAction: warn (not deny)
3. Monitor audit logs for violations
4. Fix existing violations
5. Change to enforcementAction: deny
```

### Gap to Study
- **Complete the deliverables** - In interviews/tickets, incomplete answers = partial credit
- **Gatekeeper enforcement modes** - `deny`, `warn`, `dryrun`

---

## TICKET-016 | CI/CD Security

### What You Got Right
- **Root cause: CORRECT** - Fallback pattern exposes secret in source code
- **Secure fix: CORRECT** - Fail fast, no fallback
- **When to use .gitleaksignore: CORRECT** - Test keys yes, real secrets never
- **Custom .gitleaks.toml: CORRECT** - Allow test keys, explicitly block live

### What I'd Add

**One clarification for interviews:**
```
WHY Gitleaks caught it even though "it's an env var":

Gitleaks scans the CODE, not runtime behavior.
The || fallback means the literal string "sk_live_..."
is IN THE SOURCE FILE, committed to Git history.

Even if process.env.STRIPE_KEY works at runtime,
the fallback is still exposed in:
- Git history
- GitHub search
- Any clone of the repo
```

### No Gaps - You nailed this one.

---

## TICKET-017 | Scripting/Automation

### What You Got Right
- **Understanding the ask: CORRECT**
- **Script structure explanation: GOOD**
- **Token security (file > command line): CORRECT**
- **Logging requirements: GOOD**
- **Honest confidence level: APPRECIATED** (3/10)

### The Problem: You Can't Validate the Script

You wrote: "Still relying on Claude to be correct"

**This is the gap.** Here's how to validate AI-generated code yourself:

**1. Check for obvious issues:**
```python
# Line 565 in the script:
import os  # <-- This should be at the TOP of the file, not inside main()

# This works, but it's bad practice. A code reviewer would flag it.
```

**2. Check the API calls are real:**
```bash
# Does this endpoint exist?
# GET /repos/{owner}/{repo}/actions/secrets/public-key

# Verify: https://docs.github.com/en/rest/actions/secrets
# Answer: YES, it's real
```

**3. Check error handling:**
```python
# The script has:
if response.status_code in [201, 204]:
    return True

# But what about rate limiting (403)?
# What about network errors?
# Missing: requests.exceptions.RequestException handling
```

**4. Test incrementally:**
```bash
# Don't run the full script first. Test each function:
python -c "from rotate_token import get_headers; print(get_headers('test'))"
```

### Gap to Study
- **Read Python code critically** - Line by line, ask "what could go wrong?"
- **GitHub API documentation** - Know how to verify endpoints
- **requests library error handling** - `try/except requests.exceptions.RequestException`

---

## TICKET-018 | API Integration

### What You Got Right
- **Understanding the problem: CORRECT**
- **Secret rotation hypothesis: CORRECT**
- **Container restart as fix: CORRECT**
- **Fetch-at-runtime pattern: CORRECT**

### What's Missing

**Deliverable 1 asked for "5 things to check" - you didn't list them:**
```
1. Is the env var set? (print length, not value)
2. When was the secret last rotated in Secrets Manager?
3. When was the container last restarted?
4. Is there whitespace/newline in the secret?
5. Did the dashboard-side key expire?
```

**Deliverable 2 asked "How to verify the API key is being loaded":**
```python
# Add debug logging (temporarily):
API_KEY = os.getenv("DASHBOARD_API_KEY")
print(f"API_KEY present: {API_KEY is not None}")
print(f"API_KEY length: {len(API_KEY) if API_KEY else 0}")
# NEVER print the actual key
```

**Deliverable 4 asked "How to make it more resilient":**
```python
# You mentioned get_api_key() but didn't cover:
# - Retry logic
# - Circuit breaker
# - Fallback behavior (queue findings locally if API down)
# - Alerting on repeated failures
```

### Gap to Study
- **Structured troubleshooting** - Create mental checklists
- **Resilience patterns** - Retry, circuit breaker, graceful degradation

---

## TICKET-019 | Helm Charts

### What You Got Right
- **Resource values: REASONABLE**
- **Requests vs limits explanation: CORRECT**
- **Profiling approach: CORRECT** (Profile > Conservative > Observe > Tune)

### What I'd Add

**Your explanation of QoS was slightly off:**
```
You wrote: "For Guaranteed space we use QoS class implications"

Clearer version:
- Guaranteed QoS = requests EQUAL limits
- Burstable QoS = requests LESS THAN limits (what your example has)
- BestEffort QoS = no requests or limits at all

Your example is Burstable (100m/256Mi request, 1000m/1Gi limit)
```

**You didn't answer "Could I explain this in an interview?"**

### Gap to Study
- **QoS classes** - Know the three types and when to use each
- **Pod Priority and Preemption** - Related concept for eviction protection

---

## TICKET-020 | IAM Roles

### What You Got Right
- **CLI commands: CORRECT**
- **Naming convention: CORRECT**
- **Governance process: CORRECT**
- **Honest confidence level: APPRECIATED** (5/10)

### The Gap

You wrote: "Could I explain this in an interview? No"

**What you need to practice:**

```
"Walk me through how you'd audit IAM roles"

Your answer should be:
1. "First, I'd pull all roles and their last-used dates using
   aws iam list-roles with a query for RoleLastUsed"

2. "Roles not used in 90 days get flagged for review"

3. "Then I'd check for overly permissive policies -
   anything with Action:* or Resource:* is a red flag"

4. "For each flagged role, I'd work with the owner to either
   scope it down or document why it needs those permissions"

5. "Ongoing, I'd set up AWS Config rules to catch new
   violations automatically"
```

**Practice saying this out loud until it's natural.**

### Gap to Study
- **AWS IAM Access Analyzer** - Hands-on in AWS console
- **AWS Config rules for IAM** - `iam-policy-no-statements-with-admin-access`

---

## Interview Questions - Critical Feedback

### INTERVIEW-01 | Pod Security Standards

**Your answer was too brief. Compare:**

| What You Said | What Interviewers Want |
|---------------|------------------------|
| 1 paragraph summary | 2-3 minute structured explanation |
| Mentioned 3 levels | Didn't explain what each level blocks |
| Mentioned PSA | Didn't explain how to apply it |

**Better structure:**
```
"Pod Security Standards are Kubernetes' built-in way to enforce
security policies at the namespace level. There are three levels:

PRIVILEGED - No restrictions. Use for system components like
CNI plugins or monitoring agents that genuinely need host access.

BASELINE - Blocks the most dangerous settings like hostNetwork,
hostPID, and privileged containers. This is your default for
most workloads.

RESTRICTED - The strictest. Requires runAsNonRoot, drops all
capabilities, enforces read-only root filesystem. Use for
sensitive workloads handling customer data.

You apply these via Pod Security Admission by labeling namespaces:
  pod-security.kubernetes.io/enforce: restricted
  pod-security.kubernetes.io/warn: restricted

The warn mode lets you see what would break before enforcing."
```

---

### INTERVIEW-02 | OOMKilled Troubleshooting

**Your answer was a summary, not a walkthrough.**

**Better structure:**
```
"When I see OOMKilled, here's my process:

STEP 1: Confirm it's OOMKilled
  kubectl describe pod <name> | grep -A5 'Last State'
  Look for: Reason: OOMKilled

STEP 2: Check current limits
  kubectl get pod <name> -o jsonpath='{.spec.containers[*].resources}'

STEP 3: Check actual usage before the kill
  kubectl top pod <name>  # If it's running
  Or check Prometheus: container_memory_working_set_bytes

STEP 4: Is it a leak or undersized?
  - If memory grows steadily over time → LEAK
  - If memory spikes during specific operations → UNDERSIZED

  For leaks: kubectl logs --previous to see what it was doing

STEP 5: Short-term fix
  Increase memory limit by 50%
  kubectl set resources deployment/<name> --limits=memory=768Mi

STEP 6: Long-term fix
  - For leaks: Fix the code, add profiling
  - For undersized: Right-size based on observed P99 usage"
```

---

### INTERVIEW-03 | Secrets Management

**Your answer was a thesis statement, not an architecture discussion.**

**Better structure:**
```
"For secrets management in Kubernetes, I'd consider three approaches:

OPTION 1: Native Kubernetes Secrets
  Pros: Simple, no external dependencies
  Cons: Base64 encoded (not encrypted at rest by default),
        anyone with RBAC access can read them
  Use when: Low-security environments, dev clusters

OPTION 2: External Secrets Operator + AWS Secrets Manager
  Pros: Secrets never stored in etcd, audit trail, rotation
  Cons: External dependency, network calls to fetch secrets
  Use when: AWS-native shops, need rotation without redeploy

OPTION 3: HashiCorp Vault
  Pros: Dynamic secrets, fine-grained policies, comprehensive audit
  Cons: Operational complexity, another system to maintain
  Use when: Multi-cloud, need dynamic database credentials

For HIPAA/PCI, I'd require:
  - Encryption at rest (not native K8s secrets)
  - Audit logs of every access
  - Automated rotation

So I'd recommend Vault or External Secrets, depending on
whether they're already invested in Vault."
```

---

## Study Plan Based on Gaps

### Priority 1: Interview Depth (Practice Daily)
- [ ] Practice **INTERVIEW-01, 02, 03** answers out loud
- [ ] Time yourself - aim for 2-3 minutes per answer
- [ ] Record yourself, listen back

### Priority 2: Complete Answers
- [ ] When a ticket asks for 5 things, provide 5 things
- [ ] Use checklists to track deliverables

### Priority 3: Code Validation Skills
- [ ] Practice reading Python scripts line by line
- [ ] For each function: "What happens if this fails?"
- [ ] Verify API endpoints against official docs

### Priority 4: Hands-On Practice
- [ ] Create a Gatekeeper policy and test it in a real cluster
- [ ] Run `aws iam list-roles` on a real AWS account
- [ ] Deploy a pod that violates PSS and see the error

---

## Key Takeaway

**Your instincts are correct** - you identified root causes accurately on most tickets. The gaps are:

1. **Completeness** - Answer ALL parts of the question
2. **Interview depth** - Summaries aren't enough, walk through step-by-step
3. **Validation** - You said "relying on AI to be correct" multiple times. Build the skills to verify.

You're not just crossing your fingers - you're building pattern recognition. Keep going.