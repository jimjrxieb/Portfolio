#!/usr/bin/env python3
"""
RAG Pipeline Ingestion Engine
Processes input data and makes intelligent storage decisions
"""

import os
import re
import hashlib
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer
import logging

logger = logging.getLogger(__name__)

@dataclass
class ProcessingResult:
    """Result of document processing"""
    decision: str  # "embed" or "document"
    storage_path: str
    chunks: Optional[List[str]] = None
    metadata: Optional[Dict] = None
    reason: str = ""

class IngestionEngine:
    """Main engine for RAG data ingestion"""

    def __init__(self):
        # Configuration
        self.data_dir = Path(os.getenv("DATA_DIR", "/home/jimmie/linkops-industries/Portfolio/data"))
        self.docs_dir = Path(os.getenv("DOCS_DIR", "/home/jimmie/linkops-industries/Portfolio/docs"))
        self.chroma_dir = self.data_dir / "chroma"

        # Processing settings
        self.chunk_size = int(os.getenv("CHUNK_SIZE", "1000"))
        self.chunk_overlap = int(os.getenv("CHUNK_OVERLAP", "200"))

        # Initialize components
        self.embedding_model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')
        self.chroma_client = chromadb.PersistentClient(path=str(self.chroma_dir))

        # Get or create collection
        try:
            self.collection = self.chroma_client.get_collection("portfolio_knowledge")
        except:
            self.collection = self.chroma_client.create_collection("portfolio_knowledge")

    def sanitize_content(self, content: str) -> str:
        """Clean and sanitize input content"""
        # Remove excessive whitespace
        content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)

        # Remove HTML tags if present
        content = re.sub(r'<[^>]+>', '', content)

        # Fix encoding issues
        content = content.encode('utf-8', errors='ignore').decode('utf-8')

        # Normalize whitespace
        content = re.sub(r'\s+', ' ', content).strip()

        return content

    def is_queryable_content(self, content: str, source: str = "") -> Tuple[bool, str]:
        """Decide if content should be embedded or stored as document"""

        # Length check
        if len(content) < 50:
            return False, "Content too short for meaningful embedding"

        # File extension check
        source_lower = source.lower()

        # Definitely embed these
        embed_extensions = ['.md', '.txt', '.pdf']
        embed_types = ['bio', 'project', 'skill', 'faq', 'knowledge', 'interview']

        if any(ext in source_lower for ext in embed_extensions):
            if any(type_name in source_lower for type_name in embed_types):
                return True, "Knowledge content suitable for embedding"

        # Definitely don't embed these
        document_extensions = ['.yaml', '.yml', '.json', '.py', '.sh', '.js', '.ts', '.css', '.html']
        if any(ext in source_lower for ext in document_extensions):
            return False, "Configuration/code file - store as document"

        # Content analysis
        question_patterns = ['?', 'what is', 'how to', 'why', 'when', 'where', 'who']
        has_questions = any(pattern in content.lower() for pattern in question_patterns)

        # Conversational patterns
        conversational_patterns = ['i am', 'my experience', 'i work', 'i specialize', 'tell me']
        is_conversational = any(pattern in content.lower() for pattern in conversational_patterns)

        # Business/personal info patterns
        info_patterns = ['experience', 'skills', 'project', 'company', 'role', 'responsibility']
        is_info = any(pattern in content.lower() for pattern in info_patterns)

        if has_questions or is_conversational or is_info:
            return True, "Content contains queryable information"

        # Default to document storage for ambiguous content
        return False, "Content appears to be reference material"

    def chunk_content(self, content: str) -> List[str]:
        """Split content into overlapping chunks"""
        if len(content) <= self.chunk_size:
            return [content]

        chunks = []
        for i in range(0, len(content), self.chunk_size - self.chunk_overlap):
            chunk = content[i:i + self.chunk_size]
            if chunk.strip():  # Don't add empty chunks
                chunks.append(chunk.strip())

        return chunks

    def embed_content(self, content: str, source: str, metadata: Dict = None) -> bool:
        """Embed content into ChromaDB"""
        try:
            # Chunk the content
            chunks = self.chunk_content(content)

            # Process each chunk
            for i, chunk in enumerate(chunks):
                # Create unique ID
                chunk_id = hashlib.md5(f"{source}_{i}_{chunk[:50]}".encode()).hexdigest()

                # Create embedding
                embedding = self.embedding_model.encode(chunk)

                # Prepare metadata
                chunk_metadata = {
                    "source": source,
                    "chunk_index": i,
                    "total_chunks": len(chunks),
                    **(metadata or {})
                }

                # Add to collection
                self.collection.add(
                    documents=[chunk],
                    embeddings=[embedding.tolist()],
                    ids=[chunk_id],
                    metadatas=[chunk_metadata]
                )

            logger.info(f"Embedded {len(chunks)} chunks from {source}")
            return True

        except Exception as e:
            logger.error(f"Failed to embed content from {source}: {e}")
            return False

    def store_document(self, content: str, source: str, content_type: str = "general") -> str:
        """Store content as regular document"""
        # Determine storage path based on type
        if content_type in ["knowledge", "bio", "project"]:
            storage_path = self.data_dir / "knowledge" / "jimmie" / source
        elif content_type in ["config", "script"]:
            storage_path = self.docs_dir / "configs" / source
        else:
            storage_path = self.docs_dir / "general" / source

        # Ensure directory exists
        storage_path.parent.mkdir(parents=True, exist_ok=True)

        # Write content
        with open(storage_path, 'w', encoding='utf-8') as f:
            f.write(content)

        logger.info(f"Stored document at {storage_path}")
        return str(storage_path)

    def process_input(self, content: str, source: str = "", content_type: str = "general", metadata: Dict = None) -> ProcessingResult:
        """Main processing function"""
        try:
            # Step 1: Sanitize content
            clean_content = self.sanitize_content(content)

            # Step 2: Make storage decision
            should_embed, reason = self.is_queryable_content(clean_content, source)

            # Step 3: Process based on decision
            if should_embed:
                # Embed into ChromaDB
                success = self.embed_content(clean_content, source, metadata)
                if success:
                    chunks = self.chunk_content(clean_content)
                    return ProcessingResult(
                        decision="embed",
                        storage_path=str(self.chroma_dir),
                        chunks=chunks,
                        metadata=metadata,
                        reason=f"Embedded: {reason}"
                    )
                else:
                    # Fallback to document storage
                    storage_path = self.store_document(clean_content, source, content_type)
                    return ProcessingResult(
                        decision="document",
                        storage_path=storage_path,
                        reason="Embedding failed, stored as document"
                    )
            else:
                # Store as regular document
                storage_path = self.store_document(clean_content, source, content_type)
                return ProcessingResult(
                    decision="document",
                    storage_path=storage_path,
                    reason=f"Document: {reason}"
                )

        except Exception as e:
            logger.error(f"Processing failed: {e}")
            return ProcessingResult(
                decision="error",
                storage_path="",
                reason=f"Error: {str(e)}"
            )

    def get_status(self) -> Dict:
        """Get ingestion engine status"""
        try:
            doc_count = self.collection.count()
            return {
                "status": "healthy",
                "documents_embedded": doc_count,
                "chroma_available": True,
                "embedding_model": "sentence-transformers/all-MiniLM-L6-v2",
                "data_dir": str(self.data_dir),
                "docs_dir": str(self.docs_dir)
            }
        except Exception as e:
            return {
                "status": "error",
                "error": str(e),
                "chroma_available": False
            }

# Global instance
_ingestion_engine = None

def get_ingestion_engine() -> IngestionEngine:
    """Get global ingestion engine instance"""
    global _ingestion_engine
    if _ingestion_engine is None:
        _ingestion_engine = IngestionEngine()
    return _ingestion_engine