#!/usr/bin/env bash
# generate-sbom.sh
# Generate SBOM (Software Bill of Materials) for a project or container image.
#
# Usage:
#   bash generate-sbom.sh --fs <project-dir>       # Filesystem scan
#   bash generate-sbom.sh --image <image:tag>       # Container image scan
#   bash generate-sbom.sh --fs <dir> --check-licenses  # With license compliance
#
# CKS alignment: Supply chain security — know what's in your software.
# CNPE alignment: Observability — track dependencies across the platform.
#
# What it does:
#   - Generates CycloneDX SBOM using Trivy
#   - Optionally checks for copyleft/GPL licenses
#   - Outputs to project's sbom/ directory
#
# Requires: trivy

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

MODE=""
TARGET=""
CHECK_LICENSES=false
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fs) MODE="fs"; TARGET="$2"; shift 2 ;;
    --image) MODE="image"; TARGET="$2"; shift 2 ;;
    --check-licenses) CHECK_LICENSES=true; shift ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$MODE" || -z "$TARGET" ]]; then
  echo "Usage:"
  echo "  bash generate-sbom.sh --fs <project-dir>"
  echo "  bash generate-sbom.sh --image <image:tag>"
  echo "  bash generate-sbom.sh --fs <dir> --check-licenses"
  exit 1
fi

if ! command -v trivy &>/dev/null; then
  echo -e "${RED}ERROR: trivy not found. Install: https://aquasecurity.github.io/trivy${NC}"
  exit 1
fi

# Set output directory
if [[ -z "$OUTPUT_DIR" ]]; then
  if [[ "$MODE" == "fs" ]]; then
    OUTPUT_DIR="$TARGET/sbom"
  else
    OUTPUT_DIR="./sbom"
  fi
fi
mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SBOM_FILE="$OUTPUT_DIR/sbom-${TIMESTAMP}.cdx.json"

echo ""
echo -e "${BLUE}=== Ghost Protocol — SBOM Generation ===${NC}"
echo "  Mode   : $MODE"
echo "  Target : $TARGET"
echo "  Output : $SBOM_FILE"
echo ""

# Generate SBOM
echo "Generating CycloneDX SBOM..."
trivy "$MODE" "$TARGET" --format cyclonedx --output "$SBOM_FILE" 2>/dev/null

if [[ ! -f "$SBOM_FILE" ]]; then
  echo -e "${RED}ERROR: SBOM generation failed${NC}"
  exit 1
fi

# Count components
COMPONENT_COUNT=$(python3 -c "
import json
with open('$SBOM_FILE') as f:
    sbom = json.load(f)
print(len(sbom.get('components', [])))
" 2>/dev/null || echo "unknown")

echo -e "${GREEN}SBOM generated: $COMPONENT_COUNT components${NC}"
echo "  File: $SBOM_FILE"

# License compliance check
if $CHECK_LICENSES; then
  echo ""
  echo -e "${BLUE}Checking license compliance...${NC}"

  COPYLEFT_LICENSES="GPL|AGPL|LGPL|SSPL|EUPL|OSL|CPAL|RPL|Sleepycat|Watcom"

  python3 - "$SBOM_FILE" "$COPYLEFT_LICENSES" <<'PYEOF'
import json
import re
import sys

sbom_file = sys.argv[1]
copyleft_pattern = sys.argv[2]

with open(sbom_file) as f:
    sbom = json.load(f)

flagged = []
for comp in sbom.get("components", []):
    for lic in comp.get("licenses", []):
        lic_id = ""
        if "license" in lic:
            lic_id = lic["license"].get("id", lic["license"].get("name", ""))
        elif "expression" in lic:
            lic_id = lic["expression"]
        if re.search(copyleft_pattern, lic_id, re.IGNORECASE):
            flagged.append({
                "component": f"{comp.get('name', '?')}@{comp.get('version', '?')}",
                "license": lic_id
            })

if flagged:
    print(f"\n⚠ {len(flagged)} component(s) with copyleft licenses:")
    for f in flagged:
        print(f"  • {f['component']} — {f['license']}")
    print("\nReview these for proprietary compatibility.")
    print("If shipping proprietary software, these may require source disclosure.")
else:
    print("\n✓ No copyleft license issues detected.")

PYEOF
fi

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Archive SBOM with build artifacts (CI/CD)"
echo "  2. Re-generate on every release"
echo "  3. Monitor for new CVEs: trivy sbom $SBOM_FILE"
echo "  4. Commit: git commit -m 'supply-chain: add SBOM generation (CycloneDX)'"
echo ""
