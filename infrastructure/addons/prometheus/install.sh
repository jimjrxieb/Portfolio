#!/bin/bash
# Install Prometheus for metrics collection and monitoring
set -e

ADDON_NAME="Prometheus"
NAMESPACE="monitoring"
RELEASE_NAME="prometheus"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Installing ${ADDON_NAME}..."
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo "❌ Helm not found. Please install Helm 3.x first."
    echo "💡 Installation: https://helm.sh/docs/intro/install/"
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

# Add Prometheus Helm repo
echo ""
echo "📦 Adding Prometheus Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus
echo ""
echo "📦 Installing Prometheus via Helm..."
helm upgrade --install ${RELEASE_NAME} prometheus-community/prometheus \
    --namespace ${NAMESPACE} \
    --values ${SCRIPT_DIR}/manifests/values.yaml \
    --wait \
    --timeout 5m

echo ""
echo "⏳ Waiting for Prometheus server to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=prometheus,app.kubernetes.io/component=server \
    -n ${NAMESPACE} \
    --timeout=300s

echo ""
echo "✅ ${ADDON_NAME} installed successfully!"
echo ""
echo "🌐 Access Prometheus UI:"
echo "   kubectl port-forward -n ${NAMESPACE} svc/${RELEASE_NAME}-server 9090:80"
echo "   URL: http://localhost:9090"
echo ""
echo "📊 Useful queries:"
echo "   - API request rate: rate(http_requests_total[5m])"
echo "   - Pod CPU: container_cpu_usage_seconds_total{namespace=\"portfolio\"}"
echo "   - Memory usage: container_memory_usage_bytes{namespace=\"portfolio\"}"
echo ""
echo "📚 Targets being scraped:"
echo "   - Kubernetes cluster metrics"
echo "   - Node exporter (host metrics)"
echo "   - Portfolio API pods"
echo "   - Portfolio UI pods"
echo ""
