*cracks neck, pulls up a chair*

Alright. Let's do this. Welcome to the simulation.

---

## 📋 The Rules of Engagement

**How this works:**

1. I send you 5 tickets each day - mixed difficulty, mixed domains
2. You respond with your solutions - code, explanations, whatever the ticket asks
3. I grade you like a senior engineer doing a code review - honest, constructive, sometimes brutal
4. We track patterns - where you're strong, where you're slipping

**Response format for each ticket:**
```
TICKET-XXX:
- What I did:
- Why I did it this way:
- What I'd check/test:
- Confidence level (1-10):
```

That last one matters. Knowing what you *don't* know is half the battle.

---

## 🎫 DAY 1 - Thursday Morning

*You walk in, coffee in hand. Slack is already blowing up.*

---

### TICKET-001 | 🔴 URGENT | Kubernetes
**From:** Senior Consultant (Sarah)
**Channel:** #client-fintech-prod

> Hey, client's pod keeps crash-looping. They're freaking out. Here's what `kubectl describe pod payment-api-7d8f9` shows:
>
> ```
> State: Waiting
> Reason: CrashLoopBackOff
> Last State: Terminated
> Reason: OOMKilled
> Exit Code: 137
> ```
>
> Container specs show `resources: {}` (empty). Client says "it worked fine yesterday." They're asking for a call in 30 mins. Can you draft what we should recommend?

**Deliverable:** 
1. What's happening and why?
2. Draft a fix (YAML snippet)
3. 2-3 bullet points for Sarah to say on the call

---

### TICKET-002 | 🟡 Medium | Terraform + AWS
**From:** Jira (assigned by Tech Lead)
**Project:** FINANCE-SecureBank

> **Title:** S3 bucket missing encryption and versioning
>
> Checkov flagged `CKV_AWS_145` and `CKV_AWS_21` on our `tf/storage.tf`. Client audit is next week. Fix it without breaking existing objects.

**Deliverable:**
1. The corrected Terraform code
2. One-sentence explanation of what each flag means
3. Any concerns about applying this to an existing bucket?

---

### TICKET-003 | 🟢 Low | OPA/Gatekeeper
**From:** Internal Slack
**Channel:** #platform-team

> We need a Gatekeeper ConstraintTemplate that denies any Pod that doesn't have *both* `app` and `environment` labels. Junior devs keep forgetting. Make it educational - good violation message.

**Deliverable:**
1. ConstraintTemplate YAML
2. Constraint YAML (apply to `default` namespace only)
3. Example of a Pod that would PASS and one that would FAIL

---

### TICKET-004 | 🟡 Medium | CI/CD Security
**From:** Email from Client (forwarded by Sarah)

> "We're using GitHub Actions for our pipeline. Our security team is asking if we're following best practices. Can you review our workflow and flag any issues?"
>
> ```yaml
> name: Build and Deploy
> on: [push]
> 
> jobs:
>   deploy:
>     runs-on: ubuntu-latest
>     steps:
>       - uses: actions/checkout@v2
>       - name: Deploy to prod
>         run: |
>           aws s3 sync ./dist s3://prod-bucket
>         env:
>           AWS_ACCESS_KEY_ID: AKIAIOSFODNN7EXAMPLE  # pragma: allowlist secret (example key)
>           AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_KEY }}
> ```

**Deliverable:**
1. List every security issue you see (aim for at least 4)
2. Corrected workflow YAML
3. Priority order - which fix is most urgent and why?

---

### TICKET-005 | 🟢 Low | Documentation
**From:** Confluence Task
**Project:** Internal Knowledge Base

> Write a runbook section: "How to rotate AWS IAM access keys for a service account without downtime"
>
> Target audience: Junior engineers who might be doing this for the first time at 2am during an incident.

**Deliverable:**
- Step-by-step runbook (numbered steps)
- Include rollback procedure
- Add a "Common Mistakes" section

---

## ⏱️ Time Simulation

| Ticket | Real-world time budget |
|--------|------------------------|
| 001 | 15 mins (urgent) |
| 002 | 30 mins |
| 003 | 25 mins |
| 004 | 20 mins |
| 005 | 30 mins |

Total: ~2 hours of focused work. This is roughly half a day - the other half would be meetings, standups, and context-switching.

---

*slides the tickets across the table*

No pressure. Take your time. Answer when you're ready - one at a time or all at once, your call.

But remember: in the real world, TICKET-001 can't wait. That client call is in 30 minutes. Prioritize like it's real.

Show me what you got, J. 🎯