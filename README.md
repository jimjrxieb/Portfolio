# James Portfolio - Interview Ready MVP

A local-first avatar + RAG platform optimized for Azure VM B2s (2 vCPU / 4 GB RAM).

## Features

- **Local LLM**: Qwen/Qwen2.5-1.5B-Instruct for efficient inference on 4GB RAM
- **RAG System**: ChromaDB with persona + talktrack data for grounded responses
- **Interview Ready**: Optimized prompts for professional interview scenarios
- **Modular Engines**: LLM, RAG, Avatar, and Speech engines with local/cloud options
- **Docker Optimized**: Memory limits and single worker configuration for B2s VM

## Quick Start

```bash
# Clone and enter directory
git clone <repo-url>
cd Portfolio

# Start services
docker compose up --build -d

# Ingest persona/talktrack data
docker compose exec api python preprocess.py

# Open browser
open http://localhost:5173
```

## Configuration

See `.env` file for configuration options:

- **LLM_ENGINE**: `local` (default) or `openai`
- **LLM_MODEL**: `Qwen/Qwen2.5-1.5B-Instruct` (4GB RAM optimized)
- **EMBED_MODEL**: `sentence-transformers/all-MiniLM-L6-v2`

For higher quality responses, uncomment OpenAI settings in `.env`.

## Interview Questions

Try these prompts:
- "Tell me about yourself"
- "What's your DevOps experience?"
- "Explain your AI/ML background"
- "Tell me about the Afterlife project"

## API Endpoints

- `GET /health` - System health check
- `POST /chat` - Chat with RAG-grounded responses
- `POST /avatar` - Generate avatar video (stub)
- `POST /speech` - Text-to-speech (stub)
- `GET /build-info` - Build information

## Memory Optimization

- API service: 2GB limit, 1GB reservation
- UI service: 512MB limit, 256MB reservation
- Single worker configuration for uvicorn
- ChromaDB persistent storage in `/app/models/chroma`

## Security Features

- Environment variable isolation
- Secure secret management
- CORS configuration
- Health check endpoints
- Resource limits

## Development

```bash
# API development
cd api
pip install -r requirements.txt
python main.py

# UI development  
cd ui
npm install
npm run dev
```

Built with FastAPI, React, ChromaDB, and Transformers.