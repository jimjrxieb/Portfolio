#!/usr/bin/env bash
# fix-shell-injection.sh
# Fix subprocess calls using shell=True (command injection risk).
#
# Usage:
#   bash fix-shell-injection.sh <python-file>
#
# Error codes: Bandit B602, B603 | Semgrep python.lang.security.audit.subprocess-shell-true
#
# What it does:
#   - Finds subprocess calls with shell=True
#   - Shows the safe replacement pattern
#   - Creates .bak backup
#   - Applies safe replacements where unambiguous

set -euo pipefail

FILE="${1:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$FILE" ]]; then
  echo "Usage: bash fix-shell-injection.sh <python-file>"
  echo ""
  echo "Example:"
  echo "  bash fix-shell-injection.sh api/utils.py"
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  echo -e "${RED}ERROR: File not found: $FILE${NC}"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — Shell Injection Fix ===${NC}"
echo "  File: $FILE"
echo ""

# Find all lines with shell=True
MATCHES=$(grep -n "shell=True" "$FILE" 2>/dev/null || true)

if [[ -z "$MATCHES" ]]; then
  echo -e "${GREEN}No shell=True patterns found in $FILE.${NC}"
  exit 0
fi

echo -e "${RED}Found shell=True usage:${NC}"
echo ""
echo "$MATCHES"
echo ""

echo -e "${YELLOW}Why this is dangerous:${NC}"
echo "  subprocess.run(f'ls {user_input}', shell=True)"
echo "  → If user_input is '; rm -rf /', you have a problem."
echo ""

echo -e "${GREEN}Safe patterns:${NC}"
echo ""
echo "  ❌ BEFORE (shell=True with string command):"
echo "     subprocess.run('ls /tmp', shell=True)"
echo "     subprocess.call(f'echo {var}', shell=True)"
echo ""
echo "  ✅ AFTER (shell=False with list):"
echo "     subprocess.run(['ls', '/tmp'], shell=False, check=True)"
echo "     subprocess.call(['echo', var], shell=False)"
echo ""
echo "  ✅ AFTER (if you truly need shell features like pipes):"
echo "     subprocess.run('ls /tmp | grep foo', shell=True,   # still shell=True"
echo "                    capture_output=True, text=True)     # but no user input"
echo "     # Only acceptable when the command is FULLY hardcoded — no variables."
echo ""

# Create backup
cp "$FILE" "$FILE.bak"
echo -e "${YELLOW}Backup created: $FILE.bak${NC}"
echo ""

# Apply safe replacement: shell=True → shell=False
# Only safe when the command is already a list
python3 - "$FILE" <<'PYEOF'
import sys, re, ast

filepath = sys.argv[1]
content = open(filepath).read()
original = content

# Pattern: subprocess.*shell=True — flag for review, don't blindly flip
# Only auto-flip if we can confirm no shell interpolation
lines = content.split('\n')
changed = []
result = []

for i, line in enumerate(lines, 1):
    if 'shell=True' in line:
        # Safe to flip only if command arg is already a list literal
        # Look for patterns like run(['cmd', 'arg'], shell=True)
        if re.search(r'subprocess\.\w+\(\s*\[', line):
            new_line = line.replace('shell=True', 'shell=False')
            changed.append((i, line.strip(), new_line.strip()))
            result.append(new_line)
        else:
            # Has string command — needs manual review
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
echo -e "${YELLOW}Manual review required for remaining shell=True lines:${NC}"
echo "  For each line, convert the string command to a list:"
echo ""
echo "  Old: subprocess.run(f'git clone {url}', shell=True)"
echo "  New: subprocess.run(['git', 'clone', url], shell=False, check=True)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review changes: diff $FILE $FILE.bak"
echo "  2. Manually fix any remaining shell=True lines"
echo "  3. Run tests"
echo "  4. Re-scan: bandit -r ${FILE%/*}/ -t B602,B603"
echo "  5. Commit: git commit -m 'security: fix shell injection risk (Bandit B602)'"
echo ""
