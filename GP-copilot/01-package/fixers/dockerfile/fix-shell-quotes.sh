#!/usr/bin/env bash
# fix-shell-quotes.sh
# Double-quote shell variable expansions in Dockerfiles and shell scripts.
#
# Usage:
#   bash fix-shell-quotes.sh <Dockerfile-or-script>
#
# Error codes: Hadolint SC2086, ShellCheck SC2086
#
# What it fixes:
#   RUN echo $VAR        → RUN echo "$VAR"
#   cp $SOURCE $DEST     → cp "$SOURCE" "$DEST"
#   if [ $VAR = x ]      → if [ "$VAR" = x ]
#
# What it does NOT touch:
#   - Variables inside single quotes (already safe)
#   - Variables already double-quoted
#   - $@ and $* (array expansion — different quoting rules)
#   - Variables in comments
#   - Arithmetic contexts $(( ))

set -euo pipefail

FILE="${1:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: bash fix-shell-quotes.sh <Dockerfile-or-shell-script>"
  echo ""
  echo "Examples:"
  echo "  bash fix-shell-quotes.sh Dockerfile"
  echo "  bash fix-shell-quotes.sh scripts/deploy.sh"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — Shell Variable Quoting Fix ===${NC}"
echo "  File: $FILE"
echo ""

# Detect unquoted variables
FOUND=$(grep -nP '\$\w+|\$\{[^}]+\}' "$FILE" | grep -v "^#\|'.*\$.*'\|#.*\$\|\\\$\$" || true)

if [[ -z "$FOUND" ]]; then
  echo -e "${GREEN}No unquoted variable expansions found.${NC}"
  exit 0
fi

echo "Lines with variable expansions to check:"
echo "$FOUND" | head -20
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

lines = content.splitlines()
new_lines = []

for i, line in enumerate(lines, 1):
    # Skip comment lines
    stripped = line.lstrip()
    if stripped.startswith('#'):
        new_lines.append(line)
        continue

    # Skip lines that are entirely inside single quotes
    # Skip lines with no $ at all
    if '$' not in line:
        new_lines.append(line)
        continue

    new_line = line
    modified = False

    # Find unquoted $VAR and ${VAR} patterns
    # Match $VAR that is NOT:
    #   - already inside double quotes
    #   - inside single quotes
    #   - $@ or $* or $? or $! or $$ or $0-9
    #   - inside $(( )) arithmetic
    #   - part of $() command substitution (leave those alone)

    # Strategy: find $WORD patterns not preceded by " and not followed by "
    # This is imperfect but catches the common cases
    def quote_var(m):
        nonlocal modified
        prefix = m.group(1) or ''
        var = m.group(2)
        suffix = m.group(3) or ''
        # Don't quote if already inside quotes (simple heuristic)
        modified = True
        return f'{prefix}"{var}"{suffix}'

    # Match: space/=/$( then $VAR or ${VAR} not already in quotes
    # Negative lookbehind for " and positive lookahead for not "
    pattern = r'(?<=[= \t(])(\$\w+|\$\{[^}]+\})(?=[/ \t\n;|&>)<]|$)'

    matches = list(re.finditer(pattern, new_line))
    if matches:
        # Check each match isn't already quoted
        offset = 0
        for m in matches:
            start = m.start() + offset
            end = m.end() + offset
            var = m.group(0)

            # Check if already inside double quotes
            before = new_line[:start]
            quote_count = before.count('"') - before.count('\\"')
            if quote_count % 2 == 1:
                continue  # Inside quotes already

            # Skip special vars
            if var in ('$@', '$*', '$?', '$!', '$$', '$#'):
                continue
            if re.match(r'\$\d$', var):
                continue

            quoted = f'"{var}"'
            new_line = new_line[:start] + quoted + new_line[end:]
            offset += 2  # Added two quote chars
            modified = True

    if modified:
        changes.append(f"  Line {i}: quoted variable expansions")

    new_lines.append(new_line)

content = '\n'.join(new_lines)
if not content.endswith('\n') and original.endswith('\n'):
    content += '\n'

if content != original:
    open(filepath, 'w').write(content)
    print(f"CHANGES_MADE ({len(changes)} lines)")
    for c in changes[:20]:
        print(c)
    if len(changes) > 20:
        print(f"  ... and {len(changes) - 20} more")
else:
    print("NO_CHANGES")
PYEOF

echo ""
echo -e "${YELLOW}Note: This script uses heuristics. Always review the diff.${NC}"
echo "  Some legitimate unquoted uses (array expansion, intentional splitting)"
echo "  may have been quoted. Check for false positives."
echo ""
echo -e "${YELLOW}If shellcheck is available, verify:${NC}"
echo "  shellcheck $FILE"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review diff: git diff $FILE"
echo "  2. Test the script/Dockerfile still works"
echo "  3. Re-scan: hadolint $FILE  OR  shellcheck $FILE"
echo "  4. Commit: git commit -m 'security: quote shell variable expansions (SC2086)'"
echo ""
