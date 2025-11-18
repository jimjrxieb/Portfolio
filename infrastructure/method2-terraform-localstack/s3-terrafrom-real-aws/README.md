# S3: Real AWS Production

Kubernetes + AWS (real account). Production deployment.

## Prerequisites
- AWS credentials configured: `aws configure`
- Kubernetes cluster (EKS or other)
- Update `terraform.tfvars` with your API keys

## Deploy
```bash
terraform init
terraform apply
```

## Resources
- 3 Kubernetes pods (2 replicas for API/UI)
- 3 S3 buckets (versioned, encrypted)
- 3 DynamoDB tables (encrypted with KMS)
- 3 SQS queues
- 2 EventBridge rules
- 3 CloudWatch log groups (encrypted)

## Cost Estimate
Approximately $50-100/month depending on usage.
