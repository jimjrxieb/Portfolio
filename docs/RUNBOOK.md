# Portfolio Operations Runbook

## Quick Start

```bash
# Deploy everything
./scripts/release.sh

# Verify deployment
API_BASE=https://your-api-domain ./scripts/verify.sh

# Local development
docker-compose up -d
```

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   React UI      │    │   FastAPI        │    │   Ollama        │
│   (Vite/TS)     │◄──►│   + ChromaDB     │◄──►│   (LLM)         │
│                 │    │   + ElevenLabs   │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Key Components

- **UI**: `ui/src/components/` - React components with centralized API client
- **API**: `api/app/` - FastAPI with routes, services, schemas organization  
- **RAG**: ChromaDB with `portfolio` namespace for context retrieval
- **LLM**: Ollama (phi3:latest) for chat responses
- **Avatar**: ElevenLabs TTS + D-ID with fallback to default assets

## Health Checks (Production)

### 1. Model + RAG Health

```bash
API=https://your-api-domain

# Check LLM connectivity and model info
curl -sS $API/api/health/llm | jq
# Expected: {"ok": true, "provider": "ollama", "model": "phi3:latest"}

# Check RAG/ChromaDB connectivity  
curl -sS $API/api/health/rag | jq
# Expected: {"ok": true, "hits": N, "namespace": "portfolio"}
```

### 2. Chat Integration

```bash
# Test chat with context retrieval
curl -sS -X POST $API/api/chat \
  -H 'Content-Type: application/json' \
  -d '{"message":"Tell me about your work at ZRS","namespace":"portfolio","k":5}' | jq

# Expected response:
# {
#   "answer": "I work at ZRS Management...",
#   "citations": [{"text": "...", "source": "..."}],
#   "model": "phi3:latest"
# }
```

### 3. Avatar Fallback

```bash
# Test avatar creation (should work even without API keys)
curl -sS -X POST $API/api/actions/avatar/talk \
  -H 'Content-Type: application/json' \
  -d '{"text":"Hello world"}' | jq

# Expected: {"url": "/api/assets/default-intro"} or TTS URL if ELEVENLABS_API_KEY set
```

## Data Management

### Seed RAG Knowledge Base

If RAG health check returns 0 hits, seed the knowledge base:

```bash
# Ingest knowledge files
curl -sS -X POST $API/api/actions/rag/upsert \
  -H 'Content-Type: application/json' -d '{
  "namespace":"portfolio",
  "chunks":[
    {"text":"Jimmie Coleman is an AI/ML engineer and DevSecOps specialist.", "metadata":{"source":"bio"}},
    {"text":"ZRS Management is a property management company in Orlando, FL.", "metadata":{"source":"about-zrs"}},
    {"text":"Work orders must be acknowledged within 1 business day.", "metadata":{"policy":"SLA"}},
    {"text":"Jade is the AI-powered customer service system at ZRS.", "metadata":{"project":"jade"}},
    {"text":"LinkOps Afterlife is the open-source avatar memorial project.", "metadata":{"project":"afterlife"}}
  ]
}'

# Verify ingestion
curl -sS $API/api/health/rag | jq '.hits'
```

### Update Content

Edit these files and rebuild UI:

- **Q&A prompts**: `ui/src/data/knowledge/jimmie/qa.json`
- **Projects**: `ui/src/data/knowledge/jimmie/projects.json`
- **Knowledge docs**: `data/knowledge/jimmie/*.md`

## Configuration

### Environment Variables (API)

```bash
# Core LLM settings
LLM_PROVIDER=ollama
LLM_MODEL=phi3:latest
LLM_API_BASE=http://ollama:11434
LLM_API_KEY=""  # Empty for Ollama

# RAG settings  
RAG_NAMESPACE=portfolio
CHROMA_URL=http://chroma:8000

# Optional AI services
ELEVENLABS_API_KEY=el_xxx  # For voice synthesis
ELEVENLABS_DEFAULT_VOICE_ID=giancarlo
DID_API_KEY=did_xxx        # For avatar videos

# System settings
DATA_DIR=/data
PUBLIC_BASE_URL=https://your-api-domain
```

### Environment Variables (UI)

```bash
# ui/.env
VITE_API_BASE=https://your-api-domain
```

### Kubernetes Deployment

```bash
# Update API config
kubectl -n portfolio set env deploy/portfolio-api \
  LLM_PROVIDER=ollama \
  LLM_MODEL=phi3:latest \
  OLLAMA_BASE_URL=http://ollama:11434 \
  CHROMA_URL=http://chroma:8000 \
  RAG_NAMESPACE=portfolio

# Restart to apply
kubectl -n portfolio rollout restart deploy/portfolio-api
kubectl -n portfolio rollout status deploy/portfolio-api
```

## Troubleshooting

### UI Shows "Chat Failed"

**Symptoms**: Chat input shows error, no responses

**Debug steps**:
1. Check API connectivity: `curl $API/api/health`
2. Check LLM health: `curl $API/api/health/llm | jq '.ok'`
3. Check RAG health: `curl $API/api/health/rag | jq '.ok'`
4. Verify UI environment: Check `VITE_API_BASE` in built files

**Common fixes**:
- Fix `LLM_MODEL` / `LLM_API_BASE` for LLM connection
- Fix `CHROMA_URL` for RAG connection  
- Rebuild UI with correct `VITE_API_BASE`
- Check CORS settings in API

### No Context in Responses

**Symptoms**: Chat works but doesn't reference knowledge base

**Debug steps**:
1. Check RAG health: `curl $API/api/health/rag`
2. Verify namespace: Should show `"namespace": "portfolio"`
3. Check hit count: Should be > 0

**Common fixes**:
- Run RAG ingestion (see "Seed RAG Knowledge Base")
- Verify `RAG_NAMESPACE=portfolio` in API config
- Check ChromaDB connectivity

### Avatar Has No Audio

**Symptoms**: Avatar upload works but no sound on "Play Introduction"

**Debug steps**:
1. Check for ELEVENLABS_API_KEY in API logs
2. Verify default assets: `curl $API/api/assets/default-intro`
3. Check browser console for audio errors

**Expected behavior**:
- With ELEVENLABS_API_KEY: Generated TTS audio
- Without keys: Default intro audio from `/api/assets/default-intro`

### Model/Version Not Showing

**Symptoms**: ChatPanel shows "loading..." for model info

**Debug steps**:
1. Check health endpoint: `curl $API/api/health/llm | jq`
2. Verify UI is calling health endpoint
3. Check browser network tab for CORS/404 errors

**Common fixes**:
- Verify `LLM_MODEL` setting matches actual model
- Check API CORS configuration
- Ensure health endpoints are accessible

## Performance Monitoring

### Key Metrics

- **Chat response time**: Should be < 5s for typical queries
- **RAG query time**: Should be < 1s for document retrieval  
- **Avatar generation**: 2-10s depending on TTS/video processing
- **Memory usage**: API ~500MB, UI ~100MB base

### Scaling Considerations

- **Horizontal scaling**: API is stateless, can run multiple replicas
- **Database**: ChromaDB supports clustering for large knowledge bases
- **CDN**: Serve UI assets and generated audio through CDN
- **Rate limiting**: Add rate limits on chat/avatar endpoints for production

## Security Checklist

- [ ] **Secrets**: No API keys in UI source code or logs
- [ ] **Input validation**: Pydantic schemas validate all API inputs  
- [ ] **CORS**: Restricted to production domain (not `*`)
- [ ] **Container security**: Non-root containers, health probes, resource limits
- [ ] **Dependencies**: Pinned versions, vulnerability scanning
- [ ] **File uploads**: MIME type validation, safe storage paths
- [ ] **Authentication**: JWT tokens on chat/actions endpoints (TODO)
- [ ] **Network policies**: Kubernetes NetworkPolicy restricts pod communication

## Deployment Pipeline

### Automated Release

```bash
# Build, push, and deploy in one command
./scripts/release.sh

# Verify deployment
API_BASE=https://your-api-domain ./scripts/verify.sh
```

### Manual Steps

```bash
# 1. Build images
docker build -t ghcr.io/jimjrxieb/portfolio-api:latest -f api/Dockerfile api
docker build -t ghcr.io/jimjrxieb/portfolio-ui:latest -f ui/Dockerfile ui

# 2. Push images  
docker push ghcr.io/jimjrxieb/portfolio-api:latest
docker push ghcr.io/jimjrxieb/portfolio-ui:latest

# 3. Update deployments
kubectl -n portfolio set image deploy/portfolio-api api=ghcr.io/jimjrxieb/portfolio-api:latest
kubectl -n portfolio set image deploy/portfolio-ui ui=ghcr.io/jimjrxieb/portfolio-ui:latest

# 4. Wait for rollout
kubectl -n portfolio rollout status deploy/portfolio-api
kubectl -n portfolio rollout status deploy/portfolio-ui
```

## File Locations Reference

### Core Components
- **ChatBox**: `ui/src/components/ChatBox.jsx` - Main chat interface
- **ChatPanel**: `ui/src/components/ChatPanel.tsx` - Shows model/namespace info
- **Chat API**: `api/app/routes/chat.py` - Chat endpoint with RAG
- **Avatar routes**: `api/app/routes/actions.py` - Avatar creation with fallbacks
- **Settings**: `api/app/settings.py` - Centralized configuration

### Data Files  
- **Q&A prompts**: `ui/src/data/knowledge/jimmie/qa.json`
- **Projects**: `ui/src/data/knowledge/jimmie/projects.json`
- **Knowledge base**: `data/knowledge/jimmie/*.md`

### Infrastructure
- **K8s manifests**: `k8s/base/` - Base Kubernetes resources
- **Docker configs**: `api/Dockerfile`, `ui/Dockerfile`
- **Docker Compose**: `docker-compose.yml` - Local development

## Next Steps

### Immediate (Production Ready)
1. **JWT authentication**: Add auth to `/api/chat` and `/api/actions/*`
2. **Rate limiting**: Prevent abuse of LLM/avatar endpoints  
3. **Monitoring**: Add structured logging and metrics
4. **CI/CD**: GitHub Actions for automated testing and deployment

### Enhanced Features  
1. **Real ElevenLabs integration**: Complete TTS service implementation
2. **D-ID video avatars**: Add video generation capability
3. **Citation drawer**: Expandable UI for RAG sources
4. **Content management**: Admin interface for knowledge base updates

### Scale & Polish
1. **Performance**: Caching layer for frequent queries
2. **Analytics**: User interaction tracking and insights  
3. **Mobile**: Responsive design improvements
4. **Internationalization**: Multi-language support