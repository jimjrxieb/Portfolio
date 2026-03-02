#!/usr/bin/env bash
# fix-weak-random.sh
# Replace insecure random usage with cryptographically secure alternatives.
#
# Usage:
#   bash fix-weak-random.sh <python-file>
#
# Error codes: Bandit B311, B312
#
# Replacements:
#   random.choice(seq)     → secrets.choice(seq)
#   random.randrange(n)    → secrets.randbelow(n)
#   random.random()        → secrets.token_hex(16) (in security contexts)

set -euo pipefail

FILE="${1:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: bash fix-weak-random.sh <python-file>"
  echo "Example: bash fix-weak-random.sh api/utils/session.py"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Weak Random Fix ===${NC}"
echo "  File: $FILE"
echo ""

FOUND_RANDOM=$(grep -n "random\." "$FILE" | grep -v "# nosec\|# not-security\|secrets\." || true)

if [[ -z "$FOUND_RANDOM" ]]; then
  echo -e "${GREEN}No random.* usage found in $FILE.${NC}"
  exit 0
fi

echo "Found random.* usage:"
echo "$FOUND_RANDOM"
echo ""

cp "$FILE" "$FILE.bak"
echo -e "${YELLOW}Backup created: $FILE.bak${NC}"
echo ""

python3 - "$FILE" <<'PYEOF'
import sys, re
filepath = sys.argv[1]
content = open(filepath).read()
original = content
changes = []
needs_secrets_import = False

pattern = r'\brandom\.choice\s*\('
matches = re.findall(pattern, content)
if matches:
    content = re.sub(pattern, 'secrets.choice(', content)
    needs_secrets_import = True
    changes.append(f"  random.choice() → secrets.choice() ({len(matches)}x)")

pattern = r'\brandom\.randrange\s*\('
matches = re.findall(pattern, content)
if matches:
    content = re.sub(pattern, 'secrets.randbelow(', content)
    needs_secrets_import = True
    changes.append(f"  random.randrange() → secrets.randbelow() ({len(matches)}x)")

randint_matches = re.findall(r'\brandom\.randint\s*\(', content)
if randint_matches:
    changes.append(f"  random.randint() — {len(randint_matches)}x need MANUAL fix")

lines = content.splitlines()
new_lines = []
random_random_count = 0
for line in lines:
    stripped = line.lower()
    if re.search(r'\brandom\.random\(\)', line) and \
       re.search(r'token|secret|key|nonce|session|csrf|salt|otp|pin|auth|id', stripped):
        line = re.sub(r'\brandom\.random\(\)', 'secrets.token_hex(16)', line)
        needs_secrets_import = True
        random_random_count += 1
    new_lines.append(line)
content = '\n'.join(new_lines)
if random_random_count:
    changes.append(f"  random.random() → secrets.token_hex(16) ({random_random_count}x)")

if needs_secrets_import and 'import secrets' not in content:
    content = re.sub(r'(^import random\s*\n)', r'import secrets\n\1', content, flags=re.MULTILINE)
    if 'import secrets' not in content:
        content = 'import secrets\n' + content
    changes.append("  Added: import secrets")

if content != original:
    open(filepath, 'w').write(content)
    for c in changes:
        print(c)
else:
    print("No auto-fixes applied.")
    for c in changes:
        print(c)
PYEOF

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review: diff $FILE $FILE.bak"
echo "  2. Manually fix random.randint() lines"
echo "  3. Run tests"
echo "  4. Re-scan: bandit -t B311 $FILE"
echo ""
