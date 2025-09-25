# Portfolio GitOps Deployment Guide

## 🎯 Overview

Complete GitOps containerization and deployment setup for Jimmie's AI/ML Portfolio application featuring:

- **GenAI Chatbox** - AI-powered conversation about CKA, CKS, DevSecOps, Cloud, and AI/ML automation
- **Multi-Service Architecture** - React UI, FastAPI backend, ChromaDB, Avatar Creation, RAG Pipeline
- **Helm Charts** - Production-ready Kubernetes deployment
- **ArgoCD GitOps** - Automated deployment and sync from GitHub

## 🏗️ Architecture

```
Portfolio Application Architecture:
├── 🌐 UI Service (React/Vite + Nginx)
├── 🔧 API Service (FastAPI Python)
├── 🗂️ ChromaDB (Vector Database)
├── 🎨 Avatar Creation (GenAI Service)
└── 📚 RAG Pipeline (Jupyter + RAG API)
```

## 📦 Prerequisites

1. **Docker & Docker Desktop** with Kubernetes enabled
2. **Helm 3.x** installed
3. **ArgoCD** deployed (use LinkOps-Arise setup)
4. **GitHub Container Registry** access
5. **OpenAI API Key** for GenAI features

## 🚀 Quick Deployment

### Option 1: Via ArgoCD (GitOps - Recommended)

```bash
# 1. Deploy ArgoCD (if not already done)
cd /path/to/LinkOps-Arise
./scripts/deploy-local.sh

# 2. Apply Portfolio ArgoCD Application
kubectl apply -f argocd-apps/portfolio-app.yaml

# 3. Monitor deployment in ArgoCD UI
open https://localhost:8080
```

### Option 2: Direct Helm Deployment

```bash
# 1. Clone Portfolio repository
git clone https://github.com/jimjrxieb/Portfolio.git
cd Portfolio

# 2. Create namespace and secrets
kubectl create namespace portfolio
kubectl create secret generic portfolio-secrets \
  --from-literal=OPENAI_API_KEY=your-openai-api-key \
  -n portfolio

# 3. Install Helm chart
helm install portfolio ./helm/portfolio -n portfolio

# 4. Check deployment
kubectl get all -n portfolio
```

## 🐳 Container Images

The application uses these container images (built from existing Dockerfiles):

```yaml
Images Required:
  - ghcr.io/jimjrxieb/portfolio-ui:latest
  - ghcr.io/jimjrxieb/portfolio-api:latest
  - ghcr.io/jimjrxieb/portfolio-chromadb:latest
  - ghcr.io/jimjrxieb/portfolio-avatar-creation:latest
  - ghcr.io/jimjrxieb/portfolio-rag-pipeline:latest
```

### Building and Pushing Images

```bash
# Build all services
docker compose build

# Tag and push to GHCR
services=("ui" "api" "chromadb" "avatar-creation" "rag-pipeline")

for service in "${services[@]}"; do
  docker tag portfolio-$service ghcr.io/jimjrxieb/portfolio-$service:latest
  docker push ghcr.io/jimjrxieb/portfolio-$service:latest
done
```

## ⚙️ Configuration

### Helm Values Customization

Create `values-override.yaml`:

```yaml
# Custom configuration
global:
  imagePrefix: ghcr.io/yourusername/portfolio
  namespace: portfolio

# Scale for production
ui:
  replicaCount: 3
  resources:
    limits:
      memory: "512Mi"
      cpu: "500m"

api:
  replicaCount: 2
  resources:
    limits:
      memory: "2Gi"
      cpu: "1000m"

# Enable persistence
chromadb:
  persistence:
    enabled: true
    size: 5Gi
    storageClass: "fast-ssd"

# Custom domain
ui:
  ingress:
    hosts:
      - host: portfolio.yourdomain.com
        paths:
          - path: /
            pathType: Prefix
```

Deploy with custom values:
```bash
helm install portfolio ./helm/portfolio -f values-override.yaml -n portfolio
```

### Environment Variables

Key configuration via ConfigMap and Secrets:

```yaml
ConfigMap Data:
  CHROMA_DB_IMPL: "duckdb+parquet"
  AVATAR_CHARACTER: "gojo"
  GPT_MODEL: "gpt-4o-mini"
  JUPYTER_ENABLE_LAB: "yes"

Secret Data:
  OPENAI_API_KEY: [base64 encoded API key]
```

## 🔗 Service Access

### Local Development (Port Forwarding)

```bash
# UI Frontend
kubectl port-forward svc/portfolio-ui 3000:80 -n portfolio
# Access: http://localhost:3000

# API Backend
kubectl port-forward svc/portfolio-api 8000:8000 -n portfolio
# Access: http://localhost:8000/docs

# Jupyter Lab (RAG Pipeline)
kubectl port-forward svc/portfolio-rag-pipeline 8888:8888 -n portfolio
# Access: http://localhost:8888 (token: portfolio-rag-2025)

# ChromaDB Admin
kubectl port-forward svc/portfolio-chromadb 8001:8000 -n portfolio
# Access: http://localhost:8001
```

### Production Access (Ingress)

```bash
# Configure /etc/hosts for local testing
echo "127.0.0.1 portfolio.local" >> /etc/hosts

# Access via ingress
curl http://portfolio.local
curl http://portfolio.local/api/health
curl http://portfolio.local/jupyter
```

## 🎯 ArgoCD GitOps Workflow

### Application Sync Process

1. **Code Changes** → Push to Portfolio repository
2. **CI/CD Pipeline** → Builds and pushes container images
3. **ArgoCD Detection** → Monitors Helm chart changes
4. **Automatic Sync** → Deploys updated manifests
5. **Health Monitoring** → Ensures successful deployment

### ArgoCD Application Features

```yaml
Sync Policy:
  - Automated: prune=true, selfHeal=true
  - Create Namespace automatically
  - Retry with exponential backoff
  - Revision history (10 versions)

Health Monitoring:
  - Deployment readiness checks
  - Service endpoint health
  - Resource quotas and limits
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Image Pull Errors
```bash
# Check image availability
docker pull ghcr.io/jimjrxieb/portfolio-ui:latest

# Verify image pull secrets
kubectl get pods -n portfolio
kubectl describe pod [failing-pod] -n portfolio
```

#### 2. ArgoCD Sync Failures
```bash
# Check application status
kubectl get application portfolio -n argocd -o yaml

# Manual sync
kubectl patch application portfolio -n argocd --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

#### 3. Service Communication Issues
```bash
# Test internal DNS resolution
kubectl exec -it deployment/portfolio-api -n portfolio -- nslookup portfolio-chromadb

# Check service endpoints
kubectl get endpoints -n portfolio
```

#### 4. Persistent Volume Issues
```bash
# Check PVC status
kubectl get pvc -n portfolio

# Describe storage issues
kubectl describe pvc portfolio-chromadb-pvc -n portfolio
```

### Debug Commands

```bash
# Check all resources
kubectl get all -n portfolio

# View pod logs
kubectl logs -f deployment/portfolio-api -n portfolio

# Execute into pod
kubectl exec -it deployment/portfolio-ui -n portfolio -- /bin/sh

# Check resource usage
kubectl top pods -n portfolio

# View events
kubectl get events -n portfolio --sort-by=.metadata.creationTimestamp
```

## 📊 Monitoring & Observability

### Health Check Endpoints

```bash
# API Service Health
curl http://portfolio.local/api/health

# ChromaDB Health
curl http://portfolio.local:8001/api/v1/heartbeat

# Avatar Service Health
curl http://portfolio.local/avatar/health

# RAG Pipeline Health
curl http://portfolio.local/rag/health
```

### Kubernetes Monitoring

```bash
# Pod resource usage
kubectl top pods -n portfolio

# Service status
kubectl get svc -n portfolio

# Ingress status
kubectl get ingress -n portfolio

# Check HPA (if configured)
kubectl get hpa -n portfolio
```

## 🚦 Production Checklist

### Before Production Deployment

- [ ] **Security**: Replace default secrets with production values
- [ ] **Images**: Use specific tags instead of `latest`
- [ ] **Resources**: Configure appropriate CPU/memory limits
- [ ] **Storage**: Enable persistent volumes for data services
- [ ] **Ingress**: Configure proper TLS certificates
- [ ] **Monitoring**: Set up Prometheus/Grafana monitoring
- [ ] **Backup**: Configure database backup strategy
- [ ] **Scaling**: Configure HorizontalPodAutoscaler
- [ ] **Network**: Implement NetworkPolicies for security
- [ ] **RBAC**: Configure service account permissions

### Production Values Example

```yaml
# production-values.yaml
global:
  imagePrefix: ghcr.io/jimjrxieb/portfolio
  pullPolicy: IfNotPresent

ui:
  replicaCount: 3
  image:
    tag: "v1.2.3"  # Specific version
  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - host: portfolio.yourcompany.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: portfolio-tls
        hosts:
          - portfolio.yourcompany.com

chromadb:
  persistence:
    enabled: true
    size: 50Gi
    storageClass: fast-ssd

monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
```

## 🎉 Success Metrics

### Deployment Success Indicators

- ✅ All pods in `Running` state
- ✅ Services have endpoints
- ✅ Ingress returns 200 OK
- ✅ ArgoCD shows `Healthy` and `Synced`
- ✅ Health check endpoints respond
- ✅ GenAI chatbox answers questions correctly
- ✅ Persistent data survives pod restarts

### Performance Targets

- **UI Load Time**: < 2 seconds
- **API Response Time**: < 500ms
- **GenAI Response**: < 5 seconds
- **Vector Search**: < 1 second
- **Pod Startup**: < 30 seconds

---

**Portfolio GitOps Deployment**: Production-ready containerization with Helm + ArgoCD

*Multi-service • AI-powered • Kubernetes-native • GitOps-enabled*