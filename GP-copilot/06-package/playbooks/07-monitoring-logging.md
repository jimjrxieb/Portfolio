# Playbook 07 — Monitoring and Logging

> Deploy comprehensive AWS monitoring and logging to achieve full visibility across your cloud environment.
>
> **When:** After network, IAM, encryption, and compute are deployed (Playbooks 01-06).
> **Audience:** Platform engineers, security team.
> **Time:** ~45 min (CloudTrail + VPC Flow Logs + CloudWatch + GuardDuty + Security Hub + Config Rules)

---

## Prerequisites

- AWS CLI configured with admin-level access
- An existing S3 bucket for log storage (or create one below)
- SNS topics for alert routing (created in Step 8)
- `$REGION`, `$ACCOUNT_ID`, `$ENV` environment variables set

```bash
export REGION="us-east-1"
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ENV="production"
export LOG_BUCKET="${ENV}-cloudtrail-logs-${ACCOUNT_ID}"
```

---

## Essential Logs — Know What You're Collecting

| Log Source | What It Captures | Storage | Retention |
|-----------|-----------------|---------|-----------|
| **CloudTrail** | Every API call across all AWS services | S3 + CloudWatch Logs | 90 days (CloudWatch), 1 year (S3) |
| **VPC Flow Logs** | Network traffic (source, dest, port, action) | CloudWatch Logs | 90 days |
| **S3 Access Logs** | Object-level reads/writes on sensitive buckets | S3 | 1 year |
| **EKS Control Plane** | API server, authenticator, controller manager | CloudWatch Logs | 90 days |
| **GuardDuty** | Threat detection findings (recon, compromise, exfil) | GuardDuty console + EventBridge | 90 days |
| **AWS Config** | Resource configuration changes over time | S3 + Config console | 7 years (compliance) |

Philosophy: **If you can't see it, you can't protect it.**

---

## Step 1: CloudTrail Setup

CloudTrail is the audit log for everything that happens in your AWS account.

### 1a. Create the S3 bucket for trail logs

```bash
aws s3api create-bucket \
  --bucket "${LOG_BUCKET}" \
  --region "${REGION}" \
  --create-bucket-configuration LocationConstraint="${REGION}"

# Block all public access
aws s3api put-public-access-block \
  --bucket "${LOG_BUCKET}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Enable default encryption
aws s3api put-bucket-encryption \
  --bucket "${LOG_BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "aws:kms"}}]
  }'

# Bucket policy allowing CloudTrail to write
aws s3api put-bucket-policy \
  --bucket "${LOG_BUCKET}" \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AWSCloudTrailAclCheck",
        "Effect": "Allow",
        "Principal": {"Service": "cloudtrail.amazonaws.com"},
        "Action": "s3:GetBucketAcl",
        "Resource": "arn:aws:s3:::'"${LOG_BUCKET}"'"
      },
      {
        "Sid": "AWSCloudTrailWrite",
        "Effect": "Allow",
        "Principal": {"Service": "cloudtrail.amazonaws.com"},
        "Action": "s3:PutObject",
        "Resource": "arn:aws:s3:::'"${LOG_BUCKET}"'/AWSLogs/'"${ACCOUNT_ID}"'/*",
        "Condition": {"StringEquals": {"s3:x-amz-acl": "bucket-owner-full-control"}}
      }
    ]
  }'
```

### 1b. Create the trail

```bash
aws cloudtrail create-trail \
  --name "${ENV}-audit-trail" \
  --s3-bucket-name "${LOG_BUCKET}" \
  --is-multi-region-trail \
  --enable-log-file-validation \
  --kms-key-id "alias/${ENV}-cloudtrail-key" \
  --include-global-service-events

# Start logging
aws cloudtrail start-logging --name "${ENV}-audit-trail"
```

### 1c. Add event selectors for data events

```bash
aws cloudtrail put-event-selectors \
  --trail-name "${ENV}-audit-trail" \
  --advanced-event-selectors '[
    {
      "Name": "Management events",
      "FieldSelectors": [
        {"Field": "eventCategory", "Equals": ["Management"]}
      ]
    },
    {
      "Name": "S3 data events",
      "FieldSelectors": [
        {"Field": "eventCategory", "Equals": ["Data"]},
        {"Field": "resources.type", "Equals": ["AWS::S3::Object"]}
      ]
    },
    {
      "Name": "Lambda data events",
      "FieldSelectors": [
        {"Field": "eventCategory", "Equals": ["Data"]},
        {"Field": "resources.type", "Equals": ["AWS::Lambda::Function"]}
      ]
    }
  ]'
```

### 1d. Verify

```bash
aws cloudtrail get-trail-status --name "${ENV}-audit-trail"
# Expect: "IsLogging": true, "LatestDeliveryTime" within last 15 min
```

---

## Step 2: VPC Flow Logs

Enable on the VPC (not individual subnets) to capture all traffic.

### 2a. Create IAM role for flow logs

```bash
# Create the trust policy
cat > /tmp/flow-logs-trust.json << 'POLICY'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "vpc-flow-logs.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
POLICY

aws iam create-role \
  --role-name VPCFlowLogsRole \
  --assume-role-policy-document file:///tmp/flow-logs-trust.json

aws iam put-role-policy \
  --role-name VPCFlowLogsRole \
  --policy-name VPCFlowLogsPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    }]
  }'
```

### 2b. Create the log group

```bash
aws logs create-log-group \
  --log-group-name "/aws/vpc/flow-logs/${ENV}" \
  --retention-in-days 90
```

### 2c. Enable flow logs on the VPC

```bash
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Environment,Values=${ENV}" \
  --query "Vpcs[0].VpcId" --output text)

aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids "${VPC_ID}" \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name "/aws/vpc/flow-logs/${ENV}" \
  --deliver-logs-permission-arn "arn:aws:iam::${ACCOUNT_ID}:role/VPCFlowLogsRole" \
  --log-format '${version} ${account-id} ${interface-id} ${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol} ${packets} ${bytes} ${start} ${end} ${action} ${log-status} ${vpc-id} ${subnet-id} ${az-id} ${sublocation-type} ${sublocation-id} ${pkt-srcaddr} ${pkt-dstaddr} ${region} ${pkt-src-aws-service} ${pkt-dst-aws-service} ${flow-direction} ${traffic-path}'
```

### 2d. Verify

```bash
aws ec2 describe-flow-logs \
  --filter "Name=resource-id,Values=${VPC_ID}" \
  --query "FlowLogs[].{ID:FlowLogId,Status:FlowLogStatus,Traffic:TrafficType}"
# Expect: Status=ACTIVE, Traffic=ALL
```

---

## Step 3: CloudWatch Metric Filters and Alarms

Create metric filters on the CloudTrail log group to detect critical events. Each filter feeds a CloudWatch alarm that fires to SNS.

### 3a. Create the SNS topic for security alerts

```bash
SECURITY_TOPIC_ARN=$(aws sns create-topic --name "${ENV}-security-alerts" --query TopicArn --output text)
aws sns subscribe \
  --topic-arn "${SECURITY_TOPIC_ARN}" \
  --protocol email \
  --notification-endpoint security-team@example.com
```

### 3b. Send CloudTrail logs to CloudWatch

```bash
# Create log group for CloudTrail
aws logs create-log-group \
  --log-group-name "/aws/cloudtrail/${ENV}" \
  --retention-in-days 90

# Update trail to deliver to CloudWatch
aws cloudtrail update-trail \
  --name "${ENV}-audit-trail" \
  --cloud-watch-logs-log-group-arn "arn:aws:logs:${REGION}:${ACCOUNT_ID}:log-group:/aws/cloudtrail/${ENV}:*" \
  --cloud-watch-logs-role-arn "arn:aws:iam::${ACCOUNT_ID}:role/CloudTrailToCloudWatchRole"
```

### 3c. Filter 1 — Unauthorized API Calls

```bash
aws logs put-metric-filter \
  --log-group-name "/aws/cloudtrail/${ENV}" \
  --filter-name "UnauthorizedAPICalls" \
  --filter-pattern '{ ($.errorCode = "*UnauthorizedAccess") || ($.errorCode = "AccessDenied*") }' \
  --metric-transformations \
    metricName=UnauthorizedAPICallCount,metricNamespace=SecurityMetrics,metricValue=1

aws cloudwatch put-metric-alarm \
  --alarm-name "${ENV}-unauthorized-api-calls" \
  --alarm-description "Alert on unauthorized API calls (potential credential abuse)" \
  --metric-name UnauthorizedAPICallCount \
  --namespace SecurityMetrics \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions "${SECURITY_TOPIC_ARN}"
```

### 3d. Filter 2 — Console Login Without MFA

```bash
aws logs put-metric-filter \
  --log-group-name "/aws/cloudtrail/${ENV}" \
  --filter-name "ConsoleLoginNoMFA" \
  --filter-pattern '{ ($.eventName = "ConsoleLogin") && ($.additionalEventData.MFAUsed != "Yes") }' \
  --metric-transformations \
    metricName=ConsoleLoginNoMFACount,metricNamespace=SecurityMetrics,metricValue=1

aws cloudwatch put-metric-alarm \
  --alarm-name "${ENV}-console-login-no-mfa" \
  --alarm-description "Console login without MFA detected" \
  --metric-name ConsoleLoginNoMFACount \
  --namespace SecurityMetrics \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions "${SECURITY_TOPIC_ARN}"
```

### 3e. Filter 3 — Root Account Usage

```bash
aws logs put-metric-filter \
  --log-group-name "/aws/cloudtrail/${ENV}" \
  --filter-name "RootAccountUsage" \
  --filter-pattern '{ $.userIdentity.type = "Root" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != "AwsServiceEvent" }' \
  --metric-transformations \
    metricName=RootAccountUsageCount,metricNamespace=SecurityMetrics,metricValue=1

aws cloudwatch put-metric-alarm \
  --alarm-name "${ENV}-root-account-usage" \
  --alarm-description "Root account used — investigate immediately" \
  --metric-name RootAccountUsageCount \
  --namespace SecurityMetrics \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions "${SECURITY_TOPIC_ARN}"
```

### 3f. Filter 4 — IAM Policy Changes

```bash
aws logs put-metric-filter \
  --log-group-name "/aws/cloudtrail/${ENV}" \
  --filter-name "IAMPolicyChanges" \
  --filter-pattern '{ ($.eventName=DeleteGroupPolicy) || ($.eventName=DeleteRolePolicy) || ($.eventName=DeleteUserPolicy) || ($.eventName=PutGroupPolicy) || ($.eventName=PutRolePolicy) || ($.eventName=PutUserPolicy) || ($.eventName=CreatePolicy) || ($.eventName=DeletePolicy) || ($.eventName=AttachRolePolicy) || ($.eventName=DetachRolePolicy) || ($.eventName=AttachUserPolicy) || ($.eventName=DetachUserPolicy) || ($.eventName=AttachGroupPolicy) || ($.eventName=DetachGroupPolicy) }' \
  --metric-transformations \
    metricName=IAMPolicyChangeCount,metricNamespace=SecurityMetrics,metricValue=1

aws cloudwatch put-metric-alarm \
  --alarm-name "${ENV}-iam-policy-changes" \
  --alarm-description "IAM policy modification detected" \
  --metric-name IAMPolicyChangeCount \
  --namespace SecurityMetrics \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions "${SECURITY_TOPIC_ARN}"
```

### 3g. Filter 5 — Security Group Changes

```bash
aws logs put-metric-filter \
  --log-group-name "/aws/cloudtrail/${ENV}" \
  --filter-name "SecurityGroupChanges" \
  --filter-pattern '{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }' \
  --metric-transformations \
    metricName=SecurityGroupChangeCount,metricNamespace=SecurityMetrics,metricValue=1

aws cloudwatch put-metric-alarm \
  --alarm-name "${ENV}-security-group-changes" \
  --alarm-description "Security group modification detected" \
  --metric-name SecurityGroupChangeCount \
  --namespace SecurityMetrics \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions "${SECURITY_TOPIC_ARN}"
```

---

## Step 4: GuardDuty

Threat detection that analyzes CloudTrail, VPC Flow Logs, and DNS logs automatically.

### 4a. Enable GuardDuty

```bash
DETECTOR_ID=$(aws guardduty create-detector \
  --enable \
  --finding-publishing-frequency FIFTEEN_MINUTES \
  --query DetectorId --output text)

echo "GuardDuty detector: ${DETECTOR_ID}"
```

### 4b. Check for findings

```bash
# List all findings
aws guardduty list-findings \
  --detector-id "${DETECTOR_ID}" \
  --finding-criteria '{
    "Criterion": {
      "severity": {"Gte": 4}
    }
  }' \
  --query "FindingIds"

# Get finding details (replace FINDING_ID)
# aws guardduty get-findings \
#   --detector-id "${DETECTOR_ID}" \
#   --finding-ids "FINDING_ID" \
#   --query "Findings[].{Type:Type,Severity:Severity,Title:Title}"
```

### GuardDuty severity reference

| Severity Range | Label | Action Required |
|---------------|-------|-----------------|
| 7.0 - 8.9 | **High** | Investigate immediately. Page on-call. |
| 4.0 - 6.9 | **Medium** | Investigate within 24 hours. |
| 1.0 - 3.9 | **Low** | Review during next triage cycle. |

---

## Step 5: Security Hub

Aggregates findings from GuardDuty, Config, Inspector, and third-party tools into one pane.

### 5a. Enable Security Hub with standards

```bash
aws securityhub enable-security-hub \
  --enable-default-standards

# Enable CIS AWS Foundations Benchmark
aws securityhub batch-enable-standards \
  --standards-subscription-requests \
    StandardsArn="arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.4.0"

# Enable AWS Foundational Security Best Practices
aws securityhub batch-enable-standards \
  --standards-subscription-requests \
    StandardsArn="arn:aws:securityhub:${REGION}::standards/aws-foundational-security-best-practices/v/1.0.0"
```

### 5b. Get critical findings

```bash
aws securityhub get-findings \
  --filters '{
    "SeverityLabel": [{"Value": "CRITICAL", "Comparison": "EQUALS"}],
    "WorkflowStatus": [{"Value": "NEW", "Comparison": "EQUALS"}]
  }' \
  --query "Findings[].{Title:Title,Resource:Resources[0].Id,Severity:Severity.Label}" \
  --output table
```

### 5c. Get compliance score

```bash
aws securityhub get-enabled-standards \
  --query "StandardsSubscriptions[].{Standard:StandardsArn,Status:StandardsStatus}"
```

---

## Step 6: AWS Config Rules

Continuous compliance monitoring. Deploy 8 managed rules covering the critical baselines.

```bash
# 1. S3 public read prohibited
aws configservice put-config-rule --config-rule '{
  "ConfigRuleName": "s3-bucket-public-read-prohibited",
  "Source": {"Owner": "AWS", "SourceIdentifier": "S3_BUCKET_PUBLIC_READ_PROHIBITED"}
}'

# 2. Encrypted EBS volumes
aws configservice put-config-rule --config-rule '{
  "ConfigRuleName": "encrypted-volumes",
  "Source": {"Owner": "AWS", "SourceIdentifier": "ENCRYPTED_VOLUMES"}
}'

# 3. Root account MFA
aws configservice put-config-rule --config-rule '{
  "ConfigRuleName": "root-account-mfa-enabled",
  "Source": {"Owner": "AWS", "SourceIdentifier": "ROOT_ACCOUNT_MFA_ENABLED"}
}'

# 4. IAM user MFA
aws configservice put-config-rule --config-rule '{
  "ConfigRuleName": "iam-user-mfa-enabled",
  "Source": {"Owner": "AWS", "SourceIdentifier": "IAM_USER_MFA_ENABLED"}
}'

# 5. Restricted SSH
aws configservice put-config-rule --config-rule '{
  "ConfigRuleName": "restricted-ssh",
  "Source": {"Owner": "AWS", "SourceIdentifier": "INCOMING_SSH_DISABLED"}
}'

# 6. VPC flow logs enabled
aws configservice put-config-rule --config-rule '{
  "ConfigRuleName": "vpc-flow-logs-enabled",
  "Source": {"Owner": "AWS", "SourceIdentifier": "VPC_FLOW_LOGS_ENABLED"}
}'

# 7. CloudTrail enabled
aws configservice put-config-rule --config-rule '{
  "ConfigRuleName": "cloud-trail-enabled",
  "Source": {"Owner": "AWS", "SourceIdentifier": "CLOUD_TRAIL_ENABLED"}
}'

# 8. RDS storage encrypted
aws configservice put-config-rule --config-rule '{
  "ConfigRuleName": "rds-storage-encrypted",
  "Source": {"Owner": "AWS", "SourceIdentifier": "RDS_STORAGE_ENCRYPTED"}
}'
```

### Verify compliance status

```bash
aws configservice get-compliance-summary-by-config-rule \
  --query "ComplianceSummary"

# Check individual rule compliance
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name "s3-bucket-public-read-prohibited" \
  --compliance-types NON_COMPLIANT \
  --query "EvaluationResults[].{Resource:EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId,Status:ComplianceType}"
```

---

## Step 7: CloudWatch Dashboards

Reference: `monitoring/README.md` has 4 dashboard template definitions.

| Dashboard | Template | Metrics |
|-----------|----------|---------|
| Infrastructure Health | `infrastructure-health.json` | VPC, EC2, RDS, S3, ALB health |
| Cost Tracking | `cost-tracking.json` | Spend by service, trending, budget |
| Security & Compliance | `security-compliance.json` | CloudTrail, GuardDuty, Config, Security Hub |
| Migration Progress | `migration-progress.json` | Replication lag, cutover status, sync |

```bash
PKG=~/linkops-industries/GP-copilot/GP-CONSULTING/06-CLOUD-SECURITY

# Import dashboards (if template files exist)
for DASHBOARD in infrastructure-health cost-tracking security-compliance migration-progress; do
  if [[ -f "${PKG}/monitoring/${DASHBOARD}.json" ]]; then
    aws cloudwatch put-dashboard \
      --dashboard-name "${ENV}-${DASHBOARD}" \
      --dashboard-body "file://${PKG}/monitoring/${DASHBOARD}.json"
    echo "Deployed: ${ENV}-${DASHBOARD}"
  else
    echo "SKIP: ${PKG}/monitoring/${DASHBOARD}.json not found"
  fi
done
```

---

## Step 8: SNS Alert Routing

### Create topics

```bash
CRITICAL_ARN=$(aws sns create-topic --name "${ENV}-critical-alerts" --query TopicArn --output text)
SECURITY_ARN=$(aws sns create-topic --name "${ENV}-security-alerts" --query TopicArn --output text)
COST_ARN=$(aws sns create-topic --name "${ENV}-cost-alerts" --query TopicArn --output text)

echo "Critical: ${CRITICAL_ARN}"
echo "Security: ${SECURITY_ARN}"
echo "Cost:     ${COST_ARN}"
```

### Subscribe team

```bash
# Security team — all security alerts
aws sns subscribe --topic-arn "${SECURITY_ARN}" --protocol email --notification-endpoint security@example.com

# Ops team — critical infrastructure
aws sns subscribe --topic-arn "${CRITICAL_ARN}" --protocol email --notification-endpoint ops@example.com

# Finance — cost alerts
aws sns subscribe --topic-arn "${COST_ARN}" --protocol email --notification-endpoint finance@example.com

# Slack integration (via AWS Chatbot or Lambda)
# aws sns subscribe --topic-arn "${SECURITY_ARN}" --protocol https --notification-endpoint https://hooks.slack.com/...
```

### Alert routing matrix

| Alert Type | SNS Topic | Recipients | SLA |
|-----------|-----------|------------|-----|
| Root account usage | `critical-alerts` | Security + Ops on-call | 15 min |
| GuardDuty High | `security-alerts` | Security team | 1 hour |
| Unauthorized API calls (>5) | `security-alerts` | Security team | 4 hours |
| IAM policy changes | `security-alerts` | Security team | 24 hours |
| Security group changes | `security-alerts` | Security team | 24 hours |
| Console login without MFA | `security-alerts` | Security team | 24 hours |
| Daily spend > budget | `cost-alerts` | Finance + Ops lead | 24 hours |

---

## Investigating Suspicious Activity

When an alarm fires, use these queries to investigate.

### Console logins

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --start-time "$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --query "Events[].{Time:EventTime,User:Username,Source:CloudTrailEvent}" \
  --output table
```

### IAM changes

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=iam.amazonaws.com \
  --start-time "$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --query "Events[].{Time:EventTime,Event:EventName,User:Username}"
```

### Failed API calls

```bash
# Use CloudWatch Logs Insights
aws logs start-query \
  --log-group-name "/aws/cloudtrail/${ENV}" \
  --start-time "$(date -u -d '24 hours ago' +%s)" \
  --end-time "$(date -u +%s)" \
  --query-string 'fields @timestamp, userIdentity.arn, eventName, errorCode, sourceIPAddress
    | filter ispresent(errorCode)
    | sort @timestamp desc
    | limit 50'
```

### Root account usage

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --start-time "$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --query "Events[?contains(CloudTrailEvent, '\"Root\"')].{Time:EventTime,Event:EventName}"
```

### VPC Flow Logs — rejected traffic

```bash
aws logs start-query \
  --log-group-name "/aws/vpc/flow-logs/${ENV}" \
  --start-time "$(date -u -d '1 hour ago' +%s)" \
  --end-time "$(date -u +%s)" \
  --query-string 'fields @timestamp, srcAddr, dstAddr, dstPort, action
    | filter action = "REJECT"
    | stats count() by dstPort
    | sort count desc
    | limit 20'
```

---

## Expected Outcomes

| Component | Expected State |
|-----------|---------------|
| CloudTrail | Multi-region, log validation enabled, KMS encrypted, data events on |
| VPC Flow Logs | Active on VPC (not subnets), ALL traffic, 90-day retention |
| Metric Filters | 5 filters active: unauth API, no-MFA login, root usage, IAM changes, SG changes |
| CloudWatch Alarms | 5 alarms in OK state, wired to SNS topics |
| GuardDuty | Detector active, 15-min publishing |
| Security Hub | Enabled with CIS + AWS Best Practices standards |
| AWS Config | 8 managed rules evaluating continuously |
| SNS | 3 topics (critical, security, cost) with subscriptions confirmed |

---

## Logging Checklist

| # | Item | Verified |
|---|------|----------|
| 1 | CloudTrail enabled, multi-region, log validation ON | [ ] |
| 2 | CloudTrail logs encrypted with KMS | [ ] |
| 3 | VPC Flow Logs enabled on ALL VPCs (not just subnets) | [ ] |
| 4 | CloudWatch metric filters for 5 critical events | [ ] |
| 5 | GuardDuty enabled and publishing findings | [ ] |
| 6 | Security Hub enabled with compliance standards | [ ] |
| 7 | AWS Config rules deployed and evaluating | [ ] |

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| CloudTrail not logging | Trail not started | `aws cloudtrail start-logging --name <trail>` |
| Flow logs status FAILED | IAM role missing permissions | Check trust policy allows `vpc-flow-logs.amazonaws.com` |
| Metric filter not triggering | Log group ARN mismatch | Verify trail delivers to the correct CloudWatch log group |
| GuardDuty no findings | Normal — no threats detected yet | Generate sample findings: `aws guardduty create-sample-findings --detector-id <id>` |
| Config rule NON_COMPLIANT | Resource violates rule | Good — that's what it's supposed to detect. Remediate the resource. |
| SNS email not received | Subscription not confirmed | Check inbox for confirmation email, including spam folder |
| Security Hub no score yet | Standards still initializing | Wait 24 hours after enabling for initial evaluation |

---

*Ghost Protocol — Cloud Security Package*
