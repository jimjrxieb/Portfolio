#!/bin/bash
set -e

echo "🚀 Starting RAG Pipeline Services"

# Start Jupyter Lab in background
echo "📊 Starting Jupyter Lab on port 8888..."
jupyter lab --ip=127.0.0.1 --port=8888 --no-browser --allow-root --token="${JUPYTER_TOKEN:?Set JUPYTER_TOKEN before starting services}" &

# Wait a moment for Jupyter to start
sleep 5

# Start RAG API
echo "🔍 Starting RAG API on port 8000..."
uvicorn rag_api:app --host 127.0.0.1 --port 8000

# Keep the container running
wait
