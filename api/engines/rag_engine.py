import os
import chromadb
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
from sentence_transformers import SentenceTransformer
import logging
import time

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
        self.namespace = os.getenv("RAG_NAMESPACE", "portfolio")

        # Initialize with current active collection
        self.active_alias = f"{self.namespace}_active"
        self.collection = self._get_active_collection()

        embed_model = os.getenv("EMBED_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
        self.embedder = SentenceTransformer(embed_model)

    def _get_active_collection(self):
        """Get the currently active collection, creating default if needed"""
        try:
            # Try to get metadata about active collection alias
            collections = self.client.list_collections()
            active_collections = [
                c for c in collections if c.name.startswith(f"{self.namespace}_v")
            ]

            if not active_collections:
                # Create first version
                collection_name = f"{self.namespace}_v1"
                logger.info(f"Creating initial RAG collection: {collection_name}")
                return self.client.get_or_create_collection(collection_name)

            # Get the latest version (highest number)
            versions = []
            for c in active_collections:
                try:
                    version = int(c.name.split("_v")[1])
                    versions.append((version, c.name))
                except (ValueError, IndexError):
                    continue

            if versions:
                latest_version = max(versions, key=lambda x: x[0])[1]
                logger.info(f"Using active RAG collection: {latest_version}")
                return self.client.get_or_create_collection(latest_version)

        except Exception as e:
            logger.warning(f"Error getting active collection: {e}")

        # Fallback to legacy collection name
        return self.client.get_or_create_collection("portfolio_knowledge")

    def create_version(self, version_id: Optional[str] = None) -> str:
        """Create a new versioned collection for atomic updates"""
        if not version_id:
            # Generate version ID from timestamp
            timestamp = int(time.time())
            version_id = f"v{timestamp}"

        collection_name = f"{self.namespace}_{version_id}"
        self.client.get_or_create_collection(collection_name)

        logger.info(f"Created new RAG version: {collection_name}")
        return collection_name

    def atomic_swap(self, new_collection_name: str) -> bool:
        """Atomically swap to new collection version"""
        try:
            # Verify new collection exists and has data
            new_collection = self.client.get_collection(new_collection_name)
            doc_count = new_collection.count()

            if doc_count == 0:
                logger.error(f"Cannot swap to empty collection: {new_collection_name}")
                return False

            # Atomic swap: update active collection reference
            old_collection_name = self.collection.name
            self.collection = new_collection

            logger.info(
                f"Atomic RAG swap: {old_collection_name} -> {new_collection_name} "
                f"({doc_count} documents)"
            )
            return True

        except Exception as e:
            logger.error(f"Failed atomic RAG swap to {new_collection_name}: {e}")
            return False

    def ingest_to_version(self, docs: List[Doc], version_collection_name: str) -> int:
        """Ingest documents to a specific version (for atomic updates)"""
        if not docs:
            return 0

        try:
            target_collection = self.client.get_collection(version_collection_name)
        except ValueError:
            logger.error(f"Version collection not found: {version_collection_name}")
            return 0

        texts = [doc.text for doc in docs]
        ids = [doc.id for doc in docs]
        metadatas = [
            {"source": doc.source, "title": doc.title, "tags": ",".join(doc.tags)}
            for doc in docs
        ]

        embeddings = self.embedder.encode(texts, convert_to_tensor=False).tolist()

        try:
            # For versioned ingestion, we typically want clean slate
            target_collection.add(
                embeddings=embeddings, documents=texts, metadatas=metadatas, ids=ids
            )

            doc_count = target_collection.count()
            logger.info(
                f"Ingested {len(docs)} documents to version {version_collection_name} "
                f"(total: {doc_count})"
            )
            return len(docs)

        except Exception as e:
            logger.error(f"Error ingesting to version {version_collection_name}: {e}")
            return 0

    def ingest(self, docs: List[Doc]) -> int:
        """Ingest documents into the RAG system"""
        if not docs:
            return 0

        texts = [doc.text for doc in docs]
        ids = [doc.id for doc in docs]
        metadatas = [
            {"source": doc.source, "title": doc.title, "tags": ",".join(doc.tags)}
            for doc in docs
        ]

        embeddings = self.embedder.encode(texts, convert_to_tensor=False).tolist()

        try:
            # Delete existing docs with same IDs first
            existing_ids = [item["id"] for item in self.collection.get(ids=ids)["ids"]]
            if existing_ids:
                self.collection.delete(ids=existing_ids)

            self.collection.add(
                embeddings=embeddings, documents=texts, metadatas=metadatas, ids=ids
            )
            logger.info(f"Ingested {len(docs)} documents")
            return len(docs)
        except Exception as e:
            logger.error(f"Error ingesting documents: {e}")
            return 0

    def search(self, query: str, n_results: int = 5) -> List[Dict[str, Any]]:
        """Search for relevant documents"""
        try:
            query_embedding = self.embedder.encode(
                [query], convert_to_tensor=False
            ).tolist()[0]
            results = self.collection.query(
                query_embeddings=[query_embedding], n_results=n_results
            )

            contexts = []
            for i in range(len(results["documents"][0])):
                contexts.append(
                    {
                        "text": results["documents"][0][i],
                        "metadata": results["metadatas"][0][i],
                        "score": (
                            results["distances"][0][i] if results["distances"] else 0
                        ),
                    }
                )
            return contexts
        except Exception as e:
            logger.error(f"Error searching documents: {e}")
            return []


def format_prompt(question: str, contexts: List[Dict]) -> str:
    """Format the prompt for Jimmie Coleman persona"""
    SYSTEM = (
        "You are the Jimmie Coleman avatar. Be concise, friendly, and practical. "
        "Use the provided context chunks as primary ground truth. "
        "PRIORITIZE CURRENT FACTS over legacy content. "
        "If unsure, say what you'd try next."
    )

    joined = "\n\n---\n\n".join([c["text"] for c in contexts])
    return f"""{SYSTEM}

[Context]
{joined}

[User question]
{question}

[Instructions]
- CURRENT FOCUS: Prioritize current work (RAG, LangGraph, RPA, MCP, \
Jade @ ZRS) over historical projects
- DEVOPS: Lead with GitHub Actions + Azure Pipelines; mention Jenkins \
as legacy/learning experience only
- AI/ML: Emphasize production RAG systems, HuggingFace ecosystem, \
enterprise automation
- TOOLS: Current stack - GitHub Actions, Azure DevOps, Kubernetes, \
HuggingFace, LangGraph, MCP
- MODEL: This runs Qwen2.5-1.5B-Instruct (HuggingFace) + ChromaDB RAG \
for resource efficiency
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
