# Portfolio API

FastAPI-based backend service for the Portfolio AI platform with RAG capabilities, LLM integration, and avatar services.

## Overview

This API provides:
- **Chat Interface**: LLM-powered conversations with RAG context
- **Avatar Services**: D-ID and ElevenLabs integration for avatar creation
- **Health Monitoring**: System health checks and diagnostics
- **Action Processing**: Structured action handling for UI interactions
- **Knowledge Retrieval**: ChromaDB-based vector search

## Tech Stack

- **Framework**: FastAPI 0.104.1
- **ML/AI**: PyTorch, Transformers, Sentence-Transformers
- **Vector DB**: ChromaDB 0.4.18
- **LLM**: OpenAI GPT integration
- **Python**: 3.10+

## Project Structure

```
/api/
├── main.py              # FastAPI application entry point
├── settings.py          # Configuration management
├── requirements.txt     # Python dependencies
├── Dockerfile          # Container configuration
├── /routes/            # API endpoints
│   ├── actions.py      # Action processing endpoints
│   ├── avatar.py       # Avatar generation endpoints
│   ├── chat.py         # Chat/conversation endpoints
│   ├── health.py       # Health check endpoints
│   ├── rag.py          # RAG query endpoints
│   └── uploads.py      # File upload handling
├── /services/          # External service integrations
│   ├── did.py          # D-ID avatar service
│   └── elevenlabs.py   # ElevenLabs TTS service
├── /engines/           # Core processing engines
│   ├── avatar_engine.py    # Avatar processing logic
│   ├── llm_engine.py       # LLM interaction engine
│   ├── rag_engine.py       # RAG pipeline engine
│   └── speech_engine.py    # Speech synthesis engine
└── /assets/            # Static assets
    └── *.mp3           # Audio files

```

## API Endpoints

### Core Endpoints

- `GET /health` - System health status
- `GET /health/detailed` - Detailed system diagnostics

### Chat & RAG

- `POST /chat` - Send chat message with RAG context
- `POST /rag/query` - Direct RAG knowledge query
- `GET /rag/status` - RAG system status

### Avatar Services

- `POST /avatar/create` - Generate avatar from image
- `POST /avatar/speak` - Generate avatar speech
- `GET /avatar/status` - Avatar service status

### Actions

- `POST /actions/process` - Process structured UI actions
- `GET /actions/list` - Available actions

## Quick Start

### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
cp .env.example .env
# Edit .env with your API keys

# Run development server
uvicorn main:app --reload --port 8000
```

### Docker Deployment

```bash
# Build image
docker build -t portfolio-api .

# Run container
docker run -p 8000:8000 --env-file .env portfolio-api
```

## Environment Variables

```env
# Required
OPENAI_API_KEY=your-openai-key
CHROMA_URL=http://chromadb:8000

# Optional
DID_API_KEY=your-did-key
ELEVENLABS_API_KEY=your-elevenlabs-key
GPT_MODEL=gpt-4o-mini
```

## Testing

```bash
# Health check
curl http://localhost:8000/health

# Chat example
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Tell me about Jimmie"}'
```

## Security

- CORS configured for production domains
- API key authentication for external services
- Input validation via Pydantic schemas
- Rate limiting on chat endpoints

## Contributing

1. Follow FastAPI best practices
2. Add Pydantic schemas for all endpoints
3. Include docstrings for API documentation
4. Test with provided test scripts