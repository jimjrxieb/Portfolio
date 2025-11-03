# Method 1: Simple Kubernetes Deployment

**Use Case:** Quick local development on Docker Desktop Kubernetes
**Time to Deploy:** ~5 minutes
**AWS Services:** None (local only)
**Complexity:** ⭐ Beginner

---

## Prerequisites

- Docker Desktop with Kubernetes enabled
- kubectl configured
- Ollama running locally (for embeddings)
- NGINX Ingress Controller installed

---

## Quick Start

### 1. Install NGINX Ingress Controller (if not installed)

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

### 2. Start Ollama

```bash
# Start Ollama server
ollama serve

# In another terminal, pull the embedding model
ollama pull nomic-embed-text
```

### 3. Create Secrets

Copy the secrets example and add your API keys:

```bash
cd infrastructure/method1-simple-kubectl

# Option 1: Edit the YAML file
cp 02-secrets-example.yaml 02-secrets.yaml
vim 02-secrets.yaml  # Add your real API keys

# Option 2: Use kubectl create secret (recommended)
kubectl create secret generic portfolio-api-secrets \
  --from-literal=CLAUDE_API_KEY="your-claude-key" \
  --from-literal=OPENAI_API_KEY="your-openai-key" \
  --from-literal=ELEVENLABS_API_KEY="your-elevenlabs-key" \
  --from-literal=DID_API_KEY="your-did-key" \
  -n portfolio
```

### 4. Deploy Application

```bash
# Apply all manifests in order (files are numbered)
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-secrets.yaml  # or skip if you used kubectl create secret
kubectl apply -f 03-chroma-pvc.yaml
kubectl apply -f 04-chroma-deployment.yaml
kubectl apply -f 05-api-deployment.yaml
kubectl apply -f 06-ui-deployment.yaml
kubectl apply -f 07-ingress.yaml

# Or apply all at once (order is preserved)
kubectl apply -f .
```

### 5. Check Status

```bash
# Watch pods come up
kubectl get pods -n portfolio -w

# Check services
kubectl get svc -n portfolio

# Check ingress
kubectl get ingress -n portfolio
```

### 6. Access Application

Once all pods are running:

- **UI:** http://portfolio.localtest.me
- **API:** http://portfolio.localtest.me/api
- **API Health:** http://portfolio.localtest.me/api/health

---

## Troubleshooting

### Pods not starting?

```bash
# Check pod logs
kubectl logs -n portfolio deployment/portfolio-api
kubectl logs -n portfolio deployment/portfolio-ui
kubectl logs -n portfolio deployment/chroma

# Describe pods for events
kubectl describe pod -n portfolio <pod-name>
```

### Can't access via ingress?

```bash
# Check ingress controller is running
kubectl get pods -n ingress-nginx

# Check ingress details
kubectl describe ingress -n portfolio portfolio

# Test internal service connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n portfolio -- sh
curl http://portfolio-api:8000/health
curl http://portfolio-ui:80
```

### Ollama connection issues?

Make sure Ollama is running and accessible from containers:

```bash
# Test Ollama from your machine
curl http://localhost:11434/api/tags

# Check API logs for Ollama errors
kubectl logs -n portfolio deployment/portfolio-api | grep ollama
```

---

## Uninstall

```bash
# Delete all resources
kubectl delete -f infrastructure/method1-simple-kubectl/

# Or delete namespace (removes everything)
kubectl delete namespace portfolio
```

---

## What Gets Deployed?

| Resource | Name | Purpose |
|----------|------|---------|
| Namespace | portfolio | Isolates all resources |
| PVC | chroma-data | Persistent storage for ChromaDB |
| Deployment | chroma | Vector database for embeddings |
| Deployment | portfolio-api | FastAPI backend |
| Deployment | portfolio-ui | React frontend |
| Service | chroma | ClusterIP for ChromaDB |
| Service | portfolio-api | ClusterIP for API |
| Service | portfolio-ui | ClusterIP for UI |
| Ingress | portfolio | External access via nginx |

---

## Next Steps

- **Want to test AWS services locally?** → Try [Method 2: Terraform + LocalStack](../method2-terraform-localstack/)
- **Ready for production?** → Try [Method 3: Helm + ArgoCD](../method3-helm-argocd/)
- **Apply security policies:** → See [../shared-gk-policies/](../shared-gk-policies/)

---

## File Numbering System

Files are numbered to show the correct deployment order:

1. **01-** Namespace (must exist first)
2. **02-** Secrets (required by deployments)
3. **03-** PVC (must exist before deployment mounts it)
4. **04-** ChromaDB deployment + service
5. **05-** API deployment + service
6. **06-** UI deployment + service
7. **07-** Ingress (routes traffic to services)

You can safely run `kubectl apply -f .` and the order will be correct!
