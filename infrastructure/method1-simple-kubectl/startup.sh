#!/bin/bash
#
# Portfolio Startup Script
# Run this after server restart to bring everything back up
#
# Usage: ./startup.sh [--full]
#   --full: Also re-ingest RAG data to K8s ChromaDB
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORTFOLIO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "========================================"
echo "  Portfolio Startup Script"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

# ========================================
# Step 1: Check K8s is running
# ========================================
echo "Step 1: Checking Kubernetes..."
if ! kubectl cluster-info &>/dev/null; then
    error "Kubernetes not running. Start Docker Desktop first."
    exit 1
fi
success "Kubernetes is running"

# ========================================
# Step 2: Check pods are healthy
# ========================================
echo ""
echo "Step 2: Checking Portfolio pods..."

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=chroma -n portfolio --timeout=60s 2>/dev/null || {
    warn "ChromaDB pod not ready, waiting..."
    sleep 10
}
kubectl wait --for=condition=ready pod -l app=portfolio-api -n portfolio --timeout=60s 2>/dev/null || {
    warn "API pod not ready, waiting..."
    sleep 10
}

# Show pod status
echo ""
kubectl get pods -n portfolio
echo ""

# Check ChromaDB has data
CHROMA_COUNT=$(kubectl exec -n portfolio deployment/chromadb -- curl -s http://localhost:8000/api/v1/collections 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo "0")

if [ "$CHROMA_COUNT" == "0" ]; then
    warn "ChromaDB is empty! RAG data needs to be re-ingested."
    NEEDS_RAG_SYNC=true
else
    success "ChromaDB has $CHROMA_COUNT collection(s)"
    NEEDS_RAG_SYNC=false
fi

# ========================================
# Step 3: Start cloudflared tunnel
# ========================================
echo ""
echo "Step 3: Starting Cloudflare tunnel..."

if pgrep -f "cloudflared tunnel" &>/dev/null; then
    success "cloudflared already running"
else
    if [ -f ~/.cloudflared/config.yml ]; then
        nohup cloudflared tunnel --config ~/.cloudflared/config.yml run &>/dev/null &
        sleep 2
        if pgrep -f "cloudflared tunnel" &>/dev/null; then
            success "cloudflared started"
        else
            error "Failed to start cloudflared"
        fi
    else
        warn "No cloudflared config found at ~/.cloudflared/config.yml"
    fi
fi

# ========================================
# Step 4: Start port-forward for tunnel
# ========================================
echo ""
echo "Step 4: Starting port-forward (8090 -> ingress)..."

if pgrep -f "port-forward.*8090" &>/dev/null; then
    success "Port-forward already running"
else
    nohup kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8090:80 &>/dev/null &
    sleep 2
    if pgrep -f "port-forward.*8090" &>/dev/null; then
        success "Port-forward started"
    else
        error "Failed to start port-forward"
    fi
fi

# ========================================
# Step 5: Re-ingest RAG data if needed
# ========================================
if [ "$NEEDS_RAG_SYNC" == "true" ] || [ "$1" == "--full" ]; then
    echo ""
    echo "Step 5: Re-ingesting RAG data to K8s ChromaDB..."
    cd "$PORTFOLIO_ROOT/rag-pipeline"
    python run_pipeline.py k8s
    cd - &>/dev/null
fi

# ========================================
# Step 6: Verify everything works
# ========================================
echo ""
echo "Step 6: Verifying deployment..."
sleep 2

# Test API health
API_HEALTH=$(curl -s -m 5 -H "Host: linksmlm.com" http://localhost:8090/api/chat/health 2>/dev/null || echo "FAILED")

if echo "$API_HEALTH" | grep -q "healthy"; then
    success "API is healthy"

    # Check RAG status
    if echo "$API_HEALTH" | grep -q '"rag_status":"connected"'; then
        success "RAG is connected"
    else
        warn "RAG may not be connected"
    fi
else
    error "API health check failed"
    echo "Response: $API_HEALTH"
fi

# ========================================
# Summary
# ========================================
echo ""
echo "========================================"
echo "  Startup Complete!"
echo "========================================"
echo ""
echo "Access:"
echo "  Local:    http://portfolio.localtest.me"
echo "  Public:   https://linksmlm.com"
echo ""
echo "Useful commands:"
echo "  Check status:  kubectl get pods -n portfolio"
echo "  API logs:      kubectl logs -n portfolio deployment/portfolio-api"
echo "  Re-sync RAG:   cd $PORTFOLIO_ROOT/rag-pipeline && python run_pipeline.py k8s"
echo ""
