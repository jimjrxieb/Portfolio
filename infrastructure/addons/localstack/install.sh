#!/bin/bash
# Install LocalStack for local AWS emulation
set -e

ADDON_NAME="LocalStack"
NAMESPACE="localstack"
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

echo "📦 Deploying LocalStack manifests..."
kubectl apply -f ${SCRIPT_DIR}/manifests/namespace.yaml
kubectl apply -f ${SCRIPT_DIR}/manifests/deployment.yaml
kubectl apply -f ${SCRIPT_DIR}/manifests/service.yaml

echo ""
echo "⏳ Waiting for LocalStack pod to be ready (pulling image may take a minute)..."
kubectl wait --for=condition=ready pod \
    -l app=localstack \
    -n ${NAMESPACE} \
    --timeout=300s

echo ""
echo "✅ ${ADDON_NAME} installed successfully!"
echo ""
echo "🌐 Access LocalStack:"
echo "   Endpoint: http://localhost:4566"
echo "   NodePort: http://localhost:30566"
echo ""
echo "🔍 Health check:"
echo "   curl http://localhost:4566/_localstack/health"
echo ""
echo "🧪 Test S3:"
echo "   export AWS_ENDPOINT_URL=http://localhost:4566"
echo "   export AWS_ACCESS_KEY_ID=test"
echo "   export AWS_SECRET_ACCESS_KEY=test"
echo "   aws --endpoint-url=http://localhost:4566 s3 mb s3://test-bucket"
echo "   aws --endpoint-url=http://localhost:4566 s3 ls"
echo ""
echo "📚 Supported services:"
echo "   S3, DynamoDB, SQS, Lambda, CloudFormation, STS, IAM"
echo ""
