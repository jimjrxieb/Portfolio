# Method 1: Simple Kubernetes Deployment

**Use Case:** Quick local development on Docker Desktop Kubernetes
**Time to Deploy:** ~5 minutes
**AWS Services:** None (local only)
**Complexity:** ⭐ Beginner

---

## Prerequisites

- Docker Desktop with Kubernetes enabled
- kubectl configured
- helm installed (for Gatekeeper)
- Python 3.6+ installed
- Ollama running locally (for embeddings)
- NGINX Ingress Controller installed
- `.env` file in project root with API keys

### WSL2/Ubuntu: Disable System Nginx

Docker Desktop's K8s LoadBalancer needs port 80. If Ubuntu's nginx is installed, it blocks this:

```bash
# Check if system nginx is running
systemctl status nginx

# If running, disable it (one-time fix)
sudo systemctl disable --now nginx

# Verify port 80 is free
ss -tlnp | grep :80
```

After disabling, `kubectl apply -f .` will work and Docker Desktop can bind port 80.

---

## Deployment Methods

### Method A: Python Orchestration (Recommended)

Use the automated Python deployment script that handles everything in the correct order:

```bash
cd infrastructure/method1-simple-kubectl

# Full deployment with Gatekeeper, OPA policies, app, and Cloudflare
python3 deploy.py

# Skip Gatekeeper if already installed
python3 deploy.py --skip-gatekeeper

# Skip Cloudflare tunnel
python3 deploy.py --skip-cloudflare

# Skip secrets if already created
python3 deploy.py --skip-secrets
```

**What it deploys:**
1. OPA Gatekeeper (policy enforcement)
2. OPA Policies from `GP-copilot/gatekeeper-temps/`
3. Portfolio Application (namespace, secrets, storage, services)
4. Cloudflare Tunnel (optional)

### Method B: Manual Step-by-Step

For more control, run individual Python scripts and kubectl commands:

#### Step 1: Install Gatekeeper
```bash
python3 00-install-gatekeeper.py
```

#### Step 2: Deploy OPA Policies
```bash
python3 00-deploy-opa-policies.py
```

#### Step 3: Create Namespace & Secrets
```bash
kubectl apply -f 01-namespace.yaml
python3 00-create-secrets.py  # Creates from .env file
```

#### Step 4: Deploy Application
```bash
kubectl apply -f 03-chroma-pv-local.yaml
kubectl apply -f 04-chroma-deployment.yaml
kubectl apply -f 05-api-deployment.yaml
kubectl apply -f 06-ui-deployment.yaml
kubectl apply -f 07-ingress.yaml
```

#### Step 5: Deploy Cloudflare (Optional)
```bash
python3 99-deploy-cloudflare.py
```

### Method C: Traditional kubectl (Basic)

Simple kubectl deployment without Gatekeeper or OPA policies:

```bash
cd infrastructure/method1-simple-kubectl

# Step 1: Create namespace
kubectl apply -f 01-namespace.yaml

# Step 2: Create secrets (REQUIRED - not in yaml files, contains API keys)
python3 00-create-secrets.py

# Step 3: Create RAG data ConfigMap (for automatic RAG sync)
kubectl create configmap rag-data \
  --from-file=../../rag-pipeline/04-processed-rag-data/ \
  -n portfolio

# Step 4: Apply all other manifests
kubectl apply -f .

# Step 5 (Optional): Start Cloudflare tunnel for public access
python3 99-deploy-cloudflare.py
```

**Important Notes:**
- Secrets are NOT in yaml files (they contain API keys) - run `00-create-secrets.py` first
- RAG data ConfigMap must be created via `kubectl create` (too large for `kubectl apply`)
- The API deployment includes init containers that automatically sync RAG data to ChromaDB on every pod start

### Automatic RAG Sync

The API deployment now includes init containers that:
1. **wait-for-chromadb**: Waits for ChromaDB to be ready
2. **rag-sync**: Syncs RAG data from ConfigMap to ChromaDB

This means RAG data is **automatically populated** on every deployment or pod restart - no manual `python run_pipeline.py k8s` needed!

---

## Server Restart Recovery

After a server restart, run the startup script to restore everything:

```bash
cd infrastructure/method1-simple-kubectl
./startup.sh
```

**What it does:**

1. Checks K8s is running
2. Waits for pods to be healthy
3. Checks if ChromaDB has data (prompts re-sync if empty)
4. Starts cloudflared tunnel
5. Starts port-forward (8090 -> nginx ingress)
6. Verifies API health

**With full RAG re-sync:**

```bash
./startup.sh --full
```

---

## Quick Start (Method C - Basic)

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

## Cloudflare Tunnel Setup (Public Access)

The Portfolio is exposed to the internet via **Cloudflare Tunnel** at `linksmlm.com`.

### Architecture

```text
Internet → linksmlm.com → Cloudflare Edge → cloudflared tunnel
                                                   ↓
                                           localhost:8090
                                                   ↓
                                    kubectl port-forward (ingress:80)
                                                   ↓
                                           nginx ingress
                                                   ↓
                                    portfolio-api / portfolio-ui
```

### Tunnel Requirements

1. **Cloudflare account** with domain configured
2. **Tunnel created** in Cloudflare Zero Trust dashboard
3. **Tunnel token** in `.env` file as `CLOUDFLARED_TUNNEL_TOKEN`

### Tunnel Configuration

The cloudflared config file (`~/.cloudflared/config.yml`):

```yaml
tunnel: <your-tunnel-id>
credentials-file: /home/<user>/.cloudflared/credentials.json

ingress:
  - hostname: linksmlm.com
    service: http://localhost:8090
  - service: http_status:404
```

### Running the Tunnel

#### Automated (via deploy script)

```bash
python3 99-deploy-cloudflare.py
```

#### Manual Setup

```bash
# Start cloudflared (background)
cloudflared tunnel --config ~/.cloudflared/config.yml run &

# Start port-forward to bridge to nginx ingress (background)
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8090:80 &
```

### Verify Tunnel

```bash
# Test API health via tunnel chain
curl -H "Host: linksmlm.com" http://localhost:8090/api/chat/health

# Test from internet (if DNS is configured)
curl https://linksmlm.com/api/chat/health
```

### Tunnel Troubleshooting

```bash
# Check cloudflared is running
ps aux | grep cloudflared

# Check port-forward is running
ps aux | grep "port-forward.*8090"

# Check cloudflared logs
journalctl -u cloudflared -f

# Restart the tunnel
pkill cloudflared
cloudflared tunnel --config ~/.cloudflared/config.yml run &
```

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
