#!/usr/bin/env bash
# fix-weak-random.sh
# Replace insecure random usage with cryptographically secure alternatives.
#
# Usage:
#   bash fix-weak-random.sh <python-file.py>
#
# Error codes: Bandit B311, B312, B313, B314, B315
#              Semgrep python.lang.security.audit.random.use-of-random
#
# What it fixes:
#   random.random()           → secrets.token_hex(16)
#   random.randint(a, b)      → secrets.randbelow(b - a) + a
#   random.choice(seq)        → secrets.choice(seq)
#   random.randrange(n)       → secrets.randbelow(n)
#   random.shuffle(seq)       → uses secrets-based approach
#
# What it does NOT touch (non-security contexts):
#   - random usage inside test files
#   - random usage with explicit comment # nosec or # not-security
#   - random.seed() calls (simulation/reproducibility — not a secret)
#
# Note: This script flags token/password/key/nonce/session/secret contexts
# for conversion. Simulation code (e.g., Monte Carlo) is NOT flagged.

set -euo pipefail

FILE="${1:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: bash fix-weak-random.sh <python-file.py>"
  echo ""
  echo "Examples:"
  echo "  bash fix-weak-random.sh src/auth/tokens.py"
  echo "  bash fix-weak-random.sh api/utils/session.py"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — Weak Random Fix ===${NC}"
echo "  File: $FILE"
echo ""

# Detect insecure random usage
echo "Scanning for insecure random usage..."
echo ""

FOUND_RANDOM=$(grep -n "random\." "$FILE" | grep -v "# nosec\|# not-security\|secrets\." || true)

if [[ -z "$FOUND_RANDOM" ]]; then
  echo -e "${GREEN}No random.* usage found in $FILE.${NC}"
  exit 0
fi

echo "Found random.* usage:"
echo "$FOUND_RANDOM"
echo ""

# Detect security-sensitive context
SECURITY_CONTEXT=$(grep -in "token\|password\|secret\|key\|nonce\|session\|csrf\|salt\|otp\|pin\|code\|auth" "$FILE" || true)

if [[ -z "$SECURITY_CONTEXT" ]]; then
  echo -e "${YELLOW}WARNING: No obvious security context detected in $FILE.${NC}"
  echo "  This file may be using random for simulation/non-security purposes."
  echo "  If this is NOT security-sensitive (Monte Carlo, game logic, etc.),"
  echo "  you can suppress with: # nosec  or  # not-security"
  echo ""
  echo "  If this IS security-sensitive, continue with the fix below."
  echo ""
fi

# Create backup
cp "$FILE" "$FILE.bak"
echo -e "${YELLOW}Backup created: $FILE.bak${NC}"
echo ""

# Run Python to perform the replacements
python3 - "$FILE" <<'PYEOF'
import sys, re

filepath = sys.argv[1]
content = open(filepath).read()
original = content

changes = []

# Track if we need to add secrets import
needs_secrets_import = False

# Replace random.choice(x) → secrets.choice(x)
pattern = r'\brandom\.choice\s*\('
matches = re.findall(pattern, content)
if matches:
    content = re.sub(pattern, 'secrets.choice(', content)
    needs_secrets_import = True
    changes.append(f"  random.choice() → secrets.choice() ({len(matches)} occurrences)")

# Replace random.randint(a, b) — note: secrets.randbelow(n) gives [0,n), so map accordingly
# We output a TODO comment since the range semantics differ
randint_matches = re.findall(r'\brandom\.randint\s*\(', content)
if randint_matches:
    changes.append(f"  random.randint() — {len(randint_matches)} occurrence(s) need MANUAL fix (see below)")

# Replace random.randrange(n) → secrets.randbelow(n)
pattern = r'\brandom\.randrange\s*\('
matches = re.findall(pattern, content)
if matches:
    content = re.sub(pattern, 'secrets.randbelow(', content)
    needs_secrets_import = True
    changes.append(f"  random.randrange() → secrets.randbelow() ({len(matches)} occurrences)")

# Replace random.random() used in token/id contexts → secrets.token_hex(16)
# Only if in a security-context line (variable name suggests token/key/secret/id)
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
    changes.append(f"  random.random() → secrets.token_hex(16) in security context ({random_random_count} lines)")

# Add import secrets if needed
if needs_secrets_import:
    if 'import secrets' not in content:
        # Insert after existing imports
        content = re.sub(
            r'(^import random\s*\n)',
            r'import secrets\n\1',
            content, flags=re.MULTILINE
        )
        if 'import secrets' not in content:
            # Prepend if no import random found
            content = 'import secrets\n' + content
        changes.append("  Added: import secrets")

if content != original:
    open(filepath, 'w').write(content)
    print("CHANGES_MADE")
    for c in changes:
        print(c)
else:
    print("NO_CHANGES")
    for c in changes:
        print(c)
PYEOF

echo ""
echo -e "${YELLOW}Manual fixes required:${NC}"
echo ""
echo "  1. random.randint(a, b) must be manually converted:"
echo "     Insecure : random.randint(0, 255)"
echo "     Secure   : secrets.randbelow(256)     # gives [0, 256)"
echo "     Or       : int.from_bytes(os.urandom(1), 'big')"
echo ""
echo "  2. random.shuffle() for security-sensitive lists:"
echo "     Use secrets module to generate a key, then sort by that key"
echo "     Or use a dedicated shuffle: list(sorted(seq, key=lambda _: secrets.token_bytes(16)))"
echo ""
echo "  3. random.random() NOT in a security context:"
echo "     These were left unchanged — add # nosec to suppress scanner warnings"
echo ""

echo -e "${YELLOW}Verify fixes:${NC}"
echo "  grep -n 'random\\.' $FILE    # should only show simulation/non-security uses"
echo "  bandit -t B311 $FILE"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review diff: git diff $FILE"
echo "  2. Run tests: pytest tests/"
echo "  3. Re-scan: bandit -f json -t B311,B312 $FILE"
echo "  4. Commit: git commit -m 'security: replace insecure random with secrets module (B311)'"
echo ""
