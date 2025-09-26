#!/usr/bin/env python3
"""
Simple script to run RAG pipeline ingestion
Processes all knowledge files in data/knowledge/
"""

import os
import sys
from pathlib import Path
from ingestion_engine import get_ingestion_engine
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def ingest_knowledge_files():
    """Ingest all markdown files from data/knowledge/"""
    try:
        # Initialize ingestion engine
        engine = get_ingestion_engine()
        logger.info("Initialized ingestion engine")

        # Get knowledge directory
        data_dir = Path(os.getenv("DATA_DIR", "../data"))
        knowledge_dir = data_dir / "knowledge"

        if not knowledge_dir.exists():
            logger.error(f"Knowledge directory not found: {knowledge_dir}")
            return

        # Find all markdown files
        md_files = list(knowledge_dir.glob("*.md"))
        logger.info(f"Found {len(md_files)} markdown files to process")

        # Process each file
        results = []
        for md_file in md_files:
            logger.info(f"Processing: {md_file.name}")

            try:
                # Read file content
                with open(md_file, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Process content
                result = engine.process_input(
                    content=content,
                    source=md_file.name,
                    content_type="knowledge",
                    metadata={
                        "file_path": str(md_file),
                        "category": "jimmie_portfolio"
                    }
                )

                results.append(result)
                logger.info(f"✅ {md_file.name}: {result.decision} - {result.reason}")

            except Exception as e:
                logger.error(f"❌ Failed to process {md_file.name}: {e}")

        # Summary
        embedded_count = sum(1 for r in results if r.decision == "embed")
        document_count = sum(1 for r in results if r.decision == "document")
        error_count = sum(1 for r in results if r.decision == "error")

        logger.info(f"""
Pipeline Results:
- Embedded: {embedded_count} files
- Stored as documents: {document_count} files
- Errors: {error_count} files
- Total processed: {len(results)} files
        """)

        # Get final status
        status = engine.get_status()
        logger.info(f"ChromaDB now contains {status.get('documents_embedded', 0)} embedded documents")

    except Exception as e:
        logger.error(f"Pipeline failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    logger.info("🚀 Starting RAG pipeline ingestion...")
    ingest_knowledge_files()
    logger.info("✅ Pipeline ingestion complete!")