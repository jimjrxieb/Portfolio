#!/usr/bin/env bash
set -euo pipefail

# --- CONFIG ---
REGISTRY="ghcr.io/jimjrxieb"
NS="portfolio"
API_IMG="$REGISTRY/portfolio-api"
UI_IMG="$REGISTRY/portfolio-ui"
TAG="$(date +%Y%m%d%H%M%S)"

echo "🔨 Building API image: $API_IMG:$TAG"
docker build -t "$API_IMG:$TAG" -f api/Dockerfile .

echo "🔨 Building UI image:  $UI_IMG:$TAG"
docker build -t "$UI_IMG:$TAG" -f ui/Dockerfile ui

echo "🚀 Pushing images"
docker push "$API_IMG:$TAG"
docker push "$UI_IMG:$TAG"

echo "🧭 Rolling out to k8s (namespace: $NS)"
kubectl -n "$NS" set image deploy/portfolio-api api="$API_IMG:$TAG"
kubectl -n "$NS" set image deploy/portfolio-ui  ui="$UI_IMG:$TAG"

kubectl -n "$NS" rollout status deploy/portfolio-api
kubectl -n "$NS" rollout status deploy/portfolio-ui

echo "✅ Deployed: $TAG"
echo "📝 Update your DNS/ingress to point to the new pods"
echo "🔍 Quick health check:"
echo "  curl -sS https://your-api-domain/api/health/llm | jq"
echo "  curl -sS https://your-api-domain/api/health/rag | jq"
