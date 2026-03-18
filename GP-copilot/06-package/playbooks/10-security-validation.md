# Playbook 10 — Security Validation

> Run the final audit across all AWS security controls. Prove posture before handoff.
>
> **When:** After Playbooks 01-08 are complete. This is the final gate.
> **Audience:** Security lead, platform engineers, compliance team.
> **Time:** ~60 min (automated scans + manual spot-checks + report generation)

---

## Prerequisites

- AWS CLI configured with read-only admin access (SecurityAudit policy minimum)
- All prior playbooks (01-08) executed and verified
- `$REGION`, `$ACCOUNT_ID`, `$ENV`, `$CLUSTER_NAME` environment variables set
- Tools installed: Checkov, TFsec, Kubescape (optional but recommended)

```bash
export REGION="us-east-1"
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ENV="production"
export CLUSTER_NAME="production-eks"
export PKG=~/linkops-industries/GP-copilot/GP-CONSULTING/06-CLOUD-SECURITY
export REPORT_DIR="/tmp/security-validation-$(date +%Y%m%d)"
mkdir -p "${REPORT_DIR}"
```

---

## Step 1: Network Security Validation

### 1a. Security groups — no open 0.0.0.0/0 (except ALB)

```bash
echo "=== Security Groups with 0.0.0.0/0 ingress ==="
aws ec2 describe-security-groups \
  --query "SecurityGroups[?IpPermissions[?IpRanges[?CidrIp=='0.0.0.0/0']]].{
    ID:GroupId,
    Name:GroupName,
    VPC:VpcId,
    Ports:IpPermissions[?IpRanges[?CidrIp=='0.0.0.0/0']].{From:FromPort,To:ToPort}
  }" \
  --output table

# Expected: Only ALB security groups should appear (ports 80/443)
# FAIL if any SG allows 0.0.0.0/0 on ports other than 80/443
```

### 1b. VPC Flow Logs enabled

```bash
echo "=== VPC Flow Logs ==="
VPCS=$(aws ec2 describe-vpcs --query "Vpcs[].VpcId" --output text)
for VPC in ${VPCS}; do
  FLOW_LOG=$(aws ec2 describe-flow-logs \
    --filter "Name=resource-id,Values=${VPC}" \
    --query "FlowLogs[0].FlowLogStatus" --output text)
  if [[ "${FLOW_LOG}" == "ACTIVE" ]]; then
    echo "PASS: ${VPC} — Flow Logs active"
  else
    echo "FAIL: ${VPC} — Flow Logs NOT active"
  fi
done
```

### 1c. VPC endpoints exist (S3, DynamoDB minimum)

```bash
echo "=== VPC Endpoints ==="
aws ec2 describe-vpc-endpoints \
  --query "VpcEndpoints[].{Service:ServiceName,Type:VpcEndpointType,State:State}" \
  --output table

# Expected: At minimum s3 and dynamodb gateway endpoints
```

### 1d. IMDSv2 enforced on all instances

```bash
echo "=== IMDSv2 Check ==="
aws ec2 describe-instances \
  --query "Reservations[].Instances[].{
    ID:InstanceId,
    Name:Tags[?Key=='Name']|[0].Value,
    HttpTokens:MetadataOptions.HttpTokens,
    HttpEndpoint:MetadataOptions.HttpEndpoint
  }" \
  --output table

# PASS: HttpTokens=required for all instances
# FAIL: HttpTokens=optional means IMDSv1 is still allowed
```

### 1e. No public subnets routing non-ALB resources to IGW

```bash
echo "=== Public Subnet Check ==="
aws ec2 describe-route-tables \
  --query "RouteTables[?Routes[?GatewayId && starts_with(GatewayId, 'igw-')]].{
    RouteTableId:RouteTableId,
    VPC:VpcId,
    Subnets:Associations[].SubnetId
  }" \
  --output table

# Review: Only ALB subnets should have IGW routes
```

---

## Step 2: IAM Validation

### 2a. Root account MFA enabled

```bash
echo "=== Root MFA ==="
MFA_ENABLED=$(aws iam get-account-summary \
  --query "SummaryMap.AccountMFAEnabled" --output text)

if [[ "${MFA_ENABLED}" == "1" ]]; then
  echo "PASS: Root MFA enabled"
else
  echo "FAIL: Root MFA NOT enabled — fix immediately"
fi
```

### 2b. No wildcard IAM policies

```bash
echo "=== Wildcard Policy Check ==="
for POLICY_ARN in $(aws iam list-policies \
  --scope Local \
  --query "Policies[].Arn" --output text); do

  VERSION=$(aws iam get-policy \
    --policy-arn "${POLICY_ARN}" \
    --query "Policy.DefaultVersionId" --output text)

  WILDCARDS=$(aws iam get-policy-version \
    --policy-arn "${POLICY_ARN}" \
    --version-id "${VERSION}" \
    --query "PolicyVersion.Document.Statement[?Action=='*' || Resource=='*'].Effect" \
    --output text)

  if [[ -n "${WILDCARDS}" ]]; then
    echo "WARN: ${POLICY_ARN} contains wildcard Action or Resource"
  fi
done
```

### 2c. No stale credentials

```bash
echo "=== Credential Report ==="
aws iam generate-credential-report > /dev/null 2>&1
sleep 5
aws iam get-credential-report \
  --query "Content" --output text | base64 -d > "${REPORT_DIR}/credential-report.csv"

echo "Credential report saved to ${REPORT_DIR}/credential-report.csv"
echo ""
echo "Users with password but no MFA:"
awk -F',' 'NR>1 && $4=="true" && $8=="false" {print $1}' "${REPORT_DIR}/credential-report.csv"
echo ""
echo "Access keys unused >90 days:"
awk -F',' 'NR>1 && $9=="true" && $11!="N/A" {print $1, $11}' "${REPORT_DIR}/credential-report.csv"
```

### 2d. IRSA configured (EKS)

```bash
echo "=== IRSA (IAM Roles for Service Accounts) ==="
OIDC=$(aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --query "cluster.identity.oidc.issuer" --output text 2>/dev/null)

if [[ -n "${OIDC}" && "${OIDC}" != "None" ]]; then
  echo "PASS: OIDC provider configured — ${OIDC}"
else
  echo "FAIL: OIDC provider not configured — IRSA unavailable"
fi
```

### 2e. IAM Access Analyzer enabled

```bash
echo "=== Access Analyzer ==="
ANALYZERS=$(aws accessanalyzer list-analyzers \
  --query "analyzers[].{Name:name,Status:status,Type:type}" --output table)

if [[ -n "${ANALYZERS}" ]]; then
  echo "PASS: Access Analyzer active"
  echo "${ANALYZERS}"
else
  echo "FAIL: No Access Analyzer configured"
fi
```

---

## Step 3: Encryption Validation

### 3a. EBS default encryption

```bash
echo "=== EBS Default Encryption ==="
EBS_ENCRYPTED=$(aws ec2 get-ebs-encryption-by-default \
  --query "EbsEncryptionByDefault" --output text)

if [[ "${EBS_ENCRYPTED}" == "True" ]]; then
  echo "PASS: EBS default encryption enabled"
  aws ec2 get-ebs-default-kms-key-id --query "KmsKeyId" --output text
else
  echo "FAIL: EBS default encryption NOT enabled"
fi
```

### 3b. S3 buckets encrypted

```bash
echo "=== S3 Bucket Encryption ==="
for BUCKET in $(aws s3api list-buckets --query "Buckets[].Name" --output text); do
  ENCRYPTION=$(aws s3api get-bucket-encryption \
    --bucket "${BUCKET}" \
    --query "ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm" \
    --output text 2>/dev/null)

  if [[ -n "${ENCRYPTION}" && "${ENCRYPTION}" != "None" ]]; then
    echo "PASS: ${BUCKET} — ${ENCRYPTION}"
  else
    echo "FAIL: ${BUCKET} — NO encryption configured"
  fi
done
```

### 3c. RDS encrypted

```bash
echo "=== RDS Encryption ==="
aws rds describe-db-instances \
  --query "DBInstances[].{
    DB:DBInstanceIdentifier,
    Encrypted:StorageEncrypted,
    KmsKey:KmsKeyId,
    Engine:Engine
  }" \
  --output table

# FAIL if any StorageEncrypted=false
```

### 3d. KMS key rotation enabled

```bash
echo "=== KMS Key Rotation ==="
for KEY_ID in $(aws kms list-keys --query "Keys[].KeyId" --output text); do
  KEY_META=$(aws kms describe-key --key-id "${KEY_ID}" \
    --query "KeyMetadata.{Manager:KeyManager,State:KeyState}" --output text)

  # Skip AWS-managed keys
  if [[ "${KEY_META}" == *"AWS"* ]]; then continue; fi

  ROTATION=$(aws kms get-key-rotation-status \
    --key-id "${KEY_ID}" \
    --query "KeyRotationEnabled" --output text 2>/dev/null)

  if [[ "${ROTATION}" == "True" ]]; then
    echo "PASS: ${KEY_ID} — rotation enabled"
  else
    echo "FAIL: ${KEY_ID} — rotation NOT enabled"
  fi
done
```

### 3e. Secrets Manager in use

```bash
echo "=== Secrets Manager ==="
SECRET_COUNT=$(aws secretsmanager list-secrets \
  --query "length(SecretList)" --output text)
echo "Secrets Manager entries: ${SECRET_COUNT}"

if [[ "${SECRET_COUNT}" -gt 0 ]]; then
  echo "PASS: Secrets Manager in use"
  aws secretsmanager list-secrets \
    --query "SecretList[].{Name:Name,LastRotated:LastRotatedDate}" --output table
else
  echo "WARN: No secrets in Secrets Manager — verify no hardcoded secrets exist"
fi
```

---

## Step 4: EKS Validation

### 4a. Private endpoint

```bash
echo "=== EKS Endpoint Access ==="
aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --query "cluster.resourcesVpcConfig.{
    PublicAccess:endpointPublicAccess,
    PrivateAccess:endpointPrivateAccess,
    PublicCIDRs:publicAccessCidrs
  }" \
  --output table

# PASS: PublicAccess=false OR PublicAccess=true with restricted CIDRs (not 0.0.0.0/0)
# FAIL: PublicAccess=true with 0.0.0.0/0
```

### 4b. All control plane logging enabled

```bash
echo "=== EKS Logging ==="
aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --query "cluster.logging.clusterLogging[].{Enabled:enabled,Types:types}" \
  --output table

# PASS: All 5 types enabled — api, audit, authenticator, controllerManager, scheduler
```

### 4c. Envelope encryption (secrets at rest)

```bash
echo "=== EKS Envelope Encryption ==="
ENCRYPTION_CONFIG=$(aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --query "cluster.encryptionConfig" --output text)

if [[ -n "${ENCRYPTION_CONFIG}" && "${ENCRYPTION_CONFIG}" != "None" ]]; then
  echo "PASS: Envelope encryption configured"
  aws eks describe-cluster \
    --name "${CLUSTER_NAME}" \
    --query "cluster.encryptionConfig[].{Resources:resources,KeyArn:provider.keyArn}" \
    --output table
else
  echo "FAIL: Envelope encryption NOT configured — K8s Secrets stored in plaintext in etcd"
fi
```

### 4d. ECR scan on push

```bash
echo "=== ECR Scan on Push ==="
aws ecr describe-repositories \
  --query "repositories[].{
    Repo:repositoryName,
    ScanOnPush:imageScanningConfiguration.scanOnPush
  }" \
  --output table

# FAIL if any ScanOnPush=false
```

---

## Step 5: Monitoring Validation

### 5a. CloudTrail active

```bash
echo "=== CloudTrail ==="
for TRAIL in $(aws cloudtrail list-trails --query "Trails[].Name" --output text); do
  STATUS=$(aws cloudtrail get-trail-status --name "${TRAIL}" \
    --query "{Logging:IsLogging,LatestDelivery:LatestDeliveryTime}" --output text)
  echo "${TRAIL}: ${STATUS}"
done
```

### 5b. GuardDuty enabled

```bash
echo "=== GuardDuty ==="
DETECTORS=$(aws guardduty list-detectors --query "DetectorIds" --output text)
if [[ -n "${DETECTORS}" ]]; then
  for DET in ${DETECTORS}; do
    STATUS=$(aws guardduty get-detector --detector-id "${DET}" \
      --query "Status" --output text)
    echo "PASS: Detector ${DET} — ${STATUS}"
  done
else
  echo "FAIL: No GuardDuty detectors found"
fi
```

### 5c. Security Hub enabled

```bash
echo "=== Security Hub ==="
HUB_ARN=$(aws securityhub describe-hub --query "HubArn" --output text 2>/dev/null)
if [[ -n "${HUB_ARN}" && "${HUB_ARN}" != "None" ]]; then
  echo "PASS: Security Hub enabled — ${HUB_ARN}"
  aws securityhub get-enabled-standards \
    --query "StandardsSubscriptions[].{Standard:StandardsArn,Status:StandardsStatus}" \
    --output table
else
  echo "FAIL: Security Hub NOT enabled"
fi
```

### 5d. Config rules active

```bash
echo "=== AWS Config Rules ==="
aws configservice describe-config-rules \
  --query "ConfigRules[].{Rule:ConfigRuleName,State:ConfigRuleState}" \
  --output table

COMPLIANT=$(aws configservice get-compliance-summary-by-config-rule \
  --query "ComplianceSummary.CompliantResourceCount.CappedCount" --output text)
NON_COMPLIANT=$(aws configservice get-compliance-summary-by-config-rule \
  --query "ComplianceSummary.NonCompliantResourceCount.CappedCount" --output text)

echo "Compliant rules: ${COMPLIANT}"
echo "Non-compliant rules: ${NON_COMPLIANT}"
```

### 5e. CloudWatch alarms exist

```bash
echo "=== CloudWatch Alarms ==="
aws cloudwatch describe-alarms \
  --query "MetricAlarms[].{Name:AlarmName,State:StateValue,Metric:MetricName}" \
  --output table

ALARM_COUNT=$(aws cloudwatch describe-alarms \
  --query "length(MetricAlarms)" --output text)
echo "Total alarms: ${ALARM_COUNT}"

if [[ "${ALARM_COUNT}" -ge 5 ]]; then
  echo "PASS: Minimum alarm coverage met"
else
  echo "FAIL: Fewer than 5 alarms — expected at least 5 from Playbook 07"
fi
```

---

## Step 6: Run Automated Scans

### 6a. IaC security scan (Checkov + TFsec)

```bash
echo "=== IaC Security Scan ==="
bash "${PKG}/tools/validate-security.sh" --dir "${PKG}/terraform" 2>&1 | tee "${REPORT_DIR}/iac-scan.txt"
bash "${PKG}/tools/validate-security.sh" --dir "${PKG}/cloudformation" 2>&1 | tee -a "${REPORT_DIR}/iac-scan.txt"
```

### 6b. Kubescape on EKS (if accessible)

```bash
echo "=== Kubescape ==="
if command -v kubescape &>/dev/null; then
  kubescape scan \
    --format pretty-printer \
    --output "${REPORT_DIR}/kubescape-report.txt" 2>&1
  echo "Kubescape report: ${REPORT_DIR}/kubescape-report.txt"
else
  echo "SKIP: Kubescape not installed (curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | bash)"
fi
```

### 6c. AWS Config compliance summary

```bash
echo "=== Config Compliance ==="
aws configservice get-compliance-summary-by-config-rule \
  --output json | tee "${REPORT_DIR}/config-compliance.json"

# List non-compliant resources
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name "s3-bucket-public-read-prohibited" \
  --compliance-types NON_COMPLIANT \
  --query "EvaluationResults[].{
    Resource:EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId,
    Rule:EvaluationResultIdentifier.EvaluationResultQualifier.ConfigRuleName
  }" \
  --output table
```

---

## Step 7: Generate Compliance Report

Map each validation check to compliance framework controls.

### Compliance mapping

| Validation Check | NIST 800-53 | CIS AWS v1.4 | SOC 2 | FedRAMP |
|-----------------|-------------|--------------|-------|---------|
| No open SGs (0.0.0.0/0) | SC-7 | 5.1, 5.2, 5.3 | CC6.1 | SC-7 |
| VPC Flow Logs enabled | AU-2, AU-3 | 3.9 | CC7.2 | AU-2 |
| IMDSv2 enforced | CM-6 | — | CC6.1 | CM-6 |
| Root MFA enabled | IA-2(1) | 1.5 | CC6.1 | IA-2(1) |
| No wildcard IAM policies | AC-6 | 1.16 | CC6.3 | AC-6 |
| No stale credentials | AC-2(3) | 1.3 | CC6.2 | AC-2(3) |
| IRSA configured | AC-6(5) | — | CC6.3 | AC-6(5) |
| Access Analyzer enabled | CA-7 | — | CC4.1 | CA-7 |
| EBS default encryption | SC-28 | 2.2.1 | CC6.7 | SC-28 |
| S3 encryption | SC-28 | 2.1.1 | CC6.7 | SC-28 |
| RDS encryption | SC-28 | — | CC6.7 | SC-28 |
| KMS key rotation | SC-12(1) | 2.8 | CC6.7 | SC-12(1) |
| Secrets Manager in use | SC-12 | — | CC6.1 | SC-12 |
| EKS private endpoint | SC-7 | — | CC6.1 | SC-7 |
| EKS logging enabled | AU-2 | — | CC7.2 | AU-2 |
| EKS envelope encryption | SC-28(1) | — | CC6.7 | SC-28(1) |
| ECR scan on push | SI-2, RA-5 | — | CC7.1 | RA-5 |
| CloudTrail active | AU-2, AU-3 | 3.1 | CC7.2 | AU-2 |
| GuardDuty enabled | SI-4 | — | CC7.2 | SI-4 |
| Security Hub enabled | CA-7, SI-4 | — | CC4.1 | CA-7 |
| Config rules active | CM-6, CA-7 | — | CC7.1 | CM-6 |
| CloudWatch alarms | SI-4, IR-6 | 4.x | CC7.3 | SI-4 |

Reference pattern: `templates/vpc-isolation/compliance-mapping.md`

---

## Step 8: Comprehensive Validation Script

Run ALL checks as a single scorecard.

```bash
#!/usr/bin/env bash
# Full validation scorecard — runs all checks from Steps 1-5
set -uo pipefail

PASS=0
FAIL=0
WARN=0

check() {
  local name="$1"
  local result="$2"
  if [[ "${result}" == "PASS" ]]; then
    echo "  [PASS] ${name}"
    ((PASS++))
  elif [[ "${result}" == "WARN" ]]; then
    echo "  [WARN] ${name}"
    ((WARN++))
  else
    echo "  [FAIL] ${name}"
    ((FAIL++))
  fi
}

echo "========================================="
echo "  Security Validation Scorecard"
echo "  $(date -u +%Y-%m-%d\ %H:%M:%S\ UTC)"
echo "  Account: ${ACCOUNT_ID}"
echo "  Region:  ${REGION}"
echo "========================================="
echo ""

echo "--- Network Security ---"
OPEN_SGS=$(aws ec2 describe-security-groups \
  --query "length(SecurityGroups[?IpPermissions[?IpRanges[?CidrIp=='0.0.0.0/0'] && (FromPort!=\`80\` && FromPort!=\`443\`)]])" \
  --output text 2>/dev/null || echo "ERROR")
[[ "${OPEN_SGS}" == "0" ]] && check "No open SGs (non-HTTP)" "PASS" || check "No open SGs (non-HTTP)" "FAIL"

FLOW_LOGS=$(aws ec2 describe-flow-logs --query "length(FlowLogs[?FlowLogStatus=='ACTIVE'])" --output text 2>/dev/null)
[[ "${FLOW_LOGS}" -gt 0 ]] && check "VPC Flow Logs active" "PASS" || check "VPC Flow Logs active" "FAIL"

ENDPOINTS=$(aws ec2 describe-vpc-endpoints --query "length(VpcEndpoints)" --output text 2>/dev/null)
[[ "${ENDPOINTS}" -gt 0 ]] && check "VPC Endpoints exist" "PASS" || check "VPC Endpoints exist" "FAIL"

IMDS_V1=$(aws ec2 describe-instances \
  --query "length(Reservations[].Instances[?MetadataOptions.HttpTokens=='optional'])" \
  --output text 2>/dev/null || echo "0")
[[ "${IMDS_V1}" == "0" ]] && check "IMDSv2 enforced" "PASS" || check "IMDSv2 enforced" "FAIL"

echo ""
echo "--- IAM ---"
ROOT_MFA=$(aws iam get-account-summary --query "SummaryMap.AccountMFAEnabled" --output text 2>/dev/null)
[[ "${ROOT_MFA}" == "1" ]] && check "Root MFA enabled" "PASS" || check "Root MFA enabled" "FAIL"

ANALYZER=$(aws accessanalyzer list-analyzers --query "length(analyzers)" --output text 2>/dev/null)
[[ "${ANALYZER}" -gt 0 ]] && check "Access Analyzer enabled" "PASS" || check "Access Analyzer enabled" "FAIL"

echo ""
echo "--- Encryption ---"
EBS_ENC=$(aws ec2 get-ebs-encryption-by-default --query "EbsEncryptionByDefault" --output text 2>/dev/null)
[[ "${EBS_ENC}" == "True" ]] && check "EBS default encryption" "PASS" || check "EBS default encryption" "FAIL"

UNENCRYPTED_RDS=$(aws rds describe-db-instances \
  --query "length(DBInstances[?StorageEncrypted==\`false\`])" --output text 2>/dev/null || echo "0")
[[ "${UNENCRYPTED_RDS}" == "0" ]] && check "RDS encryption" "PASS" || check "RDS encryption" "FAIL"

echo ""
echo "--- Monitoring ---"
CT_LOGGING=$(aws cloudtrail get-trail-status \
  --name "${ENV}-audit-trail" \
  --query "IsLogging" --output text 2>/dev/null || echo "false")
[[ "${CT_LOGGING}" == "True" ]] && check "CloudTrail active" "PASS" || check "CloudTrail active" "FAIL"

GD_DETECTORS=$(aws guardduty list-detectors --query "length(DetectorIds)" --output text 2>/dev/null)
[[ "${GD_DETECTORS}" -gt 0 ]] && check "GuardDuty enabled" "PASS" || check "GuardDuty enabled" "FAIL"

SH_HUB=$(aws securityhub describe-hub --query "HubArn" --output text 2>/dev/null)
[[ -n "${SH_HUB}" && "${SH_HUB}" != "None" ]] && check "Security Hub enabled" "PASS" || check "Security Hub enabled" "FAIL"

CONFIG_RULES=$(aws configservice describe-config-rules --query "length(ConfigRules)" --output text 2>/dev/null)
[[ "${CONFIG_RULES}" -ge 8 ]] && check "Config rules (>=8)" "PASS" || check "Config rules (>=8)" "FAIL"

CW_ALARMS=$(aws cloudwatch describe-alarms --query "length(MetricAlarms)" --output text 2>/dev/null)
[[ "${CW_ALARMS}" -ge 5 ]] && check "CloudWatch alarms (>=5)" "PASS" || check "CloudWatch alarms (>=5)" "FAIL"

echo ""
echo "========================================="
echo "  PASS: ${PASS}  |  FAIL: ${FAIL}  |  WARN: ${WARN}"
echo "  Score: ${PASS}/$((PASS + FAIL + WARN)) ($((PASS * 100 / (PASS + FAIL + WARN)))%)"
echo "========================================="

if [[ ${FAIL} -gt 0 ]]; then
  echo "  STATUS: FINDINGS — review FAILed checks above"
  exit 1
else
  echo "  STATUS: PASSED — ready for audit"
  exit 0
fi
```

Save as `tools/run-full-validation.sh` and execute:

```bash
bash "${PKG}/tools/run-full-validation.sh" 2>&1 | tee "${REPORT_DIR}/scorecard.txt"
```

---

## Security Validation Checklist

### Network (7 checks)

| # | Check | Command Reference | Pass Criteria |
|---|-------|------------------|---------------|
| 1 | No SGs with 0.0.0.0/0 (except ALB 80/443) | Step 1a | Zero non-HTTP open SGs |
| 2 | VPC Flow Logs active on all VPCs | Step 1b | ACTIVE status per VPC |
| 3 | VPC endpoints for S3 and DynamoDB | Step 1c | Gateway endpoints exist |
| 4 | IMDSv2 enforced (HttpTokens=required) | Step 1d | No instances with optional |
| 5 | No public subnets for non-ALB resources | Step 1e | IGW routes only on ALB subnets |
| 6 | NACLs restrict admin ports | Manual | No 0.0.0.0/0 on 22/3389 |
| 7 | Default SG has zero rules | Manual | No ingress or egress rules |

### IAM (7 checks)

| # | Check | Command Reference | Pass Criteria |
|---|-------|------------------|---------------|
| 8 | Root MFA enabled | Step 2a | AccountMFAEnabled=1 |
| 9 | No wildcard IAM policies | Step 2b | Zero Action=* or Resource=* |
| 10 | No stale credentials (>90 days unused) | Step 2c | All keys active within 90 days |
| 11 | All IAM users have MFA | Step 2c | Zero users with password but no MFA |
| 12 | IRSA configured for EKS | Step 2d | OIDC issuer present |
| 13 | Access Analyzer enabled | Step 2e | At least 1 analyzer active |
| 14 | No root access keys | Step 2c | Root access_key_1_active=false |

### Encryption (6 checks)

| # | Check | Command Reference | Pass Criteria |
|---|-------|------------------|---------------|
| 15 | EBS default encryption ON | Step 3a | EbsEncryptionByDefault=True |
| 16 | All S3 buckets encrypted | Step 3b | SSE configured on every bucket |
| 17 | All RDS instances encrypted | Step 3c | StorageEncrypted=true for all |
| 18 | KMS key rotation enabled | Step 3d | KeyRotationEnabled=True (CMKs) |
| 19 | Secrets in Secrets Manager | Step 3e | Secrets count > 0 |
| 20 | TLS in transit everywhere | Manual | No unencrypted endpoints |

### EKS (5 checks)

| # | Check | Command Reference | Pass Criteria |
|---|-------|------------------|---------------|
| 21 | Private endpoint (or restricted CIDRs) | Step 4a | Public=false or CIDRs != 0.0.0.0/0 |
| 22 | All 5 log types enabled | Step 4b | api, audit, authenticator, controllerManager, scheduler |
| 23 | Envelope encryption configured | Step 4c | encryptionConfig present |
| 24 | ECR scan on push enabled | Step 4d | scanOnPush=true for all repos |
| 25 | Pod Security Standards enforced | Kubescape | PSS baseline or restricted |

### Monitoring (8 checks)

| # | Check | Command Reference | Pass Criteria |
|---|-------|------------------|---------------|
| 26 | CloudTrail active + multi-region | Step 5a | IsLogging=true |
| 27 | GuardDuty enabled | Step 5b | Detector status=ENABLED |
| 28 | Security Hub with standards | Step 5c | CIS + AWS Best Practices enabled |
| 29 | AWS Config rules (>= 8) | Step 5d | 8 managed rules active |
| 30 | CloudWatch alarms (>= 5) | Step 5e | Security metric alarms wired to SNS |
| 31 | SNS topics configured | Manual | critical, security, cost topics with subscribers |
| 32 | CloudTrail log validation | Step 5a | EnableLogFileValidation=true |
| 33 | CloudTrail KMS encrypted | Step 5a | KmsKeyId present |

---

## Expected Outcomes

| Outcome | Target |
|---------|--------|
| All 33 validation checks pass | 100% (0 FAIL) |
| Compliance mapping complete | NIST, CIS, SOC 2, FedRAMP columns populated |
| Automated scorecard generated | `${REPORT_DIR}/scorecard.txt` |
| IaC scan clean | Checkov + TFsec pass on all templates |
| Config rules compliant | 0 non-compliant resources |
| Ready for external audit | All evidence exportable |

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Scorecard shows ERRORs | AWS CLI not configured or insufficient permissions | Verify `aws sts get-caller-identity` works, attach SecurityAudit policy |
| EKS checks fail | kubectl context not set | `aws eks update-kubeconfig --name ${CLUSTER_NAME}` |
| Config rules show NOT_APPLICABLE | Resource type doesn't exist in account | Normal — rule only evaluates applicable resources |
| Security Hub score low after enabling | Standards need 24 hours for initial evaluation | Re-run after 24 hours |
| Checkov false positives on CloudFormation | Inline parameter references | Add skip comments: `# checkov:skip=CKV_AWS_123:Reason` |
| Credential report not generating | Recent request — cooldown period | Wait 4 hours between report generations |
| Kubescape not finding cluster | Wrong context | `kubectl config current-context` to verify |
| IMDSv2 check shows optional | Instance launched before enforcement | `aws ec2 modify-instance-metadata-options --instance-id <id> --http-tokens required` |

---

*Ghost Protocol — Cloud Security Package*
