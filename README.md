# Portfolio - AI-Powered Professional Showcase

> Full-stack portfolio platform with RAG-powered AI assistant, 3D avatar, and comprehensive knowledge base

**Live Demo**: [https://linksmlm.com](https://linksmlm.com)

[![Production Ready](https://img.shields.io/badge/status-production-green)](https://linksmlm.com)
[![Security](https://img.shields.io/badge/security-hardened-blue)](./GP-copilot/GP-COPILOT-ASSESSMENT-REPORT.md)
[![Kubernetes](https://img.shields.io/badge/kubernetes-ready-326CE5)](./charts/portfolio/)

---

## Overview

An intelligent portfolio platform featuring **Gojo**, an AI assistant powered by Retrieval-Augmented Generation (RAG), that answers questions about professional experience, projects, and technical expertise. The system combines modern AI/ML technologies with production-grade DevSecOps practices.

### Key Features

- **RAG-Powered Chat**: Semantic search over 20+ knowledge base documents with GPT-4o mini
- **3D Avatar**: Interactive Three.js/VRM avatar with lip-sync and animation
- **Response Validation**: Anti-hallucination detection with confidence scoring
- **Multi-Provider LLM**: OpenAI primary, local Qwen fallback for cost optimization
- **Voice Synthesis**: ElevenLabs TTS integration for natural speech
- **Version Management**: Atomic RAG collection swaps for zero-downtime updates
- **Production Ready**: Kubernetes deployment with Helm, rate limiting, security headers

---

## Architecture

### Technology Stack

**Backend (Python)**
- FastAPI 0.104.1 + Uvicorn (async web framework)
- ChromaDB 1.1.0+ (vector database with persistent storage)
- sentence-transformers/all-MiniLM-L6-v2 (384-dim embeddings)
- PyTorch 2.6.0 (GPU/CPU support)
- OpenAI GPT-4o mini (primary LLM)
- Qwen/Qwen2.5-1.5B-Instruct (local fallback LLM)

**Frontend (React)**
- React 18.2.0 + TypeScript/TSX
- Vite 5.1.0 (build tool)
- Three.js 0.164.1 + VRM (3D avatar rendering)
- Material-UI 7.3.2 + Tailwind CSS 4.1.12

**Infrastructure**
- Docker (non-root, multi-stage builds)
- Kubernetes + Helm charts
- Cloudflare Tunnel (public exposure)
- GitHub Actions (CI/CD)

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
├── rag-pipeline/            # Data ingestion & ChromaDB management
├── data/
│   ├── knowledge/           # 20+ markdown source documents
│   └── chroma/              # Persistent vector database
├── charts/portfolio/        # Kubernetes Helm deployment
├── docs/                    # Development documentation
└── scripts/                 # Deployment automation
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
- Client case studies (ZRS Management)
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

**Kubernetes with Helm**
```bash
# Build and push containers
docker build -t ghcr.io/jimjrxieb/portfolio-api:latest ./api
docker build -t ghcr.io/jimjrxieb/portfolio-ui:latest ./ui
docker push ghcr.io/jimjrxieb/portfolio-api:latest
docker push ghcr.io/jimjrxieb/portfolio-ui:latest

# Deploy with Helm
helm upgrade --install portfolio ./charts/portfolio \
  --namespace portfolio \
  --create-namespace \
  --values ./charts/portfolio/values.prod.yaml

# Check deployment
kubectl get pods -n portfolio
kubectl logs -f deployment/portfolio-api -n portfolio
```

See [Kubernetes Deployment Guide](./docs/deployment/KUBERNETES_READY.md) for detailed instructions.

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