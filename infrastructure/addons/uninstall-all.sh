#!/bin/bash
# Master uninstallation script for all infrastructure addons
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Portfolio Infrastructure Addons - Uninstaller            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}⚠️  WARNING: This will remove ALL infrastructure addons!${NC}"
echo ""
echo "The following will be uninstalled:"
echo "  - ArgoCD (argocd namespace)"
echo "  - Grafana (monitoring namespace)"
echo "  - Prometheus (monitoring namespace)"
echo "  - LocalStack (localstack namespace)"
echo "  - OPA Gatekeeper (gatekeeper-system namespace)"
echo ""

read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo ""
echo "🗑️  Starting uninstallation..."
echo ""

# Uninstall ArgoCD
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗑️  Uninstalling ArgoCD..."
if kubectl get namespace argocd &> /dev/null; then
    kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml || true
    kubectl delete namespace argocd || true
    echo "✅ ArgoCD uninstalled"
else
    echo "⏭️  ArgoCD not found, skipping"
fi
echo ""

# Uninstall Grafana
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗑️  Uninstalling Grafana..."
if helm list -n monitoring | grep -q grafana; then
    helm uninstall grafana -n monitoring || true
    echo "✅ Grafana uninstalled"
else
    echo "⏭️  Grafana not found, skipping"
fi
echo ""

# Uninstall Prometheus
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗑️  Uninstalling Prometheus..."
if helm list -n monitoring | grep -q prometheus; then
    helm uninstall prometheus -n monitoring || true
    echo "✅ Prometheus uninstalled"
else
    echo "⏭️  Prometheus not found, skipping"
fi

# Delete monitoring namespace
if kubectl get namespace monitoring &> /dev/null; then
    kubectl delete namespace monitoring || true
    echo "✅ Monitoring namespace deleted"
fi
echo ""

# Uninstall LocalStack
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗑️  Uninstalling LocalStack..."
if kubectl get namespace localstack &> /dev/null; then
    kubectl delete -f ${SCRIPT_DIR}/localstack/manifests/ || true
    kubectl delete namespace localstack || true
    echo "✅ LocalStack uninstalled"
else
    echo "⏭️  LocalStack not found, skipping"
fi
echo ""

# Uninstall OPA Gatekeeper
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗑️  Uninstalling OPA Gatekeeper..."
if kubectl get namespace gatekeeper-system &> /dev/null; then
    kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml || true
    echo "✅ OPA Gatekeeper uninstalled"
else
    echo "⏭️  OPA Gatekeeper not found, skipping"
fi
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║          🎉 ALL ADDONS UNINSTALLED! 🎉                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "🔍 Verify cleanup:"
echo "   kubectl get namespaces | grep -E 'gatekeeper|localstack|monitoring|argocd'"
echo ""
echo "📊 Remaining namespaces (should be empty):"
kubectl get namespaces | grep -E 'gatekeeper|localstack|monitoring|argocd' || echo "   None found - cleanup complete! ✅"
echo ""
