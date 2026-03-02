# Method 3: Production Deployment (Helm + ArgoCD)

This is the **production** deployment method, live at [linksmlm.com](https://linksmlm.com).

## Architecture

```
GitHub repo (main branch)
  |
  |-- GitHub Actions: build images -> push to ghcr.io -> update values.yaml
  |
  +-- ArgoCD watches infrastructure/charts/portfolio/
       |
       +-- Syncs to k3s cluster (portfolio namespace)
            |
            +-- Traefik ingress -> Cloudflare Tunnel -> Internet
```

## What's Here

```
method3-helm-argocd/
  README.md                              # This file
  argocd/portfolio-application.yaml      # ArgoCD Application definition
```

## Where's the Helm Chart?

The Helm chart lives at [`../charts/portfolio/`](../charts/portfolio/), shared between CI/CD and ArgoCD. This avoids chart duplication — there's one source of truth.

ArgoCD monitors `infrastructure/charts/portfolio/` in the GitHub repo. When CI/CD updates `values.yaml` with new image tags, ArgoCD detects the change and syncs.

## CI/CD Flow

1. Push code to `main`
2. GitHub Actions builds Docker images tagged `main-<short-sha>`
3. Images pushed to `ghcr.io/jimjrxieb/`
4. GitHub Actions updates image tags in `charts/portfolio/values.yaml` (auto-commit with `[skip ci]`)
5. ArgoCD detects `values.yaml` changed (polls every 3 minutes)
6. ArgoCD renders the Helm chart and applies the diff to the cluster
7. Kubernetes performs a rolling update — zero downtime

## Production Stack

- **Server**: k3s single-node cluster on a home server
- **Ingress**: Traefik (built into k3s)
- **Tunnel**: Cloudflare Tunnel (http2 protocol)
- **TLS**: cert-manager with Let's Encrypt
- **Namespace**: `portfolio`

## Key Commands

```bash
# Check ArgoCD sync status
kubectl get application -n argocd portfolio

# View the live Helm chart
ls ../charts/portfolio/

# Apply ArgoCD application (first-time setup)
kubectl apply -f argocd/portfolio-application.yaml

# Force a sync
argocd app sync portfolio

# Check what's running
kubectl get pods -n portfolio
```

## Key Terms

| Term | What It Means |
|------|---------------|
| **Helm** | Package manager for Kubernetes — templates + values = manifests |
| **ArgoCD** | GitOps controller that watches a repo and syncs to a cluster |
| **GitOps** | Git is the source of truth — what's in the repo is what runs |
| **Sync** | ArgoCD making the cluster match what's in Git |
| **Self-heal** | ArgoCD reverting manual cluster changes to match Git |

## Comparison to Other Methods

| Feature | Method 1 (kubectl) | Method 2 (Terraform) | **Method 3 (This)** |
|---------|--------------------|--------------------|---------------------|
| **Deployment** | Manual `kubectl apply` | `terraform apply` | Automatic (push to Git) |
| **Rollback** | Manual | Terraform state | ArgoCD (automatic) |
| **Drift detection** | None | `terraform plan` | Continuous (self-heal) |
| **Production** | No | No (LocalStack) | **Yes** (linksmlm.com) |
