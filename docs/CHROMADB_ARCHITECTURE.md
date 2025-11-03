# ChromaDB Architecture - Vector Storage Explained

**Date**: November 3, 2025
**Status**: Production vector database

---

## What is ChromaDB?

ChromaDB is your **vector database** - it stores numerical representations (embeddings) of your knowledge base documents that enable semantic search.

### Location
```
/home/jimmie/linkops-industries/Portfolio/data/chroma/
├── chroma.sqlite3                    # 6.8MB - Main database
├── c9f9d6de-a523-44cc-8ab3-93a7fa4663e5/   # Collection storage
└── f660efa7-7061-4d41-9fc8-4a113ac4f9de/   # Collection storage
```

---

## How RAG Works

```
User Question: "What is LinkOps AI-BOX?"
    ↓
1. EMBED QUESTION
   sentence-transformers converts question → 384-dimensional vector
   [0.123, -0.456, 0.789, ...]
    ↓
2. SEMANTIC SEARCH (ChromaDB)
   Find similar vectors in knowledge base
   Query ChromaDB with question vector
   Return top 5 most similar chunks
    ↓
3. RETRIEVE CONTEXT
   Chunk 1: "LinkOps AI-BOX is a plug-and-play AI system..."
   Chunk 2: "Also known as Jade Box, it targets companies..."
   Chunk 3: "First client is ZRS Management in Orlando..."
   [+ source file, chunk index, metadata]
    ↓
4. CONSTRUCT PROMPT
   System: You are a helpful assistant...
   Context: [Retrieved chunks with citations]
   Question: What is LinkOps AI-BOX?
    ↓
5. LLM GENERATION (Claude 3.5 Sonnet)
   Generate answer using context
   Include citations to source documents
    ↓
6. RETURN ANSWER
   "LinkOps AI-BOX is a plug-and-play AI system for
   security-conscious companies [Source: 06-jade.md]..."
```

---

## ChromaDB Contents (Current State)

### What's Stored
- **22 markdown files** → chunked into ~2000 segments
- **Each chunk**:
  - Original text content
  - 384-dimensional embedding vector
  - Metadata (source file, chunk index, timestamp)

### Data Flow
```
Markdown File (06-jade.md)
    ↓
Ingestion Engine reads file
    ↓
Sanitize content (remove code injection)
    ↓
Chunk into 1000-token segments
    ↓
Generate embeddings (sentence-transformers)
    ↓
Store in ChromaDB with metadata
    ↓
Query at runtime for semantic search
```

---

## Current Issue

Your ChromaDB contains **old embeddings** from before cleanup:
- ❌ Has embeddings from `08-sheyla-avatar-context.md` (deleted)
- ❌ Has embeddings from `07-current-context.md` (archived, outdated)
- ❌ Has embeddings mentioning Gojo avatar (removed)
- ❌ Has outdated tech stack info (Qwen, not Claude)

### Solution: Rebuild ChromaDB

We need to:
1. Clear old embeddings
2. Re-ingest cleaned knowledge base (21 files)
3. Generate fresh embeddings
4. Test RAG retrieval accuracy

---

## ChromaDB vs Source Files

### Source Files (Truth)
```
/data/knowledge/*.md
- 01-bio.md
- 06-jade.md
- 09-current-tech-stack.md (NEW)
- qa-validation-set.md (UPDATED)
```
**Purpose**: Human-readable knowledge base

### ChromaDB (Search Index)
```
/data/chroma/chroma.sqlite3
```
**Purpose**: Fast semantic search over embedded knowledge

**Relationship**: ChromaDB is a **searchable index** of source files

---

## Embeddings Explained

### What are embeddings?
Numerical representation of text that captures semantic meaning.

**Example**:
- "LinkOps AI-BOX" → [0.12, -0.45, 0.78, ..., 0.34] (384 numbers)
- "Jade Box product" → [0.11, -0.44, 0.79, ..., 0.35] (similar!)
- "Weather forecast" → [-0.89, 0.23, -0.12, ..., 0.91] (different!)

### Why 384 dimensions?
- Model: `sentence-transformers/all-MiniLM-L6-v2`
- Output: 384-dimensional vectors
- Balance: Good quality, reasonable speed
- Alternatives: 768-dim (better quality, slower), 128-dim (faster, lower quality)

---

## Testing ChromaDB

### Check Current Contents
```bash
# Start ChromaDB
docker-compose up -d chromadb

# Check health
curl http://localhost:8001/api/v1/heartbeat

# List collections
curl http://localhost:8001/api/v1/collections

# Count documents
curl -X POST http://localhost:8001/api/v1/collections/portfolio_knowledge/count
```

### Query ChromaDB Directly
```python
import chromadb

client = chromadb.PersistentClient(path="/data/chroma")
collection = client.get_collection("portfolio_knowledge")

# Search for similar documents
results = collection.query(
    query_texts=["What is LinkOps AI-BOX?"],
    n_results=5
)

# Print results
for doc, metadata in zip(results['documents'][0], results['metadatas'][0]):
    print(f"Source: {metadata['source']}")
    print(f"Content: {doc[:200]}...")
    print("---")
```

---

## Rebuild Process

### Step 1: Backup Current ChromaDB (Optional)
```bash
cp -r /home/jimmie/linkops-industries/Portfolio/data/chroma \
      /home/jimmie/linkops-industries/Portfolio/data/chroma.backup
```

### Step 2: Clear Old Collection
```bash
# Option A: Delete database file
rm /home/jimmie/linkops-industries/Portfolio/data/chroma/chroma.sqlite3

# Option B: Drop collection via API
curl -X DELETE http://localhost:8001/api/v1/collections/portfolio_knowledge
```

### Step 3: Re-ingest Clean Knowledge Base
```bash
cd /home/jimmie/linkops-industries/Portfolio/rag-pipeline

# Run ingestion
python run_ingestion.py

# Should process 21 files (not 22 anymore)
```

### Step 4: Verify New Embeddings
```bash
# Check count
curl -X POST http://localhost:8001/api/v1/collections/portfolio_knowledge/count

# Query should NOT return deleted files
curl -X POST http://localhost:8001/api/v1/collections/portfolio_knowledge/query \
  -H "Content-Type: application/json" \
  -d '{"query_texts": ["sheyla avatar"], "n_results": 5}'

# Should return empty or unrelated results
```

---

## Performance Metrics

### Current State
- **Database Size**: 6.8MB
- **Estimated Vectors**: ~2000 chunks
- **Search Time**: <100ms
- **Accuracy**: Unknown (needs testing with clean data)

### After Rebuild
- **Database Size**: ~6.5MB (slightly smaller, 1 file removed)
- **Estimated Vectors**: ~1950 chunks
- **Search Time**: <100ms (same)
- **Accuracy**: Should improve (no outdated info)

---

## RAG Quality Factors

### Good RAG Response
1. ✅ **Grounded**: Uses actual document content
2. ✅ **Cited**: References source files
3. ✅ **Relevant**: Top chunks match question
4. ✅ **Current**: Uses updated information
5. ✅ **Complete**: Includes key details

### Bad RAG Response
1. ❌ **Hallucinated**: Made up facts not in docs
2. ❌ **Outdated**: References deleted/old info
3. ❌ **Irrelevant**: Retrieved wrong chunks
4. ❌ **Incomplete**: Missing important context

---

## Your System: LLM + RAG

### Components
```
Claude 3.5 Sonnet (LLM)
    +
ChromaDB (Vector DB)
    +
sentence-transformers (Embeddings)
    +
Knowledge Base (21 files)
    =
Smart Chatbot (RAG-powered)
```

### What It Can Do
- Answer questions about your experience
- Explain LinkOps AI-BOX details
- Discuss ZRS Management project
- Share DevOps/AI expertise
- Provide accurate, cited responses

### What It Cannot Do (Without Retrieval)
- Know specific details about your projects
- Remember exact dates/names
- Cite sources
- Stay current with updates

**That's why RAG is crucial!**

---

## Next Steps

1. **Backup current ChromaDB** (safety)
2. **Clear old embeddings** (clean slate)
3. **Re-ingest 21 clean files** (fresh data)
4. **Test retrieval** (verify accuracy)
5. **Test full chatbot** (LLM + RAG)

Ready to rebuild? Let's do it! 🚀
