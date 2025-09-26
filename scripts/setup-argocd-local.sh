#!/bin/bash

echo "🚀 Setting up ArgoCD in Docker Desktop Kubernetes"
echo "=================================================="

# Check if kubectl is working
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Kubernetes cluster not accessible. Please:"
    echo "   1. Open Docker Desktop"
    echo "   2. Go to Settings → Kubernetes"
    echo "   3. Enable Kubernetes"
    echo "   4. Apply & Restart"
    exit 1
fi

echo "✅ Kubernetes cluster accessible"

# Create argocd namespace
echo "📦 Creating ArgoCD namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo "📦 Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# Get initial admin password
echo "🔑 Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Port forward ArgoCD server
echo "🌐 Setting up port forwarding..."
echo "   ArgoCD will be available at: https://localhost:8080"
echo "   Username: admin"
echo "   Password: $ARGOCD_PASSWORD"
echo ""
echo "🔧 To access ArgoCD UI:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "💡 After setup, configure the Portfolio application:"
echo "   kubectl apply -f argocd/portfolio-application.yaml"
echo ""
echo "🎯 ArgoCD installation complete!"
