# Production AI Portfolio Platform

> Full-stack RAG system demonstrating enterprise DevSecOps practices and production-grade AI/ML engineering

**Live Demo**: [https://linksmlm.com](https://linksmlm.com)

[![Production Ready](https://img.shields.io/badge/status-production-green)](https://linksmlm.com)
[![Security](https://img.shields.io/badge/security-hardened-blue)](./GP-copilot/GP-COPILOT-ASSESSMENT-REPORT.md)
[![Kubernetes](https://img.shields.io/badge/kubernetes-ready-326CE5)](./infrastructure/)

---

## Overview

**DevSecOps Implementation**: This project demonstrates production-ready DevSecOps workflows with comprehensive security automation throughout the development lifecycle. The CI/CD pipeline leverages GitHub Actions with parallel security scanning (detect-secrets for secrets detection, Semgrep for SAST analysis, Trivy for container vulnerability scanning, Bandit for Python security, and Safety for dependency vulnerabilities). Policy-as-Code is enforced through OPA/Conftest in CI (13 policies with 11 automated tests validating Kubernetes manifests) and Gatekeeper for runtime admission control. Infrastructure is deployed using three progressive methods—simple kubectl manifests, Terraform with LocalStack for AWS service simulation, and production-grade Helm charts with ArgoCD GitOps—showcasing the evolution from beginner to enterprise approaches. Security is hardened with Kubernetes Network Policies, RBAC, Pod Security Standards, non-root Docker containers with multi-stage builds, and pre-commit hooks preventing secret commits. Public access is secured through Cloudflare Tunnel, eliminating exposed ports while maintaining TLS encryption.

**AI/ML Architecture**: The system implements a production RAG (Retrieval-Augmented Generation) pipeline using ChromaDB as the vector database with 2,656+ embeddings generated from comprehensive technical documentation. Ollama (nomic-embed-text model) handles local embedding generation for 768-dimensional vectors, while Claude API (Anthropic's claude-3-haiku-20240307) serves as the production LLM for natural language responses. The FastAPI backend provides async endpoints with semantic search completing in <100ms, processing user queries through ChromaDB similarity search, context retrieval, and LLM response generation with source citations. The ingestion pipeline processes markdown documents through sanitization, intelligent chunking (1000 words with 200-word overlap), embedding generation, and storage in versioned ChromaDB collections supporting atomic swaps for zero-downtime updates. The React/Vite frontend delivers real-time chat with a professional AI assistant (Sheyla) trained on DevSecOps expertise, project portfolios, and technical knowledge, demonstrating practical applications of modern AI/ML technologies in production environments.

### Key Features

- **Semantic Search**: ChromaDB vector database with 2,656+ embeddings, <100ms query response time
- **Production LLM**: Claude API (Anthropic) with Haiku model for cost-optimized inference
- **Local Embeddings**: Ollama nomic-embed-text for 768-dimensional vector generation
- **Policy Enforcement**: OPA/Conftest CI validation + Gatekeeper runtime admission control
- **Security Automation**: 6-tool security pipeline (detect-secrets, Semgrep, Trivy, Bandit, Safety, npm audit)
- **GitOps Deployment**: Three deployment methods showing kubectl → Terraform → Helm+ArgoCD progression
- **Zero-Downtime Updates**: Versioned ChromaDB collections with atomic swaps
- **Secrets Management**: Automated sync from .env to Kubernetes secrets with pre-commit validation

---

## Architecture

### Technology Stack

#### Backend (Python 3.11)

- FastAPI + Uvicorn (async web framework)
- ChromaDB 0.5.18+ (vector database, persistent SQLite storage)
- Anthropic Claude API (claude-3-haiku-20240307 for production LLM)
- Ollama (nomic-embed-text for 768-dim local embeddings)
- Pydantic (request/response validation)

#### Frontend (TypeScript/React)

- React 18.2.0 + TypeScript
- Vite 6.4.1 (build tool, esbuild 0.27.0)
- Material-UI 7.3.2 + Tailwind CSS 4.1.12
- Nginx (production static file serving)

#### Infrastructure & Security

- Docker (multi-stage builds, non-root containers, distroless base images)
- Kubernetes (Docker Desktop, 3-pod architecture: UI, API, ChromaDB)
- GitHub Actions (parallel security scanning: detect-secrets, Semgrep, Trivy, Bandit, Safety)
- OPA/Conftest (CI policy validation, 13 policies with 11 automated tests)
- Gatekeeper (runtime admission control)
- Cloudflare Tunnel (TLS-encrypted public access)
- Pre-commit hooks (secrets detection, linting)

#### Deployment Methods (Progressive Complexity)

1. Method 1: Simple kubectl manifests (beginner-friendly)
2. Method 2: Terraform + LocalStack (AWS service simulation)
3. Method 3: Helm + ArgoCD (production GitOps)

### System Components

```
Portfolio/
├── api/                      # FastAPI backend
│   ├── routes/              # API endpoints (chat, RAG, health, uploads)
│   ├── engines/             # Core logic (LLM, RAG, conversation, avatar)
│   ├── jade_config/         # AI personality and configuration
│   └── Dockerfile           # Production container
├── ui/                       # React frontend
│   ├── src/components/      # UI components + 3D avatar
│   └── Dockerfile           # Production container
├── infrastructure/          # 3 deployment methods (beginner → advanced)
│   ├── method1-simple-kubectl/      # Quick kubectl deployment
│   ├── method2-terraform-localstack/ # Terraform + LocalStack
│   ├── method3-helm-argocd/         # Production GitOps
│   ├── shared-gk-policies/          # Gatekeeper runtime policies
│   └── shared-security/             # Network policies & RBAC
├── conftest-policies/       # CI/CD policy validation (OPA)
├── rag-pipeline/            # Data ingestion & ChromaDB management
├── data/
│   ├── knowledge/           # 20+ markdown source documents
│   └── chroma/              # Persistent vector database
└── docs/                    # Development documentation
```

---

## AI Assistant System

### Conversation Flow

```
User Question
    ↓
Semantic Search (ChromaDB)
    ↓
Context Retrieval (top 5 matches)
    ↓
LLM Prompt Construction (GPT-4o mini)
    ↓
Response Validation (anti-hallucination)
    ↓
Citation Formatting
    ↓
Avatar Animation + TTS
```

### Response Validation

The system includes sophisticated anti-hallucination detection:
- 8 different hallucination trap patterns
- Confidence scoring (0-1)
- Source document grounding validation
- Detects fabricated facts, fake companies, wrong identities

### Avatar System

**Gojo (Primary Avatar)**
- 3D animated male avatar (white hair, crystal blue eyes)
- Real-time Three.js/VRM rendering
- Lip-sync with ElevenLabs TTS
- Personality: Professional, technical, helpful

**Sheyla (Secondary)**
- Interview/interaction avatar
- Warm, professional Indian heritage
- Status: Conversation engine implemented

### Knowledge Base

**Data Sources** (`/data/knowledge/`)
- Biography and professional mission
- DevOps/DevSecOps expertise (Kubernetes, CI/CD, Infrastructure as Code)
- AI/ML expertise (RAG, LLMs, vector databases)
- Project descriptions (LinkOps AI-BOX, Afterlife, etc.)
- Testing partnerships (ZRS Management property reporting)
- FAQ and comprehensive portfolio documentation

**Ingestion Pipeline**
- Markdown → Sanitize → Chunk (1000 tokens) → Embed → ChromaDB
- Versioned collections with atomic swaps
- Zero-downtime updates

---

## API Endpoints

### Chat Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/chat` | Main conversation (RAG + LLM) |
| GET | `/api/chat/sessions/{id}` | Retrieve chat history |
| DELETE | `/api/chat/sessions/{id}` | Clear session |
| GET | `/api/chat/health` | Chat service status |
| GET | `/api/chat/prompts` | Conversation starters |

### RAG Management
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/rag/versions` | Create new index version |
| GET | `/api/rag/versions` | List all versions |
| POST | `/api/rag/ingest` | Ingest documents |
| POST | `/api/rag/swap` | Atomic collection swap |
| DELETE | `/api/rag/versions/{id}` | Delete old version |

### Health & Status
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Basic health check |
| GET | `/api/health/llm` | LLM provider test |
| GET | `/api/health/rag` | RAG availability |
| GET | `/api/debug/state` | Full configuration |

### Avatar/Media
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/actions/avatar/create` | Avatar creation |
| POST | `/api/actions/avatar/talk` | TTS generation |
| POST | `/api/upload/image` | Image upload |

---

## Configuration

### Environment Variables

**Required**
```bash
# LLM Configuration
LLM_PROVIDER=openai
LLM_API_KEY=sk-...
LLM_MODEL=gpt-4o-mini

# Vector Database
CHROMA_URL=http://chromadb:8000
RAG_NAMESPACE=portfolio

# Public URL
PUBLIC_BASE_URL=https://linksmlm.com
CORS_ORIGINS=http://localhost:5173,https://linksmlm.com
```

**Optional**
```bash
# Voice Services
ELEVENLABS_API_KEY=sk-...
DID_API_KEY=...

# Debug
DEBUG_MODE=true
```

See [`.env.example`](.env.example) for complete configuration template.

---

## Quick Start

### Local Development

**Prerequisites**
- Docker + Docker Compose
- Node.js 18+ (for UI development)
- Python 3.11+ (for API development)

**Start all services**
```bash
# Clone repository
git clone https://github.com/jimjrxieb/Portfolio.git
cd Portfolio

# Copy environment template
cp .env.example .env

# Edit .env with your API keys
nano .env

# Start services
docker-compose up --build -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

**Access services**
- Frontend: http://localhost:5173
- API: http://localhost:8000
- API Docs: http://localhost:8000/docs
- ChromaDB: http://localhost:8001

### Production Deployment

**3 Deployment Methods** (choose based on your experience level):

#### Method 1: Simple Kubernetes (⭐ Beginner - 5 minutes)
```bash
cd infrastructure/method1-simple-kubectl
kubectl apply -f .
```

#### Method 2: Terraform + LocalStack (⭐⭐ Intermediate - 15 minutes)

**What You'll Get:**
- Full AWS service simulation (Secrets Manager, Lambda, CloudWatch, S3, DynamoDB, SQS)
- Production-grade infrastructure patterns running locally
- Kubernetes application deployment (UI + API + ChromaDB)
- IAM roles and policies for Lambda functions
- Infrastructure as Code with Terraform modules

```bash
cd infrastructure/method2-terraform-localstack

# Start LocalStack (AWS service emulator)
docker run -d --name localstack -p 4566:4566 \
  -e SERVICES=s3,dynamodb,sqs,secretsmanager,lambda,logs,cloudwatch,events,iam \
  -v /var/run/docker.sock:/var/run/docker.sock \
  localstack/localstack:latest

# Set API keys as Terraform variables
export TF_VAR_claude_api_key="$CLAUDE_API_KEY"
export TF_VAR_openai_api_key="${OPENAI_API_KEY:-}"
export TF_VAR_elevenlabs_api_key="${ELEVENLABS_API_KEY:-}"
export TF_VAR_did_api_key="${DID_API_KEY:-}"

# Deploy infrastructure
terraform init
terraform apply

# Verify Lambda function
aws --endpoint-url=http://localhost:4566 lambda list-functions

# Check Secrets Manager
aws --endpoint-url=http://localhost:4566 secretsmanager list-secrets

# View CloudWatch logs
aws --endpoint-url=http://localhost:4566 logs tail /aws/lambda/portfolio-chat-handler
```

**Architecture Deployed:**
- **AWS Resources**: 5 secrets, 1 Lambda function, S3 bucket, DynamoDB table, SQS queue
- **Kubernetes**: portfolio namespace with UI/API/ChromaDB deployments
- **Networking**: Ingress controller for HTTP routing
- **Security**: IAM policies, Secrets Manager integration, non-root containers

#### Method 3: Helm + ArgoCD (⭐⭐⭐ Advanced - 30+ minutes)
```bash
# Build and push containers
docker build -t ghcr.io/jimjrxieb/portfolio-api:latest ./api
docker build -t ghcr.io/jimjrxieb/portfolio-ui:latest ./ui
docker push ghcr.io/jimjrxieb/portfolio-api:latest
docker push ghcr.io/jimjrxieb/portfolio-ui:latest

# Deploy with Helm
helm upgrade --install portfolio ./infrastructure/method3-helm-argocd/helm-chart/portfolio \
  --namespace portfolio \
  --create-namespace \
  --values ./infrastructure/method3-helm-argocd/helm-chart/portfolio/values.prod.yaml

# Or use ArgoCD (GitOps)
kubectl apply -f ./infrastructure/method3-helm-argocd/argocd/portfolio-application.yaml
```

**📚 Full Documentation**: See [infrastructure/README.md](./infrastructure/README.md) for detailed deployment guides, comparison table, and security best practices.

---

## Infrastructure & Deployment

### 3-Method Approach

This project offers **3 deployment methods** for different skill levels and use cases:

| Method | Difficulty | Time | Tools | Use Case | AWS Services |
|--------|-----------|------|-------|----------|--------------|
| **[Method 1](./infrastructure/method1-simple-kubectl/)** | ⭐ Beginner | 5 min | kubectl | Learning K8s basics | None |
| **[Method 2](./infrastructure/method2-terraform-localstack/)** | ⭐⭐ Intermediate | 15 min | Terraform + LocalStack | Testing AWS services locally | Lambda, Secrets Manager, CloudWatch, S3, DynamoDB, SQS |
| **[Method 3](./infrastructure/method3-helm-argocd/)** | ⭐⭐⭐ Advanced | 30+ min | Helm + ArgoCD | Production GitOps | Optional (cloud-agnostic) |

### Security & Policy Enforcement

**Two-Layer Defense (Industry Best Practice)**:

1. **CI/CD Policies** ([conftest-policies/](./conftest-policies/))
   - Validates manifests during CI/CD (shift-left security)
   - 150+ policy tests covering container security, image security, resource limits
   - Blocks deployments before they reach production

2. **Runtime Policies** ([shared-gk-policies/](./infrastructure/shared-gk-policies/))
   - Gatekeeper admission controller blocks non-compliant pods
   - ConstraintTemplates for security, governance, and compliance
   - Last line of defense at cluster level

**Additional Security** ([shared-security/](./infrastructure/shared-security/)):
- Network policies (default-deny, DNS allow)
- RBAC roles and bindings
- Pod Security Standards
- CIS Kubernetes Benchmark compliance

### Learning Path

**New to Kubernetes?** → Start with [Method 1](./infrastructure/method1-simple-kubectl/)
**Ready for Infrastructure as Code?** → Move to [Method 2](./infrastructure/method2-terraform-localstack/)
**Ready for Production?** → Graduate to [Method 3](./infrastructure/method3-helm-argocd/)

---

## Development

### Project Structure

**Backend Routes** (`api/routes/`)
- `chat.py` - Conversation endpoints
- `rag.py` - RAG management
- `health.py` - Health checks
- `uploads.py` - File uploads
- `validation.py` - Input validation

**Backend Engines** (`api/engines/`)
- `jade_engine.py` - Conversation logic (Gojo personality)
- `rag_engine.py` - RAG operations
- `llm_engine.py` - Multi-provider LLM client
- `response_generator.py` - Response validation
- `avatar_engine.py` - Avatar integration
- `speech_engine.py` - TTS integration

**Frontend Components** (`ui/src/components/`)
- `GojoAvatar3D.tsx` - 3D avatar rendering
- `Chat.tsx` - Chat interface
- `Projects.tsx` - Project showcase
- `About.tsx` - About section

### Running Tests

```bash
# Backend tests
cd api
pytest

# Frontend tests
cd ui
npm test

# Integration tests
docker-compose up -d
pytest integration/
```

### Updating Knowledge Base

```bash
# Add/edit documents in data/knowledge/

# Rebuild RAG index
cd rag-pipeline
python ingestion_engine.py

# Or use API
curl -X POST http://localhost:8000/api/rag/ingest \
  -H "Content-Type: application/json" \
  -d '{"documents_path": "/data/knowledge"}'
```

---

## Security

### Security Features Implemented

- No hardcoded secrets (environment variables)
- Input validation on all endpoints
- CORS properly configured
- Security headers (CSP, HSTS, X-Frame-Options)
- Rate limiting (30 req/min per IP)
- Non-root container execution
- Path traversal protection
- SSRF prevention
- Response validation

### Security Assessment

See [GP-Copilot Security Assessment](./GP-copilot/GP-COPILOT-ASSESSMENT-REPORT.md) for detailed security analysis.

**Status**: Production-ready with zero security findings

---

## Performance

### Metrics

- **Response Time**: <2s average (including RAG + LLM)
- **RAG Search**: <100ms for semantic search
- **Concurrent Users**: Tested up to 50 simultaneous chats
- **Knowledge Base**: 20+ documents, 384-dim embeddings
- **Rate Limiting**: 30 requests/min per IP

### Optimization

- Gzip compression for API responses
- Lazy-loaded 3D assets
- Chunked knowledge base (1000 tokens/chunk)
- Top-5 retrieval for context (configurable)
- Local LLM fallback for cost optimization

---

## External Services

### Active Integrations
- **OpenAI**: GPT-4o mini LLM (https://api.openai.com)
- **ChromaDB**: Vector database (self-hosted)
- **ElevenLabs**: Text-to-speech (optional)
- **HuggingFace**: Embedding models + local LLM
- **Cloudflare**: Tunnel for public exposure

### Configured but Inactive
- **D-ID**: Avatar video generation (in config, not actively used)

---

## Monitoring & Troubleshooting

### Health Checks

```bash
# Basic health
curl http://localhost:8000/health

# LLM provider
curl http://localhost:8000/api/health/llm

# RAG system
curl http://localhost:8000/api/health/rag

# Full debug state
curl http://localhost:8000/api/debug/state
```

### Common Issues

**Chat not responding**
```bash
# Check API logs
docker-compose logs api

# Verify ChromaDB
curl http://localhost:8001/api/v1/heartbeat

# Check LLM API key
docker-compose exec api env | grep LLM_API_KEY
```

**UI not loading**
```bash
# Check UI logs
docker-compose logs ui

# Rebuild
cd ui && npm run build

# Check CORS
curl -H "Origin: http://localhost:5173" http://localhost:8000/health -v
```

**RAG returning no results**
```bash
# Check ChromaDB collections
curl http://localhost:8001/api/v1/collections

# Rebuild index
cd rag-pipeline && python ingestion_engine.py
```

---

## Contributing

### Development Setup

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`pytest` for backend, `npm test` for frontend)
5. Commit with conventional commits (`git commit -m 'feat: add amazing feature'`)
6. Push to branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Standards

- **Python**: Black formatting, type hints, docstrings
- **TypeScript**: ESLint + Prettier, strict mode
- **Commits**: Conventional Commits specification
- **Tests**: Required for new features

---

## License

This project is proprietary. All rights reserved.

---

## Contact & Support

**Project Owner**: Jimmie Coleman
**Live Demo**: [https://linksmlm.com](https://linksmlm.com)
**Repository**: [https://github.com/jimjrxieb/Portfolio](https://github.com/jimjrxieb/Portfolio)

For questions or support, please open an issue on GitHub.

---

## Acknowledgments

- **OpenAI**: GPT-4o mini LLM
- **ChromaDB**: Vector database
- **ElevenLabs**: Professional TTS
- **Three.js**: 3D rendering
- **FastAPI**: Modern Python web framework
- **React**: UI framework

---

Built with care by [Jimmie Coleman](https://linksmlm.com) - DevSecOps Engineer & AI/ML Specialist
