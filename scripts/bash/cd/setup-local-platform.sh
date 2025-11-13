#!/bin/bash
# Setup local KinD cluster with ArgoCD for Portfolio GitOps testing
# Run this script to create a complete local development environment

set -e

CLUSTER_NAME="portfolio-local"
NAMESPACE="linkops-portfolio"
ARGOCD_VERSION="v2.8.4"

echo "🚀 Setting up local KinD cluster with ArgoCD for Portfolio"
echo "============================================================"

# Check prerequisites
echo "📋 Checking prerequisites..."
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed. Aborting." >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed. Aborting." >&2; exit 1; }

# Install KinD if not present
if ! command -v kind &> /dev/null; then
    echo "📦 Installing KinD..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    echo "✅ KinD installed successfully"
else
    echo "✅ KinD already installed: $(kind version)"
fi

# Create KinD cluster with ingress support
echo "🎯 Creating KinD cluster: $CLUSTER_NAME"
cat <<EOF | kind create cluster --name $CLUSTER_NAME --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
  - containerPort: 443
    hostPort: 8443
    protocol: TCP
EOF

# Set kubectl context
kubectl cluster-info --context kind-$CLUSTER_NAME

# Install ingress-nginx
echo "🌐 Installing ingress-nginx controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
echo "⏳ Waiting for ingress-nginx to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# Install ArgoCD
echo "🔄 Installing ArgoCD $ARGOCD_VERSION..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get ArgoCD admin password
echo "🔐 Getting ArgoCD admin password..."
ARGO_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Create portfolio namespace
echo "📁 Creating application namespace: $NAMESPACE"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Setup port-forward for ArgoCD (background)
echo "🔗 Setting up ArgoCD port-forward..."
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address=0.0.0.0 &
ARGO_PID=$!

echo ""
echo "🎉 Local KinD cluster setup complete!"
echo "=============================================="
echo ""
echo "🔧 Cluster Details:"
echo "  Name: $CLUSTER_NAME"
echo "  Context: kind-$CLUSTER_NAME"
echo "  Namespace: $NAMESPACE"
echo ""
echo "🔄 ArgoCD Access:"
echo "  URL: https://localhost:8080"
echo "  Username: admin"
echo "  Password: $ARGO_PASSWORD"
echo "  Port-forward PID: $ARGO_PID"
echo ""
echo "🌐 Ingress Controller:"
echo "  HTTP: http://localhost:8080"
echo "  HTTPS: https://localhost:8443"
echo ""
echo "📝 Next Steps:"
echo "  1. Configure ArgoCD Application pointing to charts/portfolio"
echo "  2. Test Helm chart deployment"
echo "  3. Verify ingress routing"
echo ""
echo "🛠️  Useful Commands:"
echo "  kubectl get pods -A                    # Check all pods"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  kind delete cluster --name $CLUSTER_NAME    # Cleanup"
echo ""

# Save cluster info for later use
cat > /tmp/kind-cluster-info.txt <<EOF
CLUSTER_NAME=$CLUSTER_NAME
NAMESPACE=$NAMESPACE
ARGOCD_PASSWORD=$ARGO_PASSWORD
ARGO_PID=$ARGO_PID
EOF

echo "💾 Cluster info saved to /tmp/kind-cluster-info.txt"
