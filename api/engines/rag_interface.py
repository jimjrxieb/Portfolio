"""
Jade-Brain RAG Interface
Handles all knowledge base queries and semantic search
"""

import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer
from typing import List, Dict, Optional
import logging
from pathlib import Path
import sys

# Add config to path
sys.path.append(str(Path(__file__).parent.parent / "config"))
from rag_config import get_rag_config

logger = logging.getLogger(__name__)

class RAGInterface:
    """Interface to the knowledge base for semantic search"""

    def __init__(self):
        self.config = get_rag_config()
        self.model = None
        self.client = None
        self.collection = None
        self._initialize()

    def _initialize(self):
        """Initialize RAG system"""
        try:
            # Initialize embedding model
            self.model = SentenceTransformer(self.config["embedding_model"])
            logger.info(f"Loaded embedding model: {self.config['embedding_model']}")

            # Initialize ChromaDB client
            self.client = chromadb.PersistentClient(path=self.config["chroma_dir"])

            # Get collection
            try:
                self.collection = self.client.get_collection(self.config["collection_name"])
                logger.info(f"Connected to collection: {self.config['collection_name']} with {self.collection.count()} documents")
            except Exception as e:
                logger.error(f"Failed to connect to collection: {e}")
                self.collection = None

        except Exception as e:
            logger.error(f"Failed to initialize RAG interface: {e}")
            raise

    def search(self, query: str, n_results: Optional[int] = None) -> List[Dict]:
        """Search knowledge base for relevant information"""
        if not self.collection:
            logger.warning("RAG collection not available")
            return []

        n_results = n_results or self.config["default_results"]
        n_results = min(n_results, self.config["max_results"])

        try:
            # Create query embedding
            query_embedding = self.model.encode(query).tolist()

            # Search collection
            results = self.collection.query(
                query_embeddings=[query_embedding],
                n_results=n_results
            )

            # Format results
            formatted_results = []
            if results["documents"][0]:
                for i, doc in enumerate(results["documents"][0]):
                    metadata = results["metadatas"][0][i] if results["metadatas"][0] else {}

                    formatted_results.append({
                        "content": doc,
                        "source": metadata.get("source", "unknown"),
                        "path": metadata.get("path", "unknown"),
                        "relevance_score": 1.0 - (results["distances"][0][i] if results["distances"][0] else 0.5)
                    })

            logger.info(f"Found {len(formatted_results)} results for query: {query[:50]}...")
            return formatted_results

        except Exception as e:
            logger.error(f"Search failed: {e}")
            return []

    def get_context(self, query: str, max_context_length: int = 2000) -> str:
        """Get formatted context for LLM from search results"""
        results = self.search(query)

        if not results:
            return "No relevant information found in knowledge base."

        context_parts = []
        current_length = 0

        for result in results:
            content = result["content"]
            source = result["source"]

            # Format with source attribution
            formatted_content = f"[Source: {source}]\n{content}\n"

            # Check if adding this would exceed limit
            if current_length + len(formatted_content) > max_context_length:
                break

            context_parts.append(formatted_content)
            current_length += len(formatted_content)

        context = "\n---\n".join(context_parts)

        if len(context) > max_context_length:
            context = context[:max_context_length] + "...\n[Context truncated]"

        return context

    def get_status(self) -> Dict:
        """Get RAG system status"""
        status = {
            "initialized": bool(self.collection),
            "embedding_model": self.config["embedding_model"],
            "collection_name": self.config["collection_name"]
        }

        if self.collection:
            try:
                status["document_count"] = self.collection.count()
                status["available"] = True
            except:
                status["document_count"] = 0
                status["available"] = False
        else:
            status["document_count"] = 0
            status["available"] = False

        return status

# Global instance
_rag_interface = None

def get_rag_interface() -> RAGInterface:
    """Get global RAG interface instance"""
    global _rag_interface
    if _rag_interface is None:
        _rag_interface = RAGInterface()
    return _rag_interface