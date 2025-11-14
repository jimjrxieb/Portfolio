#!/bin/bash
# Master installation script for all infrastructure addons
# Installs: OPA Gatekeeper, LocalStack, Prometheus, Grafana, ArgoCD
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Portfolio Infrastructure Addons - Master Installer       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "🔍 Checking prerequisites..."
echo ""

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "❌ Helm not found. Please install Helm 3.x first."
    echo "💡 Some addons (Prometheus, Grafana) require Helm"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    echo "💡 Make sure Docker Desktop Kubernetes is enabled"
    exit 1
fi

echo "✅ All prerequisites met!"
echo ""

# Function to install addon
install_addon() {
    local addon_name=$1
    local addon_dir=$2

    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🚀 Installing: ${addon_name}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""

    cd "${SCRIPT_DIR}/${addon_dir}"
    bash install.sh

    echo ""
    echo -e "${GREEN}✅ ${addon_name} installation complete!${NC}"
    echo ""
    sleep 2
}

# Display installation plan
echo "📋 Installation Plan:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. OPA Gatekeeper    - Runtime policy enforcement"
echo "  2. LocalStack        - Local AWS emulation"
echo "  3. Prometheus        - Metrics collection"
echo "  4. Grafana           - Metrics visualization"
echo "  5. ArgoCD            - GitOps deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Continue with installation? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$|^$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "🎯 Starting installation..."
echo ""

# Install addons in order (handling dependencies)
install_addon "OPA Gatekeeper" "opa-gatekeeper"
install_addon "LocalStack" "localstack"
install_addon "Prometheus" "prometheus"
install_addon "Grafana" "grafana"
install_addon "ArgoCD" "argocd"

# Final summary
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              🎉 ALL ADDONS INSTALLED! 🎉                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ OPA Gatekeeper (gatekeeper-system namespace)"
echo "   - Policy enforcement enabled"
echo "   - Verify: kubectl get pods -n gatekeeper-system"
echo ""
echo "✅ LocalStack (localstack namespace)"
echo "   - Endpoint: http://localhost:4566"
echo "   - Health: curl http://localhost:4566/_localstack/health"
echo ""
echo "✅ Prometheus (monitoring namespace)"
echo "   - Access: kubectl port-forward -n monitoring svc/prometheus-server 9090:80"
echo "   - URL: http://localhost:9090"
echo ""
echo "✅ Grafana (monitoring namespace)"
echo "   - Access: kubectl port-forward -n monitoring svc/grafana 3000:80"
echo "   - URL: http://localhost:3000"
echo "   - Login: admin / admin (change on first login!)"
echo ""
echo "✅ ArgoCD (argocd namespace)"
echo "   - Access: kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "   - URL: https://localhost:8080"
echo "   - User: admin"
echo "   - Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔍 Quick verification:"
echo "   kubectl get pods --all-namespaces | grep -E 'gatekeeper|localstack|monitoring|argocd'"
echo ""
echo "📚 Documentation:"
echo "   See ${SCRIPT_DIR}/README.md for detailed usage"
echo ""
echo "🎯 Next steps:"
echo "   1. Access Grafana and change default password"
echo "   2. Access ArgoCD and change admin password"
echo "   3. Configure ArgoCD to deploy Portfolio (Method 3)"
echo "   4. Test LocalStack with Terraform (Method 2)"
echo ""
