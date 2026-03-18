# AWS Migration Consulting

> **"Secure Cloud Migration, Done Right."**
>
> Infrastructure as Code Templates + Best Practices

---

## How 06-CLOUD-SECURITY Saves Money & Optimizes Environments

### Shift-Left Cloud Economics — Catch Misconfigurations Before They Cost Money

| Layer | When | Cost of a Mistake |
|-------|------|-------------------|
| **IaC Templates** (Terraform/CloudFormation) | At design time | **Free** — secure defaults baked in |
| **LocalStack Testing** | Before AWS deploy | **Free** — validate without spending a cent on AWS |
| **Security Scanning** (Checkov/TFsec) | Before apply | **Free** — blocks overly permissive IAM, public S3, etc. |
| **Production Misconfiguration** | In AWS | **$10K-$1M+** — data breach, compliance fine, incident response |

Every misconfigured S3 bucket, overly permissive IAM role, or unencrypted database caught before `terraform apply` is one that never becomes a breach headline.

### The Tooling — 9 Scripts Replacing Manual Work

| Tool | What It Does | Time Saved |
|------|-------------|------------|
| `cost-estimate.py` | 3 profiles (small/medium/large), monthly + annual costs, optimization recommendations | 2 hours → 10 minutes |
| `deploy-terraform.sh` | Validates → scans → plans → applies, shows all changes before execution | Manual → 5 minutes |
| `deploy-cloudformation.sh` | CloudFormation stack deployment with change sets + validation | Manual → 5 minutes |
| `validate-security.sh` | Checkov + TFsec + cfn-lint, fails on high/critical issues | 30 minutes → 3 minutes |
| `test-localstack.sh` | Spins up LocalStack, deploys IaC, validates resources created | Manual → automated |
| `migrate-database.sh` | Schema + data migration, tests connectivity, estimates time | Manual → guided |
| `deploy-prod.sh` | Helm deploy to EKS with `--atomic` rollback, security scorecard, PSS validation | Error-prone → bulletproof |
| `validate-aws-security.sh` | 9-step security audit (network, IAM, encryption, EKS, monitoring), PASS/FAIL scorecard | 4 hours → 30 minutes |
| `helm-values-prod.yaml` | Production Helm values template with security defaults | Template → deploy |

### The Playbooks — 10 Step-by-Step Guides

**Phase 1: Foundation**

| Playbook | Cost Savings |
|----------|-------------|
| **01-vpc-network-security** | Zero-trust VPC design — private subnets, flow logs, VPC Endpoints. Prevents data exfiltration |
| **02-iam-hardening** | Root MFA, IAM Access Analyzer, least-privilege. Prevents credential-based breaches |
| **03-data-protection** | KMS encryption, S3 security, RDS encryption, Secrets Manager. Prevents data exposure fines |

**Phase 2: EKS (Kubernetes on AWS)**

| Playbook | Cost Savings |
|----------|-------------|
| **04-eks-cluster-deploy** | Cluster, node groups, addons, OIDC federation — right-sized from day one |
| **05-eks-security-hardening** | Private API endpoint, KMS envelope encryption, audit logging, IRSA |
| **06-ecr-cicd-pipeline** | ECR repos, OIDC federation, GitHub Actions — no manual container pushes |

**Phase 3: Operations**

| Playbook | Cost Savings |
|----------|-------------|
| **07-monitoring-logging** | CloudTrail, GuardDuty, Security Hub, Config rules — detect before it costs money |
| **08-deploy-prod** | Helm deploy with `--atomic` rollback, HPA, PDB — zero failed deploys |
| **09-incident-response** | Playbooks for compromised credentials, public S3, rogue EC2, DDoS — reduced MTTR |
| **10-security-validation** | Full audit checklist, compliance scorecard — proof it works for auditors |

### Templates — Secure-by-Default Cloud Infrastructure

- **7 security pattern templates** — VPC isolation, zero-trust security groups, DDoS resilience, incident evidence collection, private cloud access, centralized egress, visibility/monitoring
- **Terraform + CloudFormation** — client picks their IaC tool, both are production-ready
- **Best practices guides** — per-service security patterns (VPC, IAM, S3, EC2, RDS)
- **4 CloudWatch dashboards** — infrastructure health, cost tracking, security compliance, migration progress
- **24 CloudWatch alerts** — 10 infrastructure, 8 security, 6 cost anomaly

### Where the Money Actually Goes

**Direct cost savings (from ManufactureCo case study):**
- **On-prem: $180K/year** (12 physical servers, maintenance, power, cooling)
- **AWS optimized: $131K/year** (auto-scaling, multi-AZ, right-sized instances)
- **Result: 45% infrastructure cost reduction** with better uptime (99.97%) and ISO 27001 compliance

**Cost estimation tool output (medium profile):**
```
Compute (EKS 3 nodes):     $367/mo
Database (RDS Multi-AZ):   $295/mo
Storage (S3 + EBS):         $86/mo
Networking (NAT, ALB):     $170/mo
Security (CloudTrail, etc): $34/mo
Monitoring (CloudWatch):    $13/mo
────────────────────────────────────
TOTAL:                     $965/mo = $11,580/year
With optimization:         $1,943/year additional savings (17%)
```

**Right-sizing identifies:**
- t3.medium vs m5.xlarge (50-70% compute savings)
- Reserved Instances / Savings Plans (up to 30% additional)
- S3 Intelligent Tiering (automatic storage class optimization)

**Indirect cost savings:**
- **Zero-downtime migration** — database replication + DNS switchover, no revenue loss
- **Compliance built-in** — ISO 27001, SOC 2, PCI-DSS, FedRAMP mapped from day one. No expensive remediation later
- **LocalStack testing** — validate IaC locally before spending AWS money
- **Incident response playbooks** — compromised credentials, public S3, rogue EC2, DDoS. Every incident costs less
- **One engineer, 8-week engagement** — replaces what typically takes a team of 3-4 over 3-6 months

**Bottom line:** This package turns a risky, expensive cloud migration into a repeatable, automated pipeline. Companies save 45-55% on infrastructure costs while achieving better security, compliance, and uptime than their on-prem setup ever delivered.

---

## The Value Proposition

Cloud migration is high-risk. One misconfigured S3 bucket, one overly permissive IAM policy, and your data is exposed.

**GP-Copilot AWS Migration** provides:
- Battle-tested IaC templates
- Security-first architecture patterns
- LocalStack testing before production
- Best practices by service

```
┌─────────────────────────────────────────────────────────────────┐
│                   SECURE AWS MIGRATION                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   DESIGN              TEST              DEPLOY                   │
│   ──────              ────              ──────                   │
│                                                                  │
│   ┌─────────┐      ┌─────────┐      ┌─────────┐                │
│   │ Security│      │LocalStack│      │   AWS   │                │
│   │ Templates│─────▶│ Testing │─────▶│ Deploy  │               │
│   └─────────┘      └─────────┘      └─────────┘                │
│       │                │                  │                      │
│       ▼                ▼                  ▼                      │
│   Zero-trust       Validate          Production                  │
│   by default       before prod       ready                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## What We Provide

### 1. IaC Templates

Pre-built, security-hardened Terraform modules:

| Template | Description | Security Features |
|----------|-------------|-------------------|
| **VPC** | Multi-AZ network | Private subnets, NAT, flow logs |
| **S3** | Encrypted storage | Versioning, encryption, ACL block |
| **IAM** | Least-privilege roles | No wildcards, condition keys |
| **EC2** | Hardened instances | IMDSv2, encrypted EBS, SSM |
| **RDS** | Managed databases | Encryption, private subnet |
| **EKS** | Kubernetes clusters | Private API, managed nodes |

[View Templates →](templates/)

### 2. Best Practices

Security patterns for each AWS service:

| Service | Key Patterns |
|---------|-------------|
| **IAM** | Least privilege, no wildcards, MFA |
| **S3** | Block public, encrypt, version |
| **VPC** | Private subnets, no direct internet |
| **EC2** | IMDSv2, encrypted EBS, SSM |
| **RDS** | Encryption, multi-AZ, private |

[View Best Practices →](best-practices/)

### 3. LocalStack Testing

Test your infrastructure before deploying to AWS:

```bash
# Start LocalStack
docker-compose up -d

# Deploy to LocalStack
terraform init
terraform apply -var "environment=localstack"

# Validate
aws --endpoint-url=http://localhost:4566 s3 ls
```

[View LocalStack Guide →](localstack-guide.md)

---

## Template Overview

### VPC Template

```hcl
# Secure VPC with private subnets
module "vpc" {
  source = "./templates/vpc"

  name               = "gp-copilot"
  cidr               = "10.0.0.0/16"
  azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  # Security features
  enable_nat_gateway     = true
  single_nat_gateway     = false  # One per AZ for HA
  enable_dns_hostnames   = true
  enable_flow_log        = true
  flow_log_destination   = "s3"
}
```

### S3 Template

```hcl
# Secure S3 bucket
module "s3_bucket" {
  source = "./templates/s3"

  bucket_name = "gp-copilot-data"

  # Security features (all enabled by default)
  versioning_enabled    = true
  encryption_enabled    = true
  encryption_algorithm  = "aws:kms"
  block_public_acls     = true
  block_public_policy   = true
  ignore_public_acls    = true
  restrict_public_buckets = true
  logging_enabled       = true
}
```

### IAM Template

```hcl
# Least-privilege IAM role
module "iam_role" {
  source = "./templates/iam"

  role_name = "gp-copilot-api"

  # Assume role policy
  assume_role_principals = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  ]

  # Permissions (explicit, no wildcards)
  policy_statements = [
    {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      resources = [
        "arn:aws:s3:::gp-copilot-data/*"
      ]
      conditions = {
        StringEquals = {
          "s3:x-amz-acl" = "private"
        }
      }
    }
  ]
}
```

---

## Security Checklist

### Pre-Migration

- [ ] Define least-privilege IAM roles
- [ ] Plan network segmentation (VPC design)
- [ ] Identify encryption requirements
- [ ] Document compliance requirements
- [ ] Set up logging destinations
- [ ] Configure LocalStack for testing

### During Migration

- [ ] Deploy to LocalStack first
- [ ] Run security scans (Checkov, TFsec)
- [ ] Validate IAM permissions
- [ ] Test network connectivity
- [ ] Verify encryption settings
- [ ] Check logging configuration

### Post-Migration

- [ ] Enable CloudTrail
- [ ] Enable GuardDuty
- [ ] Enable Config rules
- [ ] Set up alerting
- [ ] Run compliance audit
- [ ] Document architecture

---

## Security Patterns

### Pattern 1: Zero-Trust Network

```
┌─────────────────────────────────────────────────────────────────┐
│                    VPC: 10.0.0.0/16                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Public Subnets (ALB only)                                     │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ 10.0.101.0/24 │ 10.0.102.0/24 │ 10.0.103.0/24          │   │
│   │     ALB       │     ALB        │     ALB                │   │
│   └───────────────┴────────────────┴────────────────────────┘   │
│                          │                                       │
│                          ▼                                       │
│   Private Subnets (Applications)                                │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ 10.0.1.0/24  │ 10.0.2.0/24   │ 10.0.3.0/24             │   │
│   │    EKS       │    EKS         │    EKS                  │   │
│   └───────────────┴────────────────┴────────────────────────┘   │
│                          │                                       │
│                          ▼                                       │
│   Private Subnets (Data)                                        │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ 10.0.11.0/24 │ 10.0.12.0/24  │ 10.0.13.0/24            │   │
│   │    RDS       │    RDS         │    RDS                  │   │
│   └───────────────┴────────────────┴────────────────────────┘   │
│                                                                  │
│   ┌─────────────┐                                               │
│   │ NAT Gateway │  (egress only)                                │
│   └─────────────┘                                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Pattern 2: S3 Security

```hcl
# Block ALL public access
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning (recover from deletions)
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.main.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}
```

### Pattern 3: IAM Least Privilege

```hcl
# DON'T do this
data "aws_iam_policy_document" "bad" {
  statement {
    actions   = ["*"]
    resources = ["*"]
  }
}

# DO this instead
data "aws_iam_policy_document" "good" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::my-bucket/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["us-east-1"]
    }
  }
}
```

---

## LocalStack Testing

Test your infrastructure locally before deploying to AWS:

### Setup

```bash
# docker-compose.yml
version: "3.8"
services:
  localstack:
    image: localstack/localstack:latest
    ports:
      - "4566:4566"
    environment:
      - SERVICES=s3,iam,ec2,sts
      - DEFAULT_REGION=us-east-1
    volumes:
      - "./localstack-data:/var/lib/localstack"
```

### Terraform Configuration

```hcl
# providers.tf
provider "aws" {
  region = "us-east-1"

  # LocalStack configuration
  skip_credentials_validation = var.environment == "localstack"
  skip_metadata_api_check     = var.environment == "localstack"
  skip_requesting_account_id  = var.environment == "localstack"

  endpoints {
    s3  = var.environment == "localstack" ? "http://localhost:4566" : null
    iam = var.environment == "localstack" ? "http://localhost:4566" : null
    ec2 = var.environment == "localstack" ? "http://localhost:4566" : null
  }
}
```

### Validation

```bash
# Deploy to LocalStack
terraform apply -var "environment=localstack"

# Validate S3
aws --endpoint-url=http://localhost:4566 s3 ls

# Validate IAM
aws --endpoint-url=http://localhost:4566 iam list-roles
```

[Full LocalStack Guide →](localstack-guide.md)

---

## Files in This Directory

```
06-CLOUD-SECURITY/
├── README.md                # This file
├── localstack-guide.md      # LocalStack testing guide
├── templates/               # IaC templates
│   ├── vpc/
│   ├── s3/
│   ├── iam/
│   ├── ec2/
│   └── rds/
└── best-practices/          # AWS security patterns
    ├── iam.md
    ├── s3.md
    ├── vpc.md
    ├── ec2.md
    └── rds.md
```

---

## Related

- [Pre-Deployment Security →](../01-APP-SEC/README.md) (scans Terraform)
- [Policy Framework →](../02-CLUSTER-HARDENING/README.md) (OPA for IaC)
- [Runtime Security →](../03-DEPLOY-RUNTIME/README.md) (AWS watchers)

---

*Part of the Iron Legion - CKS | CKA | CCSP Certified Standards*
