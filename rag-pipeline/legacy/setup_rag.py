#!/usr/bin/env python3
"""
Setup persistent RAG system - SIMPLE AND WORKING
"""

import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer
from pathlib import Path
import hashlib
import os

# Use persistent storage
CHROMA_DIR = "/home/jimmie/linkops-industries/Portfolio/data/chroma"
os.makedirs(CHROMA_DIR, exist_ok=True)

def setup_rag():
    print("🚀 Setting up Persistent RAG System\n")

    # Use persistent ChromaDB
    client = chromadb.PersistentClient(path=CHROMA_DIR)
    model = SentenceTransformer('all-MiniLM-L6-v2')

    # Get or create collection
    try:
        collection = client.get_collection("portfolio_knowledge")
        print(f"📚 Found existing collection with {collection.count()} chunks")
        response = input("Reset and re-ingest? (y/n): ")
        if response.lower() != 'y':
            return collection
        client.delete_collection("portfolio_knowledge")
    except:
        pass

    collection = client.create_collection("portfolio_knowledge")
    print("📂 Created new collection\n")

    # Get ALL knowledge files
    knowledge_paths = [
        Path("/home/jimmie/linkops-industries/Portfolio/data/knowledge/jimmie"),
        Path("/home/jimmie/linkops-industries/Portfolio/data/rag/jimmie"),
        Path("/home/jimmie/linkops-industries/Portfolio/data/talktrack")
    ]

    all_files = []
    for path in knowledge_paths:
        if path.exists():
            all_files.extend(path.glob("*.md"))
            all_files.extend(path.glob("*.txt"))

    print(f"📚 Processing {len(all_files)} knowledge files...\n")

    # Process files
    total_chunks = 0
    for file_path in all_files:
        with open(file_path, 'r') as f:
            content = f.read()

        # Chunk it
        chunk_size = 1000
        overlap = 200
        chunks = []

        for i in range(0, len(content), chunk_size - overlap):
            chunk = content[i:i + chunk_size]
            if len(chunk) > 100:
                chunks.append(chunk)

        # Add to collection
        print(f"  📄 {file_path.name}: {len(chunks)} chunks")

        for i, chunk in enumerate(chunks):
            chunk_id = hashlib.md5(f"{file_path.name}_{i}".encode()).hexdigest()

            collection.add(
                documents=[chunk],
                embeddings=[model.encode(chunk).tolist()],
                ids=[chunk_id],
                metadatas=[{
                    "source": file_path.name,
                    "path": str(file_path.parent.name),
                    "chunk_index": i
                }]
            )
            total_chunks += 1

    print(f"\n✅ Setup Complete!")
    print(f"  - Files: {len(all_files)}")
    print(f"  - Chunks: {total_chunks}")
    print(f"  - Persisted to: {CHROMA_DIR}")

    return collection

def query_rag(question="Tell me about Jimmie"):
    """Simple query function"""
    client = chromadb.PersistentClient(path=CHROMA_DIR)
    model = SentenceTransformer('all-MiniLM-L6-v2')

    collection = client.get_collection("portfolio_knowledge")
    results = collection.query(
        query_embeddings=[model.encode(question).tolist()],
        n_results=3
    )

    print(f"\n🔍 Query: {question}\n")
    for i, doc in enumerate(results['documents'][0]):
        print(f"Result {i+1}: {doc[:200]}...\n")

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "query":
        query = " ".join(sys.argv[2:]) if len(sys.argv) > 2 else "Tell me about Jimmie"
        query_rag(query)
    else:
        setup_rag()
        # Test it
        query_rag("What is Jimmie's AI/ML experience?")