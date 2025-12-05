# Terraform + LocalStack Deployment Pattern

## Overview

Method 2 deployment uses Terraform for Infrastructure-as-Code (IaC) with LocalStack for local AWS service emulation. This demonstrates advanced DevOps capabilities beyond simple kubectl apply.

## Key Components

### Terraform Modules Structure
```
infrastructure/method2-terraform-localstack/
├── s0-shared-mods/
│   ├── portfolio-app/     # Main application module
│   ├── gatekeeper/        # OPA Gatekeeper installation
│   └── opa-policies/      # Security policy constraints
└── s2-terraform-localstack/
    └── main.tf            # Root module calling shared modules
```

### What LocalStack Provides
- **S3:** Object storage emulation
- **DynamoDB:** NoSQL database emulation
- **SQS:** Message queue emulation
- **Purpose:** Test AWS integrations locally without costs

### What Terraform Manages
- Kubernetes namespace, deployments, services, ingress
- ConfigMaps and Secrets
- OPA Gatekeeper installation via Helm
- AWS resources in LocalStack

## Critical Patterns

### 1. Terraform Import for Existing Resources
When migrating to Terraform from kubectl:
```bash
terraform import 'module.kubernetes_app.kubernetes_deployment.api' portfolio/api
```

### 2. OPA Gatekeeper Security Requirements
All pods must include:
```hcl
security_context {
  run_as_user     = 10001
  run_as_non_root = true
  seccomp_profile {
    type = "RuntimeDefault"
  }
}
```

Containers must include:
```hcl
security_context {
  read_only_root_filesystem  = true
  allow_privilege_escalation = false
  capabilities {
    drop = ["ALL"]
  }
}
```

### 3. ReadOnly Filesystem + Logging
When using `read_only_root_filesystem = true`, override file-based logging with ConfigMap:
```yaml
version: 1
handlers:
  console:
    class: logging.StreamHandler
    stream: ext://sys.stdout
root:
  handlers: [console]
```

### 4. Init Containers for RAG Sync
Two-stage initialization:
1. **wait-for-chromadb:** Polls ChromaDB heartbeat endpoint
2. **rag-sync:** Ingests documents from ConfigMap into ChromaDB

### 5. Ingress Rewrite Patterns
For `/api/*` routes to reach backend as `/api/*`:
```hcl
path          = "/api(/|$)(.*)"
rewrite-target = "/api/$2"
```

## Troubleshooting Quick Reference

| Symptom | Cause | Fix |
|---------|-------|-----|
| "namespace already exists" | Terraform state empty | `terraform import` |
| "admission webhook denied" | OPA policy violation | Add security contexts |
| CrashLoopBackOff + log error | readOnlyRootFilesystem | ConfigMap for log config |
| 404 on /api/chat | Wrong rewrite-target | Use `/api/$2` not `/$2` |

## Verification Commands

```bash
# Check pods
kubectl get pods -n portfolio

# Verify RAG sync
kubectl exec -n portfolio deployment/api -- python -c \
  "import chromadb; print(chromadb.HttpClient(host='chroma',port=8000).get_collection('portfolio_docs').count())"

# Test chat
curl -X POST http://portfolio.localtest.me/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Tell me about Jimmie"}'
```

## Key Files

- [main.tf](infrastructure/method2-terraform-localstack/s0-shared-mods/portfolio-app/main.tf) - Core deployments with init containers
- [variables.tf](infrastructure/method2-terraform-localstack/s0-shared-mods/portfolio-app/variables.tf) - Module configuration
- [ingress.tf](infrastructure/method2-terraform-localstack/s0-shared-mods/portfolio-app/ingress.tf) - Routing rules

## Why Method 2 Matters for Interviews

Demonstrates:
- Infrastructure-as-Code with Terraform
- Module composition and reusability
- Security policy enforcement (OPA Gatekeeper)
- Init container patterns for dependencies
- AWS service integration patterns
- Production-grade security contexts