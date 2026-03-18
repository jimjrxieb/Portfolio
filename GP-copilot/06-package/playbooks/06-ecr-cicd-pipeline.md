# Playbook 06 — ECR CI/CD Pipeline with OIDC Federation

> Replace long-lived AWS credentials in GitHub with OIDC federation. GitHub Actions mints a JWT, AWS STS verifies it, and your workflow gets 15-minute temporary credentials. No secrets to rotate, no credentials to leak.
>
> **When:** After EKS cluster (Playbook 04) and ECR repositories are needed for container workloads.
> **Audience:** Platform engineers setting up CI/CD for client repos.
> **Time:** ~20 min (one-time setup per AWS account + per repo)

---

## The Problem

Long-lived AWS access keys stored as GitHub Secrets:
- Never expire unless manually rotated
- Visible to anyone with repo admin access
- One leaked key = full ECR push access (or worse)
- FedRAMP AC-2 requires automated credential lifecycle management

## The Solution

OIDC federation eliminates stored credentials entirely:

```
GitHub Actions Runner  →  Mints JWT (signed by GitHub)
        ↓
AWS STS                →  Verifies JWT signature against OIDC provider
        ↓
Temporary Credentials  →  15-minute session, auto-expires, scoped to one role
```

---

## Prerequisites

| Prerequisite | How to Verify |
|---|---|
| AWS CLI v2 configured | `aws sts get-caller-identity` |
| GitHub repo with Actions enabled | Repo Settings > Actions > General |
| ECR permissions (or admin) | `aws ecr describe-repositories` |

```bash
export PROJECT="anthra"
export REGION="us-east-1"
export ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
export GITHUB_ORG="jimjrxieb"
export GITHUB_REPO="Anthra-FedRAMP"
```

---

## Step 1: Create ECR Repositories

One repository per service. Immutable tags prevent overwriting images. Scan-on-push catches CVEs at build time.

```bash
# Define services
SERVICES=("anthra-api" "anthra-ui" "anthra-log-ingest")

for SERVICE in "${SERVICES[@]}"; do
  aws ecr create-repository \
    --repository-name ${PROJECT}/${SERVICE} \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability IMMUTABLE \
    --encryption-configuration encryptionType=KMS \
    --region ${REGION} \
    --tags Key=Project,Value=${PROJECT} Key=Service,Value=${SERVICE}
  echo "Created ECR repo: ${PROJECT}/${SERVICE}"
done

# Verify
aws ecr describe-repositories \
  --query 'repositories[*].{Name:repositoryName,ScanOnPush:imageScanningConfiguration.scanOnPush,TagMutability:imageTagMutability}' \
  --region ${REGION} \
  --output table
```

### Lifecycle Policy (prevent unbounded storage costs)

```bash
# Apply lifecycle policy — keep last 30 images, expire untagged after 7 days
LIFECYCLE_POLICY='{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire untagged images after 7 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": { "type": "expire" }
    },
    {
      "rulePriority": 2,
      "description": "Keep only last 30 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 30
      },
      "action": { "type": "expire" }
    }
  ]
}'

for SERVICE in "${SERVICES[@]}"; do
  aws ecr put-lifecycle-policy \
    --repository-name ${PROJECT}/${SERVICE} \
    --lifecycle-policy-text "${LIFECYCLE_POLICY}" \
    --region ${REGION}
  echo "Applied lifecycle policy: ${PROJECT}/${SERVICE}"
done
```

---

## Step 2: Create OIDC Identity Provider

This is a one-time setup per AWS account. It tells AWS to trust JWTs signed by GitHub.

```bash
# Check if provider already exists
EXISTING=$(aws iam list-open-id-connect-providers \
  --query 'OpenIDConnectProviderList[?ends_with(Arn, `token.actions.githubusercontent.com`)]' \
  --output text)

if [ -z "${EXISTING}" ]; then
  # Get GitHub's OIDC thumbprint
  THUMBPRINT=$(echo | openssl s_client -servername token.actions.githubusercontent.com \
    -connect token.actions.githubusercontent.com:443 2>/dev/null | \
    openssl x509 -fingerprint -sha1 -noout | cut -d'=' -f2 | tr -d ':' | tr '[:upper:]' '[:lower:]')

  # Create the provider
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list ${THUMBPRINT} \
    --tags Key=Project,Value=${PROJECT} Key=Purpose,Value=github-actions-oidc

  echo "OIDC provider created"
else
  echo "OIDC provider already exists: ${EXISTING}"
fi

# Verify
aws iam list-open-id-connect-providers \
  --query 'OpenIDConnectProviderList[*].Arn' --output table
```

---

## Step 3: Create IAM Role with Trust Policy

The trust policy scopes access to a specific GitHub org/repo. Never use wildcards.

```bash
# Create trust policy — scoped to specific repo
cat > /tmp/gha-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name ${PROJECT}-gha-ecr-push \
  --assume-role-policy-document file:///tmp/gha-trust-policy.json \
  --max-session-duration 3600 \
  --tags Key=Project,Value=${PROJECT} Key=Purpose,Value=github-actions-ecr

export GHA_ROLE_ARN=$(aws iam get-role --role-name ${PROJECT}-gha-ecr-push \
  --query 'Role.Arn' --output text)
echo "Role ARN: ${GHA_ROLE_ARN}"
```

> **Security note:** The `sub` condition uses `repo:${GITHUB_ORG}/${GITHUB_REPO}:*` which allows any branch/event from that repo. For tighter control, scope to a specific branch: `repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main`.

---

## Step 4: Attach ECR Permissions

Minimal policy — only what's needed to authenticate and push images.

```bash
cat > /tmp/ecr-push-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAuth",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "ECRPush",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImages",
        "ecr:DescribeImageScanFindings"
      ],
      "Resource": "arn:aws:ecr:${REGION}:${ACCOUNT_ID}:repository/${PROJECT}/*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name ${PROJECT}-gha-ecr-push \
  --policy-name ecr-push-access \
  --policy-document file:///tmp/ecr-push-policy.json

echo "ECR push policy attached"
```

---

## Step 5: Configure GitHub Repository

Add the role ARN as a GitHub Actions secret.

```bash
# Using gh CLI
gh secret set AWS_ROLE_ARN \
  --repo ${GITHUB_ORG}/${GITHUB_REPO} \
  --body "${GHA_ROLE_ARN}"

gh secret set AWS_REGION \
  --repo ${GITHUB_ORG}/${GITHUB_REPO} \
  --body "${REGION}"

gh secret set ECR_REGISTRY \
  --repo ${GITHUB_ORG}/${GITHUB_REPO} \
  --body "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "GitHub secrets configured"

# Verify (shows secret names, not values)
gh secret list --repo ${GITHUB_ORG}/${GITHUB_REPO}
```

---

## Step 6: GitHub Actions Workflow Template

Create this workflow in the client repo at `.github/workflows/build-push-ecr.yml`:

```yaml
name: Build and Push to ECR

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  id-token: write   # Required for OIDC
  contents: read     # Required for checkout

env:
  SERVICE_NAME: anthra-api   # Change per service

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ secrets.AWS_REGION }}
          role-session-name: gha-ecr-${{ github.run_id }}

      - name: Login to Amazon ECR
        id: ecr-login
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, Tag, and Push
        env:
          ECR_REGISTRY: ${{ steps.ecr-login.outputs.registry }}
          IMAGE_TAG_SHA: ${{ github.sha }}
          IMAGE_TAG_REF: ${{ github.ref_name }}
        run: |
          # Build the image
          docker build -t ${ECR_REGISTRY}/${SERVICE_NAME}:${IMAGE_TAG_SHA} .
          docker tag ${ECR_REGISTRY}/${SERVICE_NAME}:${IMAGE_TAG_SHA} \
            ${ECR_REGISTRY}/${SERVICE_NAME}:${IMAGE_TAG_REF}

          # Push both tags
          docker push ${ECR_REGISTRY}/${SERVICE_NAME}:${IMAGE_TAG_SHA}
          docker push ${ECR_REGISTRY}/${SERVICE_NAME}:${IMAGE_TAG_REF}

          echo "image=${ECR_REGISTRY}/${SERVICE_NAME}:${IMAGE_TAG_SHA}" >> $GITHUB_OUTPUT

      - name: Scan Image with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ steps.ecr-login.outputs.registry }}/${{ env.SERVICE_NAME }}:${{ github.sha }}
          format: table
          exit-code: 1
          severity: CRITICAL,HIGH
          ignore-unfixed: true

      - name: Check ECR Scan Findings
        if: github.ref == 'refs/heads/main'
        run: |
          echo "Waiting for ECR scan results..."
          sleep 15
          FINDINGS=$(aws ecr describe-image-scan-findings \
            --repository-name ${SERVICE_NAME} \
            --image-id imageTag=${{ github.sha }} \
            --query 'imageScanFindings.findingSeverityCounts' \
            --output json 2>/dev/null || echo '{}')
          echo "ECR Scan Findings: ${FINDINGS}"

          CRITICAL=$(echo ${FINDINGS} | python3 -c "import sys,json; print(json.load(sys.stdin).get('CRITICAL', 0))" 2>/dev/null || echo 0)
          if [ "${CRITICAL}" -gt 0 ]; then
            echo "::error::ECR scan found ${CRITICAL} CRITICAL vulnerabilities"
            exit 1
          fi
```

### Key Points

| Config | Value | Why |
|---|---|---|
| `permissions.id-token: write` | Required | Allows the runner to mint OIDC JWTs |
| `role-session-name` | Includes `run_id` | Unique per run for CloudTrail auditing |
| Image tag: git SHA | `${{ github.sha }}` | Immutable, traceable to exact commit |
| Image tag: branch name | `${{ github.ref_name }}` | Human-readable for latest on branch |
| Trivy `exit-code: 1` | Fail on CRITICAL/HIGH | Blocks vulnerable images from deploying |

---

## Verification

Run through this checklist after setup:

```bash
# 1. OIDC provider exists
aws iam list-open-id-connect-providers | grep token.actions.githubusercontent.com

# 2. Role exists with correct trust policy
aws iam get-role --role-name ${PROJECT}-gha-ecr-push \
  --query 'Role.AssumeRolePolicyDocument' --output json

# 3. ECR repos exist with scan-on-push
aws ecr describe-repositories \
  --query 'repositories[?starts_with(repositoryName, `'${PROJECT}'`)].{Name:repositoryName,Scan:imageScanningConfiguration.scanOnPush,Tags:imageTagMutability}' \
  --region ${REGION} --output table

# 4. GitHub secrets are set
gh secret list --repo ${GITHUB_ORG}/${GITHUB_REPO}

# 5. Trigger a test build
gh workflow run build-push-ecr.yml --repo ${GITHUB_ORG}/${GITHUB_REPO} --ref main

# 6. Watch the run
gh run watch --repo ${GITHUB_ORG}/${GITHUB_REPO}
```

---

## Adding New Services

When the client adds a new microservice:

```bash
NEW_SERVICE="anthra-webhook"

# 1. Create the ECR repo
aws ecr create-repository \
  --repository-name ${PROJECT}/${NEW_SERVICE} \
  --image-scanning-configuration scanOnPush=true \
  --image-tag-mutability IMMUTABLE \
  --encryption-configuration encryptionType=KMS \
  --region ${REGION}

# 2. Apply lifecycle policy
aws ecr put-lifecycle-policy \
  --repository-name ${PROJECT}/${NEW_SERVICE} \
  --lifecycle-policy-text "${LIFECYCLE_POLICY}" \
  --region ${REGION}

# 3. No IAM changes needed — the role policy uses wildcard on project prefix:
#    arn:aws:ecr:REGION:ACCOUNT:repository/${PROJECT}/*
```

No role policy update needed because Step 4's resource scope covers `${PROJECT}/*`.

---

## Lifecycle

| Task | Frequency | Who |
|---|---|---|
| Initial OIDC + role setup | Once per AWS account | Platform engineer |
| New ECR repo | Per new service | Platform engineer |
| Workflow template updates | As needed | Dev team |
| Role trust policy audit | Quarterly | Security team |
| ECR lifecycle policy review | Quarterly | Platform engineer |
| Rotate OIDC thumbprint | Only if GitHub rotates their cert | Platform engineer |

---

## Expected Outcomes

| Item | Expected State |
|---|---|
| OIDC provider | Created for `token.actions.githubusercontent.com` |
| IAM role | Trust policy scoped to specific repo, ECR push only |
| ECR repositories | Created with scan-on-push, immutable tags, KMS encryption |
| GitHub secrets | `AWS_ROLE_ARN`, `AWS_REGION`, `ECR_REGISTRY` set |
| First build | Image pushed, Trivy scan passed, ECR scan clean |
| No stored credentials | No `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` anywhere |

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| "Not authorized to perform sts:AssumeRoleWithWebIdentity" | Trust policy `sub` condition doesn't match the repo/branch | Check: `aws iam get-role --role-name ${PROJECT}-gha-ecr-push --query 'Role.AssumeRolePolicyDocument'` — verify org/repo matches exactly |
| "No identity-based policy allows the ecr:GetAuthorizationToken action" | Role policy missing or not attached | Check: `aws iam list-role-policies --role-name ${PROJECT}-gha-ecr-push` — re-run Step 4 |
| ECR login fails with "error getting credentials" | Wrong region in `aws-region` input | Verify `AWS_REGION` secret matches the region where ECR repos were created |
| Image push fails with "repository does not exist" | Repo name mismatch (case-sensitive) or repo not created | Verify: `aws ecr describe-repositories --repository-names ${PROJECT}/${SERVICE_NAME}` |
| Trivy scan fails but ECR scan passes | Different vulnerability databases, Trivy is more current | Trivy is the gate — fix the findings Trivy reports |
| "Error: id-token permission is needed" | Missing `permissions.id-token: write` in workflow | Add the permissions block at job or workflow level |

---

*Ghost Protocol — Cloud Security Package*
