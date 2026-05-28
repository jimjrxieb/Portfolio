#!/usr/bin/env python3
"""
Wipe the portfolio_knowledge ChromaDB collection so the pipeline does a clean reingest.

Usage:
  python reset_collection.py                     # local PersistentClient (data/chroma/)
  CHROMA_URL=http://localhost:8001 python reset_collection.py   # remote HTTP client
"""

import os
import sys
import chromadb
from pathlib import Path

COLLECTION_NAME = "portfolio_knowledge"
PIPELINE_ROOT = Path(__file__).parent
CHROMA_DIR = Path(os.getenv("CHROMA_DIR", str(PIPELINE_ROOT.parent / "data" / "chroma")))
CHROMA_URL = os.getenv("CHROMA_URL", None)


def get_client():
    if CHROMA_URL:
        print(f"  Connecting to remote ChromaDB: {CHROMA_URL}")
        return chromadb.HttpClient(host=CHROMA_URL.split("://")[1].split(":")[0],
                                   port=int(CHROMA_URL.split(":")[-1]))
    print(f"  Using local ChromaDB: {CHROMA_DIR}")
    return chromadb.PersistentClient(path=str(CHROMA_DIR))


def main():
    print(f"\n  Wiping collection: {COLLECTION_NAME}")
    client = get_client()

    existing = [c.name for c in client.list_collections()]
    if COLLECTION_NAME not in existing:
        print(f"  Collection '{COLLECTION_NAME}' does not exist — nothing to wipe.")
        sys.exit(0)

    col = client.get_collection(COLLECTION_NAME)
    count = col.count()
    print(f"  Current document count: {count}")

    client.delete_collection(COLLECTION_NAME)
    print(f"  Deleted. Collection will be recreated empty on next ingest run.")


if __name__ == "__main__":
    main()
