#!/usr/bin/env bash
# add-nonroot-user.sh
# Add a non-root USER instruction to a Dockerfile.
#
# Usage:
#   bash add-nonroot-user.sh <Dockerfile-path> [uid]
#
# Error codes: Hadolint DL3002, Trivy DS002, Checkov CKV_DOCKER_2
#
# What it does:
#   - Checks if USER instruction already exists
#   - Adds useradd + USER before the final CMD/ENTRYPOINT
#   - Creates .bak backup

set -euo pipefail

DOCKERFILE="${1:-Dockerfile}"
UID_NUM="${2:-10001}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ ! -f "$DOCKERFILE" ]]; then
  echo -e "${RED}ERROR: Dockerfile not found: $DOCKERFILE${NC}"
  echo "Usage: bash add-nonroot-user.sh <Dockerfile-path> [uid]"
  echo "Example: bash add-nonroot-user.sh api/Dockerfile 10001"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — Dockerfile Non-Root User ===${NC}"
echo "  File : $DOCKERFILE"
echo "  UID  : $UID_NUM"
echo ""

# Check if USER already set
if grep -qE "^USER [^0]" "$DOCKERFILE"; then
  EXISTING=$(grep -E "^USER" "$DOCKERFILE")
  echo -e "${GREEN}USER instruction already present: $EXISTING${NC}"
  echo "Verify it is not root (uid 0). If it is, set it to a non-zero UID."
  exit 0
fi

if grep -qE "^USER 0|^USER root" "$DOCKERFILE"; then
  echo -e "${RED}USER is explicitly set to root. Changing to UID $UID_NUM.${NC}"
fi

# Show current last few lines
echo "Current Dockerfile (last 10 lines):"
tail -10 "$DOCKERFILE"
echo ""

# Create backup
cp "$DOCKERFILE" "$DOCKERFILE.bak"
echo -e "${YELLOW}Backup created: $DOCKERFILE.bak${NC}"
echo ""

# Build the USER block to insert
USER_BLOCK="# Security: Run as non-root user (Hadolint DL3002, Checkov CKV_DOCKER_2)\nRUN useradd --uid ${UID_NUM} --no-create-home --shell /bin/false appuser\nUSER ${UID_NUM}"

# Insert before the last CMD or ENTRYPOINT
if grep -qE "^(CMD|ENTRYPOINT)" "$DOCKERFILE"; then
  # Find the last CMD or ENTRYPOINT line number
  LAST_CMD=$(grep -nE "^(CMD|ENTRYPOINT)" "$DOCKERFILE" | tail -1 | cut -d: -f1)
  INSERT_AT=$((LAST_CMD - 1))

  python3 - "$DOCKERFILE" "$INSERT_AT" "$USER_BLOCK" <<'PYEOF'
import sys
filepath, insert_at_str, user_block = sys.argv[1], sys.argv[2], sys.argv[3]
insert_at = int(insert_at_str)
lines = open(filepath).read().splitlines()
# Remove existing USER 0 / USER root lines
lines = [l for l in lines if not l.strip().startswith('USER 0') and not l.strip() == 'USER root']
# Re-find CMD/ENTRYPOINT position after removal
insert_pos = len(lines)
for i, l in enumerate(lines):
    if l.startswith('CMD') or l.startswith('ENTRYPOINT'):
        insert_pos = i
        break
lines.insert(insert_pos, '')
for block_line in reversed(user_block.replace('\\n', '\n').splitlines()):
    lines.insert(insert_pos, block_line)
open(filepath, 'w').write('\n'.join(lines) + '\n')
print(f"Inserted non-root USER block before line {insert_pos + 1}")
PYEOF

else
  # No CMD/ENTRYPOINT — append at end
  echo "" >> "$DOCKERFILE"
  echo -e "$USER_BLOCK" >> "$DOCKERFILE"
  echo "Appended USER block at end of Dockerfile."
fi

echo ""
echo -e "${GREEN}Done. New Dockerfile (last 15 lines):${NC}"
tail -15 "$DOCKERFILE"
echo ""

echo -e "${YELLOW}Important: verify your app can run as UID $UID_NUM${NC}"
echo "  - Files written by the app need correct ownership"
echo "  - Ports < 1024 require NET_BIND_SERVICE capability or port > 1024"
echo "  - If using readOnlyRootFilesystem in K8s, mount emptyDir for /tmp"
echo ""
echo "  If using Python: ensure pip packages installed before USER instruction"
echo "  If using Node: ensure node_modules installed before USER instruction"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Build and test: docker build -t test . && docker run test"
echo "  2. Verify: docker run test id  (should show uid=$UID_NUM)"
echo "  3. Re-scan: hadolint $DOCKERFILE"
echo "  4. Commit: git commit -m 'security: run container as non-root UID $UID_NUM (DL3002)'"
echo ""
