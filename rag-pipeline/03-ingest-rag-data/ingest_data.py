#!/usr/bin/env python3
"""
INGEST DATA SCRIPT - The Kitchen (Cooking Station)
===================================================

Takes prepared ingredients from 02-prepared-rag-data/ and cooks them.
Embedding is the "cooking" - transforming text into 768-dimensional vectors.

FLOW:
  02-prepared-rag-data/  -->  [chunk, embed, store]  -->  ChromaDB + 04-processed-rag-data/

What this does:
  1. LOAD     - Read prepared .md files and .meta.json sidecars
  2. CHUNK    - Split documents into semantic chunks (512 tokens max)
  3. EMBED    - Generate 768-dim vectors via Ollama nomic-embed-text
  4. STORE    - Upsert chunks into ChromaDB collection
  5. ARCHIVE  - Move processed files to 04-processed-rag-data/

Usage:
  cd rag-pipeline/03-ingest-rag-data
  python ingest_data.py

Requirements:
  - Ollama running with nomic-embed-text model
  - ChromaDB (local or Kubernetes service)

Author: Jimmie Coleman
Date: 2025-12-05
"""

import os
import json
import shutil
import hashlib
import requests
import chromadb
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

# Directories (relative to this script)
SCRIPT_DIR = Path(__file__).parent
PIPELINE_ROOT = SCRIPT_DIR.parent
PREPARED_DIR = PIPELINE_ROOT / "02-prepared-rag-data"
ARCHIVE_DIR = PIPELINE_ROOT / "04-processed-rag-data"

# ChromaDB settings
CHROMA_DIR = Path(os.getenv("CHROMA_DIR", str(PIPELINE_ROOT.parent / "data" / "chroma")))
CHROMA_URL = os.getenv("CHROMA_URL", None)  # http://chroma:8000 for K8s
COLLECTION_NAME = "portfolio_knowledge"

# Ollama settings
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
EMBED_MODEL = os.getenv("EMBED_MODEL", "nomic-embed-text")
EMBED_DIMS = 768  # nomic-embed-text output dimensions

# Chunking settings
CHUNK_SIZE = 512  # tokens (approx 4 chars per token)
CHUNK_OVERLAP = 50  # tokens of overlap between chunks


def print_header(title: str):
    """Print formatted header"""
    print(f"\n{'='*70}")
    print(f"  {title}")
    print(f"{'='*70}\n")


def print_stage(stage_num: int, stage_name: str):
    """Print stage indicator"""
    print(f"\n{'─'*70}")
    print(f"  STAGE {stage_num}: {stage_name}")
    print(f"{'─'*70}\n")


# =============================================================================
# CHROMADB CONNECTION
# =============================================================================

def get_chroma_client():
    """Get ChromaDB client (HTTP for K8s, Persistent for local)"""
    if CHROMA_URL:
        # Parse HTTP URL for Kubernetes deployment
        import re
        match = re.match(r'http://([^:]+):(\d+)', CHROMA_URL)
        if match:
            host, port = match.groups()
            print(f"  Connecting to ChromaDB server at {CHROMA_URL}")
            return chromadb.HttpClient(host=host, port=int(port))
        else:
            raise ValueError(f"Invalid CHROMA_URL format: {CHROMA_URL}")
    else:
        # Local PersistentClient
        CHROMA_DIR.mkdir(parents=True, exist_ok=True)
        print(f"  Using local ChromaDB at {CHROMA_DIR}")
        return chromadb.PersistentClient(path=str(CHROMA_DIR))


# =============================================================================
# STAGE 1: LOAD - Read prepared files
# =============================================================================

def load_prepared_files() -> List[Dict[str, Any]]:
    """Load all prepared .md files and their metadata sidecars"""
    documents = []

    # Find all .md files (excluding this script and meta files)
    md_files = [f for f in PREPARED_DIR.glob("*.md") if not f.name.startswith('.')]

    for md_path in sorted(md_files):
        meta_path = PREPARED_DIR / f"{md_path.stem}.meta.json"

        # Read content
        with open(md_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Read metadata if exists
        metadata = {}
        if meta_path.exists():
            with open(meta_path, 'r', encoding='utf-8') as f:
                metadata = json.load(f)

        documents.append({
            'path': md_path,
            'meta_path': meta_path if meta_path.exists() else None,
            'content': content,
            'metadata': metadata,
            'filename': md_path.name
        })

    return documents


# =============================================================================
# STAGE 2: CHUNK - Split into semantic chunks
# =============================================================================

def chunk_document(content: str, metadata: Dict[str, Any], filename: str) -> List[Dict[str, Any]]:
    """
    Split document into semantic chunks for better retrieval.

    Strategy:
    - Split on double newlines (paragraphs) first
    - Keep headers with their content
    - Respect max chunk size
    - Add overlap for context continuity
    """
    chunks = []

    # Split into paragraphs/sections
    sections = content.split('\n\n')

    current_chunk = ""
    current_header = ""
    chunk_index = 0

    for section in sections:
        section = section.strip()
        if not section:
            continue

        # Track headers for context
        if section.startswith('#'):
            current_header = section.split('\n')[0]

        # Check if adding this section exceeds chunk size
        potential_chunk = current_chunk + '\n\n' + section if current_chunk else section

        # Approximate token count (4 chars per token)
        token_estimate = len(potential_chunk) // 4

        if token_estimate > CHUNK_SIZE and current_chunk:
            # Save current chunk
            chunk_id = generate_chunk_id(filename, chunk_index)
            chunks.append({
                'id': chunk_id,
                'text': current_chunk.strip(),
                'metadata': {
                    **metadata,
                    'chunk_index': chunk_index,
                    'header': current_header,
                    'source': filename
                }
            })
            chunk_index += 1

            # Start new chunk with overlap (keep last paragraph)
            overlap_text = current_chunk.split('\n\n')[-1] if '\n\n' in current_chunk else ""
            current_chunk = overlap_text + '\n\n' + section if overlap_text else section
        else:
            current_chunk = potential_chunk

    # Don't forget the last chunk
    if current_chunk.strip():
        chunk_id = generate_chunk_id(filename, chunk_index)
        chunks.append({
            'id': chunk_id,
            'text': current_chunk.strip(),
            'metadata': {
                **metadata,
                'chunk_index': chunk_index,
                'header': current_header,
                'source': filename
            }
        })

    return chunks


def generate_chunk_id(filename: str, chunk_index: int) -> str:
    """Generate deterministic chunk ID"""
    raw = f"{filename}::chunk_{chunk_index}"
    return hashlib.sha256(raw.encode()).hexdigest()[:16]


# =============================================================================
# STAGE 3: EMBED - Generate vectors via Ollama
# =============================================================================

def check_ollama_ready() -> bool:
    """Check if Ollama is running and model is available"""
    try:
        response = requests.get(f"{OLLAMA_URL}/api/tags", timeout=5)
        if response.status_code == 200:
            models = response.json().get('models', [])
            model_names = [m.get('name', '').split(':')[0] for m in models]
            if EMBED_MODEL in model_names or any(EMBED_MODEL in n for n in model_names):
                return True
            print(f"  !! Model {EMBED_MODEL} not found. Available: {model_names}")
            print(f"     Run: ollama pull {EMBED_MODEL}")
            return False
        return False
    except Exception as e:
        print(f"  !! Ollama not reachable at {OLLAMA_URL}: {e}")
        return False


def get_embedding(text: str) -> Optional[List[float]]:
    """Get embedding from Ollama"""
    try:
        response = requests.post(
            f"{OLLAMA_URL}/api/embeddings",
            json={"model": EMBED_MODEL, "prompt": text},
            timeout=60
        )
        response.raise_for_status()
        embedding = response.json().get("embedding")
        if embedding and len(embedding) == EMBED_DIMS:
            return embedding
        else:
            print(f"  !! Unexpected embedding dimension: {len(embedding) if embedding else 0}")
            return None
    except Exception as e:
        print(f"  !! Embedding failed: {e}")
        return None


def embed_chunks(chunks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Generate embeddings for all chunks"""
    embedded = []

    for i, chunk in enumerate(chunks):
        print(f"     Embedding chunk {i+1}/{len(chunks)}...", end='\r')

        embedding = get_embedding(chunk['text'])
        if embedding:
            chunk['embedding'] = embedding
            embedded.append(chunk)
        else:
            print(f"  !! Skipping chunk {chunk['id']} - embedding failed")

    print(f"     Embedded {len(embedded)}/{len(chunks)} chunks" + " " * 20)
    return embedded


# =============================================================================
# STAGE 4: STORE - Upsert to ChromaDB
# =============================================================================

def store_chunks(client, chunks: List[Dict[str, Any]]) -> int:
    """Store embedded chunks in ChromaDB"""
    if not chunks:
        return 0

    collection = client.get_or_create_collection(COLLECTION_NAME)

    # Prepare batch data
    ids = [c['id'] for c in chunks]
    embeddings = [c['embedding'] for c in chunks]
    documents = [c['text'] for c in chunks]
    metadatas = []

    for c in chunks:
        # Flatten metadata for ChromaDB (no nested dicts)
        meta = {
            'source': c['metadata'].get('source', ''),
            'title': c['metadata'].get('title', ''),
            'chunk_index': c['metadata'].get('chunk_index', 0),
            'header': c['metadata'].get('header', ''),
            'ingested_at': datetime.now().isoformat()
        }
        metadatas.append(meta)

    # Upsert (add or update)
    try:
        # Delete existing chunks from same source first
        sources = set(c['metadata'].get('source', '') for c in chunks)
        for source in sources:
            existing = collection.get(where={"source": source})
            if existing['ids']:
                collection.delete(ids=existing['ids'])
                print(f"     Deleted {len(existing['ids'])} existing chunks from {source}")

        # Add new chunks
        collection.add(
            ids=ids,
            embeddings=embeddings,
            documents=documents,
            metadatas=metadatas
        )

        return len(chunks)
    except Exception as e:
        print(f"  !! Error storing chunks: {e}")
        return 0


# =============================================================================
# STAGE 5: ARCHIVE - Move processed files
# =============================================================================

def archive_files(documents: List[Dict[str, Any]]) -> int:
    """Move processed files to archive directory"""
    ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)

    archived = 0
    for doc in documents:
        try:
            # Move .md file
            md_dest = ARCHIVE_DIR / doc['filename']
            shutil.move(str(doc['path']), str(md_dest))

            # Move .meta.json if exists
            if doc['meta_path'] and doc['meta_path'].exists():
                meta_dest = ARCHIVE_DIR / doc['meta_path'].name
                shutil.move(str(doc['meta_path']), str(meta_dest))

            archived += 1
        except Exception as e:
            print(f"  !! Error archiving {doc['filename']}: {e}")

    return archived


# =============================================================================
# MAIN
# =============================================================================

def main():
    """Run the ingestion pipeline"""
    print_header("RAG PIPELINE: INGEST DATA")
    print("  Taking prepared ingredients from 02-prepared-rag-data/")
    print("  Chunking, embedding, and storing in ChromaDB...\n")

    # Pre-flight checks
    print_stage(0, "PRE-FLIGHT CHECKS")

    if not PREPARED_DIR.exists():
        print(f"  !! Prepared data directory not found: {PREPARED_DIR}")
        return

    print(f"  ✓ Prepared directory: {PREPARED_DIR}")
    print(f"  ✓ Archive directory: {ARCHIVE_DIR}")
    print(f"  ✓ ChromaDB: {CHROMA_URL or CHROMA_DIR}")
    print(f"  ✓ Ollama: {OLLAMA_URL}")
    print(f"  ✓ Embedding model: {EMBED_MODEL} ({EMBED_DIMS} dims)")

    if not check_ollama_ready():
        print("\n  !! Ollama not ready. Please start Ollama and pull the model.")
        return

    print(f"  ✓ Ollama ready with {EMBED_MODEL}")

    # Stage 1: Load
    print_stage(1, "LOAD - Reading prepared files")
    documents = load_prepared_files()

    if not documents:
        print("  !! No prepared files found in 02-prepared-rag-data/")
        print("     Run prepare_data.py first to prepare raw data.")
        return

    print(f"  Found {len(documents)} prepared documents:")
    for doc in documents:
        word_count = doc['metadata'].get('word_count', len(doc['content'].split()))
        print(f"     - {doc['filename']} ({word_count} words)")

    # Stage 2: Chunk
    print_stage(2, "CHUNK - Splitting into semantic chunks")
    all_chunks = []

    for doc in documents:
        chunks = chunk_document(doc['content'], doc['metadata'], doc['filename'])
        print(f"  {doc['filename']}: {len(chunks)} chunks")
        all_chunks.extend(chunks)

    print(f"\n  Total chunks: {len(all_chunks)}")

    # Stage 3: Embed
    print_stage(3, "EMBED - Generating vectors via Ollama")
    embedded_chunks = embed_chunks(all_chunks)

    if not embedded_chunks:
        print("  !! No chunks were embedded successfully")
        return

    # Stage 4: Store
    print_stage(4, "STORE - Upserting to ChromaDB")
    client = get_chroma_client()
    stored = store_chunks(client, embedded_chunks)

    collection = client.get_or_create_collection(COLLECTION_NAME)
    total_docs = collection.count()
    print(f"  Stored {stored} chunks")
    print(f"  Collection '{COLLECTION_NAME}' now has {total_docs} documents")

    # Stage 5: Archive
    print_stage(5, "ARCHIVE - Moving to 04-processed-rag-data")
    archived = archive_files(documents)
    print(f"  Archived {archived} files to {ARCHIVE_DIR}")

    # Summary
    print_header("INGESTION COMPLETE")
    print(f"  Results:")
    print(f"     Documents processed: {len(documents)}")
    print(f"     Chunks created:      {len(all_chunks)}")
    print(f"     Chunks embedded:     {len(embedded_chunks)}")
    print(f"     Chunks stored:       {stored}")
    print(f"     Files archived:      {archived}")
    print(f"\n  ChromaDB collection: {COLLECTION_NAME}")
    print(f"  Total documents in collection: {total_docs}")
    print(f"\n  Your RAG knowledge base is ready!")
    print(f"  Test it: curl -X POST http://localhost:8080/chat -d '{{\"message\": \"your question\"}}'")


if __name__ == "__main__":
    main()
