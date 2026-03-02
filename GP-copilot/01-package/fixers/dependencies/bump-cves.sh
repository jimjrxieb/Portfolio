#!/usr/bin/env bash
# bump-cves.sh
# Upgrade a vulnerable package to its patched version.
#
# Usage:
#   bash bump-cves.sh <package-manager> <package-name> <fixed-version>
#
# Error codes: Trivy (any CVE), Grype (any CVE), Safety (any)
#
# Supported: pip, npm, yarn, go, gem
#
# Examples:
#   bash bump-cves.sh pip python-multipart 0.0.20
#   bash bump-cves.sh npm lodash 4.17.21

set -euo pipefail

PKG_MGR="${1:-}"
PACKAGE="${2:-}"
VERSION="${3:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$PKG_MGR" || -z "$PACKAGE" || -z "$VERSION" ]]; then
  echo "Usage: bash bump-cves.sh <package-manager> <package-name> <fixed-version>"
  echo ""
  echo "  package-manager : pip | npm | yarn | go | gem"
  echo "  package-name    : exact package name from scanner output"
  echo "  fixed-version   : version that fixes the CVE"
  echo ""
  echo "Examples:"
  echo "  bash bump-cves.sh pip python-multipart 0.0.20"
  echo "  bash bump-cves.sh npm lodash 4.17.21"
  exit 1
fi

echo ""
echo -e "${BLUE}=== CVE Dependency Fix ===${NC}"
echo "  Package manager : $PKG_MGR"
echo "  Package         : $PACKAGE"
echo "  Target version  : $VERSION"
echo ""

case "$PKG_MGR" in

  pip)
    if [[ ! -f "requirements.txt" ]]; then
      echo -e "${RED}ERROR: requirements.txt not found.${NC}"
      exit 1
    fi

    echo "Current entry:"
    grep -i "$PACKAGE" requirements.txt || echo "  (not pinned — indirect dependency)"
    echo ""

    cp requirements.txt requirements.txt.bak
    echo -e "${YELLOW}Backup: requirements.txt.bak${NC}"

    if grep -qi "^${PACKAGE}" requirements.txt; then
      sed -i "s|^${PACKAGE}[>=<~!]*.*|${PACKAGE}>=${VERSION}|I" requirements.txt
      echo -e "${GREEN}Updated: ${PACKAGE}>=${VERSION}${NC}"
    else
      echo "${PACKAGE}>=${VERSION}" >> requirements.txt
      echo -e "${GREEN}Added: ${PACKAGE}>=${VERSION}${NC}"
    fi

    echo ""
    echo "Installing..."
    pip install "${PACKAGE}>=${VERSION}" --quiet && \
      echo -e "${GREEN}Installed successfully.${NC}" || \
      echo -e "${RED}Install failed — check version compatibility.${NC}"
    ;;

  npm)
    if [[ ! -f "package.json" ]]; then
      echo -e "${RED}ERROR: package.json not found.${NC}"
      exit 1
    fi

    echo "Installing ${PACKAGE}@${VERSION}..."
    npm install "${PACKAGE}@${VERSION}" --save && \
      echo -e "${GREEN}npm install completed.${NC}" || \
      echo -e "${RED}npm install failed.${NC}"
    ;;

  yarn)
    if [[ ! -f "yarn.lock" ]]; then
      echo -e "${RED}ERROR: yarn.lock not found.${NC}"
      exit 1
    fi

    echo "Upgrading ${PACKAGE} to ${VERSION}..."
    yarn upgrade "${PACKAGE}@${VERSION}" && \
      echo -e "${GREEN}yarn upgrade completed.${NC}" || \
      echo -e "${RED}yarn upgrade failed.${NC}"
    ;;

  go)
    if [[ ! -f "go.mod" ]]; then
      echo -e "${RED}ERROR: go.mod not found.${NC}"
      exit 1
    fi

    echo "Updating go.mod..."
    go get "${PACKAGE}@${VERSION}" && go mod tidy && \
      echo -e "${GREEN}go get + tidy completed.${NC}" || \
      echo -e "${RED}go get failed.${NC}"
    ;;

  gem|bundler)
    if [[ ! -f "Gemfile" ]]; then
      echo -e "${RED}ERROR: Gemfile not found.${NC}"
      exit 1
    fi

    cp Gemfile Gemfile.bak
    if grep -q "gem ['\"]${PACKAGE}['\"]" Gemfile; then
      sed -i "s|gem ['\"]${PACKAGE}['\"].*|gem '${PACKAGE}', '>= ${VERSION}'|" Gemfile
      echo -e "${GREEN}Updated ${PACKAGE} in Gemfile.${NC}"
    else
      echo "gem '${PACKAGE}', '>= ${VERSION}'" >> Gemfile
      echo -e "${GREEN}Added ${PACKAGE} to Gemfile.${NC}"
    fi
    bundle update "${PACKAGE}" && \
      echo -e "${GREEN}bundle update completed.${NC}" || \
      echo -e "${RED}bundle update failed.${NC}"
    ;;

  *)
    echo -e "${RED}ERROR: Unknown package manager: $PKG_MGR${NC}"
    echo "Supported: pip, npm, yarn, go, gem"
    exit 1
    ;;
esac

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Run tests to check for breaking changes"
echo "  2. Re-scan: trivy fs . --scanners vuln"
echo "  3. Commit: git commit -m 'security: bump ${PACKAGE} to ${VERSION} (CVE fix)'"
echo ""
