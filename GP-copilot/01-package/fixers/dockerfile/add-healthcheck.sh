#!/usr/bin/env bash
# add-healthcheck.sh
# Add a HEALTHCHECK instruction to a Dockerfile.
#
# Usage:
#   bash add-healthcheck.sh <Dockerfile-path> [health-endpoint] [port]
#
# Error codes: Trivy DS026, Checkov CKV_DOCKER_3

set -euo pipefail

DOCKERFILE="${1:-Dockerfile}"
ENDPOINT="${2:-/health}"
PORT="${3:-8000}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ ! -f "$DOCKERFILE" ]]; then
  echo -e "${RED}ERROR: Dockerfile not found: $DOCKERFILE${NC}"
  echo "Usage: bash add-healthcheck.sh <Dockerfile-path> [endpoint] [port]"
  echo "Examples:"
  echo "  bash add-healthcheck.sh api/Dockerfile /health 8000"
  echo "  bash add-healthcheck.sh ui/Dockerfile / 80"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Dockerfile HEALTHCHECK ===${NC}"
echo "  File     : $DOCKERFILE"
echo "  Endpoint : $ENDPOINT"
echo "  Port     : $PORT"
echo ""

if grep -q "^HEALTHCHECK" "$DOCKERFILE"; then
  echo -e "${GREEN}HEALTHCHECK already present:${NC}"
  grep "^HEALTHCHECK" "$DOCKERFILE"
  exit 0
fi

cp "$DOCKERFILE" "$DOCKERFILE.bak"
echo -e "${YELLOW}Backup created: $DOCKERFILE.bak${NC}"

FROM_LINE=$(grep -i "^FROM" "$DOCKERFILE" | head -1)
IS_DB=false
echo "$FROM_LINE" | grep -qiE "(postgres|mysql|mariadb|redis|mongo)" && IS_DB=true

if [[ "$IS_DB" == "true" ]]; then
  if echo "$FROM_LINE" | grep -qi "postgres"; then
    HC_LINE="HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \\\n    CMD pg_isready -U \${POSTGRES_USER:-postgres} || exit 1"
  elif echo "$FROM_LINE" | grep -qi "redis"; then
    HC_LINE="HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \\\n    CMD redis-cli ping || exit 1"
  else
    HC_LINE="HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \\\n    CMD echo 'configure health check' || exit 1"
  fi
else
  HC_LINE="HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \\\n    CMD curl -f http://localhost:${PORT}${ENDPOINT} || exit 1"
fi

python3 - "$DOCKERFILE" "$HC_LINE" <<'PYEOF'
import sys
filepath = sys.argv[1]
hc_line = sys.argv[2].replace('\\n', '\n')
lines = open(filepath).read().splitlines()
insert_pos = len(lines)
for i, l in enumerate(lines):
    if l.startswith('CMD') or l.startswith('ENTRYPOINT'):
        insert_pos = i
        break
lines.insert(insert_pos, '')
for block_line in reversed(hc_line.splitlines()):
    lines.insert(insert_pos, block_line)
lines.insert(insert_pos, '# Health check for container orchestrator (CKV_DOCKER_3)')
open(filepath, 'w').write('\n'.join(lines) + '\n')
print(f"Inserted HEALTHCHECK before line {insert_pos + 1}")
PYEOF

echo ""
echo -e "${GREEN}Done. New Dockerfile (last 15 lines):${NC}"
tail -15 "$DOCKERFILE"
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Ensure curl is installed in the image"
echo "  2. Build and test: docker build -t test . && docker inspect test | grep -A5 Health"
echo "  3. Re-scan: checkov -f $DOCKERFILE --check CKV_DOCKER_3"
echo ""
