# data-dev:api-rag  (RAG helpers)
# NOTE: keep imports local to functions so missing deps produce *clear* errors
from typing import List, Tuple

def _get_chroma(persist_dir: str):
    # Lazy import so api still boots if chromadb missing, we error only when used
    import chromadb
    client = chromadb.PersistentClient(path=persist_dir)
    # Single collection for Jimmie's knowledge
    return client.get_or_create_collection(name="jimmie")

def rag_retrieve(persist_dir: str, query: str, k: int = 4) -> List[Tuple[str, float]]:
    """
    Returns [(doc_text, distance), ...]
    """
    coll = _get_chroma(persist_dir)
    # naive embedding: rely on chroma's default (or configure an embedding_fn at ingest)
    res = coll.query(query_texts=[query], n_results=k)
    docs = res.get("documents", [[]])[0]
    dists = res.get("distances", [[]])[0] or [0.0] * len(docs)
    return list(zip(docs, dists))