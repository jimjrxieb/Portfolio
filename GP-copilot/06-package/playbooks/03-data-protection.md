# Playbook 03 — Data Protection

> Encrypt everything at rest and in transit. Block public access on S3. Rotate secrets automatically. That's the whole strategy.
>
> **When:** After VPC (Playbook 01) and IAM (Playbook 02) are hardened. Data protection builds on both.
> **Audience:** Platform engineers, security consultants, compliance teams.
> **Time:** ~45 min (KMS + S3 + Secrets Manager + validation)

---

## Prerequisites

- AWS CLI configured with appropriate permissions (`kms:*`, `s3:*`, `secretsmanager:*`)
- VPC deployed ([01-vpc-network-security.md](01-vpc-network-security.md))
- IAM hardened ([02-iam-hardening.md](02-iam-hardening.md))
- Target region selected (examples use `us-east-1`)

---

## Encryption Decision Tree

| Service | At Rest | In Transit | Key Type | Notes |
|---------|---------|------------|----------|-------|
| S3 | SSE-KMS (CMK) | TLS (bucket policy enforces HTTPS) | Customer Managed Key | Block public access at account + bucket level |
| EBS | KMS | N/A (block device) | Customer Managed Key | Enable default encryption per region |
| RDS | KMS | TLS (force via parameter group) | Customer Managed Key | Must be set at creation — cannot add later |
| DynamoDB | KMS | TLS (default) | Customer Managed Key | Can switch from AWS-managed to CMK anytime |
| EKS etcd | KMS envelope encryption | TLS (default) | Customer Managed Key | Set at cluster creation for full coverage |
| Secrets Manager | KMS | TLS (default) | Customer Managed Key | Automatic rotation every 30 days |

**Rule: If it stores data, it gets a KMS Customer Managed Key. No exceptions.**

---

## Step 1: Create KMS Keys

One key per purpose. Never share keys across unrelated services.

```bash
# Create KMS key for EKS secrets (envelope encryption)
EKS_KEY_ID=$(aws kms create-key \
  --description "acme-eks-secrets-encryption" \
  --tags TagKey=Purpose,TagValue=eks-secrets TagKey=Environment,TagValue=production \
  --query 'KeyMetadata.KeyId' --output text)

aws kms create-alias \
  --alias-name alias/acme-eks-secrets \
  --target-key-id $EKS_KEY_ID

# Create KMS key for S3 encryption
S3_KEY_ID=$(aws kms create-key \
  --description "acme-s3-encryption" \
  --tags TagKey=Purpose,TagValue=s3 TagKey=Environment,TagValue=production \
  --query 'KeyMetadata.KeyId' --output text)

aws kms create-alias \
  --alias-name alias/acme-s3 \
  --target-key-id $S3_KEY_ID

# Create KMS key for Secrets Manager
SM_KEY_ID=$(aws kms create-key \
  --description "acme-secrets-manager-encryption" \
  --tags TagKey=Purpose,TagValue=secrets-manager TagKey=Environment,TagValue=production \
  --query 'KeyMetadata.KeyId' --output text)

aws kms create-alias \
  --alias-name alias/acme-secrets \
  --target-key-id $SM_KEY_ID

# Enable automatic key rotation on ALL keys (FedRAMP requires this)
for KEY_ID in $EKS_KEY_ID $S3_KEY_ID $SM_KEY_ID; do
  aws kms enable-key-rotation --key-id $KEY_ID
  echo "Rotation enabled for $KEY_ID"
done

# Verify rotation is enabled
for KEY_ID in $EKS_KEY_ID $S3_KEY_ID $SM_KEY_ID; do
  ROTATION=$(aws kms get-key-rotation-status --key-id $KEY_ID \
    --query 'KeyRotationEnabled' --output text)
  echo "Key $KEY_ID rotation: $ROTATION"
done
```

---

## Step 2: Block Public Access on S3 (Account-Level)

This is a one-time operation per AWS account. It blocks public access on ALL buckets, even if someone misconfigures a bucket policy later.

```bash
# Account-level public access block (do this ONCE)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws s3control put-public-access-block \
  --account-id $ACCOUNT_ID \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Verify account-level block
aws s3control get-public-access-block --account-id $ACCOUNT_ID
# Expected: All four settings = true
```

---

## Step 3: Create Hardened S3 Bucket

This is the evidence bucket pattern — every compliance-sensitive bucket should look like this.

```bash
BUCKET_NAME="acme-data-$(date +%Y%m%d)"
REGION="us-east-1"
LOG_BUCKET="acme-access-logs-$(date +%Y%m%d)"

# Create logging bucket first
aws s3api create-bucket --bucket $LOG_BUCKET --region $REGION

# Block public access on logging bucket
aws s3api put-public-access-block --bucket $LOG_BUCKET \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create the data bucket
aws s3api create-bucket --bucket $BUCKET_NAME --region $REGION

# Block public access (belt AND suspenders with account-level)
aws s3api put-public-access-block --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Enable versioning (required for compliance — protect against accidental deletes)
aws s3api put-bucket-versioning --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable SSE-KMS encryption with our CMK
aws s3api put-bucket-encryption --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "alias/acme-s3"
      },
      "BucketKeyEnabled": true
    }]
  }'

# Enable access logging
aws s3api put-bucket-logging --bucket $BUCKET_NAME \
  --bucket-logging-status '{
    "LoggingEnabled": {
      "TargetBucket": "'"$LOG_BUCKET"'",
      "TargetPrefix": "'"$BUCKET_NAME"'/"
    }
  }'

# Force HTTPS — deny any request that isn't TLS
aws s3api put-bucket-policy --bucket $BUCKET_NAME \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "DenyInsecureTransport",
        "Effect": "Deny",
        "Principal": "*",
        "Action": "s3:*",
        "Resource": [
          "arn:aws:s3:::'"$BUCKET_NAME"'",
          "arn:aws:s3:::'"$BUCKET_NAME"'/*"
        ],
        "Condition": {
          "Bool": {
            "aws:SecureTransport": "false"
          }
        }
      },
      {
        "Sid": "DenyUnencryptedUploads",
        "Effect": "Deny",
        "Principal": "*",
        "Action": "s3:PutObject",
        "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'/*",
        "Condition": {
          "StringNotEquals": {
            "s3:x-amz-server-side-encryption": "aws:kms"
          }
        }
      }
    ]
  }'

# Lifecycle policy — Glacier at 90 days, delete at 365 days
aws s3api put-bucket-lifecycle-configuration --bucket $BUCKET_NAME \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "ArchiveAndExpire",
      "Status": "Enabled",
      "Filter": {},
      "Transitions": [{
        "Days": 90,
        "StorageClass": "GLACIER"
      }],
      "Expiration": {
        "Days": 365
      },
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 90
      }
    }]
  }'

echo "Hardened bucket created: $BUCKET_NAME"
```

---

## Step 4: Enable Default EBS Encryption

One-time per region. Every new EBS volume will be encrypted automatically.

```bash
# Enable default EBS encryption (per region)
aws ec2 enable-ebs-encryption-by-default

# Verify
aws ec2 get-ebs-encryption-by-default \
  --query 'EbsEncryptionByDefault'
# Expected: true

# Set the default KMS key for EBS (optional — uses aws/ebs if not set)
aws ec2 modify-ebs-default-kms-key-id \
  --kms-key-id alias/acme-ebs

# Verify existing volumes are encrypted
echo "=== Unencrypted EBS Volumes ==="
aws ec2 describe-volumes \
  --filters "Name=encrypted,Values=false" \
  --query 'Volumes[].{ID:VolumeId,Size:Size,State:State,AZ:AvailabilityZone}' \
  --output table
# Expected: Empty (no unencrypted volumes)
# If volumes appear, they must be migrated (snapshot -> copy with encryption -> restore)
```

---

## Step 5: Configure Secrets Manager

Never hardcode secrets. Never store them in environment variables. Use Secrets Manager with automatic rotation.

```bash
# Store database credentials
aws secretsmanager create-secret \
  --name acme/production/rds-credentials \
  --description "Production RDS PostgreSQL credentials" \
  --kms-key-id alias/acme-secrets \
  --secret-string '{
    "username": "app_user",
    "password": "INITIAL_PASSWORD_CHANGE_ME",
    "engine": "postgres",
    "host": "acme-prod-db.xxxx.us-east-1.rds.amazonaws.com",
    "port": 5432,
    "dbname": "acme_production"
  }'

# Store Redis token
aws secretsmanager create-secret \
  --name acme/production/redis-token \
  --description "Production Redis AUTH token" \
  --kms-key-id alias/acme-secrets \
  --secret-string '{"auth_token": "INITIAL_TOKEN_CHANGE_ME"}'

# Store API keys
aws secretsmanager create-secret \
  --name acme/production/api-keys \
  --description "Third-party API keys" \
  --kms-key-id alias/acme-secrets \
  --secret-string '{"stripe_key": "sk_live_xxx", "datadog_key": "dd_xxx"}'

# Enable automatic rotation (30-day cycle)
# Requires a Lambda rotation function — use the AWS template
aws secretsmanager rotate-secret \
  --secret-id acme/production/rds-credentials \
  --rotation-lambda-arn arn:aws:lambda:us-east-1:ACCOUNT_ID:function:SecretsManagerRotation \
  --rotation-rules AutomaticallyAfterDays=30

# Verify rotation configuration
aws secretsmanager describe-secret \
  --secret-id acme/production/rds-credentials \
  --query '{Name:Name,RotationEnabled:RotationEnabled,RotationDays:RotationRules.AutomaticallyAfterDays}' \
  --output table
```

**Secrets Manager with VPC Endpoint (private access):**

```bash
# Create VPC Endpoint for Secrets Manager (traffic stays in VPC)
aws ec2 create-vpc-endpoint \
  --vpc-id $VPC_ID \
  --vpc-endpoint-type Interface \
  --service-name com.amazonaws.us-east-1.secretsmanager \
  --subnet-ids $PRIV_SUB_A $PRIV_SUB_B \
  --security-group-ids $APP_SG \
  --private-dns-enabled \
  --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=acme-secretsmanager-endpoint}]'
```

**Resource-based policy (restrict who can read secrets):**

```bash
aws secretsmanager put-resource-policy \
  --secret-id acme/production/rds-credentials \
  --resource-policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Deny",
      "Principal": "*",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalArn": [
            "arn:aws:iam::ACCOUNT_ID:role/acme-app-irsa-role",
            "arn:aws:iam::ACCOUNT_ID:role/acme-admin-role"
          ]
        }
      }
    }]
  }'
```

---

## Step 6: Validate Everything

```bash
PKG=~/linkops-industries/GP-copilot/GP-CONSULTING/06-CLOUD-SECURITY

# Run security validation
bash $PKG/tools/validate-security.sh --target ./infrastructure/

echo "=== KMS Key Validation ==="
for ALIAS in acme-eks-secrets acme-s3 acme-secrets; do
  KEY_ID=$(aws kms describe-key --key-id alias/$ALIAS \
    --query 'KeyMetadata.KeyId' --output text 2>/dev/null)
  if [ -n "$KEY_ID" ]; then
    ROTATION=$(aws kms get-key-rotation-status --key-id $KEY_ID \
      --query 'KeyRotationEnabled' --output text)
    echo "Key alias/$ALIAS: ID=$KEY_ID Rotation=$ROTATION"
  else
    echo "MISSING: alias/$ALIAS"
  fi
done

echo ""
echo "=== S3 Public Access Block (Account Level) ==="
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3control get-public-access-block --account-id $ACCOUNT_ID \
  --query 'PublicAccessBlockConfiguration' --output table
# Expected: All four = True

echo ""
echo "=== S3 Bucket Security Audit ==="
for BUCKET in $(aws s3api list-buckets --query 'Buckets[].Name' --output text); do
  echo "--- $BUCKET ---"

  # Check public access block
  PAB=$(aws s3api get-public-access-block --bucket $BUCKET 2>/dev/null \
    --query 'PublicAccessBlockConfiguration.BlockPublicAcls' --output text || echo "NOT SET")
  echo "  Public Access Block: $PAB"

  # Check encryption
  ENC=$(aws s3api get-bucket-encryption --bucket $BUCKET 2>/dev/null \
    --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
    --output text || echo "NONE")
  echo "  Encryption: $ENC"

  # Check versioning
  VER=$(aws s3api get-bucket-versioning --bucket $BUCKET \
    --query 'Status' --output text)
  echo "  Versioning: ${VER:-DISABLED}"

  # Check logging
  LOG=$(aws s3api get-bucket-logging --bucket $BUCKET \
    --query 'LoggingEnabled.TargetBucket' --output text 2>/dev/null || echo "DISABLED")
  echo "  Access Logging: $LOG"
done

echo ""
echo "=== EBS Default Encryption ==="
aws ec2 get-ebs-encryption-by-default \
  --query 'EbsEncryptionByDefault' --output text
# Expected: true

echo ""
echo "=== Secrets Manager Audit ==="
aws secretsmanager list-secrets \
  --query 'SecretList[].{Name:Name,KmsKey:KmsKeyId,Rotation:RotationEnabled,LastRotated:LastRotatedDate}' \
  --output table

echo ""
echo "=== Unencrypted Resources ==="
# Unencrypted EBS volumes
UNENC_EBS=$(aws ec2 describe-volumes --filters "Name=encrypted,Values=false" \
  --query 'length(Volumes)' --output text)
echo "Unencrypted EBS volumes: $UNENC_EBS"

# Unencrypted RDS instances
UNENC_RDS=$(aws rds describe-db-instances \
  --query 'DBInstances[?StorageEncrypted==`false`].DBInstanceIdentifier' --output text)
echo "Unencrypted RDS instances: ${UNENC_RDS:-none}"
```

---

## Expected Outcomes

| Check | Pass Criteria |
|-------|--------------|
| KMS keys | 3+ CMKs created with rotation enabled |
| Account public access block | All four settings = true |
| S3 buckets | SSE-KMS, versioning, logging, HTTPS-only policy |
| EBS default encryption | Enabled for the region |
| Secrets Manager | All secrets use CMK, rotation enabled (30 days) |
| No unencrypted EBS | Zero volumes with encrypted=false |
| No unencrypted RDS | Zero instances with StorageEncrypted=false |

---

## S3 Security Checklist

| # | Control | Status |
|---|---------|--------|
| 1 | Account-level public access block enabled | [ ] |
| 2 | Bucket-level public access block enabled | [ ] |
| 3 | SSE-KMS encryption with CMK | [ ] |
| 4 | Versioning enabled | [ ] |
| 5 | Access logging enabled | [ ] |
| 6 | No ACLs (use bucket policies only) | [ ] |
| 7 | Lifecycle policy (Glacier + expiration) | [ ] |
| 8 | HTTPS-only bucket policy | [ ] |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `AccessDenied` when writing to S3 | Bucket policy requires KMS encryption header | Add `--sse aws:kms --sse-kms-key-id alias/acme-s3` to upload commands |
| KMS key rotation not working | Key is AWS-managed, not customer-managed | Create a new CMK and migrate — AWS-managed keys don't support custom rotation |
| Secrets Manager `DecryptionFailure` | IAM role missing `kms:Decrypt` for the CMK | Add `kms:Decrypt` permission for the secret's KMS key ARN |
| EBS volume not encrypted | Created before default encryption was enabled | Snapshot -> Copy with encryption -> Create volume from encrypted snapshot |
| RDS not encrypted | Cannot enable encryption on existing instance | Snapshot -> Copy with encryption -> Restore from encrypted snapshot (requires downtime) |
| S3 upload fails with `InvalidEncryptionMethod` | Bucket policy requires `aws:kms` but client sent `AES256` | Update client to use `--sse aws:kms` or update bucket policy to allow both |
| Lifecycle policy not transitioning | Objects smaller than 128KB can't transition to Glacier | Add size filter to lifecycle rule or accept that small objects stay in Standard |

---

## Next Steps

- Data protection complete? Deploy and test with LocalStack. -> `bash $PKG/tools/test-localstack.sh`
- Ready to deploy to AWS? -> `bash $PKG/tools/deploy-terraform.sh`
- Need database migration? -> `bash $PKG/tools/migrate-database.sh`
- Need cost estimation? -> `python3 $PKG/tools/cost-estimate.py`

---

*Ghost Protocol — Cloud Security Package*
