#!/usr/bin/env python3
"""
Batch RAG Pipeline - LangChain Style
Monitors new-rag-data/, processes files, and moves to proceed-rag-data/
Similar workflow to your familiar LangChain approach
"""

import os
import shutil
import glob
import time
from pathlib import Path
from datetime import datetime
import logging
from typing import List, Dict

# LangChain-style imports (but using our existing engine)
from ingestion_engine import get_ingestion_engine
from sentence_transformers import SentenceTransformer
import chromadb

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class BatchRAGPipeline:
    """LangChain-style batch processing pipeline"""

    def __init__(self):
        # Directory setup (similar to your LangChain approach)
        self.base_dir = Path(__file__).parent
        self.new_data_dir = self.base_dir / "new-rag-data"
        self.processed_dir = self.base_dir / "proceed-rag-data"

        # Ensure directories exist
        self.new_data_dir.mkdir(exist_ok=True)
        self.processed_dir.mkdir(exist_ok=True)

        # Initialize our existing ingestion engine
        self.ingestion_engine = get_ingestion_engine()

        # LangChain-style configuration
        self.chunk_size = 1000
        self.chunk_overlap = 200
        self.supported_extensions = ['.md', '.txt', '.pdf']

        logger.info("Batch RAG Pipeline initialized")
        logger.info(f"Monitoring: {self.new_data_dir}")
        logger.info(f"Processed files moved to: {self.processed_dir}")

    def scan_for_new_files(self) -> List[Path]:
        """Scan new-rag-data directory for files to process"""
        new_files = []

        # Check for supported file types (similar to your glob approach)
        for extension in self.supported_extensions:
            pattern = f"**/*{extension}"
            files = list(self.new_data_dir.glob(pattern))
            new_files.extend(files)

        return sorted(new_files)

    def process_document(self, file_path: Path) -> Dict:
        """Process a single document (similar to your LangChain loader approach)"""
        try:
            logger.info(f"Processing: {file_path.name}")

            # Read document content
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Create metadata (similar to your doc_type approach)
            metadata = {
                "filename": file_path.name,
                "doc_type": "batch_processed",
                "processed_date": datetime.now().isoformat(),
                "source_dir": "new-rag-data"
            }

            # Process using our existing ingestion engine
            result = self.ingestion_engine.process_input(
                content=content,
                source=file_path.name,
                content_type="knowledge",
                metadata=metadata
            )

            return {
                "file": file_path.name,
                "status": "success",
                "decision": result.decision,
                "reason": result.reason,
                "chunks": len(result.chunks) if result.chunks else 0
            }

        except Exception as e:
            logger.error(f"Failed to process {file_path.name}: {e}")
            return {
                "file": file_path.name,
                "status": "error",
                "error": str(e)
            }

    def move_processed_file(self, file_path: Path):
        """Move processed file to proceed-rag-data directory"""
        try:
            # Create timestamp subdirectory
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            target_dir = self.processed_dir / timestamp
            target_dir.mkdir(exist_ok=True)

            # Move file
            target_path = target_dir / file_path.name
            shutil.move(str(file_path), str(target_path))
            logger.info(f"Moved {file_path.name} -> {target_path}")

        except Exception as e:
            logger.error(f"Failed to move {file_path.name}: {e}")

    def run_batch_processing(self) -> Dict:
        """Run one batch processing cycle"""
        start_time = time.time()

        # Scan for new files
        new_files = self.scan_for_new_files()

        if not new_files:
            logger.info("No new files found")
            return {"status": "no_files", "processed": 0}

        logger.info(f"Found {len(new_files)} files to process")

        # Process each file
        results = []
        successful_files = []

        for file_path in new_files:
            result = self.process_document(file_path)
            results.append(result)

            if result["status"] == "success":
                successful_files.append(file_path)

        # Move successfully processed files
        for file_path in successful_files:
            self.move_processed_file(file_path)

        # Summary (similar to your result counting)
        successful = len(successful_files)
        errors = len(new_files) - successful
        processing_time = time.time() - start_time

        # Get vectorstore status (like your vectorstore._collection.count())
        status = self.ingestion_engine.get_status()
        total_docs = status.get('documents_embedded', 0)

        summary = {
            "status": "completed",
            "processed": successful,
            "errors": errors,
            "total_files": len(new_files),
            "processing_time": f"{processing_time:.2f}s",
            "total_vectorstore_docs": total_docs,
            "results": results
        }

        logger.info(f"""
Batch Processing Complete:
- Processed: {successful} files
- Errors: {errors} files
- Total time: {processing_time:.2f}s
- ChromaDB total docs: {total_docs}
        """)

        return summary

    def watch_mode(self, interval: int = 30):
        """Watch mode - continuously monitor for new files"""
        logger.info(f"Starting watch mode (checking every {interval}s)")
        logger.info("Press Ctrl+C to stop")

        try:
            while True:
                self.run_batch_processing()
                time.sleep(interval)

        except KeyboardInterrupt:
            logger.info("Watch mode stopped by user")

# Main execution functions (similar to your notebook cells)

def run_once():
    """Run batch processing once - similar to running a notebook cell"""
    pipeline = BatchRAGPipeline()
    return pipeline.run_batch_processing()

def start_watching(interval: int = 30):
    """Start continuous monitoring - similar to your Gradio launch"""
    pipeline = BatchRAGPipeline()
    pipeline.watch_mode(interval)

if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "watch":
        # Continuous monitoring mode
        interval = int(sys.argv[2]) if len(sys.argv) > 2 else 30
        start_watching(interval)
    else:
        # Single batch processing
        logger.info("🚀 Starting batch RAG processing...")
        result = run_once()
        logger.info("✅ Batch processing complete!")
        print("\nResults:", result)