#!/usr/bin/env python3
"""
INGEST DATA SCRIPT (Stage 2)
============================

Reads pre-chunked data from prepared_*.jsonl files and embeds into ChromaDB.
After successful ingestion, moves processed files to 04-processed-rag-data/.

FLOW:
  02-prepared-rag-data/prepared_*.jsonl  -->  [embed]  -->  data/chroma/
                                         -->  [move]   -->  04-processed-rag-data/

What this does:
  1. LOAD     - Find and read prepared_*.jsonl files (pre-chunked, deduplicated)
  2. EMBED    - Generate 768-dim vectors via Ollama nomic-embed-text
  3. STORE    - Upsert chunks into ChromaDB collection
  4. MOVE     - Move processed JSONL to 04-processed-rag-data/

Note: Chunking is already done by prepare_data.py. This script only embeds.

Usage:
  cd rag-pipeline/03-ingest-rag-data
  python ingest_data.py                    # Ingest all prepared_*.jsonl files
  python ingest_data.py --file prepared_20260107_123456.jsonl  # Specific file
  python ingest_data.py --batch-size 50    # Custom batch size
  python ingest_data.py --dry-run          # Preview without storing
  python ingest_data.py --stats            # Show collection stats

Environment Variables:
  CHROMA_URL    - ChromaDB server URL (e.g., http://chroma:8000)
  CHROMA_DIR    - Local ChromaDB path (default: ../data/chroma)
  OLLAMA_URL    - Ollama API URL (default: http://localhost:11434)
  EMBED_MODEL   - Embedding model (default: nomic-embed-text)

Requirements:
  - Ollama running with nomic-embed-text model
  - ChromaDB (local or Kubernetes service)
  - prepared_*.jsonl file(s) from prepare_data.py

Author: Jimmie Coleman
Date: 2026-01-05 (Rewritten for JSONL input)
Updated: 2026-01-07 (Multi-file support, auto-move to processed)
"""

import os
import sys
import json
import argparse
import requests
import chromadb
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

# =============================================================================
# CONFIGURATION
# =============================================================================

# Directories
SCRIPT_DIR = Path(__file__).parent
PIPELINE_ROOT = SCRIPT_DIR.parent
PREPARED_DIR = PIPELINE_ROOT / "02-prepared-rag-data"
PROCESSED_DIR = PIPELINE_ROOT / "04-processed-rag-data"
MANIFEST_FILE = PREPARED_DIR / "chunk_manifest.json"

# ChromaDB settings
CHROMA_DIR = Path(os.getenv("CHROMA_DIR", str(PIPELINE_ROOT.parent / "data" / "chroma")))
CHROMA_URL = os.getenv("CHROMA_URL", None)  # http://chroma:8000 for K8s
COLLECTION_NAME = "portfolio_knowledge"

# Ollama settings
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
EMBED_MODEL = os.getenv("EMBED_MODEL", "nomic-embed-text")
EMBED_DIMS = 768  # nomic-embed-text output dimensions

# Batching
DEFAULT_BATCH_SIZE = 25


def print_header(title: str):
    """Print formatted header"""
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}\n")


def print_stage(stage_num: int, stage_name: str):
    """Print stage indicator"""
    print(f"\n{'-' * 60}")
    print(f"  STAGE {stage_num}: {stage_name}")
    print(f"{'-' * 60}\n")


# =============================================================================
# CHROMADB CONNECTION
# =============================================================================

def get_chroma_client():
    """Get ChromaDB client (HTTP for K8s, Persistent for local)"""
    if CHROMA_URL:
        import re
        match = re.match(r'http://([^:]+):(\d+)', CHROMA_URL)
        if match:
            host, port = match.groups()
            print(f"  Connecting to ChromaDB server at {CHROMA_URL}")
            return chromadb.HttpClient(host=host, port=int(port))
        else:
            raise ValueError(f"Invalid CHROMA_URL format: {CHROMA_URL}")
    else:
        CHROMA_DIR.mkdir(parents=True, exist_ok=True)
        print(f"  Using local ChromaDB at {CHROMA_DIR}")
        return chromadb.PersistentClient(path=str(CHROMA_DIR))


# =============================================================================
# STAGE 1: LOAD - Read prepared chunks from JSONL
# =============================================================================

def find_prepared_files() -> List[Path]:
    """Find all prepared_*.jsonl files in the prepared directory"""
    if not PREPARED_DIR.exists():
        return []
    return sorted(PREPARED_DIR.glob("prepared_*.jsonl"))


def load_prepared_chunks(chunks_file: Path) -> List[Dict[str, Any]]:
    """Load pre-chunked data from a prepared JSONL file"""
    if not chunks_file.exists():
        print(f"  Error: {chunks_file} not found")
        return []

    chunks = []
    with open(chunks_file, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                chunk = json.loads(line)
                # Validate required fields (chunk_id from prepare_data.py)
                if 'chunk_id' in chunk and 'content' in chunk:
                    # Normalize field names for consistency
                    chunk['id'] = chunk.get('chunk_id')
                    chunk['source'] = chunk.get('source_file', '')
                    chunks.append(chunk)
                else:
                    print(f"  Warning: Line {line_num} missing required fields (chunk_id, content)")
            except json.JSONDecodeError as e:
                print(f"  Warning: Line {line_num} is not valid JSON: {e}")

    return chunks


def move_to_processed(filepath: Path) -> bool:
    """Move a file to the processed directory"""
    try:
        PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
        dest = PROCESSED_DIR / filepath.name
        # If file exists, add timestamp to avoid overwriting
        if dest.exists():
            from datetime import datetime
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            stem = filepath.stem
            suffix = filepath.suffix
            dest = PROCESSED_DIR / f"{stem}_{timestamp}{suffix}"
        filepath.rename(dest)
        return True
    except Exception as e:
        print(f"  Error moving {filepath.name}: {e}")
        return False


def load_manifest() -> Optional[Dict[str, Any]]:
    """Load chunk manifest for stats"""
    if not MANIFEST_FILE.exists():
        return None
    try:
        with open(MANIFEST_FILE, 'r') as f:
            return json.load(f)
    except Exception:
        return None


# =============================================================================
# STAGE 2: EMBED - Generate vectors via Ollama
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
            print(f"  Model {EMBED_MODEL} not found. Available: {model_names}")
            print(f"  Run: ollama pull {EMBED_MODEL}")
            return False
        return False
    except Exception as e:
        print(f"  Ollama not reachable at {OLLAMA_URL}: {e}")
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
            print(f"  Unexpected embedding dimension: {len(embedding) if embedding else 0}")
            return None
    except Exception as e:
        print(f"  Embedding failed: {e}")
        return None


def embed_chunks(chunks: List[Dict[str, Any]], batch_size: int = DEFAULT_BATCH_SIZE) -> List[Dict[str, Any]]:
    """Generate embeddings for all chunks with progress"""
    embedded = []
    total = len(chunks)

    for i, chunk in enumerate(chunks):
        # Progress indicator
        pct = int((i / total) * 100) if total > 0 else 0
        print(f"  Embedding chunk {i+1}/{total} ({pct}%)...", end='\r')

        embedding = get_embedding(chunk['content'])
        if embedding:
            chunk['embedding'] = embedding
            embedded.append(chunk)
        else:
            print(f"\n  Skipping chunk {chunk['id'][:8]}... - embedding failed")

    print(f"  Embedded {len(embedded)}/{total} chunks successfully" + " " * 20)
    return embedded


# =============================================================================
# STAGE 3: STORE - Upsert to ChromaDB
# =============================================================================

def store_chunks(client, chunks: List[Dict[str, Any]], batch_size: int = DEFAULT_BATCH_SIZE) -> int:
    """Store embedded chunks in ChromaDB with batching"""
    if not chunks:
        return 0

    collection = client.get_or_create_collection(
        name=COLLECTION_NAME,
        metadata={"description": "Portfolio knowledge base for RAG"}
    )

    stored = 0
    total_batches = (len(chunks) + batch_size - 1) // batch_size

    for batch_num in range(total_batches):
        start = batch_num * batch_size
        end = min(start + batch_size, len(chunks))
        batch = chunks[start:end]

        # Prepare batch data
        ids = [c['id'] for c in batch]
        embeddings = [c['embedding'] for c in batch]
        documents = [c['content'] for c in batch]
        metadatas = []

        for c in batch:
            # Flatten metadata for ChromaDB (no nested dicts)
            meta = {
                'source': c.get('source', c.get('source_file', '')),
                'chunk_index': c.get('chunk_index', 0),
                'token_count': c.get('token_count', 0),
                'char_count': c.get('char_count', len(c.get('content', ''))),
                'total_chunks': c.get('total_chunks', 0),
                'ingested_at': datetime.now().isoformat()
            }
            # Add optional fields if present
            if 'source_title' in c:
                meta['title'] = c['source_title']
            if 'content_hash' in c:
                meta['content_hash'] = c['content_hash']

            metadatas.append(meta)

        try:
            # Upsert handles both add and update
            collection.upsert(
                ids=ids,
                embeddings=embeddings,
                documents=documents,
                metadatas=metadatas
            )
            stored += len(batch)
            print(f"  Batch {batch_num + 1}/{total_batches}: stored {len(batch)} chunks")
        except Exception as e:
            print(f"  Error storing batch {batch_num + 1}: {e}")

    return stored


def get_collection_stats(client) -> Dict[str, Any]:
    """Get stats about the collection"""
    try:
        collection = client.get_or_create_collection(COLLECTION_NAME)
        count = collection.count()

        # Get sample of sources
        sample = collection.peek(limit=10)
        sources = set()
        if sample and 'metadatas' in sample:
            for meta in sample['metadatas']:
                if meta and 'source' in meta:
                    sources.add(meta['source'])

        return {
            'total_documents': count,
            'sample_sources': list(sources)[:5]
        }
    except Exception as e:
        return {'error': str(e)}


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(description='Ingest prepared chunks into ChromaDB')
    parser.add_argument('--batch-size', type=int, default=DEFAULT_BATCH_SIZE,
                        help=f'Batch size for embedding/storing (default: {DEFAULT_BATCH_SIZE})')
    parser.add_argument('--dry-run', action='store_true',
                        help='Preview chunks without embedding/storing')
    parser.add_argument('--stats', action='store_true',
                        help='Show collection stats and exit')
    parser.add_argument('--file', type=str,
                        help='Specific prepared_*.jsonl file to ingest')
    args = parser.parse_args()

    print_header("RAG PIPELINE: INGEST DATA")

    # Stats only mode
    if args.stats:
        print("  Checking collection stats...")
        client = get_chroma_client()
        stats = get_collection_stats(client)
        print(f"\n  Collection: {COLLECTION_NAME}")
        print(f"  Total documents: {stats.get('total_documents', 'N/A')}")
        if stats.get('sample_sources'):
            print(f"  Sample sources: {', '.join(stats['sample_sources'])}")
        return

    # Pre-flight checks
    print_stage(0, "PRE-FLIGHT CHECKS")

    # Find prepared files
    if args.file:
        prepared_files = [Path(args.file)]
        if not prepared_files[0].exists():
            print(f"  Error: Specified file not found: {args.file}")
            sys.exit(1)
    else:
        prepared_files = find_prepared_files()

    if not prepared_files:
        print(f"  Error: No prepared_*.jsonl files found in {PREPARED_DIR}")
        print(f"  Run: python ../02-prepared-rag-data/prepare_data.py")
        sys.exit(1)

    print(f"  [OK] Found {len(prepared_files)} prepared file(s):")
    for pf in prepared_files:
        print(f"       - {pf.name}")
    print(f"  [OK] ChromaDB: {CHROMA_URL or CHROMA_DIR}")
    print(f"  [OK] Ollama: {OLLAMA_URL}")
    print(f"  [OK] Model: {EMBED_MODEL} ({EMBED_DIMS} dims)")
    print(f"  [OK] Batch size: {args.batch_size}")

    # Load manifest for stats
    manifest = load_manifest()
    if manifest:
        stats = manifest.get('stats', {})
        print(f"\n  Manifest stats:")
        print(f"     Total chunks: {stats.get('total_chunks', 'N/A')}")
        print(f"     Total tokens: {stats.get('total_tokens', 'N/A'):,}")
        print(f"     Source files: {stats.get('files_processed', 'N/A')}")

    if not args.dry_run:
        if not check_ollama_ready():
            print("\n  Error: Ollama not ready. Please start Ollama and pull the model.")
            print(f"  Run: ollama serve")
            print(f"  Run: ollama pull {EMBED_MODEL}")
            sys.exit(1)
        print(f"  [OK] Ollama ready with {EMBED_MODEL}")

    # Process each prepared file
    total_loaded = 0
    total_embedded = 0
    total_stored = 0
    files_processed = []

    for chunks_file in prepared_files:
        # Stage 1: Load
        print_stage(1, f"LOAD - Reading {chunks_file.name}")
        chunks = load_prepared_chunks(chunks_file)

        if not chunks:
            print(f"  Warning: No chunks found in {chunks_file.name}, skipping")
            continue

        print(f"  Loaded {len(chunks)} chunks from {chunks_file.name}")
        total_loaded += len(chunks)

        # Show sample
        if chunks:
            sample = chunks[0]
            print(f"\n  Sample chunk:")
            print(f"     ID: {sample.get('id', sample.get('chunk_id', 'N/A'))[:16]}...")
            print(f"     Source: {sample.get('source', sample.get('source_file', 'N/A'))}")
            print(f"     Tokens: {sample.get('token_count', 'N/A')}")
            print(f"     Chunk: {sample.get('chunk_index', 0)+1}/{sample.get('total_chunks', '?')}")
            print(f"     Content: {sample.get('content', '')[:80]}...")

        if args.dry_run:
            print(f"\n  [DRY RUN] Would embed and store {len(chunks)} chunks from {chunks_file.name}")
            continue

        # Stage 2: Embed
        print_stage(2, "EMBED - Generating vectors via Ollama")
        embedded_chunks = embed_chunks(chunks, batch_size=args.batch_size)

        if not embedded_chunks:
            print(f"  Warning: No chunks embedded from {chunks_file.name}")
            continue

        total_embedded += len(embedded_chunks)

        # Stage 3: Store
        print_stage(3, "STORE - Upserting to ChromaDB")
        client = get_chroma_client()
        stored = store_chunks(client, embedded_chunks, batch_size=args.batch_size)
        total_stored += stored

        # Track for moving
        files_processed.append(chunks_file)

    if args.dry_run:
        print_header("DRY RUN COMPLETE")
        print(f"  Would embed and store {total_loaded} chunks from {len(prepared_files)} file(s)")
        print(f"  Run without --dry-run to actually ingest")
        return

    # Stage 4: Move processed files
    if files_processed:
        print_stage(4, "MOVE - Moving prepared files to processed")
        moved_count = 0
        for pf in files_processed:
            if move_to_processed(pf):
                print(f"  Moved: {pf.name} -> 04-processed-rag-data/")
                moved_count += 1
        print(f"\n  Moved {moved_count} file(s) to 04-processed-rag-data/")

    # Final stats
    client = get_chroma_client()
    final_stats = get_collection_stats(client)

    # Summary
    print_header("INGESTION COMPLETE")
    print(f"  Results:")
    print(f"     Files processed:  {len(files_processed)}")
    print(f"     Chunks loaded:    {total_loaded}")
    print(f"     Chunks embedded:  {total_embedded}")
    print(f"     Chunks stored:    {total_stored}")
    print(f"\n  Collection: {COLLECTION_NAME}")
    print(f"  Total documents: {final_stats.get('total_documents', 'N/A')}")
    print(f"\n  Your RAG knowledge base is ready!")


if __name__ == "__main__":
    main()
