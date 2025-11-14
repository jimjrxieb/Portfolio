# Method 2: Terraform + LocalStack - Deployment Results

**Date:** November 14, 2025
**Status:** ✅ Core Infrastructure Deployed (Partial Success)

---

## 🎯 Summary

Successfully deployed Portfolio core storage infrastructure to LocalStack using Terraform!

**Deployment Stats:**
- ✅ **7 out of 16 resources** created successfully (44%)
- 🚀 **DynamoDB + SQS fully operational**
- ⚠️ S3, EventBridge, CloudWatch need additional configuration

---

## ✅ What Worked

### 1. LocalStack Installation
```bash
cd infrastructure/addons/localstack
./install.sh
# Pod running successfully in localstack namespace
```

### 2. Terraform Initialization & Planning
```bash
cd infrastructure/method2-terraform-localstack
terraform init -upgrade
terraform plan  # Successfully planned 16 resources
```

### 3. Core Resources Created

#### **DynamoDB Tables (3/3)** ✅
```bash
aws dynamodb list-tables --endpoint-url=http://localhost:4566

# Tables Created:
- portfolio-document-registry
- portfolio-embedding-chunks
- portfolio-ingestion-jobs
```

#### **SQS Queues (3/3)** ✅
```bash
aws sqs list-queues --endpoint-url=http://localhost:4566

# Queues Created:
- portfolio-ingestion-queue
- portfolio-embedding-queue
- portfolio-ingestion-dlq (dead letter queue)
```

#### **SQS Redrive Policy (1/1)** ✅
- Configured dead letter queue for failed message handling

---

## ❌ What Didn't Work (Yet)

### 1. S3 Buckets (0/3) - DNS Resolution Issue
**Error:**
```
dial tcp: lookup portfolio-raw.localhost on DNS: no such host
```

**Root Cause:**
- Terraform AWS provider uses virtual hosted-style URLs by default
- LocalStack needs path-style access enabled

**Fix Required:**
```hcl
# In main.tf, add to provider "aws" block:
s3_use_path_style           = true
s3_force_path_style         = true
```

### 2. EventBridge Rules (0/2) - Service Not Enabled
**Error:**
```
Service 'events' is not enabled. Please check your 'SERVICES' configuration variable.
```

**Root Cause:**
LocalStack deployment only enables: `s3,dynamodb,sqs`

**Fix Required:**
Update LocalStack deployment env:
```yaml
- name: SERVICES
  value: "s3,dynamodb,sqs,events,logs,cloudwatch"
```

### 3. CloudWatch Log Groups (0/3) - Service Not Enabled
**Error:**
```
Service 'logs' is not enabled.
```

**Same fix as EventBridge above.**

---

## 📊 Resource Verification

### Check DynamoDB Tables

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# List tables
aws dynamodb list-tables --endpoint-url=$AWS_ENDPOINT_URL

# Describe a table
aws dynamodb describe-table \
  --table-name portfolio-document-registry \
  --endpoint-url=$AWS_ENDPOINT_URL
```

### Check SQS Queues

```bash
# List queues
aws sqs list-queues --endpoint-url=$AWS_ENDPOINT_URL

# Get queue attributes
aws sqs get-queue-attributes \
  --queue-url http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/portfolio-ingestion-queue \
  --attribute-names All \
  --endpoint-url=$AWS_ENDPOINT_URL
```

### Test SQS Message

```bash
# Send test message
aws sqs send-message \
  --queue-url http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/portfolio-ingestion-queue \
  --message-body "Test ingestion job" \
  --endpoint-url=$AWS_ENDPOINT_URL

# Receive messages
aws sqs receive-message \
  --queue-url http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/portfolio-ingestion-queue \
  --endpoint-url=$AWS_ENDPOINT_URL
```

---

## 🔧 How to Replicate (Your Turn!)

### Prerequisites
1. ✅ LocalStack running: `kubectl get pods -n localstack`
2. ✅ Port forward active: `kubectl port-forward -n localstack svc/localstack 4566:4566`
3. ✅ AWS CLI installed
4. ✅ Terraform installed

### Step-by-Step Deployment

#### 1. Start LocalStack Port Forward
```bash
# In one terminal, keep this running:
kubectl port-forward -n localstack svc/localstack 4566:4566
```

#### 2. Navigate to Method 2 Directory
```bash
cd /home/jimmie/linkops-industries/Portfolio/infrastructure/method2-terraform-localstack
```

#### 3. Verify terraform.tfvars Exists
```bash
cat terraform.tfvars
# Should show:
# project_name = "portfolio"
# aws_region   = "us-east-1"
```

#### 4. Run Terraform Init
```bash
terraform init -upgrade
```

#### 5. Run Terraform Plan
```bash
terraform plan
# Review what will be created (16 resources)
```

#### 6. Run Terraform Apply
```bash
terraform apply -auto-approve
# Expected: 7 resources created, 9 errors (S3, EventBridge, CloudWatch)
```

#### 7. Verify Resources
```bash
# Set AWS CLI environment
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Check DynamoDB
aws dynamodb list-tables --endpoint-url=$AWS_ENDPOINT_URL

# Check SQS
aws sqs list-queues --endpoint-url=$AWS_ENDPOINT_URL
```

#### 8. Clean Up (Optional)
```bash
# Destroy all resources
terraform destroy -auto-approve

# Stop port forward
# Ctrl+C in the port-forward terminal
```

---

## 💡 Key Learnings

### 1. LocalStack Service Configuration
**Lesson:** LocalStack only runs services you explicitly enable.

**In Deployment:**
```yaml
env:
- name: SERVICES
  value: "s3,dynamodb,sqs"  # Only these 3 are enabled
```

**For Full Support:**
```yaml
env:
- name: SERVICES
  value: "s3,dynamodb,sqs,events,logs,cloudwatch,lambda"
```

### 2. S3 Path-Style vs Virtual Hosted-Style
**Virtual Hosted (default):** `http://bucket-name.localhost:4566/`
**Path-Style (LocalStack):** `http://localhost:4566/bucket-name`

**Fix in Terraform:**
```hcl
provider "aws" {
  s3_use_path_style = true
  # ... rest of config
}
```

### 3. Port Forwarding is Critical
LocalStack runs in Kubernetes but Terraform runs on your laptop.
**Must** port-forward `4566` to `localhost:4566` for Terraform to work.

### 4. Terraform State Management
- `terraform.tfstate` tracks what's been created
- Run `terraform destroy` to clean up resources
- State file shows URLs of created resources

---

## 🎯 What Method 2 Demonstrates

✅ **Infrastructure-as-Code:**
- Declarative resource definitions
- Version-controlled infrastructure
- Repeatable deployments

✅ **Local AWS Testing:**
- No AWS costs!
- Test S3, DynamoDB, SQS locally
- Same Terraform code works on real AWS

✅ **Production-Ready Patterns:**
- Modular Terraform structure
- Proper tagging
- Dead letter queues
- Table versioning

✅ **Cost Optimization:**
- DynamoDB on-demand billing mode
- SQS visibility timeouts
- Message retention policies

---

## 📚 Terraform Concepts Shown

### 1. Provider Configuration
```hcl
provider "aws" {
  region = "us-east-1"
  endpoints {
    s3 = "http://localhost:4566"
    # Point ALL AWS APIs to LocalStack
  }
}
```

### 2. Modules
```hcl
module "storage" {
  source = "./modules/aws-resources/storage"
  project_name = var.project_name
}
```

### 3. Variables
```hcl
variable "project_name" {
  type = string
}
```

### 4. Outputs
```hcl
output "dynamodb_tables" {
  value = module.storage.dynamodb_tables
}
```

### 5. State File
`terraform.tfstate` - JSON file tracking all created resources

---

## 🚀 Next Steps

### Option A: Fix S3/EventBridge Issues
1. Update LocalStack deployment with all services
2. Add `s3_use_path_style = true` to provider
3. Re-run `terraform apply`

### Option B: Keep Current Setup
- DynamoDB + SQS is enough to demonstrate Method 2
- Shows Terraform + LocalStack integration
- Core storage layer is functional

### Option C: Move to Method 3 (Helm + ArgoCD)
- Install ArgoCD from infrastructure/addons
- Deploy Portfolio using GitOps
- More production-grade than Method 2

---

## 📊 Comparison: Method 1 vs Method 2

| Aspect | Method 1 (kubectl) | Method 2 (Terraform + LocalStack) |
|--------|-------------------|----------------------------------|
| **Deployment** | Manual YAML apply | Declarative IaC |
| **Storage** | Kubernetes only | AWS services (simulated) |
| **State Management** | None | terraform.tfstate |
| **Repeatability** | Manual steps | Automated |
| **Learning Curve** | Easy | Intermediate |
| **Production Readiness** | Basic | Better |

---

## 🎓 What You Learned

1. ✅ How to install LocalStack in Kubernetes
2. ✅ How to configure Terraform for LocalStack
3. ✅ How to use Terraform modules
4. ✅ How to create DynamoDB tables with Terraform
5. ✅ How to create SQS queues with dead letter queues
6. ✅ How to verify AWS resources with AWS CLI
7. ✅ How to troubleshoot Terraform errors
8. ✅ Why port-forwarding is necessary

---

**Status:** Method 2 Core Deployment Complete! ✅
**Ready for:** Method 3 (Helm + ArgoCD) 🚀

**Created by:** Claude Code (Test Pilot Mode)
**Your Turn:** Follow the "How to Replicate" section above!
