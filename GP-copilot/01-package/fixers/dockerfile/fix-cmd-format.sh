#!/usr/bin/env bash
# fix-cmd-format.sh
# Convert CMD shell form to exec (JSON array) form.
#
# Usage:
#   bash fix-cmd-format.sh <Dockerfile-path>
#
# Error codes: Hadolint DL3025
#
# What it fixes:
#   CMD python app.py          → CMD ["python", "app.py"]
#   CMD npm start              → CMD ["npm", "start"]
#   CMD ./entrypoint.sh        → CMD ["./entrypoint.sh"]
#   ENTRYPOINT python app.py   → ENTRYPOINT ["python", "app.py"]
#
# What it does NOT touch:
#   CMD ["already", "json"]    → already correct
#   CMD with shell pipes/&&    → flagged for manual (needs shell)

set -euo pipefail

DOCKERFILE="${1:-Dockerfile}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ ! -f "$DOCKERFILE" ]]; then
  echo -e "${RED}ERROR: Dockerfile not found: $DOCKERFILE${NC}"
  echo "Usage: bash fix-cmd-format.sh <Dockerfile-path>"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — CMD/ENTRYPOINT JSON Format ===${NC}"
echo "  File: $DOCKERFILE"
echo ""

# Find CMD/ENTRYPOINT in shell form (not already JSON)
FOUND=$(grep -nE '^(CMD|ENTRYPOINT) [^\[]' "$DOCKERFILE" || true)

if [[ -z "$FOUND" ]]; then
  echo -e "${GREEN}All CMD/ENTRYPOINT instructions already use exec form.${NC}"
  exit 0
fi

echo "Found shell-form instructions:"
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

    # Match CMD or ENTRYPOINT not followed by [
    match = re.match(r'^(CMD|ENTRYPOINT)\s+(?!\[)(.+)$', stripped)
    if not match:
        new_lines.append(line)
        continue

    instruction = match.group(1)
    args_str = match.group(2).strip()

    # If it uses shell features (pipes, &&, ||, ;, redirects) — leave it
    if any(c in args_str for c in ['|', '&&', '||', ';', '>', '<', '$(']):
        changes.append(f"  Line {i}: {instruction} uses shell features — MANUAL fix needed")
        changes.append(f"           Wrap with: {instruction} [\"/bin/sh\", \"-c\", \"{args_str}\"]")
        new_lines.append(line)
        continue

    # Split into args and format as JSON array
    parts = args_str.split()
    json_parts = ', '.join(f'"{p}"' for p in parts)
    new_line = f'{instruction} [{json_parts}]'
    new_lines.append(new_line)
    changes.append(f"  Line {i}: {instruction} {args_str} → {new_line}")

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
echo -e "${YELLOW}Why exec form matters:${NC}"
echo "  Shell form: CMD python app.py"
echo "    → Runs as: /bin/sh -c 'python app.py'"
echo "    → Python is NOT PID 1, so SIGTERM goes to sh, not your app"
echo "    → App doesn't receive shutdown signals = data loss risk"
echo ""
echo "  Exec form: CMD [\"python\", \"app.py\"]"
echo "    → Runs directly as PID 1"
echo "    → SIGTERM reaches your app = clean shutdown"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review diff: git diff $DOCKERFILE"
echo "  2. Build test: docker build -t test ."
echo "  3. Re-scan: hadolint $DOCKERFILE"
echo "  4. Commit: git commit -m 'dockerfile: use exec form for CMD/ENTRYPOINT (DL3025)'"
echo ""
