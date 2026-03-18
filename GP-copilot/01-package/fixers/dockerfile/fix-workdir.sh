#!/usr/bin/env bash
# fix-workdir.sh
# Replace "RUN cd /path && command" with "WORKDIR /path" + "RUN command".
#
# Usage:
#   bash fix-workdir.sh <Dockerfile-path>
#
# Error codes: Hadolint DL3003
#
# What it fixes:
#   RUN cd /app && npm install     → WORKDIR /app
#                                    RUN npm install
#   RUN cd /src && make build      → WORKDIR /src
#                                    RUN make build
#
# Why: cd in RUN only affects that layer. Next RUN resets to previous WORKDIR.
# Using WORKDIR persists across layers and is the Docker-idiomatic approach.

set -euo pipefail

DOCKERFILE="${1:-Dockerfile}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ ! -f "$DOCKERFILE" ]]; then
  echo -e "${RED}ERROR: Dockerfile not found: $DOCKERFILE${NC}"
  echo "Usage: bash fix-workdir.sh <Dockerfile-path>"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — cd to WORKDIR Fix ===${NC}"
echo "  File: $DOCKERFILE"
echo ""

FOUND=$(grep -n 'RUN cd ' "$DOCKERFILE" || true)

if [[ -z "$FOUND" ]]; then
  echo -e "${GREEN}No 'RUN cd' patterns found in $DOCKERFILE.${NC}"
  exit 0
fi

echo "Found RUN cd patterns:"
echo "$FOUND"
echo ""

cp "$DOCKERFILE" "$DOCKERFILE.bak"
echo -e "${YELLOW}Backup created: $DOCKERFILE.bak${NC}"
echo ""

python3 - "$DOCKERFILE" <<'PYEOF'
import sys, re

filepath = sys.argv[1]
lines = open(filepath).read().splitlines()
new_lines = []
changes = []

for i, line in enumerate(lines, 1):
    stripped = line.strip()

    # Match: RUN cd /path && command(s)
    match = re.match(r'^RUN\s+cd\s+(\S+)\s*&&\s*(.+)$', stripped)
    if match:
        workdir = match.group(1)
        commands = match.group(2).strip()
        new_lines.append(f'WORKDIR {workdir}')
        new_lines.append(f'RUN {commands}')
        changes.append(f"  Line {i}: RUN cd {workdir} && ... → WORKDIR {workdir} + RUN ...")
        continue

    # Match: RUN cd /path ; command(s)
    match = re.match(r'^RUN\s+cd\s+(\S+)\s*;\s*(.+)$', stripped)
    if match:
        workdir = match.group(1)
        commands = match.group(2).strip()
        new_lines.append(f'WORKDIR {workdir}')
        new_lines.append(f'RUN {commands}')
        changes.append(f"  Line {i}: RUN cd {workdir} ; ... → WORKDIR {workdir} + RUN ...")
        continue

    new_lines.append(line)

content = '\n'.join(new_lines) + '\n'
open(filepath, 'w').write(content)

if changes:
    print("CHANGES_MADE")
    for c in changes:
        print(c)
else:
    print("NO_CHANGES")
PYEOF

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review diff: git diff $DOCKERFILE"
echo "  2. Build test: docker build -t test ."
echo "  3. Re-scan: hadolint $DOCKERFILE"
echo "  4. Commit: git commit -m 'dockerfile: replace RUN cd with WORKDIR (DL3003)'"
echo ""
