# Playbook 01 — VPC Network Security

> Design and deploy a hardened VPC with public/private subnets, restrictive security groups, VPC Flow Logs, and VPC Endpoints. Default posture: everything private. Add public access only where justified and documented.
>
> **When:** Phase 1 of any AWS migration engagement. VPC is the foundation — nothing else deploys until this is solid.
> **Audience:** Platform engineers, cloud architects, security consultants.
> **Time:** ~45 min (Terraform deploy) or ~60 min (manual CLI)

---

## Prerequisites

- AWS CLI configured with appropriate IAM permissions (`ec2:*`, `logs:*`)
- Terraform >= 1.5 (if using IaC path)
- Target region selected (examples use `us-east-1`)
- CIDR range allocated (examples use `10.0.0.0/16`)

---

## VPC Security Layers

```
Internet → IGW → WAF → Network Firewall → NACLs → Security Groups → EC2/EKS
```

Every layer is defense-in-depth. Security Groups are your primary control. NACLs are your safety net. VPC Flow Logs are your audit trail.

---

## Step 1: Create VPC with Public/Private Subnets

Two availability zones minimum. Public subnets for ALBs only. Private subnets for everything else.

**Terraform (recommended):**

```bash
PKG=~/linkops-industries/GP-copilot/GP-CONSULTING/06-CLOUD-SECURITY

# Use the VPC isolation template as a base
cp $PKG/templates/vpc-isolation/ ./infrastructure/vpc/ -r

# Deploy with our wrapper
bash $PKG/tools/deploy-terraform.sh \
  --template ./infrastructure/vpc/ \
  --var project_name=acme-corp \
  --var vpc_cidr=10.0.0.0/16 \
  --var environment=production
```

**AWS CLI (for operations and verification):**

```bash
# Create VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=acme-corp-vpc},{Key=Environment,Value=production}]' \
  --query 'Vpc.VpcId' --output text)

# Enable DNS hostnames (required for VPC Endpoints)
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

# Create public subnets (ALBs only)
PUB_SUB_A=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=acme-public-1a},{Key=Tier,Value=public}]' \
  --query 'Subnet.SubnetId' --output text)

PUB_SUB_B=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=acme-public-1b},{Key=Tier,Value=public}]' \
  --query 'Subnet.SubnetId' --output text)

# Create private subnets (workloads, databases, EKS nodes)
PRIV_SUB_A=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.10.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=acme-private-1a},{Key=Tier,Value=private}]' \
  --query 'Subnet.SubnetId' --output text)

PRIV_SUB_B=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.11.0/24 \
  --availability-zone us-east-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=acme-private-1b},{Key=Tier,Value=private}]' \
  --query 'Subnet.SubnetId' --output text)

echo "VPC: $VPC_ID"
echo "Public:  $PUB_SUB_A, $PUB_SUB_B"
echo "Private: $PRIV_SUB_A, $PRIV_SUB_B"
```

---

## Step 2: Configure Internet Gateway and NAT Gateway

Public subnets route to the Internet Gateway. Private subnets route to the NAT Gateway (egress only — no inbound from internet).

```bash
# Internet Gateway (for public subnets)
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=acme-igw}]' \
  --query 'InternetGateway.InternetGatewayId' --output text)

aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID

# Elastic IP for NAT Gateway
EIP_ALLOC=$(aws ec2 allocate-address --domain vpc \
  --query 'AllocationId' --output text)

# NAT Gateway (in public subnet — provides egress for private subnets)
NAT_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $PUB_SUB_A \
  --allocation-id $EIP_ALLOC \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=acme-nat}]' \
  --query 'NatGateway.NatGatewayId' --output text)

# Wait for NAT Gateway to become available
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_ID
```

---

## Step 3: Configure Route Tables

```bash
# Public route table — routes to IGW
PUB_RT=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=acme-public-rt}]' \
  --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-route --route-table-id $PUB_RT \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID

aws ec2 associate-route-table --route-table-id $PUB_RT --subnet-id $PUB_SUB_A
aws ec2 associate-route-table --route-table-id $PUB_RT --subnet-id $PUB_SUB_B

# Private route table — routes to NAT Gateway (egress only)
PRIV_RT=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=acme-private-rt}]' \
  --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-route --route-table-id $PRIV_RT \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_ID

aws ec2 associate-route-table --route-table-id $PRIV_RT --subnet-id $PRIV_SUB_A
aws ec2 associate-route-table --route-table-id $PRIV_RT --subnet-id $PRIV_SUB_B
```

**Private connectivity patterns:**

| Source | Destination | Path |
|--------|-------------|------|
| Private subnet | Internet | NAT Gateway (egress only) |
| Private subnet | S3 | Gateway VPC Endpoint (free, no NAT) |
| Private subnet | AWS services | Interface VPC Endpoint (private IP) |
| Public subnet | Internet | Internet Gateway (bidirectional) |

---

## Step 4: Configure Security Groups

Security Groups reference other Security Groups — not CIDR blocks — for east-west traffic. This is the zero-trust pattern.

```bash
# ALB Security Group — only 443 from internet
ALB_SG=$(aws ec2 create-security-group \
  --group-name acme-alb-sg \
  --description "ALB - HTTPS from internet only" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $ALB_SG \
  --protocol tcp --port 443 --cidr 0.0.0.0/0

# EKS / App Security Group — only from ALB SG
APP_SG=$(aws ec2 create-security-group \
  --group-name acme-app-sg \
  --description "App tier - traffic from ALB only" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $APP_SG \
  --protocol tcp --port 8080 --source-group $ALB_SG

# RDS Security Group — only from App SG on port 5432
RDS_SG=$(aws ec2 create-security-group \
  --group-name acme-rds-sg \
  --description "RDS - PostgreSQL from app tier only" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $RDS_SG \
  --protocol tcp --port 5432 --source-group $APP_SG

# Redis Security Group — only from App SG on port 6379
REDIS_SG=$(aws ec2 create-security-group \
  --group-name acme-redis-sg \
  --description "Redis - from app tier only" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $REDIS_SG \
  --protocol tcp --port 6379 --source-group $APP_SG
```

**Security Groups vs NACLs:**

| Feature | Security Groups | NACLs |
|---------|----------------|-------|
| Level | Instance / ENI | Subnet |
| State | Stateful (return traffic auto-allowed) | Stateless (must allow both directions) |
| Rules | Allow only | Allow and Deny |
| Evaluation | All rules evaluated | Rules evaluated in order (lowest number first) |
| Default | Deny all inbound, allow all outbound | Allow all |
| Use case | Primary access control | Defense-in-depth, emergency block |

---

## Step 5: Configure NACLs (Defense-in-Depth)

NACLs are your subnet-level safety net. They catch mistakes in Security Group configuration.

```bash
# Create restrictive NACL for private subnets
PRIV_NACL=$(aws ec2 create-network-acl --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=network-acl,Tags=[{Key=Name,Value=acme-private-nacl}]' \
  --query 'NetworkAcl.NetworkAclId' --output text)

# Allow inbound from VPC CIDR only
aws ec2 create-network-acl-entry --network-acl-id $PRIV_NACL \
  --rule-number 100 --protocol -1 --rule-action allow \
  --ingress --cidr-block 10.0.0.0/16

# Allow outbound to VPC CIDR
aws ec2 create-network-acl-entry --network-acl-id $PRIV_NACL \
  --rule-number 100 --protocol -1 --rule-action allow \
  --egress --cidr-block 10.0.0.0/16

# Allow outbound HTTPS (for NAT Gateway / VPC Endpoints)
aws ec2 create-network-acl-entry --network-acl-id $PRIV_NACL \
  --rule-number 110 --protocol tcp --port-range From=443,To=443 \
  --rule-action allow --egress --cidr-block 0.0.0.0/0

# Allow inbound ephemeral ports (return traffic from NAT)
aws ec2 create-network-acl-entry --network-acl-id $PRIV_NACL \
  --rule-number 110 --protocol tcp --port-range From=1024,To=65535 \
  --rule-action allow --ingress --cidr-block 0.0.0.0/0

# Deny all else (implicit — rule *)

# Associate with private subnets
aws ec2 replace-network-acl-association \
  --association-id $(aws ec2 describe-network-acls --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "NetworkAcls[0].Associations[?SubnetId=='$PRIV_SUB_A'].NetworkAclAssociationId" --output text) \
  --network-acl-id $PRIV_NACL
```

---

## Step 6: Enable VPC Flow Logs

Flow Logs are non-negotiable. They give you visibility into every connection attempt — accepted and rejected.

```bash
# Create CloudWatch Log Group for flow logs
aws logs create-log-group --log-group-name /vpc/acme-corp/flow-logs

# Set retention (90 days for compliance)
aws logs put-retention-policy \
  --log-group-name /vpc/acme-corp/flow-logs \
  --retention-in-days 90

# Create IAM role for flow logs (one-time)
aws iam create-role --role-name vpc-flow-logs-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "vpc-flow-logs.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

aws iam put-role-policy --role-name vpc-flow-logs-role \
  --policy-name flow-logs-policy \
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

# Enable flow logs on VPC
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids $VPC_ID \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /vpc/acme-corp/flow-logs \
  --deliver-logs-permission-arn arn:aws:iam::ACCOUNT_ID:role/vpc-flow-logs-role \
  --tag-specifications 'ResourceType=vpc-flow-log,Tags=[{Key=Name,Value=acme-flow-logs}]'
```

---

## Step 7: Deploy VPC Endpoints

Gateway Endpoints for S3 and DynamoDB are free and keep traffic off the public internet. Interface Endpoints cost money but provide private connectivity to other AWS services.

```bash
# S3 Gateway Endpoint (FREE — always enable this)
aws ec2 create-vpc-endpoint \
  --vpc-id $VPC_ID \
  --service-name com.amazonaws.us-east-1.s3 \
  --route-table-ids $PRIV_RT \
  --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=acme-s3-endpoint}]'

# DynamoDB Gateway Endpoint (FREE)
aws ec2 create-vpc-endpoint \
  --vpc-id $VPC_ID \
  --service-name com.amazonaws.us-east-1.dynamodb \
  --route-table-ids $PRIV_RT \
  --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=acme-dynamodb-endpoint}]'

# Interface Endpoints (for private EKS clusters — these cost ~$7.50/mo each)
for SERVICE in sts ecr.api ecr.dkr logs ec2; do
  aws ec2 create-vpc-endpoint \
    --vpc-id $VPC_ID \
    --vpc-endpoint-type Interface \
    --service-name com.amazonaws.us-east-1.$SERVICE \
    --subnet-ids $PRIV_SUB_A $PRIV_SUB_B \
    --security-group-ids $APP_SG \
    --private-dns-enabled \
    --tag-specifications "ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=acme-${SERVICE}-endpoint}]"
done
```

---

## Step 8: Enforce IMDSv2

IMDSv2 blocks SSRF attacks against the instance metadata service. This is a one-liner that prevents a whole class of cloud credential theft.

```bash
# For existing instances — enforce IMDSv2 (HttpTokens=required)
for INSTANCE_ID in $(aws ec2 describe-instances \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' --output text); do

  aws ec2 modify-instance-metadata-options \
    --instance-id $INSTANCE_ID \
    --http-tokens required \
    --http-endpoint enabled \
    --http-put-response-hop-limit 1
  echo "IMDSv2 enforced on $INSTANCE_ID"
done

# For Terraform — set in launch template
# metadata_options {
#   http_tokens   = "required"
#   http_endpoint = "enabled"
#   http_put_response_hop_limit = 1
# }
```

---

## Step 9: Validate

```bash
PKG=~/linkops-industries/GP-copilot/GP-CONSULTING/06-CLOUD-SECURITY

# Run security validation
bash $PKG/tools/validate-security.sh --target ./infrastructure/

# Manual checks
echo "=== Security Group Audit ==="
# Verify no 0.0.0.0/0 rules on non-ALB security groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[?length(IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]) > `0`].{Name:GroupName,ID:GroupId}' \
  --output table
# Only the ALB SG should appear here

echo "=== VPC Flow Logs ==="
aws ec2 describe-flow-logs --filter "Name=resource-id,Values=$VPC_ID" \
  --query 'FlowLogs[].{Status:FlowLogStatus,Traffic:TrafficType,Destination:LogDestinationType}' \
  --output table
# Expected: Status=ACTIVE, Traffic=ALL

echo "=== IMDSv2 Enforcement ==="
aws ec2 describe-instances \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{ID:InstanceId,IMDSv2:MetadataOptions.HttpTokens}' \
  --output table
# Expected: All instances show HttpTokens=required

echo "=== VPC Endpoints ==="
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'VpcEndpoints[].{Service:ServiceName,Type:VpcEndpointType,State:State}' \
  --output table
# Expected: s3 (Gateway), dynamodb (Gateway), plus Interface endpoints
```

---

## Expected Outcomes

| Check | Pass Criteria |
|-------|--------------|
| VPC created | 2+ AZs, public + private subnets |
| No open SGs | Only ALB SG has 0.0.0.0/0 (port 443 only) |
| SG referencing | App SG references ALB SG, RDS SG references App SG |
| Flow Logs | Status=ACTIVE, TrafficType=ALL |
| VPC Endpoints | S3 + DynamoDB Gateway Endpoints active |
| IMDSv2 | All instances HttpTokens=required |
| NACLs | Private subnets have restrictive NACLs |
| Route tables | Private subnets route through NAT, not IGW |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Private subnet can't reach internet | NAT Gateway not in public subnet or route missing | Verify NAT is in public subnet, check private route table has 0.0.0.0/0 -> NAT |
| VPC Endpoint not working | DNS hostnames not enabled on VPC | `aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames` |
| Security Group rule denied | SG reference uses wrong group ID | `aws ec2 describe-security-groups --group-ids $SG_ID` — verify source-group |
| Flow Logs not appearing | IAM role trust policy wrong | Verify principal is `vpc-flow-logs.amazonaws.com` |
| IMDSv2 breaks app | App uses IMDSv1 SDK calls | Update SDK, set hop limit to 2 for containerized workloads |
| Interface Endpoint 504 | Security group on endpoint missing inbound 443 | Add inbound 443 from VPC CIDR to endpoint SG |

---

## Reference Templates

- `$PKG/templates/vpc-isolation/` — Terraform VPC with all security controls
- `$PKG/templates/zero-trust-sg/` — Security Group referencing patterns
- `$PKG/templates/private-cloud-access/` — VPC Endpoint configurations

---

## Next Steps

- VPC is live? Harden IAM next. -> [02-iam-hardening.md](02-iam-hardening.md)
- Need to test locally first? -> `bash $PKG/tools/test-localstack.sh`
- Ready for full Terraform deploy? -> `bash $PKG/tools/deploy-terraform.sh`

---

*Ghost Protocol — Cloud Security Package*
