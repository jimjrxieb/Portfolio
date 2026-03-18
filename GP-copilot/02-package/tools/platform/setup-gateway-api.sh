#!/usr/bin/env bash
# =============================================================================
# Ghost Protocol -- setup-gateway-api.sh
# Install Gateway API CRDs, deploy a controller, and apply GatewayClass
#
# Usage:
#   bash tools/setup-gateway-api.sh --controller envoy --domain app.example.com
#   bash tools/setup-gateway-api.sh --controller cilium --dry-run
#   bash tools/setup-gateway-api.sh --help
#
# Supported controllers: envoy, cilium, istio, nginx
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEMPLATE_DIR="${PACKAGE_DIR}/templates/gateway-api"

# Pinned versions
GATEWAY_API_VERSION="v1.2.1"
ENVOY_GATEWAY_VERSION="v1.2.4"
NGINX_GW_VERSION="1.5.0"

# Defaults
CONTROLLER="envoy"
NAMESPACE="gateway-system"
DOMAIN=""
TLS_SECRET=""
DRY_RUN=false

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_section() { echo -e "\n${BLUE}=== $* ===${NC}"; }

die() { log_error "$*"; exit 1; }

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --controller  envoy|cilium|istio|nginx  Gateway controller (default: envoy)"
    echo "  --namespace   NAMESPACE                 Target namespace (default: gateway-system)"
    echo "  --domain      DOMAIN                    Hostname for Gateway (e.g. app.example.com)"
    echo "  --tls-secret  SECRET                    TLS secret name (if pre-created)"
    echo "  --dry-run                               Print what would be done, do not apply"
    echo "  -h, --help                              Show this help"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --controller)
            CONTROLLER="${2:-}"
            [[ "$CONTROLLER" =~ ^(envoy|cilium|istio|nginx)$ ]] \
                || die "Invalid controller: $CONTROLLER. Must be envoy, cilium, istio, or nginx."
            shift 2 ;;
        --namespace)  NAMESPACE="${2:-}"; shift 2 ;;
        --domain)     DOMAIN="${2:-}"; shift 2 ;;
        --tls-secret) TLS_SECRET="${2:-}"; shift 2 ;;
        --dry-run)    DRY_RUN=true; shift ;;
        -h|--help)    usage ;;
        *)            die "Unknown option: $1" ;;
    esac
done

# ── Pre-flight checks ─────────────────────────────────────────────────────
log_section "Pre-flight checks"

command -v kubectl >/dev/null 2>&1 || die "kubectl not found. Run tools/hardening/install-scanners.sh first."
command -v helm >/dev/null 2>&1 || die "helm not found. Run tools/hardening/install-scanners.sh first."

kubectl cluster-info >/dev/null 2>&1 || die "Cannot connect to Kubernetes cluster."
log_ok "Cluster reachable"

# ── Step 1: Install Gateway API CRDs ──────────────────────────────────────
log_section "Installing Gateway API CRDs (${GATEWAY_API_VERSION})"

CRD_URL="https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"

if kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
    log_ok "Gateway API CRDs already installed"
else
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would apply: ${CRD_URL}"
    else
        kubectl apply -f "${CRD_URL}"
        log_ok "Gateway API CRDs installed"
    fi
fi

# ── Step 2: Deploy controller ─────────────────────────────────────────────
log_section "Deploying ${CONTROLLER} controller"

case "$CONTROLLER" in
    envoy)
        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would install envoy-gateway ${ENVOY_GATEWAY_VERSION} via Helm"
        else
            helm repo add envoy-gateway https://gateway.envoyproxy.io/helm 2>/dev/null || true
            helm repo update envoy-gateway
            helm upgrade --install envoy-gateway envoy-gateway/gateway-helm \
                --version "${ENVOY_GATEWAY_VERSION}" \
                --namespace envoy-gateway-system \
                --create-namespace \
                --wait --timeout 120s
            log_ok "Envoy Gateway deployed"
        fi
        ;;
    cilium)
        if kubectl get daemonset -n kube-system cilium >/dev/null 2>&1; then
            log_ok "Cilium already running — Gateway API support is built-in"
            log_info "Ensure gatewayAPI.enabled=true in Cilium Helm values"
        else
            die "Cilium not found. Install Cilium first with gatewayAPI.enabled=true."
        fi
        ;;
    istio)
        if kubectl get deploy -n istio-system istiod >/dev/null 2>&1; then
            log_ok "Istio already running — Gateway API support is built-in"
        else
            die "Istio not found. Install Istio first (istioctl install --set profile=minimal)."
        fi
        ;;
    nginx)
        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would install nginx-gateway-fabric ${NGINX_GW_VERSION} via Helm"
        else
            helm repo add nginx-gateway https://nginx-gateway-fabric.nginx.org 2>/dev/null || true
            helm repo update nginx-gateway
            helm upgrade --install nginx-gateway nginx-gateway/nginx-gateway-fabric \
                --version "${NGINX_GW_VERSION}" \
                --namespace nginx-gateway \
                --create-namespace \
                --wait --timeout 120s
            log_ok "nginx-gateway-fabric deployed"
        fi
        ;;
esac

# ── Step 3: Apply GatewayClass ────────────────────────────────────────────
log_section "Applying GatewayClass"

# Build controller name from selection
case "$CONTROLLER" in
    envoy)  CONTROLLER_NAME="gateway.envoyproxy.io/gatewayclass-controller" ;;
    cilium) CONTROLLER_NAME="io.cilium/gateway-controller" ;;
    istio)  CONTROLLER_NAME="istio.io/gateway-controller" ;;
    nginx)  CONTROLLER_NAME="gateway.nginx.org/nginx-gateway-controller" ;;
esac

if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would apply GatewayClass 'gp-gateway' with controller: ${CONTROLLER_NAME}"
else
    cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: gp-gateway
  labels:
    app.kubernetes.io/managed-by: gp-copilot
    control: SC-7
spec:
  controllerName: ${CONTROLLER_NAME}
EOF
    log_ok "GatewayClass 'gp-gateway' created"
fi

# ── Step 4: Verify ────────────────────────────────────────────────────────
if [ "$DRY_RUN" = false ]; then
    log_section "Verification"

    if kubectl get gatewayclass gp-gateway >/dev/null 2>&1; then
        ACCEPTED=$(kubectl get gatewayclass gp-gateway -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}' 2>/dev/null || echo "Unknown")
        log_ok "GatewayClass 'gp-gateway' exists (Accepted: ${ACCEPTED})"
    else
        log_warn "GatewayClass not found — controller may still be starting"
    fi
fi

# ── Summary ───────────────────────────────────────────────────────────────
log_section "Summary"
echo ""
echo "  Controller:    ${CONTROLLER}"
echo "  GatewayClass:  gp-gateway"
echo "  CRD version:   ${GATEWAY_API_VERSION}"
echo ""
echo "  Next steps:"
echo "    1. Create a Gateway:     kubectl apply -f templates/gateway-api/gateway.yaml"
echo "    2. Create HTTPRoutes:    kubectl apply -f templates/gateway-api/httproute.yaml"
echo "    3. Test canary routing:  kubectl apply -f templates/gateway-api/httproute-canary.yaml"
echo "    4. Enforce TLS policy:   kubectl apply -f templates/policies/kyverno/require-gateway-tls.yaml"
echo ""
echo "  Templates: ${TEMPLATE_DIR}/"
echo ""
echo "Done."
