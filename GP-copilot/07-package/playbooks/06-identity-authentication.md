# Playbook 06: Identification & Authentication
### Controls: IA-2, IA-5

---

## WHAT THIS COVERS

| Control | Name | What the assessor checks |
|---------|------|------------------------|
| IA-2 | Identification and Authentication (Users) | Users are uniquely identified and authenticated before access |
| IA-5 | Authenticator Management | Passwords/tokens/keys are managed securely throughout lifecycle |

---

## IA-2: USER IDENTIFICATION AND AUTHENTICATION

### What "compliant" looks like
- Every user has a unique identity (no shared accounts)
- Multi-factor authentication for all privileged access
- Authentication is centralized (SSO/OIDC)
- Service-to-service authentication uses unique credentials

### Step 1: Audit current authentication

```bash
# AWS: Check MFA status for all users
aws iam generate-credential-report > /dev/null 2>&1 && sleep 5
aws iam get-credential-report --query 'Content' --output text | base64 -d | \
  awk -F',' 'NR>1 {print $1, "MFA:" ($8=="true" ? "YES" : "NO"), "Console:" ($4=="true" ? "YES" : "NO")}'

# K8s: Check authentication method
kubectl config view --minify -o jsonpath='{.users[0].user}' | jq .
# Should show OIDC or exec-based auth, NOT static tokens or certs

# K8s: List all ServiceAccounts (each should be purpose-specific)
kubectl get sa -A -o custom-columns=\
"NAMESPACE:.metadata.namespace,NAME:.metadata.name,AUTOMOUNT:.automountServiceAccountToken"
```

### Step 2: Enable MFA for all IAM users

```bash
# Create MFA policy — deny all actions without MFA
cat > mfa-required-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyAllExceptMFASetup",
      "Effect": "Deny",
      "NotAction": [
        "iam:CreateVirtualMFADevice",
        "iam:EnableMFADevice",
        "iam:GetUser",
        "iam:ListMFADevices",
        "iam:ListVirtualMFADevices",
        "iam:ResyncMFADevice",
        "sts:GetSessionToken"
      ],
      "Resource": "*",
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        }
      }
    }
  ]
}
EOF

# Attach to all human users (not service accounts)
aws iam put-user-policy \
  --user-name <username> \
  --policy-name RequireMFA \
  --policy-document file://mfa-required-policy.json
```

### Step 3: Configure OIDC for kubectl access

```bash
# EKS: Associate OIDC provider
eksctl utils associate-iam-oidc-provider --cluster <cluster> --approve

# Configure kubectl to use OIDC (via kubelogin)
kubectl config set-credentials oidc-user \
  --exec-api-version=client.authentication.k8s.io/v1beta1 \
  --exec-command=kubectl \
  --exec-arg=oidc-login \
  --exec-arg=get-token \
  --exec-arg=--oidc-issuer-url=https://login.company.com \
  --exec-arg=--oidc-client-id=<client-id>
```

### Step 4: Unique ServiceAccounts per application

```yaml
# Every application gets its own SA — never use "default"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: payments-api-sa
  namespace: payments
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/payments-api-role
automountServiceAccountToken: false
---
# Reference in deployment
spec:
  serviceAccountName: payments-api-sa
  automountServiceAccountToken: false  # only mount if app needs K8s API access
```

---

## IA-5: AUTHENTICATOR MANAGEMENT (SECRETS)

### What "compliant" looks like
- No hardcoded secrets in code, config, or environment variables
- Secrets stored in a dedicated secret store (AWS Secrets Manager, Vault)
- Secrets are rotated regularly
- Secret access is logged and auditable
- Minimum complexity requirements for passwords

### Step 1: Find all hardcoded secrets

```bash
# Run Gitleaks against the entire repo history
gitleaks detect --source . --report-format json --report-path gitleaks-full.json

# Check for secrets in K8s manifests
grep -rn "password\|secret\|api_key\|token" k8s/ --include="*.yaml" --include="*.yml"

# Check for secrets in environment variables (in deployment specs)
kubectl get deployments -A -o json | \
  jq -r '.items[] | .spec.template.spec.containers[]? |
    select(.env[]?.value != null and (.env[]?.name | test("SECRET|PASSWORD|TOKEN|KEY"; "i"))) |
    "HARDCODED SECRET: " + .name'

# Check for K8s Secrets that look like they were manually created
kubectl get secrets -A -o json | \
  jq -r '.items[] | select(.metadata.annotations["external-secrets.io/managed"] == null) |
    select(.type != "kubernetes.io/service-account-token") |
    .metadata.namespace + "/" + .metadata.name + " (type: " + .type + ")"'
```

### Step 2: Migrate secrets to AWS Secrets Manager

```bash
# For each hardcoded secret found:

# 1. Create in AWS Secrets Manager
aws secretsmanager create-secret \
  --name "platform/<namespace>/<app-name>/database" \
  --description "Database credentials for payments-api" \
  --secret-string '{"username":"app_user","password":"<generated>","host":"db.internal","port":"5432"}' \
  --kms-key-id <kms-key-id>

# 2. Create ExternalSecret in K8s
cat << EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: payments-db-creds
  namespace: payments
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: payments-db-creds
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: platform/payments/payments-api/database
        property: username
    - secretKey: password
      remoteRef:
        key: platform/payments/payments-api/database
        property: password
    - secretKey: host
      remoteRef:
        key: platform/payments/payments-api/database
        property: host
EOF

# 3. Update deployment to reference the K8s Secret
# env:
#   - name: DB_USERNAME
#     valueFrom:
#       secretKeyRef:
#         name: payments-db-creds
#         key: username

# 4. Remove the hardcoded value from code/config
# 5. Rotate the exposed secret (it was in Git — assume compromised)
```

### Step 3: Enable secret rotation

```bash
# AWS Secrets Manager automatic rotation
aws secretsmanager rotate-secret \
  --secret-id platform/payments/payments-api/database \
  --rotation-lambda-arn <rotation-lambda-arn> \
  --rotation-rules AutomaticallyAfterDays=90

# For API keys — use Lambda rotation function
# Template: https://github.com/aws-samples/aws-secrets-manager-rotation-lambdas
```

### Step 4: Audit secret access

```bash
# CloudTrail logs all Secrets Manager access
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=secretsmanager.amazonaws.com \
  --max-results 20 \
  --query 'Events[*].[EventTime,EventName,Username]' --output table

# K8s audit logs show Secret access
# Query CloudWatch for K8s audit events on secrets:
aws logs filter-log-events \
  --log-group-name /aws/eks/<cluster>/cluster \
  --filter-pattern '{ $.objectRef.resource = "secrets" }' \
  --start-time $(date -d '24 hours ago' +%s000) \
  --query 'events[*].message' --output text | jq -r '.verb + " " + .objectRef.namespace + "/" + .objectRef.name + " by " + .user.username'
```

### Step 5: Add Gitleaks to CI and pre-commit

```yaml
# .github/workflows/ci.yml
- name: Secret scan
  run: |
    gitleaks detect --source . --exit-code 1 --report-format json --report-path gitleaks.json
    # Fails the build if any secrets are found

# Pre-commit hook (catches before it hits the repo)
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
```

### Password/token complexity requirements

Document these for the assessor:

```markdown
## Authenticator Policy

### User passwords (via SSO/OIDC provider)
- Minimum 14 characters
- Complexity: upper, lower, number, special character
- No password reuse (last 24 passwords)
- Maximum age: 90 days
- Lockout: 5 failed attempts → 30 min lockout
- MFA required for all users

### Service account tokens
- Minimum 32 characters, cryptographically random
- Generated via AWS Secrets Manager (not manually)
- Rotated every 90 days (automated)
- Never stored in code or config files

### API keys
- Minimum 256-bit entropy
- Scoped to specific operations (least privilege)
- Rotated every 90 days
- Revoked immediately upon compromise
```

---

## EVIDENCE FOR THE ASSESSOR

| Evidence | Source | Control |
|----------|--------|---------|
| IAM credential report (MFA status) | `aws iam get-credential-report` | IA-2 |
| OIDC configuration for kubectl | kubeconfig showing exec-based auth | IA-2 |
| ServiceAccount inventory (no shared accounts) | `kubectl get sa -A` | IA-2 |
| MFA enforcement policy | IAM policy JSON | IA-2 |
| Gitleaks scan (clean) | CI pipeline artifact | IA-5 |
| ExternalSecret resources | `kubectl get externalsecret -A` | IA-5 |
| Secret rotation config | AWS SM rotation settings | IA-5 |
| Secret access audit logs | CloudTrail query output | IA-5 |
| Pre-commit hook config | `.pre-commit-config.yaml` | IA-5 |
| Password/token complexity policy | Policy document | IA-5 |

---

## COMPLETION CHECKLIST

```
[ ] IA-2:  Every user has unique identity (no shared accounts)
[ ] IA-2:  MFA enabled for all IAM users with console access
[ ] IA-2:  MFA enforcement policy attached to all human users
[ ] IA-2:  kubectl access via OIDC/SSO (not static tokens)
[ ] IA-2:  Unique ServiceAccount per application
[ ] IA-2:  Default SA has automountServiceAccountToken: false
[ ] IA-5:  Gitleaks scan clean (no hardcoded secrets in repo)
[ ] IA-5:  All secrets in AWS Secrets Manager (or Vault)
[ ] IA-5:  ExternalSecrets syncing secrets to K8s
[ ] IA-5:  Secret rotation enabled (90-day cycle)
[ ] IA-5:  Secret access logged via CloudTrail
[ ] IA-5:  Gitleaks in CI pipeline (blocks on findings)
[ ] IA-5:  Gitleaks pre-commit hook configured
[ ] IA-5:  Password/token complexity policy documented
[ ] IA-5:  Compromised secrets rotated immediately
```
