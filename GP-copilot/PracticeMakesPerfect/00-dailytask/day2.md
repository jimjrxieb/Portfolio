*Monday morning. Three unread emails marked urgent. Coffee's not going to cut it.*

---

## DAY 2 - Monday Morning

*You open Slack. The on-call channel is hot.*

---

### TICKET-006 | 🔴 URGENT | Kubernetes + AWS
**From:** On-call Engineer (Mike)
**Channel:** #incident-high

> Pods in the `payment-service` namespace can't pull secrets from AWS Secrets Manager. Started failing 20 mins ago after someone ran `terraform apply` on the IAM module.
>
> ```
> Error: AccessDeniedException: User: arn:aws:sts::123456789:assumed-role/payment-service-role/...
> is not authorized to perform: secretsmanager:GetSecretValue on resource: arn:aws:secretsmanager:us-east-1:123456789:secret:prod/payment/db-creds
> ```
>
> Payments are failing. Client is aware. We need this fixed NOW.

**Deliverable:**
1. What likely broke and why?
2. Fastest fix to restore service (IAM policy snippet or console steps)
3. How to verify it's working
4. What should've prevented this?

---

### TICKET-007 | 🟡 Medium | OPA/Gatekeeper
**From:** Jira (Security Team)
**Project:** SEC-Audit-2026

> **Title:** Implement container image registry restriction
>
> Compliance requires all production workloads pull images ONLY from our approved registries:
> - `ghcr.io/our-org/*`
> - `123456789.dkr.ecr.us-east-1.amazonaws.com/*`
>
> Block everything else. We need this before the SOC2 audit.

**Deliverable:**
1. ConstraintTemplate YAML (Rego logic)
2. Constraint YAML (apply to `production` namespace)
3. Example Pod that PASSES (uses approved registry)
4. Example Pod that FAILS (uses `docker.io`)
5. How would you test this before enforcing?

---

### TICKET-008 | 🟡 Medium | Terraform + AWS Security
**From:** Email from Client (forwarded by Sarah)

> "Our security scan flagged these Terraform issues. Can you fix them before our audit next week?"
>
> ```
> CKV_AWS_19: Ensure all data stored in ECR is encrypted
> CKV_AWS_163: Ensure ECR image scan on push is enabled
> CKV_AWS_136: Ensure ECR repositories are encrypted using KMS
> ```
>
> Current code:
> ```hcl
> resource "aws_ecr_repository" "app" {
>   name = "our-app"
> }
> ```

**Deliverable:**
1. Corrected Terraform code
2. One-sentence explanation of each Checkov rule
3. Should we use AWS-managed KMS or customer-managed? Why?

---

### TICKET-009 | 🟢 Low | Application Hardening
**From:** Platform Team
**Channel:** #devsecops

> We're standardizing our Dockerfile security. Can you review this and create a hardened version?
>
> ```dockerfile
> FROM python:3.11
> WORKDIR /app
> COPY . .
> RUN pip install -r requirements.txt
> EXPOSE 8080
> CMD ["python", "app.py"]
> ```
>
> Target: Pass Checkov and Trivy with zero HIGH/CRITICAL findings.

**Deliverable:**
1. List security issues in the current Dockerfile (aim for 5+)
2. Hardened Dockerfile with comments explaining each change
3. What base image would you recommend and why?

---

### TICKET-010 | 🟢 Low | CI/CD + MLOps
**From:** Confluence Task
**Project:** Internal Knowledge Base

> The ML team is deploying models via GitHub Actions. They're asking for a security review of their pipeline pattern:
>
> ```yaml
> name: Deploy Model
> on:
>   push:
>     paths: ['models/**']
>
> jobs:
>   deploy:
>     runs-on: ubuntu-latest
>     steps:
>       - uses: actions/checkout@v3
>       - name: Setup Python
>         uses: actions/setup-python@v4
>       - name: Deploy to SageMaker
>         run: |
>           pip install boto3 sagemaker
>           python deploy_model.py
>         env:
>           AWS_ACCESS_KEY_ID: ${{ secrets.AWS_KEY }}
>           AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET }}
>           MODEL_BUCKET: ml-models-prod
> ```
>
> Write recommendations as if you're mentoring a junior ML engineer.

**Deliverable:**
1. Security issues in this workflow (aim for 4+)
2. Corrected workflow using OIDC instead of long-lived keys
3. What additional controls would you recommend for ML model deployments?

---

### TICKET-011 | 🔴 URGENT | Secrets Management
**From:** Sarah (Senior Consultant)
**Channel:** #client-healthvault-prod

Client just called in a panic. They found this in their EKS deployment:
yamlapiVersion: v1
kind: Pod
metadata:
  name: api-server
spec:
  containers:
  - name: app
    image: healthvault/api:latest
    env:
    - name: DB_PASSWORD
      value: "Pr0d_P@ssw0rd_2024!"
    - name: JWT_SECRET
      value: "super-secret-jwt-key-do-not-share"
    - name: AWS_ACCESS_KEY_ID
      value: "AKIAIOSFODNN7EXAMPLE"  # pragma: allowlist secret (example key)
This is in their Git repo. They're asking what to do RIGHT NOW.

**Deliverable:**

1. Immediate triage - what are the 3 things they need to do in the next 30 minutes?
2. Proper fix - show the corrected YAML using Kubernetes Secrets
3. Better fix - show how to use External Secrets Operator or AWS Secrets Manager
4. What rank would YOUR classifier assign this? Why?


### TICKET-012 | 🟡 Medium | Terraform State Security
**From:** Jira (assigned by Tech Lead)
**Project:** DEFENSE-TacticalNet

Security review flagged our Terraform setup. Current backend config:
hclterraform {
  backend "s3" {
    bucket = "tacticalnet-tfstate"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}
Auditor is asking: "How do you prevent two engineers from running terraform apply at the same time? How do you know who changed what?"

**Deliverable:**

1. What are the TWO security issues with this backend config?
2. Corrected Terraform with state locking and encryption
3. One-paragraph explanation for the auditor (non-technical language)


### TICKET-013 | 🟢 Low | Feedback Loop Validation
**From:** Internal (Self-assigned)
**Project:** GP-Copilot

You just built the feedback loop. Now prove it works.
Create a test scenario:

Simulate a finding going through the classifier
Simulate a human "rejecting" the rank and correcting it
Show the resulting log entry in decisions.jsonl
Explain how this logged data becomes future training data


**Deliverable:**

Test script or manual steps to validate the feedback loop
Example log entry (the actual JSON that would be written)
Diagram or explanation: log → training data → improved classifier

---

## ⏱️ Time Budget

| Ticket | Domain | Time |
|--------|--------|------|
| 006 | K8s + IAM | 15 mins |
| 007 | OPA/Gatekeeper | 30 mins |
| 008 | Terraform/ECR | 25 mins |
| 009 | Container Security | 25 mins |
| 010 | CI/CD + MLOps | 25 mins |

**Total: ~2 hours**

---

*Mike's pinging you again. That IAM issue isn't going to fix itself.*

Prioritize like it's real. TICKET-006 is bleeding money. Go. 🎯
