#!/usr/bin/env bash
# add-probes.sh
# Add liveness and readiness probes to K8s manifest YAML files (pre-deploy).
#
# Usage:
#   bash add-probes.sh <manifest.yaml> [--port 8080] [--liveness-path /healthz] [--readiness-path /ready] [--dry-run]
#
# Error codes: Polaris readinessProbeMissing, livenessProbeMissing
#              Checkov CKV_K8S_8, CKV_K8S_9
#              Kubescape C-0018
#
# Rank: C (context-dependent — needs app endpoint check)
#
# What it does:
#   - Adds livenessProbe and readinessProbe to containers missing them
#   - Default: liveness → HTTP GET /healthz:8080, readiness → HTTP GET /ready:8080
#   - Liveness checks PROCESS health only (never external deps)
#   - Readiness checks dependency health (DB, DNS, cache)
#   - Creates .bak backup
#
# IMPORTANT: Liveness and readiness probes serve DIFFERENT purposes.
#   Liveness  = "Is the process alive?" → kills pod on failure (restart)
#   Readiness = "Can it serve traffic?" → removes from Service endpoints
#   NEVER use a deep health check (?full=true, dep checks) on liveness.
#   A brief DNS/DB hiccup will cause unnecessary pod restarts.

set -euo pipefail

MANIFEST=""
PROBE_PORT="8080"
LIVENESS_PATH="/healthz"
READINESS_PATH="/ready"
DRY_RUN=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PROBE_PORT="$2"; shift 2 ;;
    --path) LIVENESS_PATH="$2"; READINESS_PATH="$2"; shift 2 ;;
    --liveness-path) LIVENESS_PATH="$2"; shift 2 ;;
    --readiness-path) READINESS_PATH="$2"; shift 2 ;;
    --dry-run) DRY_RUN="--dry-run"; shift ;;
    *) MANIFEST="$1"; shift ;;
  esac
done

if [[ -z "$MANIFEST" ]]; then
  echo "Usage: bash add-probes.sh <manifest.yaml> [--port 8080] [--liveness-path /healthz] [--readiness-path /ready] [--dry-run]"
  exit 1
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ ! -f "$MANIFEST" ]]; then
  echo -e "${RED}ERROR: File not found: $MANIFEST${NC}"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — K8s Health Probes ===${NC}"
echo "  File           : $MANIFEST"
echo "  Port           : $PROBE_PORT"
echo "  Liveness path  : $LIVENESS_PATH (process health only — no dep checks)"
echo "  Readiness path : $READINESS_PATH (can check dependencies)"
echo -e "  ${YELLOW}NOTE: C-rank — verify your app serves both endpoints on port $PROBE_PORT${NC}"
echo ""

cp "$MANIFEST" "$MANIFEST.bak"
echo -e "${YELLOW}Backup created: $MANIFEST.bak${NC}"

python3 - "$MANIFEST" "$DRY_RUN" "$PROBE_PORT" "$LIVENESS_PATH" "$READINESS_PATH" <<'PYEOF'
import sys
import re

filepath = sys.argv[1]
dry_run = sys.argv[2] == "--dry-run" if len(sys.argv) > 2 else False
port = sys.argv[3] if len(sys.argv) > 3 else "8080"
liveness_path = sys.argv[4] if len(sys.argv) > 4 else "/healthz"
readiness_path = sys.argv[5] if len(sys.argv) > 5 else "/ready"

with open(filepath) as f:
    lines = f.read().split("\n")

# Liveness: checks PROCESS health only. Generous timeouts to avoid false kills.
# Readiness: checks dependency health. Tighter timeouts OK — just removes from LB.
probes_block = [
    "          livenessProbe:",
    "            httpGet:",
    f"              path: {liveness_path}",
    f"              port: {port}",
    "            initialDelaySeconds: 30",
    "            periodSeconds: 20",
    "            timeoutSeconds: 10",
    "            failureThreshold: 6",
    "          readinessProbe:",
    "            httpGet:",
    f"              path: {readiness_path}",
    f"              port: {port}",
    "            initialDelaySeconds: 5",
    "            periodSeconds: 10",
    "            timeoutSeconds: 5",
    "            failureThreshold: 3",
]

result = []
changes = []
i = 0
while i < len(lines):
    result.append(lines[i])
    if re.match(r"^        - name: ", lines[i]):
        container_name = lines[i].strip().replace("- name: ", "")
        has_liveness = False
        has_readiness = False
        j = i + 1
        while j < len(lines) and not re.match(r"^        - name: ", lines[j]) and not re.match(r"^      \w", lines[j]):
            if "livenessProbe:" in lines[j]:
                has_liveness = True
            if "readinessProbe:" in lines[j]:
                has_readiness = True
            j += 1
        if not has_liveness or not has_readiness:
            added = []
            for pl in probes_block:
                if "liveness" in pl and has_liveness:
                    continue
                if "readiness" in pl and has_readiness:
                    continue
                result.append(pl)
            if not has_liveness:
                added.append("livenessProbe")
            if not has_readiness:
                added.append("readinessProbe")
            if added:
                changes.append(f"Added {', '.join(added)} for container: {container_name}")
    i += 1

if not changes:
    print("No changes needed — all containers already have probes.")
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
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. VERIFY your app serves $LIVENESS_PATH (process-only) and $READINESS_PATH (deps) on port $PROBE_PORT"
echo "     (C-rank — human check. Liveness must NOT check external deps or you'll get restart loops)"
echo "  2. Review: diff $MANIFEST.bak $MANIFEST"
echo "  3. Validate: kubectl --dry-run=client -f $MANIFEST"
echo "  4. Re-scan: polaris audit --audit-path $MANIFEST"
echo "  5. Commit: git commit -m 'security: add health probes to $(basename $MANIFEST) (CKV_K8S_8)'"
echo ""
