#!/bin/bash
# Create development secrets for local K8s deployment
# This script reads from .env and creates K8s secrets

set -e

NAMESPACE="${1:-linkops-portfolio}"
SECRET_NAME="portfolio-api-secrets"

echo "Creating development secrets in namespace: $NAMESPACE"

# Source environment variables
if [[ -f .env ]]; then
    echo "Loading environment from .env file..."
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found. Please copy .env.example to .env and configure."
    exit 1
fi

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Create secret with base64 encoding
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$NAMESPACE" \
    --from-literal=OPENAI_API_KEY="${OPENAI_API_KEY:-}" \
    --from-literal=ELEVENLABS_API_KEY="${ELEVENLABS_API_KEY:-}" \
    --from-literal=DID_API_KEY="${DID_API_KEY:-}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Development secrets created successfully!"
echo "🔍 Verify with: kubectl get secret $SECRET_NAME -n $NAMESPACE -o yaml"
