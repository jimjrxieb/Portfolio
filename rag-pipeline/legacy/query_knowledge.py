#!/usr/bin/env python3
"""
Simple query tool for the knowledge base
"""

import chromadb
from sentence_transformers import SentenceTransformer
import sys

def query_knowledge(question, n_results=5):
    # Initialize
    client = chromadb.Client()
    model = SentenceTransformer('all-MiniLM-L6-v2')

    # Get collection
    try:
        collection = client.get_collection("portfolio_knowledge")
        print(f"📚 Knowledge base has {collection.count()} chunks\n")
    except:
        print("❌ Knowledge base not found. Run ingest_knowledge.py first!")
        return

    # Query
    print(f"🔍 Query: {question}\n")
    results = collection.query(
        query_embeddings=[model.encode(question).tolist()],
        n_results=n_results
    )

    # Display results
    print("📖 Relevant Information:\n")
    seen_content = set()

    for i, doc in enumerate(results['documents'][0]):
        meta = results['metadatas'][0][i]

        # Skip duplicates
        content_hash = hash(doc[:100])
        if content_hash in seen_content:
            continue
        seen_content.add(content_hash)

        print(f"[Source: {meta['source']}]")
        print(doc[:500])
        print("\n" + "-"*80 + "\n")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        question = " ".join(sys.argv[1:])
    else:
        question = "Tell me about Jimmie's experience"

    query_knowledge(question)