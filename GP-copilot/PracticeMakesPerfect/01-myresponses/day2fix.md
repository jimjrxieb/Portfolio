# Day [2] Responses on /home/jimmie/linkops-industries/GP-copilot/GP-PROJECTS/02-instance/slot-3/Portfolio/GP-copilot/PracticeMakesPerfect/00-dailytask/day2.md
**Date:** 2026-01-09
**Started:** [0850]
**Completed:** [HH:MM]

---

## TICKET-006 | [K8S + AWS]
**Time spent:** __ mins

### Ticket Deliverables:
1. based on the error code provided, the USER that ran terraform apply didnt have the correct permissions. 
2. add user temporarily to security group that has correct permissions and re-apply
3. After USER re-applies terraform and pod is no longer getting the error code 
4. i believe what couldve prevented this was to have better iam roles on who can run terraform apply to prod. 

### My use of JSA to fix(if allowed):
I would have jsa-infrasec run a aws cli command to add user temporarily to privilaged security group. I would have Jade inspect secuirty groups and see if we need to create a new group that is allowed to push to prod. 

### Why I did it this way:
From reading the logs, i can see what the problem is. the "not authorized" tells me its RBAC and IAM issues. Also the fact that it was working before and after a user ran terraform apply it broke. only confirms its not code or configuration denial but authorization. 

### How I would validate:
error: the logs 
fix: after have that user or someone with authorization reapply, with the new security group of pushing to prod i would test with a none authorized dummy account to see if i was correctly denied access

### Confidence level: _8_/10

---

## TICKET-007 | [OPA/GATEKEEPER]
**Time spent:** __ mins

### Ticket Deliverables:
1. apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: portfolioimagesecurity
  annotations:
    metadata.gatekeeper.sh/title: "Portfolio Image Security Policy"
    metadata.gatekeeper.sh/version: 1.0.0
    description: "Enforces container image security policies for Portfolio platform"
spec:
  crd:
    spec:
      names:
        kind: PortfolioImageSecurity
      validation:
        openAPIV3Schema:
          type: object
          properties:
            allowedRegistries:
              description: "List of allowed container registries"
              type: array
              items:
                type: string
            
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package portfolioimagesecurity

        # Require trusted registries
        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          image := container.image
          not starts_with_allowed_registry(image)
          msg := sprintf("Container '%s' uses untrusted registry. Allowed: ghcr.io/our-org/, 123456789.dkr.ecr.us-east-1.amazonaws.com/*", [container.name])
        }

        starts_with_allowed_registry(image) {
            some registry
            registry := input.parameters.allowedRegistries[_]
            startswith(image, registry)
        }
2. apiVersion: constraints.gatekeeper.sh/v1beta1
kind: PortfolioImageSecurity
metadata:
  name: portfolio-image-security
  namespace: portfolio
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
    namespaces: ["production"]
  parameters:
    allowedRegistries:
      - "ghcr.io/our-org/"
      - "123456789.dkr.ecr.us-east-1.amazonaws.com/"

    blockedTags:
      - "latest"
    requireDigests: false
3. PASSING POD 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jade-api
  namespace: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jade-api
  template:
    metadata:
      labels:
        app: jade-api
    spec:
      containers:
        - name: jade-api
          image: ghcr.io/our-org/jade-api:v1.2.0
          ports:
            - containerPort: 8000
4. FAILING POD
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jade-api
  namespace: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jade-api
  template:
    metadata:
      labels:
        app: jade-api
    spec:
      containers:
        - name: jade-api
          image: docker.io/library/python:3.11-slim
          ports:
            - containerPort: 8000
5. I would test it by trying to create the failed pod.

### My use of JSA to fix(if allowed):
I would ask Jade to create these contraints, contraint template and test pod. I would also update the Conftest test so we can catch this early in the CICD pipeline

### Why I did it this way:
I used a template of image security , plugged in with correct information. Using Jade is always faster , but the template we easy enough to copy , paste and modify .

### How I would validate:
tried to run a pod with incorrect image

### Confidence level: _8_/10


---


## TICKET-008 | [TERRAFORM, CHECKOV, TRIVY]
**Time spent:** __ mins

### Ticket Deliverables:
1. resource "aws_ecr_repository" "app" {
  name                 = "our-app"
  image_tag_mutability = "IMMUTABLE" # prevents tag overwriting

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn  # or use "AES256" for AWS-managed
  }
}

resource "aws_kms_key" "ecr" {
  description             = "KMS key for ECR encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}
2. - CKV_AWS_19 — Ensures images at rest aren't stored in plaintext; ECR must have encryption enabled (AES256 or KMS).
   - CKV_AWS_163 — Ensures every pushed image gets scanned for CVEs automatically, catching vulnerabilities before deployment.
   - CKV_AWS_136 — Requires KMS specifically (not just AES256) so you have audit trails and key management control.

3. Depending on the size of the company. KMS is for multi-account architecture, its free, automatic key rotation(annually) but with customer managed its 1 dollar per key a month but they have full control of deletion and rotation and get a full granularity cloudtrail audit

### My use of JSA to fix(if allowed):
i would use jade to create and to tell jsa-infrasec to implement. no secrets exposed and its an add on like i would use chatgpt or stackoverflow 

### Why I did it this way:
faster and better 

### How I would validate:
i would rerun the scan or if jade did the changes and automatic verify rescan is already in place 

### Confidence level: _8_/10


---


## TICKET-009 | [DOCKER]
**Time spent:** __ mins

### Ticket Deliverables:
1. ISSUE | RISK | CHECKOV/TRIVY FLAG 
- Full python:3.11 base image | ~900MB, includes gcc, curl, wget — huge attack surface | CKV_DOCKER_2
- Running as root | Container compromise = root access | CKV_DOCKER_3
- No pinned image digest | Supply chain attack via tag mutation | CKV_DOCKER_7
- COPY . . copies everything | Leaks .git, .env, secrets, pycache | Manual review
- pip cache left in image | Increases image size, potential info leak | Trivy
- No HEALTHCHECK | Can't detect hung processes, affects availability | CKV_DOCKER_2
- Unpinned pip dependencies | Dependency confusion, malicious package injection | Trivy supply chain
- Single-stage build | Build tools remain in production image | Best practice

2.  =============================================================================
# STAGE 1: Build dependencies in isolated environment
# =============================================================================
FROM python:3.11-slim@sha256:xxx AS builder

# Pinned digest prevents supply chain attacks via tag mutation
# Get current digest: docker pull python:3.11-slim && docker inspect --format='{{index .RepoDigests 0}}' python:3.11-slim

WORKDIR /app

# Install build dependencies (won't exist in final image)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy ONLY requirements first (layer caching optimization)
COPY requirements.txt .

# Install dependencies to a specific directory we can copy later
# --no-cache-dir: don't store pip cache (smaller image, less attack surface)
# --prefix: install to custom location for clean copy to final stage
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# =============================================================================
# STAGE 2: Minimal production image
# =============================================================================
FROM python:3.11-slim@sha256:xxx AS production

# Metadata for container inspection
LABEL maintainer="jimmie@linkops.dev" \
      version="1.0.0" \
      description="Jade API - LinksOps Portfolio"

# Create non-root user BEFORE copying files
# -r: system user, -s /bin/false: no shell access
RUN groupadd --gid 1000 appgroup && \
    useradd --uid 1000 --gid appgroup --shell /bin/false --create-home appuser

WORKDIR /app

# Copy installed dependencies from builder stage
COPY --from=builder /install /usr/local

# Copy application code with explicit ownership (not root)
# List specific files/dirs instead of COPY . . to prevent secret leakage
COPY --chown=appuser:appgroup app.py .
COPY --chown=appuser:appgroup src/ ./src/

# Switch to non-root user
USER appuser

# Expose port (documentation only, doesn't publish)
EXPOSE 8080

# Healthcheck for orchestrator awareness
# Adjust endpoint to your actual health route
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

# Use exec form (not shell form) - proper signal handling
CMD ["python", "-u", "app.py"]


3. Base Image Recommendation:**

For your portfolio, use **`python:3.11-slim`** with multi-stage builds. Here's the comparison:

| Image | Size | Security | Debugging | Portfolio Fit |
|-------|------|----------|-----------|---------------|
| python:3.11 | ~900MB | Poor (gcc, curl, shell tools) | Easy | No |
| python:3.11-slim | ~150MB | Good (minimal packages) | Reasonable | **Yes** |
| python:3.11-alpine | ~50MB | Good but musl libc issues | Harder | Maybe |
| gcr.io/distroless/python3 | ~50MB | Excellent (no shell) | Very hard | Overkill |

**Why slim over distroless for you:**

1. Distroless has no shell — you can't `kubectl exec` to debug, which matters when you're learning
2. Some Python packages with C extensions break on Alpine (musl vs glibc)
3. Slim + non-root + multi-stage passes all Checkov/Trivy checks anyway
4. In interviews, you can explain *why* you chose slim over distroless — shows you understand tradeoffs, not just cargo-culting "most secure"

---

### My use of JSA to fix(if allowed):


### Why I did it this way:
Not good at archicture yet so I used Claude for suggestions

### How I would validate:
To get the actual SHA256 digest for pinning:
bashdocker pull python:3.11-slim
docker inspect --format='{{index .RepoDigests 0}}' python:3.11-slim
Then replace @sha256:xxx with the real value. 

### Confidence level: _3_/10

---

## TICKET-010 | [CI/CD + MLOPS ]
**Time spent:** __ mins

### Ticket Deliverables:
1. no branch, different python versions, model bucket env exposed, paths has 2 '*'
2. ```name: Deploy Model

on:
  push:
    branches: [main]  # Only main, not all branches
    paths: ['models/**']
  # Allow manual trigger for rollbacks
  workflow_dispatch:
    inputs:
      model_version:
        description: 'Model version to deploy'
        required: true

# OIDC requires these permissions
permissions:
  id-token: write   # Required for OIDC token request
  contents: read    # Required for checkout

jobs:
  validate:
    name: Validate Model
    runs-on: ubuntu-22.04  # Pinned, not 'latest'
    steps:
      - name: Checkout
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1 - pinned to SHA

      - name: Setup Python
        uses: actions/setup-python@0a5c61591373683505ea898e09a3ea4f39ef2b9c  # v5.0.0
        with:
          python-version: '3.11'
          cache: 'pip'

      - name: Install dependencies
        run: pip install -r requirements-ml.txt  # Pinned versions in lockfile

      - name: Validate model artifact
        run: |
          python scripts/validate_model.py models/
          # Checks: file integrity, expected format, no pickle exploits

      - name: Scan for secrets
        uses: trufflesecurity/trufflehog@8a8ef8526527c1a8fb584be55c2e705bbc150431  # v3.63.5
        with:
          path: ./models/

  deploy:
    name: Deploy to SageMaker
    needs: validate  # Only runs if validation passes
    runs-on: ubuntu-22.04
    environment: production  # Requires approval in GitHub settings
    
    steps:
      - name: Checkout
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11

      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502  # v4.0.2
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-actions-ml-deploy
          role-session-name: github-actions-${{ github.run_id }}
          aws-region: us-east-1

      - name: Setup Python
        uses: actions/setup-python@0a5c61591373683505ea898e09a3ea4f39ef2b9c
        with:
          python-version: '3.11'
          cache: 'pip'

      - name: Install dependencies
        run: pip install -r requirements-ml.txt

      - name: Deploy to SageMaker
        run: python deploy_model.py
        env:
          MODEL_BUCKET: ${{ vars.MODEL_BUCKET }}  # Use GitHub Variables, not hardcoded
          MODEL_VERSION: ${{ github.event.inputs.model_version || github.sha }}

      - name: Notify on failure
        if: failure()
        run: |
          # Send to Slack/PagerDuty
          echo "Deployment failed for ${{ github.sha }}"
> ```

2. # OIDC Provider (create once per AWS account)
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]  # pragma: allowlist secret (GitHub OIDC thumbprint)
}

# Role for ML deployments
resource "aws_iam_role" "github_actions_ml" {
  name = "github-actions-ml-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # CRITICAL: Lock to specific repo and branch
          "token.actions.githubusercontent.com:sub" = "repo:your-org/your-repo:ref:refs/heads/main"
        }
      }
    }]
  })
}

# Attach minimal permissions for SageMaker deployment
resource "aws_iam_role_policy" "sagemaker_deploy" {
  name = "sagemaker-deploy"
  role = aws_iam_role.github_actions_ml.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreateModel",
          "sagemaker:CreateEndpointConfig", 
          "sagemaker:CreateEndpoint",
          "sagemaker:UpdateEndpoint",
          "sagemaker:DescribeEndpoint"
        ]
        Resource = "arn:aws:sagemaker:us-east-1:123456789012:*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = "arn:aws:s3:::ml-models-prod/*"
      }
    ]
  })
}

3. CONTROL | WHY IT MATTERS | IMPLEMENTATION
- model signing | Prove model hasn't been tampered with | Sign with Sigstore/cosign, verify before deploy
- Canary deployments | Catch bad models before full rollout | SageMaker traffic splitting, 10% → 50% → 100%
- Model card / metadata | Audit trail for compliance | Require model card JSON with training data provenance
- Rollback automation | Fast recovery from bad deployments | Keep previous 3 endpoint configs, one-click rollback
- Inference monitoring | Detect model drift or adversarial inputs | CloudWatch + SageMaker Model Monitor
- Pickle scanning | Pickle files can contain arbitrary code execution | Use fickling or picklescan in validation step
### My use of JSA to fix(if allowed):
if Jade knew how to do this then yes or have her make a tmp santized version so i can ask Claude or haiku to finish. have jsa-devec monitor gha logs

### Why I did it this way:
faster and better 

### How I would validate:
run pipeline and insert add this step before the actual deploy
- name: Verify AWS identity
  run: |
    aws sts get-caller-identity
    # Should show the assumed role, not an IAM user
    # Expected output:
    # {
    #   "UserId": "AROA...:github-actions-12345",
    #   "Account": "123456789012",
    #   "Arn": "arn:aws:sts::123456789012:assumed-role/github-actions-ml-deploy/github-actions-12345"
    # }

### Confidence level: _3_/10

---

## TICKET-011 | [SECRETS MANAGEMENT]
**Time spent:** __ mins

### Ticket Deliverables:
1. rotate old secrets and create new secrets, remove visible secrets from repo, clear git history of exposed keys. 
2. 
# 1. Create the secret (don't commit this file)
apiVersion: v1
kind: Secret
metadata:
  name: api-server-secrets
  namespace: production
type: Opaque
stringData:  # Use stringData, not data - avoids base64 manually
  db-password: "NEW_ROTATED_PASSWORD"  # pragma: allowlist secret (placeholder)
  jwt-secret: "NEW_ROTATED_JWT_SECRET"  # pragma: allowlist secret (placeholder)
---
# 2. Create separate secret for AWS (or better, use IRSA - see below)
apiVersion: v1
kind: Secret
metadata:
  name: aws-credentials
  namespace: production
type: Opaque
stringData:
  aws-access-key-id: "NEW_ROTATED_KEY"
  aws-secret-access-key: "NEW_ROTATED_SECRET"
---
# 3. Updated Pod spec
apiVersion: v1
kind: Pod
metadata:
  name: api-server
  namespace: production
spec:
  containers:
  - name: app
    image: healthvault/api:v1.2.3  # Pin version, not latest
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: api-server-secrets
          key: db-password
    - name: JWT_SECRET
      valueFrom:
        secretKeyRef:
          name: api-server-secrets
          key: jwt-secret
    - name: AWS_ACCESS_KEY_ID
      valueFrom:
        secretKeyRef:
          name: aws-credentials
          key: aws-access-key-id
    - name: AWS_SECRET_ACCESS_KEY
      valueFrom:
        secretKeyRef:
          name: aws-credentials
          key: aws-secret-access-key
3. # Install ESO first:
# helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace

# 1. Tell ESO how to authenticate to AWS Secrets Manager
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets
---
# 2. Define what secrets to sync
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: api-server-secrets
  namespace: production
spec:
  refreshInterval: 1h  # Auto-rotate from source
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: api-server-secrets  # K8s secret name created by ESO
  data:
  - secretKey: db-password
    remoteRef:
      key: production/api-server  # AWS Secrets Manager path
      property: db_password
  - secretKey: jwt-secret
    remoteRef:
      key: production/api-server
      property: jwt_secret
---
# 3. Pod references the synced secret (same as before)
apiVersion: v1
kind: Pod
metadata:
  name: api-server
  namespace: production
spec:
  serviceAccountName: api-server
  containers:
  - name: app
    image: healthvault/api:v1.2.3
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: api-server-secrets
          key: db-password
    - name: JWT_SECRET
      valueFrom:
        secretKeyRef:
          name: jwt-secret
          key: jwt-secret

4. most likely B rank. exposed secrets are terrible but fix for it is pretty common. this wouldve been escalated to me with old secrets deleted and git history scrubbed. already 
### My use of JSA to fix(if allowed):
since its dealing with secrets we move on to creating contraints and conftest 

### Why I did it this way:
best practice 

### How I would validate:
inpect git logs, inspect secrets, try to use old key again

### Confidence level: _6_/10

---


## TICKET-012 | [TERRAFORM]
**Time spent:** __ mins

### Ticket Deliverables:
1. no state locking and no version/audit trail
2. terraform {
  backend "s3" {
    bucket         = "tacticalnet-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    
    # State locking
    dynamodb_table = "terraform-state-lock"
    
    # Encryption at rest
    encrypt        = true
  }
}
3. Our infrastructure configuration system maintains a file that tracks what resources exist in our environment. The current setup has two control gaps: First, there's no mechanism to prevent two team members from making changes simultaneously, which could result in conflicting modifications and configuration errors — similar to two people editing the same spreadsheet without any checkout system. Second, we have no change history or audit trail, meaning we cannot determine who made changes, when they occurred, or what the previous configuration looked like. The fix involves adding a locking mechanism (think of it as a "checked out for editing" flag) and enabling version history on the storage system, which gives us both collision prevention and a complete audit trail of all changes with timestamps.
### My use of JSA to fix(if allowed):
jsa-infrasec and jade would take care of this

### Why I did it this way:


### How I would validate:
run another security review

### Confidence level: __/10

---
---

## TICKET-013 | [Title]
**Time spent:** __ mins

### Ticket Deliverables:
working on that now

### My use of JSA to fix(if allowed):


### Why I did it this way:


### How I would validate:


### Confidence level: __/10

---



## Self-Assessment

**Tickets completed:** __/N
**Total time:** __ mins
**Hardest ticket:** TICKET-___
**Most confident:** TICKET-___
**Need to study more:**
