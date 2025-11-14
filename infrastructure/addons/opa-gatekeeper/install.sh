#!/bin/bash
# Install OPA Gatekeeper for runtime policy enforcement
set -e

ADDON_NAME="OPA Gatekeeper"
NAMESPACE="gatekeeper-system"
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

echo "📦 Deploying Gatekeeper..."
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

echo ""
echo "⏳ Waiting for Gatekeeper pods to be ready..."
kubectl wait --for=condition=ready pod \
    --all \
    -n ${NAMESPACE} \
    --timeout=300s

echo ""
echo "✅ ${ADDON_NAME} installed successfully!"
echo ""
echo "📊 Verification:"
echo "   kubectl get pods -n ${NAMESPACE}"
echo "   kubectl get constrainttemplates"
echo ""
echo "📚 Next steps:"
echo "   1. Apply constraint templates from GP-copilot/conftest-policies/"
echo "   2. Create constraints to enforce policies"
echo "   3. Test with: kubectl apply -f <test-resource>"
echo ""
