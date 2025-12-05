#!/usr/bin/env python3
"""
RAG PIPELINE ORCHESTRATOR - The Assembly Line
==============================================

This script orchestrates the entire RAG data processing pipeline,
moving data through each stage like a factory assembly line.

FLOW:
  00-new-rag-data/         (Raw ingredients arrive)
         ↓
  01-preprocessing-stages/ (NPCs sanitize, validate, format)
         ↓
  02-prepared-rag-data/    (Inspection checkpoint - ready to cook)
         ↓
  [Manual inspection or auto-proceed]
         ↓
  03-ingest-rag-data/      (Vectorize & embed into ChromaDB)
         ↓
  04-processed-rag-data/   (Final resting place)

Usage:
  python run_pipeline.py prep       # Prepare data (stages 00 → 02)
  python run_pipeline.py cook       # Ingest data (stages 02 → 04)
  python run_pipeline.py full       # Full pipeline (00 → 04)
  python run_pipeline.py status     # Show pipeline status

Author: Jimmie Coleman
Date: 2025-12-04
"""

import os
import sys
import shutil
import json
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

# Pipeline directories (relative to this script's location)
PIPELINE_ROOT = Path(__file__).parent
RAW_DATA_DIR = PIPELINE_ROOT / "00-new-rag-data"
PREPROCESSING_DIR = PIPELINE_ROOT / "01-preprocessing-stages"
PREPARED_DATA_DIR = PIPELINE_ROOT / "02-prepared-rag-data"
INGEST_DIR = PIPELINE_ROOT / "03-ingest-rag-data"
PROCESSED_DATA_DIR = PIPELINE_ROOT / "04-processed-rag-data"

# Add preprocessing stages to path
sys.path.insert(0, str(PREPROCESSING_DIR))

# Supported file types
SUPPORTED_EXTENSIONS = {'.md', '.txt', '.json', '.jsonl'}


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
# STAGE 1: DISCOVER - Find raw files
# =============================================================================

def discover_raw_files() -> List[Path]:
    """Find all processable files in raw data directory"""
    if not RAW_DATA_DIR.exists():
        print(f"  ⚠️  Raw data directory not found: {RAW_DATA_DIR}")
        return []

    files = []
    for ext in SUPPORTED_EXTENSIONS:
        files.extend(RAW_DATA_DIR.glob(f"*{ext}"))

    return sorted(files)


# =============================================================================
# STAGE 2: SANITIZE - Clean and validate content
# =============================================================================

def sanitize_content(content: str) -> str:
    """
    Sanitize text content:
    - Remove null bytes and control characters
    - Fix encoding issues
    - Normalize whitespace
    - Remove excessive blank lines
    """
    # Remove null bytes and control characters (keep newlines and tabs)
    content = ''.join(char for char in content if ord(char) >= 32 or char in '\n\t')

    # Fix encoding issues
    content = content.encode('utf-8', errors='ignore').decode('utf-8')

    # Remove excessive blank lines (max 2)
    while '\n\n\n' in content:
        content = content.replace('\n\n\n', '\n\n')

    # Strip leading/trailing whitespace
    content = content.strip()

    return content


def validate_content(content: str, filepath: Path) -> Dict[str, Any]:
    """
    Validate content quality

    Returns:
        {
            'valid': bool,
            'status': 'PASS' | 'REPAIR' | 'FAIL',
            'issues': List[str],
            'word_count': int
        }
    """
    issues = []
    status = 'PASS'

    # Check minimum content length
    if len(content) < 50:
        issues.append(f"Content too short ({len(content)} chars)")
        status = 'FAIL'

    # Check for meaningful content
    word_count = len(content.split())
    if word_count < 10:
        issues.append(f"Too few words ({word_count})")
        status = 'FAIL'

    # Check for binary/garbage content
    non_printable = sum(1 for c in content if ord(c) > 127 and c not in 'äöüßéèêëàâîïôûùçñ')
    if non_printable > len(content) * 0.1:  # More than 10% non-printable
        issues.append(f"Possible binary content ({non_printable} non-printable chars)")
        status = 'FAIL'

    # Check for proper structure (markdown)
    if filepath.suffix == '.md':
        if not content.startswith('#') and '# ' not in content[:500]:
            issues.append("Markdown file missing headers")
            if status == 'PASS':
                status = 'REPAIR'  # Not fatal, but noted

    return {
        'valid': status != 'FAIL',
        'status': status,
        'issues': issues,
        'word_count': word_count
    }


# =============================================================================
# STAGE 3: FORMAT - Standardize for RAG ingestion
# =============================================================================

def format_for_rag(content: str, filepath: Path) -> Dict[str, Any]:
    """
    Format content for RAG ingestion

    Returns:
        {
            'content': str,        # Formatted content
            'metadata': dict,      # Metadata for ChromaDB
            'format': str          # Output format
        }
    """
    filename = filepath.name

    # Extract title from markdown headers or filename
    title = filename.replace('.md', '').replace('.txt', '').replace('-', ' ').replace('_', ' ').title()

    # Look for actual title in content
    lines = content.split('\n')
    for line in lines[:5]:
        if line.startswith('# '):
            title = line[2:].strip()
            break

    metadata = {
        'source': filename,
        'title': title,
        'prepared_at': datetime.now().isoformat(),
        'word_count': len(content.split()),
        'char_count': len(content),
        'original_format': filepath.suffix
    }

    return {
        'content': content,
        'metadata': metadata,
        'format': 'markdown'
    }


# =============================================================================
# PREP COMMAND: Process raw data → prepared data
# =============================================================================

def run_prep():
    """
    PREP STAGE: Process raw data through NPCs to prepared state

    00-new-rag-data → 02-prepared-rag-data
    """
    print_header("RAG PIPELINE: PREP STAGE")
    print("  Processing raw data through sanitization and formatting...\n")

    # Ensure directories exist
    PREPARED_DATA_DIR.mkdir(parents=True, exist_ok=True)

    # Stage 1: Discover
    print_stage(1, "DISCOVER - Finding raw files")
    raw_files = discover_raw_files()

    if not raw_files:
        print("  ⚠️  No files found in 00-new-rag-data/")
        print(f"     Add .md, .txt, .json, or .jsonl files to: {RAW_DATA_DIR}")
        return

    print(f"  📂 Found {len(raw_files)} files:")
    for f in raw_files:
        print(f"     - {f.name}")

    # Process each file
    stats = {'processed': 0, 'passed': 0, 'failed': 0, 'repaired': 0}

    for filepath in raw_files:
        print_stage(2, f"SANITIZE - {filepath.name}")

        try:
            # Read content
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                raw_content = f.read()

            print(f"  📄 Read {len(raw_content)} chars")

            # Sanitize
            clean_content = sanitize_content(raw_content)
            print(f"  🧹 Sanitized: {len(raw_content)} → {len(clean_content)} chars")

            # Validate
            validation = validate_content(clean_content, filepath)
            print(f"  ✓ Validation: {validation['status']} ({validation['word_count']} words)")

            if validation['issues']:
                for issue in validation['issues']:
                    print(f"     ⚠️  {issue}")

            if not validation['valid']:
                print(f"  ❌ FAILED - Skipping file")
                stats['failed'] += 1
                continue

            # Format for RAG
            print_stage(3, f"FORMAT - {filepath.name}")
            formatted = format_for_rag(clean_content, filepath)
            print(f"  📋 Title: {formatted['metadata']['title']}")
            print(f"  📊 Words: {formatted['metadata']['word_count']}")

            # Write to prepared directory
            output_path = PREPARED_DATA_DIR / filepath.name
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(formatted['content'])

            # Write metadata sidecar
            meta_path = PREPARED_DATA_DIR / f"{filepath.stem}.meta.json"
            with open(meta_path, 'w', encoding='utf-8') as f:
                json.dump(formatted['metadata'], f, indent=2)

            print(f"  ✅ Saved to: 02-prepared-rag-data/{filepath.name}")

            stats['processed'] += 1
            if validation['status'] == 'PASS':
                stats['passed'] += 1
            else:
                stats['repaired'] += 1

        except Exception as e:
            print(f"  ❌ Error processing {filepath.name}: {e}")
            stats['failed'] += 1

    # Summary
    print_header("PREP COMPLETE")
    print(f"  📊 Results:")
    print(f"     Processed: {stats['processed']}")
    print(f"     Passed:    {stats['passed']}")
    print(f"     Repaired:  {stats['repaired']}")
    print(f"     Failed:    {stats['failed']}")
    print(f"\n  📂 Prepared files are in: 02-prepared-rag-data/")
    print(f"  👀 Inspect them before running: python run_pipeline.py cook")


# =============================================================================
# COOK COMMAND: Ingest prepared data into ChromaDB
# =============================================================================

def run_cook():
    """
    COOK STAGE: Ingest prepared data into ChromaDB

    02-prepared-rag-data → ChromaDB → 04-processed-rag-data
    """
    print_header("RAG PIPELINE: COOK STAGE")
    print("  Ingesting prepared data into ChromaDB...\n")

    # Check for prepared files
    prepared_files = list(PREPARED_DATA_DIR.glob("*.md")) + list(PREPARED_DATA_DIR.glob("*.txt"))

    if not prepared_files:
        print("  ⚠️  No prepared files found in 02-prepared-rag-data/")
        print("     Run 'python run_pipeline.py prep' first")
        return

    print(f"  📂 Found {len(prepared_files)} files ready for ingestion:")
    for f in prepared_files:
        print(f"     - {f.name}")

    # Check Ollama
    print_stage(1, "CHECK PREREQUISITES")
    try:
        import requests
        response = requests.get("http://localhost:11434/api/tags", timeout=5)
        models = [m['name'].split(':')[0] for m in response.json().get('models', [])]
        print(f"  ✅ Ollama running with models: {', '.join(models)}")

        if 'nomic-embed-text' not in models:
            print("  ⚠️  nomic-embed-text not found!")
            print("     Run: ollama pull nomic-embed-text")
            return
    except Exception as e:
        print(f"  ❌ Ollama not available: {e}")
        print("     Start Ollama first: ollama serve")
        return

    # Import and run ingestion
    print_stage(2, "INGEST INTO CHROMADB")

    # Change to ingest directory and run
    original_dir = os.getcwd()
    os.chdir(INGEST_DIR)

    try:
        # Update config to use prepared data directory
        sys.path.insert(0, str(INGEST_DIR))

        # Import the clean ingestion script
        import importlib.util
        spec = importlib.util.spec_from_file_location("ingest_clean", INGEST_DIR / "ingest_clean.py")
        ingest_module = importlib.util.module_from_spec(spec)

        # Override the source directory
        ingest_module.CONFIG = {
            "source_dir": str(PREPARED_DATA_DIR),
            "chroma_dir": str(PIPELINE_ROOT.parent / "data" / "chroma"),
            "ollama_url": "http://localhost:11434",
            "embedding_model": "nomic-embed-text",
            "collection_name": "portfolio_knowledge",
            "chunk_size": 1000,
            "chunk_overlap": 200,
        }

        spec.loader.exec_module(ingest_module)
        ingest_module.main()

    except Exception as e:
        print(f"  ❌ Ingestion error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        os.chdir(original_dir)

    # Move processed files to final directory
    print_stage(3, "ARCHIVE PROCESSED FILES")

    PROCESSED_DATA_DIR.mkdir(parents=True, exist_ok=True)

    for filepath in prepared_files:
        try:
            dest = PROCESSED_DATA_DIR / filepath.name
            if dest.exists():
                # Add timestamp to avoid overwriting
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                dest = PROCESSED_DATA_DIR / f"{filepath.stem}_{timestamp}{filepath.suffix}"

            shutil.move(str(filepath), str(dest))
            print(f"  📦 Moved: {filepath.name} → 04-processed-rag-data/")

            # Also move metadata sidecar if exists
            meta_path = PREPARED_DATA_DIR / f"{filepath.stem}.meta.json"
            if meta_path.exists():
                meta_dest = PROCESSED_DATA_DIR / meta_path.name
                shutil.move(str(meta_path), str(meta_dest))

        except Exception as e:
            print(f"  ⚠️  Could not move {filepath.name}: {e}")

    print_header("COOK COMPLETE")
    print("  🍖 Data has been ingested into ChromaDB!")
    print("  📂 Processed files archived in: 04-processed-rag-data/")


# =============================================================================
# K8S COMMAND: Ingest directly to K8s ChromaDB via HTTP
# =============================================================================

def run_k8s():
    """
    K8S STAGE: Ingest from 04-processed-rag-data to K8s ChromaDB via port-forward

    Uses HTTP client to connect to K8s ChromaDB service
    """
    print_header("RAG PIPELINE: K8S INGESTION")
    print("  Ingesting data to Kubernetes ChromaDB...\n")

    import subprocess
    import time
    import signal
    import requests as req_lib

    # Check for processed files (already cooked data)
    source_files = list(PROCESSED_DATA_DIR.glob("*.md")) + list(PROCESSED_DATA_DIR.glob("*.txt"))

    if not source_files:
        print("  ⚠️  No files found in 04-processed-rag-data/")
        print("     Run 'python run_pipeline.py full' first to process data")
        return

    print(f"  📂 Found {len(source_files)} files to ingest:")
    for f in source_files[:5]:
        print(f"     - {f.name}")
    if len(source_files) > 5:
        print(f"     ... and {len(source_files) - 5} more")

    # Check Ollama
    print_stage(1, "CHECK PREREQUISITES")
    try:
        response = req_lib.get("http://localhost:11434/api/tags", timeout=5)
        models = [m['name'].split(':')[0] for m in response.json().get('models', [])]
        print(f"  ✅ Ollama running with models: {', '.join(models)}")

        if 'nomic-embed-text' not in models:
            print("  ⚠️  nomic-embed-text not found!")
            print("     Run: ollama pull nomic-embed-text")
            return
    except Exception as e:
        print(f"  ❌ Ollama not available: {e}")
        print("     Start Ollama first: ollama serve")
        return

    # Start port-forward
    print_stage(2, "CONNECT TO K8S CHROMADB")
    print("  🔗 Starting port-forward to K8s ChromaDB...")

    port_forward = None
    try:
        # Start port-forward in background
        port_forward = subprocess.Popen(
            ["kubectl", "port-forward", "svc/chromadb", "-n", "portfolio", "8200:8000"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        time.sleep(3)  # Wait for port-forward to establish

        # Check if port-forward is working
        try:
            response = req_lib.get("http://localhost:8200/api/v1/heartbeat", timeout=5)
            if response.status_code == 200:
                print("  ✅ Connected to K8s ChromaDB")
            else:
                raise Exception(f"Unexpected response: {response.status_code}")
        except Exception as e:
            print(f"  ❌ Cannot connect to K8s ChromaDB: {e}")
            print("     Make sure K8s cluster is running and chromadb pod is healthy")
            return

        # Import chromadb and create HTTP client
        print_stage(3, "INGEST TO K8S CHROMADB")
        import chromadb
        from chromadb.config import Settings

        # Connect via HTTP client
        k8s_client = chromadb.HttpClient(
            host="localhost",
            port=8200,
            settings=Settings(anonymized_telemetry=False)
        )

        # Delete old collection if exists
        try:
            k8s_client.delete_collection("portfolio_knowledge")
            print("  🗑️  Deleted old collection")
        except:
            pass

        # Create new collection
        collection = k8s_client.create_collection(
            name="portfolio_knowledge",
            metadata={
                "description": "Jimmie Coleman's portfolio knowledge base",
                "embedding_model": "nomic-embed-text",
                "created_at": datetime.now().isoformat()
            }
        )
        print(f"  ✅ Created collection: portfolio_knowledge")

        # Process and ingest each file
        total_docs = 0
        for filepath in source_files:
            print(f"\n  📄 {filepath.name}")

            try:
                # Read file
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Clean content
                content = sanitize_content(content)

                if len(content) < 100:
                    print(f"     ⚠️  Too short, skipping")
                    continue

                # Chunk the content
                words = content.split()
                chunk_size = 1000
                chunk_overlap = 200

                if len(words) <= chunk_size:
                    chunks = [content]
                else:
                    chunks = []
                    start = 0
                    while start < len(words):
                        end = start + chunk_size
                        chunk_words = words[start:end]
                        chunks.append(' '.join(chunk_words))
                        start += chunk_size - chunk_overlap
                        if end >= len(words):
                            break

                print(f"     ✂️  Split into {len(chunks)} chunks")

                # Get embeddings and add to collection
                for i, chunk in enumerate(chunks):
                    print(f"     🔮 Chunk {i+1}/{len(chunks)}...", end='', flush=True)

                    # Get embedding from Ollama
                    embed_response = req_lib.post(
                        "http://localhost:11434/api/embeddings",
                        json={"model": "nomic-embed-text", "prompt": chunk},
                        timeout=30
                    )
                    embed_response.raise_for_status()
                    embedding = embed_response.json()["embedding"]

                    # Generate doc ID
                    import hashlib
                    doc_id = hashlib.sha256(f"{filepath.name}_{i}_nomic-embed-text".encode()).hexdigest()

                    # Add to collection
                    collection.add(
                        ids=[doc_id],
                        embeddings=[embedding],
                        documents=[chunk],
                        metadatas=[{
                            "source": filepath.name,
                            "chunk_index": i,
                            "total_chunks": len(chunks),
                            "word_count": len(chunk.split()),
                            "ingested_at": datetime.now().isoformat(),
                            "model": "nomic-embed-text"
                        }]
                    )
                    print(" ✅")
                    total_docs += 1

            except Exception as e:
                print(f"     ❌ Error: {e}")
                continue

        # Summary
        print_header("K8S INGESTION COMPLETE")
        print(f"  ✅ Ingested {total_docs} documents to K8s ChromaDB")
        print(f"  ✅ Collection count: {collection.count()}")
        print(f"\n  🎉 Sheyla can now access this data!")

    except Exception as e:
        print(f"  ❌ Error: {e}")
        import traceback
        traceback.print_exc()

    finally:
        # Clean up port-forward
        if port_forward:
            port_forward.terminate()
            port_forward.wait()
            print("\n  🔌 Port-forward closed")


# =============================================================================
# STATUS COMMAND: Show pipeline status
# =============================================================================

def run_status():
    """Show current pipeline status"""
    print_header("RAG PIPELINE STATUS")

    def count_files(directory: Path) -> Dict[str, int]:
        if not directory.exists():
            return {'total': 0, 'md': 0, 'txt': 0, 'json': 0, 'jsonl': 0}

        return {
            'total': len(list(directory.glob('*.*'))),
            'md': len(list(directory.glob('*.md'))),
            'txt': len(list(directory.glob('*.txt'))),
            'json': len(list(directory.glob('*.json'))),
            'jsonl': len(list(directory.glob('*.jsonl'))),
        }

    stages = [
        ("00-new-rag-data", RAW_DATA_DIR, "📥 Raw Ingredients"),
        ("02-prepared-rag-data", PREPARED_DATA_DIR, "🍳 Ready to Cook"),
        ("04-processed-rag-data", PROCESSED_DATA_DIR, "🍖 Cooked & Served"),
    ]

    for name, path, emoji in stages:
        counts = count_files(path)
        status = "✅" if counts['total'] > 0 else "○"
        print(f"  {status} {emoji}: {name}/")
        print(f"     Files: {counts['total']} (md:{counts['md']}, txt:{counts['txt']}, json:{counts['json']})")

    # Check ChromaDB
    print(f"\n  🗄️  ChromaDB Status:")
    try:
        import chromadb
        chroma_path = PIPELINE_ROOT.parent / "data" / "chroma"
        if chroma_path.exists():
            client = chromadb.PersistentClient(path=str(chroma_path))
            collections = client.list_collections()
            for col in collections:
                print(f"     - {col.name}: {col.count()} documents")
        else:
            print("     ○ Not initialized (run cook to create)")
    except Exception as e:
        print(f"     ⚠️  Could not check: {e}")

    print(f"\n  💡 Commands:")
    print(f"     python run_pipeline.py prep   - Process raw → prepared")
    print(f"     python run_pipeline.py cook   - Ingest prepared → local ChromaDB")
    print(f"     python run_pipeline.py full   - Run entire local pipeline")
    print(f"     python run_pipeline.py k8s    - Sync to K8s ChromaDB (for Sheyla)")


# =============================================================================
# MAIN
# =============================================================================

def main():
    if len(sys.argv) < 2:
        run_status()
        return

    command = sys.argv[1].lower()

    if command == 'prep':
        run_prep()
    elif command == 'cook':
        run_cook()
    elif command == 'full':
        run_prep()
        print("\n" + "="*70)
        print("  Proceeding to COOK stage...")
        print("="*70)
        run_cook()
    elif command == 'k8s':
        run_k8s()
    elif command == 'status':
        run_status()
    else:
        print(f"Unknown command: {command}")
        print("Usage: python run_pipeline.py [prep|cook|full|k8s|status]")
        print("")
        print("Commands:")
        print("  prep   - Process raw → prepared (sanitize, format)")
        print("  cook   - Ingest prepared → local ChromaDB → processed")
        print("  full   - Run entire local pipeline (prep + cook)")
        print("  k8s    - Ingest processed data → K8s ChromaDB (for Sheyla)")
        print("  status - Show pipeline status")


if __name__ == "__main__":
    main()
