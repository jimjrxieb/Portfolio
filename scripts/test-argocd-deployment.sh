#!/bin/bash

echo "🧪 Testing ArgoCD Local Deployment"
echo "=================================="

# Check if kubectl is working
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Kubernetes cluster not accessible"
    echo "💡 Please enable Docker Desktop Kubernetes first"
    exit 1
fi

echo "✅ Kubernetes cluster accessible"

# Check if ArgoCD is installed
if ! kubectl get namespace argocd &> /dev/null; then
    echo "❌ ArgoCD not installed"
    echo "💡 Run: ./scripts/setup-argocd-local.sh"
    exit 1
fi

echo "✅ ArgoCD namespace exists"

# Check ArgoCD pods
echo "📋 ArgoCD Pod Status:"
kubectl get pods -n argocd

# Check if Portfolio application exists
if kubectl get application portfolio -n argocd &> /dev/null; then
    echo "✅ Portfolio application exists"
    echo "📋 Application Status:"
    kubectl get application portfolio -n argocd -o wide
else
    echo "⚠️ Portfolio application not found"
    echo "💡 Apply with: kubectl apply -f argocd/portfolio-application.yaml"
fi

# Check Portfolio namespace
if kubectl get namespace portfolio &> /dev/null; then
    echo "✅ Portfolio namespace exists"
    echo "📋 Portfolio Resources:"
    kubectl get all -n portfolio
else
    echo "⚠️ Portfolio namespace not found - application may not be synced yet"
fi

echo ""
echo "🔗 Access URLs (when running):"
echo "   ArgoCD UI:    kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Portfolio UI: kubectl port-forward svc/portfolio-ui -n portfolio 3000:3000"
echo "   Portfolio API: kubectl port-forward svc/portfolio-api -n portfolio 8000:8000"
echo "   ChromaDB:     kubectl port-forward svc/portfolio-chromadb -n portfolio 8001:8001"
echo ""
echo "🎯 Testing complete!"
