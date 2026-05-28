# Tools and Stack — The GP-Copilot Toolchain

## Philosophy: Open Source First

Open source handles the load. Paid tools handle the gap.

GP-Copilot uses open source to cover what enterprise tools charge for. Trivy does what Prisma Cloud does for container scanning. Semgrep does what Checkmarx does for SAST. Kyverno does what Styra does for admission control. Falco does what Sysdig Secure does for runtime detection. The coverage is real and the results are auditable.

Where open source coverage is sufficient — use it. Where the gap justifies cost — document it and recommend the right tool. This gives clients honest coverage without unnecessary license spend. A senior engineer does not sell tools. A senior engineer solves problems and recommends what actually fits.

## The 5 C's — Tools by Pillar

### Code (SAST, Secrets, Dependencies)
- **Semgrep** — SAST, custom rules, OWASP top 10 detection
- **Bandit** — Python-specific security linting
- **Gitleaks** — Git history secret scanning (tokens, API keys, credentials)
- **detect-secrets** — Pre-commit secret detection with baseline management
- **Grype** — Dependency CVE scanning (language-agnostic)
- **pip-audit** — Python dependency audit
- **npm audit** — Node.js dependency audit
- **Trivy fs** — Filesystem vulnerability scanning including dependencies

### Container (Images, Dockerfiles, Runtime)
- **Trivy** — Container image CVE scanning, SBOM generation
- **Hadolint** — Dockerfile linting (best practices, security)
- **Grype** — Container image vulnerability matching
- **cosign** — Container image signing and verification (supply chain)
- Security defaults enforced: non-root USER, multi-stage builds, pinned base images, read-only root filesystem, dropped capabilities

### Cluster (Kubernetes Policy, RBAC, Admission Control)
- **kube-bench** — CIS Kubernetes Benchmark compliance checks
- **Kubescape** — NSA/CISA hardening guidance, RBAC analysis
- **Polaris** — Kubernetes workload best practices
- **Kyverno** — Policy-as-code admission controller (mutating + validating)
- **Gatekeeper (OPA)** — Rego-based admission control, runtime enforcement
- **Conftest** — Policy testing for Helm/YAML manifests in CI
- **Falco** — Runtime threat detection (syscall-level behavioral analysis)

### Cloud (IaC, AWS, Cloud Config)
- **Checkov** — Terraform/IaC security scanning
- **Tfsec** — Terraform static analysis
- **Terrascan** — Multi-cloud IaC scanning
- **Prowler** — AWS security best practices assessment
- **Trivy config** — Cloud configuration scanning

### Compliance (Evidence, Frameworks, Reporting)
- **BERU AI** — Internal GRC analyst model (LLaMA 3.1-8B fine-tuned on NIST 800-53)
- **CrewAI** — Multi-agent framework for automated compliance evidence gathering
- **SQLite** — Findings databases (code.db, container.db, cluster.db, cloud.db)
- Custom evidence APIs producing machine-readable JSON audit trails
- POA&M generation from structured findings data

## Infrastructure and Platform Stack

### Kubernetes
- **k3s** — Lightweight Kubernetes (production on private host)
- **kind / minikube** — Local development clusters
- **ArgoCD** — GitOps continuous deployment (automated sync, self-heal, prune)
- **Traefik** — Ingress controller with Gateway API support
- **cert-manager** — Automatic TLS certificate management (Let's Encrypt)
- **Velero** — Backup and disaster recovery

### CI/CD
- **GitHub Actions** — Primary CI/CD pipeline (9 parallel security scanners)
- **Helm** — Kubernetes package management
- **Docker** — Container builds (multi-stage, non-root, pinned tags)
- **ghcr.io** — Container registry (GitHub Container Registry)

### Observability
- **Prometheus + Grafana** — Metrics and dashboards (monitoring namespace)
- **Fluent Bit** — Log forwarding (SIEM gap item in current POA&M)

### Secrets and Identity
- **External Secrets Operator** — Kubernetes secret sync from external vaults
- **HashiCorp Vault** — Secrets management (vault namespace on cluster)
- **OIDC** — Identity federation

### Cloud Infrastructure
- **Cloudflare Tunnel** — Zero-trust network access (no exposed ports, http2 protocol)
- **Cloudflare DNS** — Domain management (linksmlm.com)
- **Tailscale** — Private network for management access

## Application Stack (Portfolio — linksmlm.com)

- **FastAPI** (Python) — Backend API, streaming Claude responses
- **React + Vite** (TypeScript) — Frontend, ESLint strict mode
- **ChromaDB** — Vector database for RAG (nomic-embed-text 768-dim embeddings)
- **Ollama** — Local embedding server (nomic-embed-text model)
- **Claude API** (Anthropic) — Primary LLM for Sheyla AI assistant
- **HuggingFace** (Qwen2.5-1.5B) — Local fallback LLM for air-gap scenarios

## AI/ML Stack

- **Ollama** — Local model serving (JADE, KATIE, BERU, embedding models)
- **LangGraph** — Multi-step agentic reasoning framework
- **LangChain** — RAG pipeline, text splitting, retrieval chains
- **ChromaDB** — Vector store (33k+ documents across 7 collections)
- **scikit-learn** — RANK-AI classifier (E/D/C/B/S rank routing)
- **MLflow** — Experiment tracking for model training runs
- **HuggingFace Transformers** — Model fine-tuning base
- **PEFT / LoRA** — Parameter-efficient fine-tuning
- **llama.cpp** — GGUF quantization and local inference

## Security Standards (Always Enforced)

25 non-negotiable rules enforced on every line of code:
- No eval/exec/compile with dynamic input
- No shell=True with string interpolation
- No SQL string concatenation — parameterized queries only
- No unsafe deserialization (no pickle.loads, yaml.load → yaml.safe_load)
- No MD5/SHA1 for security, no random for tokens
- No hardcoded secrets
- No TLS verification disabled
- No CORS wildcard in production
- Input validation at all system boundaries
- secrets module for all token generation
- All dependencies pinned with exact versions and justification
- CVE scans (pip-audit, npm audit, trivy) before committing dependency changes
- Base images pinned (never :latest)
- Non-root container USER always set
- K8s securityContext always set (runAsNonRoot, readOnlyRootFilesystem, drop ALL capabilities)
- Resource limits and health probes always set
