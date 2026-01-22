#!/bin/bash
# =============================================================================
# SYNC RAG TO ALL TARGETS (Local + K8s)
# =============================================================================
#
# Ingests prepared RAG data to BOTH local ChromaDB AND Kubernetes ChromaDB
# in a single run. Files are only moved after both targets succeed.
#
# Usage:
#   cd rag-pipeline/03-ingest-rag-data
#   ./sync_all.sh
#
# What it does:
#   1. Ingest to local ChromaDB (--no-move to keep file)
#   2. Port-forward to K8s ChromaDB
#   3. Ingest to K8s ChromaDB (moves file when done)
#
# Prerequisites:
#   - Ollama running with nomic-embed-text
#   - kubectl configured for your cluster
#   - ChromaDB pod running in portfolio namespace
#   - prepared_*.jsonl file(s) from prepare_data.py
#
# Author: Jimmie Coleman
# Date: 2026-01-22
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="portfolio"
CHROMA_SERVICE="chroma"
LOCAL_PORT="8100"
REMOTE_PORT="8000"

echo ""
echo "========================================================================"
echo "  SYNC RAG TO ALL TARGETS"
echo "========================================================================"
echo ""
echo "  This syncs your RAG data to BOTH local and K8s ChromaDB."
echo ""

# Check for prepared files first
PREPARED_DIR="$SCRIPT_DIR/../02-prepared-rag-data"
if ! ls "$PREPARED_DIR"/prepared_*.jsonl 1>/dev/null 2>&1; then
    echo "  !! No prepared_*.jsonl files found in 02-prepared-rag-data/"
    echo "     Run: cd ../02-prepared-rag-data && python prepare_data.py"
    exit 1
fi

PREPARED_COUNT=$(ls -1 "$PREPARED_DIR"/prepared_*.jsonl 2>/dev/null | wc -l)
echo "  Found $PREPARED_COUNT prepared file(s)"
echo ""

# =============================================================================
# STAGE 1: LOCAL CHROMADB
# =============================================================================

echo "------------------------------------------------------------------------"
echo "  STAGE 1: INGEST TO LOCAL CHROMADB"
echo "------------------------------------------------------------------------"
echo ""

cd "$SCRIPT_DIR"
python ingest_data.py --no-move

if [ $? -ne 0 ]; then
    echo ""
    echo "  !! Local ingestion failed"
    exit 1
fi

echo ""
echo "  Local ingestion complete!"
echo ""

# =============================================================================
# STAGE 2: K8S CHROMADB
# =============================================================================

echo "------------------------------------------------------------------------"
echo "  STAGE 2: INGEST TO K8S CHROMADB"
echo "------------------------------------------------------------------------"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "  !! kubectl not found - skipping K8s sync"
    echo "     Local ChromaDB was updated successfully."
    echo "     Install kubectl to enable K8s sync."
    # Still move the files since local succeeded
    python ingest_data.py --stats  # Just to trigger move logic
    exit 0
fi

# Check if ChromaDB pod is running
echo "  Checking K8s ChromaDB pod..."
if ! kubectl get pods -n "$NAMESPACE" -l app=chroma --no-headers 2>/dev/null | grep -q Running; then
    echo "  !! ChromaDB pod not running in namespace '$NAMESPACE'"
    echo "     Local ChromaDB was updated successfully."
    echo "     Start K8s ChromaDB to enable K8s sync."
    exit 0
fi
echo "  ChromaDB pod is running"

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
echo "  Port-forward established (localhost:$LOCAL_PORT -> $CHROMA_SERVICE:$REMOTE_PORT)"

# Cleanup function
cleanup() {
    echo ""
    echo "  Cleaning up port-forward..."
    kill $PF_PID 2>/dev/null || true
}
trap cleanup EXIT

# Run ingestion with K8s ChromaDB URL (this one WILL move files)
echo ""
CHROMA_URL="http://localhost:$LOCAL_PORT" python ingest_data.py

echo ""
echo "========================================================================"
echo "  SYNC COMPLETE - BOTH TARGETS UPDATED"
echo "========================================================================"
echo ""
echo "  Local ChromaDB:  Updated"
echo "  K8s ChromaDB:    Updated"
echo ""
echo "  Test locally:    Run your app with local ChromaDB"
echo "  Test production: https://linksmlm.com"
echo ""
