#!/bin/bash
# Create Kubernetes secrets from .env file
# Usage: ./create-secrets-from-env.sh [namespace]

set -e

NAMESPACE="${1:-portfolio}"
SECRET_NAME="portfolio-api-secrets"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🔐 Creating Kubernetes secrets from .env file"
echo "   Namespace: $NAMESPACE"
echo "   Secret: $SECRET_NAME"
echo ""

# Check if .env exists
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo "❌ Error: .env file not found at $PROJECT_ROOT/.env"
    echo "💡 Copy .env.example to .env and configure your API keys"
    exit 1
fi

# Source .env file
echo "📄 Loading environment from .env..."
source "$PROJECT_ROOT/.env"

# Validate required variables
if [ -z "$CLAUDE_API_KEY" ] || [ "$CLAUDE_API_KEY" = "sk-ant-your-claude-api-key-here" ]; then
    echo "❌ Error: CLAUDE_API_KEY not set in .env or still has placeholder value"
    exit 1
fi

# Create namespace if it doesn't exist
echo "📦 Ensuring namespace exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Create secret
echo "🔑 Creating/updating secret..."
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$NAMESPACE" \
    --from-literal=CLAUDE_API_KEY="$CLAUDE_API_KEY" \
    --from-literal=OPENAI_API_KEY="${OPENAI_API_KEY:-REPLACE_WITH_YOUR_OPENAI_API_KEY}" \
    --from-literal=ELEVENLABS_API_KEY="${ELEVENLABS_API_KEY:-REPLACE_WITH_YOUR_ELEVENLABS_API_KEY}" \
    --from-literal=DID_API_KEY="${DID_API_KEY:-REPLACE_WITH_YOUR_DID_API_KEY}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "✅ Secrets created/updated successfully!"
echo ""
echo "📊 Verify with:"
echo "   kubectl get secret $SECRET_NAME -n $NAMESPACE"
echo "   kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.CLAUDE_API_KEY}' | base64 -d | cut -c1-10"
echo ""
echo "🔄 Restart deployments to pick up new secrets:"
echo "   kubectl rollout restart deployment/portfolio-api -n $NAMESPACE"
