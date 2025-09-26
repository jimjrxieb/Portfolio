#!/bin/bash
set -e

echo "🚀 Starting RAG Pipeline Services"

# Start Jupyter Lab in background
echo "📊 Starting Jupyter Lab on port 8888..."
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --token=portfolio-rag-2025 &

# Wait a moment for Jupyter to start
sleep 5

# Start RAG API
echo "🔍 Starting RAG API on port 8000..."
uvicorn rag_api:app --host 0.0.0.0 --port 8000

# Keep the container running
wait