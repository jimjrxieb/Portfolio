# Day [1] Responses
**Date:** YYYY-MM-DD
**Started:** [HH:MM]
**Completed:** [HH:MM]

---

<!-- COPY THIS BLOCK FOR EACH TICKET -->

## TICKET-001 | [Title]
**Time spent:** __ mins

### What I did:
I investigated and confirmed the error being OOMkilled, meaning the pod is requesting more memory than whats alocated to the pod. 
### Why I did it this way:
To confirm for myself the error making sure the client and I are on the same page. 

### What I'd check/test:
I would check the state of the pod , I would check the memory requets and limits inside Deployment manifests. I would view the metrics on Grafana. View the node scheduler manifest and make sure pods are being created safely 

### Confidence level: _5_/10

### Deliverables:
1. OOMkilled means memory limits are being hit inside the pod and kubernetes kills it. 
2. apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: app-vpa
  namespace: your-namespace
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: your-deployment
  updatePolicy:
    updateMode: "Off"   # Recommendation-only (no pod restarts)
  resourcePolicy:
    containerPolicies:
    - containerName: "*"
      controlledResources:
        - memory
        - cpu
      minAllowed:
        memory: 256Mi
        cpu: 100m
      maxAllowed:
        memory: 2Gi
        cpu: 2000m
using a vpa we can further monitor pod usage and balance according. In the mean time have a >80% rate limit. 

3. - 1st lets increase the memory limits. Apply VPA and monitor the true metrics of the application to run properly. 
   - 2nd we can apply alerts to trigger >%80 memory cap. 
   - kubernetes is doing its job in killing the pod . the application it requesting more memory than we are providing. 

<!-- Add deliverable sections based on ticket requirements -->

---

<!-- END TICKET BLOCK -->

## Self-Assessment

**Tickets completed:** __/N
**Total time:** __ mins
**Hardest ticket:** TICKET-___
**Most confident:** TICKET-___
**Need to study more:**

--- 

# Day [1] Responses
**Date:** 2026-01-08
**Started:** [HH:MM]
**Completed:** [HH:MM]

---

<!-- COPY THIS BLOCK FOR EACH TICKET -->

## TICKET-002 | [Title]
**Time spent:** __ mins

### What I did:
Run the checkov scan. Confirm errors. Apply fixes based off CIS benchmark correctly to storage.tf . If allowed I would use my jsa-devsec agent and checkov fix npc. 

### Why I did it this way:
to confirm errors. research error codes , its not about memorizing errors but memorizing where to look and find solutions efficently. 

### What I'd check/test:


### Confidence level: 7_/10

### Deliverables:
1. resource "aws_s3_bucket" "storage" {
  bucket = var.bucket_name

  # Optional but recommended
  force_destroy = false

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

# ---------------------------------------------------
# CKV_AWS_21 — Enable Versioning
# ---------------------------------------------------
resource "aws_s3_bucket_versioning" "storage" {
  bucket = aws_s3_bucket.storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ---------------------------------------------------
# CKV_AWS_145 — Enable Encryption at Rest
# ---------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
      # OR use KMS if required:
      # sse_algorithm     = "aws:kms"
      # kms_master_key_id = aws_kms_key.s3.id
    }
  }
}
2. CKV_AWS_21 → S3 bucket versioning must be enabled - "Can I recover if something gets deleted?"
   CKV_AWS_145 → S3 bucket must have encryption at rest enabled - "Do I control the encryption keys, or does Amazon?"

3. nothing changes when you enable versioning. but when you start encrypting, everything from that moment is encrypted. but youll have to re-encrpyt the existing data. 
<!-- Add deliverable sections based on ticket requirements -->

---

<!-- END TICKET BLOCK -->

## Self-Assessment

**Tickets completed:** __/N
**Total time:** __ mins
**Hardest ticket:** TICKET-___
**Most confident:** TICKET-___
**Need to study more:**


# Day [1] Responses
**Date:** YYYY-MM-DD
**Started:** [HH:MM]
**Completed:** [HH:MM]

---

<!-- COPY THIS BLOCK FOR EACH TICKET -->

## TICKET-003 | [Title]
**Time spent:** __ mins

### What I did:
provided required yamls using Jade. 

### Why I did it this way:
Jade writes better yamls quicker than I can 

### What I'd check/test:
test pod to see if it works

### Confidence level: __/10

### Deliverables:
1. apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          properties:
            requiredLabels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels

        violation[{"msg": msg}] {
          input.review.kind.kind == "Pod"

          required := input.parameters.requiredLabels
          provided := object.get(input.review.object.metadata, "labels", {})

          missing := [label | label := required[_]; not provided[label]]

          count(missing) > 0

          msg := sprintf(
            "Pod rejected: missing required label(s): %v. All Pods must define BOTH 'app' and 'environment' labels (example: app=my-service, environment=dev). This helps with ownership, cost tracking, and incident response.",
            [missing]
          )
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-app-and-environment-labels
spec:
  match:
    namespaces:
      - default
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
  parameters:
    requiredLabels:
      - app
      - environment
3. passing pod 
apiVersion: v1
kind: Pod
metadata:
  name: good-pod
  namespace: default
  labels:
    app: payments-api
    environment: dev
spec:
  containers:
    - name: app
      image: nginx

failing pod 
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
  namespace: default
  labels:
    app: payments-api
spec:
  containers:
    - name: app
      image: nginx

<!-- Add deliverable sections based on ticket requirements -->

---

<!-- END TICKET BLOCK -->

## Self-Assessment

**Tickets completed:** __/N
**Total time:** __ mins
**Hardest ticket:** TICKET-___
**Most confident:** TICKET-___
**Need to study more:**


---

# Day [1] Responses
**Date:** YYYY-MM-DD
**Started:** [HH:MM]
**Completed:** [HH:MM]

---

<!-- COPY THIS BLOCK FOR EACH TICKET -->

## TICKET-004 | [Title]
**Time spent:** __ mins

### What I did:
viewed yaml . seen exposed secrets. 

### Why I did it this way:
following security best practices. 

### What I'd check/test:


### Confidence level: _5_/10

### Deliverables:
1. i see exposed secrets, pushed directly to prod. 
2. name: Build and Deploy

on:
  push:
    branches:
      - main

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-actions-prod
          aws-region: us-east-1

      - name: Deploy to S3
        run: |
          aws s3 sync ./dist s3://prod-bucket --delete
3. exposed secrets > needs to be rotated and push to prod without branching is dangerous. 

<!-- Add deliverable sections based on ticket requirements -->

---

<!-- END TICKET BLOCK -->

## Self-Assessment

**Tickets completed:** __/N
**Total time:** __ mins
**Hardest ticket:** TICKET-___
**Most confident:** TICKET-___
**Need to study more:**


---

# Day [N] Responses
**Date:** YYYY-MM-DD
**Started:** [HH:MM]
**Completed:** [HH:MM]

---

<!-- COPY THIS BLOCK FOR EACH TICKET -->

## TICKET-005 | [Title]
**Time spent:** __ mins

### What I did:
used Claude. best for cases like this. no secrets exposed so AI should be allowed. 

### Why I did it this way:
better and faster than  i could write. 

### What I'd check/test:


### Confidence level: __/10

### Deliverables:
1. How to Rotate AWS IAM Access Keys for a Service Account Without Downtime
Purpose

This procedure describes how to rotate AWS IAM access keys for a service account without service interruption, while maintaining security best practices and auditability.

Preconditions

Before starting, verify:

The IAM user has two access keys max (AWS limit)

The application supports key reload (env var refresh, secret reload, or rolling restart)

You have access to:

AWS Console or CLI

Secret store (AWS Secrets Manager, SSM, Vault, Kubernetes Secret, etc.)

Monitoring and alerts are active

High-Level Strategy (Read This First)

AWS allows two active access keys per IAM user.
We create a new key, deploy it alongside the old one, validate usage, then remove the old key.

This overlap guarantees zero downtime.

Step-by-Step Procedure
Step 1: Identify the Active Access Key

Determine which key is currently in use.

aws iam list-access-keys --user-name <service-account>


Record:

Access Key ID

Status (Active)

LastUsedDate (if available)

⚠️ Do not delete anything yet.

Step 2: Create a New Access Key

Create a second key for the same IAM user.

aws iam create-access-key --user-name <service-account>


You will receive:

AccessKeyId

SecretAccessKey

📌 Store securely immediately — this value cannot be retrieved again.

Step 3: Update the Secret Store

Replace credentials without removing the old ones yet.

Examples:

AWS Secrets Manager: update secret value

Kubernetes: update Secret

CI/CD: update encrypted variables

Important:
Do not invalidate the old key yet.

Step 4: Deploy the New Credentials

Roll out the updated secret using a non-disruptive method:

Rolling restart

Hot reload

Gradual deployment

Validate:

Application starts successfully

AWS API calls succeed

No increase in error rates

Step 5: Verify the New Key Is in Use

Confirm traffic has switched.

aws iam get-access-key-last-used \
  --access-key-id <new-access-key-id>


You should see recent activity timestamps.

📌 This is your proof point for audit and rollback safety.

Step 6: Deactivate the Old Access Key

Once the new key is confirmed active:

aws iam update-access-key \
  --user-name <service-account> \
  --access-key-id <old-access-key-id> \
  --status Inactive


Wait and observe for:

Authentication failures

AWS permission errors

⏱ Recommended observation window: 15–60 minutes

Step 7: Delete the Old Access Key

If no issues are observed:

aws iam delete-access-key \
  --user-name <service-account> \
  --access-key-id <old-access-key-id>


Rotation is now complete.

Rollback Procedure

If issues occur before deletion:

Re-activate the old key:

aws iam update-access-key --status Active


Revert secret to previous value

Redeploy application

Rollback is instant as long as the old key exists.

Validation Checklist (Required)

 New key shows recent usage

 Old key shows no usage after cutover

 No elevated error rates

 Logs show successful AWS authentication

 Old key deleted

Security Notes

Rotate keys at least every 90 days

Prefer OIDC / IAM Roles over static keys whenever possible

Never log or expose access keys

Ensure CloudTrail is enabled for auditability

Common Failure Modes (and How to Avoid Them)
Mistake	Impact	Prevention
Deleting old key too early	Immediate outage	Always overlap keys
Single-key IAM users	Forced downtime	Maintain 2-key rotation
Secrets not reloaded	App auth failures	Confirm reload mechanism
Keys copied insecurely	Credential leak	Use secret managers only
Recommended Improvement (Future State)

Eliminate static access keys entirely by migrating to:

IAM Roles (EC2 / ECS / EKS)

GitHub Actions OIDC

STS AssumeRole

This removes the need for key rotation altogether.

Final Note

This process is safe, reversible, and auditable when followed correctly.
Any deviation (especially early deletion) introduces avoidable risk.
<!-- Add deliverable sections based on ticket requirements -->

---

<!-- END TICKET BLOCK -->

## Self-Assessment

**Tickets completed:** __/N
**Total time:** __ mins
**Hardest ticket:** TICKET-___
**Most confident:** TICKET-___
**Need to study more:**
