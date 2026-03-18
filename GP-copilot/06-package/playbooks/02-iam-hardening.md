# Playbook 02 — IAM Hardening

> Audit and harden AWS IAM: root account lockdown, MFA enforcement, stale credential cleanup, policy audit, IRSA for EKS, and permission boundaries. IAM is the front door. If it's wide open, nothing else matters.
>
> **When:** After VPC is deployed (Playbook 01). IAM controls who can touch what you just built.
> **Audience:** Platform engineers, security consultants, cloud architects.
> **Time:** ~30 min (audit + remediation)

---

## Prerequisites

- AWS CLI configured with IAM admin access
- Root account credentials available (for MFA setup only)
- EKS cluster deployed (for IRSA steps — skip if no EKS yet)
- Completed [01-vpc-network-security.md](01-vpc-network-security.md)

---

## IAM Mental Model

Every IAM decision answers four questions:

```
WHO (principal) → WHAT (action) → WHICH (resource) → CONDITIONS
```

| Question | Example |
|----------|---------|
| WHO | `arn:aws:iam::123456:role/app-backend` |
| WHAT | `s3:GetObject` |
| WHICH | `arn:aws:s3:::acme-data-bucket/*` |
| CONDITIONS | `aws:SourceVpc = vpc-abc123` |

If any of these are wildcards (`*`), your blast radius is too wide.

---

## Step 1: Lock Down the Root Account

Root has unlimited power. It should never be used for daily work.

```bash
# Check if root has access keys (should be NONE)
aws iam get-account-summary \
  --query 'SummaryMap.AccountAccessKeysPresent'
# Expected: 0

# If root has access keys — DELETE THEM from the console
# Console → IAM → Root user → Security credentials → Delete access keys

# Check if root has MFA enabled
aws iam get-account-summary \
  --query 'SummaryMap.AccountMFAEnabled'
# Expected: 1

# If MFA is not enabled:
# Console → IAM → Root user → Security credentials → Assign MFA device
# Use a hardware TOTP key (YubiKey) or authenticator app
# NEVER use SMS-based MFA
```

**Root account rules:**
1. MFA enabled — hardware key preferred
2. Access keys deleted — no programmatic access
3. Never used for daily operations
4. Password stored in a physical safe or secrets vault
5. Used only for: account closure, support PIN, billing changes

---

## Step 2: Audit Users and MFA

```bash
# Find all IAM users
aws iam list-users --query 'Users[].{User:UserName,Created:CreateDate,LastUsed:PasswordLastUsed}' \
  --output table

# Find users WITHOUT MFA enabled
aws iam generate-credential-report
sleep 5
aws iam get-credential-report --query 'Content' --output text | base64 -d | \
  awk -F',' '$4=="true" && $8=="false" {print "NO MFA:", $1}'
# $4=password_enabled, $8=mfa_active
# Any output here = users with passwords but no MFA

# Count users with MFA vs without
echo "=== MFA Coverage ==="
TOTAL=$(aws iam list-users --query 'length(Users)' --output text)
MFA_ENABLED=$(aws iam list-mfa-devices --query 'length(MFADevices)' --output text 2>/dev/null || echo "check-per-user")
echo "Total users: $TOTAL"
```

**Enforce MFA with IAM policy:**

```bash
# Create MFA enforcement policy
# Users can do nothing (except manage their own MFA) until MFA is active
cat > /tmp/enforce-mfa-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowViewAccountInfo",
      "Effect": "Allow",
      "Action": [
        "iam:GetAccountPasswordPolicy",
        "iam:ListVirtualMFADevices"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowManageOwnMFA",
      "Effect": "Allow",
      "Action": [
        "iam:CreateVirtualMFADevice",
        "iam:DeleteVirtualMFADevice",
        "iam:ListMFADevices",
        "iam:EnableMFADevice",
        "iam:ResyncMFADevice"
      ],
      "Resource": [
        "arn:aws:iam::*:mfa/${aws:username}",
        "arn:aws:iam::*:user/${aws:username}"
      ]
    },
    {
      "Sid": "DenyAllExceptMFAUnlessMFAd",
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

aws iam create-policy \
  --policy-name EnforceMFA \
  --policy-document file:///tmp/enforce-mfa-policy.json

# Attach to a group that all users belong to
aws iam attach-group-policy \
  --group-name AllUsers \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/EnforceMFA
```

---

## Step 3: Find and Deactivate Stale Credentials

Access keys older than 90 days are a liability. Find them, deactivate them, notify the owner.

```bash
# Generate fresh credential report
aws iam generate-credential-report
sleep 10

# Find access keys older than 90 days
echo "=== Stale Access Keys (>90 days) ==="
aws iam get-credential-report --query 'Content' --output text | base64 -d | \
  awk -F',' 'NR>1 {
    if ($9 == "true") {
      cmd="date -d \"" $10 "\" +%s 2>/dev/null"
      cmd | getline created
      close(cmd)
      cmd2="date +%s"
      cmd2 | getline now
      close(cmd2)
      age = (now - created) / 86400
      if (age > 90) print "STALE (" int(age) " days):", $1, "Key1"
    }
    if ($14 == "true") {
      cmd="date -d \"" $15 "\" +%s 2>/dev/null"
      cmd | getline created2
      close(cmd)
      cmd2="date +%s"
      cmd2 | getline now2
      close(cmd2)
      age2 = (now2 - created2) / 86400
      if (age2 > 90) print "STALE (" int(age2) " days):", $1, "Key2"
    }
  }'

# Deactivate a stale key (per-user, after notification)
# aws iam update-access-key --user-name USERNAME --access-key-id AKIAXXXXXXXX --status Inactive

# List access keys for a specific user
aws iam list-access-keys --user-name USERNAME \
  --query 'AccessKeyMetadata[].{KeyId:AccessKeyId,Status:Status,Created:CreateDate}' \
  --output table
```

---

## Step 4: Audit IAM Policies for Wildcards

Wildcard policies (`"Action": "*"` or `"Resource": "*"`) are the most common privilege escalation vector.

```bash
# Find all customer-managed policies
echo "=== Scanning Customer Managed Policies ==="
for POLICY_ARN in $(aws iam list-policies --scope Local \
  --query 'Policies[].Arn' --output text); do

  VERSION=$(aws iam get-policy --policy-arn $POLICY_ARN \
    --query 'Policy.DefaultVersionId' --output text)

  DOCUMENT=$(aws iam get-policy-version --policy-arn $POLICY_ARN \
    --version-id $VERSION --query 'PolicyVersion.Document' --output json)

  # Check for wildcard actions
  if echo "$DOCUMENT" | grep -q '"Action": "\*"'; then
    echo "WILDCARD ACTION: $POLICY_ARN"
  fi

  # Check for wildcard resources with powerful actions
  if echo "$DOCUMENT" | grep -q '"Resource": "\*"'; then
    echo "WILDCARD RESOURCE: $POLICY_ARN"
  fi
done

# Find inline policies (should be ZERO — use managed policies)
echo "=== Inline Policies (should be none) ==="
for USER in $(aws iam list-users --query 'Users[].UserName' --output text); do
  INLINE=$(aws iam list-user-policies --user-name $USER --query 'PolicyNames' --output text)
  if [ -n "$INLINE" ]; then
    echo "INLINE POLICY on user $USER: $INLINE"
  fi
done

for ROLE in $(aws iam list-roles --query 'Roles[].RoleName' --output text); do
  INLINE=$(aws iam list-role-policies --role-name $ROLE --query 'PolicyNames' --output text)
  if [ -n "$INLINE" ]; then
    echo "INLINE POLICY on role $ROLE: $INLINE"
  fi
done
```

**Dangerous permission combinations to flag:**

| Permission | Risk | Mitigation |
|-----------|------|------------|
| `iam:CreateAccessKey` | Create keys for any user — impersonation | Restrict to self only |
| `iam:PassRole` | Pass any role to a service — privilege escalation | Scope to specific role ARNs |
| `lambda:CreateFunction` + `iam:PassRole` | Create Lambda with admin role — full account takeover | Permission boundary |
| `sts:AssumeRole` with `"Resource": "*"` | Assume any role in any account | Scope to specific role ARNs |
| `iam:CreatePolicy` + `iam:AttachRolePolicy` | Create admin policy and attach it | Permission boundary |

---

## Step 5: Set Up IRSA (IAM Roles for Service Accounts)

IRSA gives pods their own IAM identity. Without it, every pod on a node inherits the node's IAM role — massive blast radius.

```bash
CLUSTER_NAME=acme-eks

# Step 5a: Create OIDC provider (one-time per cluster)
eksctl utils associate-iam-oidc-provider \
  --cluster $CLUSTER_NAME --approve

# Verify OIDC provider
aws eks describe-cluster --name $CLUSTER_NAME \
  --query "cluster.identity.oidc.issuer" --output text

OIDC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME \
  --query "cluster.identity.oidc.issuer" --output text | cut -d'/' -f5)
echo "OIDC Provider ID: $OIDC_ID"

# Step 5b: Create IAM role with OIDC trust policy
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)

cat > /tmp/irsa-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:production:app-sa",
        "oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com"
      }
    }
  }]
}
EOF

aws iam create-role \
  --role-name acme-app-irsa-role \
  --assume-role-policy-document file:///tmp/irsa-trust-policy.json

# Attach MINIMAL permissions (example: read-only S3 for one bucket)
cat > /tmp/irsa-permissions.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::acme-data-bucket",
      "arn:aws:s3:::acme-data-bucket/*"
    ]
  }]
}
EOF

aws iam put-role-policy \
  --role-name acme-app-irsa-role \
  --policy-name S3ReadOnly \
  --policy-document file:///tmp/irsa-permissions.json

# Step 5c: Create Kubernetes ServiceAccount with annotation
kubectl create sa app-sa -n production

kubectl annotate sa app-sa -n production \
  eks.amazonaws.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/acme-app-irsa-role

# Step 5d: Verify from inside a pod
kubectl run irsa-test --rm -it \
  --image=amazon/aws-cli:latest \
  --serviceaccount=app-sa \
  -n production \
  -- sts get-caller-identity
# Expected: Shows acme-app-irsa-role ARN, NOT the node role
```

---

## Step 6: Configure Permission Boundaries

Permission boundaries cap what a role can do, even if its policies grant more. Use them for delegated admin scenarios.

```bash
# Create a permission boundary that caps privileges
cat > /tmp/permission-boundary.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowedServices",
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "dynamodb:*",
        "sqs:*",
        "sns:*",
        "logs:*",
        "cloudwatch:*",
        "ecr:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DenyDangerous",
      "Effect": "Deny",
      "Action": [
        "iam:CreateUser",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:PutRolePolicy",
        "organizations:*",
        "account:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name DevTeamBoundary \
  --policy-document file:///tmp/permission-boundary.json

# Apply boundary to a role
aws iam put-role-permissions-boundary \
  --role-name DevTeamRole \
  --permissions-boundary arn:aws:iam::ACCOUNT_ID:policy/DevTeamBoundary
```

---

## Step 7: Enable IAM Access Analyzer

Access Analyzer finds resources shared with external accounts or the public. Enable it once, review findings weekly.

```bash
# Create Access Analyzer (one per region)
aws accessanalyzer create-analyzer \
  --analyzer-name acme-access-analyzer \
  --type ACCOUNT

# List findings
aws accessanalyzer list-findings \
  --analyzer-arn arn:aws:access-analyzer:us-east-1:ACCOUNT_ID:analyzer/acme-access-analyzer \
  --query 'findings[].{Resource:resource,Type:resourceType,Status:status,Action:action}' \
  --output table

# Archive a finding (after review and confirmation it's intentional)
# aws accessanalyzer update-findings \
#   --analyzer-arn ARN \
#   --ids FINDING_ID \
#   --status ARCHIVED
```

---

## Step 8: Troubleshoot Access Denied

When something breaks, this is your debugging sequence:

```bash
# 1. Who am I?
aws sts get-caller-identity
# Verify you're the principal you think you are

# 2. Simulate the action
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT_ID:role/MyRole \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::acme-bucket/file.txt \
  --query 'EvaluationResults[].{Action:EvalActionName,Decision:EvalDecision,Matched:MatchedStatements}'

# 3. Check for explicit denies (SCPs, permission boundaries, resource policies)
# SCPs (if using AWS Organizations)
aws organizations list-policies --filter SERVICE_CONTROL_POLICY

# 4. Check resource-based policy
aws s3api get-bucket-policy --bucket acme-bucket

# 5. Check if VPC endpoint policy is blocking
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'VpcEndpoints[].{Service:ServiceName,Policy:PolicyDocument}'
```

**Access evaluation order:** Explicit Deny (any policy) > SCP > Permission Boundary > Identity Policy + Resource Policy. A deny anywhere = denied.

---

## Step 9: Validate

```bash
echo "=== IAM Hardening Validation ==="

echo "--- Root Account ---"
aws iam get-account-summary --query '{
  RootMFA: SummaryMap.AccountMFAEnabled,
  RootAccessKeys: SummaryMap.AccountAccessKeysPresent
}' --output table
# Expected: RootMFA=1, RootAccessKeys=0

echo "--- Wildcard Policies ---"
aws iam list-policies --scope Local --query 'length(Policies)' --output text
# Review each one with Step 4

echo "--- Access Analyzer ---"
aws accessanalyzer list-analyzers \
  --query 'analyzers[].{Name:name,Status:status}' --output table
# Expected: Status=ACTIVE

echo "--- IRSA Verification ---"
kubectl get sa -A -o json | \
  jq -r '.items[] | select(.metadata.annotations["eks.amazonaws.com/role-arn"] != null) |
  "\(.metadata.namespace)/\(.metadata.name) -> \(.metadata.annotations["eks.amazonaws.com/role-arn"])"'
# Lists all ServiceAccounts with IRSA roles
```

---

## Expected Outcomes

| Check | Pass Criteria |
|-------|--------------|
| Root MFA | Enabled (hardware key preferred) |
| Root access keys | Deleted (0 keys) |
| User MFA | 100% of console users have MFA |
| Stale keys | No access keys older than 90 days active |
| Wildcard policies | Zero `"Action": "*"` in customer-managed policies |
| Inline policies | Zero inline policies on users or roles |
| IRSA | All EKS workloads use ServiceAccount-level IAM |
| Permission boundaries | Applied to all delegated admin roles |
| Access Analyzer | Enabled, zero unreviewed findings |

---

## IAM Hardening Checklist

| # | Control | Status |
|---|---------|--------|
| 1 | Root account MFA enabled (hardware key) | [ ] |
| 2 | Root access keys deleted | [ ] |
| 3 | All console users have MFA | [ ] |
| 4 | MFA enforcement policy attached | [ ] |
| 5 | No inline policies on users or roles | [ ] |
| 6 | No wildcard `Action: *` policies | [ ] |
| 7 | IAM roles used instead of access keys | [ ] |
| 8 | Permission boundaries on delegated admins | [ ] |
| 9 | Access Analyzer enabled and reviewed | [ ] |
| 10 | Stale credentials (>90 days) deactivated | [ ] |
| 11 | IRSA configured for EKS workloads | [ ] |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `AccessDenied` after MFA policy | User hasn't set up MFA yet | User must set up MFA in console before API calls work |
| IRSA pod shows node role | ServiceAccount annotation missing or wrong | Verify `eks.amazonaws.com/role-arn` annotation on SA |
| IRSA pod shows `ExpiredTokenException` | OIDC provider not associated with cluster | `eksctl utils associate-iam-oidc-provider --cluster NAME --approve` |
| Access Analyzer shows external access | S3 bucket policy or IAM role trust is too broad | Review and scope down the resource policy |
| `simulate-principal-policy` says Allow but real call Denied | SCP or permission boundary blocking | Check org SCPs: `aws organizations list-policies --filter SERVICE_CONTROL_POLICY` |
| `iam:PassRole` denied | Role not in PassRole condition | Add specific role ARN to `iam:PassRole` resource list |

---

## Next Steps

- IAM hardened? Protect your data next. -> [03-data-protection.md](03-data-protection.md)
- Need to set up cross-account access? -> See ENGAGEMENT-GUIDE.md Tier 2
- Ready for cost analysis? -> `python3 $PKG/tools/cost-estimate.py`

---

*Ghost Protocol — Cloud Security Package*
