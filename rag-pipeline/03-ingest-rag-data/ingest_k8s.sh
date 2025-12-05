#!/bin/bash
# =============================================================================
# INGEST TO K8S CHROMADB
# =============================================================================
#
# Same as ingest_data.py but targets the Kubernetes ChromaDB pod instead of
# local SQLite. Use this after running prepare_data.py to sync to production.
#
# Usage:
#   cd rag-pipeline/03-ingest-rag-data
#   ./ingest_k8s.sh
#
# Prerequisites:
#   - kubectl configured for your cluster
#   - ChromaDB pod running in portfolio namespace
#   - Ollama running locally with nomic-embed-text
#
# Author: Jimmie Coleman
# Date: 2025-12-05
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="portfolio"
CHROMA_SERVICE="chroma"
LOCAL_PORT="8100"
REMOTE_PORT="8000"

echo ""
echo "========================================================================"
echo "  INGEST TO K8S CHROMADB"
echo "========================================================================"
echo ""
echo "  This syncs your local RAG data to the Kubernetes ChromaDB pod."
echo "  Stages 1-3 (prepare) are the same - only the target changes."
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "  !! kubectl not found. Please install kubectl."
    exit 1
fi

# Check if ChromaDB pod is running
echo "  Checking K8s ChromaDB pod..."
if ! kubectl get pods -n "$NAMESPACE" -l app=chroma --no-headers 2>/dev/null | grep -q Running; then
    echo "  !! ChromaDB pod not running in namespace '$NAMESPACE'"
    echo "     Run: kubectl get pods -n $NAMESPACE"
    exit 1
fi
echo "  ✓ ChromaDB pod is running"

# Check if port is already in use
if lsof -i :"$LOCAL_PORT" &>/dev/null; then
    echo "  !! Port $LOCAL_PORT is already in use"
    echo "     Kill existing process or change LOCAL_PORT in this script"
    exit 1
fi

# Start port-forward in background
echo ""
echo "  Starting port-forward to K8s ChromaDB..."
kubectl port-forward svc/"$CHROMA_SERVICE" -n "$NAMESPACE" "$LOCAL_PORT":"$REMOTE_PORT" &>/dev/null &
PF_PID=$!

# Give it a moment to establish
sleep 3

# Verify port-forward is working
if ! kill -0 $PF_PID 2>/dev/null; then
    echo "  !! Port-forward failed to start"
    exit 1
fi
echo "  ✓ Port-forward established (localhost:$LOCAL_PORT → $CHROMA_SERVICE:$REMOTE_PORT)"

# Cleanup function
cleanup() {
    echo ""
    echo "  Cleaning up port-forward..."
    kill $PF_PID 2>/dev/null || true
    echo "  ✓ Done"
}
trap cleanup EXIT

# Run ingestion with K8s ChromaDB URL
echo ""
echo "  Running ingest_data.py against K8s ChromaDB..."
echo ""

cd "$SCRIPT_DIR"
CHROMA_URL="http://localhost:$LOCAL_PORT" python ingest_data.py

echo ""
echo "========================================================================"
echo "  K8S SYNC COMPLETE"
echo "========================================================================"
echo ""
echo "  Your production ChromaDB is now synced!"
echo "  Test it: https://linksmlm.com"
echo ""
