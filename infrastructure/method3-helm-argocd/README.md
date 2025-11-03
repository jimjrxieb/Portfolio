# Method 3: Production Deployment (Helm + ArgoCD)

**Use Case:** Production deployment with GitOps on real AWS
**Time to Deploy:** ~30+ minutes (first time)
**AWS Services:** Real AWS (EKS, S3, DynamoDB, RDS, etc.)
**Complexity:** ⭐⭐⭐ Advanced

---

## What This Does

This method uses **Helm + ArgoCD** for GitOps-based deployment to production:
1. **Helm** packages your application as a versioned chart
2. **ArgoCD** watches your Git repo and auto-deploys changes
3. **AWS EKS** runs your Kubernetes cluster
4. **Real AWS services** (S3, DynamoDB, etc.)

This is how **companies like Netflix, Lyft, and Google** deploy to production!

---

## Prerequisites

- AWS account with EKS cluster
- kubectl configured for EKS
- Helm 3.x installed
- ArgoCD installed on cluster
- Your purchased domain configured
- AWS CLI configured

---

## Quick Start (Production)

### 1. Install ArgoCD (if not installed)

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### 2. Access ArgoCD UI

```bash
# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser to: https://localhost:8080
# Username: admin
# Password: (from previous step)
```

### 3. Deploy with ArgoCD

```bash
# Create ArgoCD application
kubectl apply -f infrastructure/method3-helm-argocd/argocd/portfolio-application.yaml

# Check sync status
kubectl get applications -n argocd

# Watch deployment
kubectl get pods -n portfolio -w
```

### 4. Configure Production Values

Edit [helm-chart/values.prod.yaml](helm-chart/values.prod.yaml):

```yaml
# Production overrides
ingress:
  host: your-domain.com  # Your purchased domain
  tls: true

image:
  tag: "v1.0.0"  # Specific version, not latest

env:
  api:
    LLM_PROVIDER: "claude"
    # ... production config
```

### 5. Deploy Updates via Git

ArgoCD watches your Git repo. To deploy updates:

```bash
# 1. Make changes to helm-chart/
vim helm-chart/templates/deployment-api.yaml

# 2. Commit and push
git add .
git commit -m "Update API deployment"
git push

# 3. ArgoCD auto-syncs (if configured)
# Or manually sync via UI
```

---

## Manual Helm Deployment (without ArgoCD)

If you want to use Helm directly:

```bash
cd infrastructure/method3-helm-argocd/helm-chart

# Install chart
helm install portfolio . \
  --namespace portfolio \
  --create-namespace \
  --values values.yaml \
  --values values.prod.yaml

# Upgrade chart
helm upgrade portfolio . \
  --namespace portfolio \
  --values values.yaml \
  --values values.prod.yaml

# Check status
helm status portfolio -n portfolio

# List releases
helm list -n portfolio
```

---

## Helm Chart Structure

```
helm-chart/
├── Chart.yaml                   # Chart metadata
├── values.yaml                  # Default values
├── values.dev.yaml              # Development overrides
├── values.prod.yaml             # Production overrides
└── templates/
    ├── _helpers.tpl             # Template helpers
    ├── deployment-api.yaml      # API deployment
    ├── deployment-ui.yaml       # UI deployment
    ├── deployment-chroma.yaml   # ChromaDB deployment
    ├── service-api.yaml         # API service
    ├── service-ui.yaml          # UI service
    ├── service-chroma.yaml      # ChromaDB service
    ├── ingress.yaml             # Ingress rules
    ├── pvc-chroma.yaml          # Persistent volume
    └── ...                      # Other resources
```

---

## ArgoCD Application Structure

```
argocd/
└── portfolio-application.yaml   # ArgoCD Application manifest
```

**Key Configuration:**
```yaml
spec:
  source:
    repoURL: https://github.com/your-repo/Portfolio.git
    path: infrastructure/method3-helm-argocd/helm-chart
    targetRevision: main
    helm:
      valueFiles:
        - values.yaml
        - values.prod.yaml
  syncPolicy:
    automated:
      prune: true        # Remove deleted resources
      selfHeal: true     # Auto-fix drift
```

---

## CI/CD Integration

Your GitHub Actions workflow already builds and pushes images. ArgoCD watches for:
1. **Image tag updates** in `values.yaml`
2. **Template changes** in `helm-chart/templates/`
3. **Configuration changes** in `values.prod.yaml`

**Example workflow:**
```
Developer push → GitHub Actions builds image → Updates values.yaml with new tag
                → Commits back to repo → ArgoCD detects change
                → ArgoCD syncs to cluster → New version deployed!
```

---

## Production Checklist

Before deploying to production:

- [ ] **Secrets:** Use external secrets manager (AWS Secrets Manager, Vault)
- [ ] **Monitoring:** Set up Prometheus + Grafana
- [ ] **Logging:** Configure centralized logging (ELK, CloudWatch)
- [ ] **Backups:** Enable automated backups for PVCs and databases
- [ ] **Disaster Recovery:** Test restore procedures
- [ ] **Security Policies:** Apply Gatekeeper policies (see [../shared-gk-policies/](../shared-gk-policies/))
- [ ] **Network Policies:** Apply network segmentation (see [../shared-security/](../shared-security/))
- [ ] **SSL/TLS:** Configure cert-manager for automatic certificates
- [ ] **DNS:** Point your domain to the ingress load balancer
- [ ] **Autoscaling:** Configure HPA (Horizontal Pod Autoscaler)
- [ ] **Resource Limits:** Review and adjust CPU/memory limits
- [ ] **Cost Monitoring:** Set up AWS cost alerts

---

## Troubleshooting

### ArgoCD not syncing?

```bash
# Check application status
kubectl describe application portfolio -n argocd

# Force sync
kubectl patch app portfolio -n argocd \
  --type json -p='[{"op": "replace", "path": "/operation", "value": {"sync": {}}}]'

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-server
```

### Helm deployment failed?

```bash
# Check release status
helm status portfolio -n portfolio

# See failure reason
helm history portfolio -n portfolio

# Rollback to previous version
helm rollback portfolio 1 -n portfolio
```

### Can't access application?

```bash
# Check ingress
kubectl describe ingress -n portfolio

# Check if LoadBalancer has external IP
kubectl get svc -n ingress-nginx

# Test internal connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n portfolio -- sh
curl http://portfolio-api:8000/health
```

---

## Tear Down

```bash
# Delete ArgoCD application (removes all resources)
kubectl delete application portfolio -n argocd

# Or delete via Helm
helm uninstall portfolio -n portfolio

# Delete namespace
kubectl delete namespace portfolio
```

---

## Next Steps

- **Set up monitoring:** Install Prometheus + Grafana
- **Configure alerts:** Set up PagerDuty/Slack notifications
- **Implement blue-green deployments:** Use ArgoCD rollouts
- **Add E2E tests:** Integrate with CI/CD pipeline

---

## Comparison with Other Methods

| Feature | Method 1 | Method 2 | **Method 3** |
|---------|----------|----------|--------------|
| **AWS Services** | ❌ No | ✅ LocalStack | ✅ Real AWS |
| **GitOps** | ❌ No | ❌ No | ✅ Yes |
| **Auto-sync** | ❌ No | ❌ No | ✅ Yes |
| **Rollback** | Manual | Terraform | Automatic |
| **Production Ready** | No | No | **Yes** |
| **Learning Curve** | Easy | Medium | **Hard** |

---

**This is the production-grade deployment method used by enterprises!**

Once you're comfortable with Method 1 and 2, this is the final step to true DevOps mastery! 🚀
