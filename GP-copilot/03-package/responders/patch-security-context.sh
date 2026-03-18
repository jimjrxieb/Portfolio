#!/usr/bin/env bash
# =============================================================================
# patch-security-context.sh — Patch a deployment's security context at runtime
# =============================================================================
# Implements: CAPABILITIES.md Responders #1 (Pod Patcher) + #2 (Deployment Updater)
# Rank: D (auto-approved when automated)
#
# Runtime version of 02-CLUSTER-HARDENING/fixers/add-security-context.sh.
# Patches a live deployment with hardened security context settings.
#
# Usage:
#   bash patch-security-context.sh --deployment nginx --namespace production
#   bash patch-security-context.sh --deployment nginx --namespace production --dry-run
#   bash patch-security-context.sh --deployment nginx --namespace production --rollback
# =============================================================================
set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Defaults ---
DEPLOYMENT=""
NAMESPACE=""
DRY_RUN=false
ROLLBACK=false
SNAPSHOT_DIR="/tmp/gp-snapshots"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="${SCRIPT_DIR}/../tools/verify-container-hardening.sh"
TIMESTAMP=$(date -u +%Y%m%d-%H%M%S)

# --- Usage ---
usage() {
    cat <<'USAGE'
Usage: patch-security-context.sh --deployment DEPLOY --namespace NS [--dry-run] [--rollback]

Options:
  --deployment DEPLOY   Name of the deployment to patch
  --namespace NS        Namespace the deployment is in
  --dry-run             Show what would change without applying
  --rollback            Undo the last patch (kubectl rollout undo)
  -h, --help            Show this help

Patches applied:
  Pod level:
    - runAsNonRoot: true
    - runAsUser: 10001
    - fsGroup: 10001
    - seccompProfile: RuntimeDefault
  Container level (all containers):
    - allowPrivilegeEscalation: false
    - capabilities.drop: [ALL]
    - readOnlyRootFilesystem: true

Examples:
  bash patch-security-context.sh --deployment nginx --namespace production
  bash patch-security-context.sh --deployment nginx --namespace production --dry-run
  bash patch-security-context.sh --deployment nginx --namespace production --rollback
USAGE
    exit "${1:-0}"
}

# --- Parse args ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --deployment) DEPLOYMENT="$2"; shift 2 ;;
        --namespace)  NAMESPACE="$2"; shift 2 ;;
        --dry-run)    DRY_RUN=true; shift ;;
        --rollback)   ROLLBACK=true; shift ;;
        -h|--help)    usage 0 ;;
        *)            echo -e "${RED}ERROR: Unknown option: $1${NC}"; usage 1 ;;
    esac
done

if [[ -z "$DEPLOYMENT" || -z "$NAMESPACE" ]]; then
    echo -e "${RED}ERROR: --deployment and --namespace are required${NC}"
    usage 1
fi

# --- Verify deployment exists ---
echo -e "${CYAN}[1/6] Verifying deployment exists...${NC}"
if ! kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}ERROR: Deployment '$DEPLOYMENT' not found in namespace '$NAMESPACE'${NC}"
    exit 1
fi
echo -e "${GREEN}  Found: $DEPLOYMENT in $NAMESPACE${NC}"

# --- Rollback mode ---
if [[ "$ROLLBACK" == true ]]; then
    echo -e "${CYAN}[ROLLBACK] Rolling back deployment $DEPLOYMENT...${NC}"
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}  DRY RUN: Would run kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE${NC}"
        exit 0
    fi
    kubectl rollout undo deployment/"$DEPLOYMENT" -n "$NAMESPACE"
    echo -e "${GREEN}  Rollback initiated. Waiting for rollout...${NC}"
    kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=120s
    echo -e "${GREEN}  Rollback complete.${NC}"
    exit 0
fi

# --- Step 2: Save snapshot ---
echo -e "${CYAN}[2/6] Saving deployment snapshot...${NC}"
mkdir -p "$SNAPSHOT_DIR"
SNAPSHOT_FILE="${SNAPSHOT_DIR}/${DEPLOYMENT}-${TIMESTAMP}.yaml"
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o yaml > "$SNAPSHOT_FILE"
echo -e "${GREEN}  Snapshot saved: $SNAPSHOT_FILE${NC}"

# --- Step 3: Get container names and show diff ---
echo -e "${CYAN}[3/6] Analyzing current security context...${NC}"

CONTAINERS=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[*].name}')

echo -e "  Containers: $CONTAINERS"

# Show current state
echo ""
echo -e "${CYAN}  Current security context:${NC}"
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o json | python3 -c "
import sys, json
dep = json.load(sys.stdin)
spec = dep['spec']['template']['spec']

# Pod-level
pod_sc = spec.get('securityContext', {})
print(f'  Pod-level securityContext:')
if pod_sc:
    for k, v in pod_sc.items():
        print(f'    {k}: {v}')
else:
    print('    (none)')

# Container-level
for c in spec.get('containers', []):
    sc = c.get('securityContext', {})
    print("  Container \"%s\" securityContext:" % c['name'])
    if sc:
        for k, v in sc.items():
            print(f'    {k}: {v}')
    else:
        print('    (none)')
"

echo ""
echo -e "${CYAN}  After patch:${NC}"
echo -e "  Pod-level securityContext:"
echo -e "    runAsNonRoot: true"
echo -e "    runAsUser: 10001"
echo -e "    fsGroup: 10001"
echo -e "    seccompProfile: {type: RuntimeDefault}"
for c in $CONTAINERS; do
    echo -e "  Container \"$c\" securityContext:"
    echo -e "    allowPrivilegeEscalation: false"
    echo -e "    capabilities: {drop: [ALL]}"
    echo -e "    readOnlyRootFilesystem: true"
done

# --- Step 4: Build and apply patch ---
echo ""
echo -e "${CYAN}[4/6] Building strategic merge patch...${NC}"

# Build container patches dynamically
CONTAINER_PATCHES=""
for c in $CONTAINERS; do
    CONTAINER_PATCHES="${CONTAINER_PATCHES}
        {
          \"name\": \"${c}\",
          \"securityContext\": {
            \"allowPrivilegeEscalation\": false,
            \"capabilities\": {\"drop\": [\"ALL\"]},
            \"readOnlyRootFilesystem\": true
          }
        },"
done
# Remove trailing comma
CONTAINER_PATCHES="${CONTAINER_PATCHES%,}"

PATCH_JSON=$(cat <<EOF
{
  "spec": {
    "template": {
      "spec": {
        "securityContext": {
          "runAsNonRoot": true,
          "runAsUser": 10001,
          "fsGroup": 10001,
          "seccompProfile": {"type": "RuntimeDefault"}
        },
        "containers": [${CONTAINER_PATCHES}
        ]
      }
    }
  }
}
EOF
)

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}  DRY RUN: Would apply the following patch:${NC}"
    echo "$PATCH_JSON" | python3 -m json.tool
    echo ""
    echo -e "${YELLOW}  DRY RUN: No changes made.${NC}"
    echo -e "${YELLOW}  Snapshot saved at: $SNAPSHOT_FILE${NC}"
    exit 0
fi

echo -e "  Applying patch..."
kubectl patch deployment "$DEPLOYMENT" -n "$NAMESPACE" \
    --type=strategic \
    -p "$PATCH_JSON"
echo -e "${GREEN}  Patch applied.${NC}"

# --- Step 5: Wait for rollout ---
echo -e "${CYAN}[5/6] Waiting for rollout...${NC}"
if kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=120s; then
    echo -e "${GREEN}  Rollout complete.${NC}"
else
    echo -e "${RED}  Rollout failed or timed out.${NC}"
    echo -e "${YELLOW}  To rollback: bash $0 --deployment $DEPLOYMENT --namespace $NAMESPACE --rollback${NC}"
    echo -e "${YELLOW}  Or manually: kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE${NC}"
    exit 1
fi

# --- Step 6: Verify ---
echo -e "${CYAN}[6/6] Verifying security context...${NC}"
if [[ -f "$VERIFY_SCRIPT" ]]; then
    bash "$VERIFY_SCRIPT" --namespace "$NAMESPACE" 2>/dev/null || true
else
    # Inline verification
    echo -e "  (verify-container-hardening.sh not found, doing inline check)"
    kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o json | python3 -c "
import sys, json
dep = json.load(sys.stdin)
spec = dep['spec']['template']['spec']
pod_sc = spec.get('securityContext', {})
ok = True

checks = [
    ('runAsNonRoot', pod_sc.get('runAsNonRoot') == True),
    ('runAsUser=10001', pod_sc.get('runAsUser') == 10001),
    ('fsGroup=10001', pod_sc.get('fsGroup') == 10001),
    ('seccompProfile', pod_sc.get('seccompProfile', {}).get('type') == 'RuntimeDefault'),
]
for name, passed in checks:
    status = '\033[0;32mPASS\033[0m' if passed else '\033[0;31mFAIL\033[0m'
    print(f'  {status}  Pod: {name}')
    if not passed: ok = False

for c in spec.get('containers', []):
    sc = c.get('securityContext', {})
    cchecks = [
        ('allowPrivilegeEscalation=false', sc.get('allowPrivilegeEscalation') == False),
        ('capabilities.drop=[ALL]', 'ALL' in sc.get('capabilities', {}).get('drop', [])),
        ('readOnlyRootFilesystem=true', sc.get('readOnlyRootFilesystem') == True),
    ]
    for name, passed in cchecks:
        status = '\033[0;32mPASS\033[0m' if passed else '\033[0;31mFAIL\033[0m'
        print("  %s  Container \"%s\": %s" % (status, c['name'], name))
        if not passed: ok = False

if ok:
    print('\n  \033[0;32mAll security context checks passed.\033[0m')
else:
    print('\n  \033[0;31mSome checks failed. Review the deployment.\033[0m')
"
fi

# --- Summary ---
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  SECURITY CONTEXT PATCHED: $DEPLOYMENT${NC}"
echo -e "${GREEN}============================================${NC}"
echo -e "  Namespace:  $NAMESPACE"
echo -e "  Snapshot:   $SNAPSHOT_FILE"
echo -e "  Timestamp:  $TIMESTAMP"
echo ""
echo -e "${CYAN}To rollback:${NC}"
echo -e "  bash $0 --deployment $DEPLOYMENT --namespace $NAMESPACE --rollback"
echo -e "  # Or restore snapshot: kubectl apply -f $SNAPSHOT_FILE"
