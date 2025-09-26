#!/bin/bash

echo "🔒 Setting up OPA Gatekeeper for Portfolio Platform"
echo "=================================================="

# Check if kubectl is working
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Kubernetes cluster not accessible"
    echo "💡 Please enable Docker Desktop Kubernetes first"
    exit 1
fi

echo "✅ Kubernetes cluster accessible"

# Install OPA Gatekeeper
echo "📦 Installing OPA Gatekeeper..."
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Wait for Gatekeeper to be ready
echo "⏳ Waiting for Gatekeeper to be ready..."
kubectl wait --for=condition=ready pod -l gatekeeper.sh/operation=webhook -n gatekeeper-system --timeout=120s

# Create portfolio namespace with labels
echo "📦 Creating portfolio namespace..."
kubectl create namespace portfolio --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace portfolio policy.gatekeeper.sh/controlled=true --overwrite

# Apply security policies
echo "🔒 Applying security policies..."

# Apply ConstraintTemplates
kubectl apply -f policies/security/container-security.yaml
kubectl apply -f policies/security/image-security.yaml
kubectl apply -f policies/governance/resource-limits.yaml
kubectl apply -f policies/compliance/pod-security-standards.yaml

# Wait for ConstraintTemplates to be ready
echo "⏳ Waiting for ConstraintTemplates to be established..."
sleep 10

# Check policy status
echo "📊 Policy Status:"
kubectl get constrainttemplates

echo "📋 Constraint Status:"
kubectl get constraints -A

# Install Conftest for local validation
echo "📦 Installing Conftest for local validation..."
if ! command -v conftest &> /dev/null; then
    echo "   Downloading Conftest..."
    wget -q https://github.com/open-policy-agent/conftest/releases/download/v0.46.0/conftest_0.46.0_Linux_x86_64.tar.gz
    tar xzf conftest_0.46.0_Linux_x86_64.tar.gz
    sudo mv conftest /usr/local/bin/
    rm conftest_0.46.0_Linux_x86_64.tar.gz
    echo "✅ Conftest installed"
else
    echo "✅ Conftest already installed"
fi

# Test policy validation
echo "🧪 Testing policy validation..."
conftest verify --policy policies/

echo ""
echo "🎯 OPA Gatekeeper Setup Complete!"
echo ""
echo "📊 Monitoring Commands:"
echo "   View violations: kubectl get constraints -A"
echo "   Check Gatekeeper status: kubectl get pods -n gatekeeper-system"
echo "   View policy logs: kubectl logs -n gatekeeper-system deployment/gatekeeper-controller-manager"
echo ""
echo "🧪 Local Testing:"
echo "   Validate manifests: conftest test k8s/ --policy policies/"
echo "   Validate Helm charts: conftest test <(helm template portfolio helm/portfolio/) --policy policies/"
echo ""
echo "🔒 Policies Enforced:"
echo "   ✅ Container Security Contexts"
echo "   ✅ Image Security (trusted registries, no latest tags)"
echo "   ✅ Resource Limits and Requests"
echo "   ✅ Pod Security Standards (restricted)"
echo ""
echo "⚠️  Note: Policies are enforced at admission time - non-compliant resources will be rejected!"
