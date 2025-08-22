#!/usr/bin/env python3
"""
Comprehensive RAG Document Ingestion Script
Loads all detailed portfolio, technical, and project documentation into ChromaDB
"""

import os
import sys
import logging
from typing import List, Dict
from pathlib import Path

# Add the API directory to Python path for imports
api_dir = Path(__file__).parent.parent.parent / "api"
sys.path.insert(0, str(api_dir))

from engines.rag_engine import RAGEngine, Doc

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class DocumentProcessor:
    """Process and chunk large documents for RAG ingestion"""
    
    def __init__(self, chunk_size: int = 2000, overlap: int = 200):
        self.chunk_size = chunk_size
        self.overlap = overlap
    
    def chunk_document(self, text: str, max_chunk_size: int = None) -> List[str]:
        """Intelligently chunk document by sections and paragraphs"""
        if max_chunk_size is None:
            max_chunk_size = self.chunk_size
        
        # Split by major sections (## headers)
        sections = text.split('\n## ')
        chunks = []
        
        for i, section in enumerate(sections):
            if i > 0:  # Add back the ## for non-first sections
                section = '## ' + section
            
            # If section is small enough, use as-is
            if len(section) <= max_chunk_size:
                if section.strip():
                    chunks.append(section.strip())
            else:
                # Split large sections by paragraphs
                paragraphs = section.split('\n\n')
                current_chunk = ""
                
                for paragraph in paragraphs:
                    # If adding this paragraph would exceed limit
                    if len(current_chunk) + len(paragraph) + 2 > max_chunk_size:
                        if current_chunk:
                            chunks.append(current_chunk.strip())
                            # Start new chunk with overlap (last paragraph)
                            current_chunk = paragraph
                        else:
                            # Single paragraph is too long, force split
                            if paragraph.strip():
                                chunks.append(paragraph.strip()[:max_chunk_size])
                    else:
                        if current_chunk:
                            current_chunk += "\n\n" + paragraph
                        else:
                            current_chunk = paragraph
                
                # Add final chunk
                if current_chunk.strip():
                    chunks.append(current_chunk.strip())
        
        return chunks

    def process_markdown_file(self, file_path: Path, source_name: str) -> List[Doc]:
        """Process a markdown file into RAG documents"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Extract title from first header
            lines = content.split('\n')
            title = "Untitled"
            for line in lines:
                if line.startswith('# '):
                    title = line[2:].strip()
                    break
            
            # Chunk the document
            chunks = self.chunk_document(content)
            
            docs = []
            for i, chunk in enumerate(chunks):
                doc_id = f"{file_path.stem}_chunk_{i:03d}"
                
                # Determine tags based on content
                tags = self._extract_tags(chunk, file_path.name)
                
                docs.append(Doc(
                    id=doc_id,
                    text=chunk,
                    source=source_name,
                    title=f"{title} (Part {i+1})" if len(chunks) > 1 else title,
                    tags=tuple(tags)
                ))
            
            logger.info(f"Processed {file_path.name}: {len(chunks)} chunks")
            return docs
            
        except Exception as e:
            logger.error(f"Error processing {file_path}: {e}")
            return []
    
    def _extract_tags(self, text: str, filename: str) -> List[str]:
        """Extract relevant tags from document content"""
        tags = []
        
        # File-based tags
        if "comprehensive-portfolio" in filename:
            tags.extend(["overview", "executive-summary", "all-projects"])
        elif "linkops-aibox" in filename:
            tags.extend(["linkops", "aibox", "technical", "architecture"])
        elif "zrs-management" in filename:
            tags.extend(["zrs", "case-study", "property-management", "roi"])
        elif "devops-expertise" in filename:
            tags.extend(["devops", "devsecops", "kubernetes", "cicd"])
        elif "ai-ml-expertise" in filename:
            tags.extend(["ai", "ml", "llm", "rag", "voice"])
        
        # Content-based tags
        text_lower = text.lower()
        
        # Technology tags
        if any(term in text_lower for term in ["kubernetes", "k8s", "kubectl"]):
            tags.append("kubernetes")
        if any(term in text_lower for term in ["docker", "container"]):
            tags.append("containers")
        if any(term in text_lower for term in ["github actions", "ci/cd", "pipeline"]):
            tags.append("cicd")
        if any(term in text_lower for term in ["terraform", "infrastructure as code"]):
            tags.append("infrastructure")
        if any(term in text_lower for term in ["phi-3", "gpt", "llm", "language model"]):
            tags.append("llm")
        if any(term in text_lower for term in ["chromadb", "vector database", "embeddings"]):
            tags.append("rag")
        if any(term in text_lower for term in ["elevenlabs", "azure speech", "tts"]):
            tags.append("voice")
        if any(term in text_lower for term in ["jade", "assistant", "zrs"]):
            tags.append("jade-assistant")
        
        # Business tags
        if any(term in text_lower for term in ["roi", "cost", "savings", "revenue"]):
            tags.append("business-impact")
        if any(term in text_lower for term in ["security", "compliance", "hipaa", "gdpr"]):
            tags.append("security")
        if any(term in text_lower for term in ["property management", "tenant", "maintenance"]):
            tags.append("property-management")
        
        return list(set(tags))  # Remove duplicates

def main():
    """Main ingestion process"""
    logger.info("Starting comprehensive RAG document ingestion")
    
    # Initialize processor and RAG engine
    processor = DocumentProcessor(chunk_size=1800, overlap=200)
    
    # Set environment for ChromaDB
    os.environ["CHROMA_DIR"] = "./data/chroma"
    os.environ["RAG_NAMESPACE"] = "portfolio"
    
    rag_engine = RAGEngine()
    
    # Document files to process
    knowledge_dir = Path(__file__).parent.parent.parent / "data" / "knowledge" / "jimmie"
    
    document_files = [
        {
            "file": "comprehensive-portfolio.md",
            "source": "Comprehensive Portfolio Overview",
            "priority": 1  # Highest priority for overview queries
        },
        {
            "file": "linkops-aibox-technical-deep-dive.md", 
            "source": "LinkOps AI-BOX Technical Documentation",
            "priority": 2
        },
        {
            "file": "zrs-management-case-study.md",
            "source": "ZRS Management Implementation Case Study", 
            "priority": 2
        },
        {
            "file": "devops-expertise-comprehensive.md",
            "source": "DevSecOps Technical Expertise",
            "priority": 3
        },
        {
            "file": "ai-ml-expertise-detailed.md",
            "source": "AI/ML Engineering Expertise",
            "priority": 3
        }
    ]
    
    # Process all documents
    all_docs = []
    
    for doc_info in document_files:
        file_path = knowledge_dir / doc_info["file"]
        
        if not file_path.exists():
            logger.warning(f"File not found: {file_path}")
            continue
        
        logger.info(f"Processing: {doc_info['file']}")
        
        docs = processor.process_markdown_file(file_path, doc_info["source"])
        
        # Add priority to metadata through tags
        for doc in docs:
            doc.tags = doc.tags + (f"priority-{doc_info['priority']}",)
        
        all_docs.extend(docs)
    
    # Create new version for atomic update
    logger.info(f"Creating new RAG version with {len(all_docs)} documents")
    version_name = rag_engine.create_version()
    
    # Ingest documents to new version
    ingested_count = rag_engine.ingest_to_version(all_docs, version_name)
    
    if ingested_count > 0:
        logger.info(f"Successfully ingested {ingested_count} documents to {version_name}")
        
        # Atomic swap to new version
        if rag_engine.atomic_swap(version_name):
            logger.info("✅ RAG pipeline updated successfully!")
            logger.info("Chat system now has access to comprehensive knowledge base")
        else:
            logger.error("❌ Failed to activate new RAG version")
    else:
        logger.error("❌ Failed to ingest documents")
    
    # Test the RAG system
    logger.info("\n🧪 Testing RAG retrieval...")
    test_queries = [
        "What is LinkOps AI-BOX?",
        "Tell me about ZRS Management implementation",
        "What DevSecOps tools does Jimmie use?",
        "How does the RAG pipeline work?",
        "What are the business results from AI-BOX?"
    ]
    
    for query in test_queries:
        results = rag_engine.search(query, n_results=3)
        logger.info(f"\nQuery: {query}")
        logger.info(f"Found {len(results)} relevant documents")
        
        if results:
            top_result = results[0]
            logger.info(f"Top result from: {top_result['metadata'].get('source', 'Unknown')}")
            logger.info(f"Score: {top_result.get('score', 'N/A')}")
            
    logger.info("\n✅ Comprehensive RAG ingestion completed!")
    logger.info("The chat system can now answer detailed questions about:")
    logger.info("  • LinkOps AI-BOX platform and architecture")
    logger.info("  • ZRS Management case study and ROI")  
    logger.info("  • DevSecOps expertise and implementations")
    logger.info("  • AI/ML engineering capabilities")
    logger.info("  • Project portfolio and technical achievements")

if __name__ == "__main__":
    main()