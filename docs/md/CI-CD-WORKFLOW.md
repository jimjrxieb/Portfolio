# CI/CD Workflow - Perfect DevOps Pipeline

## 🎯 **Problem Solved**
You needed automated deployment when content changes (like Sheyla's knowledge base updates) without manual kubectl commands interfering with your local development environment.

## 🔄 **New GitHub Actions Workflows**

### 1. **Main CI/CD Pipeline** (`.github/workflows/main.yml`)
**Triggers on:** API/UI code changes, knowledge base updates, charts
**Does:**
- ✅ Builds Docker images with security scanning (Trivy)
- ✅ Pushes to GitHub Container Registry (GHCR)
- ✅ Deploys to **production cluster** (not your local KIND)
- ✅ Triggers RAG re-ingestion automatically
- ✅ Verifies deployment health

### 2. **Content Update Pipeline** (`.github/workflows/content-update.yml`)
**Triggers on:** Knowledge base changes only (`data/knowledge/**`, `chat/data/**`)
**Does:**
- ✅ Syncs content to production without rebuilding Docker images
- ✅ Triggers RAG re-ingestion for immediate Sheyla updates
- ✅ Verifies new responses are working
- ✅ Fast ~2 minute deployment vs ~10 minute full build

## 🚀 **Your New DevOps Workflow**

### **For Content Updates (Sheyla's responses):**
```bash
# 1. Update knowledge base
vim data/knowledge/jimmie/01-bio.md
vim chat/data/sheyla_personality.md

# 2. Commit and push
git add .
git commit -m "Update Sheyla responses for AI-BOX funding info"
git push origin main

# 3. Watch content-update workflow (2 min)
# → GitHub Actions automatically updates production
# → RAG re-ingestion happens automatically
# → Sheyla immediately has new responses at linksmlm.com
```

### **For Code Changes (API/UI features):**
```bash
# 1. Make code changes
vim api/routes/chat.py
vim ui/src/components/ChatPanel.tsx

# 2. Commit and push
git add .
git commit -m "Add new chat features"
git push origin main

# 3. Watch main workflow (8-10 min)
# → Full build, security scan, deploy
# → New Docker images built and deployed
# → Production updated with new features
```

### **For Local Development/Testing:**
```bash
# Pull latest from registry (avoid conflicts)
./scripts/deploy-from-registry.sh main-a1b2c3d4

# OR pull latest
./scripts/deploy-from-registry.sh latest

# Test locally at http://portfolio.localtest.me
# No conflicts with production deployments!
```

## 🏗️ **Architecture Benefits**

### **Separation of Concerns:**
- **Production:** GitHub Actions → GHCR → Production Cluster
- **Local:** Manual pull from GHCR → Local KIND cluster
- **No Conflicts:** Your local kubectl never affects production

### **Smart Triggering:**
- **Content changes** → Fast content sync (2 min)
- **Code changes** → Full build pipeline (10 min)
- **No false triggers** on README updates

### **Security & DevOps Best Practices:**
- ✅ Trivy vulnerability scanning
- ✅ Separate production/dev environments  
- ✅ Immutable image tags (main-<sha>)
- ✅ Health checks and rollout verification
- ✅ Automatic RAG re-ingestion

## 📋 **GitHub Repository Setup**

### **Required Secrets:**
```bash
KUBE_CONFIG_DATA  # Base64 encoded kubeconfig for production cluster
```

### **Required Permissions:**
- Repository → Settings → Actions → General
- Set "Workflow permissions" to "Read and write permissions"
- This allows pushing to GHCR (GitHub Container Registry)

## 🎬 **Demo Flow for Interviews**

**Perfect DevOps demonstration:**

```bash
# 1. Show current Sheyla response
curl -s "https://linksmlm.com/api/chat" \
  -d '{"message": "Tell me about LinkOps AI-BOX"}' | jq -r '.answer'

# 2. Update knowledge base
echo "Updated content about funding status" >> data/knowledge/jimmie/01-bio.md

# 3. Commit and push
git add . && git commit -m "Update funding info" && git push

# 4. Show GitHub Actions running (2 min for content updates)

# 5. Test updated response
curl -s "https://linksmlm.com/api/chat" \
  -d '{"message": "Tell me about LinkOps AI-BOX"}' | jq -r '.answer'
# → Shows new funding information immediately!

# 6. Pull to local for testing
./scripts/deploy-from-registry.sh latest
```

**Total demo time: ~5 minutes from code change to live production**

## 🔧 **Troubleshooting**

### **GitHub Actions fails:**
- Check repository permissions for packages
- Verify KUBE_CONFIG_DATA secret is set
- Check production cluster is accessible

### **Content updates not reflected:**
- Check if content-update workflow triggered
- Verify RAG re-ingestion completed successfully
- Test API directly: `kubectl logs -f deployment/portfolio-api -n portfolio-prod`

### **Local deployment issues:**
- Ensure KIND cluster is running: `kind get clusters`
- Check context: `kubectl config current-context`
- Try: `./scripts/deploy-from-registry.sh latest`

## 🎯 **Success Metrics**

✅ **Content updates deploy in ~2 minutes**
✅ **Full deployments complete in ~10 minutes**  
✅ **Zero local environment conflicts**
✅ **Automatic RAG re-ingestion on every update**
✅ **Security scanning on every build**
✅ **Immutable deployments with rollback capability**

**This is production-grade DevOps that demonstrates real CI/CD expertise!** 🚀