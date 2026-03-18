#!/usr/bin/env bash
# add-security-context.sh
# Add a hardened securityContext to a Kubernetes Deployment manifest.
#
# Usage:
#   bash add-security-context.sh <manifest.yaml> [uid]
#
# Error codes:
#   Checkov CKV_K8S_6, CKV_K8S_20, CKV_K8S_22, CKV_K8S_25, CKV_K8S_28, CKV_K8S_30
#   Kubescape C-0013, C-0016, C-0017, C-0034, C-0046, C-0055
#   Trivy KSV001, KSV003, KSV020, KSV021
#
# What it does:
#   - Prints the full hardened securityContext block to add
#   - Shows exactly where it goes in the manifest
#   - Creates .bak backup
#   - Note: YAML patching is complex — this guides you through it

set -euo pipefail

MANIFEST="${1:-}"
RUN_AS_USER="${2:-10001}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$MANIFEST" || ! -f "$MANIFEST" ]]; then
  echo "Usage: bash add-security-context.sh <manifest.yaml> [uid]"
  echo ""
  echo "Example:"
  echo "  bash add-security-context.sh infrastructure/api-deployment.yaml 10001"
  echo "  bash add-security-context.sh infrastructure/db-deployment.yaml 999"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — K8s Security Context ===${NC}"
echo "  File : $MANIFEST"
echo "  UID  : $RUN_AS_USER"
echo ""

# Check what's already there
echo "Checking current securityContext settings..."
echo ""

HAS_POD_SC=$(grep -c "securityContext:" "$MANIFEST" || true)
HAS_RUN_AS_NON_ROOT=$(grep -c "runAsNonRoot" "$MANIFEST" || true)
HAS_CAPS=$(grep -c "capabilities:" "$MANIFEST" || true)
HAS_READONLY=$(grep -c "readOnlyRootFilesystem" "$MANIFEST" || true)
HAS_PRIV_ESC=$(grep -c "allowPrivilegeEscalation" "$MANIFEST" || true)

if [[ $HAS_RUN_AS_NON_ROOT -gt 0 ]]; then
  echo -e "  ${GREEN}✓ runAsNonRoot — present${NC}"
else
  echo -e "  ${RED}✗ runAsNonRoot — MISSING${NC}"
fi

if [[ $HAS_CAPS -gt 0 ]]; then
  echo -e "  ${GREEN}✓ capabilities — present${NC}"
else
  echo -e "  ${RED}✗ capabilities drop ALL — MISSING${NC}"
fi

if [[ $HAS_READONLY -gt 0 ]]; then
  echo -e "  ${GREEN}✓ readOnlyRootFilesystem — present${NC}"
else
  echo -e "  ${YELLOW}⚠ readOnlyRootFilesystem — MISSING (add if app supports it)${NC}"
fi

if [[ $HAS_PRIV_ESC -gt 0 ]]; then
  echo -e "  ${GREEN}✓ allowPrivilegeEscalation — present${NC}"
else
  echo -e "  ${RED}✗ allowPrivilegeEscalation: false — MISSING${NC}"
fi

echo ""

# Create backup
cp "$MANIFEST" "$MANIFEST.bak"
echo -e "${YELLOW}Backup created: $MANIFEST.bak${NC}"
echo ""

# Print the full hardened securityContext blocks to apply
echo -e "${GREEN}Add the following to your Deployment manifest:${NC}"
echo ""
echo -e "${BLUE}--- Pod-level securityContext (under spec.template.spec) ---${NC}"
cat <<YAML
      securityContext:
        runAsNonRoot: true
        runAsUser: ${RUN_AS_USER}
        fsGroup: ${RUN_AS_USER}
        seccompProfile:
          type: RuntimeDefault
YAML

echo ""
echo -e "${BLUE}--- Container-level securityContext (under each container) ---${NC}"
cat <<YAML
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: ${RUN_AS_USER}
            capabilities:
              drop:
                - ALL
YAML

echo ""
echo -e "${BLUE}--- If readOnlyRootFilesystem: true, add a writable /tmp volume ---${NC}"
cat <<YAML
        # Under spec.template.spec.containers[].volumeMounts:
          volumeMounts:
            - name: tmp-volume
              mountPath: /tmp
        # Under spec.template.spec.volumes:
        volumes:
          - name: tmp-volume
            emptyDir: {}
YAML

echo ""
echo -e "${YELLOW}Placement guide:${NC}"
echo ""
cat <<'GUIDE'
  apiVersion: apps/v1
  kind: Deployment
  spec:
    template:
      spec:
        securityContext:        ← POD-LEVEL (add here)
          runAsNonRoot: true
          ...
        containers:
          - name: app
            image: app:v1.0.0
            securityContext:   ← CONTAINER-LEVEL (add here, inside containers[])
              allowPrivilegeEscalation: false
              ...
GUIDE

echo ""

# Check if yq is available for auto-patching
if command -v yq &>/dev/null; then
  echo -e "${YELLOW}yq detected. Applying pod-level securityContext automatically...${NC}"
  echo ""

  yq -i ".spec.template.spec.securityContext.runAsNonRoot = true" "$MANIFEST"
  yq -i ".spec.template.spec.securityContext.runAsUser = ${RUN_AS_USER}" "$MANIFEST"
  yq -i ".spec.template.spec.securityContext.fsGroup = ${RUN_AS_USER}" "$MANIFEST"
  yq -i '.spec.template.spec.securityContext.seccompProfile.type = "RuntimeDefault"' "$MANIFEST"

  echo -e "${GREEN}Pod-level securityContext applied.${NC}"
  echo -e "${YELLOW}Container-level securityContext requires manual addition (multi-container safety).${NC}"
else
  echo -e "${YELLOW}yq not installed — manual application required.${NC}"
  echo "  Install yq for auto-patching: https://github.com/mikefarah/yq"
  echo "  brew install yq  OR  snap install yq"
fi

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Apply container-level securityContext manually (see above)"
echo "  2. If readOnlyRootFilesystem: add tmp-volume mount"
echo "  3. Test in cluster: kubectl apply -f $MANIFEST --dry-run=client"
echo "  4. Re-scan: checkov -f $MANIFEST --check CKV_K8S_20,CKV_K8S_28,CKV_K8S_30"
echo "  5. Commit: git commit -m 'security: add pod/container securityContext (CKV_K8S_28)'"
echo ""
