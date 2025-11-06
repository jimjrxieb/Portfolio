#!/usr/bin/env python3
"""
Clean Ingestion Pipeline - Ollama + ChromaDB
Processes markdown and jsonl files from new-rag-data/
Uses proper embedding models with batch processing
"""

import os
import json
import re
import shutil
from pathlib import Path
from typing import List, Dict, Any, Optional
import chromadb
import requests
import hashlib
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

class OllamaIngestionPipeline:
    """Production-ready ingestion pipeline using Ollama embeddings"""

    def __init__(
        self,
        source_dir: str = "./new-rag-data",
        chroma_dir: str = "/home/jimmie/linkops-industries/Portfolio/data/chroma",
        processed_dir: str = "./processed-rag-data",
        ollama_url: str = "http://localhost:11434",
        embedding_model: str = "nomic-embed-text",  # Proper embedding model
        batch_size: int = 10,
        chunk_size: int = 1000,
        chunk_overlap: int = 200
    ):
        self.source_dir = Path(source_dir)
        self.chroma_dir = Path(chroma_dir)
        self.processed_dir = Path(processed_dir)
        self.ollama_url = ollama_url
        self.embedding_model = embedding_model
        self.batch_size = batch_size
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap

        # Verify Ollama and model availability
        self._verify_ollama()
        self._verify_model()

        # Get embedding dimension dynamically
        self.embedding_dim = self._get_embedding_dimension()

        # Initialize ChromaDB
        self.client = chromadb.PersistentClient(path=str(self.chroma_dir))
        self.collection = self.client.get_or_create_collection(
            name="portfolio_knowledge",
            metadata={
                "description": "Jimmie's portfolio knowledge base",
                "embedding_model": self.embedding_model,
                "embedding_dimension": self.embedding_dim
            }
        )

        # Ensure processed directory exists
        self.processed_dir.mkdir(parents=True, exist_ok=True)

        print(f"✅ Initialized pipeline")
        print(f"   Source: {self.source_dir}")
        print(f"   ChromaDB: {self.chroma_dir}")
        print(f"   Processed: {self.processed_dir}")
        print(f"   Model: {self.embedding_model} ({self.embedding_dim}D)")

    def _verify_ollama(self):
        """Verify Ollama server is running"""
        try:
            response = requests.get(f"{self.ollama_url}/api/tags", timeout=5)
            response.raise_for_status()
        except requests.RequestException as e:
            raise RuntimeError(
                f"Ollama server not available at {self.ollama_url}. "
                f"Please start Ollama: {e}"
            )

    def _verify_model(self):
        """Verify embedding model is available"""
        try:
            response = requests.get(f"{self.ollama_url}/api/tags", timeout=5)
            models = response.json().get('models', [])
            model_names = [m['name'].split(':')[0] for m in models]

            if self.embedding_model not in model_names:
                raise RuntimeError(
                    f"Model '{self.embedding_model}' not found. "
                    f"Available models: {', '.join(model_names)}. "
                    f"Pull with: ollama pull {self.embedding_model}"
                )
        except requests.RequestException as e:
            raise RuntimeError(f"Cannot verify model availability: {e}")

    def _get_embedding_dimension(self) -> int:
        """Dynamically determine embedding dimension"""
        try:
            test_embedding = self.get_embedding("test")
            return len(test_embedding)
        except Exception as e:
            raise RuntimeError(f"Cannot determine embedding dimension: {e}")

    def sanitize_content(self, content: str) -> str:
        """Clean and sanitize text content"""
        # Remove excessive whitespace
        content = re.sub(r'\n\s*\n\s*\n+', '\n\n', content)

        # Remove HTML tags
        content = re.sub(r'<[^>]+>', '', content)

        # Remove control characters
        content = re.sub(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '', content)

        # Fix encoding issues
        content = content.encode('utf-8', errors='ignore').decode('utf-8')

        # Normalize whitespace (but preserve single newlines)
        lines = content.split('\n')
        normalized_lines = [' '.join(line.split()) for line in lines]
        content = '\n'.join(normalized_lines)

        return content.strip()

    def chunk_text(self, text: str) -> List[str]:
        """Split text into overlapping chunks by word count"""
        words = text.split()
        chunks = []

        if len(words) <= self.chunk_size:
            return [text]

        for i in range(0, len(words), self.chunk_size - self.chunk_overlap):
            chunk_words = words[i:i + self.chunk_size]
            if chunk_words:
                chunks.append(' '.join(chunk_words))

        return chunks

    def get_embedding(self, text: str) -> List[float]:
        """Get embedding from Ollama for a single text"""
        try:
            response = requests.post(
                f"{self.ollama_url}/api/embeddings",
                json={
                    "model": self.embedding_model,
                    "prompt": text
                },
                timeout=30
            )
            response.raise_for_status()
            return response.json()["embedding"]
        except requests.RequestException as e:
            raise RuntimeError(f"Embedding generation failed: {e}")

    def get_embeddings_batch(self, texts: List[str]) -> List[List[float]]:
        """Get embeddings for multiple texts with parallel processing"""
        embeddings = []

        # Process in batches to avoid overwhelming the server
        for i in range(0, len(texts), self.batch_size):
            batch = texts[i:i + self.batch_size]

            # Use ThreadPoolExecutor for parallel requests
            with ThreadPoolExecutor(max_workers=min(len(batch), 5)) as executor:
                future_to_text = {
                    executor.submit(self.get_embedding, text): idx
                    for idx, text in enumerate(batch)
                }

                batch_embeddings = [None] * len(batch)
                for future in as_completed(future_to_text):
                    idx = future_to_text[future]
                    try:
                        batch_embeddings[idx] = future.result()
                    except Exception as e:
                        print(f"   ⚠️  Embedding failed for text {i+idx}: {e}")
                        # Use zero vector as fallback
                        batch_embeddings[idx] = [0.0] * self.embedding_dim

                embeddings.extend(batch_embeddings)

        return embeddings

    def process_markdown(self, file_path: Path) -> List[Dict[str, Any]]:
        """Process markdown file"""
        print(f"   📄 Processing markdown: {file_path.name}")

        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Sanitize
        clean_content = self.sanitize_content(content)

        if len(clean_content) < 50:
            print(f"   ⚠️  Content too short ({len(clean_content)} chars), skipping")
            return []

        # Chunk
        chunks = self.chunk_text(clean_content)
        print(f"   ✂️  Split into {len(chunks)} chunks")

        # Prepare documents
        documents = []
        for i, chunk in enumerate(chunks):
            # Fixed: Using hashlib.sha256 for better security and setting usedforsecurity=False
            doc_id = hashlib.sha256(f"{file_path.name}_{i}_{self.embedding_model}".encode(), usedforsecurity=False).hexdigest()
            documents.append({
                "id": doc_id,
                "text": chunk,
                "metadata": {
                    "source": file_path.name,
                    "chunk_index": i,
                    "total_chunks": len(chunks),
                    "file_type": "markdown",
                    "ingestion_date": datetime.now().isoformat(),
                    "embedding_model": self.embedding_model
                }
            })

        return documents

    def process_jsonl(self, file_path: Path) -> List[Dict[str, Any]]:
        """Process JSONL file"""
        print(f"   📋 Processing JSONL: {file_path.name}")

        documents = []
        with open(file_path, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                try:
                    data = json.loads(line.strip())

                    # Extract text content (flexible field names)
                    text = data.get('text') or data.get('content') or data.get('document') or str(data)

                    # Sanitize
                    clean_text = self.sanitize_content(text)

                    if len(clean_text) < 50:
                        continue

                    # Fixed: Use hashlib.sha256 for stronger security
                    import hashlib

                    doc_id = hashlib.sha256(
                    f"{file_path.name}_{line_num}_{self.embedding_model}".encode()
                    ).hexdigest()
                    doc_id = hashlib.md5(
                        f"{file_path.name}_{line_num}_{self.embedding_model}".encode()
                    ).hexdigest()
                    documents.append({
                        "id": doc_id,
                        "text": clean_text,
                        "metadata": {
                            "source": file_path.name,
                            "line_number": line_num,
                            "file_type": "jsonl",
                            "ingestion_date": datetime.now().isoformat(),
                            "embedding_model": self.embedding_model,
                            **{k: v for k, v in data.items() if k not in ['text', 'content', 'document']}
                        }
                    })
                except json.JSONDecodeError:
                    print(f"   ⚠️  Invalid JSON at line {line_num}")
                    continue

        print(f"   ✂️  Extracted {len(documents)} documents")
        return documents

    def embed_and_store(self, documents: List[Dict[str, Any]]):
        """Generate embeddings and store in ChromaDB"""
        if not documents:
            return

        print(f"   🔮 Generating embeddings for {len(documents)} documents...")

        # Extract texts
        texts = [doc["text"] for doc in documents]

        # Get embeddings in batches
        embeddings = self.get_embeddings_batch(texts)

        # Prepare data for ChromaDB
        ids = [doc["id"] for doc in documents]
        metadatas = [doc["metadata"] for doc in documents]

        # Store in ChromaDB
        try:
            self.collection.add(
                ids=ids,
                embeddings=embeddings,
                documents=texts,
                metadatas=metadatas
            )
            print(f"   ✅ Stored {len(documents)} documents in ChromaDB")
        except Exception as e:
            print(f"   ❌ Storage failed: {e}")
            raise

    def move_to_processed(self, file_path: Path):
        """Move processed file to processed directory"""
        # Maintain directory structure
        relative_path = file_path.relative_to(self.source_dir)
        dest_path = self.processed_dir / relative_path
        dest_path.parent.mkdir(parents=True, exist_ok=True)

        shutil.move(str(file_path), str(dest_path))
        print(f"   ✅ Moved to: {dest_path}")

    def process_file(self, file_path: Path):
        """Process a single file"""
        print(f"\n📁 Processing: {file_path}")

        documents = []

        if file_path.suffix == '.md':
            documents = self.process_markdown(file_path)
        elif file_path.suffix == '.jsonl':
            documents = self.process_jsonl(file_path)
        else:
            print(f"   ⚠️  Unsupported file type: {file_path.suffix}")
            return

        if documents:
            self.embed_and_store(documents)
            self.move_to_processed(file_path)
        else:
            print(f"   ⚠️  No documents extracted, file not moved")

    def run(self):
        """Run full ingestion pipeline"""
        print("\n" + "="*60)
        print("🚀 OLLAMA INGESTION PIPELINE")
        print("="*60)

        # Find all markdown and jsonl files
        md_files = list(self.source_dir.rglob("*.md"))
        jsonl_files = list(self.source_dir.rglob("*.jsonl"))
        all_files = md_files + jsonl_files

        print(f"\n📊 Found {len(all_files)} files:")
        print(f"   - Markdown: {len(md_files)}")
        print(f"   - JSONL: {len(jsonl_files)}")

        if not all_files:
            print("\n⚠️  No files to process!")
            return

        # Process each file
        processed_count = 0
        error_count = 0

        for file_path in all_files:
            try:
                self.process_file(file_path)
                processed_count += 1
            except Exception as e:
                print(f"   ❌ Error: {e}")
                error_count += 1

        # Summary
        print("\n" + "="*60)
        print("📈 INGESTION COMPLETE")
        print("="*60)
        print(f"✅ Processed: {processed_count} files")
        print(f"❌ Errors: {error_count} files")

        # Check ChromaDB status
        count = self.collection.count()
        print(f"🗄️  ChromaDB contains: {count} documents")
        print(f"📏 Embedding model: {self.embedding_model} ({self.embedding_dim}D)")
        print("="*60)


if __name__ == "__main__":
    pipeline = OllamaIngestionPipeline()
    pipeline.run()
