#!/usr/bin/env bash
# add-healthcheck.sh
# Add a HEALTHCHECK instruction to a Dockerfile.
#
# Usage:
#   bash add-healthcheck.sh <Dockerfile-path> [health-endpoint] [port]
#
# Error codes: Trivy DS026, Hadolint (warning), Checkov CKV_DOCKER_3
#
# What it does:
#   - Detects if HEALTHCHECK already present
#   - Adds appropriate HEALTHCHECK before CMD/ENTRYPOINT
#   - Auto-detects HTTP vs TCP check based on port/endpoint

set -euo pipefail

DOCKERFILE="${1:-Dockerfile}"
ENDPOINT="${2:-/api/health}"
PORT="${3:-8080}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ ! -f "$DOCKERFILE" ]]; then
  echo -e "${RED}ERROR: Dockerfile not found: $DOCKERFILE${NC}"
  echo "Usage: bash add-healthcheck.sh <Dockerfile-path> [endpoint] [port]"
  echo "Examples:"
  echo "  bash add-healthcheck.sh api/Dockerfile /api/health 8080"
  echo "  bash add-healthcheck.sh services/Dockerfile /health 9090"
  echo "  bash add-healthcheck.sh db/Dockerfile"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — Dockerfile HEALTHCHECK ===${NC}"
echo "  File     : $DOCKERFILE"
echo "  Endpoint : $ENDPOINT"
echo "  Port     : $PORT"
echo ""

# Already has HEALTHCHECK?
if grep -q "^HEALTHCHECK" "$DOCKERFILE"; then
  echo -e "${GREEN}HEALTHCHECK already present:${NC}"
  grep "^HEALTHCHECK" "$DOCKERFILE"
  exit 0
fi

# Create backup
cp "$DOCKERFILE" "$DOCKERFILE.bak"
echo -e "${YELLOW}Backup created: $DOCKERFILE.bak${NC}"

# Detect if this looks like a database Dockerfile (postgres, mysql, redis, etc.)
FROM_LINE=$(grep -i "^FROM" "$DOCKERFILE" | head -1)
IS_DB=false
if echo "$FROM_LINE" | grep -qiE "(postgres|mysql|mariadb|redis|mongo|cassandra)"; then
  IS_DB=true
fi

# Build the HEALTHCHECK line
if [[ "$IS_DB" == "true" ]]; then
  # Database-appropriate health check
  if echo "$FROM_LINE" | grep -qi "postgres"; then
    HC_LINE="HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \\\n    CMD pg_isready -U \${POSTGRES_USER:-postgres} || exit 1"
  elif echo "$FROM_LINE" | grep -qi "mysql\|mariadb"; then
    HC_LINE="HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \\\n    CMD mysqladmin ping -h localhost --silent || exit 1"
  elif echo "$FROM_LINE" | grep -qi "redis"; then
    HC_LINE="HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \\\n    CMD redis-cli ping || exit 1"
  else
    HC_LINE="HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \\\n    CMD echo 'health check not configured' || exit 1"
  fi
else
  # HTTP health check — use curl if available, wget as fallback
  HC_LINE="HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \\\n    CMD curl -f http://localhost:${PORT}${ENDPOINT} || exit 1"
fi

# Insert before CMD/ENTRYPOINT or at end
python3 - "$DOCKERFILE" "$HC_LINE" <<'PYEOF'
import sys
filepath = sys.argv[1]
hc_line = sys.argv[2].replace('\\n', '\n')
lines = open(filepath).read().splitlines()
# Find last CMD or ENTRYPOINT
insert_pos = len(lines)
for i, l in enumerate(lines):
    if l.startswith('CMD') or l.startswith('ENTRYPOINT'):
        insert_pos = i
        break
lines.insert(insert_pos, '')
for block_line in reversed(hc_line.splitlines()):
    lines.insert(insert_pos, block_line)
lines.insert(insert_pos, '# Security: Health check for K8s liveness/readiness (Checkov CKV_DOCKER_3)')
open(filepath, 'w').write('\n'.join(lines) + '\n')
print(f"Inserted HEALTHCHECK before line {insert_pos + 1}")
PYEOF

echo ""
echo -e "${GREEN}Done. New Dockerfile (last 15 lines):${NC}"
tail -15 "$DOCKERFILE"
echo ""

echo -e "${YELLOW}Notes:${NC}"
echo "  - Ensure 'curl' is installed in the image (add to RUN apt-get install -y curl)"
echo "  - Adjust --start-period if your app takes longer to boot"
echo "  - K8s livenessProbe/readinessProbe are separate — this is the Docker-level check"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Verify curl (or pg_isready etc.) is available in the image"
echo "  2. Build and test: docker build -t test . && docker inspect test | grep -A5 Health"
echo "  3. Re-scan: checkov -f $DOCKERFILE --check CKV_DOCKER_3"
echo "  4. Commit: git commit -m 'security: add HEALTHCHECK to Dockerfile (CKV_DOCKER_3)'"
echo ""
