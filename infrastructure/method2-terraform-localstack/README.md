# Method 2: Terraform + LocalStack

**Use Case:** Full AWS stack testing locally with your purchased domain
**Time to Deploy:** ~15 minutes
**AWS Services:** S3, DynamoDB, SQS (emulated via LocalStack)
**Complexity:** ⭐⭐ Intermediate

---

## What This Does

This method uses **Terraform** to deploy:
1. **AWS Resources** (S3, DynamoDB, SQS) to LocalStack (local AWS emulation)
2. **Kubernetes Application** (API, UI, ChromaDB) to your local K8s cluster

This gives you a **production-like environment** on your laptop!

---

## Prerequisites

- Docker Desktop with Kubernetes enabled
- Terraform 1.0+ installed
- LocalStack running (via Docker Compose)
- kubectl configured
- Ollama running locally
- Your purchased domain configured (DNS)

---

## Quick Start

### 1. Start LocalStack

```bash
# From project root
docker-compose -f docker-compose.localstack.yml up -d

# Wait for LocalStack to be ready
sleep 10

# Verify LocalStack is running
curl http://localhost:4566/_localstack/health
```

### 2. Start Ollama

```bash
ollama serve
ollama pull nomic-embed-text
```

### 3. Configure Terraform Variables

```bash
cd infrastructure/method2-terraform-localstack

# Copy example config
cp terraform.tfvars.example terraform.tfvars

# Edit with your settings
vim terraform.tfvars
```

**Example terraform.tfvars:**
```hcl
project_name = "portfolio"
environment  = "localstack"
aws_region   = "us-east-1"

# Your purchased domain
domain_name  = "your-domain.com"
```

### 4. Deploy with Terraform

```bash
# Initialize Terraform (downloads providers)
terraform init

# See what will be created
terraform plan

# Deploy everything!
terraform apply
```

**What Terraform deploys:**
- ✅ S3 buckets (portfolio-raw, portfolio-embeddings, portfolio-config)
- ✅ DynamoDB tables (document_registry, embedding_chunks, ingestion_jobs)
- ✅ SQS queues (ingestion, embedding, DLQ)
- ✅ CloudWatch log groups
- ✅ EventBridge rules
- ✅ Kubernetes deployments (API, UI, ChromaDB)
- ✅ Kubernetes services and ingress

### 5. Verify Deployment

```bash
# Check AWS resources in LocalStack
aws s3 ls --endpoint-url=http://localhost:4566
aws dynamodb list-tables --endpoint-url=http://localhost:4566
aws sqs list-queues --endpoint-url=http://localhost:4566

# Check Kubernetes resources
kubectl get pods -n portfolio
kubectl get svc -n portfolio
kubectl get ingress -n portfolio
```

### 6. Access Application

- **UI:** http://portfolio.localtest.me (or your configured domain)
- **API:** http://portfolio.localtest.me/api
- **API Health:** http://portfolio.localtest.me/api/health

---

## Testing AWS Services

### Upload a file to S3

```bash
# Create test file
echo "Test document content" > test.md

# Upload to S3 (via LocalStack)
aws s3 cp test.md s3://portfolio-raw/incoming/ \
  --endpoint-url=http://localhost:4566

# Verify upload
aws s3 ls s3://portfolio-raw/incoming/ \
  --endpoint-url=http://localhost:4566
```

### Query DynamoDB

```bash
# Scan document registry
aws dynamodb scan \
  --table-name portfolio-document-registry \
  --endpoint-url=http://localhost:4566 \
  | jq '.Items'
```

### Send SQS Message

```bash
# Send message to ingestion queue
aws sqs send-message \
  --queue-url http://localhost:4566/000000000000/portfolio-ingestion-queue \
  --message-body "Test ingestion message" \
  --endpoint-url=http://localhost:4566

# Receive messages
aws sqs receive-message \
  --queue-url http://localhost:4566/000000000000/portfolio-ingestion-queue \
  --endpoint-url=http://localhost:4566
```

---

## Switching to Real AWS

To use real AWS instead of LocalStack:

1. **Remove LocalStack endpoint** from `main.tf`:
   ```hcl
   provider "aws" {
     region = var.aws_region
     # Remove: endpoints block
   }
   ```

2. **Configure AWS credentials**:
   ```bash
   aws configure
   # Or set: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
   ```

3. **Deploy**:
   ```bash
   terraform apply
   ```

**Note:** This will create REAL AWS resources that may incur costs!

---

## Troubleshooting

### LocalStack not responding?

```bash
# Check LocalStack logs
docker logs localstack

# Restart LocalStack
docker-compose -f docker-compose.localstack.yml restart
```

### Terraform errors?

```bash
# See detailed logs
TF_LOG=DEBUG terraform apply

# Destroy and recreate
terraform destroy
terraform apply
```

### Can't access Kubernetes app?

```bash
# Check pods
kubectl get pods -n portfolio

# Check logs
kubectl logs -n portfolio deployment/portfolio-api

# Check if services exist
kubectl get svc -n portfolio
```

---

## Tear Down

```bash
# Destroy Terraform resources
terraform destroy

# Stop LocalStack
docker-compose -f docker-compose.localstack.yml down -v
```

---

## Directory Structure

```
method2-terraform-localstack/
├── README.md                    # This file
├── main.tf                      # Main Terraform configuration
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── terraform.tfvars.example     # Example configuration
└── modules/
    ├── aws-resources/           # S3, DynamoDB, SQS module
    └── kubernetes-app/          # K8s deployment module (coming soon)
```

---

## Next Steps

- **Learn Helm and ArgoCD?** → Try [Method 3: Helm + ArgoCD](../method3-helm-argocd/)
- **Apply security policies:** → See [../shared-gk-policies/](../shared-gk-policies/)
- **Need simple kubectl?** → Try [Method 1: Simple Kubectl](../method1-simple-kubectl/)

---

## Comparison with Other Methods

| Feature | Method 1 | **Method 2** | Method 3 |
|---------|----------|--------------|----------|
| **AWS Services** | ❌ No | ✅ Yes (LocalStack) | ✅ Yes (Real AWS) |
| **IaC** | ❌ No | ✅ Terraform | ✅ Terraform/Helm |
| **Production-like** | Low | High | Highest |
| **Learning Curve** | Easy | Medium | Hard |
| **Deploy Time** | 5 min | 15 min | 30+ min |

---

**This is the recommended method for learning production AWS deployments locally!**
