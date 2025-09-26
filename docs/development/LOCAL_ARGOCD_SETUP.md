# Local ArgoCD Setup for Portfolio Development

## Overview

This guide sets up ArgoCD in Docker Desktop Kubernetes to simulate deploying the Portfolio platform to your "old laptop" environment. This allows you to test the GitOps deployment workflow locally.

## Architecture Separation

### **RAG Pipeline (ROG Strix - Local Only)**

- **Purpose**: Data ingestion and embedding generation
- **Location**: Development machine only (`rag-pipeline/`)
- **Function**: Processes documents → stores in ChromaDB
- **Deployment**: NOT deployed to Kubernetes
- **Usage**: `docker-compose --profile dev-tools up rag-pipeline`

### **Portfolio Platform (Kubernetes Deployment)**

- **API Service**: FastAPI + integrated Jade-Brain AI
- **UI Service**: React/TypeScript frontend
- **ChromaDB**: Vector database with embedded documents
- **Deployment**: Via ArgoCD from GitHub

## Prerequisites

1. **Docker Desktop** with Kubernetes enabled
2. **kubectl** command-line tool
3. **Git** access to Portfolio repository

## Setup Instructions

### Step 1: Enable Docker Desktop Kubernetes

1. Open Docker Desktop
2. Go to **Settings → Kubernetes**
3. Check **"Enable Kubernetes"**
4. Click **"Apply & Restart"**
5. Wait for Kubernetes to start (green indicator)

### Step 2: Install ArgoCD

Run the automated setup script:

```bash
cd /home/jimmie/linkops-industries/Portfolio
./scripts/setup-argocd-local.sh
```

This script will:

- Create `argocd` namespace
- Install ArgoCD components
- Wait for services to be ready
- Display admin credentials

### Step 3: Access ArgoCD UI

```bash
# Port forward ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access ArgoCD at: **https://localhost:8080**

- **Username**: `admin`
- **Password**: (displayed by setup script)

### Step 4: Deploy Portfolio Application

```bash
# Apply the Portfolio application configuration
kubectl apply -f argocd/portfolio-application.yaml
```

## Configuration Details

### **ArgoCD Application Spec**

```yaml
source:
  repoURL: https://github.com/jimjrxieb/Portfolio.git
  path: helm/portfolio
  targetRevision: HEAD

destination:
  server: https://kubernetes.default.svc
  namespace: portfolio

syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

### **Helm Parameters**

- `global.imagePrefix`: `ghcr.io/jimjrxieb/portfolio`
- `ui.image.tag`: `latest`
- `api.image.tag`: `latest`
- `chromadb.image.tag`: `latest`

## Monitoring Deployment

### **ArgoCD UI**

- View sync status and health
- Monitor deployment progress
- See application topology

### **kubectl Commands**

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check Portfolio namespace
kubectl get all -n portfolio

# View application logs
kubectl logs -n portfolio deployment/portfolio-api
kubectl logs -n portfolio deployment/portfolio-ui
```

## Simulating "Old Laptop" Deployment

This local setup simulates your actual deployment scenario:

1. **Code Changes**: Push to GitHub main branch
2. **CI/CD Pipeline**: GitHub Actions builds and pushes images
3. **ArgoCD Sync**: Automatically pulls latest images and manifests
4. **Local Testing**: Verify deployment works before actual laptop deployment

## Development Workflow

### **Update Knowledge Base (Local)**

```bash
# Run RAG pipeline to update ChromaDB data
docker-compose --profile dev-tools up rag-pipeline

# Data gets stored in ./data/chroma/ volume
# This volume is shared with deployed ChromaDB service
```

### **Test Application Changes**

```bash
# 1. Make code changes
# 2. Push to GitHub
git add .
git commit -m "Update feature"
git push origin main

# 3. GitHub Actions builds new images
# 4. ArgoCD automatically syncs changes
# 5. Check deployment in ArgoCD UI
```

### **Force Sync (if needed)**

```bash
# Force ArgoCD to check for changes
kubectl patch app portfolio -n argocd -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"hook":{}}}}}' --type merge
```

## Troubleshooting

### **ArgoCD Not Starting**

```bash
# Check Kubernetes status
kubectl cluster-info

# Check ArgoCD pods
kubectl get pods -n argocd

# View ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server
```

### **Application Sync Issues**

1. Check GitHub repository access
2. Verify Helm chart validity
3. Review ArgoCD application logs
4. Check container image availability

### **Port Conflicts**

If port 8080 is in use:

```bash
# Use different port
kubectl port-forward svc/argocd-server -n argocd 9090:443
```

## Security Considerations

- ArgoCD uses HTTPS with self-signed certificates (accept in browser)
- Admin password should be changed after initial setup
- Consider creating dedicated ArgoCD users for production

## Benefits of This Setup

1. **Realistic Testing**: Mirrors actual deployment environment
2. **GitOps Workflow**: Test entire CI/CD → ArgoCD pipeline
3. **Isolated Development**: RAG pipeline stays local, platform deploys
4. **Continuous Sync**: Automatic updates on GitHub changes
5. **Deployment Validation**: Verify before actual laptop deployment

---

**Next Steps**: After successful local testing, deploy ArgoCD and Portfolio to your old laptop using the same configuration files.
