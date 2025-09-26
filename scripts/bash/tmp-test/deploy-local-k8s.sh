#!/bin/bash

set -e

echo "🚀 Portfolio MVP - Local Kubernetes Deployment"
echo "=============================================="

# Check if kind or minikube is preferred
if command -v kind &> /dev/null; then
    CLUSTER_TYPE="kind"
    echo "📦 Using kind for local deployment"
elif command -v minikube &> /dev/null; then
    CLUSTER_TYPE="minikube" 
    echo "📦 Using minikube for local deployment"
else
    echo "❌ Please install kind or minikube first"
    echo "   kind: https://kind.sigs.k8s.io/docs/user/quick-start/"
    echo "   minikube: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Deploy using make
case $CLUSTER_TYPE in
    "kind")
        echo "🔨 Building and deploying to kind..."
        make deploy-kind
        echo ""
        echo "✅ Deployment complete!"
        echo "🌐 Open: http://portfolio.localtest.me"
        echo "🔍 Health: curl -s http://portfolio.localtest.me/api/health"
        ;;
    "minikube")
        echo "🔨 Building and deploying to minikube..."
        make deploy-minikube
        MINIKUBE_IP=$(minikube ip)
        echo ""
        echo "✅ Deployment complete!"
        echo "🔧 Add to /etc/hosts:"
        echo "   echo \"$MINIKUBE_IP portfolio.localtest.me\" | sudo tee -a /etc/hosts"
        echo "🌐 Then open: http://portfolio.localtest.me"
        ;;
esac

echo ""
echo "📊 Status:"
kubectl -n portfolio get pods,svc,ing

echo ""
echo "🎤 Try these interview questions:"
echo "  • Tell me about yourself"
echo "  • What's your DevOps experience?"
echo "  • Explain your AI/ML background"  
echo "  • Tell me about the Afterlife project"