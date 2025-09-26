#!/usr/bin/env python3
"""
Simple working ingestion script for Jimmie's knowledge base
No fancy structure - just make it work
"""

import chromadb
from sentence_transformers import SentenceTransformer
from pathlib import Path
import hashlib

def ingest_all_knowledge():
    print("🚀 Starting Knowledge Ingestion (Simple & Working)\n")

    # Initialize
    client = chromadb.Client()
    model = SentenceTransformer('all-MiniLM-L6-v2')

    # Reset collection
    try:
        client.delete_collection("portfolio_knowledge")
    except:
        pass
    collection = client.create_collection("portfolio_knowledge")

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

    print(f"📚 Found {len(all_files)} knowledge files\n")

    # Process each file
    total_chunks = 0
    for file_path in all_files:
        print(f"  Processing: {file_path.name}")

        with open(file_path, 'r') as f:
            content = f.read()

        # Simple chunking - 1000 chars with 200 overlap
        chunk_size = 1000
        overlap = 200
        chunks = []

        for i in range(0, len(content), chunk_size - overlap):
            chunk = content[i:i + chunk_size]
            if len(chunk) > 100:  # Skip tiny chunks
                chunks.append(chunk)

        # Add chunks to collection
        for i, chunk in enumerate(chunks):
            chunk_id = hashlib.md5(f"{file_path.name}_{i}_{chunk[:50]}".encode()).hexdigest()

            collection.add(
                documents=[chunk],
                embeddings=[model.encode(chunk).tolist()],
                ids=[chunk_id],
                metadatas=[{
                    "source": file_path.name,
                    "path": str(file_path.parent.name),
                    "chunk_index": i,
                    "total_chunks": len(chunks)
                }]
            )
            total_chunks += 1

    print(f"\n✅ Ingestion Complete!")
    print(f"  - Files processed: {len(all_files)}")
    print(f"  - Total chunks: {total_chunks}")
    print(f"  - Collection count: {collection.count()}")

    # Test it works
    print("\n🧪 Testing retrieval...")
    test_query = "What is Jimmie's experience with Kubernetes and DevOps?"
    results = collection.query(
        query_embeddings=[model.encode(test_query).tolist()],
        n_results=3
    )

    print(f"Query: '{test_query}'")
    for i, doc in enumerate(results['documents'][0]):
        meta = results['metadatas'][0][i]
        print(f"\n  Result {i+1} from {meta['source']}:")
        print(f"    {doc[:150]}...")

    return collection

if __name__ == "__main__":
    ingest_all_knowledge()