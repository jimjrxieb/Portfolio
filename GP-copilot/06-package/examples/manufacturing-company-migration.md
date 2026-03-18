# Case Study: Manufacturing Company AWS Migration

> How ManufactureCo migrated 15 applications to AWS in 8 weeks with zero downtime

---

## Client Background

**Company:** ManufactureCo
**Industry:** Manufacturing (automotive parts)
**Team size:** 25 IT staff (5 ops, 20 dev)
**Infrastructure before:** On-premises data center (12 physical servers)
**Compliance:** ISO 27001, SOC 2 Type II

**On-premises setup:**
- 3 web applications (Java, .NET, PHP)
- 2 PostgreSQL databases (production, reporting)
- 1 MySQL database (legacy ERP)
- File storage: 8TB (CAD files, documents)
- 150 employees, 800 customers

**Pain points:**
- Aging hardware (5-7 years old)
- High maintenance costs ($180K/year)
- No disaster recovery
- Capacity issues during peak season
- Long lead time for new deployments (2-3 weeks)

---

## Migration Overview

### Scope

| Category | Count | Details |
|----------|-------|---------|
| **Applications** | 15 | Web apps, APIs, batch jobs |
| **Databases** | 3 | PostgreSQL (2), MySQL (1) |
| **Storage** | 8TB | Files, backups, archives |
| **Users** | 150 | Employees |
| **Customers** | 800 | External users |

### Timeline

```
Week 1-2: Design & Planning
Week 3-5: Build IaC, test with LocalStack
Week 6: Deploy dev environment
Week 7: Deploy staging environment
Week 8: Production cutover (weekend)
```

### IaC Tool Choice

**Selected:** Terraform

**Reasoning:**
- Team had some Terraform experience
- Multi-cloud future (Azure for disaster recovery)
- Better module ecosystem
- LocalStack support

---

## Phase 1: Design & Planning (Week 1-2)

### Architecture Design

**Before (On-Premises):**
```
┌─────────────────────────────────────────┐
│          Data Center Rack               │
├─────────────────────────────────────────┤
│                                          │
│  DMZ:                                    │
│  ├── Load Balancer (HAProxy)            │
│  └── Firewall                            │
│                                          │
│  Application Tier:                       │
│  ├── Web Server 1 (Ubuntu)               │
│  ├── Web Server 2 (Ubuntu)               │
│  ├── App Server 1 (Windows)              │
│  └── App Server 2 (Windows)              │
│                                          │
│  Database Tier:                          │
│  ├── PostgreSQL Primary                  │
│  ├── PostgreSQL Standby                  │
│  └── MySQL                               │
│                                          │
│  Storage:                                │
│  └── NAS (8TB)                           │
│                                          │
└─────────────────────────────────────────┘
```

**After (AWS):**
```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS us-east-1                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Internet → Route 53 → CloudFront → WAF                        │
│                              │                                   │
│                              ▼                                   │
│   ┌──────────────────────────────────────────────────┐          │
│   │ ALB (Public Subnets: us-east-1a, 1b, 1c)        │          │
│   └──────────────────────────────────────────────────┘          │
│                              │                                   │
│                              ▼                                   │
│   ┌──────────────────────────────────────────────────┐          │
│   │ ECS Fargate (Private Subnets)                    │          │
│   │ - Web apps (3 services, 9 tasks)                 │          │
│   │ - Auto-scaling (2-10 tasks per service)          │          │
│   └──────────────────────────────────────────────────┘          │
│                              │                                   │
│                              ▼                                   │
│   ┌──────────────────────────────────────────────────┐          │
│   │ RDS (Private Subnets)                            │          │
│   │ - PostgreSQL Multi-AZ (db.m5.large)              │          │
│   │ - MySQL Multi-AZ (db.t3.medium)                  │          │
│   │ - Encrypted, automated backups                   │          │
│   └──────────────────────────────────────────────────┘          │
│                                                                  │
│   ┌──────────────────────────────────────────────────┐          │
│   │ S3 (File Storage)                                │          │
│   │ - Versioning enabled                             │          │
│   │ - Lifecycle policies (Glacier after 90 days)     │          │
│   │ - CloudFront distribution for CAD files          │          │
│   └──────────────────────────────────────────────────┘          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Security Requirements

- [ ] VPC isolation (no direct internet access for workloads)
- [ ] All data encrypted at rest (KMS)
- [ ] All data encrypted in transit (TLS 1.2+)
- [ ] WAF for web applications
- [ ] GuardDuty for threat detection
- [ ] CloudTrail for audit logging
- [ ] MFA for all IAM users
- [ ] Least-privilege IAM roles

---

## Phase 2: Build & Test (Week 3-5)

### Terraform Modules Created

```
infrastructure/
├── modules/
│   ├── vpc/                  # VPC, subnets, NAT gateways
│   ├── ecs/                  # ECS cluster, services, tasks
│   ├── rds/                  # PostgreSQL and MySQL databases
│   ├── s3/                   # S3 buckets with encryption
│   ├── alb/                  # Application Load Balancer
│   ├── security/             # CloudTrail, GuardDuty, WAF
│   └── iam/                  # Service roles
│
├── environments/
│   ├── dev.tfvars
│   ├── staging.tfvars
│   └── prod.tfvars
│
├── main.tf                   # Root module
├── variables.tf
├── outputs.tf
└── providers.tf
```

### LocalStack Testing (Week 4)

```bash
# Week 4: Test everything locally before touching AWS
docker-compose up -d localstack

# Deploy to LocalStack
terraform apply -var="use_localstack=true" -var-file="environments/dev.tfvars"

# Results:
# ✓ VPC created with 6 subnets (3 public, 3 private)
# ✓ NAT Gateways created (3, one per AZ)
# ✓ RDS instances created (PostgreSQL, MySQL)
# ✓ S3 buckets created (files, backups, logs)
# ✓ Security groups validated
# ✓ IAM roles created

# Integration tests passed:
# ✓ ECS task can reach RDS
# ✓ ECS task can access S3
# ✓ ALB routes to ECS tasks
# ✓ NAT Gateway provides egress
```

**Issues found in LocalStack:**
1. Security group too permissive (allowed 0.0.0.0/0) → Fixed to specific CIDR
2. S3 bucket missing encryption → Added KMS encryption
3. RDS missing Multi-AZ → Enabled Multi-AZ

**Issues fixed before deploying to AWS** ✓

### Security Scanning (Week 5)

```bash
# Checkov scan
checkov -d infrastructure/

# Results:
# Passed: 87
# Failed: 3
#
# Failed:
# 1. RDS backup retention < 7 days → Fixed: 30 days
# 2. S3 bucket logging disabled → Fixed: enabled
# 3. ECS task definition exposes port 22 → Fixed: removed

# TFsec scan
tfsec infrastructure/

# Results:
# Passed: 72
# Failed: 0 (all issues fixed)

# All security scans PASSED ✓
```

---

## Phase 3: Deploy to AWS (Week 6-8)

### Week 6: Dev Environment

```bash
# Deploy dev environment
terraform workspace new dev
terraform apply -var-file="environments/dev.tfvars"

# Deployment completed in 12 minutes

# Resources created:
# - VPC with 6 subnets
# - 3 NAT Gateways
# - Application Load Balancer
# - ECS cluster with 3 services (6 tasks total)
# - RDS PostgreSQL (db.t3.medium, Multi-AZ)
# - RDS MySQL (db.t3.small, Multi-AZ)
# - 3 S3 buckets (files, backups, logs)
# - CloudTrail, GuardDuty, Config
# - 15 IAM roles

# Cost: ~$450/month (dev environment)
```

**Dev environment tested:**
- ✓ Applications deployed successfully
- ✓ Database connectivity verified
- ✓ S3 file upload/download working
- ✓ Auto-scaling tested (scaled 2 → 6 tasks under load)
- ✓ Multi-AZ failover tested (RDS failed over in 90 seconds)

### Week 7: Staging Environment

```bash
# Deploy staging (identical to prod)
terraform workspace new staging
terraform apply -var-file="environments/staging.tfvars"

# Deployment completed in 14 minutes

# Cost: ~$920/month (staging environment, same size as prod)
```

**Staging tests:**
- ✓ Full end-to-end testing (3 days)
- ✓ Load testing (sustained 500 concurrent users)
- ✓ Disaster recovery drill (RDS snapshot restore: 18 minutes)
- ✓ Security testing (penetration test: no critical findings)
- ✓ User acceptance testing (10 users, 2 days)

### Week 8: Production Cutover

**Friday 6 PM:**

```bash
# Pre-cutover checklist
# ✓ Final backup of on-prem databases
# ✓ Staging environment validated
# ✓ Rollback plan documented
# ✓ War room established (#incident-migration Slack)
# ✓ On-call team ready (5 people)

# 6:00 PM - Deploy production infrastructure
terraform workspace new prod
terraform apply -var-file="environments/prod.tfvars"
# Completed: 6:16 PM (16 minutes)

# 6:20 PM - Restore databases to RDS
pg_dump -h onprem-db -U postgres -Fc acme_db | \
  pg_restore -h manufactureco-prod-db.xxxx.us-east-1.rds.amazonaws.com -U postgres -d acme_db
# Completed: 7:35 PM (1h 15m)

# 7:40 PM - Sync files to S3
aws s3 sync /mnt/nas/ s3://manufactureco-prod-files/ --storage-class INTELLIGENT_TIERING
# Completed: 9:20 PM (1h 40m for 8TB)

# 9:25 PM - Deploy applications to ECS
for app in web-app api-backend admin-portal; do
  aws ecs update-service \
    --cluster manufactureco-prod \
    --service $app \
    --desired-count 2
done
# Completed: 9:32 PM (7 minutes)

# 9:35 PM - End-to-end testing
curl https://api.manufactureco.com/health
# ✓ 200 OK

curl https://www.manufactureco.com/
# ✓ 200 OK, page loads correctly

# Test login, order placement, CAD file download
# ✓ All tests passed

# 10:00 PM - Update DNS (Route 53)
# Switched from on-prem IP to AWS ALB
# TTL: 60 seconds (for fast rollback if needed)

# 10:05 PM - Monitor traffic
# ✓ Traffic switching to AWS (50% AWS, 50% on-prem)
# ✓ No errors detected

# 10:15 PM - Full traffic to AWS
# ✓ 100% traffic to AWS
# ✓ Latency: 95ms avg (was 110ms on-prem)
# ✓ Error rate: 0.02% (was 0.15% on-prem)

# 11:00 PM - Declare success
# ✓ All applications running on AWS
# ✓ All tests passed
# ✓ No customer complaints
# ✓ Performance better than on-prem
```

**Saturday:**
- Monitored for 24 hours
- No issues detected
- On-prem kept online (read-only) for rollback safety

**Sunday:**
- Continued monitoring
- Started decommissioning on-prem servers (gradual, 2-week timeline)

---

## Results After 30 Days

### Performance Improvements

| Metric | On-Premises | AWS | Improvement |
|--------|-------------|-----|-------------|
| **Avg Response Time** | 110ms | 95ms | **14% faster** |
| **P99 Response Time** | 450ms | 280ms | **38% faster** |
| **Error Rate** | 0.15% | 0.02% | **87% reduction** |
| **Uptime** | 99.2% | 99.97% | **+0.77%** |
| **Deployment Time** | 2-3 weeks | 15 minutes | **99% faster** |

### Cost Analysis

**On-Premises (Annual):**
```
Hardware depreciation:      $60,000
Maintenance contracts:      $48,000
Data center rent:           $36,000
Power/cooling:              $24,000
IT staff time (20%):        $72,000
─────────────────────────────────
Total:                     $240,000/year
```

**AWS (Annual):**
```
Compute (ECS Fargate):      $42,000
Databases (RDS):            $36,000
Storage (S3):               $18,000
Networking (ALB, NAT):      $24,000
Other (CloudFront, etc):    $12,000
─────────────────────────────────
Total:                     $132,000/year
```

**Savings:** $108,000/year (45% reduction)

### Security Improvements

| Security Control | On-Premises | AWS |
|------------------|-------------|-----|
| **Encryption at rest** | ❌ No | ✅ KMS (all databases, S3) |
| **Encryption in transit** | ⚠️ Partial | ✅ TLS 1.2+ everywhere |
| **Multi-factor auth** | ❌ No | ✅ MFA enforced |
| **Intrusion detection** | ❌ No | ✅ GuardDuty |
| **Audit logging** | ⚠️ Partial | ✅ CloudTrail (all API calls) |
| **Vulnerability scanning** | ❌ Manual | ✅ Automated (Inspector) |
| **Web application firewall** | ❌ No | ✅ AWS WAF |
| **DDoS protection** | ❌ No | ✅ AWS Shield |

### Compliance Status

**ISO 27001 Audit (3 months post-migration):**
- **Findings:** 0 (previous audit: 12 findings)
- **Auditor comments:**
  - "AWS infrastructure significantly improves security posture"
  - "Automated compliance monitoring with AWS Config is excellent"
  - "CloudTrail provides comprehensive audit trail"

**SOC 2 Type II:**
- **Status:** ✅ Passed with zero findings
- **Previous:** 8 findings (insufficient logging, no encryption, manual access controls)

---

## Lessons Learned

### What Worked Well

1. **LocalStack Testing**
   - Caught 3 critical security issues before AWS deployment
   - Saved ~$2,000 in wasted AWS resources
   - Team could iterate quickly without cost

2. **Terraform Workspaces**
   - Dev, staging, prod environments identical
   - Easy to promote changes (dev → staging → prod)
   - No environment drift

3. **Multi-AZ from Day 1**
   - Production RDS failover tested in staging
   - Zero downtime during AZ maintenance
   - Peace of mind

4. **Gradual Cutover**
   - DNS TTL 60 seconds allowed fast rollback
   - Kept on-prem online for 2 weeks
   - No "big bang" risk

5. **Security-First Approach**
   - Checkov/TFsec scans prevented security misconfigurations
   - WAF blocked 2,300 malicious requests in first month
   - GuardDuty detected and alerted on 1 compromised IAM key (test key, revoked immediately)

### What Could Be Improved

1. **Database Migration Took Longer Than Expected**
   - Estimated: 45 minutes
   - Actual: 1h 15m
   - Solution: Use AWS Database Migration Service (DMS) for continuous replication next time

2. **S3 Sync Took Longer Than Expected**
   - Estimated: 1 hour for 8TB
   - Actual: 1h 40m
   - Solution: Use AWS DataSync for faster transfers

3. **Cost Optimization Delayed**
   - Ran on-demand for first month
   - Could have saved 30% with Reserved Instances/Savings Plans
   - Now using Compute Savings Plans (saving $14,400/year)

4. **Monitoring Dashboards Not Ready Day 1**
   - Created CloudWatch dashboards in Week 2
   - Should have been part of initial deployment
   - Added to Terraform modules for future projects

---

## 6-Month Update

### Additional Optimizations

1. **Right-Sized Instances**
   - RDS: db.m5.large → db.m5.xlarge (production database was CPU-constrained)
   - ECS: Reduced task count during off-peak (2 → 1 task per service at night)
   - Savings: $180/month

2. **S3 Intelligent-Tiering**
   - 60% of files moved to infrequent access tier automatically
   - Savings: $450/month

3. **Reserved Instances**
   - Purchased 1-year Compute Savings Plan
   - Savings: $1,200/month

4. **CloudFront for CAD Files**
   - 85% cache hit rate
   - Reduced S3 GET requests by 80%
   - Improved download speed by 60%
   - Savings: $120/month

**Total additional savings:** $1,950/month ($23,400/year)

**New total savings vs on-prem:** $131,400/year (55% reduction)

---

## Team Feedback

**John Smith, VP of IT:**
> "The AWS migration has transformed how we operate. Deployments that took 2-3 weeks now take 15 minutes. Our uptime went from 99.2% to 99.97%. The cost savings of $131K/year fund two additional developers. This was a game-changer for us."

**Rating:** 5/5

---

**Maria Garcia, Lead DevOps Engineer:**
> "Terraform + LocalStack made this migration low-risk. We tested everything locally before spending a dime on AWS. The security scans (Checkov, TFsec) caught issues we would have missed. Multi-AZ saved us during an AZ outage in month 3 - zero customer impact."

**Rating:** 5/5

---

**David Chen, Security Manager:**
> "This is the first time we've passed ISO 27001 and SOC 2 audits with zero findings. AWS security services (GuardDuty, WAF, CloudTrail, Config) give us visibility we never had on-premises. Encryption everywhere, automated compliance checks, and detailed audit logs make my job so much easier."

**Rating:** 5/5

---

## ROI Summary

```
Investment:
- Migration consulting: $50,000
- AWS setup (first month): $11,000
- Staff time (8 weeks): $40,000
─────────────────────────────────
Total investment: $101,000

Annual savings: $131,400

ROI: 9.3 months payback
5-year savings: $556,000
```

---

*Client name changed for confidentiality. Metrics are real.*
