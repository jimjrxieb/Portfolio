#!/usr/bin/env bash
# fix-yaml-load.sh
# Replace yaml.load() with yaml.safe_load() to prevent arbitrary code execution.
#
# Usage:
#   bash fix-yaml-load.sh <python-file.py>
#
# Error codes: Bandit B506
#              Semgrep python.lang.security.audit.yaml-load
#
# What it fixes:
#   yaml.load(data)                → yaml.safe_load(data)
#   yaml.load(f, Loader=...)       → yaml.safe_load(f)
#   yaml.load_all(data)            → yaml.safe_load_all(data)
#   yaml.dump() with Dumper=...    → (left alone — not a security issue)

set -euo pipefail

FILE="${1:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: bash fix-yaml-load.sh <python-file.py>"
  echo ""
  echo "Examples:"
  echo "  bash fix-yaml-load.sh config/loader.py"
  echo "  bash fix-yaml-load.sh src/utils/parse.py"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — YAML Safe Load Fix ===${NC}"
echo "  File: $FILE"
echo ""

# Detect unsafe yaml.load usage
FOUND=$(grep -n 'yaml\.load\b\|yaml\.load_all\b' "$FILE" | grep -v 'safe_load\|# nosec' || true)

if [[ -z "$FOUND" ]]; then
  echo -e "${GREEN}No unsafe yaml.load() usage found in $FILE.${NC}"
  exit 0
fi

echo "Found unsafe yaml.load() usage:"
echo "$FOUND"
echo ""

# Create backup
cp "$FILE" "$FILE.bak"
echo -e "${YELLOW}Backup created: $FILE.bak${NC}"
echo ""

python3 - "$FILE" <<'PYEOF'
import sys, re

filepath = sys.argv[1]
content = open(filepath).read()
original = content
changes = []

# yaml.load_all(x, Loader=...) → yaml.safe_load_all(x)
# Must come before yaml.load to avoid partial match
pattern_all = r'yaml\.load_all\s*\(([^,)]+)(?:,\s*Loader\s*=[^)]+)?\)'
matches_all = re.findall(pattern_all, content)
if matches_all:
    content = re.sub(pattern_all, r'yaml.safe_load_all(\1)', content)
    changes.append(f"  yaml.load_all() → yaml.safe_load_all() ({len(matches_all)} occurrences)")

# yaml.load(x, Loader=...) → yaml.safe_load(x)
pattern = r'yaml\.load\s*\(([^,)]+)(?:,\s*Loader\s*=[^)]+)?\)'
matches = re.findall(pattern, content)
if matches:
    content = re.sub(pattern, r'yaml.safe_load(\1)', content)
    changes.append(f"  yaml.load() → yaml.safe_load() ({len(matches)} occurrences)")

if content != original:
    open(filepath, 'w').write(content)
    print("CHANGES_MADE")
    for c in changes:
        print(c)
else:
    print("NO_CHANGES")
PYEOF

echo ""
echo -e "${YELLOW}Verify fixes:${NC}"
echo "  grep -n 'yaml\\.load' $FILE    # should only show safe_load"
echo "  bandit -t B506 $FILE"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review diff: git diff $FILE"
echo "  2. Run tests: pytest tests/"
echo "  3. Re-scan: bandit -f json -t B506 $FILE"
echo "  4. Commit: git commit -m 'security: replace yaml.load with yaml.safe_load (B506)'"
echo ""
