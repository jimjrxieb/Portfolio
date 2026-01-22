# Method 3: Production Deployment (Helm + ArgoCD)

## What is this? (Plain English)

Imagine you're running a restaurant chain. You need:
- A **recipe book** that tells every kitchen exactly how to make each dish (that's **Helm**)
- A **manager** who watches the recipe book and makes sure every restaurant follows it perfectly (that's **ArgoCD**)
- **Actual kitchens** where the food gets made (that's **Kubernetes/AWS**)

This method is how big companies like Netflix and Spotify deploy their apps to millions of users!

---

## Quick Facts

| What | Answer |
|------|--------|
| **Who is this for?** | Real production websites that need to be reliable |
| **How long to set up?** | About 30+ minutes the first time |
| **How hard is it?** | Advanced (but this guide helps!) |
| **What do I need?** | An AWS account and some terminal skills |

---

## The Big Picture: How It Works

Think of it like this:

```
YOU make a change to your code
         ↓
GITHUB stores your change (like saving to the cloud)
         ↓
ARGOCD notices "Hey, something changed!"
         ↓
ARGOCD automatically updates your live website
         ↓
YOUR USERS see the new version!
```

**The magic:** You never manually deploy. You just push code, and everything happens automatically. This is called **GitOps** - using Git as the "source of truth" for what should be running.

---

## Key Terms Explained

| Term | What It Actually Means |
|------|------------------------|
| **Helm** | A package manager for Kubernetes. Like how you install apps on your phone from the App Store, Helm installs apps to your server. |
| **Helm Chart** | A folder with instructions that tells Kubernetes "here's how to run my app" |
| **ArgoCD** | A tool that watches your GitHub repo and automatically deploys changes |
| **GitOps** | The practice of using Git (GitHub) as the boss - whatever is in Git is what runs |
| **Kubernetes (K8s)** | Software that manages and runs your application containers |
| **Sync** | When ArgoCD makes your live server match what's in GitHub |

---

## Before You Start

You'll need these things ready:

1. **An AWS account** - Where your app will actually run
2. **A Kubernetes cluster** - The "computer" that runs your app (AWS EKS)
3. **ArgoCD installed** - The "auto-deployer" tool
4. **Your domain name** - Like `yourportfolio.com`
5. **Terminal access** - To run commands

---

## Step-by-Step Setup

### Step 1: Install the Auto-Deployer (ArgoCD)

This is like hiring a manager who watches your code and deploys it automatically.

```bash
# Create a special area for ArgoCD to live
kubectl create namespace argocd

# Install ArgoCD (downloads and sets it up)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for it to be ready (about 2-3 minutes)
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Get your login password (save this!)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

**What just happened?** You installed ArgoCD - it's now running and ready to watch your code.

### Step 2: Open the ArgoCD Dashboard

ArgoCD has a nice visual dashboard where you can see your deployments.

```bash
# This opens a tunnel to ArgoCD's dashboard
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Now open your web browser and go to: **https://localhost:8080**

- **Username:** `admin`
- **Password:** (the one you got in Step 1)

**What you'll see:** A dashboard showing all your applications and their status (healthy, syncing, etc.)

### Step 3: Tell ArgoCD About Your App

Now we tell ArgoCD "watch this GitHub repo and deploy what's in it."

```bash
# Apply the ArgoCD application config
kubectl apply -f infrastructure/method3-helm-argocd/argocd/portfolio-application.yaml

# Check that it was created
kubectl get applications -n argocd
```

**What just happened?** ArgoCD is now watching your GitHub repo. Whenever you push changes, it will automatically update your live app.

### Step 4: Watch Your App Come to Life

```bash
# Watch the pods (containers) start up
kubectl get pods -n portfolio -w
```

You should see your app containers starting up. When they all say "Running", your app is live!

---

## How to Deploy Updates (The Easy Way)

This is the magic of GitOps. To update your live app:

1. **Make your code change** (fix a bug, add a feature)
2. **Commit and push to GitHub**
   ```bash
   git add .
   git commit -m "Fixed the login button"
   git push
   ```
3. **That's it!** ArgoCD sees the change and deploys it automatically

No manual deployment commands. No SSH into servers. Just push code.

---

## What's in the Helm Chart Folder?

Think of the `helm-chart/` folder as your app's instruction manual:

```
helm-chart/
├── Chart.yaml          ← "Hi, my name is Portfolio App, version 1.0"
├── values.yaml         ← "Here are my default settings"
├── values.prod.yaml    ← "Here are my PRODUCTION settings (more secure)"
└── templates/          ← "Here's exactly how to run each piece"
    ├── deployment-api.yaml    ← "How to run the backend"
    ├── deployment-ui.yaml     ← "How to run the frontend"
    ├── service-api.yaml       ← "How to connect to the backend"
    └── ingress.yaml           ← "How to let the internet reach my app"
```

---

## Configuration: values.yaml Explained

The `values.yaml` file is like a settings menu for your app:

```yaml
# How many copies of the app to run (more = handles more users)
replicaCount: 2

# What container image to use (like picking which version of the app)
image:
  repository: ghcr.io/jimjrxieb/portfolio-api
  tag: "v1.0.0"

# How much computer power to give each copy
resources:
  limits:
    cpu: "500m"      # Half a CPU core max
    memory: "512Mi"  # Half a gigabyte of RAM max
```

**Tip:** For production, edit `values.prod.yaml` with your real domain and settings.

---

## The Automatic Deployment Flow

Here's what happens when you push code:

```
┌─────────────────────────────────────────────────────────────┐
│  1. You push code to GitHub                                 │
│                    ↓                                        │
│  2. GitHub Actions builds a new container image             │
│                    ↓                                        │
│  3. The image gets pushed to a container registry           │
│                    ↓                                        │
│  4. ArgoCD notices the change in your repo                  │
│                    ↓                                        │
│  5. ArgoCD compares: "What's in Git?" vs "What's running?"  │
│                    ↓                                        │
│  6. ArgoCD deploys the changes to make them match           │
│                    ↓                                        │
│  7. Your users see the new version (zero downtime!)         │
└─────────────────────────────────────────────────────────────┘
```

---

## Production Checklist (Before Going Live)

Before real users visit your site, make sure:

- [ ] **Secrets are secure** - API keys stored in AWS Secrets Manager, not in code
- [ ] **Monitoring is set up** - You can see if something breaks (Prometheus + Grafana)
- [ ] **Backups are running** - Your data is safe if something crashes
- [ ] **SSL certificate** - The padlock shows in the browser (https://)
- [ ] **Domain configured** - Your domain points to your app
- [ ] **Security policies** - Bad deployments get blocked automatically

---

## Common Problems & Solutions

### "ArgoCD says OutOfSync but won't update"

**What it means:** ArgoCD sees a difference but isn't applying it.

**Fix:**
```bash
# Force it to sync
kubectl patch app portfolio -n argocd \
  --type json -p='[{"op": "replace", "path": "/operation", "value": {"sync": {}}}]'
```

### "My app won't start (CrashLoopBackOff)"

**What it means:** Your app keeps crashing when it tries to start.

**Fix:** Check the logs to see what's wrong:
```bash
kubectl logs -n portfolio deployment/portfolio-api
```

### "I can't reach my app from the internet"

**What it means:** The app is running but the "front door" isn't configured.

**Fix:** Check the ingress (the front door):
```bash
kubectl describe ingress -n portfolio
```

---

## How to Undo a Bad Deployment (Rollback)

Made a mistake? ArgoCD makes it easy to go back:

**Option 1: Through the Dashboard**
1. Open ArgoCD UI (https://localhost:8080)
2. Click on your app
3. Click "History" tab
4. Pick a previous version
5. Click "Rollback"

**Option 2: Through Commands**
```bash
# See deployment history
helm history portfolio -n portfolio

# Go back to version 1
helm rollback portfolio 1 -n portfolio
```

---

## Shutting Everything Down

If you need to remove everything:

```bash
# Tell ArgoCD to delete the app (removes everything)
kubectl delete application portfolio -n argocd

# Remove the namespace (cleanup)
kubectl delete namespace portfolio
```

---

## How This Compares to Other Methods

| Feature | Method 1 (Basic) | Method 2 (Local) | **Method 3 (This)** |
|---------|------------------|------------------|---------------------|
| **Real AWS?** | No | Fake (LocalStack) | Yes, real AWS |
| **Auto-deploy?** | No, manual | No, manual | Yes, automatic |
| **Can undo mistakes?** | Hard | Medium | Easy (automatic) |
| **Production ready?** | No | No | **Yes!** |
| **Best for** | Learning | Testing | Real websites |

---

## Summary

**What you learned:**
1. **Helm** packages your app into an easy-to-deploy bundle
2. **ArgoCD** automatically deploys changes when you push to GitHub
3. **GitOps** means your Git repo is the "boss" - what's in Git is what runs
4. You never manually deploy - just push code and it happens automatically

**This is how professional DevOps teams deploy software.** You're learning enterprise-grade skills!

---

## Need Help?

- **ArgoCD Documentation:** https://argo-cd.readthedocs.io/
- **Helm Documentation:** https://helm.sh/docs/
- **Kubernetes Basics:** https://kubernetes.io/docs/tutorials/

---

**Congratulations!** You've set up a production-grade deployment pipeline. This is the same approach used by companies serving millions of users. You're ready for the real world!
