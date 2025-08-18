# Portfolio Architecture Documentation

## Executive Summary

**Interview-ready AI portfolio platform** featuring local-first architecture, RAG-powered chat, and clean single-page design. Optimized for Azure B2s VMs (4GB RAM) with comprehensive fallback mechanisms.

### Key Features
- 🤖 **Sheyla AI Avatar**: Professional Indian lady voice with intro playback
- 💬 **RAG-Powered Chat**: ChromaDB + HuggingFace embeddings for contextual Q&A
- 📱 **Single-Page Design**: Clean layout - avatar left, projects right
- ☸️ **Kubernetes Ready**: Local development + production deployment
- 🔄 **LLM Flexibility**: Local Ollama + OpenAI GPT-4o mini fallback
- 🧪 **Comprehensive Testing**: E2E, golden answers, API validation

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Portfolio Platform                      │
├─────────────────────┬─────────────────────┬─────────────────┤
│     Frontend        │        API          │     Storage     │
│   (Single Page)     │   (FastAPI)         │   (Persistent)  │
├─────────────────────┼─────────────────────┼─────────────────┤
│ • Landing.jsx       │ • app/main.py       │ • ChromaDB      │
│ • AvatarPanel       │ • routes/chat.py    │ • Knowledge MD  │
│ • ChatPanel         │ • engines/rag.py    │ • Audio Assets  │
│ • Projects          │ • services/speech   │ • User Uploads  │
└─────────────────────┴─────────────────────┴─────────────────┘
```

### Memory Optimization (4GB RAM)
- **API**: 2GB limit, single worker
- **UI**: 512MB limit, static build
- **ChromaDB**: 1GB allocation
- **LLM**: Qwen2.5-1.5B (1.2GB model)

---

## 📁 Directory Structure

### Root Level
```
Portfolio/
├── README.md                  # Primary documentation
├── DEVELOPMENT.md            # Developer workflow
├── ARCHITECTURE.md           # This file
├── package.json              # Root package management
├── docker-compose.yml        # Local development
├── Makefile                  # K8s deployment automation
├── .env                      # Environment configuration
└── deploy-local-k8s.sh       # One-command deploy
```

### API Structure (Clean - `/api/app/`)
```
api/app/
├── main.py                   # FastAPI entry point
├── settings.py               # Centralized configuration
├── routes/                   # API endpoints
│   ├── chat.py              # RAG-powered Q&A
│   ├── health.py            # System health checks
│   ├── avatar.py            # Avatar creation/playback
│   ├── actions.py           # Avatar actions with fallbacks
│   ├── uploads.py           # File upload handling
│   └── debug.py             # Debug endpoints
├── engines/                  # Core processing engines
│   ├── rag_engine.py        # ChromaDB integration
│   ├── llm_engine.py        # LLM client (Ollama/OpenAI)
│   ├── avatar_engine.py     # Avatar processing
│   └── speech_engine.py     # Text-to-speech
├── services/                 # External service integrations
│   ├── elevenlabs.py        # TTS service
│   └── did.py               # Video avatar service
├── schemas/                  # Pydantic data models
│   ├── chat.py              # Chat request/response
│   ├── avatar.py            # Avatar request/response
│   └── common.py            # Shared schemas
├── mcp/                      # Model Control Protocol
│   ├── adapter.py           # MCP API adapter
│   ├── client.py            # MCP client
│   └── server.py            # MCP server
└── utils/                    # Utility functions
    └── preprocess.py         # Data preprocessing
```

### UI Structure (Single Entry Point - `/ui/src/`)
```
ui/src/
├── App.jsx                   # Application root
├── main.jsx                  # React DOM entry
├── pages/
│   └── Landing.jsx          # Main layout (only page)
├── components/               # Core components only
│   ├── AvatarPanel.tsx      # Avatar creation + audio
│   ├── ChatBox.jsx          # Chat input/output
│   ├── ChatPanel.tsx        # Model info + chat wrapper
│   └── Projects.tsx         # Project showcase
├── data/knowledge/jimmie/    # Content management
│   ├── projects.json        # Project information
│   └── qa.json              # Quick chat prompts
├── lib/
│   ├── api.ts               # Centralized API client
│   └── utils.ts             # Utility functions
└── _legacy/                 # Archived components
    └── [6 archived components]
```

### Data & Knowledge (`/data/`)
```
data/
├── knowledge/jimmie/         # RAG knowledge base
│   ├── 01-bio.md            # Personal background
│   ├── 02-devops.md         # DevOps experience
│   ├── 03-aiml.md           # AI/ML experience
│   ├── 04-projects.md       # Project details
│   ├── 05-faq.md            # Common Q&A
│   ├── 06-jade.md           # Jade project specifics
│   ├── 07-current-context.md # Current work focus
│   └── 08-sheyla-avatar-context.md # Avatar persona
├── personas/                 # Character definitions
│   ├── jimmie.yaml          # Main portfolio persona
│   ├── james.yaml           # Alternative persona
│   └── sheyla.yaml          # Default avatar
├── rag/jimmie/              # Additional RAG content
└── talktrack/               # Interview conversation guides
```

### Kubernetes Deployment (`/k8s/`)
```
k8s/
├── base/                    # Base manifests
│   ├── deployment-api.yaml  # API deployment
│   ├── deployment-ui.yaml   # UI deployment
│   ├── service-*.yaml       # Services
│   ├── ingress.yaml         # Ingress routing
│   ├── configmap.yaml       # Configuration
│   └── pvc-chroma.yaml      # Persistent storage
├── portfolio/               # Additional services
│   ├── chromadb-deployment.yaml
│   └── ollama-deployment.yaml
└── overlays/local/          # Local development
```

---

## 🔧 Technology Stack

### Backend (API)
- **Framework**: FastAPI 0.104.1
- **Server**: Uvicorn (single worker for memory)
- **AI/ML**: HuggingFace transformers, sentence-transformers
- **Vector DB**: ChromaDB with persistent storage
- **LLM**: Ollama (local) + OpenAI (fallback)
- **Avatar**: D-ID + ElevenLabs with fallbacks

### Frontend (UI)
- **Framework**: React 18 with TypeScript
- **Bundler**: Vite (optimized build)
- **Styling**: TailwindCSS 4.1.12
- **Icons**: Lucide React
- **API Client**: Centralized fetch wrapper

### Infrastructure
- **Containerization**: Docker multi-stage builds
- **Orchestration**: Kubernetes (KIND/Minikube/Production)
- **Storage**: Persistent volumes for ChromaDB
- **Networking**: Ingress with local domain support
- **Monitoring**: Health checks + debug endpoints

### Development Tools
- **Testing**: Playwright E2E + Golden answer validation
- **Quality**: Husky git hooks + Prettier formatting
- **CI/CD**: GitHub Actions for automated testing
- **Documentation**: Comprehensive markdown docs

---

## 🎯 Key Design Decisions

### 1. **Local-First Architecture**
- **Rationale**: Minimize external dependencies, reduce costs
- **Implementation**: Ollama for LLM, ChromaDB for vector storage
- **Fallbacks**: OpenAI GPT-4o mini for reliability

### 2. **Memory Optimization**
- **Constraint**: Azure B2s VM (4GB RAM)
- **Solution**: Qwen2.5-1.5B model, single API worker, optimized builds
- **Monitoring**: Resource limits in K8s manifests

### 3. **Single Entry Point UI**
- **Problem**: Component overlap and complexity
- **Solution**: One page, three components, archived alternatives
- **Benefit**: Clear user flow, easier maintenance

### 4. **Dual API Structure Management**
- **Legacy**: Root-level files (`routes_*.py`, `engines/`, etc.)
- **Modern**: Clean `app/` structure with proper imports
- **Migration**: Legacy archived to `_legacy/` directories

### 5. **RAG-First Chat Design**
- **Knowledge Base**: Curated markdown files for accuracy
- **Embeddings**: sentence-transformers for semantic search
- **Validation**: Golden answer testing prevents drift

---

## 🔄 Data Flow

### Chat Flow
```
User Input → ChatBox → API /chat → RAG Engine → LLM → Response
                                     ↓
                              ChromaDB Query
                                     ↓
                            Knowledge Base Search
```

### Avatar Flow
```
User Upload → AvatarPanel → API /avatar → Speech Engine → Audio
                                            ↓
                                     ElevenLabs TTS
                                            ↓
                                    Fallback: Default Audio
```

### Content Management Flow
```
projects.json → Projects Component → UI Display
qa.json → ChatBox → Quick Prompts
knowledge/*.md → RAG Ingestion → ChromaDB
```

---

## 🚀 Deployment Options

### Local Development
```bash
# One-command setup
./deploy-local-k8s.sh

# Alternative: Make targets
make deploy-kind     # KIND cluster
make deploy-minikube # Minikube cluster
```

### Production Deployment
```bash
# Build and deploy clean API
./scripts/deploy-clean-api.sh

# Verify deployment
./scripts/verify-clean-api.sh

# Health check
curl https://your-domain/health
```

### Resource Requirements
- **Minimum**: 4GB RAM, 2 CPU cores
- **Recommended**: 8GB RAM, 4 CPU cores
- **Storage**: 10GB for ChromaDB + models

---

## 📊 Performance Characteristics

### API Response Times
- **Health Check**: <50ms
- **Chat (RAG)**: 2-5 seconds (local LLM)
- **Chat (OpenAI)**: 500ms-2s (GPT-4o mini)
- **Avatar Audio**: 3-8 seconds (ElevenLabs)

### Memory Usage
- **API Process**: 1.5-2GB
- **ChromaDB**: 500MB-1GB
- **UI Build**: 151KB compressed
- **Total System**: 3-4GB peak

### Scalability Limits
- **Concurrent Users**: 10-20 (single worker)
- **Knowledge Base**: 1000 documents
- **Audio Generation**: 5 concurrent requests

---

## 🔒 Security Considerations

### Implemented Protections
- **CORS**: Configured origins in settings
- **Input Validation**: Pydantic schemas
- **File Uploads**: Type and size restrictions
- **API Keys**: Environment variable management

### Areas for Hardening
- **Rate Limiting**: Not implemented
- **Authentication**: Currently open access
- **Network Policies**: Basic K8s policies
- **Secret Rotation**: Manual process

---

## 🧪 Testing Strategy

### Test Types
1. **Unit Tests**: Individual component validation
2. **E2E Tests**: Full user journey via Playwright
3. **Golden Answer Tests**: RAG response quality
4. **API Tests**: Endpoint functionality
5. **Health Tests**: System readiness

### Test Automation
- **Pre-commit**: Code formatting and basic validation
- **Pre-push**: Full test suite execution
- **CI/CD**: Automated testing on GitHub Actions

---

## 📈 Monitoring & Observability

### Health Endpoints
- `/health`: System status
- `/api/debug/state`: Detailed diagnostics
- `/health/llm`: LLM provider status
- `/health/rag`: RAG system status

### Logging
- **Structured**: JSON format with correlation IDs
- **Levels**: DEBUG, INFO, WARN, ERROR
- **Retention**: 7 days local, configurable production

### Metrics
- **Response Times**: Per endpoint tracking
- **Error Rates**: 4xx/5xx monitoring
- **Resource Usage**: Memory/CPU utilization
- **User Interactions**: Chat/avatar usage

---

## 🔮 Future Roadmap

### Phase 1 - Stability (Current)
- [x] Clean API structure
- [x] Single UI entry point
- [x] Local LLM optimization
- [x] Comprehensive testing

### Phase 2 - Enhancement
- [ ] Authentication system
- [ ] Rate limiting
- [ ] Advanced monitoring
- [ ] Multi-user support

### Phase 3 - Scale
- [ ] Multi-worker API
- [ ] Distributed ChromaDB
- [ ] CDN integration
- [ ] Advanced analytics

---

## 📚 Related Documentation

- [DEVELOPMENT.md](./DEVELOPMENT.md) - Developer workflow and setup
- [README.md](./README.md) - Quick start guide and overview
- [docs/RUNBOOK.md](./docs/RUNBOOK.md) - Operations playbook
- [docs/SECURITY-CHECKLIST.md](./docs/SECURITY-CHECKLIST.md) - Security validation
- [docs/API-CLEANUP.md](./docs/API-CLEANUP.md) - Architecture migration details

---

*This documentation reflects the current state of the Portfolio platform. For questions or updates, consult the development team.*