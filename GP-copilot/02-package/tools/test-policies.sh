#!/usr/bin/env bash
# test-policies.sh
# Run conftest policy checks locally against Portfolio's K8s manifests.
# Validates infrastructure YAMLs against OPA/Rego policies in GP-copilot/02-package/conftest-policies/.
#
# Usage:
#   bash GP-copilot/02-package/tools/test-policies.sh
#   bash GP-copilot/02-package/tools/test-policies.sh --verbose

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
POLICY_DIR="${REPO_ROOT}/GP-copilot/02-package/conftest-policies"
VERBOSE=""

[[ "${1:-}" == "--verbose" ]] && VERBOSE="--trace"

echo ""
echo -e "${BLUE}=== Portfolio Policy Check ===${NC}"
echo "  Policies : ${POLICY_DIR}"
echo "  Repo root: ${REPO_ROOT}"
echo ""

# Check conftest is installed
if ! command -v conftest &>/dev/null; then
  echo -e "${RED}ERROR: conftest not installed${NC}"
  echo "  Install: https://www.conftest.dev/install/"
  echo "  brew install conftest"
  echo "  wget -q https://github.com/open-policy-agent/conftest/releases/download/v0.46.0/conftest_0.46.0_Linux_x86_64.tar.gz"
  exit 1
fi

FAIL=0

# 1. Run policy unit tests
echo -e "${BLUE}[1/3]${NC} Policy unit tests (conftest verify)"
if conftest verify --policy "${POLICY_DIR}" ${VERBOSE}; then
  echo -e "  ${GREEN}PASS${NC}"
else
  echo -e "  ${RED}FAIL${NC} — policy tests have errors"
  FAIL=1
fi
echo ""

# 2. Test Helm chart rendered manifests (if helm is available)
echo -e "${BLUE}[2/3]${NC} Helm chart manifests"
CHARTS_DIR="${REPO_ROOT}/infrastructure/charts/portfolio"
if [[ -d "$CHARTS_DIR" ]] && command -v helm &>/dev/null; then
  RENDERED=$(mktemp)
  if helm template portfolio "${CHARTS_DIR}" --values "${CHARTS_DIR}/values.yaml" > "$RENDERED" 2>/dev/null; then
    if conftest test "$RENDERED" --policy "${POLICY_DIR}" --all-namespaces ${VERBOSE}; then
      echo -e "  ${GREEN}PASS${NC}"
    else
      echo -e "  ${YELLOW}VIOLATIONS FOUND${NC} — review output above"
      FAIL=1
    fi
  else
    echo -e "  ${YELLOW}SKIP${NC} — helm template failed"
  fi
  rm -f "$RENDERED"
else
  echo -e "  ${YELLOW}SKIP${NC} — helm not installed or chart not found at ${CHARTS_DIR}"
fi
echo ""

# 3. Test any raw YAML manifests in infrastructure/
echo -e "${BLUE}[3/3]${NC} Infrastructure manifests"
INFRA_YAMLS=$(find "${REPO_ROOT}/infrastructure" -name "*.yaml" -not -path "*/charts/*" -not -path "*/.git/*" 2>/dev/null || true)
if [[ -n "$INFRA_YAMLS" ]]; then
  if echo "$INFRA_YAMLS" | xargs conftest test --policy "${POLICY_DIR}" --all-namespaces ${VERBOSE} 2>/dev/null; then
    echo -e "  ${GREEN}PASS${NC}"
  else
    echo -e "  ${YELLOW}VIOLATIONS FOUND${NC} — review output above"
    FAIL=1
  fi
else
  echo -e "  ${YELLOW}SKIP${NC} — no YAML files found in infrastructure/"
fi
echo ""

# Summary
if [[ "$FAIL" -eq 0 ]]; then
  echo -e "${GREEN}=== All checks passed ===${NC}"
else
  echo -e "${YELLOW}=== Some checks had violations — review above ===${NC}"
fi
echo ""
exit $FAIL
