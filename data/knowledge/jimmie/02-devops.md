# DevOps Experience (Tools & Patterns)

## Current Stack: GitHub Actions + Azure Pipelines
**Primary CI/CD:** GitHub Actions + Azure DevOps for enterprise-grade pipelines
**Kubernetes:** KinD/kind for local dev, Azure AKS for production, Helm + ArgoCD for GitOps
**Security:** Trivy, Snyk, and Defender for Cloud for comprehensive security scanning
**Observability:** Azure Monitor + Application Insights, Prometheus + Grafana for K8s
**Infrastructure:** Terraform for infrastructure as code, Azure Resource Manager templates
**AI-Assisted Development:** Claude + Cursor for enhanced productivity and code quality

## GitHub Actions & Azure Pipelines
- **Current standard**: GitHub Actions for open-source projects, Azure Pipelines for enterprise
- **Pipeline stages**: build → test → security scan (Trivy/Snyk/Defender) → container registry → K8s deployment
- **GitOps workflow**: ArgoCD monitors container registry for new images and auto-deploys
- **Multi-environment**: Automated promotion from dev → staging → production with approval gates
- **Security integration**: Built-in vulnerability scanning and compliance checks at every stage

## Legacy: Jenkins Experience (Learning Foundation)
- **Historical project**: Terraform-provisioned Jenkins infrastructure on AWS (7 EC2 instances)
- **Architecture**: Jenkins controller, build agents, private registry, monitoring, staging environment
- **Value**: Taught infrastructure automation fundamentals and CI/CD principles
- **Evolution**: Migrated from Jenkins to cloud-native solutions (GHA/Azure) for better scalability and maintenance

## Proper way to pull a project
- If I **have write access** → `git clone` the canonical repo and create branches/PRs
- If I **don't have write access** or want to propose changes → **fork** the repo to my namespace, then PR from fork to upstream
- Always read the repo's `CONTRIBUTING.md` to match branching, commit, and DCO/signoff rules

## Security/DevSecOps habits
- Never commit secrets; use `.env.example`, Kubernetes Secrets, or a vault
- SBOM + scans in CI (Trivy, Snyk). Pin dependency versions. Non-root containers
- K8s: `runAsNonRoot`, drop capabilities, readiness/liveness probes, NetworkPolicies