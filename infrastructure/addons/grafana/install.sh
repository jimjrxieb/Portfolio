#!/bin/bash
# Install Grafana for metrics visualization
set -e

ADDON_NAME="Grafana"
NAMESPACE="monitoring"
RELEASE_NAME="grafana"
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

# Check if Prometheus is installed (dependency)
if ! kubectl get svc prometheus-server -n ${NAMESPACE} &> /dev/null; then
    echo "⚠️  Warning: Prometheus not found in ${NAMESPACE} namespace"
    echo "💡 Grafana requires Prometheus as a data source"
    echo "   Install Prometheus first: cd ../prometheus && ./install.sh"
    echo ""
    read -p "Continue without Prometheus? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create namespace (if not exists from Prometheus install)
echo "📦 Ensuring namespace exists: ${NAMESPACE}"
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Add Grafana Helm repo
echo ""
echo "📦 Adding Grafana Helm repository..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Grafana
echo ""
echo "📦 Installing Grafana via Helm..."
helm upgrade --install ${RELEASE_NAME} grafana/grafana \
    --namespace ${NAMESPACE} \
    --values ${SCRIPT_DIR}/manifests/values.yaml \
    --wait \
    --timeout 5m

echo ""
echo "⏳ Waiting for Grafana pod to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=grafana \
    -n ${NAMESPACE} \
    --timeout=300s

echo ""
echo "✅ ${ADDON_NAME} installed successfully!"
echo ""
echo "🔐 Default credentials:"
echo "   Username: admin"
echo "   Password: admin (CHANGE ON FIRST LOGIN!)"
echo ""
echo "🌐 Access Grafana UI:"
echo "   kubectl port-forward -n ${NAMESPACE} svc/${RELEASE_NAME} 3000:80"
echo "   URL: http://localhost:3000"
echo "   NodePort: http://localhost:30300"
echo ""
echo "📊 Pre-configured dashboards:"
echo "   - Kubernetes Cluster Monitoring (ID: 7249)"
echo "   - Node Exporter Full (ID: 1860)"
echo "   - Kubernetes Pod Resources (ID: 6417)"
echo ""
echo "📚 Data source configured:"
echo "   - Prometheus: http://prometheus-server.monitoring.svc.cluster.local"
echo ""
echo "🎨 Next steps:"
echo "   1. Access Grafana UI"
echo "   2. Login with admin/admin"
echo "   3. Change admin password (Settings > Profile > Change Password)"
echo "   4. Explore pre-configured dashboards"
echo "   5. Create custom dashboards for Portfolio metrics"
echo ""
