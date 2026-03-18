#!/usr/bin/env bash
# add-resource-limits.sh
# Add resource requests and limits to K8s manifest YAML files (pre-deploy).
#
# Usage:
#   bash add-resource-limits.sh <manifest.yaml> [--dry-run]
#
# Error codes: Checkov CKV_K8S_11, CKV_K8S_12, CKV_K8S_13
#              Kubescape C-0009, C-0050
#              Polaris cpuLimitsMissing, memoryLimitsMissing
#
# What it does:
#   - Adds resources.requests and resources.limits to containers missing them
#   - Default: 100m/128Mi requests, 500m/512Mi limits (safe for most workloads)
#   - Creates .bak backup

set -euo pipefail

MANIFEST="${1:?Usage: bash add-resource-limits.sh <manifest.yaml> [--dry-run]}"
DRY_RUN="${2:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# Defaults — override via env vars
CPU_REQ="${CPU_REQUEST:-100m}"
CPU_LIM="${CPU_LIMIT:-500m}"
MEM_REQ="${MEM_REQUEST:-128Mi}"
MEM_LIM="${MEM_LIMIT:-512Mi}"

if [[ ! -f "$MANIFEST" ]]; then
  echo -e "${RED}ERROR: File not found: $MANIFEST${NC}"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — K8s Resource Limits ===${NC}"
echo "  File     : $MANIFEST"
echo "  Requests : cpu=$CPU_REQ, memory=$MEM_REQ"
echo "  Limits   : cpu=$CPU_LIM, memory=$MEM_LIM"
echo ""

cp "$MANIFEST" "$MANIFEST.bak"
echo -e "${YELLOW}Backup created: $MANIFEST.bak${NC}"

python3 - "$MANIFEST" "$DRY_RUN" "$CPU_REQ" "$CPU_LIM" "$MEM_REQ" "$MEM_LIM" <<'PYEOF'
import sys
import re

filepath = sys.argv[1]
dry_run = len(sys.argv) > 2 and sys.argv[2] == "--dry-run"
cpu_req, cpu_lim, mem_req, mem_lim = sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6]

with open(filepath) as f:
    lines = f.read().split("\n")

resources_block = [
    "          resources:",
    f"            requests:",
    f"              cpu: \"{cpu_req}\"",
    f"              memory: \"{mem_req}\"",
    f"            limits:",
    f"              cpu: \"{cpu_lim}\"",
    f"              memory: \"{mem_lim}\"",
]

result = []
changes = []
i = 0
while i < len(lines):
    result.append(lines[i])
    # Detect container entry
    if re.match(r"^        - name: ", lines[i]):
        container_name = lines[i].strip().replace("- name: ", "")
        # Check if this container already has resources
        has_resources = False
        j = i + 1
        while j < len(lines) and not re.match(r"^        - name: ", lines[j]) and not re.match(r"^      \w", lines[j]):
            if "resources:" in lines[j]:
                has_resources = True
            j += 1
        if not has_resources:
            for rl in resources_block:
                result.append(rl)
            changes.append(f"Added resource limits for container: {container_name}")
    i += 1

if not changes:
    print("No changes needed — all containers already have resource limits.")
    sys.exit(0)

content = "\n".join(result)

if dry_run:
    print("DRY RUN — changes that would be applied:")
    for c in changes:
        print(f"  • {c}")
else:
    with open(filepath, "w") as f:
        f.write(content)
    print("Changes applied:")
    for c in changes:
        print(f"  ✓ {c}")

PYEOF

echo ""
echo -e "${YELLOW}Tune limits for your workload:${NC}"
echo "  CPU_REQUEST=200m CPU_LIMIT=1 bash add-resource-limits.sh $MANIFEST"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review: diff $MANIFEST.bak $MANIFEST"
echo "  2. Validate: kubectl --dry-run=client -f $MANIFEST"
echo "  3. Re-scan: checkov -f $MANIFEST --check CKV_K8S_11,CKV_K8S_12,CKV_K8S_13"
echo "  4. Commit: git commit -m 'security: add resource limits to $(basename $MANIFEST) (CKV_K8S_11)'"
echo ""
