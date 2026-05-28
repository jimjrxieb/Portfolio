# Portfolio-Prod — Production AI Portfolio Platform

> RAG-powered portfolio with an AI assistant (Sheyla), assessed end-to-end using the CBBP security methodology

**Live**: [https://linksmlm.com](https://linksmlm.com)

[![CI](https://github.com/jimjrxieb/Portfolio/actions/workflows/main.yml/badge.svg)](https://github.com/jimjrxieb/Portfolio/actions/workflows/main.yml)
[![Status](https://img.shields.io/badge/status-production-green)](https://linksmlm.com)
[![k3s](https://img.shields.io/badge/kubernetes-k3s-326CE5)](./infrastructure/)
[![ArgoCD](https://img.shields.io/badge/gitops-argocd-orange)](./infrastructure/charts/)

---

## What This Is

A production RAG (Retrieval-Augmented Generation) platform that combines a FastAPI backend, React/Vite frontend, and ChromaDB vector database to deliver semantic search over a personal knowledge base with Claude-generated responses.

**Sheyla** is the AI assistant — she answers questions about experience, projects, and certifications grounded in RAG context, not hallucination. Her security stack is mapped to **OWASP LLM Top 10** and governed by **NIST AI RMF**.

This repo is also a live target for the **CBBP methodology** (Comply → Build → Break → Prove). The `CBBP/` directory contains the public security assessment artifacts produced by running that methodology against this system.

---

## Architecture

```
Browser → Cloudflare Tunnel → Traefik (k3s) → UI (nginx) / API (FastAPI)
                                                      ↓
                                             ChromaDB (embeddings)
                                                      ↑
                                          Ollama (nomic-embed-text)
                                                      
                                    API → Claude API (streaming)
                                        → HuggingFace Qwen2.5-1.5B (fallback)
```

### Service Topology

| Service | Image | Port |
|---------|-------|------|
| UI | `ghcr.io/jimjrxieb/portfolio-ui` | 80 (nginx) |
| API | `ghcr.io/jimjrxieb/portfolio-api` | 8000 (FastAPI) |
| ChromaDB | `chromadb/chroma:1.0.0` | 8000 (internal) |

### Request Flow

```
User query → api/routes/chat.py → 7-layer security check (sheyla_security/)
           → RAG retrieval (ChromaDB top-3) → Claude API → validated response → client
```

---

## Tech Stack

### Backend (Python 3.11)
- **FastAPI** + Uvicorn — async API, streaming responses
- **ChromaDB ≥1.0.0** — vector store, persistent SQLite
- **Anthropic Claude API** — primary LLM (streaming)
- **HuggingFace Qwen2.5-1.5B** — local fallback LLM
- **Ollama nomic-embed-text** — 768-dim local embeddings

### Frontend (TypeScript)
- **React 18** + Vite — UI framework and build tool
- **Tailwind CSS** — styling
- **Nginx** — production static serving (non-root, port 8080)

### Infrastructure
- **k3s** — single-node Kubernetes (production)
- **ArgoCD** — GitOps continuous deployment (auto-sync, self-heal, prune)
- **Helm** — Kubernetes packaging (`infrastructure/charts/portfolio/`)
- **Traefik** — Ingress (Gateway API HTTPRoutes)
- **Cloudflare Tunnel** — zero-trust public access, http2 protocol
- **cert-manager** — automatic TLS (Let's Encrypt)
- **External Secrets** + **Vault** — secrets management

---

## Security

### CI/CD Pipeline (9 parallel scanners)

| Scanner | Domain |
|---------|--------|
| Semgrep | SAST — code vulnerabilities |
| Bandit | Python security linting |
| Safety | Python dependency CVEs |
| detect-secrets | Secret scanning (pre-commit baseline) |
| Checkov | IaC / Terraform misconfiguration |
| Trivy | Container image CVEs + SBOM |
| SonarCloud | Code quality + security |
| npm audit | Node.js dependency CVEs |
| OPA/Conftest | Kubernetes manifest policy validation |

### AI Security (OWASP LLM Top 10)

Sheyla's security stack is implemented in `api/sheyla_security/` and mapped to the OWASP LLM Top 10:

| Control | Implementation | OWASP |
|---------|---------------|-------|
| Prompt injection detection | 15+ regex patterns | LLM01 |
| Input sanitization | Boundary validation, encoding fixes | LLM06 |
| Output filtering | PII redaction, path sanitization | LLM02 |
| Rate limiting | 30 req/min per IP | DoS protection |
| Audit trail | JSONL with hashed IPs | NIST AI RMF — MEASURE |

### Runtime (K8s)

- **OPA/Gatekeeper** — admission control (runtime policy enforcement)
- **Conftest** — CI manifest validation (13 policies)
- **NetworkPolicy** — default-deny with explicit allow rules
- **Pod Security**: `runAsNonRoot`, `readOnlyRootFilesystem`, drop ALL capabilities
- **Non-root containers**: `appuser` UID 1000 on all images

---

## CBBP Security Assessment

This repo is assessed using the **CBBP methodology** (Comply → Build → Break → Prove), which maps to the NIST Risk Management Framework:

| Phase | NIST RMF | What It Produces |
|-------|----------|-----------------|
| **COMPLY** | Categorize + Select | SSP, control gap analysis, NIST 800-53 mappings |
| **BUILD** | Implement | Hardened IaC, CI/CD pipeline, policy-as-code |
| **BREAK** | Assess | Scanner outputs, adversarial validation, POA&M findings |
| **PROVE** | Authorize + Monitor | SAR, POA&M, evidence package, audit trail |

Public assessment artifacts live in `CBBP/`:

```
CBBP/
  COMPLY/   scope, NIST 800-53 map, NIST AI RMF map, assessment sheets, SSP
  BUILD/    DevSecOps implementation summary, CKS-style tool map
  BREAK/    method, guardrails, evidence-routing model, findings
  PROVE/    SAR, POA&M, CISO summary, audit trail
```

The BREAK material shows how controls are routed to `greatsuccess` (validated, audit-ready) versus `patchworkneeded` (open findings, not yet provable). Open POA&M items are tracked with unique IDs, owners, and milestone dates — not swept under the rug.

---

## RAG Pipeline

```
rag-pipeline/00-new-rag-data/      → Drop new source documents here
rag-pipeline/02-prepared-rag-data/ → Chunked + sanitized (prepare_data.py)
rag-pipeline/03-ingest-rag-data/   → Embedded + stored in ChromaDB (ingest_data.py)
rag-pipeline/04-processed-rag-data/→ Archived originals
```

**Run the pipeline** (requires Ollama running locally with nomic-embed-text):
```bash
cd rag-pipeline
python run_pipeline.py         # full: prep → ingest → archive
python run_pipeline.py status  # show collection stats
```

**Knowledge base**: 251 chunks, 30 source documents, 768-dim vectors, `portfolio_knowledge` collection.

**Sync to production** (after local pipeline run):
```bash
# Reset old collection on cluster
CHROMA_URL=http://localhost:8001 python reset_collection.py

# Run pipeline against cluster ChromaDB
CHROMA_URL=http://localhost:8001 python run_pipeline.py
```

---

## Deployment

### Production (ArgoCD GitOps)

Push to `main` → GitHub Actions builds + tags images → auto-commits tag to `values.yaml` → ArgoCD detects + syncs → rolling update.

Image tags: `main-<short-sha>` at `ghcr.io/jimjrxieb/portfolio-{api,ui}`.

```bash
# Check ArgoCD sync status
kubectl get application portfolio -n argocd

# Force refresh
kubectl annotate application portfolio -n argocd argocd.argoproj.io/refresh=normal
```

**Hard rule**: ArgoCD-managed resources are fixed in git only. Never `kubectl patch` them directly.

### Local Development (Docker Compose)

```bash
cp .env.example .env          # add CLAUDE_API_KEY + OLLAMA_URL
docker-compose up --build -d
docker-compose logs -f api
```

Access: UI → http://localhost:3000 · API → http://localhost:8000 · ChromaDB → http://localhost:8001

### Kubernetes (3 methods)

```bash
# Method 1 — kubectl manifests (learning)
kubectl apply -f infrastructure/method1-simple-kubectl/

# Method 2 — Terraform + LocalStack (IaC practice)
cd infrastructure/method2-terraform-localstack && terraform apply

# Method 3 — Helm + ArgoCD (production)
helm upgrade --install portfolio infrastructure/charts/portfolio/ \
  --namespace portfolio --create-namespace \
  -f infrastructure/charts/portfolio/values.yaml
```

```bash
# Makefile shortcuts
make deploy-kind       # build + deploy to kind
make deploy-minikube   # build + deploy to minikube
make security-scan     # Trivy image scan + SBOM
make helm-security     # Helm lint + Conftest policy check
```

---

## Configuration

### Required Environment Variables

```bash
# Primary LLM
LLM_PROVIDER=claude
CLAUDE_API_KEY=sk-ant-...

# Embeddings (local Ollama)
OLLAMA_URL=http://host.docker.internal:11434

# Vector DB
CHROMA_URL=http://chromadb:8000

# App
ENVIRONMENT=production
CORS_ORIGINS=https://linksmlm.com
```

See [`.env.example`](.env.example) for the full template.

---

## Build Commands

```bash
# UI
cd ui && npm run dev        # Vite dev server :5173
cd ui && npm run build      # production build
cd ui && npm run lint        # ESLint

# API
cd api && uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Tests
cd ui && npx playwright test                   # all e2e
cd ui && npx playwright test tests/api.spec.ts # single file

# OPA policy tests
conftest verify --policy GP-copilot/02-package/conftest-policies/
```

---

## Path Routing (Production)

Traefik `strip-api` middleware removes `/api` prefix before forwarding to FastAPI:

- Browser calls `/api/chat` → Traefik strips to `/chat` → FastAPI handles `/chat`
- `VITE_API_BASE_URL=/api` baked at Docker build time
- **Never hardcode `/api` in fetch calls** — use `${API_BASE}/endpoint`

---

## Common Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| 502 from `/api/` | API pod down or rolling update in progress | `kubectl get pods -n portfolio`; wait for `1/1 Running` |
| 502 persistent | Cloudflare tunnel half-open connections | `sudo systemctl restart cloudflared` |
| Chat "Unknown error" | 502 hitting fetch during rollout | Same as above; transient |
| Site loads, API dead | Tunnel issue not K8s | Check `sudo systemctl status cloudflared` |
| White page after deploy | Stale browser cache | Ctrl+Shift+R force refresh |
| RAG returns no results | ChromaDB collection empty or wrong CHROMA_URL | Run `python run_pipeline.py status` |

---

## Repository Layout

```
Portfolio-Prod/
├── api/                   FastAPI app (main.py, routes/, sheyla_security/)
├── backend/               Shared engines (rag_engine, llm_interface, settings)
├── ui/                    React + Vite frontend
├── infrastructure/
│   ├── charts/portfolio/  Helm chart (production, ArgoCD managed)
│   ├── method1-simple-kubectl/
│   ├── method2-terraform-localstack/
│   └── method3-helm-argocd/
├── rag-pipeline/          RAG ingestion pipeline
├── data/chroma/           Local ChromaDB (sync to server PVC)
├── CBBP/                  Security assessment artifacts (COMPLY/BUILD/BREAK/PROVE)
└── .github/workflows/     CI/CD (main.yml — 9 parallel security scanners)
```

---

Built by [Jimmie Coleman](https://linksmlm.com) — DevSecOps + AI Security Engineering
