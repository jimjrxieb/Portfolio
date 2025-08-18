#!/bin/bash
# Deploy Portfolio from GHCR registry to local KinD cluster
# Usage: ./scripts/deploy-from-registry.sh [image-tag]

set -e

# Configuration
REGISTRY="ghcr.io"
IMAGE_NAME="jimjrxieb/portfolio"
NAMESPACE="portfolio"

# Get image tag from argument or latest
if [ -n "$1" ]; then
    IMAGE_TAG="$1"
else
    IMAGE_TAG="latest"
fi

echo "🚀 Deploying Portfolio from Registry"
echo "====================================="
echo "Registry: ${REGISTRY}"
echo "Images: ${IMAGE_NAME}-{api,ui}:${IMAGE_TAG}"
echo "Cluster: $(kubectl config current-context)"
echo "Namespace: ${NAMESPACE}"
echo ""

# Verify cluster connection
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Cannot connect to Kubernetes cluster"
    echo "   Make sure KinD cluster is running: kind get clusters"
    exit 1
fi

# Pull images to local Docker (will be available to KinD)
echo "📦 Pulling images from registry..."
docker pull ${REGISTRY}/${IMAGE_NAME}-api:${IMAGE_TAG}
docker pull ${REGISTRY}/${IMAGE_NAME}-ui:${IMAGE_TAG}

# Load images into KinD cluster
echo "🔄 Loading images into KinD..."
kind load docker-image ${REGISTRY}/${IMAGE_NAME}-api:${IMAGE_TAG} --name portfolio-local
kind load docker-image ${REGISTRY}/${IMAGE_NAME}-ui:${IMAGE_TAG} --name portfolio-local

echo "✅ Images loaded into cluster"

# Deploy with Helm
echo "🎯 Deploying with Helm..."
helm upgrade --install portfolio ./charts/portfolio \
  --namespace ${NAMESPACE} \
  --create-namespace \
  -f ./charts/portfolio/values.dev.yaml \
  --set image.repository=${REGISTRY}/${IMAGE_NAME}-api \
  --set image.tag=${IMAGE_TAG} \
  --set ui.image.repository=${REGISTRY}/${IMAGE_NAME}-ui \
  --set ui.image.tag=${IMAGE_TAG} \
  --wait --timeout=5m

echo "✅ Deployment completed"

# Verify deployment
echo "🔍 Verifying deployment..."
kubectl -n ${NAMESPACE} rollout status deploy/portfolio-api --timeout=300s
kubectl -n ${NAMESPACE} rollout status deploy/portfolio-ui --timeout=300s

echo ""
echo "📊 Deployment Status:"
kubectl -n ${NAMESPACE} get pods,svc,ingress

echo ""
echo "🎉 Portfolio deployed successfully!"
echo "🌐 Application should be accessible at: https://linksmlm.com"
echo "   (via Cloudflare tunnel)"
echo ""
echo "🔧 Useful commands:"
echo "  Check pods: kubectl get pods -n ${NAMESPACE}"
echo "  View logs: kubectl logs -f deployment/portfolio-api -n ${NAMESPACE}"
echo "  Port forward: kubectl port-forward svc/portfolio-api 8080:8000 -n ${NAMESPACE}"