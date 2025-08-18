#!/usr/bin/env python3
"""
RAG Lab: ingest docs -> verify count -> ask questions via your API.
Usage:
  API_BASE=https://your-api.example.com python rag_lab.py
"""

import os, json, glob, textwrap
import requests

API_BASE = os.environ.get("API_BASE", "http://localhost:8000")
NAMESPACE = os.environ.get("RAG_NAMESPACE", "portfolio")
DOC_DIR = os.environ.get("DOC_DIR", os.path.join("Portfolio","data","rag","jimmie"))

def ingest_docs(docs: list[dict]) -> dict:
    """Use the existing /ingest endpoint"""
    r = requests.post(f"{API_BASE}/ingest", json=docs, timeout=30)
    r.raise_for_status()
    return r.json()

def ask(question: str, k: int = 5) -> str:
    """Use the existing /chat endpoint"""
    r = requests.post(f"{API_BASE}/chat", 
                      json={"question": question, "k": k}, timeout=45)
    r.raise_for_status()
    return r.text  # Returns streaming text

def get_debug_state() -> dict:
    """Get debug state from API"""
    r = requests.get(f"{API_BASE}/api/debug/state", timeout=10)
    r.raise_for_status()
    return r.json()

def chunk_text(text: str, max_chars: int = 1200) -> list[str]:
    # naive chunker by paragraphs
    paras = [p.strip() for p in text.split("\n") if p.strip()]
    chunks, cur = [], ""
    for p in paras:
        if len(cur) + len(p) + 1 > max_chars:
            if cur: chunks.append(cur)
            cur = p
        else:
            cur = (cur + "\n" + p).strip()
    if cur: chunks.append(cur)
    return chunks

def ingest_dir(dir_path: str) -> int:
    files = sorted(glob.glob(os.path.join(dir_path, "*.md")))
    total = 0
    for idx, fp in enumerate(files, start=1):
        with open(fp, "r", encoding="utf-8") as f:
            text = f.read()
        chunks = chunk_text(text)
        docs = [{"id": f"{os.path.basename(fp)}-{i}",
                 "text": ct,
                 "source": os.path.basename(fp)}
                for i, ct in enumerate(chunks)]
        res = ingest_docs(docs)
        total += res.get("ingested", 0)
        print(f"✅ Ingested {res.get('ingested',0)} chunks from {os.path.basename(fp)}")
    return total

def main():
    print(f"API_BASE={API_BASE}")
    
    # 1) Show debug state
    try:
        debug_state = get_debug_state()
        print("🔎 DEBUG STATE:", json.dumps(debug_state, indent=2))
    except Exception as e:
        print("⚠️ Could not get debug state:", e)
        
    # 2) Show health status
    try:
        health = requests.get(f"{API_BASE}/healthz", timeout=10)
        if health.ok:
            print("🔎 Health:", health.json())
        engines = requests.get(f"{API_BASE}/engines", timeout=10)
        if engines.ok:
            print("🔧 Engines:", engines.json())
    except Exception as e:
        print("⚠️ Could not get health/engines:", e)

    # 3) Ingest docs
    print(f"📥 Ingesting docs from {DOC_DIR} ...")
    count = ingest_dir(DOC_DIR)
    print(f"📦 Total ingested: {count}")

    # 4) Ask a couple questions
    for q in [
        "Who is ZRS and what is the work order SLA?",
        "What is LinkOps Afterlife?",
    ]:
        print("\n❓", q)
        try:
            ans = ask(q, k=5)
            print("🗣️  Answer:", textwrap.shorten(ans, width=400))
        except requests.HTTPError as he:
            print("❌ Chat error:", he.response.text)
        except Exception as e:
            print("❌ Chat error:", e)

if __name__ == "__main__":
    main()
