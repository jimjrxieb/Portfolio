#!/usr/bin/env bash
# =============================================================================
# Ghost Protocol -- setup-vpa.sh
# Install Vertical Pod Autoscaler (CRDs + controller) and deploy a sample VPA
#
# Usage:
#   bash tools/platform/setup-vpa.sh
#   bash tools/platform/setup-vpa.sh --mode recommend
#   bash tools/platform/setup-vpa.sh --mode auto
#   bash tools/platform/setup-vpa.sh --namespace kube-system --dry-run
#
# Modes: recommend (default, safe), auto (evicts pods to resize)
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEMPLATE_DIR="${PACKAGE_DIR}/templates/vpa"

# Pinned version
VPA_VERSION="1.2.1"

# Defaults
MODE="recommend"
NAMESPACE="kube-system"
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
    echo "  --mode        recommend|auto   VPA update mode (default: recommend)"
    echo "  --namespace   NS               Namespace for VPA controller (default: kube-system)"
    echo "  --dry-run                      Print what would be done, do not apply"
    echo "  -h, --help                     Show this help"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            MODE="${2:-}"
            [[ "$MODE" =~ ^(recommend|auto)$ ]] \
                || die "Invalid mode: $MODE. Must be recommend or auto."
            shift 2 ;;
        --namespace)   NAMESPACE="${2:-}"; shift 2 ;;
        --dry-run)     DRY_RUN=true; shift ;;
        -h|--help)     usage ;;
        *)             die "Unknown option: $1" ;;
    esac
done

# ── Pre-flight checks ─────────────────────────────────────────────────────
log_section "Pre-flight checks"

command -v kubectl >/dev/null 2>&1 || die "kubectl not found."
kubectl cluster-info >/dev/null 2>&1 || die "Cannot connect to Kubernetes cluster."
log_ok "Cluster reachable"

# Check Metrics Server (VPA requires it)
if kubectl top pods -n kube-system --request-timeout=5s >/dev/null 2>&1; then
    log_ok "Metrics Server is available"
else
    log_warn "Metrics Server may not be installed — VPA requires it for recommendations"
    log_info "Install Metrics Server: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
fi

# ── Step 1: Install VPA CRDs + Controller ─────────────────────────────────
log_section "Installing VPA (version ${VPA_VERSION})"

VPA_BASE_URL="https://raw.githubusercontent.com/kubernetes/autoscaler/vertical-pod-autoscaler-${VPA_VERSION}/vertical-pod-autoscaler/deploy"

if kubectl get crd verticalpodautoscalers.autoscaling.k8s.io >/dev/null 2>&1; then
    log_ok "VPA CRDs already installed"
    CRDS_EXIST=true
else
    CRDS_EXIST=false
fi

if kubectl get deploy -n "${NAMESPACE}" vpa-recommender >/dev/null 2>&1; then
    log_ok "VPA recommender already running in ${NAMESPACE}"
    CONTROLLER_EXISTS=true
else
    CONTROLLER_EXISTS=false
fi

if [ "$CRDS_EXIST" = false ]; then
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would install VPA CRDs from ${VPA_BASE_URL}/vpa-v1-crd-gen.yaml"
    else
        log_info "Installing VPA CRDs..."
        kubectl apply -f "${VPA_BASE_URL}/vpa-v1-crd-gen.yaml"
        log_ok "VPA CRDs installed"
    fi
fi

if [ "$CONTROLLER_EXISTS" = false ]; then
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would install VPA controller components into ${NAMESPACE}"
    else
        log_info "Installing VPA controller components..."

        # Deploy recommender
        kubectl apply -f "${VPA_BASE_URL}/recommender-deployment.yaml"
        log_ok "VPA recommender deployed"

        # Deploy updater (only needed for Auto mode, but install always for flexibility)
        kubectl apply -f "${VPA_BASE_URL}/updater-deployment.yaml"
        log_ok "VPA updater deployed"

        # Deploy admission controller
        kubectl apply -f "${VPA_BASE_URL}/admission-controller-deployment.yaml"
        log_ok "VPA admission controller deployed"

        # Wait for recommender to be ready
        log_info "Waiting for VPA recommender to be ready..."
        kubectl rollout status deploy/vpa-recommender -n "${NAMESPACE}" --timeout=120s 2>/dev/null || \
            log_warn "VPA recommender not ready yet — check: kubectl get pods -n ${NAMESPACE} -l app=vpa-recommender"
    fi
fi

# ── Step 2: Deploy sample VPA resource ────────────────────────────────────
log_section "Deploying sample VPA resource (mode: ${MODE})"

if [ "$MODE" = "recommend" ]; then
    TEMPLATE_FILE="${TEMPLATE_DIR}/vpa-recommend.yaml"
    UPDATE_MODE="Off"
else
    TEMPLATE_FILE="${TEMPLATE_DIR}/vpa-auto.yaml"
    UPDATE_MODE="Auto"
fi

if [ -f "$TEMPLATE_FILE" ]; then
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would deploy sample VPA from ${TEMPLATE_FILE}"
        log_info "[DRY RUN] Template uses updateMode: ${UPDATE_MODE}"
        log_info "[DRY RUN] Edit <APP_NAME> and <NAMESPACE> before applying to your workloads"
    else
        log_info "Sample VPA template available at: ${TEMPLATE_FILE}"
        log_info "To deploy for your workload:"
        log_info "  cp ${TEMPLATE_FILE} /tmp/vpa-myapp.yaml"
        log_info "  sed -i 's|<APP_NAME>|my-deployment|g' /tmp/vpa-myapp.yaml"
        log_info "  sed -i 's|<NAMESPACE>|default|g' /tmp/vpa-myapp.yaml"
        log_info "  kubectl apply -f /tmp/vpa-myapp.yaml"
    fi
else
    log_warn "Template not found: ${TEMPLATE_FILE}"
    log_info "Create VPA resources manually — see playbook 13b for examples"
fi

# ── Step 3: Verify installation ───────────────────────────────────────────
if [ "$DRY_RUN" = false ]; then
    log_section "Verifying VPA installation"

    # Verify CRDs
    for crd in verticalpodautoscalers.autoscaling.k8s.io verticalpodautoscalercheckpoints.autoscaling.k8s.io; do
        if kubectl get crd "$crd" >/dev/null 2>&1; then
            log_ok "CRD: $crd"
        else
            log_warn "CRD missing: $crd"
        fi
    done

    # Verify controller pods
    for component in vpa-recommender vpa-updater vpa-admission-controller; do
        READY=$(kubectl get deploy -n "${NAMESPACE}" "$component" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        if [ "${READY}" -ge 1 ] 2>/dev/null; then
            log_ok "${component} is running (${READY} ready replicas)"
        else
            log_warn "${component} not ready — check: kubectl get pods -n ${NAMESPACE} -l app=${component}"
        fi
    done

    # Check for existing VPA objects
    VPA_COUNT=$(kubectl get vpa -A --no-headers 2>/dev/null | wc -l)
    log_info "VPA objects in cluster: ${VPA_COUNT}"
fi

# ── Summary ───────────────────────────────────────────────────────────────
log_section "Summary"
echo ""
echo "  VPA version:         ${VPA_VERSION}"
echo "  Controller namespace: ${NAMESPACE}"
echo "  Mode:                ${MODE} (updateMode: ${UPDATE_MODE:-Off})"
echo "  Dry run:             ${DRY_RUN}"
echo ""
echo "  Next steps:"
echo "    1. Deploy VPA for your workloads:  cp templates/vpa/vpa-recommend.yaml /tmp/vpa-myapp.yaml"
echo "    2. Edit placeholders:              sed -i 's|<APP_NAME>|my-app|g' /tmp/vpa-myapp.yaml"
echo "    3. Apply:                          kubectl apply -f /tmp/vpa-myapp.yaml"
echo "    4. Wait 24-48h for recommendations"
echo "    5. Review:                         kubectl get vpa -A -o yaml"
echo "    6. Switch to Auto mode when ready: templates/vpa/vpa-auto.yaml"
echo ""
echo "  Templates: ${TEMPLATE_DIR}/"
echo ""
echo "Done."
