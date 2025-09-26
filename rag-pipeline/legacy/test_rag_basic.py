#!/usr/bin/env python3
"""
Basic RAG System Test - Can we even ingest and query?
"""

import chromadb
import os
from sentence_transformers import SentenceTransformer

def test_basic_rag():
    print("Testing Basic RAG Functionality...")

    # 1. Can we connect to ChromaDB?
    try:
        client = chromadb.Client()
        print("✓ ChromaDB client created")
    except Exception as e:
        print(f"✗ Failed to create ChromaDB client: {e}")
        return False

    # 2. Can we create a collection?
    try:
        collection = client.create_collection(name="test_collection")
        print("✓ Collection created")
    except:
        collection = client.get_collection(name="test_collection")
        print("✓ Collection retrieved")

    # 3. Can we create embeddings?
    try:
        model = SentenceTransformer('all-MiniLM-L6-v2')
        test_text = "Jimmie is a DevOps engineer with AI/ML experience"
        embedding = model.encode(test_text)
        print(f"✓ Embedding created (dimension: {len(embedding)})")
    except Exception as e:
        print(f"✗ Failed to create embedding: {e}")
        return False

    # 4. Can we add documents?
    try:
        collection.add(
            documents=[test_text],
            ids=["test_doc_1"],
            embeddings=[embedding.tolist()]
        )
        print("✓ Document added to collection")
    except Exception as e:
        print(f"✗ Failed to add document: {e}")
        return False

    # 5. Can we query?
    try:
        query = "Tell me about Jimmie's experience"
        query_embedding = model.encode(query)
        results = collection.query(
            query_embeddings=[query_embedding.tolist()],
            n_results=1
        )
        print(f"✓ Query successful: {results['documents'][0][0][:50]}...")
    except Exception as e:
        print(f"✗ Failed to query: {e}")
        return False

    print("\n✅ Basic RAG functionality works!")

    # 6. Test with actual knowledge file
    knowledge_path = "/home/jimmie/linkops-industries/Portfolio/data/knowledge/jimmie/jimmie_overview.txt"
    if os.path.exists(knowledge_path):
        print(f"\n📂 Found knowledge file: {knowledge_path}")
        with open(knowledge_path, 'r') as f:
            content = f.read()[:200]
            print(f"Content preview: {content}...")
    else:
        print(f"\n⚠️  Knowledge file not found at {knowledge_path}")

    return True

if __name__ == "__main__":
    test_basic_rag()