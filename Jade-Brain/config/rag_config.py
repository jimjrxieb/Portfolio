"""
Jade-Brain RAG Configuration
Configuration for knowledge base and semantic search
"""

import os
from pathlib import Path

# ChromaDB Configuration
CHROMA_DIR = Path(os.getenv("CHROMA_DIR", "/home/jimmie/linkops-industries/Portfolio/data/chroma"))
COLLECTION_NAME = "portfolio_knowledge"
CHROMA_URL = os.getenv("CHROMA_URL", "http://localhost:8000")

# Embedding Configuration
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
EMBEDDING_DIMENSION = 384  # all-MiniLM-L6-v2 dimension

# Search Parameters
DEFAULT_SEARCH_RESULTS = 5
MAX_SEARCH_RESULTS = 10
SIMILARITY_THRESHOLD = 0.5

# Knowledge Base Configuration
KNOWLEDGE_PATHS = [
    Path("/home/jimmie/linkops-industries/Portfolio/data/knowledge/jimmie"),
    Path("/home/jimmie/linkops-industries/Portfolio/data/rag/jimmie"),
    Path("/home/jimmie/linkops-industries/Portfolio/data/talktrack")
]

def get_rag_config() -> dict:
    """Get complete RAG configuration"""
    return {
        "chroma_dir": str(CHROMA_DIR),
        "collection_name": COLLECTION_NAME,
        "chroma_url": CHROMA_URL,
        "embedding_model": EMBEDDING_MODEL,
        "embedding_dimension": EMBEDDING_DIMENSION,
        "default_results": DEFAULT_SEARCH_RESULTS,
        "max_results": MAX_SEARCH_RESULTS,
        "similarity_threshold": SIMILARITY_THRESHOLD,
        "knowledge_paths": [str(p) for p in KNOWLEDGE_PATHS]
    }

def is_rag_configured() -> bool:
    """Check if RAG system is properly configured"""
    return CHROMA_DIR.exists() and any(p.exists() for p in KNOWLEDGE_PATHS)