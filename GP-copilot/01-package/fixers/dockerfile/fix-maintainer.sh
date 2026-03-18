#!/usr/bin/env bash
# fix-maintainer.sh
# Replace deprecated MAINTAINER instruction with LABEL maintainer=.
#
# Usage:
#   bash fix-maintainer.sh <Dockerfile-path>
#
# Error codes: Hadolint DL4000
#
# What it fixes:
#   MAINTAINER John Doe <john@example.com>
#     → LABEL maintainer="John Doe <john@example.com>"

set -euo pipefail

DOCKERFILE="${1:-Dockerfile}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ ! -f "$DOCKERFILE" ]]; then
  echo -e "${RED}ERROR: Dockerfile not found: $DOCKERFILE${NC}"
  echo "Usage: bash fix-maintainer.sh <Dockerfile-path>"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — MAINTAINER to LABEL Fix ===${NC}"
echo "  File: $DOCKERFILE"
echo ""

FOUND=$(grep -n '^MAINTAINER ' "$DOCKERFILE" || true)

if [[ -z "$FOUND" ]]; then
  echo -e "${GREEN}No MAINTAINER instruction found in $DOCKERFILE.${NC}"
  exit 0
fi

echo "Found deprecated MAINTAINER:"
echo "$FOUND"
echo ""

cp "$DOCKERFILE" "$DOCKERFILE.bak"
echo -e "${YELLOW}Backup created: $DOCKERFILE.bak${NC}"
echo ""

# Replace MAINTAINER with LABEL
sed -i 's/^MAINTAINER \(.*\)/LABEL maintainer="\1"/' "$DOCKERFILE"

echo -e "${GREEN}Replaced MAINTAINER with LABEL maintainer=.${NC}"
echo ""
echo "Result:"
grep -n 'LABEL maintainer' "$DOCKERFILE" || true
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review diff: git diff $DOCKERFILE"
echo "  2. Re-scan: hadolint $DOCKERFILE"
echo "  3. Commit: git commit -m 'dockerfile: replace MAINTAINER with LABEL (DL4000)'"
echo ""
