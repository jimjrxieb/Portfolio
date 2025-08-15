# API Components (`data-dev` Reference)

## Core Routes

### Chat Endpoint
**Tag**: `data-dev:api-routes-chat`  
**File**: `api/routes_chat.py`  
**Purpose**: Main chat interface with RAG integration

```python
# Key functions:
- chat(req: ChatRequest) -> ChatResponse
- Integrates RAG retrieval with LLM completion
- Returns answer + context snippets
```

**Dependencies**:
- `llm_client.py` - OpenAI-compatible LLM calls
- `rag.py` - ChromaDB retrieval functions
- `settings.py` - Environment configuration

### Health Endpoints
**Tag**: `data-dev:api-routes-health`  
**File**: `api/routes_health.py`  
**Purpose**: System health diagnostics

```python
# Endpoints:
- GET /api/health/llm - Tests LLM connectivity
- GET /api/health/rag - Tests ChromaDB and document retrieval
```

**Diagnostic Flow**:
1. `/health/llm` calls LLM with simple "ping" message
2. `/health/rag` queries ChromaDB for "What is Jade?" 
3. Returns `{ok: true/false, ...details}`

### Avatar Services
**Tag**: `data-dev:api-routes-avatar`  
**File**: `api/routes_avatar.py`  
**Purpose**: Avatar upload, TTS, and D-ID integration

```python
# Endpoints:
- POST /api/voice/tts - Text-to-speech via ElevenLabs
- POST /api/avatar/talk - Create D-ID talking avatar
- GET /api/avatar/talk/{id} - Poll for avatar completion
```

### Upload Services  
**Tag**: `data-dev:api-routes-uploads`  
**File**: `api/routes_uploads.py`  
**Purpose**: Image upload with validation

```python
# Functions:
- upload_image() - Validates, saves, returns public URL
- Image type checking with imghdr
- UUID-based filenames for security
```

## Supporting Modules

### RAG System
**Tag**: `data-dev:api-rag`  
**File**: `api/rag.py`  
**Purpose**: ChromaDB integration and document retrieval

```python
# Key functions:
- rag_retrieve(persist_dir, query, k=4) -> [(text, distance)]
- _get_chroma(persist_dir) - Lazy ChromaDB client initialization
```

### LLM Client
**File**: `api/llm_client.py`  
**Purpose**: OpenAI-compatible API calls (Ollama, vLLM, etc.)

```python
# Function:
- chat_complete(system_prompt, user_message) -> str
- Supports Bearer token auth for external APIs
- Configurable timeout and base URL
```

### Settings
**File**: `api/settings.py`  
**Purpose**: Environment variable configuration

```python
# Key settings:
- LLM_API_BASE - LLM server URL
- LLM_MODEL_ID - Model name (e.g., "phi3")
- DATA_DIR - Storage path for uploads/ChromaDB
- ELEVENLABS_API_KEY, DID_API_KEY - Service credentials
```

## Data Ingestion

### Knowledge Ingestion
**Tag**: `data-dev:ingest`  
**File**: `api/scripts/ingest.py`  
**Purpose**: Load markdown files into ChromaDB

```python
# Process:
1. Read *.md files from /data/knowledge/jimmie/
2. Create ChromaDB collection "jimmie"  
3. Upsert documents with simple doc-{i} IDs
```

**Usage**:
```bash
kubectl exec -it deploy/portfolio-api -- python -m api.scripts.ingest
```

## Error Handling Patterns

### Health Endpoints
- Return `{ok: false, error: "..."}` on failures
- Include diagnostic info (status_code, base URL)
- Lazy imports to avoid boot failures

### Chat Pipeline
- Transparent error messages: "Chat pipeline error: {e}"
- HTTP 502 for backend failures
- Context always returned (empty array if retrieval fails)

### File Uploads
- Content-type validation with imghdr
- Size limits (10MB images)
- UUID prefixes to prevent filename collisions