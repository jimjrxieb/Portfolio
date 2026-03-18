#!/usr/bin/env bash
# fix-defusedxml.sh
# Replace xml.etree.ElementTree with defusedxml to prevent XXE attacks.
#
# Usage:
#   bash fix-defusedxml.sh <python-file.py>
#
# Error codes: Bandit B314
#              Semgrep python.lang.security.audit.xml-etree
#
# What it fixes:
#   import xml.etree.ElementTree as ET   → import defusedxml.ElementTree as ET
#   from xml.etree.ElementTree import *  → from defusedxml.ElementTree import *
#   from xml.etree import ElementTree    → from defusedxml import ElementTree
#   xml.etree.ElementTree.parse(...)     → defusedxml.ElementTree.parse(...)
#
# Also checks if defusedxml is in requirements and adds it if missing.

set -euo pipefail

FILE="${1:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: bash fix-defusedxml.sh <python-file.py>"
  echo ""
  echo "Examples:"
  echo "  bash fix-defusedxml.sh src/parsers/xml_handler.py"
  echo "  bash fix-defusedxml.sh api/import/feed.py"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — DefusedXML Fix ===${NC}"
echo "  File: $FILE"
echo ""

# Detect unsafe xml usage
FOUND=$(grep -n 'xml\.etree\|from xml\.' "$FILE" | grep -v 'defusedxml\|# nosec' || true)

if [[ -z "$FOUND" ]]; then
  echo -e "${GREEN}No unsafe xml.etree usage found in $FILE.${NC}"
  exit 0
fi

echo "Found unsafe xml.etree usage:"
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

# import xml.etree.ElementTree as ET → import defusedxml.ElementTree as ET
pattern = r'import xml\.etree\.ElementTree(\s+as\s+\w+)?'
matches = re.findall(pattern, content)
if matches:
    content = re.sub(pattern, lambda m: f'import defusedxml.ElementTree{m.group(1) or ""}', content)
    changes.append(f"  import xml.etree.ElementTree → import defusedxml.ElementTree ({len(matches)})")

# from xml.etree.ElementTree import X → from defusedxml.ElementTree import X
pattern = r'from xml\.etree\.ElementTree import'
matches = re.findall(pattern, content)
if matches:
    content = re.sub(pattern, 'from defusedxml.ElementTree import', content)
    changes.append(f"  from xml.etree.ElementTree → from defusedxml.ElementTree ({len(matches)})")

# from xml.etree import ElementTree → from defusedxml import ElementTree
pattern = r'from xml\.etree import ElementTree'
matches = re.findall(pattern, content)
if matches:
    content = re.sub(pattern, 'from defusedxml import ElementTree', content)
    changes.append(f"  from xml.etree → from defusedxml ({len(matches)})")

# xml.etree.ElementTree.X → defusedxml.ElementTree.X (inline usage)
pattern = r'xml\.etree\.ElementTree\.'
matches = re.findall(pattern, content)
if matches:
    content = re.sub(pattern, 'defusedxml.ElementTree.', content)
    changes.append(f"  xml.etree.ElementTree.* → defusedxml.ElementTree.* ({len(matches)})")

if content != original:
    open(filepath, 'w').write(content)
    print("CHANGES_MADE")
    for c in changes:
        print(c)
else:
    print("NO_CHANGES")
PYEOF

echo ""

# Check if defusedxml is in requirements
REQ_FILES=("requirements.txt" "requirements-dev.txt" "requirements-security.txt" "pyproject.toml" "setup.cfg")
FOUND_REQ=false
for req in "${REQ_FILES[@]}"; do
  if [[ -f "$req" ]]; then
    if grep -q "defusedxml" "$req" 2>/dev/null; then
      echo -e "${GREEN}defusedxml already in $req${NC}"
      FOUND_REQ=true
      break
    fi
  fi
done

if [[ "$FOUND_REQ" == "false" ]]; then
  echo -e "${RED}defusedxml NOT found in any requirements file.${NC}"
  if [[ -f "requirements.txt" ]]; then
    echo "defusedxml>=0.7.1" >> requirements.txt
    echo -e "${GREEN}Added defusedxml>=0.7.1 to requirements.txt${NC}"
  else
    echo "  Add manually: pip install defusedxml"
    echo "  Or add to your requirements: defusedxml>=0.7.1"
  fi
fi

echo ""
echo -e "${YELLOW}Verify fixes:${NC}"
echo "  grep -n 'xml\\.etree' $FILE    # should be zero matches"
echo "  bandit -t B314 $FILE"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Install: pip install defusedxml"
echo "  2. Review diff: git diff $FILE"
echo "  3. Run tests: pytest tests/"
echo "  4. Re-scan: bandit -f json -t B314 $FILE"
echo "  5. Commit: git commit -m 'security: replace xml.etree with defusedxml (B314)'"
echo ""
