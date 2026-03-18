#!/usr/bin/env bash
# pin-base-image.sh
# Replace image tags with pinned digests in Dockerfiles and K8s manifests (pre-deploy).
#
# Usage:
#   bash pin-base-image.sh <Dockerfile|manifest.yaml> [--dry-run]
#
# Error codes: Checkov CKV_DOCKER_7
#              Kubescape C-0048 (partial)
#
# CKS alignment: Supply chain security — prevent tag mutation attacks.
# An attacker who compromises a registry can push malicious content to :latest or :v1.0.
# Pinning to @sha256:digest ensures you get exactly the image you verified.
#
# What it does:
#   - Finds image references using :tag (not @sha256:)
#   - Resolves the current digest via docker manifest inspect or skopeo
#   - Replaces :tag with @sha256:<digest>
#   - Creates .bak backup
#
# Requires: docker CLI or skopeo (for digest resolution)

set -euo pipefail

TARGET="${1:?Usage: bash pin-base-image.sh <Dockerfile|manifest.yaml> [--dry-run]}"
DRY_RUN="${2:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ ! -f "$TARGET" ]]; then
  echo -e "${RED}ERROR: File not found: $TARGET${NC}"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — Pin Image Digests ===${NC}"
echo "  File : $TARGET"
echo ""

# Detect tool for digest resolution
RESOLVER=""
if command -v skopeo &>/dev/null; then
  RESOLVER="skopeo"
elif command -v docker &>/dev/null; then
  RESOLVER="docker"
else
  echo -e "${RED}ERROR: Neither skopeo nor docker found. Install one to resolve digests.${NC}"
  echo "  apt install skopeo   OR   docker must be running"
  exit 1
fi
echo "  Resolver: $RESOLVER"
echo ""

cp "$TARGET" "$TARGET.bak"
echo -e "${YELLOW}Backup created: $TARGET.bak${NC}"

# Extract image references
if grep -qE "^FROM " "$TARGET"; then
  # Dockerfile — extract FROM lines
  IMAGES=$(grep -E "^FROM " "$TARGET" | sed 's/FROM //; s/ [aA][sS] .*//' | grep -v '@sha256:' || true)
elif grep -qE "image:" "$TARGET"; then
  # K8s manifest — extract image: lines
  IMAGES=$(grep -E "^\s+image:" "$TARGET" | sed 's/.*image: //; s/"//g; s/'"'"'//g' | grep -v '@sha256:' || true)
else
  echo -e "${GREEN}No image references found to pin.${NC}"
  exit 0
fi

if [[ -z "$IMAGES" ]]; then
  echo -e "${GREEN}All images already pinned to digests.${NC}"
  exit 0
fi

CHANGES=0
while IFS= read -r IMAGE; do
  [[ -z "$IMAGE" ]] && continue

  echo -n "  Resolving $IMAGE ... "

  DIGEST=""
  if [[ "$RESOLVER" == "skopeo" ]]; then
    DIGEST=$(skopeo inspect "docker://$IMAGE" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('Digest',''))" 2>/dev/null || true)
  else
    DIGEST=$(docker manifest inspect "$IMAGE" 2>/dev/null | python3 -c "
import sys, json, hashlib
data = sys.stdin.read()
digest = hashlib.sha256(data.encode()).hexdigest()
manifest = json.loads(data)
# Use the manifest list digest if available
for m in manifest.get('manifests', []):
    if m.get('platform', {}).get('architecture') == 'amd64':
        print(m['digest']); sys.exit()
# Fallback: use config digest
print(manifest.get('config', {}).get('digest', ''))
" 2>/dev/null || true)
  fi

  if [[ -z "$DIGEST" ]]; then
    echo -e "${YELLOW}SKIP (could not resolve digest — registry unreachable?)${NC}"
    continue
  fi

  # Extract repo without tag
  REPO="${IMAGE%%:*}"
  PINNED="${REPO}@${DIGEST}"

  if [[ "$DRY_RUN" == "--dry-run" ]]; then
    echo -e "${BLUE}would pin → $PINNED${NC}"
  else
    # Escape for sed
    ESCAPED_IMAGE=$(printf '%s' "$IMAGE" | sed 's/[.[\*^$()+?{|]/\\&/g')
    ESCAPED_PINNED=$(printf '%s' "$PINNED" | sed 's/[&/\]/\\&/g')
    sed -i "s|${IMAGE}|${PINNED}|g" "$TARGET"
    echo -e "${GREEN}pinned → $PINNED${NC}"
  fi
  CHANGES=$((CHANGES + 1))

done <<< "$IMAGES"

echo ""
if [[ $CHANGES -eq 0 ]]; then
  echo -e "${GREEN}No changes needed.${NC}"
else
  echo -e "${GREEN}$CHANGES image(s) pinned to digest.${NC}"
fi

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review: diff $TARGET.bak $TARGET"
echo "  2. Test build: docker build -t test . (if Dockerfile)"
echo "  3. Re-scan: checkov -f $TARGET --check CKV_DOCKER_7"
echo "  4. Commit: git commit -m 'supply-chain: pin image digests in $(basename $TARGET)'"
echo ""
echo -e "${YELLOW}Maintenance: Re-run periodically to pick up security patches in base images.${NC}"
echo "  Automate with: dependabot or renovate for digest updates"
echo ""
