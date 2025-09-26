#!/bin/bash
# RAG Pipeline Processing Script - LangChain Style
# Similar to your Gradio.launch() approach

cd "$(dirname "$0")"

echo "🚀 RAG Pipeline - Processing New Data"
echo "Similar to your familiar LangChain workflow"
echo ""

# Check if ChromaDB is running
if ! curl -s http://localhost:8001/api/v1/heartbeat > /dev/null 2>&1; then
    echo "❌ ChromaDB not running on port 8001"
    echo "Please ensure ChromaDB service is started"
    exit 1
fi

# Set environment
export DATA_DIR=../data
export CHROMA_URL=http://localhost:8001

if [ "$1" = "watch" ]; then
    # Continuous monitoring mode (like Gradio with blocking=True)
    echo "📡 Starting watch mode - monitoring new-rag-data directory..."
    echo "Press Ctrl+C to stop"
    echo ""
    python3 batch_pipeline.py watch "${2:-30}"
else
    # Single batch processing (like running a notebook cell)
    echo "🔄 Processing files in new-rag-data directory..."
    echo ""
    python3 batch_pipeline.py
fi