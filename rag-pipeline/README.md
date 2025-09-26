# RAG Data Ingestion Pipeline 📊

**Separate service for processing and ingesting data that Jade needs to know**

## Purpose

This pipeline runs on a **separate port** and handles:
1. **Data Input**: Raw documents, files, content
2. **Preprocessing**: Sanitization and formatting
3. **Intelligence Decision**: Embed vs regular doc storage
4. **Storage**: Proper organization in `/data` or `/docs`

## Flow Architecture

```
Input Box → Sanitize → Preprocess → Decision → Storage → Jade Access
```

### Decision Logic:
```python
Ask: "Will someone query this with natural language questions?"
├── YES → Embed it (ChromaDB) → /data/chroma/
└── NO  → Regular doc → /docs/ or /data/knowledge/
```

## Current Setup

### Port Configuration
- **Main API**: Port 8000 (Jade-Brain integration)
- **RAG Pipeline**: Port 8003 (Data ingestion)
- **ChromaDB**: Port 8001 (Vector database)
- **UI**: Port 5173 (Frontend)

### Service Endpoints
- `POST /ingest` - Process and ingest documents
- `POST /sanitize` - Clean and preprocess data
- `POST /decide` - Determine storage strategy
- `GET /status` - Pipeline health check

## Data Flow

### 1. **Input Processing**
```
Raw Data Input → Sanitization → Format Detection
```

### 2. **Intelligence Decision**
```python
def decide_storage_strategy(content, metadata):
    if is_queryable_content(content):
        return "embed"  # → ChromaDB
    else:
        return "document"  # → Regular storage
```

### 3. **Storage Routing**
```
Embed Decision:
├── YES → Chunk → Embed → ChromaDB → /data/chroma/
└── NO  → Organize → File → /docs/ or /data/knowledge/
```

### 4. **Jade Access**
```
Jade Query → RAG Interface → ChromaDB Search → Context → Response
```

## Usage

### Start Pipeline Service
```bash
cd rag-pipeline
python3 rag_api.py  # Runs on port 8003
```

### Ingest Data via API
```bash
curl -X POST http://localhost:8003/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Jimmie is an AI engineer...",
    "source": "bio.md",
    "type": "knowledge"
  }'
```

### Web Interface (Future)
```html
<form action="http://localhost:8003/ingest" method="post">
  <textarea name="content" placeholder="Paste content here..."></textarea>
  <input type="text" name="source" placeholder="Source name">
  <button type="submit">Process & Ingest</button>
</form>
```

## Storage Strategy

### Embeddable Content (ChromaDB)
- **Criteria**: Natural language queryable
- **Examples**:
  - Bio information
  - Project descriptions
  - Technical expertise
  - FAQ content
- **Storage**: `/data/chroma/` (vector database)

### Document Content (File System)
- **Criteria**: Reference material, configs
- **Examples**:
  - Docker configurations
  - Kubernetes manifests
  - Scripts and code
  - Binary assets
- **Storage**: `/docs/` or organized in `/data/`

## Integration with Jade-Brain

### Query Flow
```
User Question → Jade-Brain → RAG Interface → ChromaDB → Context → LLM → Response
```

### Knowledge Access
- **Jade-Brain** queries ChromaDB for semantic search
- **Pipeline** populates ChromaDB with processed content
- **Clean separation** between ingestion and query

## Configuration

### Environment Variables
```bash
# Pipeline Configuration
RAG_PIPELINE_PORT=8003
CHROMA_URL=http://localhost:8001
EMBED_MODEL=sentence-transformers/all-MiniLM-L6-v2

# Storage Paths
DATA_DIR=/data
DOCS_DIR=/docs
KNOWLEDGE_DIR=/data/knowledge

# Processing Settings
CHUNK_SIZE=1000
CHUNK_OVERLAP=200
SANITIZE_HTML=true
```

### Decision Rules
```python
EMBED_RULES = {
    "file_types": [".md", ".txt", ".pdf"],
    "content_types": ["bio", "project", "skill", "faq"],
    "min_length": 50,
    "has_questions": True
}

DOCUMENT_RULES = {
    "file_types": [".yaml", ".json", ".py", ".sh"],
    "content_types": ["config", "script", "binary"],
    "reference_only": True
}
```

## Benefits of This Design

### 1. **Clean Separation**
- **Ingestion** service separate from **query** service
- **Preprocessing** isolated from **conversation**
- **Data decisions** centralized

### 2. **Intelligent Storage**
- **Automatic routing** based on content analysis
- **Optimal performance** for different content types
- **Proper organization** in filesystem

### 3. **Scalable Architecture**
- **Independent scaling** of ingestion vs query
- **Service isolation** for maintenance
- **Clear data flow** for debugging

### 4. **User-Friendly**
- **Simple input interface** for content
- **Automatic processing** decisions
- **Immediate availability** to Jade

---

**This pipeline ensures Jade has access to properly processed, intelligently stored knowledge while keeping the ingestion process clean and separate.**