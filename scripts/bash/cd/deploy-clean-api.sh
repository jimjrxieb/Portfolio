#!/usr/bin/env bash
set -euo pipefail

# Deploy clean API with debug endpoints
REG="${REGISTRY:-ghcr.io/jimjrxieb}"
NS="${NAMESPACE:-portfolio}"
TAG="clean-api-$(date +%Y%m%d%H%M%S)"

echo "🔨 Building clean API image: $REG/portfolio-api:$TAG"
docker build -t "$REG/portfolio-api:$TAG" -f api/Dockerfile .

echo "🚀 Pushing image"
docker push "$REG/portfolio-api:$TAG"

echo "🧭 Deploying to Kubernetes (namespace: $NS)"
kubectl -n "$NS" set image deploy/portfolio-api api="$REG/portfolio-api:$TAG"

echo "⚙️ Configuring environment"
kubectl -n "$NS" set env deploy/portfolio-api \
  LLM_PROVIDER=ollama \
  LLM_MODEL=phi3:latest \
  LLM_API_BASE=http://ollama:11434 \
  CHROMA_URL=http://chroma:8000 \
  RAG_NAMESPACE=portfolio \
  ELEVENLABS_DEFAULT_VOICE_ID=giancarlo \
  DATA_DIR=/data

echo "♻️ Restarting deployment"
kubectl -n "$NS" rollout restart deploy/portfolio-api

echo "⏳ Waiting for rollout to complete"
kubectl -n "$NS" rollout status deploy/portfolio-api --timeout=300s

echo "✅ Clean API deployed: $TAG"
echo
echo "🔍 Verification commands:"
echo "  # Get API info and connectivity status"
echo "  curl -sS \$API/api/debug/state | jq"
echo
echo "  # Check LLM health"
echo "  curl -sS \$API/api/health/llm | jq"
echo
echo "  # Check RAG health and document count"
echo "  curl -sS \$API/api/health/rag | jq"
echo "  curl -sS \$API/api/actions/rag/count | jq"
echo
echo "  # Test chat endpoint"
echo "  curl -sS -X POST \$API/api/chat -H 'Content-Type: application/json' \\"
echo "    -d '{\"message\":\"What is Jade?\",\"namespace\":\"portfolio\",\"k\":3}' | jq"
echo
echo "📝 Set API variable: export API=https://your-api-domain"
