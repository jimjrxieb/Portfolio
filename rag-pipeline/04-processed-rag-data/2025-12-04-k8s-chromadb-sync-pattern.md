# K8s ChromaDB Sync Pattern - Docker Desktop WSL2
Date: 2025-12-04

## Problem
RAG pipeline was ingesting to local ChromaDB, but K8s-deployed Sheyla connected to a separate, empty K8s ChromaDB. Docker Desktop WSL2 doesn't support hostPath volume mapping from WSL filesystem paths.

## Key Discovery
- Local ChromaDB: `/Portfolio/data/chroma/` - 35 docs
- K8s ChromaDB: emptyDir volume - 0 docs (empty!)
- hostPath PV pointing to `/home/jimmie/...` doesn't work in Docker Desktop K8s

## Solution: HTTP-based Sync
Added `k8s` command to pipeline that:
1. Port-forwards to K8s ChromaDB service
2. Connects via ChromaDB HttpClient (not PersistentClient)
3. Re-creates collection and ingests all documents
4. Cleans up port-forward

## Usage
```bash
cd ~/linkops-industries/Portfolio/rag-pipeline
python run_pipeline.py k8s  # Sync to K8s ChromaDB
```

## Trade-offs
- **Accepted**: K8s ChromaDB uses emptyDir (data lost on restart)
- **Accepted**: Must re-run `k8s` command after RAG updates or pod restarts
- **Avoided**: Complex storage configuration for dev environment

## When to Use
- Docker Desktop on WSL2 with local-to-K8s data sync
- Development environments where data can be recreated
- When PV/PVC debugging isn't worth the time

## Key Insight
Always verify the full data flow: where data is written vs where the app reads from. Two separate ChromaDB instances (local file vs K8s pod) look identical in code but are completely disconnected.
