# Portfolio Infrastructure

Three deployment methods showcasing progression from basic kubectl to production GitOps. Method 3 is live at [linksmlm.com](https://linksmlm.com).

---

## Deployment Methods

### [Method 1: Simple Kubernetes](method1-simple-kubectl/)
**Beginner | Raw YAML manifests**

Deploy to a local Kubernetes cluster with plain `kubectl apply`.

```bash
cd infrastructure/method1-simple-kubectl
kubectl apply -f .
```

**Runbook:** Step-by-step deployment guide in [RUNBOOK.md](method1-simple-kubectl/RUNBOOK.md)

**Use when:** Learning Kubernetes, understanding what each resource does.

---

### [Method 2: Terraform + LocalStack](method2-terraform-localstack/)
**Intermediate | Infrastructure as Code**

Full AWS stack simulation locally using Terraform + LocalStack. CloudFormation templates planned but not yet created.

```bash
cd infrastructure/method2-terraform-localstack/s2-terraform-localstack
terraform init
terraform apply
```

**Runbook:** Step-by-step deployment guide in [RUNBOOK.md](method2-terraform-localstack/RUNBOOK.md)

**Use when:** Testing AWS services locally, learning Terraform.

---

### [Method 3: Helm + ArgoCD](method3-helm-argocd/) (PRODUCTION)
**Advanced | GitOps on k3s**

Production deployment to a k3s home server via Cloudflare Tunnel. ArgoCD watches the shared Helm chart at `charts/portfolio/` and auto-syncs on every push.

```bash
# The ArgoCD application definition:
kubectl apply -f infrastructure/method3-helm-argocd/argocd/portfolio-application.yaml

# The Helm chart it deploys:
ls infrastructure/charts/portfolio/
```

**Runbook:** Server setup to production deploy in [RUNBOOK.md](method3-helm-argocd/RUNBOOK.md)

**Use when:** Production deployment with GitOps workflow.

---

## Directory Structure

```
infrastructure/
  README.md                          # This file
  charts/portfolio/                  # ACTIVE Helm chart (ArgoCD + CI/CD use this)
    Chart.yaml, values.yaml, templates/
  method1-simple-kubectl/            # Demo: raw kubectl apply -f
    README.md
    01-namespace.yaml ... 07-ingress.yaml
  method2-terraform-localstack/      # Demo: Terraform + LocalStack
    README.md
    s0-shared-mods/                  # Reusable Terraform modules
    s2-terraform-localstack/         # LocalStack stage
    s3-cloudformation/               # CloudFormation templates (planned)
  method3-helm-argocd/               # Demo: Helm + ArgoCD (PRODUCTION)
    README.md                        # Points to ../charts/portfolio/
    argocd/portfolio-application.yaml
  shared-security/                   # Shared K8s security configs
    README.md
    kubernetes/                      # Network policies, RBAC, pod security, node hardening
    scripts/                         # Remediation scripts
    reports/                         # Security scan reports
```

---

## Security & Policy Enforcement

### CI/CD Policies (Shift-Left)
Located at project root: [`GP-copilot/02-package/conftest-policies/`](../GP-copilot/02-package/conftest-policies/)

13 OPA/Rego policies enforced during CI to catch issues before deployment.

### Runtime Policies (Admission Control)
Gatekeeper is installed on the production cluster (`gatekeeper-system` namespace). Constraint templates and constraints are managed via the GP-copilot platform.

### Security Configurations
Located at: [`shared-security/`](shared-security/)

Network policies, RBAC, pod security standards, and node hardening configs shared across all methods.

---

## Method Comparison

| Feature | Method 1 | Method 2 | Method 3 |
|---------|----------|----------|----------|
| **Deployment Tool** | kubectl | Terraform | Helm + ArgoCD |
| **Infrastructure** | Local K8s | LocalStack (simulated AWS) | k3s home server |
| **GitOps** | No | No | Yes |
| **Infrastructure as Code** | No | Yes | Yes |
| **Rollback** | Manual | Terraform state | ArgoCD automatic |
| **Production** | No | No | **Yes** (linksmlm.com) |
| **Cost** | Free | Free | Free (self-hosted) |

---

## Production Stack (Method 3)

```
Internet -> Cloudflare Edge -> Cloudflare Tunnel -> k3s (Traefik ingress)
  UI (nginx :80)  on /
  API (FastAPI :8000) on /api (strip-prefix middleware)
  ChromaDB (:8000) internal only
```

CI/CD flow: push to main -> GitHub Actions builds images -> updates `charts/portfolio/values.yaml` -> ArgoCD auto-syncs -> rolling update.

---

## Additional Resources

- [Method 1 README](method1-simple-kubectl/README.md) - Simple kubectl deployment
- [Method 2 README](method2-terraform-localstack/README.md) - Terraform + LocalStack
- [Method 3 README](method3-helm-argocd/README.md) - Helm + ArgoCD
- [Security Configs](shared-security/README.md) - Network policies & RBAC
- [Conftest Policies](../GP-copilot/02-package/conftest-policies/README.md) - CI/CD validation
