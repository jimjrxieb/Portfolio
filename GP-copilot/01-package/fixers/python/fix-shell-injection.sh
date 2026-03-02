#!/usr/bin/env bash
# fix-shell-injection.sh
# Fix subprocess calls using shell=True (command injection risk).
#
# Usage:
#   bash fix-shell-injection.sh <python-file>
#
# Error codes: Bandit B602, B603

set -euo pipefail

FILE="${1:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: bash fix-shell-injection.sh <python-file>"
  echo "Example: bash fix-shell-injection.sh api/utils.py"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Shell Injection Fix ===${NC}"
echo "  File: $FILE"
echo ""

MATCHES=$(grep -n "shell=True" "$FILE" 2>/dev/null || true)

if [[ -z "$MATCHES" ]]; then
  echo -e "${GREEN}No shell=True patterns found in $FILE.${NC}"
  exit 0
fi

echo -e "${RED}Found shell=True usage:${NC}"
echo ""
echo "$MATCHES"
echo ""

echo -e "${GREEN}Safe pattern:${NC}"
echo "  Before: subprocess.run('ls /tmp', shell=True)"
echo "  After:  subprocess.run(['ls', '/tmp'], shell=False, check=True)"
echo ""

cp "$FILE" "$FILE.bak"
echo -e "${YELLOW}Backup created: $FILE.bak${NC}"
echo ""

python3 - "$FILE" <<'PYEOF'
import sys, re
filepath = sys.argv[1]
content = open(filepath).read()
lines = content.split('\n')
changed = []
result = []
for i, line in enumerate(lines, 1):
    if 'shell=True' in line:
        if re.search(r'subprocess\.\w+\(\s*\[', line):
            new_line = line.replace('shell=True', 'shell=False')
            changed.append((i, line.strip(), new_line.strip()))
            result.append(new_line)
        else:
            result.append(line)
    else:
        result.append(line)
if changed:
    open(filepath, 'w').write('\n'.join(result))
    print(f"\033[0;32mAuto-fixed {len(changed)} safe shell=True → shell=False:\033[0m")
    for lineno, before, after in changed:
        print(f"  Line {lineno}:")
        print(f"    Before: {before}")
        print(f"    After:  {after}")
else:
    print("\033[1;33mNo auto-fix applied — commands use string interpolation.\033[0m")
    print("These require manual refactoring to list syntax.")
PYEOF

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review: diff $FILE $FILE.bak"
echo "  2. Manually fix remaining shell=True lines"
echo "  3. Run tests"
echo "  4. Re-scan: bandit -r ${FILE%/*}/ -t B602,B603"
echo ""
