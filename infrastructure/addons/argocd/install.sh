#!/bin/bash
# Install ArgoCD for GitOps continuous deployment
set -e

ADDON_NAME="ArgoCD"
NAMESPACE="argocd"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Installing ${ADDON_NAME}..."
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if cluster is reachable
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    echo "💡 Make sure Docker Desktop Kubernetes is enabled"
    exit 1
fi

# Create namespace
echo "📦 Creating namespace: ${NAMESPACE}"
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "📦 Deploying ArgoCD..."
kubectl apply -n ${NAMESPACE} -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo ""
echo "⏳ Waiting for ArgoCD pods to be ready (this may take 2-3 minutes)..."
kubectl wait --for=condition=ready pod \
    --all \
    -n ${NAMESPACE} \
    --timeout=300s

echo ""
echo "✅ ${ADDON_NAME} installed successfully!"
echo ""
echo "🔐 Get admin password:"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d && echo"
echo ""
echo "🌐 Access ArgoCD UI:"
echo "   kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "   URL: https://localhost:8080"
echo "   User: admin"
echo "   Pass: (run command above to get password)"
echo ""
echo "📚 Next steps:"
echo "   1. Port forward to access UI"
echo "   2. Login with admin credentials"
echo "   3. Change admin password (recommended)"
echo "   4. Connect your Git repository"
echo "   5. Create ArgoCD Application for Portfolio"
echo ""
