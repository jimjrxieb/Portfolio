#!/usr/bin/env python3
"""
Test RAG Ingestion - Can we ingest and query actual knowledge?
"""

import chromadb
import os
from sentence_transformers import SentenceTransformer
from pathlib import Path

def test_rag_ingestion():
    print("Testing RAG Ingestion with Real Data...\n")

    # Initialize
    client = chromadb.Client()
    model = SentenceTransformer('all-MiniLM-L6-v2')

    # Get or create collection
    try:
        client.delete_collection("jimmie_knowledge")
    except:
        pass
    collection = client.create_collection("jimmie_knowledge")

    # Load knowledge files
    knowledge_dir = Path("/home/jimmie/linkops-industries/Portfolio/data/knowledge/jimmie")
    files = list(knowledge_dir.glob("*.md"))[:5]  # Start with 5 files

    print(f"Found {len(files)} knowledge files to ingest:\n")

    documents = []
    embeddings = []
    ids = []
    metadata = []

    for file_path in files:
        print(f"  📄 {file_path.name}")
        with open(file_path, 'r') as f:
            content = f.read()
            # Split into chunks (simple approach - 500 char chunks)
            chunks = [content[i:i+500] for i in range(0, len(content), 400)]

            for i, chunk in enumerate(chunks[:3]):  # Max 3 chunks per file for testing
                documents.append(chunk)
                embeddings.append(model.encode(chunk).tolist())
                ids.append(f"{file_path.stem}_chunk_{i}")
                metadata.append({"source": file_path.name, "chunk": i})

    print(f"\n💾 Adding {len(documents)} document chunks to ChromaDB...")
    collection.add(
        documents=documents,
        embeddings=embeddings,
        ids=ids,
        metadatas=metadata
    )
    print("✓ Documents added successfully")

    # Test queries
    test_queries = [
        "What is Jimmie's experience with AI and ML?",
        "Tell me about DevOps work",
        "What projects has Jimmie worked on?",
        "What is AfterLife AI?"
    ]

    print("\n🔍 Testing queries:\n")
    for query in test_queries:
        print(f"Query: {query}")
        query_embedding = model.encode(query)
        results = collection.query(
            query_embeddings=[query_embedding.tolist()],
            n_results=2
        )

        if results['documents'][0]:
            print(f"✓ Found {len(results['documents'][0])} results")
            print(f"  Best match: {results['documents'][0][0][:100]}...")
            print(f"  Source: {results['metadatas'][0][0]['source']}\n")
        else:
            print("✗ No results found\n")

    # Check collection stats
    print(f"\n📊 Collection Stats:")
    print(f"  Total documents: {collection.count()}")

    return True

if __name__ == "__main__":
    test_rag_ingestion()