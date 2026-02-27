# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A production RAG-powered portfolio platform with an AI assistant (Sheyla/Gojo avatars). The system combines a FastAPI backend, React/Vite frontend, and ChromaDB vector database to deliver semantic search over a personal knowledge base with LLM-generated responses.

Live at: https://linksmlm.com

## Build & Run Commands

### Full Stack (Docker Compose)
```bash
docker-compose up --build -d    # Start all services (ChromaDB, API, UI)
docker-compose ps               # Check status
docker-compose logs -f api      # Tail API logs
```

### UI Development
```bash
cd ui && npm run dev             # Vite dev server on :5173 (proxies /api to :8000)
cd ui && npm run build           # Production build
cd ui && npm run lint            # ESLint
cd ui && npm run format          # Prettier
```

### Backend Development
```bash
cd api && pip install -r requirements.txt
cd api && uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Testing
```bash
cd ui && npx playwright test                    # All e2e tests
cd ui && npx playwright test tests/api.spec.ts  # Single test file
cd ui && npx playwright test --ui               # Interactive test runner
```

### RAG Pipeline
```bash
cd rag-pipeline && python run_pipeline.py       # Full pipeline: prep → ingest → status
```

### Kubernetes (Makefile)
```bash
make deploy-kind       # Build + deploy to kind cluster
make deploy-minikube   # Build + deploy to minikube
make test              # Test K8s deployment health
make security-scan     # Trivy image scan + SBOM generation
make helm-security     # Render Helm → kubeconform → Conftest policy check
```

### OPA Policy Tests
```bash
conftest test rendered-manifests.yaml --policy GP-copilot/conftest-policies/
conftest verify --policy GP-copilot/conftest-policies/  # Run policy unit tests
```

## Architecture

### Service Topology
```
UI (:3000/nginx, :5173/dev) → API (:8000/FastAPI) → ChromaDB (:8001)
                                    ↓                     ↑
                              LLM (Claude API)    Ollama (embeddings)
```

### Two Backend Directories

- **`api/`** — FastAPI app entry point (`main.py`), routes, Dockerfile, security middleware. This is the containerized service.
- **`backend/`** — Shared engines and configuration imported by `api/`. Contains `settings.py` (centralized config), `engines/` (rag_engine, llm_interface, speech_engine), and `personality/` (avatar persona loader).

The API imports from backend: `from backend.settings import settings`, `from backend.engines.rag_engine import RAGEngine`.

### Request Flow
User query → `api/routes/chat.py` → 5-layer security check (`api/sheyla_security/`) → RAG retrieval (ChromaDB top-5) → LLM prompt construction → Claude API → response validation → client

### LLM Provider Chain
Primary: Claude (AsyncAnthropic, streaming) → Fallback: Local HuggingFace (Qwen2.5-1.5B). Configured in `backend/engines/llm_interface.py`.

### RAG Pipeline Stages
```
rag-pipeline/00-new-rag-data/        → Raw documents (input)
rag-pipeline/02-prepared-rag-data/   → Chunked + sanitized (prepare_data.py)
rag-pipeline/03-ingest-rag-data/     → Embedded + stored in ChromaDB (ingest_data.py)
rag-pipeline/04-processed-rag-data/  → Archived originals + metadata
```
Embeddings: Ollama nomic-embed-text (768-dim). Knowledge source docs live in `data/knowledge/`.

### Infrastructure: 3 Deployment Methods
1. **method1-simple-kubectl/** — Raw YAML manifests (`kubectl apply -f .`)
2. **method2-terraform-localstack/** — Terraform + LocalStack AWS simulation
3. **method3-helm-argocd/** — Helm charts + ArgoCD GitOps (production)

### Security Layers
- **API middleware**: Rate limiting (30 req/min), CORS, security headers (CSP, HSTS), gzip
- **Prompt security**: 15+ injection pattern regexes in `api/sheyla_security/llm_security.py`
- **CI/CD**: 8 parallel security scanners (Semgrep, Bandit, Safety, detect-secrets, Checkov, Trivy, SonarCloud, npm audit)
- **K8s policies**: OPA/Conftest CI validation (13 policies) + Gatekeeper runtime admission
- **Pre-commit**: detect-secrets baseline audit, large file checks (5MB limit)

## Key Configuration

### Environment Variables (see `.env.example`)
- `LLM_PROVIDER=claude` / `CLAUDE_API_KEY` — Primary LLM
- `CHROMA_URL=http://chromadb:8000` — Vector DB (internal port 8000, exposed as 8001)
- `OLLAMA_URL=http://host.docker.internal:11434` — Local embedding server
- `OPENAI_API_KEY` — Optional fallback LLM

### Ports
| Service  | Container | Host (compose) | Host (dev) |
|----------|-----------|----------------|------------|
| API      | 8000      | 8000           | 8000       |
| UI       | 80 (nginx)| 3000           | 5173       |
| ChromaDB | 8000      | 8001           | 8001       |

## CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/main.yml`) runs on push to main:
1. Security scanning (8 tools in parallel)
2. Code quality (ESLint, Prettier, Flake8)
3. Docker image build → push to `ghcr.io/jimjrxieb/`
4. Image tag update in Helm values (auto-commit with `[skip ci]`)
5. K8s manifest validation (Helm lint + Conftest)

Image tags follow pattern: `main-<short-sha>`.

## Production Infrastructure (linksmlm.com)

### Server

- **Host**: `ssh jimmie@100.116.11.56` (Tailnet IP, `portfolioserver`)
- **OS**: Ubuntu, WiFi interface `wlp2s0`, LAN IP `192.168.1.110`
- **K8s**: k3s single-node cluster with Traefik ingress controller

### How Traffic Reaches the App

```text
Internet → Cloudflare Edge (DNS: linksmlm.com)
         → Cloudflare Tunnel (http2 protocol, NOT quic)
         → cloudflared on portfolioserver → http://192.168.1.110:80
         → Traefik ingress (Host: linksmlm.com)
         → K8s services (UI on /, API on /api)
```

### Cloudflare Tunnel Setup

- **Tunnel ID**: `17334a76-6f89-43ef-bbae-9dfb19aa5815`
- **Credentials**: `/home/jimmie/.cloudflared/credentials.json`
- **Local config**: `/home/jimmie/.cloudflared/config.yml` (overridden by remote-managed config from Zero Trust dashboard)
- **Systemd service**: `/etc/systemd/system/cloudflared.service`
- **Protocol**: Must use `--protocol http2` (QUIC is blocked/dropped by the network)
- **Dashboard config** (Zero Trust > Networks > Tunnels > Portfolio):
  - Hostname: `linksmlm.com` → `http://192.168.1.110:80`
  - HTTP Host Header: `linksmlm.com` (required — without this, Traefik returns 404)
- **DNS** (Cloudflare dashboard): CNAME `linksmlm.com` → tunnel (type "Tunnel", proxied)
- **Also routed**: `argocd.linksmlm.com` → ArgoCD service (noTLSVerify)

### K8s Namespace: portfolio

```text
portfolio-portfolio-app-api     → FastAPI on :8000 (ClusterIP)
portfolio-portfolio-app-ui      → Nginx on :80 (ClusterIP)
portfolio-portfolio-app-chroma  → ChromaDB on :8000 (ClusterIP)
```

- **Ingress**: Traefik, host `linksmlm.com`, TLS via cert-manager (letsencrypt-prod)
- **Middleware**: `strip-api` (Traefik CRD) for `/api` path routing
- **Helm chart**: `infrastructure/charts/portfolio/` managed by ArgoCD (source: `infrastructure/charts/portfolio` in GitHub repo)

### Other K8s Namespaces on the Cluster

`argocd`, `cert-manager`, `external-secrets`, `gatekeeper-system`, `jsa-infrasec`, `monitoring` (Prometheus/Grafana), `vault`

### Sysctl Tuning (required for cloudflared)

```ini
net.core.rmem_max=7500000
net.core.wmem_max=7500000
```

Persisted in `/etc/sysctl.conf`. Without this, QUIC connections fail with undersized UDP buffers.

### Path Routing (critical to understand)

Traefik `strip-api` middleware removes `/api` prefix before forwarding to FastAPI. This means:

- Browser calls `/api/chat` → Traefik strips to `/chat` → FastAPI handles `/chat`
- Browser calls `/api/health` → Traefik strips to `/health` → FastAPI handles `/health`
- `VITE_API_BASE_URL` is baked at Docker build time (Vite), NOT runtime. CI builds with empty default, so `API_BASE=""` in production.
- **All UI fetch calls must use `/api/` prefix** (e.g., `fetch('/api/chat')`), not bare paths like `/chat` which would hit the UI nginx instead of the API.

### ArgoCD GitOps Flow

1. Push to `main` → GitHub Actions builds images tagged `main-<sha>` → pushes to `ghcr.io/jimjrxieb/`
2. `update-image-tags` job updates `infrastructure/charts/portfolio/values.yaml` with new tag via `sed` + auto-commit `[skip ci]`
3. ArgoCD polls the repo (automated sync + self-heal + prune enabled) → detects values.yaml change → syncs
4. K8s rolling update pulls new images

**White page after deploy**: Usually means the new UI image built but `index.html` references JS/CSS assets with new hashes that haven't loaded yet. Force-refresh (Ctrl+Shift+R) clears it. If persistent, check `kubectl -n portfolio logs <ui-pod>` for nginx 404s on asset files.

### Common Troubleshooting

- **502 from linksmlm.com**: Check `sudo systemctl status cloudflared` — restart if QUIC errors in logs. Verify `httpHostHeader: linksmlm.com` is set in Zero Trust dashboard.
- **Tunnel not proxying**: Confirm protocol is http2 (`journalctl -u cloudflared | grep protocol`). QUIC does not work on this network.
- **Pods healthy but site down**: Tunnel issue, not K8s. Test locally: `curl -H 'Host: linksmlm.com' http://192.168.1.110:80`
- **Chat not working**: Verify fetch URLs use `/api/chat` prefix (not `/chat`). Test: `curl https://linksmlm.com/api/chat/health`
- **Restart tunnel**: `sudo systemctl restart cloudflared`
- **Check tunnel metrics**: `curl http://127.0.0.1:20241/metrics`

## Conventions

- **Commits**: Conventional Commits (`feat:`, `fix:`, `chore:`, etc.)
- **Python**: Black formatting, type hints
- **TypeScript/JSX**: ESLint strict mode (no-eval, eqeqeq), single quotes, 2-space indent, Prettier
- **UI path alias**: `@/*` maps to `./src/*` (tsconfig paths)
- **Unused routes**: Deprecated API routes live in `api/routes/_unused/` — not mounted
- **Container images**: Non-root (`appuser` UID 1000), multi-stage builds, distroless where possible
