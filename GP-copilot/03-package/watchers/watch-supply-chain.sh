#!/usr/bin/env bash
# watch-supply-chain.sh — Container supply chain auditor
# Part of GP-CONSULTING/03-DEPLOY-RUNTIME/watchers/
#
# Matches: GP-BEDROCK-AGENTS/jsa-infrasec/src/layer2_supply_chain/watchers/supply_chain_watcher.py
#
# Checks:
#   1. Images from untrusted registries                            → MEDIUM
#   2. Unsigned images (cosign verify fails)                       → HIGH
#   3. Images without SBOMs (trivy check)                          → MEDIUM
#
# Dependencies: kubectl, python3
# Optional:     cosign (for signature checks), trivy (for SBOM checks)
#
# References:
#   CKS: Supply Chain Security - Image Footprint, Signing
#   SLSA Level 2: Signed provenance

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

NAMESPACE=""
REPORT=""
SKIP_SYSTEM=true
CHECK_SIGNATURES=true
CHECK_SBOM=false
JSON_OUTPUT=false
SCRIPT_NAME="$(basename "$0")"

# Default allowed registries — matches supply_chain_watcher.py
ALLOWED_REGISTRIES="gcr.io registry.k8s.io quay.io docker.io ghcr.io public.ecr.aws"

SYSTEM_NS="kube-system kube-public kube-node-lease"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Audit container image supply chain: registries, signatures, SBOMs.

Options:
  --namespace NS       Scan a single namespace (default: all namespaces)
  --include-system     Include system namespaces
  --skip-signatures    Skip cosign signature verification
  --check-sbom         Enable SBOM checks (requires trivy, slow)
  --allowed-registries "reg1 reg2 ..."  Override allowed registry list
  --report FILE        Write markdown report to FILE
  --json            Output structured JSON findings (for piping to responders)
  -h, --help           Show this help

Examples:
  bash $SCRIPT_NAME                              # registry check + signatures
  bash $SCRIPT_NAME --skip-signatures            # registry check only (fast)
  bash $SCRIPT_NAME --check-sbom                 # full audit (slow)
  bash $SCRIPT_NAME --namespace production       # single namespace
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --namespace)           NAMESPACE="$2"; shift 2 ;;
        --include-system)      SKIP_SYSTEM=false; shift ;;
        --skip-signatures)     CHECK_SIGNATURES=false; shift ;;
        --check-sbom)          CHECK_SBOM=true; shift ;;
        --allowed-registries)  ALLOWED_REGISTRIES="$2"; shift 2 ;;
        --report)              REPORT="$2"; shift 2 ;;
        --json)                JSON_OUTPUT=true; shift ;;
        -h|--help)             usage; exit 0 ;;
        *)                     echo -e "${RED}Unknown option: $1${RESET}"; usage; exit 1 ;;
    esac
done

if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}ERROR: Cannot reach cluster.${RESET}"
    exit 1
fi

HAS_COSIGN=false
HAS_TRIVY=false
if command -v cosign &>/dev/null; then HAS_COSIGN=true; fi
if command -v trivy &>/dev/null; then HAS_TRIVY=true; fi

echo ""
echo -e "${BOLD}=== Supply Chain Audit ===${RESET}"
echo -e "  Cluster:    $(kubectl config current-context)"
echo -e "  Time:       $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo -e "  cosign:     $( [[ "$HAS_COSIGN" == "true" ]] && echo "available" || echo "not installed (signature checks skipped)" )"
echo -e "  trivy:      $( [[ "$HAS_TRIVY" == "true" ]] && echo "available" || echo "not installed (SBOM checks skipped)" )"
echo -e "  Allowed:    $ALLOWED_REGISTRIES"
echo ""

# Build kubectl command
if [[ -n "$NAMESPACE" ]]; then
    KUBECTL_CMD="kubectl get pods -n $NAMESPACE -o json"
else
    KUBECTL_CMD="kubectl get pods --all-namespaces -o json"
fi

# Step 1: Registry check (always runs, fast)
echo -e "${BOLD}--- Registry Check ---${RESET}"
echo ""

REGISTRY_RESULTS=$($KUBECTL_CMD 2>/dev/null | python3 -c "
import sys, json

SYSTEM_NS = {'kube-system', 'kube-public', 'kube-node-lease'}
skip_system = $( [[ "$SKIP_SYSTEM" == "true" ]] && echo "True" || echo "False" )

ALLOWED = set('$ALLOWED_REGISTRIES'.split())

pods = json.load(sys.stdin)
seen_images = set()
untrusted = []
trusted = []

for pod in pods.get('items', []):
    ns = pod['metadata'].get('namespace', 'default')
    pod_name = pod['metadata']['name']
    if skip_system and ns in SYSTEM_NS:
        continue

    spec = pod.get('spec', {})
    for container in spec.get('containers', []) + spec.get('initContainers', []):
        image = container.get('image', '')
        if not image or image in seen_images:
            continue
        seen_images.add(image)

        # Extract registry — matches supply_chain_watcher.py logic
        parts = image.split('/')
        if len(parts) == 1:
            registry = 'docker.io'
        elif '.' in parts[0] or ':' in parts[0]:
            registry = parts[0]
        else:
            registry = 'docker.io'

        is_allowed = any(registry == a or registry.startswith(a) for a in ALLOWED)

        if not is_allowed:
            untrusted.append(f'{ns}|{pod_name}|{image}|{registry}')
        else:
            trusted.append(f'{ns}|{pod_name}|{image}|{registry}')

for item in untrusted:
    print(f'UNTRUSTED|{item}')
for item in trusted:
    print(f'TRUSTED|{item}')
print(f'REG_SUMMARY|{len(seen_images)}|{len(untrusted)}|{len(trusted)}')
")

UNTRUSTED_COUNT=0
TRUSTED_COUNT=0
TOTAL_IMAGES=0
UNIQUE_UNTRUSTED_IMAGES=""

REPORT_LINES=""
report() { REPORT_LINES+="$1"$'\n'; }

# JSON findings collector (pipe-delimited: code|severity|namespace|resource|message|responder|args)
JSON_LINES=""
jf() { JSON_LINES+="$1|$2|$3|$4|$5|$6|$7"$'\n'; }

report "# Supply Chain Audit — $(date -u '+%Y-%m-%d %H:%M UTC')"
report ""
report "Cluster: $(kubectl config current-context)"
report ""
report "## Registry Check"
report ""
report "Allowed: \`$ALLOWED_REGISTRIES\`"
report ""
report "| Image | Registry | Namespace | Pod | Status |"
report "|-------|----------|-----------|-----|--------|"

while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    STATUS=$(echo "$line" | cut -d'|' -f1)

    if [[ "$STATUS" == "REG_SUMMARY" ]]; then
        TOTAL_IMAGES=$(echo "$line" | cut -d'|' -f2)
        UNTRUSTED_COUNT=$(echo "$line" | cut -d'|' -f3)
        TRUSTED_COUNT=$(echo "$line" | cut -d'|' -f4)
        continue
    fi

    NS=$(echo "$line" | cut -d'|' -f2)
    POD=$(echo "$line" | cut -d'|' -f3)
    IMAGE=$(echo "$line" | cut -d'|' -f4)
    REGISTRY=$(echo "$line" | cut -d'|' -f5)

    if [[ "$STATUS" == "UNTRUSTED" ]]; then
        echo -e "  ${YELLOW}MEDIUM${RESET}    $IMAGE (registry: $REGISTRY) in $NS/$POD"
        report "| $IMAGE | $REGISTRY | $NS | $POD | UNTRUSTED |"
        jf "REGISTRY_UNTRUSTED" "MEDIUM" "$NS" "$IMAGE" "Image from untrusted registry: $REGISTRY" "" ""
        UNIQUE_UNTRUSTED_IMAGES+="$IMAGE"$'\n'
    else
        report "| $IMAGE | $REGISTRY | $NS | $POD | trusted |"
    fi
done <<< "$REGISTRY_RESULTS"

if [[ "$UNTRUSTED_COUNT" -eq 0 ]]; then
    echo -e "  ${GREEN}PASS${RESET}      All $TOTAL_IMAGES unique images from allowed registries"
fi

# Step 2: Signature check (requires cosign)
UNSIGNED_COUNT=0

if [[ "$CHECK_SIGNATURES" == "true" && "$HAS_COSIGN" == "true" ]]; then
    echo ""
    echo -e "${BOLD}--- Signature Verification ---${RESET}"
    echo ""

    report ""
    report "## Signature Verification"
    report ""
    report "| Image | Signed | Severity |"
    report "|-------|--------|----------|"

    # Get unique images
    UNIQUE_IMAGES=$($KUBECTL_CMD 2>/dev/null | python3 -c "
import sys, json
SYSTEM_NS = {'kube-system', 'kube-public', 'kube-node-lease'}
skip_system = $( [[ "$SKIP_SYSTEM" == "true" ]] && echo "True" || echo "False" )
pods = json.load(sys.stdin)
seen = set()
for pod in pods.get('items', []):
    ns = pod['metadata'].get('namespace', 'default')
    if skip_system and ns in SYSTEM_NS:
        continue
    for c in pod['spec'].get('containers', []) + pod['spec'].get('initContainers', []):
        img = c.get('image', '')
        if img and img not in seen:
            seen.add(img)
            print(img)
")

    SIGNED_COUNT=0
    while IFS= read -r image; do
        [[ -z "$image" ]] && continue

        # cosign verify with 15s timeout
        if timeout 15 cosign verify "$image" &>/dev/null 2>&1; then
            SIGNED_COUNT=$((SIGNED_COUNT + 1))
            report "| $image | yes | PASS |"
        else
            echo -e "  ${YELLOW}HIGH${RESET}      $image — unsigned or verification failed"
            report "| $image | no | HIGH |"
            jf "IMAGE_UNSIGNED" "HIGH" "" "$image" "Image unsigned or signature verification failed" "" ""
            UNSIGNED_COUNT=$((UNSIGNED_COUNT + 1))
        fi
    done <<< "$UNIQUE_IMAGES"

    if [[ "$UNSIGNED_COUNT" -eq 0 ]]; then
        echo -e "  ${GREEN}PASS${RESET}      All images have valid signatures"
    fi
elif [[ "$CHECK_SIGNATURES" == "true" && "$HAS_COSIGN" == "false" ]]; then
    echo ""
    echo -e "  ${CYAN}SKIP${RESET}      cosign not installed — signature checks skipped"
    echo "            Install: https://docs.sigstore.dev/cosign/system_config/installation/"
fi

# Step 3: SBOM check (requires trivy, opt-in)
MISSING_SBOM_COUNT=0

if [[ "$CHECK_SBOM" == "true" && "$HAS_TRIVY" == "true" ]]; then
    echo ""
    echo -e "${BOLD}--- SBOM Verification ---${RESET}"
    echo ""

    report ""
    report "## SBOM Verification"
    report ""
    report "| Image | SBOM | Severity |"
    report "|-------|------|----------|"

    while IFS= read -r image; do
        [[ -z "$image" ]] && continue

        if timeout 30 trivy image --format json --scanners config "$image" &>/dev/null 2>&1; then
            report "| $image | present | PASS |"
        else
            echo -e "  ${YELLOW}MEDIUM${RESET}    $image — no SBOM or scan failed"
            report "| $image | missing | MEDIUM |"
            jf "IMAGE_NO_SBOM" "MEDIUM" "" "$image" "No SBOM or SBOM scan failed" "" ""
            MISSING_SBOM_COUNT=$((MISSING_SBOM_COUNT + 1))
        fi
    done <<< "$UNIQUE_IMAGES"

    if [[ "$MISSING_SBOM_COUNT" -eq 0 ]]; then
        echo -e "  ${GREEN}PASS${RESET}      All images have SBOMs"
    fi
elif [[ "$CHECK_SBOM" == "true" && "$HAS_TRIVY" == "false" ]]; then
    echo ""
    echo -e "  ${CYAN}SKIP${RESET}      trivy not installed — SBOM checks skipped"
fi

echo ""
echo -e "${BOLD}=== Summary ===${RESET}"
echo "  Unique images:  $TOTAL_IMAGES"
echo -e "  ${YELLOW}MEDIUM${RESET}  : $UNTRUSTED_COUNT untrusted registry"
echo -e "  ${YELLOW}HIGH${RESET}    : $UNSIGNED_COUNT unsigned images"
echo -e "  ${YELLOW}MEDIUM${RESET}  : $MISSING_SBOM_COUNT missing SBOMs"
echo -e "  ${GREEN}TRUSTED${RESET} : $TRUSTED_COUNT"
echo ""

TOTAL_FINDINGS=$((UNTRUSTED_COUNT + UNSIGNED_COUNT + MISSING_SBOM_COUNT))
if [[ $TOTAL_FINDINGS -gt 0 ]]; then
    echo "Fixes:"
    if [[ $UNTRUSTED_COUNT -gt 0 ]]; then
        echo "  Registry: Mirror images to an allowed registry, or update --allowed-registries"
    fi
    if [[ $UNSIGNED_COUNT -gt 0 ]]; then
        echo "  Signatures: Sign images with cosign: cosign sign <image>"
    fi
    if [[ $MISSING_SBOM_COUNT -gt 0 ]]; then
        echo "  SBOMs: Generate with: trivy image --format spdx-json <image> > sbom.json"
    fi
    echo ""
fi

report ""
report "## Summary"
report ""
report "- Unique images: $TOTAL_IMAGES"
report "- Untrusted registry: $UNTRUSTED_COUNT"
report "- Unsigned: $UNSIGNED_COUNT"
report "- Missing SBOM: $MISSING_SBOM_COUNT"
report "- Trusted: $TRUSTED_COUNT"

if [[ -n "$REPORT" ]]; then
    echo "$REPORT_LINES" > "$REPORT"
    echo "Report written to: $REPORT"
fi

# JSON output mode
if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo "$JSON_LINES" | python3 -c "
import sys, json
findings = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split('|', 6)
    if len(parts) < 5:
        continue
    f = {'code': parts[0], 'severity': parts[1], 'namespace': parts[2], 'resource': parts[3], 'message': parts[4]}
    if len(parts) > 5 and parts[5]:
        f['responder'] = parts[5]
    if len(parts) > 6 and parts[6]:
        f['args'] = parts[6]
    findings.append(f)
json.dump({'watcher': 'watch-supply-chain', 'findings': findings, 'summary': {'total': len(findings), 'critical': sum(1 for f in findings if f['severity'] == 'CRITICAL'), 'high': sum(1 for f in findings if f['severity'] == 'HIGH'), 'medium': sum(1 for f in findings if f['severity'] == 'MEDIUM')}}, sys.stdout, indent=2)
print()
"
fi
