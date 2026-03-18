#!/usr/bin/env bash
# add-security-context.sh
# Add or fix securityContext in K8s manifest YAML files (pre-deploy).
#
# Usage:
#   bash add-security-context.sh <manifest.yaml> [--dry-run]
#
# Error codes: Checkov CKV_K8S_6, CKV_K8S_20, CKV_K8S_22, CKV_K8S_28, CKV_K8S_37
#              Kubescape C-0017, C-0057, C-0055
#              Polaris runAsNonRoot, privilegeEscalation, readOnlyFilesystem
#
# What it does:
#   - Adds pod-level securityContext (runAsNonRoot, seccompProfile)
#   - Adds container-level securityContext (readOnlyRootFilesystem, allowPrivilegeEscalation, drop ALL)
#   - Creates .bak backup
#   - Does NOT touch running clusters — fixes YAML files in the repo

set -euo pipefail

MANIFEST="${1:?Usage: bash add-security-context.sh <manifest.yaml> [--dry-run]}"
DRY_RUN="${2:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ ! -f "$MANIFEST" ]]; then
  echo -e "${RED}ERROR: File not found: $MANIFEST${NC}"
  exit 1
fi

# Validate it's a K8s manifest
if ! grep -qE "^kind:" "$MANIFEST"; then
  echo -e "${RED}ERROR: Not a Kubernetes manifest (no 'kind:' field): $MANIFEST${NC}"
  exit 1
fi

KIND=$(grep -E "^kind:" "$MANIFEST" | head -1 | awk '{print $2}')
echo ""
echo -e "${BLUE}=== Ghost Protocol — K8s SecurityContext Fix ===${NC}"
echo "  File : $MANIFEST"
echo "  Kind : $KIND"
echo ""

# Only patch workload kinds
case "$KIND" in
  Deployment|StatefulSet|DaemonSet|Job|CronJob|Pod|ReplicaSet)
    ;;
  *)
    echo -e "${YELLOW}Skipping $KIND — securityContext applies to workload resources only${NC}"
    exit 0
    ;;
esac

# Create backup
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

# --- Pod-level securityContext ---
pod_security_context = """    securityContext:
      runAsNonRoot: true
      seccompProfile:
        type: RuntimeDefault"""

# Check if pod-level securityContext exists under spec.template.spec
if "template:" in content:
    # Deployment/StatefulSet/DaemonSet/Job — has spec.template.spec
    spec_pattern = r"(  template:\n    metadata:.*?\n    spec:\n)"
    if not re.search(r"    securityContext:", content):
        # Insert after "    spec:\n"
        content = re.sub(
            r"(    spec:\n)",
            r"\1" + pod_security_context + "\n",
            content,
            count=1
        )
        changes.append("Added pod-level securityContext (runAsNonRoot, seccompProfile)")
    else:
        # Ensure runAsNonRoot is true
        if "runAsNonRoot: false" in content:
            content = content.replace("runAsNonRoot: false", "runAsNonRoot: true")
            changes.append("Changed runAsNonRoot: false → true")
elif "kind: Pod" in content:
    # Bare Pod — spec is top-level
    if not re.search(r"  securityContext:", content):
        content = re.sub(
            r"(spec:\n)",
            r"\1  securityContext:\n    runAsNonRoot: true\n    seccompProfile:\n      type: RuntimeDefault\n",
            content,
            count=1
        )
        changes.append("Added pod-level securityContext (runAsNonRoot, seccompProfile)")

# --- Container-level securityContext ---
container_security = """          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL"""

# Find containers that lack securityContext
lines = content.split("\n")
result = []
i = 0
while i < len(lines):
    result.append(lines[i])
    # Detect container entry: "        - name: <container-name>"
    if re.match(r"^        - name: ", lines[i]):
        # Check if this container already has securityContext
        has_sc = False
        j = i + 1
        while j < len(lines) and not re.match(r"^        - name: ", lines[j]) and not re.match(r"^      \w", lines[j]):
            if "securityContext:" in lines[j]:
                has_sc = True
            j += 1
        if not has_sc:
            # Insert securityContext after the container name line
            for sc_line in container_security.split("\n"):
                result.append(sc_line)
            changes.append(f"Added container securityContext for: {lines[i].strip()}")
    i += 1

content = "\n".join(result)

# --- Fix existing bad patterns ---
if "allowPrivilegeEscalation: true" in content:
    content = content.replace("allowPrivilegeEscalation: true", "allowPrivilegeEscalation: false")
    changes.append("Changed allowPrivilegeEscalation: true → false")

if "privileged: true" in content:
    content = content.replace("privileged: true", "privileged: false")
    changes.append("Changed privileged: true → false")

if not changes:
    print("No changes needed — securityContext already present and correct.")
    sys.exit(0)

if dry_run:
    print("DRY RUN — changes that would be applied:")
    for c in changes:
        print(f"  • {c}")
    print("\nRun without --dry-run to apply.")
else:
    with open(filepath, "w") as f:
        f.write(content)
    print("Changes applied:")
    for c in changes:
        print(f"  ✓ {c}")

PYEOF

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review: diff $MANIFEST.bak $MANIFEST"
echo "  2. Validate: kubectl --dry-run=client -f $MANIFEST"
echo "  3. Re-scan: checkov -f $MANIFEST --check CKV_K8S_6,CKV_K8S_20,CKV_K8S_22,CKV_K8S_28"
echo "  4. Commit: git commit -m 'security: add securityContext to $(basename $MANIFEST) (CKV_K8S_6)'"
echo ""
