# Jimmie Coleman - Professional Bio & Projects

## Professional Summary

Jimmie Coleman is an AI Engineer and DevSecOps Specialist with production deployments serving real enterprise clients. His Portfolio project embodies both skillsets: **Sheyla** (the AI chatbot) demonstrates AI engineering—production RAG pipelines, semantic search across 2,600+ embeddings, LLM integration with Claude API, and intelligent chunking strategies. The platform infrastructure demonstrates **DevSecOps**—CI/CD with 6-tool parallel security scanning, 3 progressive Kubernetes deployment methods (kubectl → Terraform/LocalStack → Helm/ArgoCD), policy-as-code with OPA/Gatekeeper, and AWS deployments via LocalStack development to real cloud production.

Currently operating GP-Copilot, an autonomous DevSecOps platform achieving 70% auto-fix rates on security findings with a custom fine-tuned LLM (JADE v0.9). His work with ZRS Management (Orlando) manages 4,000+ residential units through AI-powered property reporting and RPA workflows. Holds CKA and CompTIA Security+ certifications, currently pursuing AWS AI Practitioner.

## Core Expertise

### DevSecOps & Infrastructure
- **Track Record**: 70% auto-fix rate on security findings, 14 integrated scanner tools, 29,000+ RAG vectors
- **Enterprise Clients**: ZRS Management (4,000+ property units), production Kubernetes clusters running 24/7
- **Certifications**: CKA (Certified Kubernetes Administrator), CompTIA Security+, working on AWS AI Practitioner
- **Kubernetes**: 3-pod production architecture (UI, API, ChromaDB), 3 progressive deployment methods
- **Security Automation**: 6-tool CI/CD pipeline (detect-secrets, Semgrep, Trivy, Bandit, Safety, npm audit)
- **Policy-as-Code**: OPA/Conftest with 13 security policies and 11 automated tests in CI, Gatekeeper runtime admission control
- **CI/CD**: GitHub Actions with parallel security scanning, every build runs through secure GHA pipeline
- **Three Progressive Deployment Methods** (showing evolution from beginner to enterprise):
  - Method 1: Simple `kubectl apply -f` commands for basic deployments
  - Method 2: Terraform + LocalStack tools to simulate AWS services locally before production deployment
  - Method 3: Helm charts + ArgoCD GitOps automatically pulling and deploying code with every sync
- **Container Security**: Multi-stage Docker builds, non-root containers, security contexts, Pod Security Standards
- **Network Security**: Cloudflare Tunnel (TLS-encrypted public access), Kubernetes Network Policies, RBAC
- **Philosophy**: Every build/deployment uses OPA policies for consistency and security enforcement

### AI/ML Engineering
- **RAG Pipeline**: Production ChromaDB with 2,656+ vector embeddings, <100ms semantic search
- **Vector Embeddings**: Ollama nomic-embed-text (768-dimensional), intelligent chunking (1000 words, 200 overlap)
- **LLM Integration**: Claude API (Anthropic claude-3-haiku-20240307), cost-optimized production inference
- **Vector Database**: ChromaDB 0.5.18+ with persistent SQLite backend, versioned collections, atomic swaps
- **Knowledge Base**: DevSecOps policies, API architecture, security docs, deployment methods, cloud infrastructure
- **Ingestion Pipeline**: Markdown sanitization → chunking → Ollama embedding → ChromaDB storage
- **LLM Fine-tuning**: Google Colab + HuggingFace for domain-specific models (property management, compliance)
- **AI Assistants**: Sheyla personality system, dynamic prompts, source citations, zero-downtime updates

### Backend Development
- **FastAPI**: Production-grade API with async/await, security headers, CORS, rate limiting
- **Python**: Clean architecture, type hints, Pydantic models, error handling
- **Microservices**: Container-based deployments, service discovery, health checks

### Frontend Development
- **React 18 + TypeScript**: Modern component architecture, hooks, async patterns
- **UI Frameworks**: Material-UI 7.3.2, Tailwind CSS 4.1.12, custom themes
- **Build Tools**: Vite 5.1.0, multi-stage Docker builds, production optimization

## Certifications
- Certified Kubernetes Administrator (CKA)
- CompTIA Security+

## Key Projects

### 1. LinkOps AI-BOX with Jade Assistant (Primary Project)

**Status**: Raising investment for product development
**Testing Partner**: ZRS Management (Orlando) - property management reporting and marketing automation

**Problem Solved**: Companies want AI but fear security risks and lack technical resources. Cloud solutions expose sensitive data.

**Solution**: Plug-and-play hardware box with local AI that keeps all data on-premises.

**Technical Stack**:
- Qwen2.5 1.5B LLM for local inference
- ChromaDB for vector storage and RAG
- Custom RPAs for workflow automation
- Okta session integration for secure data gathering

**Current Capabilities**:
- Gathers and vectorizes weekly property information through Okta sessions
- Provides reports for upper management and property owners
- Queries property data via chatbox (vacancies, move-ins, etc.)
- Uses company policies and recommended formats for reports
- Alerts and summarizes work orders for maintenance tracking

**In Development**:
- Vendor suggestions based on work history, cost, and quality of work
- Invoice and contractor payment automation (pending permission)

**Business Value**:
- Data stays completely local (critical for property management, healthcare, legal)
- No ongoing cloud costs or subscription fees
- Peace of mind for data-sensitive industries

**Tech Stack**: Qwen2.5 1.5B, ChromaDB, RPA automation, Okta integration, secure hardware box

### 2. Portfolio RAG System (This Project)

**Purpose**: Demonstrate production-grade AI/infrastructure skills to potential employers and investors

**Architecture**:
- **Frontend**: React 18 + TypeScript, Vite build, Material-UI + Tailwind CSS
- **Backend**: FastAPI with Claude 3.5 Sonnet integration, Sheyla personality system
- **RAG Engine**: ChromaDB + Ollama embeddings (nomic-embed-text, 768-dim)
- **Infrastructure**: 3 deployment methods (kubectl, Terraform+LocalStack, Helm+ArgoCD)
- **Security**: OPA/Conftest policies, Gatekeeper, security contexts, non-root containers
- **Deployment**: Docker multi-stage builds, Kubernetes, Cloudflare Tunnel (linksmlm.com)

**Technical Highlights**:
- 88 embeddings from 30 curated documents (bio, projects, DevOps, AI/ML, FAQs)
- Dual-mode ChromaDB (HTTP for K8s, persistent for local dev)
- Multi-provider LLM support (Claude primary, local fallback)
- Production security: CORS, rate limiting (30 req/min), security headers
- 3-tier deployment complexity for different skill demonstrations

**Demonstrates**:
- End-to-end AI system design and implementation
- Production Kubernetes patterns
- Security-first development
- Infrastructure as Code
- Full-stack development skills

### 3. ZRS Management Testing Partnership

**Partner**: ZRS Management (Orlando, FL)
**Industry**: Property Management
**Role**: Built RPAs for reports and marketing automation

**Technical Implementation**:
- Jade Box gathers and vectorizes weekly information through Okta sessions
- Qwen2.5 1.5B LLM with ChromaDB for local RAG
- Custom RPAs for property reporting workflows

**Current Capabilities**:
- Property data queries via chatbox (vacancies, move-ins, etc.)
- Reports for upper management and property owners
- Uses ZRS policies and recommended formats
- Work order alerts and summaries

**In Development**:
- Vendor suggestions based on work history, cost, and quality
- Invoice and contractor payment automation (pending permission)

### 4. LinkOps Afterlife (Open Source)

**Purpose**: Digital legacy preservation platform
**Status**: Open-source community project
**Philosophy**: Technology serving human connection

**Innovation**:
- AI-powered interactive memory preservation
- User-owned data, bring-your-own-keys approach
- React + FastAPI + D-ID + ElevenLabs integration

**Tech Stack**: React, FastAPI, D-ID API, ElevenLabs API, user-owned data model

## Technical Skills by Category

### Languages & Frameworks
- **Python**: FastAPI, async/await, Pydantic, type hints
- **JavaScript/TypeScript**: React 18, Node.js, async patterns
- **Infrastructure**: YAML, HCL (Terraform), Rego (OPA), Bash
- **Markup**: Markdown, JSON, TOML

### DevSecOps Tools
- **Container**: Docker (multi-stage builds, non-root, security contexts)
- **Orchestration**: Kubernetes (CKA certified), Helm, ArgoCD
- **CI/CD**: GitHub Actions, automated security scanning
- **IaC**: Terraform, Terragrunt, GitOps patterns
- **Security**: OPA/Conftest, Gatekeeper, Trivy, Snyk
- **Monitoring**: Prometheus, Grafana, CloudWatch

### AI/ML Stack
- **LLMs**: Claude 3.5 Sonnet, HuggingFace models, GPT, Qwen2.5
- **Vector DBs**: ChromaDB (production), SQLite backend
- **Embeddings**: Ollama (nomic-embed-text), 768-dimensional
- **RAG**: Chunking strategies, semantic search, citation generation
- **Fine-tuning**: Google Colab, HuggingFace Trainer API
- **Orchestration**: LangGraph, MCP tools

### Cloud & Platforms
- **AWS**: S3, Lambda, Secrets Manager, CloudWatch, DynamoDB, SQS
- **Local Dev**: LocalStack (AWS emulation), Docker Desktop Kubernetes
- **Networking**: Cloudflare Tunnel, DNS, TLS/SSL
- **Databases**: SQLite, PostgreSQL, DynamoDB

## Architecture & Design Patterns

### Infrastructure Patterns
- **GitOps**: Declarative infrastructure, version control, automated sync
- **Policy as Code**: OPA/Conftest for CI/CD, Gatekeeper for runtime
- **Defense in Depth**: 5-layer security (Conftest, Gatekeeper, NetworkPolicy, RBAC, PodSecurity)
- **Zero Trust**: Default-deny network policies, RBAC least privilege
- **Atomic Updates**: Versioned collections, blue-green deployments

### Application Patterns
- **Microservices**: Container-based, service mesh ready, health checks
- **Async Processing**: FastAPI async/await, streaming LLM responses
- **Graceful Degradation**: Fallback providers, error handling, retries
- **Configuration Management**: Environment variables, secrets, ConfigMaps

### RAG Patterns
- **Chunking**: 1000 words with 200-word overlap (20% standard)
- **Metadata Enrichment**: Source tracking, timestamps, relevance scores
- **Dual-mode Storage**: HTTP (K8s) + Persistent (local dev)
- **Citation Generation**: Source attribution with relevance scores

## Development Workflow

### Local Development
- WSL2 Ubuntu on Windows for native Linux tooling
- Docker Desktop Kubernetes for local K8s testing
- LocalStack for AWS service emulation
- Hot reload with Vite (frontend) and uvicorn (backend)

### Production Deployment
- Multi-stage Docker builds (builder + runtime)
- Non-root containers for security
- Health checks (startup, readiness, liveness)
- Resource limits and requests
- Secrets via Kubernetes Secrets or AWS Secrets Manager

### Security Practices
- Security scanning in CI/CD (Trivy, Snyk)
- Policy validation before deployment
- Non-root user enforcement
- Privilege escalation prevention
- Read-only root filesystems
- Capability drops (ALL)

## Interview Talking Points

### "Tell me about yourself"

"I'm an AI Engineer and DevSecOps Specialist—my Portfolio project demonstrates both. Sheyla, the AI chatbot you can try, shows my AI engineering: production RAG with 2,600+ embeddings, semantic search, and LLM integration. The infrastructure shows DevSecOps: CI/CD with 6-tool security scanning, 3 Kubernetes deployment methods from kubectl to Helm/ArgoCD, and Terraform with LocalStack for AWS development. I also run GP-Copilot, an autonomous security platform achieving 70% auto-fix rates, and I'm working with ZRS Management on AI-powered property reporting for 4,000+ units."

### "What's your biggest technical achievement?"

"GP-Copilot with JADE v0.9—a custom fine-tuned LLM I trained on 300,000+ security examples. It integrates 14 scanners (Trivy, Semgrep, Gitleaks, Kubescape) and achieves 70% auto-remediation on findings. The AI engineering: 29,000+ RAG vectors for context-aware fix recommendations. The DevSecOps: runs 24/7 in production Kubernetes with zero cloud dependencies, HIPAA/SOC2 ready. Both skillsets working together."

### "Tell me about your DevSecOps experience"

"I'm CKA and Security+ certified with production Kubernetes running 24/7. My CI/CD pipelines run 6 security tools in parallel (detect-secrets, Semgrep, Trivy, Bandit, Safety, npm audit). I've implemented 3 deployment methods: basic kubectl, Terraform with LocalStack for AWS mocking ($0 dev costs), and Helm with ArgoCD for GitOps. Policy-as-code with OPA/Conftest (13 policies) and Gatekeeper for runtime admission. Defense-in-depth: NetworkPolicies, RBAC, Pod Security Standards."

### "Tell me about your AI engineering experience"

"Sheyla in my Portfolio is production RAG: ChromaDB with 2,600+ embeddings, sub-100ms semantic search, intelligent chunking (1000 words, 200 overlap), and Claude API integration. GP-Copilot scales this to 29,000+ security vectors with a fine-tuned Qwen2.5-7B model I trained myself. I've built full ingestion pipelines: sanitization, chunking, embedding generation, versioned collections for zero-downtime updates. The AI-BOX I'm building for ZRS Management uses local Qwen inference to keep all property data on-premises."

### "What makes you different?"

"I ship both skillsets together. My Portfolio isn't just a demo—Sheyla is production RAG, and the infrastructure is real DevSecOps with Kubernetes, Terraform, and policy-as-code. GP-Copilot runs 24/7 fixing actual vulnerabilities. ZRS Management uses my AI for real property reporting. I bridge AI engineering and DevSecOps because modern systems need both: smart automation AND secure, scalable infrastructure."

## Mentorship & Inspiration

### Constant Young
Constant Young is Jimmie's mentor and Mr. Frank's second favorite. He is the domain SME (Subject Matter Expert) behind GP-Copilot. Constant set Jimmie on the DevSecOps path, persuading him to obtain his CompTIA Security+ and CKA certifications. Jimmie looks up to Constant like Deku admires All Might in My Hero Academia - he's someone Jimmie truly aspires to be like in the cloud security world. Having a mentor like Constant has been invaluable to Jimmie's professional growth and technical development.

## Contact & Links

- **GitHub**: github.com/jimjrxieb
- **Portfolio**: linksmlm.com (via Cloudflare Tunnel)
- **LinkedIn**: [Available on request]
- **Location**: Based in US, available remote

## Current Focus

1. **Raising investment** for LinkOps AI-BOX product development
2. **Expanding ZRS testing** and gathering metrics
3. **Building portfolio** of real-world AI deployments
4. **Open source contributions** to AI/infrastructure projects

## Professional Goals

- Scale LinkOps AI-BOX to multiple property management clients
- Expand to other data-sensitive industries (healthcare, legal, finance)
- Build open-source tools for local-first AI deployment
- Mentor others in DevSecOps and practical AI implementation

---

*Last updated: January 2026*
*This document is part of the Portfolio RAG knowledge base*
