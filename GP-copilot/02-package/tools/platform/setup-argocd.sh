#!/usr/bin/env bash
# setup-argocd.sh — Install and configure ArgoCD on the cluster
#
# Usage:
#   bash tools/setup-argocd.sh
#   bash tools/setup-argocd.sh --dry-run
#
# What it does:
#   1. Creates argocd namespace
#   2. Installs ArgoCD (stable release)
#   3. Waits for pods to be ready
#   4. Prints the initial admin password
#   5. Sets up port-forward instructions
#
# Prerequisites: kubectl with cluster access, curl

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN="${1:-}"

ARGOCD_VERSION="v2.13.3"
ARGOCD_NAMESPACE="argocd"

echo "=== ArgoCD Setup ==="
echo "Version:   ${ARGOCD_VERSION}"
echo "Namespace: ${ARGOCD_NAMESPACE}"
echo ""

# Check kubectl access
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "ERROR: Cannot connect to Kubernetes cluster."
    echo "       Ensure kubectl is configured and the cluster is reachable."
    exit 1
fi

if [ "$DRY_RUN" = "--dry-run" ]; then
    echo "[DRY RUN] Would install ArgoCD ${ARGOCD_VERSION} into namespace ${ARGOCD_NAMESPACE}"
    echo "[DRY RUN] Would create namespace ${ARGOCD_NAMESPACE}"
    echo "[DRY RUN] Would apply: https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
    echo "[DRY RUN] Would wait for argocd-server deployment"
    exit 0
fi

# Step 1: Create namespace (with PSS labels — Kyverno requires them)
echo "Step 1/6: Creating namespace ${ARGOCD_NAMESPACE}..."
if kubectl get namespace "${ARGOCD_NAMESPACE}" &>/dev/null; then
    echo "  Namespace ${ARGOCD_NAMESPACE} already exists — skipping"
else
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${ARGOCD_NAMESPACE}
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
EOF
fi

# Step 2: Install ArgoCD
echo "Step 2/6: Installing ArgoCD ${ARGOCD_VERSION}..."
kubectl apply -n "${ARGOCD_NAMESPACE}" \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

# Step 3: Wait for rollout
echo "Step 3/6: Waiting for ArgoCD pods to be ready..."
kubectl rollout status deployment/argocd-server -n "${ARGOCD_NAMESPACE}" --timeout=120s
kubectl rollout status deployment/argocd-repo-server -n "${ARGOCD_NAMESPACE}" --timeout=120s
kubectl rollout status deployment/argocd-applicationset-controller -n "${ARGOCD_NAMESPACE}" --timeout=120s

echo ""
echo "Step 4/6: ArgoCD is running."
echo ""

# Step 4: Install ArgoCD CLI
echo "Step 5/6: Installing ArgoCD CLI..."
ARGOCD_CLI_URL="https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"
if command -v argocd > /dev/null 2>&1; then
    INSTALLED_VERSION=$(argocd version --client --short 2>/dev/null || echo "unknown")
    echo "  ArgoCD CLI already installed: ${INSTALLED_VERSION}"
    echo "  Skipping CLI install. To upgrade, run:"
    echo "    sudo curl -sSL -o /usr/local/bin/argocd ${ARGOCD_CLI_URL} && sudo chmod +x /usr/local/bin/argocd"
else
    if sudo curl -sSL -o /usr/local/bin/argocd "${ARGOCD_CLI_URL}" && sudo chmod +x /usr/local/bin/argocd; then
        echo "  ArgoCD CLI installed: $(argocd version --client --short 2>/dev/null)"
    else
        echo "  WARNING: Could not install CLI to /usr/local/bin/ (sudo may be required)."
        echo "  Install manually:"
        echo "    sudo curl -sSL -o /usr/local/bin/argocd ${ARGOCD_CLI_URL}"
        echo "    sudo chmod +x /usr/local/bin/argocd"
    fi
fi

echo ""

# Step 5: Get initial admin password
echo "Step 6/6: Retrieving admin credentials..."
ADMIN_PW=$(kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")

if [ -n "$ADMIN_PW" ]; then
    echo "=== Initial Admin Credentials ==="
    echo "  Username: admin"
    echo "  Password: ${ADMIN_PW}"
    echo ""
    echo "  IMPORTANT: Change this password immediately after first login."
    echo "  Run: argocd account update-password"
else
    echo "  Could not retrieve initial admin password."
    echo "  It may have already been deleted (expected after first login)."
fi

echo ""
echo "=== Access ArgoCD ==="
echo ""
echo "  # Login via CLI (ClusterIP — works on single-node clusters like k3s):"
CLUSTER_IP=$(kubectl -n "${ARGOCD_NAMESPACE}" get svc argocd-server -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
if [ -n "$CLUSTER_IP" ] && [ -n "$ADMIN_PW" ]; then
    echo "  argocd login ${CLUSTER_IP} --insecure --username admin --password '${ADMIN_PW}'"
else
    echo "  argocd login <CLUSTER_IP> --insecure --username admin --password '<admin-password>'"
fi
echo ""
echo "  # Or port forward (for UI access or when ClusterIP is not reachable):"
echo "  kubectl port-forward svc/argocd-server -n ${ARGOCD_NAMESPACE} 8443:443"
echo "  argocd login localhost:8443 --insecure --username admin --password '${ADMIN_PW}'"
echo "  # Then open: https://localhost:8443"
echo ""
echo "=== Next Steps ==="
echo ""
echo "  1. Connect your manifests repo:"
echo "     argocd repo add https://github.com/YOUR_ORG/YOUR_MANIFESTS_REPO.git"
echo ""
echo "  2. Create an app deployment:"
echo "     bash tools/platform/create-app-deployment.sh --app-name myapp --image ghcr.io/org/app:v1.0"
echo ""
echo "  3. Apply the ArgoCD Application:"
echo "     kubectl apply -f myapp/argocd/application-dev.yaml"
echo ""
echo "ArgoCD setup complete."
