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
    """Format the prompt for Jimmie Coleman persona"""
    SYSTEM = (
        "You are the Jimmie Coleman avatar. Be concise, friendly, and practical. "
        "Use the provided context chunks as primary ground truth. PRIORITIZE CURRENT FACTS over legacy content. "
        "If unsure, say what you'd try next."
    )
    
    joined = "\n\n---\n\n".join([c['text'] for c in contexts])
    return f"""{SYSTEM}

[Context]
{joined}

[User question]
{question}

[Instructions]
- CURRENT FOCUS: Prioritize current work (RAG, LangGraph, RPA, MCP, Jade @ ZRS) over historical projects
- DEVOPS: Lead with GitHub Actions + Azure Pipelines; mention Jenkins as legacy/learning experience only
- AI/ML: Emphasize production RAG systems, HuggingFace ecosystem, enterprise automation
- TOOLS: Current stack - GitHub Actions, Azure DevOps, Kubernetes, HuggingFace, LangGraph, MCP
- MODEL: This runs Qwen2.5-1.5B-Instruct (HuggingFace) + ChromaDB RAG for resource efficiency
- If repo access questions: explain clone vs fork and PR etiquette
- Keep answers focused and practical unless asked for detail
"""

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