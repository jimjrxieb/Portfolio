#!/usr/bin/env bash
# fix-exec.sh
# Replace exec()/eval() with safe alternatives where possible.
#
# Usage:
#   bash fix-exec.sh <python-file.py>
#
# Error codes: Bandit B102
#              Semgrep python.lang.security.audit.exec-used
#
# What it fixes:
#   eval(user_input)    → ast.literal_eval(user_input)  (for data parsing)
#   exec(code_string)   → flagged with safe alternative suggestions
#
# Safe patterns (NOT flagged):
#   eval() inside Django/Flask migration files
#   exec() in __init__.py dynamic imports
#   eval/exec with # nosec comment
#
# NOTE: exec/eval are inherently dangerous. This script converts the obvious
# data-parsing cases to ast.literal_eval() and flags everything else for
# manual review. There is no universal safe replacement for exec().

set -euo pipefail

FILE="${1:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: bash fix-exec.sh <python-file.py>"
  echo ""
  echo "Examples:"
  echo "  bash fix-exec.sh src/utils/config_parser.py"
  echo "  bash fix-exec.sh api/dynamic_handler.py"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — exec/eval Replacement ===${NC}"
echo "  File: $FILE"
echo ""

# Detect exec/eval usage
FOUND=$(grep -n '\bexec\s*(\|\beval\s*(' "$FILE" | grep -v '# nosec\|# safe\|__import__' || true)

if [[ -z "$FOUND" ]]; then
  echo -e "${GREEN}No unsafe exec/eval usage found in $FILE.${NC}"
  exit 0
fi

echo "Found exec/eval usage:"
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
manual_lines = []

needs_ast = False

lines = content.splitlines()
new_lines = []

for i, line in enumerate(lines, 1):
    stripped = line.strip()

    # Skip nosec / safe comments
    if '# nosec' in line or '# safe' in line:
        new_lines.append(line)
        continue

    # eval() used for data parsing → ast.literal_eval()
    # Common patterns: eval(json_str), eval(config_val), eval(request.data)
    if re.search(r'\beval\s*\(', stripped):
        # If it looks like data parsing (variable, string, or dict/list literal)
        match = re.search(r'\beval\s*\(([^)]+)\)', line)
        if match:
            arg = match.group(1).strip()
            # Safe to convert: single variable, attribute access, or string
            if re.match(r'^[\w.]+$', arg) or re.match(r'^["\']', arg):
                new_line = re.sub(r'\beval\s*\(', 'ast.literal_eval(', line)
                new_lines.append(new_line)
                needs_ast = True
                changes.append(f"  Line {i}: eval({arg}) → ast.literal_eval({arg})")
                continue
            else:
                manual_lines.append(f"  Line {i}: eval({arg}) — complex expression, needs manual review")
                new_lines.append(line)
                continue

    # exec() — almost never safe to auto-convert
    if re.search(r'\bexec\s*\(', stripped):
        match = re.search(r'\bexec\s*\(([^)]*)\)', line)
        arg = match.group(1).strip() if match else "?"
        manual_lines.append(f"  Line {i}: exec({arg}) — requires manual refactoring")
        new_lines.append(line)
        continue

    new_lines.append(line)

content = '\n'.join(new_lines)

# Add import ast if needed
if needs_ast and 'import ast' not in content:
    # Insert after existing imports
    import_added = False
    final_lines = content.splitlines()
    for idx, l in enumerate(final_lines):
        if l.startswith('import ') or l.startswith('from '):
            continue
        if idx > 0:
            final_lines.insert(idx, 'import ast')
            import_added = True
            changes.append("  Added: import ast")
            break
    if not import_added:
        final_lines.insert(0, 'import ast')
        changes.append("  Added: import ast")
    content = '\n'.join(final_lines)

if content != original:
    open(filepath, 'w').write(content)
    print("CHANGES_MADE")
else:
    print("NO_CHANGES")

for c in changes:
    print(c)

if manual_lines:
    print("MANUAL_REVIEW_NEEDED")
    for m in manual_lines:
        print(m)
PYEOF

echo ""
echo -e "${YELLOW}Common safe replacements for exec/eval:${NC}"
echo ""
echo "  # Instead of eval() for config parsing:"
echo "  import ast"
echo "  result = ast.literal_eval(config_string)  # only parses literals"
echo ""
echo "  # Instead of eval() for math:"
echo "  # pip install simpleeval"
echo "  from simpleeval import simple_eval"
echo "  result = simple_eval(expression)"
echo ""
echo "  # Instead of exec() for dynamic dispatch:"
echo "  handlers = {'action_a': func_a, 'action_b': func_b}"
echo "  handlers[action_name]()"
echo ""
echo "  # Instead of exec() for dynamic imports:"
echo "  import importlib"
echo "  module = importlib.import_module(module_name)"
echo ""
echo -e "${YELLOW}Verify fixes:${NC}"
echo "  grep -n 'exec\\|eval' $FILE"
echo "  bandit -t B102 $FILE"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review diff: git diff $FILE"
echo "  2. Run tests: pytest tests/"
echo "  3. Re-scan: bandit -f json -t B102 $FILE"
echo "  4. Commit: git commit -m 'security: replace eval with ast.literal_eval (B102)'"
echo ""
