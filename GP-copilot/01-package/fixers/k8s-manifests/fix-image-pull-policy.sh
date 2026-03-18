#!/usr/bin/env bash
# fix-image-pull-policy.sh
# Set imagePullPolicy to Always and remove :latest tags in K8s manifests (pre-deploy).
#
# Usage:
#   bash fix-image-pull-policy.sh <manifest.yaml> [--dry-run]
#
# Error codes: Polaris pullPolicyNotAlways
#              Kubescape C-0048
#              Checkov CKV_K8S_15
#
# What it does:
#   - Sets imagePullPolicy: Always on all containers
#   - Flags :latest tags for manual replacement with semver
#   - Creates .bak backup

set -euo pipefail

MANIFEST="${1:?Usage: bash fix-image-pull-policy.sh <manifest.yaml> [--dry-run]}"
DRY_RUN="${2:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ ! -f "$MANIFEST" ]]; then
  echo -e "${RED}ERROR: File not found: $MANIFEST${NC}"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — K8s Image Pull Policy ===${NC}"
echo "  File : $MANIFEST"
echo ""

cp "$MANIFEST" "$MANIFEST.bak"
echo -e "${YELLOW}Backup created: $MANIFEST.bak${NC}"

python3 - "$MANIFEST" "$DRY_RUN" <<'PYEOF'
import sys
import re

filepath = sys.argv[1]
dry_run = len(sys.argv) > 2 and sys.argv[2] == "--dry-run"

with open(filepath) as f:
    content = f.read()

changes = []

# Fix imagePullPolicy: Never or IfNotPresent → Always
for bad_policy in ["IfNotPresent", "Never"]:
    if f"imagePullPolicy: {bad_policy}" in content:
        content = content.replace(f"imagePullPolicy: {bad_policy}", "imagePullPolicy: Always")
        changes.append(f"Changed imagePullPolicy: {bad_policy} → Always")

# Flag :latest tags
latest_matches = re.findall(r"image: (.+):latest", content)
for img in latest_matches:
    changes.append(f"WARNING: {img}:latest found — replace with specific version tag")

# Flag images with no tag at all (implicitly :latest)
no_tag = re.findall(r"image: ([a-z0-9/._-]+)\s*$", content, re.MULTILINE)
for img in no_tag:
    if ":" not in img:
        changes.append(f"WARNING: {img} has no tag (defaults to :latest) — add specific version")

# Add imagePullPolicy: Always if missing entirely
lines = content.split("\n")
result = []
for i, line in enumerate(lines):
    result.append(line)
    if re.match(r"\s+image: ", line) and "imagePullPolicy" not in line:
        # Check if next line already has imagePullPolicy
        if i + 1 < len(lines) and "imagePullPolicy" in lines[i + 1]:
            continue
        indent = len(line) - len(line.lstrip())
        result.append(" " * indent + "imagePullPolicy: Always")
        img_name = line.strip().replace("image: ", "")
        changes.append(f"Added imagePullPolicy: Always for {img_name}")

content = "\n".join(result)

if not changes:
    print("No changes needed — imagePullPolicy already correct.")
    sys.exit(0)

if dry_run:
    print("DRY RUN — changes that would be applied:")
    for c in changes:
        print(f"  • {c}")
else:
    with open(filepath, "w") as f:
        f.write(content)
    print("Changes applied:")
    for c in changes:
        if "WARNING" in c:
            print(f"  ⚠ {c}")
        else:
            print(f"  ✓ {c}")

PYEOF

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Replace any :latest tags with specific versions (semver)"
echo "  2. Consider using image digests: pin-base-image.sh"
echo "  3. Review: diff $MANIFEST.bak $MANIFEST"
echo "  4. Re-scan: polaris audit --audit-path $MANIFEST"
echo "  5. Commit: git commit -m 'security: set imagePullPolicy Always in $(basename $MANIFEST)'"
echo ""
