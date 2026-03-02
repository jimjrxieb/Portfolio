#!/usr/bin/env bash
# fix-env-reference.sh
# Replace a hardcoded secret with an environment variable reference.
#
# Usage:
#   bash fix-env-reference.sh <file> <line_number> <VAR_NAME>
#
# Error codes: Gitleaks (any), Bandit B105, B106, B107
#
# Semi-manual for safety — shows the replacement, you apply it.
# After fixing: ROTATE the exposed credential immediately.

set -euo pipefail

FILE="${1:-}"
LINE="${2:-}"
VAR_NAME="${3:-SECRET_VALUE}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$FILE" || -z "$LINE" ]]; then
  echo "Usage: bash fix-env-reference.sh <file> <line_number> <VAR_NAME>"
  echo ""
  echo "Example:"
  echo "  bash fix-env-reference.sh api/config.py 42 CLAUDE_API_KEY"
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  echo -e "${RED}ERROR: File not found: $FILE${NC}"
  exit 1
fi

EXT="${FILE##*.}"

echo ""
echo -e "${BLUE}=== Secret Remediation ===${NC}"
echo "  File    : $FILE"
echo "  Line    : $LINE"
echo "  Var name: $VAR_NAME"
echo ""

echo -e "${RED}CURRENT (line $LINE):${NC}"
sed -n "${LINE}p" "$FILE"
echo ""

cp "$FILE" "$FILE.bak"
echo -e "${YELLOW}Backup created: $FILE.bak${NC}"
echo ""

echo -e "${GREEN}REPLACEMENT:${NC}"

case "$EXT" in
  py)
    echo ""
    echo "  import os"
    echo "  ${VAR_NAME} = os.environ.get('${VAR_NAME}')"
    echo ""
    echo "  Add to .env.example:"
    echo "  ${VAR_NAME}=your_value_here"
    ;;
  js|ts|jsx|tsx)
    echo ""
    echo "  const ${VAR_NAME} = process.env.${VAR_NAME};"
    echo ""
    echo "  Add to .env.example:"
    echo "  ${VAR_NAME}=your_value_here"
    ;;
  yaml|yml)
    echo ""
    echo "  For Kubernetes — use secretKeyRef:"
    echo "  env:"
    echo "    - name: ${VAR_NAME}"
    echo "      valueFrom:"
    echo "        secretKeyRef:"
    echo "          name: app-secrets"
    echo "          key: ${VAR_NAME,,}"
    echo ""
    echo "  For GitHub Actions — use secrets:"
    echo "  env:"
    echo "    ${VAR_NAME}: \${{ secrets.${VAR_NAME} }}"
    ;;
  sh|bash)
    echo ""
    echo "  ${VAR_NAME}=\"\${${VAR_NAME}:?'${VAR_NAME} must be set'}\""
    ;;
  *)
    echo "  Set via environment variable: ${VAR_NAME}"
    ;;
esac

echo ""
echo -e "${RED}ROTATE THE CREDENTIAL NOW${NC}"
echo "  The exposed value is compromised — rotating later means it's still exploitable."
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Apply the replacement above to line $LINE"
echo "  2. Rotate the credential in the issuing system"
echo "  3. Add the env var to your deployment secrets (K8s Secret, SSM, etc.)"
echo "  4. Add to .env.example with a placeholder"
echo "  5. Purge from git history: bash fixers/secrets/git-purge-secret.sh $FILE"
echo "  6. Verify clean: gitleaks detect --source . --no-git"
echo ""
