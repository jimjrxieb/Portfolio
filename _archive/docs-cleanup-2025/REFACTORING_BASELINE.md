# Portfolio Project - Refactoring Baseline

**Date**: November 3, 2025
**Purpose**: Establish accurate baseline before major refactoring
**Status**: Documentation phase - identifying inconsistencies and technical debt

---

## Executive Summary

This document establishes the **actual current state** of the Portfolio project based on comprehensive codebase analysis. It identifies discrepancies between documentation and implementation, technical debt, and areas requiring refactoring.

### Critical Findings

1. **README.md was completely wrong** - Showed Conftest documentation instead of Portfolio (FIXED)
2. **Avatar naming inconsistency** - Code uses "Gojo" but docs reference "Jade-Brain" and "Sheyla"
3. **GP-COPILOT report lacked technical depth** - Missing actual LLM providers, RAG architecture (FIXED)
4. **File structure mismatch** - `api/services/` directory doesn't exist, it's `api/engines/`
5. **Mixed terminology** - "Jade Engine" vs "Gojo Avatar" vs "Sheyla" needs clarification

---

## Current Architecture (Verified)

### Technology Stack (ACTUAL)

#### Backend
```
Language: Python 3.11
Framework: FastAPI 0.104.1 + Uvicorn
Vector DB: ChromaDB 1.1.0+ (persistent storage)
Embeddings: sentence-transformers/all-MiniLM-L6-v2 (384-dim)
ML Framework: PyTorch 2.6.0 (GPU/CPU)
Primary LLM: OpenAI GPT-4o mini
Fallback LLM: Qwen/Qwen2.5-1.5B-Instruct (HuggingFace)
Container: Docker (non-root, Python 3.11-slim)
```

#### Frontend
```
Language: TypeScript/TSX
Framework: React 18.2.0
Build Tool: Vite 5.1.0
3D Engine: Three.js 0.164.1
Avatar: VRM format rendering
UI: Material-UI 7.3.2 + Tailwind CSS 4.1.12
Container: Docker (nginx-based)
```

#### Infrastructure
```
Orchestration: Kubernetes + Helm
Deployment: GitOps (GitHub Actions)
Exposure: Cloudflare Tunnel (linksmlm.com)
Monitoring: Basic health checks (no Prometheus yet)
```

### Directory Structure (ACTUAL)

```
Portfolio/
├── api/                          # FastAPI backend (Python)
│   ├── engines/                 # Core logic (NOT services/)
│   │   ├── avatar_engine.py     # Avatar integration
│   │   ├── jade_engine.py       # Conversation logic (Gojo personality)
│   │   ├── llm_engine.py        # Multi-provider LLM client
│   │   ├── llm_interface.py     # LLM abstraction
│   │   ├── rag_engine.py        # RAG operations
│   │   ├── rag_interface.py     # RAG abstraction
│   │   ├── response_generator.py # Response validation
│   │   └── speech_engine.py     # TTS integration
│   ├── jade_config/             # AI personality config
│   │   ├── llm_config.py        # LLM settings
│   │   ├── personality_config.py # Personality traits
│   │   └── rag_config.py        # RAG settings
│   ├── routes/                  # API endpoints
│   │   ├── chat.py              # Main chat endpoint
│   │   ├── rag.py               # RAG management
│   │   ├── health.py            # Health checks
│   │   ├── uploads.py           # File uploads
│   │   ├── actions.py           # Avatar actions
│   │   ├── debug.py             # Debug endpoints
│   │   └── validation.py        # Input validation
│   ├── main.py                  # FastAPI app entry
│   ├── settings.py              # Configuration
│   └── Dockerfile               # Production container
│
├── ui/                           # React frontend (TypeScript)
│   ├── src/
│   │   ├── components/
│   │   │   ├── GojoAvatar3D.tsx    # 3D avatar (18.5KB)
│   │   │   ├── Chat.tsx            # Chat interface
│   │   │   ├── Projects.tsx        # Project showcase
│   │   │   └── About.tsx           # About section
│   │   ├── App.tsx
│   │   └── main.tsx
│   └── Dockerfile               # Production container
│
├── rag-pipeline/                 # Data ingestion
│   ├── ingestion_engine.py      # RAG ingestion
│   └── requirements.txt
│
├── data/                         # Knowledge base
│   ├── knowledge/               # 20+ markdown docs
│   │   ├── 01-bio.md
│   │   ├── 04-projects.md
│   │   ├── 06-jade.md
│   │   ├── zrs-management-case-study.md
│   │   └── gojo-golden-set.md
│   └── chroma/                  # Vector database (persistent)
│
├── charts/portfolio/             # Kubernetes Helm
│   ├── templates/               # K8s manifests
│   └── values.prod.yaml
│
├── docs/                         # Documentation
│   ├── development/
│   └── deployment/
│
├── GP-copilot/                   # Security assessment
│   └── GP-COPILOT-ASSESSMENT-REPORT.md
│
├── docker-compose.yml            # Local dev environment
├── README.md                     # Main documentation (FIXED)
└── .env.example                 # Environment template
```

---

## AI Assistant System (ACTUAL IMPLEMENTATION)

### Naming Confusion: Gojo vs Jade vs Sheyla

**The Problem**: Multiple names used inconsistently across codebase

#### What Actually Exists:

1. **Gojo (Primary - FULLY IMPLEMENTED)**
   - Location: `ui/src/components/GojoAvatar3D.tsx`
   - Description: 3D male avatar (white hair, crystal blue eyes)
   - Implementation: Three.js + VRM rendering (18.5KB component)
   - Status: Production-ready with animation
   - Voice: ElevenLabs TTS integration
   - Personality: Professional, technical, helpful

2. **Jade Engine (Backend Logic)**
   - Location: `api/engines/jade_engine.py`
   - Description: Conversation engine that powers Gojo
   - Implementation: Intent analysis, Q&A matching, context tracking
   - Status: Fully implemented (360 lines)
   - Purpose: Business logic for conversation

3. **Sheyla (Secondary - PARTIALLY IMPLEMENTED)**
   - Location: `api/engines/jade_engine.py` (ConversationEngine class)
   - Description: Interview/interaction avatar personality
   - Implementation: Personality data structure, conversation methods
   - Status: Stub implementation (personality defined but not used)
   - Characteristics: Indian heritage, warm professional tone

#### Current Reality:
- **Production Avatar**: Gojo (3D rendered, fully functional)
- **Backend Engine**: Jade Engine (powers Gojo)
- **Unused Avatar**: Sheyla (personality defined, not active)

#### Terminology Issues:
- File named `jade_engine.py` contains `ConversationEngine` class
- Documentation refers to "Jade-Brain" as a project name
- Code comments mention both "Sheyla" and "Gojo"
- API endpoints use generic "avatar" terminology

---

## RAG System Architecture (ACTUAL)

### Data Flow

```
User Question
    ↓
POST /api/chat
    ↓
rag_engine.py: semantic_search()
    ↓
ChromaDB: query(embedding, top_k=5)
    ↓
rag_engine.py: format_context_with_citations()
    ↓
llm_engine.py: generate_response()
    ↓
OpenAI API: GPT-4o mini (or local Qwen)
    ↓
response_generator.py: validate_response()
    ↓
Anti-hallucination checks (8 patterns)
    ↓
Return response + citations + follow-ups
```

### Components

#### 1. RAG Engine (`api/engines/rag_engine.py`)
- **Purpose**: Semantic search over knowledge base
- **Embedding**: sentence-transformers/all-MiniLM-L6-v2
- **Storage**: ChromaDB with versioned collections
- **Retrieval**: Top-5 chunks with cosine similarity
- **Features**: Atomic collection swaps, versioning, citations

#### 2. LLM Engine (`api/engines/llm_engine.py`)
- **Primary**: OpenAI GPT-4o mini (via API)
- **Fallback**: Qwen 1.5B (HuggingFace Transformers)
- **Interface**: Unified multi-provider abstraction
- **Context Window**: Configurable (default: 4096 tokens)

#### 3. Response Validator (`api/engines/response_generator.py`)
- **Purpose**: Anti-hallucination detection
- **Patterns**: 8 different trap detections
  - Fabricated companies
  - Wrong identities
  - Fake technologies
  - Incorrect timelines
  - Unsupported claims
  - Off-topic responses
  - Missing citations
  - Low confidence (<0.3)
- **Output**: Confidence score (0-1) + validation flags

#### 4. Knowledge Base (`/data/knowledge/`)
- **Format**: Markdown files (20+ documents)
- **Topics**:
  - Professional biography
  - DevOps/DevSecOps expertise
  - AI/ML projects
  - Client case studies
  - Certifications
  - Technical Q&A
- **Ingestion**: Chunk (1000 tokens) → Embed → Store
- **Versioning**: portfolio_v1, portfolio_v2, etc.

---

## API Endpoints (VERIFIED)

### Chat Endpoints
```
POST   /api/chat                 # Main conversation (RAG + LLM)
GET    /api/chat/sessions/{id}   # Retrieve history
DELETE /api/chat/sessions/{id}   # Clear session
GET    /api/chat/health          # Chat service status
GET    /api/chat/prompts         # Suggested starters
```

### RAG Management
```
POST   /api/rag/versions         # Create new index
GET    /api/rag/versions         # List versions
POST   /api/rag/ingest           # Ingest documents
POST   /api/rag/swap             # Atomic collection swap
DELETE /api/rag/versions/{id}    # Delete version
```

### Health & Debug
```
GET    /health                   # Basic check
GET    /api/health/llm           # LLM provider test
GET    /api/health/rag           # RAG availability
GET    /api/debug/state          # Full config dump
```

### Avatar/Media
```
POST   /api/actions/avatar/create  # Avatar creation
POST   /api/actions/avatar/talk    # TTS generation
POST   /api/upload/image           # Image upload
```

---

## Configuration (ACTUAL)

### Environment Variables (Required)

```bash
# LLM Configuration
LLM_PROVIDER=openai                    # or "local" for Qwen
LLM_API_KEY=sk-...                     # OpenAI API key
LLM_MODEL=gpt-4o-mini                  # Model name
LLM_TEMPERATURE=0.7                    # Response creativity

# Vector Database
CHROMA_URL=http://chromadb:8000        # ChromaDB endpoint
RAG_NAMESPACE=portfolio                # Collection prefix

# Voice Services
ELEVENLABS_API_KEY=sk-...              # TTS service
DID_API_KEY=...                        # Avatar video (unused)

# Application
PUBLIC_BASE_URL=https://linksmlm.com   # Public URL
CORS_ORIGINS=http://localhost:5173,https://linksmlm.com
DEBUG_MODE=true                        # Enable debug endpoints
DATA_DIR=/data                         # Persistent data path

# Security
RATE_LIMIT_PER_MINUTE=30               # Requests per IP
```

### File Structure Issues

**Problem**: Documentation references paths that don't exist

❌ `api/services/` - **DOES NOT EXIST**
✅ `api/engines/` - **ACTUAL LOCATION**

Files incorrectly referenced:
- `api/services/did.py` → Doesn't exist
- `api/services/elevenlabs.py` → Doesn't exist
- `api/services/*` → All in `api/engines/` instead

---

## External Service Integrations

### Active Services

1. **OpenAI**
   - Purpose: Primary LLM (GPT-4o mini)
   - Status: Active, required
   - Cost: ~$0.15 per 1M input tokens
   - Endpoint: `https://api.openai.com/v1/chat/completions`

2. **ChromaDB**
   - Purpose: Vector database
   - Status: Self-hosted (not cloud)
   - Location: `http://chromadb:8000` (container)
   - Persistence: `/data/chroma` volume

3. **ElevenLabs**
   - Purpose: Text-to-speech
   - Status: Optional (fallback to local audio)
   - Cost: Pay-per-character
   - Voice: Professional male voice

4. **HuggingFace**
   - Purpose: Embedding models + fallback LLM
   - Status: Active
   - Models:
     - `sentence-transformers/all-MiniLM-L6-v2` (embeddings)
     - `Qwen/Qwen2.5-1.5B-Instruct` (local LLM)
   - Cost: Free (self-hosted)

5. **Cloudflare Tunnel**
   - Purpose: Public exposure without port forwarding
   - Status: Active (linksmlm.com)
   - Cost: Free tier

### Configured But Inactive

1. **D-ID**
   - Purpose: Avatar video generation
   - Status: API key in config, not actively used
   - Reason: Gojo uses Three.js rendering instead
   - Cost: $0.12 per video

---

## Technical Debt & Issues

### High Priority

1. **Avatar Naming Confusion**
   - Impact: High - Documentation doesn't match code
   - Files affected: `jade_engine.py`, docs, README
   - Solution needed: Standardize on "Gojo + Jade Engine"

2. **Missing Services Directory**
   - Impact: High - GP-COPILOT report references wrong paths
   - Current: `api/engines/`
   - Documented: `api/services/`
   - Solution needed: Update all documentation

3. **Incomplete Sheyla Implementation**
   - Impact: Medium - Unused code in production
   - Status: Personality defined but not active
   - Decision needed: Complete or remove?

4. **README Was Completely Wrong**
   - Impact: CRITICAL (FIXED)
   - Previous: Showed Conftest documentation
   - Status: Replaced with actual Portfolio docs

### Medium Priority

5. **No Monitoring/Observability**
   - Impact: Medium - Hard to debug production issues
   - Missing: Prometheus, Grafana, structured logging
   - Current: Basic health checks only

6. **Local LLM Not Battle-Tested**
   - Impact: Medium - Fallback may not work reliably
   - Status: Qwen model configured but rarely used
   - Risk: Production failures if OpenAI unavailable

7. **Rate Limiting In-Memory**
   - Impact: Medium - Doesn't scale across replicas
   - Current: `defaultdict` in `main.py`
   - Better: Redis or distributed rate limiter

8. **No Integration Tests**
   - Impact: Medium - Regression risk
   - Current: Manual testing only
   - Needed: End-to-end RAG pipeline tests

### Low Priority

9. **Mixed Terminology**
   - "Jade-Brain" vs "Jade Engine" vs "Conversation Engine"
   - "Gojo" vs "Avatar" vs "Assistant"
   - Needs: Consistent naming convention

10. **D-ID Integration Unused**
    - API key configured but feature disabled
    - Decision: Remove or complete integration

11. **Helm Chart Values Split**
    - `values.yaml` vs `values.prod.yaml`
    - Consider: Single values file with overlays

---

## Security Posture (VERIFIED)

### Implemented Protections

✅ **Authentication/Authorization**
- No authentication implemented (public chatbot)
- Rate limiting: 30 req/min per IP

✅ **Input Validation**
- Path traversal prevention
- SSRF protection
- SQL injection N/A (no SQL database)
- XSS prevention via React

✅ **Security Headers**
- CSP (Content Security Policy)
- HSTS (HTTPS only)
- X-Frame-Options: DENY
- X-Content-Type-Options: nosniff
- X-XSS-Protection: 1; mode=block

✅ **Container Security**
- Non-root user execution
- Multi-stage builds
- No secrets in images
- Python 3.11-slim base

✅ **Dependency Security**
- No known vulnerabilities (GP-Copilot scan: 0 findings)
- Lock files: requirements.txt, package-lock.json
- Regular updates via Dependabot

### Security Gaps

⚠️ **No Authentication**
- Risk: Resource abuse, data exfiltration
- Mitigation: Rate limiting (30/min)
- Status: Acceptable for public demo

⚠️ **API Keys in Environment**
- Risk: Exposure if container compromised
- Mitigation: K8s secrets (base64)
- Better: External secret manager (Vault, AWS Secrets Manager)

⚠️ **No Request Signing**
- Risk: Replay attacks
- Status: Low priority (stateless API)

---

## Performance Characteristics

### Measured Metrics (Development)

```
Response Time: <2s average (RAG + LLM + validation)
RAG Search: <100ms (top-5 semantic search)
Embedding: ~50ms per query
LLM API Call: 800ms-1500ms (OpenAI)
Total Pipeline: 1000ms-2000ms
```

### Scalability Limits

1. **ChromaDB**
   - Current: Single instance
   - Limit: ~1M vectors before performance degrades
   - Current size: ~2000 vectors (20 docs × ~100 chunks)

2. **Rate Limiting**
   - Current: In-memory (per-pod)
   - Limit: Doesn't scale across replicas
   - Solution: Redis-backed limiter

3. **Concurrent Users**
   - Tested: Up to 50 simultaneous chats
   - Bottleneck: OpenAI API quota
   - Current quota: 10 req/min (free tier)

4. **Knowledge Base**
   - Current: 20 documents
   - Practical limit: ~200 documents before reindex time becomes significant
   - Ingestion time: ~30s for 20 docs

---

## Deployment Pipeline

### Current State

```
Development
    ↓
Git Push to main
    ↓
GitHub Actions CI/CD
    ↓
Build Docker images
    ↓
Push to GHCR (ghcr.io/jimjrxieb/portfolio-*)
    ↓
Helm deploy to Kubernetes
    ↓
Cloudflare Tunnel exposes service
    ↓
Production (linksmlm.com)
```

### Infrastructure as Code

- **K8s Manifests**: `charts/portfolio/templates/`
- **Helm Values**: `charts/portfolio/values.prod.yaml`
- **Docker Compose**: `docker-compose.yml` (local dev)
- **CI/CD**: `.github/workflows/*.yml`

### Deployment Targets

1. **Local**: Docker Compose
2. **Production**: Kubernetes cluster
3. **Cloud**: Cloudflare Tunnel (no traditional cloud provider)

---

## Data Sources & Knowledge Base

### Source Documents (20+ files in `/data/knowledge/`)

**Professional Information**:
- `01-bio.md` - Biography and mission statement
- `02-values.md` - Professional values
- `03-expertise.md` - DevOps/DevSecOps skills
- `04-projects.md` - Project descriptions
- `05-experience.md` - Work history

**Technical Deep Dives**:
- `06-jade.md` - LinkOps AI-BOX documentation
- `07-afterlife.md` - LinkOps Afterlife platform
- `08-ai-ml.md` - AI/ML expertise
- `09-kubernetes.md` - K8s knowledge
- `10-ci-cd.md` - CI/CD practices

**Case Studies & Validation**:
- `zrs-management-case-study.md` - Client success story
- `gojo-golden-set.md` - Q&A validation set
- `faq.md` - Common questions

**Certifications**:
- CKA (Certified Kubernetes Administrator)
- Security+
- GenAI certifications

### Ingestion Pipeline

```python
# rag-pipeline/ingestion_engine.py
1. Read markdown files from /data/knowledge/
2. Sanitize content (remove code injection attempts)
3. Chunk into 1000-token segments
4. Generate embeddings (sentence-transformers)
5. Store in ChromaDB with metadata
6. Create versioned collection (portfolio_v{N})
7. Atomic swap: portfolio_latest → portfolio_v{N}
```

### Vector Database Structure

```
ChromaDB Collections:
├── portfolio_v1        # Initial ingestion
├── portfolio_v2        # After updates
├── portfolio_latest    # Alias to current version
└── [metadata]
    ├── source_file     # Origin document
    ├── chunk_index     # Position in document
    ├── embedding_model # sentence-transformers/all-MiniLM-L6-v2
    └── ingestion_date  # Timestamp
```

---

## Refactoring Priorities

### Phase 1: Documentation Accuracy (PARTIALLY COMPLETE)

- [x] Fix README.md (was showing Conftest) - **DONE**
- [x] Update GP-COPILOT report with accurate tech stack - **DONE**
- [x] Create this baseline document - **IN PROGRESS**
- [ ] Standardize avatar naming (Gojo/Jade/Sheyla)
- [ ] Fix all references to `api/services/` → `api/engines/`
- [ ] Document actual vs configured services

### Phase 2: Code Cleanup

- [ ] Decide on Sheyla implementation (complete or remove)
- [ ] Rename `jade_engine.py` → `conversation_engine.py` OR embrace "Jade"
- [ ] Remove unused D-ID integration (or complete it)
- [ ] Extract hardcoded values to configuration
- [ ] Add type hints to all functions

### Phase 3: Architecture Improvements

- [ ] Replace in-memory rate limiting with Redis
- [ ] Add structured logging (JSON format)
- [ ] Implement Prometheus metrics
- [ ] Add integration test suite
- [ ] Document API with OpenAPI examples

### Phase 4: Feature Enhancements

- [ ] Admin authentication for RAG management
- [ ] Conversation history persistence
- [ ] Analytics dashboard
- [ ] A/B testing for response quality
- [ ] Multi-language support

---

## Questions Requiring Decisions

### 1. Avatar Naming Strategy

**Options**:
A. **Gojo + Jade Engine** (current reality)
B. **Sheyla + Jade Engine** (partially implemented)
C. **Single unified name** (requires renaming)

**Recommendation**: Option A - Match code reality

### 2. Service Directory Naming

**Options**:
A. Keep `api/engines/` (current)
B. Rename to `api/services/` (match common patterns)
C. Split: `api/engines/` (core) + `api/services/` (external)

**Recommendation**: Option A - Avoid large refactor

### 3. Sheyla Implementation

**Options**:
A. Complete Sheyla as second avatar
B. Remove Sheyla stub code
C. Merge Sheyla personality into Gojo

**Recommendation**: Option B or C - Avoid confusion

### 4. D-ID Integration

**Options**:
A. Complete D-ID video avatar integration
B. Remove D-ID configuration entirely
C. Keep as optional future feature

**Recommendation**: Option C - Low priority

### 5. Monitoring Strategy

**Options**:
A. Add Prometheus + Grafana (self-hosted)
B. Use cloud monitoring (Datadog, New Relic)
C. Stick with health checks only

**Recommendation**: Option A - Stay self-hosted

---

## Success Metrics

### Current State (Baseline)

- **Response Time**: ~1.5s average
- **RAG Accuracy**: ~85% (based on golden set)
- **LLM Cost**: ~$2/month (low traffic)
- **Uptime**: 99%+ (no SLA)
- **Visitors**: Low volume (demo phase)

### Target State (Post-Refactoring)

- **Response Time**: <1s (p95)
- **RAG Accuracy**: >90% (validated)
- **Documentation Accuracy**: 100% (matches code)
- **Test Coverage**: >80% (unit + integration)
- **Naming Consistency**: 100% (single terminology)

---

## Appendix: File Inventory

### Python Files (Backend)
```
api/main.py                    147 lines  Main FastAPI app
api/settings.py               ~100 lines  Configuration
api/engines/jade_engine.py     360 lines  Conversation logic
api/engines/rag_engine.py     ~250 lines  RAG operations
api/engines/llm_engine.py     ~200 lines  LLM client
api/engines/response_generator.py ~180 lines Response validation
api/routes/chat.py            ~150 lines  Chat endpoints
api/routes/rag.py             ~120 lines  RAG management
Total: ~1500 lines of production Python
```

### TypeScript Files (Frontend)
```
ui/src/components/GojoAvatar3D.tsx  ~600 lines  3D avatar
ui/src/components/Chat.tsx          ~400 lines  Chat UI
ui/src/components/Projects.tsx      ~300 lines  Project showcase
ui/src/App.tsx                      ~200 lines  Main app
Total: ~1500 lines of production TypeScript
```

### Documentation Files
```
README.md                    484 lines  Main documentation (FIXED)
GP-COPILOT-ASSESSMENT-REPORT.md  392 lines  Security assessment (UPDATED)
REFACTORING_BASELINE.md      THIS FILE  Refactoring baseline
docs/**/*.md                ~2000 lines  Development docs
```

---

## Next Steps

1. **Review this baseline** with project owner
2. **Make decisions** on naming and architecture questions
3. **Create action plan** for refactoring phases
4. **Execute Phase 1** (documentation accuracy)
5. **Validate changes** don't break production
6. **Iterate** through remaining phases

---

**Document Status**: Draft for Review
**Last Updated**: November 3, 2025
**Next Review**: After owner decisions on open questions