# Portfolio Infrastructure

Multi-environment deployment infrastructure with **3 clear deployment methods**.

---

## 🎯 Choose Your Deployment Method

### [Method 1: Simple Kubernetes](method1-simple-kubectl/)
**⭐ Beginner | 5 minutes | No AWS**

Quick local development with Docker Desktop Kubernetes.

```bash
cd infrastructure/method1-simple-kubectl
kubectl apply -f .
```

**Use when:** Learning Kubernetes, rapid local development

---

### [Method 2: Terraform + LocalStack](method2-terraform-localstack/)
**⭐⭐ Intermediate | 15 minutes | LocalStack AWS**

Full AWS stack testing locally with Terraform.

```bash
cd infrastructure/method2-terraform-localstack
terraform init
terraform apply
```

**Use when:** Testing AWS services locally, learning Terraform, production-like environment on laptop

---

### [Method 3: Helm + ArgoCD](method3-helm-argocd/)
**⭐⭐⭐ Advanced | 30+ minutes | Real AWS**

Production deployment with GitOps to real AWS EKS.

```bash
cd infrastructure/method3-helm-argocd
kubectl apply -f argocd/portfolio-application.yaml
```

**Use when:** Production deployment, GitOps workflow, enterprise-grade infrastructure

---

## 📁 Directory Structure

```
infrastructure/
├── method1-simple-kubectl/      # Method 1: kubectl apply -f
│   ├── README.md
│   ├── 01-namespace.yaml
│   ├── 02-secrets-example.yaml
│   ├── 03-chroma-pvc.yaml
│   ├── 04-chroma-deployment.yaml
│   ├── 05-api-deployment.yaml
│   ├── 06-ui-deployment.yaml
│   └── 07-ingress.yaml
│
├── method2-terraform-localstack/ # Method 2: Terraform + LocalStack
│   ├── README.md
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── aws-resources/       # S3, DynamoDB, SQS
│       └── kubernetes-app/      # K8s deployments (coming soon)
│
├── method3-helm-argocd/         # Method 3: Helm + ArgoCD
│   ├── README.md
│   ├── helm-chart/              # Helm chart for Portfolio
│   │   ├── values.yaml
│   │   ├── values.prod.yaml
│   │   └── templates/
│   └── argocd/
│       └── portfolio-application.yaml
│
├── shared-gk-policies/          # Gatekeeper policies (all methods)
│   ├── README.md
│   ├── security/
│   ├── governance/
│   └── compliance/
│
├── shared-security/             # K8s security configs (all methods)
│   ├── README.md
│   ├── network-policies/
│   ├── rbac/
│   └── pod-security/
│
└── localstack/
    └── init-aws.sh              # Alternative LocalStack setup script
```

---

## 🔒 Security & Policy Enforcement

### CI/CD Policies (Shift-Left)
Located at project root: [`/conftest-policies/`](../conftest-policies/)

Enforced during CI/CD pipeline to catch issues **before** deployment.

### Runtime Policies (Admission Control)
Located at: [`shared-gk-policies/`](shared-gk-policies/)

Enforced by Gatekeeper at the cluster level to block non-compliant pods.

### Security Configurations
Located at: [`shared-security/`](shared-security/)

Network policies, RBAC, and Pod Security Standards.

---

## 📊 Method Comparison

| Feature | Method 1 | Method 2 | Method 3 |
|---------|----------|----------|----------|
| **Deployment Tool** | kubectl | Terraform | Helm + ArgoCD |
| **AWS Services** | ❌ None | ✅ LocalStack | ✅ Real AWS |
| **Time to Deploy** | 5 min | 15 min | 30+ min |
| **Learning Curve** | Easy | Medium | Hard |
| **Production Ready** | No | No | **Yes** |
| **GitOps** | ❌ No | ❌ No | ✅ Yes |
| **Infrastructure as Code** | ❌ No | ✅ Yes | ✅ Yes |
| **Rollback Support** | Manual | Terraform | Automatic |
| **Cost** | Free | Free | $$$ |

---

## 🚀 Quick Start Guides

### Prerequisites (All Methods)

- Docker Desktop with Kubernetes enabled
- kubectl configured
- Ollama running locally (for embeddings)
- NGINX Ingress Controller installed

### Install Prerequisites

```bash
# 1. Enable Kubernetes in Docker Desktop
# (Settings → Kubernetes → Enable Kubernetes)

# 2. Install NGINX Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# 3. Start Ollama
ollama serve
ollama pull nomic-embed-text
```

---

## 🎓 Learning Path

### New to Kubernetes?
Start with **[Method 1](method1-simple-kubectl/)** to understand basic K8s resources.

### Ready for Infrastructure as Code?
Move to **[Method 2](method2-terraform-localstack/)** to learn Terraform and AWS services.

### Ready for Production?
Graduate to **[Method 3](method3-helm-argocd/)** for GitOps with Helm and ArgoCD.

---

## 🛡️ Security Best Practices

### 1. Apply Security Policies

```bash
# Install Gatekeeper
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper gatekeeper/gatekeeper \
  -n gatekeeper-system --create-namespace

# Apply policies
kubectl apply -f infrastructure/shared-gk-policies/security/
kubectl apply -f infrastructure/shared-gk-policies/governance/
kubectl apply -f infrastructure/shared-gk-policies/compliance/
```

### 2. Apply Network Policies

```bash
kubectl apply -f infrastructure/shared-security/network-policies/
```

### 3. Apply RBAC

```bash
kubectl apply -f infrastructure/shared-security/rbac/
```

---

## 🔧 Troubleshooting

### Can't access application via ingress?

```bash
# Check ingress controller is running
kubectl get pods -n ingress-nginx

# Check your ingress
kubectl get ingress -n portfolio
kubectl describe ingress -n portfolio portfolio
```

### Pods not starting?

```bash
# Check pod status
kubectl get pods -n portfolio

# Check logs
kubectl logs -n portfolio deployment/portfolio-api
kubectl logs -n portfolio deployment/portfolio-ui
kubectl logs -n portfolio deployment/chroma

# Describe pod for events
kubectl describe pod -n portfolio <pod-name>
```

### Ollama connection issues?

```bash
# Test Ollama from your machine
curl http://localhost:11434/api/tags

# Check API logs for Ollama errors
kubectl logs -n portfolio deployment/portfolio-api | grep -i ollama
```

---

## 📚 Additional Resources

### Documentation
- [Method 1 README](method1-simple-kubectl/README.md) - Simple kubectl deployment
- [Method 2 README](method2-terraform-localstack/README.md) - Terraform + LocalStack
- [Method 3 README](method3-helm-argocd/README.md) - Helm + ArgoCD
- [Gatekeeper Policies](shared-gk-policies/README.md) - Runtime enforcement
- [Conftest Policies](../conftest-policies/README.md) - CI/CD validation
- [Security Configs](shared-security/README.md) - Network policies & RBAC

### External Links
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Helm Documentation](https://helm.sh/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [LocalStack Documentation](https://docs.localstack.cloud/)
- [Gatekeeper Documentation](https://open-policy-agent.github.io/gatekeeper/)

---

## 💡 Tips

- **Start simple:** Begin with Method 1 to learn Kubernetes basics
- **Test locally:** Use Method 2 to test AWS services without cost
- **Go production:** Use Method 3 when you're ready for real deployments
- **Security first:** Always apply Gatekeeper policies before deploying applications
- **Use conftest:** Run conftest locally before pushing to catch policy violations early

---

## 🤝 Contributing

When adding new features:
1. Test with **Method 1** first (fastest iteration)
2. Validate with **Method 2** (production-like)
3. Update **Method 3** Helm chart (production)
4. Update all READMEs

---

## 📝 License

See project root LICENSE file.

---

**Your infrastructure is now organized for success! 🚀**

Choose your method above and start deploying!
