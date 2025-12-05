# Method 1 - Deployment Guide

## Two Deployment Approaches

### Approach 1: Simple kubectl apply (Recommended for You)

Run prerequisites, then use `kubectl apply`:

```bash
# Step 1: Install Gatekeeper (optional)
python3 00-install-gatekeeper.py

# Step 2: Deploy OPA policies (optional)
python3 00-deploy-opa-policies.py

# Step 3: Create namespace
kubectl apply -f 01-namespace.yaml

# Step 4: Create secrets
python3 00-create-secrets.py

# Step 5: Deploy everything!
kubectl apply -f /home/jimmie/linkops-industries/Portfolio/infrastructure/method1-simple-kubectl

# Step 6: Install Cloudflare (optional)
python3 99-deploy-cloudflare.py
```

See [PREREQS.md](PREREQS.md) for detailed instructions.

### Approach 2: Python Orchestration

Let the script handle everything:

```bash
python3 deploy.py
```

## Minimal Deployment (Skip Security)

If you just want the app running:

```bash
# 1. Create namespace
kubectl apply -f 01-namespace.yaml

# 2. Create secrets
kubectl create secret generic portfolio-api-secrets \
  --from-literal=CLAUDE_API_KEY="your-key" \
  -n portfolio

# 3. Deploy app
kubectl apply -f /home/jimmie/linkops-industries/Portfolio/infrastructure/method1-simple-kubectl
```

## What kubectl apply Deploys

When you run `kubectl apply -f .`, it applies:

✅ **01-namespace.yaml** - Creates portfolio namespace
✅ **03-chroma-pv-local.yaml** - Persistent volume for ChromaDB
✅ **04-chroma-deployment.yaml** - ChromaDB vector database
✅ **05-api-deployment.yaml** - Portfolio API (requires secrets)
✅ **06-ui-deployment.yaml** - Portfolio UI
✅ **07-ingress.yaml** - Ingress routes

❌ Does NOT apply:
- Python scripts (.py)
- Documentation (.md)
- Subdirectories (k8s-security/)

## Prerequisites Scripts

### 00-install-gatekeeper.py
- Installs OPA Gatekeeper via Helm
- Adds Gatekeeper Helm repo
- Installs with 3 replicas
- Waits for webhooks to register

### 00-deploy-opa-policies.py
- Deploys OPA policies from `GP-copilot/gatekeeper-temps/`
- 2-pass deployment (ConstraintTemplates → Constraints)
- Waits for CRDs to be established

### 00-create-secrets.py
- Reads `CLAUDE_API_KEY` from `../../.env`
- Creates `portfolio-api-secrets` in portfolio namespace

### 99-deploy-cloudflare.py
- Installs cloudflared on host system
- Installs as systemd service
- Reads `CLOUDFLARED_TUNNEL_TOKEN` from .env

## Required .env File

```bash
CLAUDE_API_KEY=sk-ant-your-key-here
CLOUDFLARED_TUNNEL_TOKEN=your-token  # Optional
```