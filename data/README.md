# Portfolio RAG Data

This directory contains the ChromaDB vector database used by Sheyla (the portfolio chatbot) to answer questions about Jimmie Coleman's experience, projects, and the GP-Copilot platform.

## Vector Database Stats

| Metric | Value |
|--------|-------|
| **Collection** | `portfolio_knowledge` |
| **Total Vectors** | 118 |
| **Embedding Model** | `nomic-embed-text` (768 dimensions) |
| **Embedding Provider** | Ollama (local) |
| **Source Documents** | 29 |

## Directory Structure

```
data/
├── README.md                    # This file
├── assets/                      # Static assets (images, etc.)
├── chroma/                      # ChromaDB persistent storage
│   ├── chroma.sqlite3           # SQLite metadata database
│   ├── 3be5febc-.../            # HNSW index segment
│   │   ├── data_level0.bin      # Vector data
│   │   ├── header.bin           # Index header
│   │   ├── length.bin           # Vector lengths
│   │   └── link_lists.bin       # HNSW graph links
│   ├── 76213bad-.../            # HNSW index segment
│   └── 91337959-.../            # HNSW index segment
├── chromadb-config/             # ChromaDB container config
│   ├── Dockerfile               # Custom ChromaDB image
│   └── health-check.py          # K8s health probe
└── uploads/                     # User upload staging
```

## Embedding Pipeline

The RAG pipeline lives in `../rag-pipeline/` and follows this flow:

```
00-new-rag-data/           Raw markdown/JSONL documents
        │
        ▼
02-prepared-rag-data/      Chunked & deduplicated (prepare_data.py)
   └── prepared_chunks.jsonl
        │
        ▼
03-ingest-rag-data/        Embedded into ChromaDB (ingest_data.py)
        │
        ▼
04-processed-rag-data/     Archived originals
```

### How to Re-embed

```bash
cd ../rag-pipeline

# Full pipeline (prep + ingest)
python run_pipeline.py

# Or run stages individually
python run_pipeline.py prep      # Chunk documents
python run_pipeline.py ingest    # Embed to ChromaDB
python run_pipeline.py status    # Check pipeline status
```

### Requirements

- **Ollama** running with `nomic-embed-text` model
- **Python 3.11+** with chromadb, requests packages

```bash
# Install embedding model
ollama pull nomic-embed-text

# Install Python dependencies
pip install -r ../rag-pipeline/requirements.txt
```

## Source Documents (29 files, 118 vectors)

### Architecture & Deployment
- `01-infrastructure-deployment.md` - K8s/Terraform infrastructure
- `02-ui-architecture.md` - React/Vite frontend architecture
- `03-security-policies.md` - OPA/Conftest security policies
- `04-api-backend-architecture.md` - FastAPI backend design
- `gp-copilot-overview.md` - GP-Copilot platform overview

### Personal & Bio
- `05-jimmie-coleman-bio-projects.md` - Professional background
- `2026-01-05-about-jimmie-coleman.md` - Detailed bio
- `2026-01-05-aws-cloud-experience.md` - AWS certifications & experience
- `07-sheyla-personality-easter-eggs.md` - Chatbot personality
- `2026-01-05-easter-eggs-and-people.md` - Fun facts & references

### AI/ML Systems
- `2026-01-05-jade-ai-complete.md` - JADE v0.9 LLM documentation
- `2026-01-05-jsa-agents-complete.md` - JSA agent architecture
- `01-jsa-variant-capabilities.jsonl` - Agent capabilities matrix
- `2026-01-05-gp-copilot-architecture.md` - Full system architecture

### Deployment Patterns (Troubleshooting Knowledge)
- `2025-12-04-cloudflare-tunnel-pattern.md`
- `2025-12-04-docker-image-deployment-pattern.md`
- `2025-12-04-k8s-chromadb-sync-pattern.md`
- `2025-12-04-k8s-deployment-triple-failure-pattern.md`
- `2025-12-04-terraform-localstack-deployment-pattern.md`
- `2025-12-05-chromadb-embedding-timeout-pattern.md`
- `2025-12-05-cicd-pipeline-method2-deployment-pattern.md`
- `method1-deployment-troubleshooting.md`
- `rag-grounding-fix-tldr.md`

### Policy Reviews
- `CONFTEST-POLICY-REVIEW.md`
- `GATEKEEPER-POLICY-REVIEW.md`
- `POLICY-IMPROVEMENTS-SUMMARY.md`

### Deployment Records
- `06-portfolio-deployment-session.md`
- `DEPLOYMENT-SUMMARY.md`
- `METHOD2-DEPLOYMENT-RESULTS.md`

## Metadata Schema

Each vector in ChromaDB includes this metadata:

```json
{
  "source": "01-infrastructure-deployment.md",
  "chunk_index": 0,
  "total_chunks": 5,
  "word_count": 312,
  "model": "nomic-embed-text",
  "ingested_at": "2026-01-05T22:30:00Z"
}
```

## Querying the Database

```python
import chromadb

client = chromadb.PersistentClient(path="data/chroma")
collection = client.get_collection("portfolio_knowledge")

# Semantic search
results = collection.query(
    query_texts=["What is JADE AI?"],
    n_results=5
)

# Get all documents
all_docs = collection.get(include=["documents", "metadatas"])
print(f"Total vectors: {collection.count()}")
```

## Kubernetes Deployment

ChromaDB runs in the `portfolio` namespace:

```bash
# Check ChromaDB pod
kubectl get pods -n portfolio -l app=chroma

# Port-forward for local access
kubectl port-forward -n portfolio svc/chroma 8000:8000

# Query via API
curl http://localhost:8000/api/v1/collections
```

---

*Last updated: 2026-01-06*
*Vectors: 118 | Documents: 29 | Model: nomic-embed-text*
