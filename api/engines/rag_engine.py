import os
import chromadb
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
from sentence_transformers import SentenceTransformer
import logging

logger = logging.getLogger(__name__)

@dataclass
class Doc:
    id: str
    text: str
    source: str = ""
    title: str = ""
    tags: tuple = ()

class RAGEngine:
    def __init__(self):
        chroma_dir = os.getenv("CHROMA_DIR", "/app/models/chroma")
        os.makedirs(chroma_dir, exist_ok=True)
        
        self.client = chromadb.PersistentClient(path=chroma_dir)
        self.collection = self.client.get_or_create_collection("portfolio_knowledge")
        
        embed_model = os.getenv("EMBED_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
        self.embedder = SentenceTransformer(embed_model)
        
    def ingest(self, docs: List[Doc]) -> int:
        """Ingest documents into the RAG system"""
        if not docs:
            return 0
            
        texts = [doc.text for doc in docs]
        ids = [doc.id for doc in docs]
        metadatas = [{
            "source": doc.source,
            "title": doc.title,
            "tags": ",".join(doc.tags)
        } for doc in docs]
        
        embeddings = self.embedder.encode(texts, convert_to_tensor=False).tolist()
        
        try:
            # Delete existing docs with same IDs first
            existing_ids = [item["id"] for item in self.collection.get(ids=ids)["ids"]]
            if existing_ids:
                self.collection.delete(ids=existing_ids)
            
            self.collection.add(
                embeddings=embeddings,
                documents=texts,
                metadatas=metadatas,
                ids=ids
            )
            logger.info(f"Ingested {len(docs)} documents")
            return len(docs)
        except Exception as e:
            logger.error(f"Error ingesting documents: {e}")
            return 0
    
    def search(self, query: str, n_results: int = 5) -> List[Dict[str, Any]]:
        """Search for relevant documents"""
        try:
            query_embedding = self.embedder.encode([query], convert_to_tensor=False).tolist()[0]
            results = self.collection.query(
                query_embeddings=[query_embedding],
                n_results=n_results
            )
            
            contexts = []
            for i in range(len(results["documents"][0])):
                contexts.append({
                    "text": results["documents"][0][i],
                    "metadata": results["metadatas"][0][i],
                    "score": results["distances"][0][i] if results["distances"] else 0
                })
            return contexts
        except Exception as e:
            logger.error(f"Error searching documents: {e}")
            return []

def format_prompt(question: str, contexts: List[Dict]) -> str:
    """Format the prompt for interview-style responses"""
    ctx = "\n\n".join([f"[{i+1}] {c['metadata'].get('title','')} ({c['metadata'].get('source','')}):\n{c['text']}"
                       for i,c in enumerate(contexts)])
    return (
      "You are a friendly, concise interview assistant representing James.\n"
      "Use ONLY the context for facts; if unsure, say so. Prefer bullet points. Cite [1],[2] when using context.\n\n"
      f"Context:\n{ctx}\n\n"
      f"Interviewer asks: {question}\n\n"
      "Answer (brief first, then specifics):"
    )

# Global instance
_rag_engine = None

def get_rag_engine() -> RAGEngine:
    global _rag_engine
    if _rag_engine is None:
        _rag_engine = RAGEngine()
    return _rag_engine

def ingest(docs: List[Doc]) -> int:
    """Convenience function for document ingestion"""
    return get_rag_engine().ingest(docs)