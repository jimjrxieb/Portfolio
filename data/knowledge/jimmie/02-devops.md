# DevOps Experience (Tools & Patterns)

## Current Stack: GitHub Actions + Advanced CI/CD
**Primary CI/CD:** GitHub Actions with production-grade pipelines, dual workflow architecture
**Kubernetes:** KinD/kind for local dev, production clusters via GHCR deployment, Helm + GitOps
**Security:** Trivy, Snyk scanning integrated in every pipeline, security-first container builds
**Observability:** Health endpoints, automated monitoring, real-time deployment verification  
**Infrastructure:** Local KIND + Cloudflare tunnel architecture, resource-optimized deployments
**AI-Assisted Development:** Claude + advanced prompt engineering for efficient development
**Recent Innovation:** Smart content vs code deployment pipelines (2min vs 10min deployments)

## Recent CI/CD Innovation: Dual Workflow Architecture
- **Smart Triggering**: Content changes (2min) vs code changes (10min) - separate workflows
- **Production-Grade**: GitHub Actions → GHCR → Production K8s (no local conflicts)
- **Automatic RAG Re-ingestion**: Content updates trigger immediate knowledge base refresh
- **Security Integration**: Trivy scanning, non-root containers, security contexts
- **Zero-Downtime**: Rolling updates with health checks and deployment verification
- **Environment Separation**: Production deployment independent of local KIND development

## GitHub Actions & Enterprise Pipelines  
- **Current standard**: GitHub Actions for all projects, enterprise-grade patterns
- **Pipeline stages**: build → test → security scan (Trivy/Snyk) → GHCR → K8s deployment
- **Smart GitOps**: Path-based triggering, automated RAG updates, content synchronization
- **Multi-environment**: Local KIND for development, production clusters for live deployment
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