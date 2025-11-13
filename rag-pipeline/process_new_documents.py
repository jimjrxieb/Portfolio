#!/usr/bin/env python3
"""
NEW DOCUMENTS PROCESSING PIPELINE
===================================
Process new documents from new-rag-data/ and add to ChromaDB.
Moves processed files to processed-rag-data/ when done.

Supported formats: .md, .jsonl, .txt

Flow:
1. Find new files in new-rag-data/
2. Sanitize content (remove junk, fix encoding)
3. Chunk text (1000 words, 200 overlap)
4. Generate embeddings (Ollama nomic-embed-text)
5. Store in existing ChromaDB collection
6. Move processed files to processed-rag-data/

Author: Jimmie Coleman
Date: 2025-11-12
"""

import os
import json
import hashlib
import shutil
from pathlib import Path
from typing import List, Dict, Optional
from datetime import datetime

import chromadb
import requests


# ============================================================================
# CONFIGURATION
# ============================================================================

CONFIG = {
    # Directories
    "new_docs_dir": "./new-rag-data",
    "processed_dir": "./processed-rag-data",
    "chroma_dir": "../data/chroma",

    # Ollama settings
    "ollama_url": "http://localhost:11434",
    "embedding_model": "nomic-embed-text",

    # ChromaDB collection
    "collection_name": "portfolio_knowledge",

    # Chunking settings
    "chunk_size": 1000,      # words per chunk
    "chunk_overlap": 200,    # word overlap between chunks

    # Processing settings
    "min_content_length": 100,  # minimum chars to process
}


# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

def check_ollama() -> bool:
    """Verify Ollama is running and model is available"""
    try:
        response = requests.get(f"{CONFIG['ollama_url']}/api/tags", timeout=5)
        response.raise_for_status()
        models = response.json().get('models', [])
        model_names = [m['name'].split(':')[0] for m in models]

        if CONFIG['embedding_model'] not in model_names:
            print(f"❌ Model '{CONFIG['embedding_model']}' not found")
            print(f"💡 Run: ollama pull {CONFIG['embedding_model']}")
            return False

        return True

    except requests.RequestException as e:
        print(f"❌ Ollama not running: {e}")
        print(f"💡 Start Ollama first")
        return False


def check_chromadb() -> Optional[chromadb.Collection]:
    """Verify ChromaDB exists and collection is accessible"""
    try:
        chroma_dir = Path(CONFIG['chroma_dir'])

        if not chroma_dir.exists():
            print(f"❌ ChromaDB directory not found: {chroma_dir}")
            print(f"💡 Run ingest_clean.py first to create initial database")
            return None

        client = chromadb.PersistentClient(path=str(chroma_dir))

        try:
            collection = client.get_collection(CONFIG['collection_name'])
            doc_count = collection.count()
            print(f"✅ Found ChromaDB collection with {doc_count} documents")
            return collection

        except Exception as e:
            print(f"❌ Collection '{CONFIG['collection_name']}' not found: {e}")
            print(f"💡 Run ingest_clean.py first to create collection")
            return None

    except Exception as e:
        print(f"❌ ChromaDB error: {e}")
        return None


# ============================================================================
# TEXT PROCESSING FUNCTIONS
# ============================================================================

def sanitize_text(text: str) -> str:
    """
    Clean and sanitize text content

    Steps:
    - Remove null bytes and control characters
    - Fix encoding issues
    - Normalize whitespace
    - Remove excessive blank lines

    Args:
        text: Raw text content

    Returns:
        Cleaned text
    """
    # Remove null bytes and control characters (keep newlines and tabs)
    text = ''.join(char for char in text if ord(char) >= 32 or char in '\n\t')

    # Fix encoding issues (replace invalid UTF-8)
    text = text.encode('utf-8', errors='ignore').decode('utf-8')

    # Remove excessive blank lines (max 2)
    while '\n\n\n' in text:
        text = text.replace('\n\n\n', '\n\n')

    # Remove leading/trailing whitespace
    text = text.strip()

    return text


def chunk_text(text: str, chunk_size: int, overlap: int) -> List[str]:
    """
    Split text into overlapping chunks by word count

    Args:
        text: Text to chunk
        chunk_size: Words per chunk
        overlap: Overlapping words between chunks

    Returns:
        List of text chunks
    """
    words = text.split()

    # If text is short, return as single chunk
    if len(words) <= chunk_size:
        return [text]

    chunks = []
    start = 0

    while start < len(words):
        # Get chunk
        end = start + chunk_size
        chunk_words = words[start:end]
        chunks.append(' '.join(chunk_words))

        # Move start position (with overlap)
        start += chunk_size - overlap

        # Stop if we're at the end
        if end >= len(words):
            break

    return chunks


def get_embedding(text: str) -> List[float]:
    """
    Get embedding vector from Ollama

    Args:
        text: Text to embed

    Returns:
        768-dimensional embedding vector

    Raises:
        RuntimeError: If embedding generation fails
    """
    response = requests.post(
        f"{CONFIG['ollama_url']}/api/embeddings",
        json={
            "model": CONFIG['embedding_model'],
            "prompt": text
        },
        timeout=30
    )
    response.raise_for_status()
    return response.json()["embedding"]


def generate_doc_id(filename: str, chunk_index: int) -> str:
    """
    Generate unique document ID

    Args:
        filename: Source filename
        chunk_index: Chunk number

    Returns:
        SHA256 hash as hex string
    """
    content = f"{filename}_{chunk_index}_{CONFIG['embedding_model']}_{datetime.now().isoformat()}"
    return hashlib.sha256(content.encode()).hexdigest()


# ============================================================================
# FILE PROCESSING FUNCTIONS
# ============================================================================

def process_markdown(filepath: Path) -> List[Dict]:
    """
    Process markdown file

    Args:
        filepath: Path to .md file

    Returns:
        List of document dicts (id, text, embedding, metadata)
    """
    print(f"   📝 Reading markdown...")

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Sanitize
    clean_content = sanitize_text(content)

    if len(clean_content) < CONFIG['min_content_length']:
        print(f"   ⚠️  Too short ({len(clean_content)} chars), skipping")
        return []

    # Chunk
    chunks = chunk_text(
        clean_content,
        CONFIG['chunk_size'],
        CONFIG['chunk_overlap']
    )
    print(f"   ✂️  Split into {len(chunks)} chunks")

    # Process chunks
    return process_chunks(filepath, chunks, "markdown")


def process_text(filepath: Path) -> List[Dict]:
    """
    Process plain text file

    Args:
        filepath: Path to .txt file

    Returns:
        List of document dicts
    """
    print(f"   📄 Reading text file...")

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Sanitize
    clean_content = sanitize_text(content)

    if len(clean_content) < CONFIG['min_content_length']:
        print(f"   ⚠️  Too short ({len(clean_content)} chars), skipping")
        return []

    # Chunk
    chunks = chunk_text(
        clean_content,
        CONFIG['chunk_size'],
        CONFIG['chunk_overlap']
    )
    print(f"   ✂️  Split into {len(chunks)} chunks")

    # Process chunks
    return process_chunks(filepath, chunks, "text")


def process_jsonl(filepath: Path) -> List[Dict]:
    """
    Process JSONL file (one JSON object per line)

    Expects each line to have a 'text', 'content', or 'document' field.
    Additional fields are stored as metadata.

    Args:
        filepath: Path to .jsonl file

    Returns:
        List of document dicts
    """
    print(f"   📋 Reading JSONL...")

    documents = []
    line_count = 0
    skipped = 0

    with open(filepath, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            line_count += 1

            try:
                data = json.loads(line.strip())

                # Extract text content (flexible field names)
                text = data.get('text') or data.get('content') or data.get('document')

                if not text:
                    print(f"   ⚠️  Line {line_num}: No text field found")
                    skipped += 1
                    continue

                # Sanitize
                clean_text = sanitize_text(text)

                if len(clean_text) < CONFIG['min_content_length']:
                    skipped += 1
                    continue

                # Chunk (JSONL entries are usually pre-chunked, but we'll chunk if large)
                chunks = chunk_text(
                    clean_text,
                    CONFIG['chunk_size'],
                    CONFIG['chunk_overlap']
                )

                # Generate embedding for each chunk
                for chunk_idx, chunk in enumerate(chunks):
                    try:
                        embedding = get_embedding(chunk)

                        # Extract metadata (everything except text fields)
                        metadata = {
                            "source": filepath.name,
                            "line_number": line_num,
                            "chunk_index": chunk_idx,
                            "total_chunks": len(chunks),
                            "file_type": "jsonl",
                            "ingested_at": datetime.now().isoformat(),
                            "model": CONFIG['embedding_model']
                        }

                        # Add custom fields from JSON
                        for key, value in data.items():
                            if key not in ['text', 'content', 'document']:
                                metadata[f"custom_{key}"] = str(value)

                        doc = {
                            "id": generate_doc_id(f"{filepath.name}_L{line_num}", chunk_idx),
                            "text": chunk,
                            "embedding": embedding,
                            "metadata": metadata
                        }
                        documents.append(doc)

                    except Exception as e:
                        print(f"   ❌ Line {line_num}, chunk {chunk_idx}: {e}")
                        continue

            except json.JSONDecodeError:
                print(f"   ⚠️  Line {line_num}: Invalid JSON")
                skipped += 1
                continue

    print(f"   ✂️  Processed {line_count} lines ({skipped} skipped)")
    print(f"   ✅ Extracted {len(documents)} document chunks")

    return documents


def process_chunks(filepath: Path, chunks: List[str], file_type: str) -> List[Dict]:
    """
    Generate embeddings and metadata for text chunks

    Args:
        filepath: Source file path
        chunks: List of text chunks
        file_type: Type of source file (markdown, text, etc)

    Returns:
        List of document dicts
    """
    documents = []

    for i, chunk in enumerate(chunks):
        print(f"   🔮 Chunk {i+1}/{len(chunks)}: generating embedding...", end='', flush=True)

        try:
            # Generate embedding
            embedding = get_embedding(chunk)

            # Create document
            doc = {
                "id": generate_doc_id(filepath.name, i),
                "text": chunk,
                "embedding": embedding,
                "metadata": {
                    "source": filepath.name,
                    "chunk_index": i,
                    "total_chunks": len(chunks),
                    "word_count": len(chunk.split()),
                    "file_type": file_type,
                    "ingested_at": datetime.now().isoformat(),
                    "model": CONFIG['embedding_model']
                }
            }
            documents.append(doc)
            print(" ✅")

        except Exception as e:
            print(f" ❌ {e}")
            continue

    return documents


# ============================================================================
# CHROMADB STORAGE
# ============================================================================

def store_in_chromadb(documents: List[Dict], collection: chromadb.Collection) -> bool:
    """
    Store documents in ChromaDB collection

    Args:
        documents: List of processed documents
        collection: ChromaDB collection object

    Returns:
        True if successful, False otherwise
    """
    if not documents:
        return False

    print(f"\n💾 Storing {len(documents)} documents in ChromaDB...")

    # Prepare data
    ids = [doc["id"] for doc in documents]
    embeddings = [doc["embedding"] for doc in documents]
    texts = [doc["text"] for doc in documents]
    metadatas = [doc["metadata"] for doc in documents]

    try:
        collection.add(
            ids=ids,
            embeddings=embeddings,
            documents=texts,
            metadatas=metadatas
        )
        print(f"   ✅ Stored successfully")
        return True

    except Exception as e:
        print(f"   ❌ Storage failed: {e}")
        return False


# ============================================================================
# FILE MANAGEMENT
# ============================================================================

def move_to_processed(filepath: Path) -> bool:
    """
    Move processed file to processed-rag-data/ directory

    Args:
        filepath: Path to file to move

    Returns:
        True if successful, False otherwise
    """
    try:
        processed_dir = Path(CONFIG['processed_dir'])
        processed_dir.mkdir(parents=True, exist_ok=True)

        dest_path = processed_dir / filepath.name

        # If destination exists, add timestamp to filename
        if dest_path.exists():
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            stem = dest_path.stem
            suffix = dest_path.suffix
            dest_path = processed_dir / f"{stem}_{timestamp}{suffix}"

        shutil.move(str(filepath), str(dest_path))
        print(f"   ✅ Moved to: {dest_path.name}")
        return True

    except Exception as e:
        print(f"   ❌ Move failed: {e}")
        return False


# ============================================================================
# MAIN PIPELINE
# ============================================================================

def process_file(filepath: Path, collection: chromadb.Collection) -> bool:
    """
    Process a single file through the pipeline

    Args:
        filepath: Path to file
        collection: ChromaDB collection

    Returns:
        True if successful, False otherwise
    """
    print(f"\n{'='*70}")
    print(f"📁 Processing: {filepath.name}")
    print(f"{'='*70}")

    # Route to appropriate processor
    documents = []

    if filepath.suffix == '.md':
        documents = process_markdown(filepath)
    elif filepath.suffix == '.txt':
        documents = process_text(filepath)
    elif filepath.suffix == '.jsonl':
        documents = process_jsonl(filepath)
    else:
        print(f"   ⚠️  Unsupported file type: {filepath.suffix}")
        return False

    # Store in ChromaDB
    if documents:
        if store_in_chromadb(documents, collection):
            # Move to processed directory
            return move_to_processed(filepath)
    else:
        print(f"   ⚠️  No documents extracted, file not moved")

    return False


def main():
    """Main pipeline execution"""
    print("\n" + "="*70)
    print("🚀 NEW DOCUMENTS PROCESSING PIPELINE")
    print("="*70)

    # Show configuration
    print("\n📋 Configuration:")
    print(f"   New docs: {CONFIG['new_docs_dir']}")
    print(f"   Processed: {CONFIG['processed_dir']}")
    print(f"   ChromaDB: {CONFIG['chroma_dir']}")
    print(f"   Embedding model: {CONFIG['embedding_model']}")
    print(f"   Chunk size: {CONFIG['chunk_size']} words")
    print(f"   Overlap: {CONFIG['chunk_overlap']} words")

    # Verify prerequisites
    print("\n🔍 Checking prerequisites...")

    if not check_ollama():
        print("\n❌ Ollama check failed. Exiting.")
        return

    collection = check_chromadb()
    if not collection:
        print("\n❌ ChromaDB check failed. Exiting.")
        return

    # Find new files
    new_docs_dir = Path(CONFIG['new_docs_dir'])

    if not new_docs_dir.exists():
        print(f"\n❌ Directory not found: {new_docs_dir}")
        return

    # Find all supported files
    md_files = list(new_docs_dir.glob("*.md"))
    txt_files = list(new_docs_dir.glob("*.txt"))
    jsonl_files = list(new_docs_dir.glob("*.jsonl"))
    all_files = md_files + txt_files + jsonl_files

    print(f"\n📂 Found {len(all_files)} files:")
    print(f"   - Markdown: {len(md_files)}")
    print(f"   - Text: {len(txt_files)}")
    print(f"   - JSONL: {len(jsonl_files)}")

    if not all_files:
        print(f"\n⚠️  No new files to process in {new_docs_dir}")
        print(f"   💡 Add .md, .txt, or .jsonl files to process them")
        return

    # Process each file
    successful = 0
    failed = 0

    for filepath in all_files:
        try:
            if process_file(filepath, collection):
                successful += 1
            else:
                failed += 1
        except Exception as e:
            print(f"\n   ❌ Unexpected error: {e}")
            import traceback
            traceback.print_exc()
            failed += 1

    # Final summary
    print("\n" + "="*70)
    print("📊 PROCESSING COMPLETE")
    print("="*70)
    print(f"✅ Successful: {successful}/{len(all_files)}")
    print(f"❌ Failed: {failed}/{len(all_files)}")

    # Verify ChromaDB
    final_count = collection.count()
    print(f"\n🗄️  ChromaDB now contains: {final_count} documents")

    print("\n" + "="*70)
    print("🎉 PIPELINE COMPLETE!")
    print("="*70)

    if successful > 0:
        print(f"\n💡 Next steps:")
        print(f"   1. Deploy to Kubernetes (see QUICK-START.md)")
        print(f"   2. Test RAG chatbot at https://linksmlm.com")


# ============================================================================
# RUN
# ============================================================================

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Interrupted by user")
    except Exception as e:
        print(f"\n\n❌ Fatal error: {e}")
        import traceback
        traceback.print_exc()
