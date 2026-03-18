# AWS Migration Engagement Guide

> **How to migrate on-premises infrastructure to AWS securely**

---

## Overview

This guide walks you through a secure AWS migration using Infrastructure as Code (IaC). You can choose **Terraform** or **CloudFormation** based on your team's preference - we provide both.

**Timeline:** 8-12 weeks from planning to production migration

**Outcome:** Secure, compliant, repeatable AWS infrastructure

Good — you're thinking about this the right way now. **When** something happens in the deployment lifecycle matters as much as **what** it is. Let me break this down by phase, because if you mix up the order you'll be debugging dependency chains for hours.

## First — The Mental Model You Need

Before I give you the checklist, internalize this lifecycle:

```
PRE-DEPLOY (Terraform/eksctl) → DEPLOY (kubectl/helm) → RUNTIME (monitoring/agents) → OBSERVE (dashboards/alerts)
```

Some of these controls are **infrastructure-level** — they exist before a single pod runs. Others are **workload-level** — they only matter once apps are deployed. Mixing these up is a common junior mistake and interviewers will test you on it.

---

## TIER 1 — Interview-Killers

### 1A. KMS Envelope Encryption for Secrets

**Phase: PRE-DEPLOY (must exist before cluster creation)**

This is infrastructure. You're telling EKS "encrypt etcd secrets with my KMS key" at cluster creation time. You cannot bolt this on after — well, technically you can enable it later, but it only encrypts **new** secrets going forward, existing ones stay unencrypted until rewritten. So do it first.

**What's actually happening under the hood:**

Kubernetes Secrets are stored in etcd. By default on EKS, etcd is encrypted with an AWS-managed key (you don't control it). With envelope encryption, you bring your own KMS Customer Managed Key (CMK). Kubernetes uses a Data Encryption Key (DEK) to encrypt the secret, then KMS encrypts the DEK itself. That's the "envelope" — encrypted data wrapped in an encrypted key.

**Step by step:**

```
1. Create KMS key (Terraform or CLI)
   - aws kms create-key --description "anthra-cloud-eks-secrets"
   - Set key policy: allow EKS service principal to use it
   - Enable key rotation (FedRAMP requires this)
   
2. Create EKS cluster WITH encryption config
   - In eksctl cluster config YAML:
     
     secretsEncryption:
       keyARN: arn:aws:kms:us-east-1:ACCOUNT:key/KEY-ID
   
   - Or in Terraform:
     
     encryption_config {
       provider {
         key_arn = aws_kms_key.eks_secrets.arn
       }
       resources = ["secrets"]
     }

3. Verify (CLI — post-creation)
   - aws eks describe-cluster --name anthra-cloud \
       --query "cluster.encryptionConfig"
   - Create a test secret, then check etcd isn't storing plaintext
   
4. Document for compliance
   - Screenshot the KMS key policy
   - Record the key ARN and rotation schedule
   - This goes in your FedRAMP SSP under SC-28 (Protection of Information at Rest)
```

**Common gotcha I need to warn you about:** The KMS key and the EKS cluster must be in the same region. Sounds obvious but people trip on this with multi-region setups.

### 1B. EKS Audit Logging to CloudWatch

**Phase: PRE-DEPLOY (enable at cluster creation) + RUNTIME (query and alert)**

This is split across two phases. You enable the logging at cluster creation (or update it after), but the actual value — querying audit trails, building alerts — is runtime and dashboard work.

**What's actually happening:**

EKS control plane components (API server, authenticator, controller manager, scheduler, audit) each produce logs. You choose which log types to send to CloudWatch. For security, the **audit** and **authenticator** logs are critical — they tell you who called what API and who authenticated.

**Step by step:**

```
PRE-DEPLOY:

1. Enable control plane logging in cluster config
   - eksctl config:
     
     cloudWatch:
       clusterLogging:
         enableTypes:
           - api
           - audit
           - authenticator
           - controllerManager
           - scheduler
   
   - You MUST enable at minimum: audit + authenticator
   - The others are useful but audit is the compliance requirement

2. Verify log group exists (CLI — post-creation)
   - aws logs describe-log-groups \
       --log-group-name-prefix "/aws/eks/anthra-cloud"
   - You should see /aws/eks/anthra-cloud/cluster

RUNTIME (once cluster is running):

3. Query audit logs (CLI)
   - aws logs filter-log-events \
       --log-group-name "/aws/eks/anthra-cloud/cluster" \
       --log-stream-name-prefix "kube-apiserver-audit" \
       --filter-pattern '{ $.verb = "delete" }'
   
   - This finds all DELETE operations — security gold

4. Build CloudWatch Insights queries (UI — CloudWatch console)
   - "Show all RBAC changes in the last 24 hours"
   - "Show all anonymous or failed authentication attempts"  
   - "Show all secret access events"
   - These become your compliance audit trail

5. Create CloudWatch Alarms (UI + CLI)
   - Alert on: cluster-admin binding creation
   - Alert on: secret access from unexpected service accounts
   - Alert on: API calls from IPs outside your CIDR

6. Document
   - FedRAMP controls: AU-2 (Audit Events), AU-6 (Audit Review)
   - Export sample audit logs as evidence
```

**Where jsa-infrasec connects:** Your EtcdAnalyzer and RBACAnalyzer already catch misconfigurations in-cluster. The CloudWatch audit trail catches **who made the misconfiguration and when.** These are complementary — jsa-infrasec finds the problem, CloudWatch audit tells you the story of how it got there. In a consulting engagement, clients want both.

### 1C. IRSA (IAM Roles for Service Accounts)

**Phase: PRE-DEPLOY (OIDC provider) + DEPLOY (role + service account binding)**

This is the most important one for interviews and the most conceptually tricky. Let me make sure you understand what's happening before the steps.

**What's actually happening:**

Without IRSA, every pod on a node inherits the node's IAM role. That means if one pod needs S3 access, the entire node gets S3 access — every pod on that node can read your buckets. That's a massive blast radius violation.

IRSA fixes this. It creates a trust relationship between a **Kubernetes ServiceAccount** and an **AWS IAM Role** using OIDC (OpenID Connect). When a pod with that ServiceAccount starts, AWS STS gives it temporary credentials for ONLY that IAM role. Pod-level least privilege.

The chain is: EKS OIDC provider → IAM role trust policy references the OIDC provider + specific ServiceAccount → pod assumes role via projected service account token.

**Step by step:**

```
PRE-DEPLOY:

1. Create OIDC provider for the cluster
   - eksctl utils associate-iam-oidc-provider \
       --cluster anthra-cloud --approve
   
   - Or in Terraform:
     data "tls_certificate" "eks" { ... }
     resource "aws_iam_openid_connect_provider" "eks" { ... }
   
   - This is a ONE-TIME setup per cluster
   - Verify: aws eks describe-cluster --name anthra-cloud \
       --query "cluster.identity.oidc"

2. Create IAM role with OIDC trust policy
   - The trust policy says: "only the ServiceAccount 'my-app-sa' 
     in namespace 'production' can assume this role"
   
   - Trust policy JSON:
     {
       "Version": "2012-10-17",
       "Statement": [{
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.REGION.amazonaws.com/id/CLUSTER_ID"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringEquals": {
             "oidc.eks.REGION.amazonaws.com/id/CLUSTER_ID:sub": 
               "system:serviceaccount:NAMESPACE:SA_NAME",
             "oidc.eks.REGION.amazonaws.com/id/CLUSTER_ID:aud": 
               "sts.amazonaws.com"
           }
         }
       }]
     }
   
   - Attach a MINIMAL permission policy (e.g., read-only S3 for one bucket)

DEPLOY (kubectl):

3. Create Kubernetes ServiceAccount with annotation
   - kubectl create sa my-app-sa -n production
   - Annotate it:
     kubectl annotate sa my-app-sa -n production \
       eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT:role/my-app-role

4. Deploy a pod using that ServiceAccount
   - In the pod spec:
     serviceAccountName: my-app-sa
   
   - The EKS webhook automatically injects:
     - AWS_ROLE_ARN env var
     - AWS_WEB_IDENTITY_TOKEN_FILE env var  
     - Projected token volume mount

RUNTIME (verify it works):

5. Exec into the pod and verify identity
   - kubectl exec -it my-pod -n production -- aws sts get-caller-identity
   - Should show the IRSA role ARN, NOT the node role
   
6. Verify least privilege
   - From inside the pod: try to access something NOT in the policy
   - It should be DENIED — that proves scoping works

7. Negative test (critical for security demos)
   - Deploy a DIFFERENT pod WITHOUT the ServiceAccount annotation
   - It should NOT be able to assume the role
   - This proves the trust policy condition is enforced
```

**This is your anthra-cloud money shot.** When you demo this to Constant or in an interview, the story is: "This pod can read from S3 with temporary credentials scoped to exactly one bucket. No other pod on the same node can assume this role. No long-lived credentials anywhere. Fully auditable through CloudTrail." That's chef's kiss for a cloud security role.

---

## TIER 2 — Differentiators

### 2A. VPC Endpoint Policies / Private EKS API

**Phase: PRE-DEPLOY (cluster and VPC config)**

```
1. Create cluster with private API endpoint
   - eksctl config:
     vpc:
       clusterEndpoints:
         publicAccess: false    # no internet access to API
         privateAccess: true    # only VPC-internal access
   
   - This means: kubectl only works from INSIDE the VPC
     (or through a bastion / VPN / SSM session)

2. Create VPC endpoints for AWS services
   - EKS pods need to reach AWS APIs (STS, ECR, S3, CloudWatch)
   - Without endpoints, traffic goes through NAT → internet → AWS
   - With endpoints, traffic stays inside AWS network
   
   - Required endpoints:
     com.amazonaws.REGION.sts          (for IRSA)
     com.amazonaws.REGION.ecr.api      (image pulls)
     com.amazonaws.REGION.ecr.dkr      (image pulls)
     com.amazonaws.REGION.s3            (ECR image layers)
     com.amazonaws.REGION.logs          (CloudWatch)
     com.amazonaws.REGION.ec2           (node registration)

3. Apply endpoint policies (the security part)
   - Each VPC endpoint can have an IAM policy restricting 
     WHICH principals can use it
   - Example: S3 endpoint only allows access to YOUR buckets,
     not arbitrary S3 buckets

4. Verify from inside a pod
   - Traffic should resolve to private IPs, not public endpoints
   - kubectl exec -it test-pod -- nslookup s3.amazonaws.com
     → should return VPC endpoint IP
```

**Why this matters for consulting:** If a client asks "how do we ensure our EKS cluster never talks to the public internet," this is the answer. FedRAMP boundary requirements basically demand this.

### 2B. EKS Access Entries

**Phase: PRE-DEPLOY (cluster auth config)**

```
1. Create cluster with access entry authentication mode
   - eksctl config:
     accessConfig:
       authenticationMode: API_AND_CONFIG_MAP
   
   - This enables the NEW auth model alongside the legacy aws-auth

2. Create access entries (CLI)
   - aws eks create-access-entry \
       --cluster-name anthra-cloud \
       --principal-arn arn:aws:iam::ACCOUNT:role/DevOpsRole \
       --type STANDARD
   
   - Associate a policy:
     aws eks associate-access-policy \
       --cluster-name anthra-cloud \
       --principal-arn arn:aws:iam::ACCOUNT:role/DevOpsRole \
       --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
       --access-scope type=namespace,namespaces=production

3. Why this beats aws-auth ConfigMap
   - aws-auth is a single ConfigMap — one bad edit locks everyone out
   - Access Entries are API-managed, auditable, recoverable
   - Namespace-scoped policies (the old way was all-or-nothing)
```

**Interview ammo:** "I use EKS Access Entries instead of aws-auth because they're auditable through CloudTrail, recoverable through the API, and support namespace-scoped access policies." That tells the interviewer you're current — most people still only know aws-auth.

### 2C. Security Groups for Pods

**Phase: DEPLOY (requires VPC CNI configuration)**

```
1. Enable VPC CNI pod security groups
   - kubectl set env daemonset aws-node \
       -n kube-system ENABLE_POD_ENI=true
   
2. Create a SecurityGroupPolicy resource
   - This is a CRD that maps pods to specific security groups
   - Example: "pods with label app=database get SG-database 
     which only allows port 5432 from SG-backend"

3. Verify traffic isolation
   - Pod A (SG-frontend) tries to hit Pod B (SG-database) on 5432 → DENIED
   - Pod C (SG-backend) tries the same → ALLOWED
```

**This is network microsegmentation at the AWS layer** — it works alongside Kubernetes NetworkPolicies but enforced by VPC, not a CNI plugin. Defense in depth.

---

## TIER 3 — Nice to Have

### 3A. Fargate Profiles — DEPLOY phase
Serverless pods, no node management. Define which namespaces/labels run on Fargate.

### 3B. GuardDuty EKS Runtime Monitoring — RUNTIME phase (enable in AWS console)
Detects cryptomining, privilege escalation, DNS exfil from inside pods.

### 3C. AWS Config Rules — RUNTIME phase (UI + CLI)
Continuous compliance checking: "is encryption enabled? are logs on? is public access disabled?"

---

## The Summary Map

| Control | Phase | Tool |
|---|---|---|
| KMS Envelope Encryption | PRE-DEPLOY | Terraform/eksctl + AWS CLI |
| CloudWatch Audit Logging | PRE-DEPLOY + RUNTIME | eksctl + CloudWatch Console |
| IRSA | PRE-DEPLOY + DEPLOY | AWS CLI + kubectl |
| VPC Private Endpoint | PRE-DEPLOY | Terraform/eksctl |
| EKS Access Entries | PRE-DEPLOY | AWS CLI |
| Security Groups for Pods | DEPLOY | kubectl + AWS Console |
| Fargate | DEPLOY | eksctl config |
| GuardDuty | RUNTIME | AWS Console |
| AWS Config Rules | RUNTIME | AWS Console + CLI |

---

## Where I'll Push Back On You

Don't look at this list and think "I need all 9 before I can call anthra-cloud done." You need **Tier 1 solid with documentation and demo-ready walkthroughs.** Tier 2 adds depth. Tier 3 is icing.

If you deploy anthra-cloud with IRSA + KMS + audit logging working, and you can explain the trust chain, the encryption envelope, and query the audit trail live — that's already ahead of 80% of candidates interviewing for cloud security roles.

Want me to turn this into a Claude-Code architect prompt that builds the Terraform + eksctl config for Tier 1 as a single deployable stack?
---

## Engagement Phases

```
┌─────────────────────────────────────────────────────────────────┐
│                    AWS MIGRATION PHASES                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Phase 1: DESIGN & PLAN (Week 1-2)                             │
│   ─────────────────────────                                     │
│   • Current state assessment                                     │
│   • AWS architecture design                                      │
│   • Choose IaC tool (Terraform vs CloudFormation)                │
│   • Security requirements                                        │
│   • Compliance mapping                                           │
│                                                                  │
│   Phase 2: BUILD & TEST LOCALLY (Week 3-5)                      │
│   ────────────────────────────────                              │
│   • Write IaC templates                                          │
│   • Test with LocalStack                                         │
│   • Security scanning (Checkov, TFsec)                          │
│   • Validate compliance                                          │
│   • Runbook creation                                             │
│                                                                  │
│   Phase 3: DEPLOY TO AWS (Week 6-8)                             │
│   ─────────────────────────                                     │
│   • Deploy to dev/staging                                        │
│   • Security validation                                          │
│   • Performance testing                                          │
│   • Disaster recovery testing                                    │
│   • Production deployment                                        │
│                                                                  │
│   Phase 4: OPTIMIZE & OPERATE (Week 9+)                         │
│   ───────────────────────────────                               │
│   • Cost optimization                                            │
│   • Performance tuning                                           │
│   • Security monitoring                                          │
│   • Continuous compliance                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Design & Plan (Week 1-2)

### Objective

Assess current infrastructure and design secure AWS architecture.

### Step 1.1: Current State Assessment

**Document existing infrastructure:**

```bash
# Create inventory
cat > inventory.yaml <<EOF
applications:
  - name: web-app
    type: nodejs
    users: 10000/day
    current: on-prem VM
    dependencies:
      - postgres-db
      - redis-cache

  - name: api-backend
    type: python
    users: 5000/day
    current: on-prem VM
    dependencies:
      - postgres-db
      - s3-compatible-storage

databases:
  - name: postgres-db
    type: postgresql
    version: "14"
    size: 500GB
    current: on-prem server

storage:
  - name: file-storage
    type: object-storage
    size: 2TB
    current: on-prem NAS
EOF
```

**Security requirements:**
- [ ] Data encryption at rest
- [ ] Data encryption in transit
- [ ] Network isolation (no public internet)
- [ ] Least-privilege IAM
- [ ] Audit logging (CloudTrail)
- [ ] Compliance (SOC 2, PCI-DSS, HIPAA, etc.)

### Step 1.2: Choose IaC Tool

| Factor | Terraform | CloudFormation |
|--------|-----------|----------------|
| **Multi-cloud** | ✅ Yes (AWS, Azure, GCP) | ❌ AWS only |
| **State management** | Remote state (S3, Terraform Cloud) | AWS-managed |
| **Community** | Large, active | AWS-specific |
| **Drift detection** | Manual (`terraform plan`) | AWS Config rules |
| **Testing** | LocalStack, Terratest | LocalStack, TaskCat |
| **Learning curve** | Moderate | Easier if AWS-only |
| **GP recommendation** | For multi-cloud or complex needs | For AWS-only, simpler setups |

**We provide both** - choose based on your needs.

### Step 1.3: AWS Architecture Design

**Example: 3-tier web application**

```
┌─────────────────────────────────────────────────────────────────┐
│                    AWS ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Internet                                                       │
│      │                                                           │
│      ▼                                                           │
│   ┌─────────────────────────────────────────────┐               │
│   │ Route 53 (DNS)                              │               │
│   └─────────────────────────────────────────────┘               │
│      │                                                           │
│      ▼                                                           │
│   ┌─────────────────────────────────────────────┐               │
│   │ CloudFront (CDN) + WAF                      │               │
│   └─────────────────────────────────────────────┘               │
│      │                                                           │
│      ▼                                                           │
│   ┌─────────────────────────────────────────────┐               │
│   │ ALB (Public Subnet)                         │               │
│   │ - us-east-1a, us-east-1b, us-east-1c        │               │
│   └─────────────────────────────────────────────┘               │
│      │                                                           │
│      ▼                                                           │
│   ┌─────────────────────────────────────────────┐               │
│   │ ECS/EKS (Private Subnet)                    │               │
│   │ - Web app containers                        │               │
│   │ - Auto-scaling group                        │               │
│   └─────────────────────────────────────────────┘               │
│      │                                                           │
│      ▼                                                           │
│   ┌─────────────────────────────────────────────┐               │
│   │ RDS PostgreSQL (Private Subnet)             │               │
│   │ - Multi-AZ                                  │               │
│   │ - Encrypted                                 │               │
│   │ - Automated backups                         │               │
│   └─────────────────────────────────────────────┘               │
│                                                                  │
│   ┌─────────────────────────────────────────────┐               │
│   │ S3 (File Storage)                           │               │
│   │ - Versioning enabled                        │               │
│   │ - Encryption enabled                        │               │
│   │ - Public access blocked                     │               │
│   └─────────────────────────────────────────────┘               │
│                                                                  │
│   ┌─────────────────────────────────────────────┐               │
│   │ Security & Monitoring                       │               │
│   │ - CloudTrail (audit logs)                   │               │
│   │ - GuardDuty (threat detection)              │               │
│   │ - Config (compliance)                       │               │
│   │ - CloudWatch (metrics/logs)                 │               │
│   └─────────────────────────────────────────────┘               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 1.4: Create Migration Plan

```markdown
# Migration Plan: Acme Corp

## Scope
- Applications: 3 (web-app, api-backend, admin-portal)
- Databases: 2 (PostgreSQL, Redis)
- Storage: 2TB files

## Timeline
- Week 1-2: Design & planning
- Week 3-5: Build IaC, test locally
- Week 6: Deploy dev environment
- Week 7: Deploy staging environment
- Week 8: Deploy production (cutover weekend)

## Rollback Plan
- Keep on-prem running for 2 weeks post-migration
- Database replication on-prem ← AWS
- DNS failback to on-prem if issues

## Success Criteria
- Zero downtime during cutover
- All security scans pass
- Performance ≥ on-prem baseline
- Cost < projected budget
```

### Week 1-2 Deliverables

- [ ] Current state documented
- [ ] IaC tool selected (Terraform or CloudFormation)
- [ ] AWS architecture designed
- [ ] Migration plan created
- [ ] Security requirements defined
- [ ] Compliance requirements mapped

---

## Phase 2: Build & Test Locally (Week 3-5)

### Objective

Write IaC templates and test with LocalStack before touching AWS.

### Step 2.1: Set Up LocalStack

```bash
# Install LocalStack
pip install localstack awscli-local

# Start LocalStack
docker-compose up -d localstack

# Verify LocalStack is running
localstack status

# Expected output:
# ┌─────────────────────────────────────────────┐
# │ LocalStack Runtime                          │
# ├─────────────────────────────────────────────┤
# │ Running: ✓                                  │
# │ Services: s3, ec2, iam, rds, dynamodb, ...  │
# └─────────────────────────────────────────────┘
```

### Step 2.2: Write IaC Templates

**Option A: Terraform**

```bash
# Use our VPC template
cp terraform/vpc/main.tf ./infrastructure/vpc.tf

# Customize variables
cat > infrastructure/terraform.tfvars <<EOF
project_name       = "acme-corp"
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
enable_flow_logs   = true
EOF

# Initialize Terraform
cd infrastructure
terraform init
```

**Option B: CloudFormation**

```bash
# Use our VPC template
cp cloudformation/vpc/template.yaml ./infrastructure/vpc-stack.yaml

# Customize parameters
cat > infrastructure/parameters.json <<EOF
[
  {
    "ParameterKey": "ProjectName",
    "ParameterValue": "acme-corp"
  },
  {
    "ParameterKey": "VpcCidr",
    "ParameterValue": "10.0.0.0/16"
  },
  {
    "ParameterKey": "EnableFlowLogs",
    "ParameterValue": "true"
  }
]
EOF
```

### Step 2.3: Test with LocalStack

**Terraform + LocalStack:**

```bash
# Deploy to LocalStack
terraform apply \
  -var "environment=localstack" \
  -auto-approve

# Verify VPC created
awslocal ec2 describe-vpcs

# Verify subnets created
awslocal ec2 describe-subnets
```

**CloudFormation + LocalStack:**

```bash
# Deploy to LocalStack
awslocal cloudformation create-stack \
  --stack-name acme-corp-vpc \
  --template-body file://vpc-stack.yaml \
  --parameters file://parameters.json

# Check stack status
awslocal cloudformation describe-stacks \
  --stack-name acme-corp-vpc
```

### Step 2.4: Security Scanning

**Scan Terraform:**

```bash
# Install scanners
pip install checkov
brew install tfsec

# Scan with Checkov
checkov -d infrastructure/

# Scan with TFsec
tfsec infrastructure/

# Expected: PASS all checks
```

**Scan CloudFormation:**

```bash
# Install cfn-lint
pip install cfn-lint

# Scan template
cfn-lint infrastructure/vpc-stack.yaml

# Scan with Checkov (works for CFN too)
checkov -f infrastructure/vpc-stack.yaml
```

### Step 2.5: Create Runbooks

```bash
# Create runbook for RDS failover
cat > runbooks/rds-failover.md <<EOF
# RDS Multi-AZ Failover Procedure

## Trigger
- Primary RDS instance failure
- Planned maintenance

## Automatic Failover
1. AWS detects primary failure
2. Promotes standby to primary (1-2 minutes)
3. Updates DNS (CNAME) to new primary
4. Applications reconnect automatically

## Verification
\`\`\`bash
# Check RDS status
aws rds describe-db-instances --db-instance-identifier acme-corp-db

# Expected: Status = available, Multi-AZ = true
\`\`\`

## Rollback
N/A - Multi-AZ failover is one-way. Create new standby automatically.
EOF
```

### Week 3-5 Deliverables

- [ ] IaC templates written (Terraform or CloudFormation)
- [ ] LocalStack testing passed
- [ ] Security scans passed (Checkov, TFsec, cfn-lint)
- [ ] Runbooks created
- [ ] Peer review completed

---

## Phase 3: Deploy to AWS (Week 6-8)

### Objective

Deploy to real AWS, starting with dev/staging, then production.

### Step 3.1: Deploy Dev Environment

**Terraform:**

```bash
# Configure AWS credentials
export AWS_PROFILE=dev

# Deploy to dev
terraform workspace new dev
terraform apply -var-file="environments/dev.tfvars"

# Verify
terraform show
```

**CloudFormation:**

```bash
# Deploy stack
aws cloudformation create-stack \
  --stack-name acme-corp-dev-vpc \
  --template-body file://vpc-stack.yaml \
  --parameters file://environments/dev-parameters.json \
  --profile dev

# Monitor deployment
aws cloudformation wait stack-create-complete \
  --stack-name acme-corp-dev-vpc \
  --profile dev
```

### Step 3.2: Security Validation

```bash
# Run AWS Config rules
aws configservice put-config-rule \
  --config-rule file://config-rules/vpc-flow-logs-enabled.json

# Check compliance
aws configservice describe-compliance-by-config-rule \
  --config-rule-names vpc-flow-logs-enabled

# Run AWS Security Hub checks
aws securityhub get-findings \
  --filters '{"ResourceType":[{"Value":"AwsEc2Vpc","Comparison":"EQUALS"}]}'
```

### Step 3.3: Deploy Staging Environment

```bash
# Terraform
terraform workspace new staging
terraform apply -var-file="environments/staging.tfvars"

# CloudFormation
aws cloudformation create-stack \
  --stack-name acme-corp-staging-vpc \
  --template-body file://vpc-stack.yaml \
  --parameters file://environments/staging-parameters.json \
  --profile staging
```

### Step 3.4: Disaster Recovery Testing

```bash
# Test RDS failover
aws rds reboot-db-instance \
  --db-instance-identifier acme-corp-staging-db \
  --force-failover

# Expected: Failover completes in 1-2 minutes

# Test snapshot restore
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier acme-corp-staging-db-test \
  --db-snapshot-identifier acme-corp-snapshot-20260212

# Expected: Restore completes in 15-30 minutes
```

### Step 3.5: Production Deployment (Cutover Weekend)

**Friday evening:**

```bash
# 1. Final backup of on-prem databases
pg_dump -h onprem-db -U postgres -F c -f backup-pre-migration.dump

# 2. Deploy production infrastructure
terraform workspace new prod
terraform apply -var-file="environments/prod.tfvars"

# 3. Restore database to RDS
pg_restore -h acme-corp-prod-db.xxxx.us-east-1.rds.amazonaws.com \
  -U postgres -d acme_db backup-pre-migration.dump

# 4. Sync files to S3
aws s3 sync /mnt/onprem-nas/ s3://acme-corp-prod-files/

# 5. Deploy applications
# (ECS/EKS deployment)

# 6. Test end-to-end
curl https://api.acmecorp.com/health
# Expected: 200 OK

# 7. Update DNS (Route 53)
# Point acmecorp.com → AWS ALB

# 8. Monitor for 4 hours
# (Team on-call, ready to rollback)
```

**Rollback plan (if needed):**

```bash
# Revert DNS to on-prem
# Update Route 53 record back to on-prem IP

# Stop AWS applications
# Prevents split-brain writes

# Verify on-prem is serving traffic
curl https://api.acmecorp.com/health
```

**Sunday:**
- Monitor metrics, logs, errors
- Verify all features working
- Keep on-prem online (read-only) for 2 weeks

### Week 6-8 Deliverables

- [ ] Dev environment deployed
- [ ] Staging environment deployed
- [ ] Security validation passed
- [ ] DR testing passed
- [ ] Production deployed
- [ ] Cutover completed
- [ ] Monitoring verified

---

## Phase 4: Optimize & Operate (Week 9+)

### Objective

Optimize costs, performance, and security for long-term operations.

### Cost Optimization

```bash
# Enable AWS Cost Explorer
aws ce get-cost-and-usage \
  --time-period Start=2026-02-01,End=2026-02-28 \
  --granularity MONTHLY \
  --metrics BlendedCost

# Right-size EC2 instances
aws compute-optimizer get-ec2-instance-recommendations

# Review S3 storage classes
aws s3api list-buckets | jq -r '.Buckets[].Name' | while read bucket; do
  aws s3api get-bucket-lifecycle-configuration --bucket $bucket
done

# Enable Reserved Instances/Savings Plans
# (for predictable workloads)
```

### Performance Tuning

```bash
# Monitor RDS performance
aws rds describe-db-instances \
  --db-instance-identifier acme-corp-prod-db \
  | jq '.DBInstances[0].PerformanceInsightsEnabled'

# Monitor ECS/EKS metrics
aws ecs describe-services \
  --cluster acme-corp-prod \
  --services web-app

# Review CloudFront cache hit ratio
aws cloudfront get-distribution-config \
  --id E1234567890ABC
```

### Security Monitoring

```bash
# Enable GuardDuty
aws guardduty create-detector --enable

# Enable Security Hub
aws securityhub enable-security-hub

# Review CloudTrail logs
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --max-results 10

# Set up automated compliance checks
aws config put-config-rule \
  --config-rule file://config-rules/s3-bucket-public-read-prohibited.json
```

---

## IaC Tool Comparison Chart

| Task | Terraform Command | CloudFormation Command |
|------|-------------------|------------------------|
| **Initialize** | `terraform init` | N/A |
| **Plan** | `terraform plan` | `aws cloudformation create-change-set` |
| **Deploy** | `terraform apply` | `aws cloudformation create-stack` |
| **Update** | `terraform apply` | `aws cloudformation update-stack` |
| **Destroy** | `terraform destroy` | `aws cloudformation delete-stack` |
| **Show state** | `terraform show` | `aws cloudformation describe-stacks` |
| **Validate** | `terraform validate` | `aws cloudformation validate-template` |
| **Format** | `terraform fmt` | `cfn-lint` |
| **Security scan** | `checkov -d .` | `checkov -f template.yaml` |
| **Local test** | LocalStack + Terraform | LocalStack + `awslocal` CLI |

---

## Security Checklist

### Network Security

- [ ] VPC with private subnets for workloads
- [ ] Public subnets only for load balancers
- [ ] NAT Gateways for egress (no Internet Gateway in private subnets)
- [ ] VPC Flow Logs enabled
- [ ] Network ACLs deny by default
- [ ] Security Groups least-privilege

### Data Security

- [ ] S3 buckets block public access
- [ ] S3 buckets have versioning enabled
- [ ] S3 buckets encrypted (KMS)
- [ ] RDS encrypted at rest (KMS)
- [ ] RDS encrypted in transit (SSL/TLS)
- [ ] Secrets in AWS Secrets Manager (not hardcoded)

### IAM Security

- [ ] No IAM users with wildcards (`*`)
- [ ] MFA enabled for root account
- [ ] IAM policies follow least privilege
- [ ] Service roles (not user credentials)
- [ ] IAM Access Analyzer enabled

### Logging & Monitoring

- [ ] CloudTrail enabled (all regions)
- [ ] CloudWatch Logs for applications
- [ ] GuardDuty enabled
- [ ] Security Hub enabled
- [ ] Config rules for compliance

---

## Client Communication Templates

### Week 1: Kickoff Email

```
Subject: AWS Migration Kickoff - Week 1

Team,

We're starting the AWS migration project this week. Here's our plan:

Timeline: 8 weeks (design → build → test → deploy)
IaC Tool: [Terraform / CloudFormation]
Go-Live Date: [Cutover weekend date]

Week 1-2 Deliverables:
- Current infrastructure documented
- AWS architecture designed
- Security requirements defined

Next meeting: [Date/time]

Questions? Ping me or join #aws-migration Slack channel.

- [Your name]
```

### Week 6: Pre-Production Checklist

```
Subject: Production Deploy Checklist - Review Required

Team,

Production deployment is scheduled for [Date]. Please review:

✅ Completed:
- Dev environment deployed and tested
- Staging environment deployed and tested
- Security scans passed (Checkov, TFsec)
- DR testing passed (RDS failover < 2 min)

⏰ Pre-Cutover Tasks (Friday evening):
- [ ] Backup on-prem databases
- [ ] Deploy AWS infrastructure
- [ ] Restore databases to RDS
- [ ] Sync files to S3
- [ ] Deploy applications
- [ ] Test end-to-end
- [ ] Update DNS

🔄 Rollback Plan:
- Revert DNS to on-prem
- Keep on-prem running 2 weeks

On-call team: [Names]
War room: #incident-migration

- [Your name]
```

---

## Troubleshooting Guide

### Terraform: State Lock Error

```bash
# Error: Error locking state: Error acquiring the state lock
# Solution: Force unlock (use carefully!)
terraform force-unlock <LOCK_ID>
```

### CloudFormation: Stack Stuck in UPDATE_IN_PROGRESS

```bash
# Check stack events
aws cloudformation describe-stack-events \
  --stack-name acme-corp-vpc

# Cancel update (if safe)
aws cloudformation cancel-update-stack \
  --stack-name acme-corp-vpc
```

### LocalStack: Service Not Available

```bash
# Check LocalStack logs
docker logs localstack

# Restart LocalStack
docker-compose restart localstack

# Verify services
localstack status services
```

### RDS: Can't Connect from ECS

```bash
# Check security group rules
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx

# Verify RDS is in private subnet
aws rds describe-db-instances \
  --db-instance-identifier acme-corp-db \
  | jq '.DBInstances[0].DBSubnetGroup.Subnets'

# Check NACLs
aws ec2 describe-network-acls \
  --filters "Name=vpc-id,Values=vpc-xxxxx"
```

---

*Part of the Iron Legion - CKS | CKA | CCSP Certified Standards*
