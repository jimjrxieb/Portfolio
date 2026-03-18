# Playbook 11 — AWS Cost Optimization

> Systematically find and eliminate waste across EC2, EBS, S3, data transfer, and idle resources. Every step has a diagnose command, a fix, and a validation check.
>
> **When:** After infrastructure is deployed (playbooks 01-10 complete). Run monthly as part of FinOps cadence.
> **Audience:** Platform engineers, cloud architects, FinOps practitioners.
> **Time:** ~2 hours (initial audit), ~30 min (monthly review)

---

## Prerequisites

- AWS CLI configured with Cost Explorer, EC2, S3, ELB, and CloudWatch permissions
- Cost Explorer enabled in the AWS account (Settings → Cost Explorer → Enable)
- Cost allocation tags activated (Environment, Team, Project minimum)

---

## The Cost Model

```
AWS BILLING = compute + storage + network + managed services + tax (support plan)

WHERE MONEY HIDES:
  1. EC2/EKS compute      — 40-60% of most bills
  2. Data transfer         — the silent killer (cross-AZ, NAT Gateway, egress)
  3. Storage (EBS, S3)     — grows forever if nobody cleans up
  4. Idle resources        — things you forgot exist
  5. Wrong pricing model   — On-Demand when Savings Plans would save 40%
```

**Golden Rule:** You can't optimize what you can't see. Turn on Cost Explorer tags FIRST.

---

## Step 1: Get Visibility

### Enable Cost Allocation Tags

```bash
# Minimum tags: Environment (prod/staging/dev), Team, Project

# Check what's tagged
aws ce get-tags --time-period Start=$(date -d '-30 days' +%Y-%m-%d),End=$(date +%Y-%m-%d)

# Find untagged resources (the blind spots)
aws resourcegroupstaggingapi get-resources \
  --query "ResourceTagMappingList[?Tags[0]==null].[ResourceARN]" \
  --output text | head -20
```

### Cost Explorer Quick Checks

```bash
# Top 10 services by cost (last 30 days)
START=$(date -d '-30 days' +%Y-%m-%d)
END=$(date +%Y-%m-%d)

aws ce get-cost-and-usage \
  --time-period Start=$START,End=$END \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query "ResultsByTime[0].Groups | sort_by(@, &Metrics.UnblendedCost.Amount) | reverse(@) | [:10]"

# Daily spend trend (catch spikes)
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '-14 days' +%Y-%m-%d),End=$END \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --query "ResultsByTime[].[TimePeriod.Start,Metrics.UnblendedCost.Amount]" \
  --output table
```

### Validate

```bash
# Confirm tags are flowing into Cost Explorer
aws ce get-tags --time-period Start=$START,End=$END \
  --query "Tags" --output text | wc -l
# Should show your tag keys. If empty, tags aren't activated in Billing Console.
```

---

## Step 2: EC2 / EKS Compute Optimization

### Diagnose: Underutilized Instances

```bash
# List all running instances with type
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].[InstanceId,InstanceType,LaunchTime,Tags[?Key=='Name']|[0].Value]" \
  --output table

# Check CPU utilization for a specific instance (14-day average)
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=INSTANCE_ID \
  --start-time $(date -d '-14 days' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 86400 \
  --statistics Average \
  --query "Datapoints | sort_by(@, &Timestamp) | [].[Timestamp,Average]" \
  --output table

# Get AWS right-sizing recommendations
aws ce get-rightsizing-recommendation \
  --service "AmazonEC2" \
  --configuration RecommendationTarget=SAME_INSTANCE_FAMILY,BenefitsConsidered=true
```

### Fix Options

| Option | Savings | When to Use |
|--------|---------|-------------|
| Right-size (e.g., m5.xlarge → m5.large) | ~50% on that instance | Avg CPU <20% for 14 days |
| Stop dev/staging off-hours | ~65% on those envs | Non-prod workloads |
| Spot instances | Up to 90% | Fault-tolerant, stateless workloads |
| Graviton (ARM) | ~20% cheaper | Apps that support ARM (Go, Python, Java) |

### EKS Worker Nodes

```bash
# Check node group configuration
aws eks list-nodegroups --cluster-name CLUSTER_NAME --output text

aws eks describe-nodegroup \
  --cluster-name CLUSTER_NAME \
  --nodegroup-name NODEGROUP_NAME \
  --query "nodegroup.[instanceTypes,scalingConfig,amiType]"

# EKS control plane: $0.10/hr = $73/month (fixed, can't reduce)
# Node cost: depends on instance type and count — optimize this

# Right-size scaling config
aws eks update-nodegroup-config \
  --cluster-name CLUSTER_NAME \
  --nodegroup-name NODEGROUP_NAME \
  --scaling-config minSize=1,maxSize=5,desiredSize=2
```

For smarter node provisioning, see `02-CLUSTER-HARDENING/playbooks/13a-deploy-karpenter.md`.

### Validate

```bash
# Re-check CPU after right-sizing (wait 7 days)
# Target: avg CPU 30-60% (efficient but not saturated)
```

---

## Step 3: Data Transfer (The Silent Killer)

### Diagnose: NAT Gateway Costs

```bash
# NAT Gateway charges: $0.045/hr + $0.045/GB processed
# 1 TB/month through NAT = $45 processing + $32 hourly = $77/month

# List all NAT Gateways
aws ec2 describe-nat-gateways \
  --query "NatGateways[].[NatGatewayId,SubnetId,State]" --output table

# Check data processed
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value=NAT_GW_ID \
  --start-time $(date -d '-14 days' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 86400 \
  --statistics Sum \
  --query "Datapoints | sort_by(@, &Timestamp)"
```

### Fix: VPC Endpoints

```bash
# S3 Gateway Endpoint — FREE, stops S3 traffic from going through NAT
aws ec2 create-vpc-endpoint \
  --vpc-id VPC_ID \
  --service-name com.amazonaws.REGION.s3 \
  --route-table-ids RTB_ID

# ECR Interface Endpoints — saves NAT costs ($7.20/month per endpoint)
for svc in "com.amazonaws.REGION.ecr.api" "com.amazonaws.REGION.ecr.dkr"; do
  aws ec2 create-vpc-endpoint \
    --vpc-id VPC_ID \
    --vpc-endpoint-type Interface \
    --service-name "$svc" \
    --subnet-ids SUBNET_ID
done
```

### Cross-AZ Traffic

Cross-AZ call = $0.01/GB each direction. Microservices chatting across AZs adds up.

**Fix:**
- Topology-aware routing in K8s (`topologyKeys` on Services)
- Colocate tightly-coupled services in the same AZ
- Use internal ALB instead of per-service cross-AZ calls

### Validate

```bash
# Re-check NAT Gateway metrics after VPC endpoint deployment
# S3 traffic through NAT should drop to near zero
```

---

## Step 4: Storage Optimization

### Unattached EBS Volumes

```bash
# Find unattached volumes (you're paying for these)
aws ec2 describe-volumes \
  --filters "Name=status,Values=available" \
  --query "Volumes[].[VolumeId,Size,VolumeType,CreateTime]" \
  --output table

# Total wasted GB
aws ec2 describe-volumes \
  --filters "Name=status,Values=available" \
  --query "sum(Volumes[].Size)"

# Fix: snapshot first, then delete
aws ec2 create-snapshot --volume-id VOL_ID --description "backup before cost cleanup"
aws ec2 delete-volume --volume-id VOL_ID
```

### Migrate gp2 → gp3 (20% cheaper, zero downtime)

```bash
# Find all gp2 volumes
aws ec2 describe-volumes \
  --filters "Name=volume-type,Values=gp2" \
  --query "Volumes[].[VolumeId,Size,Attachments[0].InstanceId]" \
  --output table

# Migrate (online, no downtime)
aws ec2 modify-volume --volume-id VOL_ID --volume-type gp3
```

### S3 Lifecycle Rules

```bash
# Check if lifecycle rules exist
aws s3api get-bucket-lifecycle-configuration --bucket BUCKET_NAME 2>/dev/null \
  || echo "No lifecycle rules — storage growing unchecked"

# Add tiered lifecycle: Standard → IA (30d) → Glacier (90d) → delete (365d)
aws s3api put-bucket-lifecycle-configuration --bucket BUCKET_NAME --lifecycle-configuration '{
  "Rules": [{
    "ID": "cost-optimization",
    "Status": "Enabled",
    "Filter": {"Prefix": ""},
    "Transitions": [
      {"Days": 30, "StorageClass": "STANDARD_IA"},
      {"Days": 90, "StorageClass": "GLACIER"}
    ],
    "Expiration": {"Days": 365}
  }]
}'
```

### S3 Storage Class Reference

```
Standard:        $0.023/GB/mo   ← default, most expensive
Intelligent:     $0.023/GB/mo   ← auto-tiers, small monitoring fee
Standard-IA:     $0.0125/GB/mo  ← 46% cheaper, $0.01/GB retrieval
One Zone-IA:     $0.01/GB/mo    ← 57% cheaper, single AZ (non-critical data)
Glacier Instant: $0.004/GB/mo   ← 83% cheaper, millisecond retrieval
Glacier Flex:    $0.0036/GB/mo  ← minutes-hours retrieval
Deep Archive:    $0.00099/GB/mo ← 96% cheaper, 12-48hr retrieval
```

### Validate

```bash
# Confirm no unattached volumes remain
aws ec2 describe-volumes --filters "Name=status,Values=available" \
  --query "length(Volumes[])"
# Should return 0

# Confirm gp2 migration
aws ec2 describe-volumes --filters "Name=volume-type,Values=gp2" \
  --query "length(Volumes[])"
# Should return 0
```

---

## Step 5: Savings Plans and Reserved Instances

### Diagnose: All On-Demand

```bash
# Check existing coverage
aws ce get-reservation-coverage \
  --time-period Start=$(date -d '-30 days' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY

# Get recommendations
aws ce get-savings-plans-purchase-recommendation \
  --savings-plans-type "COMPUTE_SP" \
  --term-in-years "ONE_YEAR" \
  --payment-option "NO_UPFRONT" \
  --lookback-period-in-days "THIRTY_DAYS"
```

### Options

```
Savings Plans (recommended — flexible):
  Compute SP:      Up to 66% off. Any region, any instance family, EC2+Fargate+Lambda.
  EC2 Instance SP: Up to 72% off. Locked to instance family + region.

Reserved Instances (for services SPs don't cover):
  RDS, ElastiCache, Redshift, OpenSearch.
  1-yr No Upfront = low risk, decent savings.

Spot Instances:
  Up to 90% off. 2-min interruption warning.
  Good for: batch jobs, CI/CD runners, stateless K8s pods.
```

**Rule of thumb:** Steady-state compute running 12+ months → buy Compute Savings Plan (No Upfront, 1-year). Easiest win.

---

## Step 6: Find and Kill Idle Resources

### Elastic IPs

```bash
# Each unattached EIP = $3.60/month
aws ec2 describe-addresses \
  --query "Addresses[?AssociationId==null].[PublicIp,AllocationId]" \
  --output table

# Release them
aws ec2 release-address --allocation-id ALLOC_ID
```

### Idle Load Balancers

```bash
# ALBs with zero healthy targets
for arn in $(aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerArn" --output text); do
  targets=$(aws elbv2 describe-target-groups --load-balancer-arn "$arn" \
    --query "TargetGroups[].TargetGroupArn" --output text)
  for tg in $targets; do
    count=$(aws elbv2 describe-target-health --target-group-arn "$tg" \
      --query "length(TargetHealthDescriptions)")
    if [ "$count" = "0" ]; then
      echo "IDLE: $arn (target group: $tg)"
    fi
  done
done
```

### Old Snapshots

```bash
# Snapshots older than 90 days
CUTOFF=$(date -d '-90 days' +%Y-%m-%d)
aws ec2 describe-snapshots --owner-ids self \
  --query "Snapshots[?StartTime<='${CUTOFF}'].[SnapshotId,VolumeSize,StartTime,Description]" \
  --output table
```

### Unused ECR Images

```bash
# Set ECR lifecycle policy (auto-cleanup — keep last 10 images)
aws ecr put-lifecycle-policy --repository-name REPO_NAME --lifecycle-policy-text '{
  "rules": [{
    "rulePriority": 1,
    "description": "Keep only last 10 images",
    "selection": {
      "tagStatus": "any",
      "countType": "imageCountMoreThan",
      "countNumber": 10
    },
    "action": {"type": "expire"}
  }]
}'
```

---

## Step 7: Cost Alerts

### Billing Alarm

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "MonthlySpendAlert" \
  --alarm-description "Alert when estimated charges exceed threshold" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --threshold 500 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions "arn:aws:sns:us-east-1:ACCOUNT_ID:billing-alerts" \
  --dimensions Name=Currency,Value=USD
```

### AWS Budgets

```bash
aws budgets create-budget --account-id ACCOUNT_ID --budget '{
  "BudgetName": "monthly-budget",
  "BudgetLimit": {"Amount": "1000", "Unit": "USD"},
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}' --notifications-with-subscribers '[{
  "Notification": {
    "NotificationType": "ACTUAL",
    "ComparisonOperator": "GREATER_THAN",
    "Threshold": 80,
    "ThresholdType": "PERCENTAGE"
  },
  "Subscribers": [{
    "SubscriptionType": "EMAIL",
    "Address": "alerts@example.com"
  }]
}]'
```

---

## Monthly Cost Review Checklist

```
[ ] Check Cost Explorer → top 5 services by spend
[ ] Find and tag any new untagged resources
[ ] Review right-sizing recommendations
[ ] Check Savings Plan utilization
[ ] Audit idle resources (EIPs, EBS, LBs, snapshots)
[ ] Review data transfer costs (NAT Gateway, cross-AZ)
[ ] Update budget alerts if spend pattern changed
```

---

## Quick Wins Summary

| Action | Effort | Savings | Risk |
|--------|--------|---------|------|
| Migrate gp2 → gp3 | 5 min/volume | 20% on EBS | Zero downtime |
| Delete unattached EBS | 10 min | $0.10/GB/mo recovered | Snapshot first |
| Release unattached EIPs | 5 min | $3.60/mo each | None |
| Create S3 Gateway Endpoint | 10 min | NAT cost reduction | None |
| Add S3 lifecycle rules | 10 min/bucket | 46-96% on old data | None |
| ECR lifecycle policies | 5 min/repo | Storage savings | Keep enough images |
| Compute Savings Plan | 30 min decision | 20-66% on compute | 1-year commitment |
| Stop dev/staging off-hours | 30 min setup | ~65% on non-prod | Teams need awareness |
| Graviton instances | 1-2 hrs testing | ~20% on compute | Test ARM compatibility |

---

## Tools

| Tool | What it does |
|------|-------------|
| AWS Cost Explorer | Built-in cost breakdown and trends |
| AWS Budgets | Alerts and forecasting |
| AWS Trusted Advisor | Idle resource and savings recommendations |
| AWS Compute Optimizer | ML-based right-sizing for EC2, EBS, Lambda |
| Infracost | Cost estimates for Terraform changes (pre-deploy) |
| Kubecost | K8s cost allocation (ties pods to AWS spend) |

---

## Cross-References

- VPC/Network: `06-CLOUD-SECURITY/playbooks/01-vpc-network-security.md`
- IAM least-privilege: `06-CLOUD-SECURITY/playbooks/02-iam-hardening.md`
- EKS hardening: `02-CLUSTER-HARDENING/playbooks/05-eks-security-hardening.md` (if it exists)
- Karpenter: `02-CLUSTER-HARDENING/playbooks/13a-deploy-karpenter.md`
- K8s cost optimization: `02-CLUSTER-HARDENING/playbooks/13c-k8s-cost-optimization.md`
- FinOps practice: `06-CLOUD-SECURITY/playbooks/12-finops-practice.md`
- FinOps + FedRAMP: `07-FEDRAMP-READY/playbooks/11-finops-compliance.md`
