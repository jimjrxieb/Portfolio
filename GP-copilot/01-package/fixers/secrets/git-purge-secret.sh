#!/usr/bin/env bash
# git-purge-secret.sh
# Remove a secret-containing file from git history entirely.
#
# Usage:
#   bash git-purge-secret.sh <file-path>
#
# WARNING: This rewrites git history.
# Coordinate with the team before running on a shared branch.
# Requires: git-filter-repo (preferred) or git filter-branch

set -euo pipefail

FILE="${1:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$FILE" ]]; then
  echo "Usage: bash git-purge-secret.sh <file-path>"
  echo "Example: bash git-purge-secret.sh api/config.py"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Git History Purge ===${NC}"
echo "  File: $FILE"
echo ""
echo -e "${RED}This rewrites git history. Read before proceeding.${NC}"
echo ""
echo "  1. ROTATE the credential FIRST"
echo "  2. Coordinate with team — they must re-clone after this"
echo "  3. Force-push will be required"
echo ""

read -rp "Have you rotated the credential? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Stopping. Rotate the credential first, then re-run."
  exit 1
fi

echo ""

if command -v git-filter-repo &> /dev/null; then
  echo "Using git-filter-repo."
  echo "Running: git filter-repo --path \"$FILE\" --invert-paths"
  echo ""
  read -rp "Confirm rewrite (yes/no): " CONFIRM2
  if [[ "$CONFIRM2" != "yes" ]]; then echo "Cancelled."; exit 0; fi

  git filter-repo --path "$FILE" --invert-paths
  echo ""
  echo -e "${GREEN}History rewritten. File removed from all commits.${NC}"

elif command -v git &> /dev/null; then
  echo "git-filter-repo not found — using git filter-branch."
  echo "Install git-filter-repo for better performance: pip install git-filter-repo"
  echo ""
  read -rp "Continue with git filter-branch? (yes/no): " CONFIRM3
  if [[ "$CONFIRM3" != "yes" ]]; then echo "Cancelled."; exit 0; fi

  git filter-branch --force --index-filter \
    "git rm --cached --ignore-unmatch \"$FILE\"" \
    --prune-empty --tag-name-filter cat -- --all

  echo ""
  echo -e "${GREEN}History rewritten using filter-branch.${NC}"
else
  echo -e "${RED}ERROR: git not found.${NC}"
  exit 1
fi

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Force-push: git push origin --force --all && git push origin --force --tags"
echo "  2. Team must re-clone (fresh clone, not pull)"
echo "  3. Verify: gitleaks detect --source . --log-opts='--all'"
echo "  4. Add to .gitignore if it should never be tracked"
echo ""
