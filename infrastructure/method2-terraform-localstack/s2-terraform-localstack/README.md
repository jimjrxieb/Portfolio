# S2: LocalStack Development

Kubernetes + AWS (LocalStack). Full stack for local development.

## Prerequisites
- LocalStack running: `kubectl get pods -n localstack`
- Port forward: `kubectl port-forward -n localstack svc/localstack 4566:4566`

## Deploy
```bash
terraform init
terraform apply
```

## Resources
- 3 Kubernetes pods
- 3 S3 buckets
- 3 DynamoDB tables  
- 3 SQS queues
- 2 EventBridge rules
- 3 CloudWatch log groups
