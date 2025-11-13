#!/bin/bash
# Test local deployment pipeline (simulates what ADO will do)

set -e

IMAGE_REPO="ghcr.io/jimjrxieb/portfolio"
IMAGE_TAG="main-$(git rev-parse --short HEAD)"

echo "🧪 Testing Local Deployment Pipeline"
echo "====================================="
echo "Image: ${IMAGE_REPO}:${IMAGE_TAG}"
echo "Cluster: $(kubectl config current-context)"
echo ""

# 1. Build images locally (simulating CI)
echo "🔨 Building images..."
docker build -f ./api/Dockerfile -t ${IMAGE_REPO}-api:${IMAGE_TAG} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg BUILD_SHA=$(git rev-parse --short HEAD) \
  .

docker build -f ./ui/Dockerfile -t ${IMAGE_REPO}-ui:${IMAGE_TAG} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg BUILD_SHA=$(git rev-parse --short HEAD) \
  .

echo "✅ Images built"

# 2. Load images into KinD (since we're not pushing to registry)
echo "📦 Loading images into KinD..."
kind load docker-image ${IMAGE_REPO}-api:${IMAGE_TAG} --name portfolio-local
kind load docker-image ${IMAGE_REPO}-ui:${IMAGE_TAG} --name portfolio-local
echo "✅ Images loaded"

# 3. Deploy with Helm
echo "🚀 Deploying with Helm..."
helm upgrade --install portfolio ./charts/portfolio \
  --namespace portfolio \
  --create-namespace \
  -f ./charts/portfolio/values.dev.yaml \
  --set image.repository=${IMAGE_REPO}-api \
  --set image.tag=${IMAGE_TAG} \
  --set ui.image.repository=${IMAGE_REPO}-ui \
  --set ui.image.tag=${IMAGE_TAG} \
  --wait --timeout=5m

echo "✅ Deployment completed"

# 4. Verify deployment
echo "🔍 Verifying deployment..."
kubectl -n portfolio rollout status deploy/portfolio-api --timeout=300s
kubectl -n portfolio rollout status deploy/portfolio-ui --timeout=300s

echo ""
echo "📊 Deployment Status:"
kubectl -n portfolio get pods,svc,ingress

echo ""
echo "🎉 Local deployment test complete!"
echo "🌐 Application should be accessible at: https://linksmlm.com"
echo "   (if Cloudflare tunnel is configured and running)"
