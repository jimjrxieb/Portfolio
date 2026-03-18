#!/usr/bin/env bash
# =============================================================================
# Ghost Protocol -- new-team.sh
# One-command developer team onboarding
# Creates namespace, RBAC, secrets, golden path, and Backstage registration
#
# Usage:
#   bash tools/platform/new-team.sh --team-name payments
#   bash tools/platform/new-team.sh --team-name payments --app-name payments-api --backstage
#   bash tools/platform/new-team.sh --team-name payments --dry-run
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Defaults
TEAM_NAME=""
AWS_REGION="us-east-1"
APP_NAME=""
BACKSTAGE=false
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
    echo "  --team-name   NAME    Team name (required — used as namespace)"
    echo "  --aws-region  REGION  AWS region for ExternalSecrets (default: us-east-1)"
    echo "  --app-name    NAME    Application name (default: team-name)"
    echo "  --backstage           Register the team in Backstage catalog"
    echo "  --dry-run             Print what would be done, do not apply"
    echo "  -h, --help            Show this help"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --team-name)   TEAM_NAME="${2:-}"; shift 2 ;;
        --aws-region)  AWS_REGION="${2:-}"; shift 2 ;;
        --app-name)    APP_NAME="${2:-}"; shift 2 ;;
        --backstage)   BACKSTAGE=true; shift ;;
        --dry-run)     DRY_RUN=true; shift ;;
        -h|--help)     usage ;;
        *)             die "Unknown option: $1" ;;
    esac
done

# Validate required args
[ -n "$TEAM_NAME" ] || die "--team-name is required"

# Sanitize: lowercase, alphanumeric + hyphens only
TEAM_NAME=$(echo "$TEAM_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

# Default app name to team name
[ -n "$APP_NAME" ] || APP_NAME="$TEAM_NAME"
APP_NAME=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

SA_NAME="${TEAM_NAME}-deployer"

# ── Pre-flight checks ─────────────────────────────────────────────────────
log_section "Pre-flight checks"

command -v kubectl >/dev/null 2>&1 || die "kubectl not found."
kubectl cluster-info >/dev/null 2>&1 || die "Cannot connect to Kubernetes cluster."
log_ok "Cluster reachable"

if kubectl get namespace "$TEAM_NAME" >/dev/null 2>&1; then
    log_warn "Namespace '${TEAM_NAME}' already exists — steps will update in-place"
fi

log_info "Team:       ${TEAM_NAME}"
log_info "App:        ${APP_NAME}"
log_info "Region:     ${AWS_REGION}"
log_info "Backstage:  ${BACKSTAGE}"
log_info "Dry run:    ${DRY_RUN}"

# ── Step 1: Namespace + ResourceQuota + LimitRange + PSS ──────────────────
log_section "Step 1 — Namespace (PSS restricted + ResourceQuota + LimitRange)"

NAMESPACE_MANIFEST=$(cat <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${TEAM_NAME}
  labels:
    app.kubernetes.io/managed-by: gp-copilot
    team: ${TEAM_NAME}
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${TEAM_NAME}-quota
  namespace: ${TEAM_NAME}
  labels:
    app.kubernetes.io/managed-by: gp-copilot
spec:
  hard:
    cpu: "8"
    memory: 16Gi
    count/deployments.apps: "20"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: ${TEAM_NAME}-limits
  namespace: ${TEAM_NAME}
  labels:
    app.kubernetes.io/managed-by: gp-copilot
spec:
  limits:
    - type: Container
      default:
        cpu: 500m
        memory: 512Mi
      defaultRequest:
        cpu: 250m
        memory: 256Mi
EOF
)

if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would create namespace '${TEAM_NAME}' with PSS restricted, ResourceQuota, and LimitRange"
    echo "$NAMESPACE_MANIFEST"
else
    echo "$NAMESPACE_MANIFEST" | kubectl apply -f -
    log_ok "Namespace '${TEAM_NAME}' created with PSS restricted"
    log_ok "ResourceQuota: cpu=8, memory=16Gi, deployments=20"
    log_ok "LimitRange: default cpu=250m/500m, memory=256Mi/512Mi"
fi

# ── Step 2: RBAC — Role + RoleBinding ──────────────────────────────────────
log_section "Step 2 — RBAC (ServiceAccount + Role + RoleBinding)"

RBAC_MANIFEST=$(cat <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${SA_NAME}
  namespace: ${TEAM_NAME}
  labels:
    app.kubernetes.io/managed-by: gp-copilot
    team: ${TEAM_NAME}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${TEAM_NAME}-developer
  namespace: ${TEAM_NAME}
  labels:
    app.kubernetes.io/managed-by: gp-copilot
    team: ${TEAM_NAME}
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "secrets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["events", "endpoints"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${TEAM_NAME}-developer-binding
  namespace: ${TEAM_NAME}
  labels:
    app.kubernetes.io/managed-by: gp-copilot
    team: ${TEAM_NAME}
subjects:
  - kind: ServiceAccount
    name: ${SA_NAME}
    namespace: ${TEAM_NAME}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ${TEAM_NAME}-developer
EOF
)

if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would create ServiceAccount '${SA_NAME}', Role, and RoleBinding in '${TEAM_NAME}'"
    echo "$RBAC_MANIFEST"
else
    echo "$RBAC_MANIFEST" | kubectl apply -f -
    log_ok "ServiceAccount '${SA_NAME}' created"
    log_ok "Role '${TEAM_NAME}-developer' bound to '${SA_NAME}'"
fi

# ── Step 3: ExternalSecrets — SecretStore + sample ExternalSecret ──────────
log_section "Step 3 — ExternalSecrets (SecretStore + sample ExternalSecret)"

SECRETS_MANIFEST=$(cat <<EOF
---
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: ${TEAM_NAME}-secrets
  namespace: ${TEAM_NAME}
  labels:
    app.kubernetes.io/managed-by: gp-copilot
    team: ${TEAM_NAME}
    control: SC-12
spec:
  provider:
    aws:
      service: SecretsManager
      region: ${AWS_REGION}
      auth:
        jwt:
          serviceAccountRef:
            name: ${SA_NAME}
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ${TEAM_NAME}-app-secrets
  namespace: ${TEAM_NAME}
  labels:
    app.kubernetes.io/managed-by: gp-copilot
    team: ${TEAM_NAME}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: ${TEAM_NAME}-secrets
    kind: SecretStore
  target:
    name: ${TEAM_NAME}-app-secrets
    creationPolicy: Owner
  data:
    - secretKey: DB_PASSWORD
      remoteRef:
        key: ${TEAM_NAME}/db-password
    - secretKey: API_KEY
      remoteRef:
        key: ${TEAM_NAME}/api-key
EOF
)

# Check if ESO CRDs are installed
if kubectl get crd externalsecrets.external-secrets.io >/dev/null 2>&1; then
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would create SecretStore and sample ExternalSecret in '${TEAM_NAME}'"
        echo "$SECRETS_MANIFEST"
    else
        echo "$SECRETS_MANIFEST" | kubectl apply -f -
        log_ok "SecretStore '${TEAM_NAME}-secrets' created (AWS Secrets Manager, ${AWS_REGION})"
        log_ok "Sample ExternalSecret '${TEAM_NAME}-app-secrets' created"
        log_info "Populate secrets in AWS: ${TEAM_NAME}/db-password, ${TEAM_NAME}/api-key"
    fi
else
    log_warn "External Secrets Operator CRDs not found — skipping secret wiring"
    log_info "Install ESO first: bash tools/platform/setup-external-secrets.sh --backend aws"
fi

# ── Step 4: Golden path scaffold ──────────────────────────────────────────
log_section "Step 4 — Golden path scaffold"

GOLDEN_PATH_SCRIPT="${SCRIPT_DIR}/create-app-deployment.sh"

if [ -x "$GOLDEN_PATH_SCRIPT" ] || [ -f "$GOLDEN_PATH_SCRIPT" ]; then
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would run: create-app-deployment.sh --app-name ${APP_NAME} --namespace ${TEAM_NAME}"
    else
        log_info "Running golden path scaffold..."
        bash "$GOLDEN_PATH_SCRIPT" --app-name "$APP_NAME" --namespace "$TEAM_NAME"
        log_ok "Golden path scaffolded for '${APP_NAME}' in namespace '${TEAM_NAME}'"
    fi
else
    log_warn "create-app-deployment.sh not found at ${GOLDEN_PATH_SCRIPT}"
    log_info "Scaffold manually: bash tools/platform/create-app-deployment.sh --app-name ${APP_NAME} --namespace ${TEAM_NAME}"
fi

# ── Step 5: Backstage registration ─────────────────────────────────────────
if [ "$BACKSTAGE" = true ]; then
    log_section "Step 5 — Backstage catalog registration"

    CATALOG_INFO=$(cat <<EOF
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ${APP_NAME}
  namespace: ${TEAM_NAME}
  annotations:
    backstage.io/kubernetes-namespace: ${TEAM_NAME}
    backstage.io/kubernetes-label-selector: app=${APP_NAME}
    github.com/project-slug: linkops-industries/${APP_NAME}
  labels:
    team: ${TEAM_NAME}
  tags:
    - kubernetes
    - gp-copilot
spec:
  type: service
  lifecycle: production
  owner: ${TEAM_NAME}
  system: gp-platform
EOF
    )

    CATALOG_DIR="${PACKAGE_DIR}/backstage/catalog"
    CATALOG_FILE="${CATALOG_DIR}/${TEAM_NAME}-${APP_NAME}.yaml"

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would write Backstage catalog-info to ${CATALOG_FILE}"
        echo "$CATALOG_INFO"
    else
        mkdir -p "$CATALOG_DIR"
        echo "$CATALOG_INFO" > "$CATALOG_FILE"
        log_ok "Backstage catalog-info written to ${CATALOG_FILE}"
        log_info "Register in Backstage: Import the YAML via the Backstage catalog or commit to your manifests repo"
    fi
else
    log_section "Step 5 — Backstage (skipped, use --backstage to enable)"
fi

# ── Step 6: Summary ───────────────────────────────────────────────────────
log_section "Summary"
echo ""
echo "  Team namespace:      ${TEAM_NAME}"
echo "  ServiceAccount:      ${SA_NAME}"
echo "  App name:            ${APP_NAME}"
echo "  PSS enforcement:     restricted"
echo "  ResourceQuota:       cpu=8, memory=16Gi, deployments=20"
echo "  LimitRange:          cpu=250m/500m, memory=256Mi/512Mi"
echo "  SecretStore:         ${TEAM_NAME}-secrets (AWS ${AWS_REGION})"
if [ "$BACKSTAGE" = true ]; then
    echo "  Backstage:           registered"
fi
echo ""
echo "  Next steps for the developer:"
echo "    1. Populate AWS secrets:  aws secretsmanager create-secret --name ${TEAM_NAME}/db-password --secret-string 'changeme'"
echo "    2. Deploy your app:       kubectl apply -k ${APP_NAME}/overlays/dev/"
echo "    3. Verify secrets sync:   kubectl get externalsecret -n ${TEAM_NAME}"
echo "    4. Check quota usage:     kubectl describe resourcequota -n ${TEAM_NAME}"
echo ""
echo "Done."
