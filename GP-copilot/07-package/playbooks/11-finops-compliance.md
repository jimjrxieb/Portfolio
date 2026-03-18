# Playbook 11 — FinOps Under FedRAMP Constraints

> Cost optimization that keeps you authorized. ~60% of normal FinOps works unchanged in FedRAMP, ~30% needs modification, ~10% is off-limits. This playbook maps every optimization to the controls that constrain it.
>
> **When:** After FedRAMP controls are implemented (playbooks 01-10). Ongoing monthly cadence.
> **Audience:** Platform engineers, FinOps practitioners, compliance leads.
> **Time:** ~2 hours (initial control-aware audit), ~30 min (monthly review)

---

## Prerequisites

- FedRAMP impact level determined (Low / Moderate / High)
- SSP drafted with approved baseline configuration (CM-2)
- Security tooling deployed and operational (SI-4, AU-2)
- AWS Cost Explorer enabled

---

## The Constraint Model

```
FedRAMP FinOps = Normal FinOps + "Can I still do this AND stay authorized?"

THE TENSION:
  Cost optimization says: "Use Spot, multi-region, shared tenancy, smallest possible"
  FedRAMP says:          "Prove control, prove isolation, prove auditability"

NEVER optimize cost in a way that removes an audit trail or breaks a control boundary.
```

---

## What You CAN Do, What Needs Modification, What's Off-Limits

### Safe — No FedRAMP Impact

```
✓ Right-size instances (CPU/memory optimization)
✓ Savings Plans / Reserved Instances
✓ Scheduled scaling for non-prod environments
✓ S3 lifecycle policies (with retention compliance)
✓ EBS volume optimization (gp3 > gp2, remove unattached)
✓ CloudWatch log tiering (Infrequent Access class)
✓ Kubecost / OpenCost for K8s cost allocation
✓ Infracost in CI/CD pipelines
✓ Karpenter for node autoscaling (with constraints)
✓ VPC endpoint usage to avoid NAT Gateway costs
```

### Needs Modification — Check Controls First

```
⚠ Spot Instances       → OK for CI/CD and batch, NOT for control plane or data processing
⚠ Multi-region         → only within authorized regions (GovCloud or approved commercial)
⚠ Auto-scaling         → must maintain minimum replicas for HA controls (CP-7, CP-10)
⚠ Log retention        → can tier but CANNOT delete before retention period (AU-11)
⚠ Resource cleanup     → must verify resource isn't part of audit trail before deleting
⚠ Shared services      → only within same authorization boundary
⚠ Container images     → must use approved registries (no public Docker Hub pulls at runtime)
```

### Off-Limits — Never Do These

```
✗ Sharing tenancy across authorization boundaries
✗ Deleting CloudTrail logs or audit records before retention period
✗ Using unapproved regions
✗ Disabling encryption to save on KMS costs
✗ Using public/shared AMIs without scanning
✗ Cross-boundary data transfer to save costs
✗ Removing security tooling (GuardDuty, Config, etc.) to cut spend
```

---

## Control Mapping for Cost Decisions

Before optimizing, check against these controls:

| Control | What It Says | Cost Impact |
|---------|-------------|-------------|
| **AU-11** | Retain audit records per policy (1-3 years) | Can't delete CloudWatch/CloudTrail/S3 access logs early |
| **CP-7** | Maintain failover capability | Must keep DR resources running (or prove cold-start meets RTO) |
| **CP-10** | Recover within defined timeframe | Can't scale to zero if RTO requires warm standby |
| **SC-7** | Control traffic at authorization boundary | Must maintain WAF, NACLs, SGs — can't merge for cost |
| **SC-28** | Encrypt data at rest | KMS costs are non-negotiable |
| **CM-2** | Maintain approved baseline | Can't swap instance types freely — SSP update needed |
| **CM-8** | Maintain component inventory | Every resource tracked — complicates dynamic autoscaling |
| **SA-10** | Control changes to system | All infra changes through approved pipeline |
| **SI-4** | Monitor for attacks/anomalies | Security monitoring costs are mandatory |

---

## Cost Optimization by Impact Level

### FedRAMP Low (125 Controls)

```
FLEXIBILITY: High — fewest constraints
Security overhead: ~5-10% of total bill

CAN DO: Standard FinOps mostly unchanged, Spot for non-critical, aggressive right-sizing
MUST KEEP: CloudTrail, encryption at rest, 90-day log retention minimum
```

### FedRAMP Moderate (323 Controls)

```
FLEXIBILITY: Medium — real constraints but room to optimize
Security overhead: ~10-20% of total bill
Compliance tooling: ~$2K-$10K/month depending on scale

ADDITIONAL REQUIREMENTS:
  - FIPS 140-2 validated crypto (limits instance types to Nitro)
  - Multi-AZ for production databases
  - Enhanced logging (VPC Flow Logs, S3 access logs, ELB logs)
  - Continuous monitoring (cannot disable)
  - WAF on all public endpoints

OPTIMIZATION OPPORTUNITIES:
  - VPC Flow Logs → S3 destination (not CloudWatch — 10x cheaper)
  - CloudWatch Logs → Infrequent Access class for older logs
  - RDS → Multi-AZ required for prod, but dev can be single-AZ
  - KMS → AWS-managed keys where customer-managed isn't required
```

### FedRAMP High (421 Controls)

```
FLEXIBILITY: Low — compliance costs are significant and non-negotiable
Security overhead: ~20-35% of total bill
Compliance tooling: ~$10K-$50K/month

FOCUS: Right-sizing is your biggest lever (compute still dominates)
  - Savings Plans in GovCloud (higher prices = bigger absolute savings)
  - Storage tiering for archived audit data
  - Reserved capacity for always-on security tooling
```

---

## Play 1: Log Storage Optimization (AU-11 Compliant)

CloudWatch Logs costs $0.50/GB ingestion + $0.03/GB/month storage. FedRAMP requires 1-3 year retention.

### Tiered Storage Strategy

```
0-30 days:   CloudWatch Logs (hot — queryable)
30-90 days:  CloudWatch Logs Infrequent Access ($0.25/GB ingest, 50% cheaper)
90d-1yr:     S3 Standard-IA ($0.0125/GB/month)
1yr-3yr:     S3 Glacier Instant Retrieval ($0.004/GB/month)
3yr+:        S3 Glacier Deep Archive ($0.00099/GB/month)
```

```bash
cat <<'EOF' > audit-log-lifecycle.json
{
  "Rules": [
    {
      "ID": "AuditLogTiering",
      "Status": "Enabled",
      "Prefix": "audit-logs/",
      "Transitions": [
        {"Days": 90, "StorageClass": "STANDARD_IA"},
        {"Days": 365, "StorageClass": "GLACIER_IR"},
        {"Days": 1095, "StorageClass": "DEEP_ARCHIVE"}
      ],
      "Expiration": {
        "Days": 2555
      }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --bucket fedramp-audit-logs \
  --lifecycle-configuration file://audit-log-lifecycle.json
```

---

## Play 2: Right-Size Within FIPS Constraints

FIPS 140-2 limits you to Nitro-based instances. Can't pick any cheap instance type.

### FIPS-Compatible Instance Families

```
General:  m5, m5a, m5n, m6i, m6a, m7i, m7a, t3 (burstable OK for dev)
Compute:  c5, c5a, c5n, c6i, c6a, c7i
Memory:   r5, r5a, r5n, r6i, r6a, r7i
Graviton: m6g, m7g, c6g, c7g, r6g, r7g (ARM — 20% cheaper, FIPS on AL2023 + openssl 3.x)
```

```bash
# Find current instance types
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,State:State.Name}' \
  --output table \
  --filters "Name=instance-state-name,Values=running"

# Price comparison example:
# m6i.xlarge: $0.192/hr = $140/month
# m7g.xlarge: $0.163/hr = $119/month (17% savings, FIPS-compliant on Nitro)
```

---

## Play 3: Dev/Staging Cost Control (CM-2 Compliant)

Dev/staging must mirror prod architecture (CM-2 baseline) but not prod SCALE.

```
Prod:     m6i.2xlarge, Multi-AZ RDS, 3 nodes (same AMI, same config)
Staging:  m6i.large,   Single-AZ RDS, 2 nodes (same AMI, same config)
Dev:      t3.medium,   Single-AZ RDS, 1 node  (same AMI, same config)

Schedule: Dev/staging OFF 7pm-7am weekdays, OFF all weekend
Savings:  ~65% on dev/staging compute
```

```bash
# Tag for scheduled scaling
aws ec2 create-tags --resources INSTANCE_ID --tags Key=Schedule,Value=business-hours
aws ec2 create-tags --resources INSTANCE_ID --tags Key=Environment,Value=dev
```

---

## Play 4: Security Tooling Cost Optimization

These tools are mandatory — budget for them. But you can optimize within the mandate.

### Mandatory Costs

```
CloudTrail              ~$2/100K events     (all regions, required)
AWS Config              ~$3/rule/region     (CM-2, CM-8)
GuardDuty               ~$4/GB flow logs    (SI-4)
Security Hub            ~$0.0010/check      (aggregation)
KMS                     ~$1/key/month       (encryption)
WAF                     ~$5/web ACL + rules (SC-7)
VPC Flow Logs           varies              (network monitoring)
```

### Optimization Within Mandatory

```bash
# 1. Config Rules — only enable what your SSP controls require
# Typical FedRAMP Moderate: ~40-60 rules, not 300+
aws configservice describe-config-rules \
  --query 'ConfigRules[].ConfigRuleName' --output text | wc -w

# 2. VPC Flow Logs — S3 destination, NOT CloudWatch (10x cost difference)
# Use max aggregation interval (10 min) unless incident response needs 1 min

# 3. GuardDuty — check if all data sources are needed
aws guardduty get-usage-statistics \
  --detector-id $(aws guardduty list-detectors --query 'DetectorIds[0]' --output text) \
  --usage-statistic-type SUM_BY_DATA_SOURCE \
  --usage-criteria '{"DataSources": ["FLOW_LOGS","CLOUD_TRAIL","DNS_LOGS"]}'

# 4. Security Hub — disable integrations you don't use
# Don't pay for Macie unless you have sensitive data discovery requirements
```

---

## Play 5: Container Image Optimization

FedRAMP requires approved base images from approved registries. Smaller images = less storage cost, less transfer cost, faster scans.

```
Cost math:
  500MB image × 50 repos × 20 tags = 500GB ECR storage = $50/month
  100MB image × 50 repos × 20 tags = 100GB ECR storage = $10/month
```

```bash
# ECR lifecycle policy — keep last 10 tagged, delete untagged after 7 days
cat <<'EOF' > ecr-lifecycle.json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Remove untagged after 7 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": {"type": "expire"}
    },
    {
      "rulePriority": 2,
      "description": "Keep last 10 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {"type": "expire"}
    }
  ]
}
EOF

aws ecr put-lifecycle-policy \
  --repository-name APP_NAME \
  --lifecycle-policy-text file://ecr-lifecycle.json
```

---

## FedRAMP-Safe Tools

### Run Inside Your Boundary (No ATO Review Needed)

| Tool | What It Does |
|------|-------------|
| AWS Cost Explorer | Spend analysis |
| AWS Trusted Advisor | Right-sizing recommendations |
| AWS Compute Optimizer | ML-based instance recommendations |
| Kubecost (self-hosted) | K8s cost allocation |
| OpenCost (self-hosted) | CNCF K8s cost monitoring |
| Infracost (self-hosted runner) | Terraform cost estimates |
| Karpenter (self-hosted) | K8s node optimization |
| Cloud Custodian (self-hosted) | Policy-based resource cleanup |

### Needs FedRAMP Authorization Review

| Tool | Concern |
|------|---------|
| Vantage | SaaS — reads billing data externally |
| CloudHealth | SaaS — VMware/Broadcom |
| CAST AI | SaaS — needs cluster API access |
| Datadog | FedRAMP Moderate authorized — OK if using their FedRAMP environment |

**Rule:** If a tool reads your billing data or accesses infrastructure, it either runs INSIDE your boundary or must be FedRAMP authorized. Check marketplace.fedramp.gov.

---

## Cost Reporting for Auditors

```
Auditors care about:
  1. Are security controls funded and operational?
  2. Is capacity adequate for SLAs?
  3. Are backups and DR properly resourced?
  4. Is monitoring comprehensive and continuous?

SHOW:
  - Budget line items for required security tooling
  - Capacity headroom reports (not running at 100%)
  - DR test results with timing
  - Monitoring coverage map

DON'T:
  - Show cost savings from removing monitoring
  - Present right-sizing that leaves zero headroom
  - Mention turning off GuardDuty in dev to save $50/month
```

---

## FedRAMP-Safe Quick Wins

| # | Action | Savings | FedRAMP Impact |
|---|--------|---------|---------------|
| 1 | VPC Flow Logs → S3 (not CloudWatch) | 10x cheaper | None — same data |
| 2 | CloudWatch Logs → Infrequent Access | 50% ingestion | None — still queryable |
| 3 | S3 lifecycle on audit logs | Auto-tier | None if retention met (AU-11) |
| 4 | ECR lifecycle policies | Storage savings | None |
| 5 | Right-size within same instance family | 20-50% | No SSP update needed |
| 6 | Schedule dev/staging off-hours | ~65% on non-prod | None if CM-2 arch maintained |
| 7 | AWS-managed KMS keys where allowed | $0 vs $1/key/mo | Check if customer-managed required |
| 8 | Audit Config Rules count | Often 50% fewer needed | Align to SSP controls |
| 9 | Graviton where app supports ARM | ~20% cheaper | FIPS-compliant on AL2023 |
| 10 | Reserved capacity for security tools | 30-40% savings | None |

---

## Cross-References

- FedRAMP controls: `07-FEDRAMP-READY/playbooks/01-10`
- Gap analysis tool: `07-FEDRAMP-READY/tools/gap-analysis.py`
- AWS cost optimization: `06-CLOUD-SECURITY/playbooks/11-aws-cost-optimization.md`
- FinOps practice: `06-CLOUD-SECURITY/playbooks/12-finops-practice.md`
- K8s cost optimization: `02-CLUSTER-HARDENING/playbooks/13c-k8s-cost-optimization.md`
- Karpenter: `02-CLUSTER-HARDENING/playbooks/13a-deploy-karpenter.md`
