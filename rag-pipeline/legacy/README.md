# Legacy RAG Scripts

These scripts are deprecated and kept for reference only.

## Deprecated Files
- `ingest_knowledge.py` - Old ingestion logic with hardcoded paths
- `query_knowledge.py` - Basic query interface
- `setup_rag.py` - Initial RAG setup script
- `test_rag_basic.py` - Basic RAG tests
- `test_rag_ingest.py` - Ingestion tests

## Current Implementation
Use the new RAG pipeline:
- `/rag-pipeline/ingestion_engine.py` - Intelligent content processing
- Updated to use `/data/knowledge/` and `/data/presentations/` structure
- Integrated with embed vs document decision logic

## Migration Notes
These scripts reference old folder structure:
- `/data/knowledge/jimmie/` → `/data/knowledge/`
- `/data/rag/jimmie/` → consolidated into `/data/knowledge/`
- `/data/talktrack/` → `/data/presentations/`