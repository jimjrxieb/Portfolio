# Portfolio Context Documentation

This folder contains comprehensive documentation with `data-dev` tags to help navigate and troubleshoot the portfolio system.

## Quick Navigation

- [API Components](./api-components.md) - Backend routes, health endpoints, LLM integration
- [UI Components](./ui-components.md) - Frontend React components and data-dev tags  
- [Database & RAG](./database-rag.md) - ChromaDB, ingestion, knowledge management
- [Deployment](./deployment.md) - Kubernetes, Docker, environment configuration
- [Troubleshooting](./troubleshooting.md) - Common issues and diagnostic steps

## Dev Tags Index

All components are marked with `data-dev` attributes for easy targeting:

### API Tags
- `data-dev:api-rag` - RAG helper functions
- `data-dev:api-routes-chat` - Chat endpoint with LLM integration
- `data-dev:api-routes-health` - Health check endpoints
- `data-dev:api-routes-avatar` - Avatar upload and talk creation
- `data-dev:ingest` - Knowledge ingestion script

### UI Tags  
- `data-dev:ui-avatar-panel` - Avatar upload and voice controls
- `data-dev:ui-intro-snippets` - Suggested chat questions
- `data-dev:ui-voice-presets` - Voice selection options
- `data-dev:chat-panel` - Chat interface
- `data-dev:chat-answer` - Chat response display
- `data-dev:image-input` - Avatar image upload
- `data-dev:voice-select` - Voice style selection

### Test Tags
- `data-dev:portfolio-root` - Main app container
- `data-dev:content-area` - Main content grid
- `data-dev:avatar-column` - Left panel with avatar
- `data-dev:projects-column` - Right panel with projects

## Architecture Overview

```
Frontend (React) → FastAPI → LLM (Ollama/vLLM) + RAG (ChromaDB) + Services (D-ID, ElevenLabs)
     ↓
Kubernetes Deployment → Cloudflare → Public Access
```