#!/usr/bin/env bash
# fix-pickle.sh
# Replace pickle.load/loads with json.load/loads where possible.
#
# Usage:
#   bash fix-pickle.sh <python-file.py>
#
# Error codes: Bandit B301
#              Semgrep python.lang.security.audit.pickle
#
# What it fixes:
#   pickle.load(f)   → json.load(f)
#   pickle.loads(s)  → json.loads(s)
#   pickle.dump(o,f) → json.dump(o, f, indent=2)
#   pickle.dumps(o)  → json.dumps(o)
#   import pickle    → import json
#
# WARNING: This is a LOSSY conversion. Pickle handles arbitrary Python objects.
# JSON only handles dicts, lists, strings, numbers, booleans, None.
# If the code pickles custom classes, numpy arrays, or sets — this will break.
# The script flags those cases and leaves them for manual review.

set -euo pipefail

FILE="${1:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: bash fix-pickle.sh <python-file.py>"
  echo ""
  echo "Examples:"
  echo "  bash fix-pickle.sh src/cache/store.py"
  echo "  bash fix-pickle.sh utils/serializer.py"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — Pickle to JSON Fix ===${NC}"
echo "  File: $FILE"
echo ""

# Detect pickle usage
FOUND=$(grep -n 'pickle\.' "$FILE" | grep -v '# nosec' || true)

if [[ -z "$FOUND" ]]; then
  echo -e "${GREEN}No pickle usage found in $FILE.${NC}"
  exit 0
fi

echo "Found pickle usage:"
echo "$FOUND"
echo ""

# Check for complex types that won't survive JSON conversion
COMPLEX=$(grep -n 'class \|numpy\|np\.\|set(\|frozenset\|datetime\.\|Decimal\|bytes(' "$FILE" || true)
if [[ -n "$COMPLEX" ]]; then
  echo -e "${RED}WARNING: File contains complex types that may not JSON-serialize:${NC}"
  echo "$COMPLEX"
  echo ""
  echo -e "${YELLOW}Review these before applying. JSON only supports: dict, list, str, int, float, bool, None${NC}"
  echo ""
fi

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

# Check for .pkl / .pickle file extensions in the code — these need manual attention
pkl_files = re.findall(r'["\'][^"\']*\.pkl[e]?["\']', content)
if pkl_files:
    changes.append(f"  WARNING: Found .pkl file references: {pkl_files}")
    changes.append(f"  These files must be re-serialized as JSON before this fix works.")

# Replace pickle.loads → json.loads
matches = re.findall(r'\bpickle\.loads\b', content)
if matches:
    content = re.sub(r'\bpickle\.loads\b', 'json.loads', content)
    changes.append(f"  pickle.loads() → json.loads() ({len(matches)} occurrences)")

# Replace pickle.load → json.load
matches = re.findall(r'\bpickle\.load\b', content)
if matches:
    content = re.sub(r'\bpickle\.load\b', 'json.load', content)
    changes.append(f"  pickle.load() → json.load() ({len(matches)} occurrences)")

# Replace pickle.dumps → json.dumps
matches = re.findall(r'\bpickle\.dumps\b', content)
if matches:
    content = re.sub(r'\bpickle\.dumps\b', 'json.dumps', content)
    changes.append(f"  pickle.dumps() → json.dumps() ({len(matches)} occurrences)")

# Replace pickle.dump(obj, f) → json.dump(obj, f, indent=2)
matches = re.findall(r'\bpickle\.dump\b', content)
if matches:
    content = re.sub(r'\bpickle\.dump\(([^,]+),\s*([^)]+)\)', r'json.dump(\1, \2, indent=2)', content)
    changes.append(f"  pickle.dump() → json.dump() ({len(matches)} occurrences)")

# Replace import pickle → import json
if 'import pickle' in content:
    content = content.replace('import pickle', 'import json')
    changes.append("  import pickle → import json")

# Replace 'rb' mode with 'r' and 'wb' mode with 'w' for json compatibility
content = re.sub(r"open\(([^,]+),\s*'rb'\)", r"open(\1, 'r')", content)
content = re.sub(r"open\(([^,]+),\s*'wb'\)", r"open(\1, 'w')", content)

if content != original:
    open(filepath, 'w').write(content)
    print("CHANGES_MADE")
    for c in changes:
        print(c)
else:
    print("NO_CHANGES")
PYEOF

echo ""
echo -e "${RED}IMPORTANT: If the code used .pkl files, you must also convert the data:${NC}"
echo ""
echo "  python3 -c \""
echo "  import pickle, json"
echo "  data = pickle.load(open('data.pkl', 'rb'))"
echo "  json.dump(data, open('data.json', 'w'), indent=2, default=str)"
echo "  \""
echo ""
echo -e "${YELLOW}Verify fixes:${NC}"
echo "  grep -n 'pickle' $FILE    # should be zero matches"
echo "  bandit -t B301 $FILE"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review diff: git diff $FILE"
echo "  2. Run tests: pytest tests/"
echo "  3. Re-scan: bandit -f json -t B301 $FILE"
echo "  4. Commit: git commit -m 'security: replace pickle with json serialization (B301)'"
echo ""
