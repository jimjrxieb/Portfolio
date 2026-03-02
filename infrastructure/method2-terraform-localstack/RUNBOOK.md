# Method 2 Runbook: Terraform + LocalStack Deployment

Git clone to fully deployed portfolio with simulated AWS services.

---

## 1. Clone the Repository

```bash
git clone https://github.com/jimjrxieb/Portfolio.git
cd Portfolio
```

---

## 2. Prerequisites

Install before proceeding:

| Tool | Install |
|------|---------|
| Docker Desktop | https://docs.docker.com/desktop/ — enable Kubernetes in settings |
| kubectl | Bundled with Docker Desktop, or `brew install kubectl` |
| Terraform 1.0+ | https://developer.hashicorp.com/terraform/install |
| AWS CLI v2 | https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html |
| Python 3.6+ | `python3 --version` to verify |
| Ollama | https://ollama.com/download |

If using kind or minikube instead of Docker Desktop K8s, start your cluster now.

---

## 3. Start Kubernetes

Ensure your local Kubernetes cluster is running:

```bash
kubectl cluster-info
kubectl get nodes   # should show Ready
```

---

## 4. Start Ollama

```bash
# Terminal 1
ollama serve

# Terminal 2
ollama pull nomic-embed-text

# Verify
curl http://localhost:11434/api/tags
```

---

## 5. Start LocalStack

```bash
cd infrastructure/method2-terraform-localstack/s2-terraform-localstack

docker-compose -f docker-compose.localstack.yml up -d

# Wait for health
sleep 10
curl http://localhost:4566/_localstack/health
```

You should see `"running"` status for services.

---

## 6. Configure Terraform Variables

```bash
# Still in s2-terraform-localstack/
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your settings:

```hcl
project_name = "portfolio"
environment  = "localstack"
aws_region   = "us-east-1"
domain_name  = "your-domain.com"
```

---

## 7. Terraform Init / Plan / Apply

```bash
terraform init
terraform plan     # review what will be created
terraform apply    # type "yes" to confirm
```

This provisions:
- **AWS resources (via LocalStack):** S3 buckets, DynamoDB tables, SQS queues, CloudWatch logs, EventBridge rules
- **Kubernetes resources:** API, UI, ChromaDB deployments with networking and ingress

---

## 8. (Optional) Apply Cluster Hardening

Run the consulting package for CIS benchmark compliance:

```bash
cd /home/jimmie/linkops-industries/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/

# Run cluster audit
bash tools/run-cluster-audit.sh

# Review findings, then deploy policies
# See ENGAGEMENT-GUIDE.md for audit → enforce workflow
```

---

## 9. Verify

### Kubernetes

```bash
kubectl get pods -n portfolio        # all Running
kubectl get svc -n portfolio         # services exist
kubectl get ingress -n portfolio     # ingress has address
```

### LocalStack AWS Resources

```bash
aws --endpoint-url=http://localhost:4566 s3 ls
aws --endpoint-url=http://localhost:4566 dynamodb list-tables
aws --endpoint-url=http://localhost:4566 sqs list-queues
```

### App Health

```bash
curl http://portfolio.localtest.me/api/health
```

Access the app:
- **UI:** http://portfolio.localtest.me
- **API:** http://portfolio.localtest.me/api/health

---

## 10. Teardown

```bash
cd infrastructure/method2-terraform-localstack/s2-terraform-localstack

# Destroy all Terraform-managed resources
terraform destroy

# Stop LocalStack
docker-compose -f docker-compose.localstack.yml down -v
```

---

## Troubleshooting

**LocalStack not responding:** Check logs — `docker logs localstack`. Restart with `docker-compose -f docker-compose.localstack.yml restart`.

**Terraform errors:** Run with debug logging — `TF_LOG=DEBUG terraform apply`. If state is corrupted, `terraform destroy` then re-apply.

**Pods not starting:** Check pod logs — `kubectl logs -n portfolio deployment/portfolio-api`. Describe pods for events — `kubectl describe pod -n portfolio <pod>`.

**AWS CLI errors:** Ensure `--endpoint-url=http://localhost:4566` is passed for every LocalStack command.
