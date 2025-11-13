#!/usr/bin/env python3
"""
CLEAN CHROMADB INGESTION PIPELINE
==================================
Simple, understandable ingestion of markdown files into ChromaDB.

What it does:
1. Reads markdown files from processed-rag-data/
2. Splits them into chunks (1000 words, 200 word overlap)
3. Gets embeddings from Ollama (nomic-embed-text model)
4. Stores in ChromaDB with proper metadata

Author: Jimmie Coleman
Date: 2025-11-12
"""

import os
import json
import hashlib
from pathlib import Path
from typing import List, Dict
from datetime import datetime

import chromadb
import requests


# ============================================================================
# CONFIGURATION
# ============================================================================

CONFIG = {
    "source_dir": "./processed-rag-data",
    "chroma_dir": "../data/chroma",
    "ollama_url": "http://localhost:11434",
    "embedding_model": "nomic-embed-text",
    "collection_name": "portfolio_knowledge",
    "chunk_size": 1000,  # words per chunk
    "chunk_overlap": 200,  # word overlap between chunks
}


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def check_ollama():
    """Verify Ollama is running"""
    print("🔍 Checking Ollama...")
    try:
        response = requests.get(f"{CONFIG['ollama_url']}/api/tags", timeout=5)
        response.raise_for_status()
        models = response.json().get('models', [])
        model_names = [m['name'].split(':')[0] for m in models]

        print(f"   ✅ Ollama running")
        print(f"   📦 Available models: {', '.join(model_names)}")

        if CONFIG['embedding_model'] not in model_names:
            print(f"\n   ❌ Model '{CONFIG['embedding_model']}' not found!")
            print(f"   💡 Run: ollama pull {CONFIG['embedding_model']}")
            exit(1)

    except requests.RequestException as e:
        print(f"   ❌ Ollama not running: {e}")
        print(f"   💡 Start Ollama first")
        exit(1)


def clean_text(text: str) -> str:
    """
    Clean text content
    - Remove excessive whitespace
    - Fix encoding issues
    - Keep paragraphs intact
    """
    # Remove null bytes and control characters
    text = ''.join(char for char in text if ord(char) >= 32 or char in '\n\t')

    # Remove excessive blank lines (keep max 2)
    while '\n\n\n' in text:
        text = text.replace('\n\n\n', '\n\n')

    # Remove trailing/leading whitespace
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
    content = f"{filename}_{chunk_index}_{CONFIG['embedding_model']}"
    return hashlib.sha256(content.encode()).hexdigest()


# ============================================================================
# MAIN INGESTION LOGIC
# ============================================================================

def process_markdown_file(filepath: Path) -> List[Dict]:
    """
    Process single markdown file into document chunks

    Args:
        filepath: Path to markdown file

    Returns:
        List of documents (id, text, embedding, metadata)
    """
    print(f"\n📄 {filepath.name}")

    # Read file
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Clean content
    clean_content = clean_text(content)

    if len(clean_content) < 100:
        print(f"   ⚠️  Too short ({len(clean_content)} chars), skipping")
        return []

    # Split into chunks
    chunks = chunk_text(
        clean_content,
        CONFIG['chunk_size'],
        CONFIG['chunk_overlap']
    )
    print(f"   ✂️  Split into {len(chunks)} chunks")

    # Process each chunk
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


def store_in_chromadb(documents: List[Dict], collection):
    """
    Store documents in ChromaDB collection

    Args:
        documents: List of processed documents
        collection: ChromaDB collection object
    """
    if not documents:
        return

    print(f"\n💾 Storing {len(documents)} documents in ChromaDB...")

    # Prepare data for ChromaDB
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
    except Exception as e:
        print(f"   ❌ Storage failed: {e}")
        raise


def main():
    """Main ingestion pipeline"""
    print("\n" + "="*70)
    print("🚀 CHROMADB INGESTION PIPELINE")
    print("="*70)

    # Show configuration
    print("\n📋 Configuration:")
    for key, value in CONFIG.items():
        print(f"   {key}: {value}")

    # Verify Ollama
    check_ollama()

    # Initialize ChromaDB
    print(f"\n🗄️  Initializing ChromaDB...")
    chroma_dir = Path(CONFIG['chroma_dir'])
    chroma_dir.mkdir(parents=True, exist_ok=True)

    client = chromadb.PersistentClient(path=str(chroma_dir))

    # Delete old collection if exists (fresh start)
    try:
        client.delete_collection(CONFIG['collection_name'])
        print(f"   🗑️  Deleted old collection")
    except:
        pass

    # Create new collection
    collection = client.create_collection(
        name=CONFIG['collection_name'],
        metadata={
            "description": "Jimmie Coleman's portfolio knowledge base",
            "embedding_model": CONFIG['embedding_model'],
            "created_at": datetime.now().isoformat()
        }
    )
    print(f"   ✅ Created collection: {CONFIG['collection_name']}")

    # Find all markdown files
    source_dir = Path(CONFIG['source_dir'])
    md_files = sorted(source_dir.glob("*.md"))

    print(f"\n📂 Found {len(md_files)} markdown files in {source_dir}")

    if not md_files:
        print("\n⚠️  No markdown files found!")
        print(f"   💡 Check directory: {source_dir.absolute()}")
        return

    # Process each file
    total_docs = 0
    successful_files = 0

    for filepath in md_files:
        try:
            documents = process_markdown_file(filepath)
            if documents:
                store_in_chromadb(documents, collection)
                total_docs += len(documents)
                successful_files += 1
        except Exception as e:
            print(f"\n   ❌ Error processing {filepath.name}: {e}")

    # Final summary
    print("\n" + "="*70)
    print("📊 INGESTION COMPLETE")
    print("="*70)
    print(f"✅ Files processed: {successful_files}/{len(md_files)}")
    print(f"✅ Total documents: {total_docs}")
    print(f"✅ ChromaDB location: {chroma_dir.absolute()}")

    # Verify ChromaDB
    final_count = collection.count()
    print(f"\n🔍 Verification:")
    print(f"   Documents in ChromaDB: {final_count}")

    if final_count == total_docs:
        print(f"   ✅ All documents stored successfully!")
    else:
        print(f"   ⚠️  Count mismatch! Expected {total_docs}, found {final_count}")

    print("\n" + "="*70)
    print("🎉 READY TO USE!")
    print("="*70)


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
