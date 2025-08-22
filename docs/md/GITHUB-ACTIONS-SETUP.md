# GitHub Actions CI/CD Setup for linksmlm.com

## 🎯 Overview
GitHub Actions builds and pushes images to GHCR → You pull and deploy locally to KinD → Cloudflare tunnel serves linksmlm.com

## 🔧 Setup Steps

### 1. GitHub Repository Secrets
No secrets needed! The workflow uses `GITHUB_TOKEN` which is automatically provided.

### 2. Enable GitHub Packages
- Go to repository Settings → Actions → General
- Set "Workflow permissions" to "Read and write permissions"
- This allows pushing to GHCR (GitHub Container Registry)

### 3. Local KinD Cluster
Ensure your KinD cluster is running:
```bash
kind get clusters
# Should show: portfolio-local

kubectl config current-context  
# Should show: kind-portfolio-local
```

### 4. Cloudflare Tunnel
Your tunnel is already configured! The workflow deploys to `portfolio` namespace which matches your existing tunnel config.

## 🚀 Deployment Workflow

### Automatic (GitHub Actions)
1. **Push to main** → GitHub Actions triggers
2. **Builds images** → Pushes to `ghcr.io/jimjrxieb/portfolio-{api,ui}:main-<sha>`
3. **Security scan** → Trivy scans for vulnerabilities  
4. **Repository dispatch** → Sends webhook to trigger local deployment

### Manual Deployment
After GitHub Actions completes, deploy locally:
```bash
# Deploy specific version
./scripts/deploy-from-registry.sh main-a1b2c3d4

# Deploy latest
./scripts/deploy-from-registry.sh latest
```

### Webhook Automation (Optional)
Run a simple webhook listener to auto-deploy:
```bash
# In a separate terminal
./scripts/github-webhook-listener.sh

# This listens for GitHub dispatch events and auto-deploys
```

## 📋 Manual Workflow

1. **Make code changes**
2. **Commit and push to main**
3. **Watch GitHub Actions** (should complete in 3-5 minutes)
4. **Deploy locally**:
   ```bash
   ./scripts/deploy-from-registry.sh main-$(git rev-parse --short HEAD)
   ```
5. **Verify at https://linksmlm.com**

## 🔍 Verification Commands

```bash
# Check GitHub Actions built images
docker pull ghcr.io/jimjrxieb/portfolio-api:latest
docker pull ghcr.io/jimjrxieb/portfolio-ui:latest

# Check local deployment
kubectl get pods -n portfolio
kubectl get ingress -n portfolio

# Check application logs
kubectl logs -f deployment/portfolio-api -n portfolio
```

## 🛠️ Troubleshooting

### Images not found
- Check GitHub Actions completed successfully
- Verify repository permissions for packages
- Try: `docker login ghcr.io -u jimjrxieb -p <github-pat>`

### Deployment fails
- Ensure KinD cluster is running: `kind get clusters`
- Check context: `kubectl config current-context`
- Verify Helm charts: `helm list -n portfolio`

### Site not accessible
- Check Cloudflare tunnel is running
- Verify ingress: `kubectl get ingress -n portfolio`
- Test locally: `kubectl port-forward svc/portfolio-ui 8080:80 -n portfolio`

## 🎬 Demo Flow
Perfect for screen recording:
1. Make visible UI change (update landing page text)
2. Commit and push to main
3. Show GitHub Actions running
4. Deploy locally: `./scripts/deploy-from-registry.sh main-<sha>`
5. Refresh https://linksmlm.com → see changes live!

**Total time: ~5-7 minutes from commit to live site** 🚀