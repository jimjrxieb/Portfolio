# ChromaDB Embedding Model Timeout Pattern

## Problem Summary

Portfolio chatbox failed with 504 timeouts because ChromaDB's `query_texts` method downloads a 79MB embedding model on first use, blocking all FastAPI threads.

## Root Cause Chain

1. Chat request triggers RAG search
2. ChromaDB `query_texts` needs to embed the query
3. Default embedding function (all-MiniLM-L6-v2) downloads 79MB ONNX model to `/.cache`
4. Download blocked by `readOnlyRootFilesystem: true` OR takes 30+ seconds
5. All threads blocked → health checks timeout → pod restart loop

## Quick Reference

| Symptom | Cause | Fix |
|---------|-------|-----|
| 504 Gateway Timeout on chat | Embedding model download blocking | Add cache volume or disable RAG |
| Read-only filesystem error | `/.cache` not writable | Add emptyDir volume for `/.cache` |
| Health probes timing out | Threads blocked by download | Same as above |
| Claude model not found | Wrong model name | Use `claude-3-haiku-20240307` |

## Key Files Modified

```
backend/engines/rag_engine.py    # Changed to query_texts
backend/settings.py              # Fixed Claude model name
api/routes/chat.py               # Disabled RAG temporarily
s0-shared-mods/portfolio-app/main.tf  # Added /.cache volume
```

## Solution Pattern

### Add Cache Volume for ChromaDB
```hcl
# Volume mount
volume_mount {
  name       = "cache"
  mount_path = "/.cache"
}

# Volume definition
volume {
  name = "cache"
  empty_dir {}
}
```

### Disable RAG as Temporary Fix
```python
# In chat.py - bypass RAG until embedding solution ready
if False and request.include_citations:
    # RAG code...
```

## Future Solutions for RAG

1. **Pre-download model in init container**
2. **Deploy Ollama sidecar**
3. **Use ChromaDB server-side embedding**

## Key Insight

ChromaDB's client-side embedding (`query_texts`) is dangerous in K8s:
- Downloads model synchronously on first query
- Blocks entire server during download
- Requires writable `/.cache` directory

Prefer `query_embeddings` with pre-computed vectors when possible.
