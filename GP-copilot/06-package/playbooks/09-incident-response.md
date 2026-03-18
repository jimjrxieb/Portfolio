# Playbook 09 — Incident Response

> Contain, investigate, eradicate, recover, and learn from AWS security incidents.
>
> **When:** A security event is detected — GuardDuty alert, CloudTrail anomaly, or manual report.
> **Audience:** Security team, on-call engineers, incident commanders.
> **Time:** Varies by incident (15 min containment target, hours for full IR cycle)

---

## IR Order

**Contain** the blast radius. **Investigate** what happened. **Eradicate** the threat. **Recover** to known-good state. **Learn** so it never happens again.

Never skip steps. Never eradicate before you preserve evidence.

---

## Prerequisites

- AWS CLI configured with admin access
- `$REGION`, `$ACCOUNT_ID` environment variables set
- CloudTrail logging active (Playbook 07)
- GuardDuty enabled
- SNS topics configured for alerting
- Know your escalation contacts

```bash
export REGION="us-east-1"
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export INCIDENT_ID="IR-$(date +%Y%m%d-%H%M%S)"
echo "Incident ID: ${INCIDENT_ID}"
```

---

## Step 1: Compromised IAM Credentials

**Trigger:** GuardDuty `UnauthorizedAccess:IAMUser/MaliciousIPCaller`, leaked key in git, unusual API activity.

### 1a. Contain — Disable the key immediately

```bash
COMPROMISED_KEY="AKIA..."  # The access key ID

# Disable the key (don't delete yet — you need it for investigation)
aws iam update-access-key \
  --user-name <USERNAME> \
  --access-key-id "${COMPROMISED_KEY}" \
  --status Inactive

# Apply deny-all inline policy to block ALL actions
aws iam put-user-policy \
  --user-name <USERNAME> \
  --policy-name "INCIDENT-DENY-ALL-${INCIDENT_ID}" \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*"
    }]
  }'

echo "CONTAINED: Key ${COMPROMISED_KEY} disabled, deny-all applied"
```

### 1b. Investigate — What did the attacker do?

```bash
# Find all API calls made with this key
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=AccessKeyId,AttributeValue="${COMPROMISED_KEY}" \
  --start-time "$(date -u -d '90 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --query "Events[].{Time:EventTime,Event:EventName,Source:EventSource,IP:CloudTrailEvent}" \
  --output json > "/tmp/${INCIDENT_ID}-cloudtrail.json"

echo "Events logged to /tmp/${INCIDENT_ID}-cloudtrail.json"

# Check for resource creation (attacker persistence)
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=AccessKeyId,AttributeValue="${COMPROMISED_KEY}" \
  --start-time "$(date -u -d '90 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --query "Events[?contains(EventName, 'Create')].{Time:EventTime,Event:EventName}" \
  --output table

# Check for new access keys (lateral movement)
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=AccessKeyId,AttributeValue="${COMPROMISED_KEY}" \
  --query "Events[?EventName=='CreateAccessKey'].{Time:EventTime,Event:EventName}" \
  --output table
```

### 1c. Eradicate

```bash
# Delete the compromised key
aws iam delete-access-key \
  --user-name <USERNAME> \
  --access-key-id "${COMPROMISED_KEY}"

# Remove the deny-all policy
aws iam delete-user-policy \
  --user-name <USERNAME> \
  --policy-name "INCIDENT-DENY-ALL-${INCIDENT_ID}"

# Delete any resources the attacker created (EC2 instances, IAM users, etc.)
# Review /tmp/${INCIDENT_ID}-cloudtrail.json for Create* events
```

### 1d. Recover

```bash
# Create new credentials with tighter permissions (least privilege)
aws iam create-access-key --user-name <USERNAME>
# Distribute new key via Secrets Manager — never email/Slack
```

### 1e. Learn

- How was the key exposed? (Git commit, env var in CI, shared in chat?)
- Add Gitleaks pre-commit hook: `01-APP-SEC/scanning-configs/`
- Rotate all keys for this user
- Enable MFA on the IAM user if not already set
- Consider switching to IAM Identity Center (SSO) with temporary credentials

---

## Step 2: Public S3 Bucket

**Trigger:** GuardDuty `Policy:S3/BucketAnonymousAccessGranted`, Shodan alert, AWS Config `s3-bucket-public-read-prohibited` non-compliant.

### 2a. Contain — Block public access immediately

```bash
BUCKET_NAME="the-exposed-bucket"

# Block ALL public access — all 4 settings
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "CONTAINED: Public access blocked on ${BUCKET_NAME}"
```

### 2b. Investigate

```bash
# Check the bucket ACL
aws s3api get-bucket-acl --bucket "${BUCKET_NAME}"

# Check bucket policy
aws s3api get-bucket-policy --bucket "${BUCKET_NAME}" 2>/dev/null || echo "No bucket policy"

# Check access logging
aws s3api get-bucket-logging --bucket "${BUCKET_NAME}"

# Classify data sensitivity — what's in the bucket?
aws s3 ls "s3://${BUCKET_NAME}/" --recursive --human-readable | head -50

# Check S3 access logs for external access (if logging was enabled)
# Look for requests from IPs outside your CIDR
```

### 2c. Eradicate

```bash
# Remove any public ACL grants
aws s3api put-bucket-acl --bucket "${BUCKET_NAME}" --acl private

# Delete public bucket policy if one exists
aws s3api delete-bucket-policy --bucket "${BUCKET_NAME}"
```

### 2d. Verify

```bash
# Confirm all 4 public access blocks are true
aws s3api get-public-access-block --bucket "${BUCKET_NAME}" \
  --query "PublicAccessBlockConfiguration"
# Expect: all four values = true
```

### 2e. Learn

- Enable account-level S3 public access block (prevents future buckets from being public):
  ```bash
  aws s3control put-public-access-block \
    --account-id "${ACCOUNT_ID}" \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  ```
- Enable S3 access logging on all sensitive buckets
- Add AWS Config rule: `s3-bucket-public-read-prohibited`
- If data was PII/PHI, initiate breach notification process

---

## Step 3: Suspicious EC2 Instance

**Trigger:** GuardDuty `CryptoCurrency:EC2/BitcoinTool.B!DNS`, high outbound traffic, unknown processes.

### 3a. Contain — Quarantine with security group

```bash
INSTANCE_ID="i-0abc123..."
VPC_ID=$(aws ec2 describe-instances \
  --instance-ids "${INSTANCE_ID}" \
  --query "Reservations[0].Instances[0].VpcId" --output text)

# Create quarantine security group (no ingress, no egress)
QUARANTINE_SG=$(aws ec2 create-security-group \
  --group-name "quarantine-${INCIDENT_ID}" \
  --description "Incident quarantine - no traffic allowed" \
  --vpc-id "${VPC_ID}" \
  --query GroupId --output text)

# Remove the default egress rule
aws ec2 revoke-security-group-egress \
  --group-id "${QUARANTINE_SG}" \
  --ip-permissions '[{"IpProtocol": "-1", "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}]'

# Apply quarantine SG (replaces all existing SGs)
aws ec2 modify-instance-attribute \
  --instance-id "${INSTANCE_ID}" \
  --groups "${QUARANTINE_SG}"

echo "CONTAINED: Instance ${INSTANCE_ID} quarantined with SG ${QUARANTINE_SG}"
```

### 3b. Preserve evidence — BEFORE doing anything destructive

```bash
# Snapshot ALL volumes attached to the instance
VOLUME_IDS=$(aws ec2 describe-instances \
  --instance-ids "${INSTANCE_ID}" \
  --query "Reservations[0].Instances[0].BlockDeviceMappings[].Ebs.VolumeId" \
  --output text)

for VOL in ${VOLUME_IDS}; do
  SNAP_ID=$(aws ec2 create-snapshot \
    --volume-id "${VOL}" \
    --description "Forensic snapshot - ${INCIDENT_ID} - ${VOL}" \
    --tag-specifications "ResourceType=snapshot,Tags=[{Key=IncidentId,Value=${INCIDENT_ID}},{Key=Purpose,Value=forensics}]" \
    --query SnapshotId --output text)
  echo "Snapshot created: ${SNAP_ID} for volume ${VOL}"
done

# Get instance details for the record
aws ec2 describe-instances \
  --instance-ids "${INSTANCE_ID}" \
  --output json > "/tmp/${INCIDENT_ID}-instance-details.json"

# Get console output (may reveal boot-time malware)
aws ec2 get-console-output \
  --instance-id "${INSTANCE_ID}" \
  --output text > "/tmp/${INCIDENT_ID}-console-output.txt"
```

### 3c. Investigate

```bash
# CloudTrail — who launched this instance?
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="${INSTANCE_ID}" \
  --query "Events[].{Time:EventTime,Event:EventName,User:Username}" \
  --output table

# VPC Flow Logs — where was it talking to?
aws logs start-query \
  --log-group-name "/aws/vpc/flow-logs/${ENV}" \
  --start-time "$(date -u -d '7 days ago' +%s)" \
  --end-time "$(date -u +%s)" \
  --query-string "fields @timestamp, srcAddr, dstAddr, dstPort, bytes
    | filter srcAddr like '${INSTANCE_PRIVATE_IP}'
    | sort bytes desc
    | limit 50"

# GuardDuty findings for this instance
aws guardduty list-findings \
  --detector-id "${DETECTOR_ID}" \
  --finding-criteria '{
    "Criterion": {
      "resource.instanceDetails.instanceId": {"Eq": ["'"${INSTANCE_ID}"'"]}
    }
  }'
```

### 3d. Eradicate

```bash
# If confirmed malicious — stop the instance (do NOT terminate, keep for forensics)
aws ec2 stop-instances --instance-ids "${INSTANCE_ID}"

# After forensic analysis is complete, terminate
# aws ec2 terminate-instances --instance-ids "${INSTANCE_ID}"
```

### 3e. Recover

```bash
# Launch clean replacement from known-good AMI
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --instance-type t3.medium \
  --key-name production-key \
  --security-group-ids sg-0abc123 \
  --subnet-id subnet-0abc123 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=replacement-web-server}]'
```

---

## Step 4: Unauthorized IAM Role Creation

**Trigger:** CloudWatch alarm on IAM changes, unexpected role in `aws iam list-roles`.

### 4a. Contain

```bash
ROGUE_ROLE="suspicious-role-name"

# Apply deny-all policy to the role
aws iam put-role-policy \
  --role-name "${ROGUE_ROLE}" \
  --policy-name "INCIDENT-DENY-ALL-${INCIDENT_ID}" \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*"
    }]
  }'

echo "CONTAINED: Deny-all applied to role ${ROGUE_ROLE}"
```

### 4b. Investigate

```bash
# Who created this role?
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreateRole \
  --start-time "$(date -u -d '90 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --query "Events[?contains(CloudTrailEvent, '${ROGUE_ROLE}')].{Time:EventTime,User:Username,IP:CloudTrailEvent}" \
  --output json > "/tmp/${INCIDENT_ID}-role-creation.json"

# What policies are attached?
aws iam list-attached-role-policies --role-name "${ROGUE_ROLE}"
aws iam list-role-policies --role-name "${ROGUE_ROLE}"

# Was the role assumed by anyone?
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRole \
  --start-time "$(date -u -d '90 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --query "Events[?contains(CloudTrailEvent, '${ROGUE_ROLE}')].{Time:EventTime,User:Username}"

# Check trust policy — who CAN assume it?
aws iam get-role --role-name "${ROGUE_ROLE}" --query "Role.AssumeRolePolicyDocument"
```

### 4c. Eradicate

```bash
# Detach all managed policies
for POLICY_ARN in $(aws iam list-attached-role-policies \
  --role-name "${ROGUE_ROLE}" \
  --query "AttachedPolicies[].PolicyArn" --output text); do
  aws iam detach-role-policy --role-name "${ROGUE_ROLE}" --policy-arn "${POLICY_ARN}"
done

# Delete all inline policies
for POLICY_NAME in $(aws iam list-role-policies \
  --role-name "${ROGUE_ROLE}" \
  --query "PolicyNames[]" --output text); do
  aws iam delete-role-policy --role-name "${ROGUE_ROLE}" --policy-name "${POLICY_NAME}"
done

# Delete instance profiles if any
for PROFILE in $(aws iam list-instance-profiles-for-role \
  --role-name "${ROGUE_ROLE}" \
  --query "InstanceProfiles[].InstanceProfileName" --output text); do
  aws iam remove-role-from-instance-profile \
    --instance-profile-name "${PROFILE}" --role-name "${ROGUE_ROLE}"
done

# Delete the role
aws iam delete-role --role-name "${ROGUE_ROLE}"
echo "ERADICATED: Role ${ROGUE_ROLE} deleted"
```

---

## Quick Reference — Incident Scenarios

| Signal | Likely Incident | First Action |
|--------|----------------|-------------|
| Unusual API calls from unknown IP | Compromised credentials | `aws iam update-access-key --status Inactive` |
| S3 bucket appears on Shodan | Public bucket exposure | `aws s3api put-public-access-block` (all 4 true) |
| High outbound traffic from EC2 | Cryptominer or C2 beacon | Quarantine SG (no ingress/egress) |
| New IAM role you didn't create | Attacker persistence | Deny-all policy on role + investigate creator |
| GuardDuty High severity finding | Varies by finding type | Triage per finding — see GuardDuty docs |
| Console login from unusual geo | Credential theft | Disable user + force MFA reset |
| Spike in failed API calls | Brute force or recon | Check source IPs, consider WAF/NACLs |
| Lambda running unknown code | Supply chain compromise | Disable trigger, check deployment history |
| RDS accessible from internet | Misconfigured SG | Move to private subnet, restrict SG |
| KMS key deletion scheduled | Destructive action | Cancel deletion: `aws kms cancel-key-deletion` |
| CloudTrail logging stopped | Cover tracks attempt | Re-enable immediately, investigate who stopped it |

---

## Evidence Preservation

**Rule: NEVER terminate or delete before preserving evidence.**

| Evidence Type | How to Preserve | Retention |
|--------------|-----------------|-----------|
| EC2 disk | `aws ec2 create-snapshot` on all volumes | Until investigation closed |
| CloudTrail logs | Export to dedicated S3 bucket with object lock | 1 year minimum |
| VPC Flow Logs | Export CloudWatch log group to S3 | 1 year minimum |
| Instance metadata | `aws ec2 describe-instances` → JSON file | Permanent |
| Console output | `aws ec2 get-console-output` → text file | Permanent |
| Memory dump | SSM `RunCommand` with LiME before stopping instance | Until analysis complete |
| IAM policies | `aws iam get-policy-version` for all attached policies | Permanent |

### Export CloudTrail to evidence bucket

```bash
EVIDENCE_BUCKET="${ENV}-incident-evidence-${ACCOUNT_ID}"

aws s3api create-bucket \
  --bucket "${EVIDENCE_BUCKET}" \
  --region "${REGION}" \
  --object-lock-enabled-for-bucket

aws s3api put-object-lock-configuration \
  --bucket "${EVIDENCE_BUCKET}" \
  --object-lock-configuration '{
    "ObjectLockEnabled": "Enabled",
    "Rule": {"DefaultRetention": {"Mode": "COMPLIANCE", "Days": 365}}
  }'

# Copy CloudTrail logs for the incident period
aws s3 sync \
  "s3://${LOG_BUCKET}/AWSLogs/${ACCOUNT_ID}/CloudTrail/${REGION}/" \
  "s3://${EVIDENCE_BUCKET}/${INCIDENT_ID}/cloudtrail/" \
  --exclude "*" \
  --include "$(date -u -d '7 days ago' +%Y/%m/%d)/*" \
  --include "$(date -u +%Y/%m/%d)/*"
```

---

## Escalation Matrix

| Severity | Who to Notify | Timeline | Channel |
|----------|--------------|----------|---------|
| **Critical** — Active breach, data exfiltration | CISO, Legal, Ops lead, on-call | Immediately | Phone + Slack `#incident` |
| **High** — Compromised credentials, public exposure | Security lead, Ops lead | Within 1 hour | Slack `#incident` |
| **Medium** — Policy violation, misconfiguration | Security team | Within 4 hours | Slack `#security-alerts` |
| **Low** — Failed brute force, blocked scan | Security team | Next business day | Email |

If PII/PHI was exposed: notify Legal within 1 hour for breach notification assessment.

---

## Post-Incident Review

Run a blameless review within 48 hours. Use this template:

### Review Template

```
Incident ID:     IR-YYYYMMDD-HHMMSS
Date:            YYYY-MM-DD
Duration:        X hours (detection to resolution)
Severity:        Critical / High / Medium / Low
Commander:       [Name]

Timeline:
- HH:MM — [Event detected by...]
- HH:MM — [Containment action taken]
- HH:MM — [Investigation started]
- HH:MM — [Root cause identified]
- HH:MM — [Eradication complete]
- HH:MM — [Recovery complete]

Root Cause:
[What actually happened and why]

What Went Well:
- [Detection was fast because...]
- [Containment worked because...]

What Could Improve:
- [We didn't have X visibility]
- [Playbook was missing Y step]

Action Items:
- [ ] [Action] — Owner: [Name] — Due: [Date]
- [ ] [Action] — Owner: [Name] — Due: [Date]
```

---

## Expected Outcomes

| Outcome | Target |
|---------|--------|
| Containment SLA | Critical: 15 min, High: 1 hour |
| Evidence preserved before eradication | 100% of incidents |
| Root cause documented | 100% of incidents |
| Post-incident review held | Within 48 hours |
| Action items tracked to closure | Within 30 days |
| Playbook updated with lessons learned | Within 1 week |

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Can't disable access key | Insufficient permissions | Use root or admin account; escalate |
| CloudTrail shows no events for key | Key used in region without trail | Enable multi-region trail (Playbook 07) |
| Quarantine SG not stopping traffic | Existing connections persist | Stop the instance to drop connections |
| Snapshot creation slow | Large volumes | Normal — snapshots are incremental, first one takes time |
| Can't delete IAM role | Has instance profiles or policies | Detach all policies and profiles first (see Step 4c) |
| GuardDuty findings missing | Detector not enabled in this region | Enable in all active regions |
| Attacker created resources in other regions | Single-region investigation | Check ALL regions: `for r in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do ...` |

---

*Ghost Protocol — Cloud Security Package*
