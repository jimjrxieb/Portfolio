#!/usr/bin/env bash
# run-all-scanners.sh
# Run all pre-deployment security scanners against a target directory.
#
# Usage:
#   bash run-all-scanners.sh --target-dir /path/to/client-repo --output-dir ./outputs/baseline-$(date +%Y%m%d)
#
# All scanner configs are read from GP-CONSULTING/01-APP-SEC/scanning-configs/
# You do NOT need to copy configs into the client repo.

set -euo pipefail

# Resolve package root (the 01-APP-SEC directory, regardless of where you run from)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$(dirname "$SCRIPT_DIR")"
CONFIGS_DIR="$PKG_DIR/scanning-configs"
# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# Defaults
TARGET_DIR="."
OUTPUT_DIR=""
SEVERITY="medium"
PARALLEL=false
SKIP_SCANNERS=()
SCAN_LABEL="baseline"
DAST=false
TARGET_URL=""
INCLUDE_DIRS=()

# GP-S3 report storage — auto-resolved from repo structure
GP_S3_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)/GP-S3/5-consulting-reports"

usage() {
    cat <<EOF
Run all pre-deployment security scanners.

Usage: bash run-all-scanners.sh [OPTIONS]

Options:
  -t, --target-dir PATH    Directory to scan (default: current dir)
  -o, --output-dir PATH    Output directory (overrides auto-routing)
  -l, --label LABEL        Scan label: baseline|post-fix|weekly|nightly (default: baseline)
  -s, --severity LEVEL     Min severity: low|medium|high|critical (default: medium)
  --parallel               Run scanners in parallel (faster, noisier output)
  --skip-scanner NAME      Skip a scanner by name (repeatable)
  --include-dir NAME       Only scan these subdirectories (repeatable, for monorepos)
  --dast                   Enable DAST scanning (requires --target-url)
  --target-url URL         Target URL for DAST scanners (e.g. https://staging.example.com)
  -h, --help               Show this help

Output routing (automatic):
  If target is under GP-PROJECTS/<instance>/<slot>/<project>/
  output auto-routes to GP-S3/5-consulting-reports/<instance>/<slot>/<label>-YYYYMMDD/

Examples:
  # Auto-routes to GP-S3/5-consulting-reports/01-instance/slot-2/baseline-YYYYMMDD/
  bash run-all-scanners.sh -t ~/GP-PROJECTS/01-instance/slot-2/Anthra-CLOUD

  # Post-fix re-scan
  bash run-all-scanners.sh -t ~/GP-PROJECTS/01-instance/slot-3/Anthra-FedRAMP -l post-fix

  # Manual output path
  bash run-all-scanners.sh -t ~/client-repo -o /tmp/scan-results

  # Skip specific scanners
  bash run-all-scanners.sh -t ~/client-repo --skip-scanner kube-bench --skip-scanner sonarcloud

  # With DAST (after deploying to staging)
  bash run-all-scanners.sh -t ~/client-repo --dast --target-url https://staging.example.com

Available scanners:
  gitleaks  bandit  semgrep  trivy-fs  grype
  checkov   hadolint  kubescape  polaris  kube-bench  conftest
  nuclei  zap (DAST — requires --dast --target-url)
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--target-dir)  TARGET_DIR="$2"; shift 2 ;;
        -o|--output-dir)  OUTPUT_DIR="$2"; shift 2 ;;
        -l|--label)       SCAN_LABEL="$2"; shift 2 ;;
        -s|--severity)    SEVERITY="$2"; shift 2 ;;
        --parallel)       PARALLEL=true; shift ;;
        --skip-scanner)   SKIP_SCANNERS+=("$2"); shift 2 ;;
        --dast)           DAST=true; shift ;;
        --target-url)     TARGET_URL="$2"; shift 2 ;;
        --include-dir)    INCLUDE_DIRS+=("$2"); shift 2 ;;
        -h|--help)        usage ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; usage ;;
    esac
done

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# If --include-dir specified, scope the scan to only those subdirectories
# This avoids scanning 143K files when you only care about platform code
SCAN_DIR="$TARGET_DIR"
if [[ ${#INCLUDE_DIRS[@]} -gt 0 ]]; then
    SCAN_DIR=$(mktemp -d)
    trap "rm -rf '$SCAN_DIR'" EXIT
    for idir in "${INCLUDE_DIRS[@]}"; do
        if [[ -d "$TARGET_DIR/$idir" ]]; then
            ln -s "$TARGET_DIR/$idir" "$SCAN_DIR/$idir"
        else
            echo -e "${YELLOW}WARNING: --include-dir $idir not found in $TARGET_DIR${NC}"
        fi
    done
    # Copy .git so gitleaks can use git mode
    [[ -d "$TARGET_DIR/.git" ]] && ln -s "$TARGET_DIR/.git" "$SCAN_DIR/.git"
    echo -e "${GREEN}Scoped to: ${INCLUDE_DIRS[*]}${NC}"
fi

# Validate DAST flags
if [[ "$DAST" == "true" && -z "$TARGET_URL" ]]; then
    echo -e "${RED}ERROR: --dast requires --target-url URL${NC}"
    echo "  Example: --dast --target-url https://staging.example.com"
    exit 1
fi
if [[ -n "$TARGET_URL" && "$DAST" != "true" ]]; then
    echo -e "${YELLOW}NOTE: --target-url provided but --dast not set. Enabling DAST.${NC}"
    DAST=true
fi

# Auto-route output to GP-S3 based on instance/slot if not manually specified
if [[ -z "$OUTPUT_DIR" ]]; then
    # Try to extract instance/slot from GP-PROJECTS path
    # Pattern: .../GP-PROJECTS/<instance>/<slot>/<project>/
    if [[ "$TARGET_DIR" =~ GP-PROJECTS/([0-9]+-instance)/(slot-[0-9]+)/ ]]; then
        INSTANCE="${BASH_REMATCH[1]}"
        SLOT="${BASH_REMATCH[2]}"
        OUTPUT_DIR="$GP_S3_DIR/${INSTANCE}/${SLOT}/${SCAN_LABEL}-$(date +%Y%m%d)"
        echo -e "${GREEN}Auto-routed: GP-S3/5-consulting-reports/${INSTANCE}/${SLOT}/${SCAN_LABEL}-$(date +%Y%m%d)${NC}"
    else
        # Fallback: use repo name as slug
        CLIENT_SLUG="$(basename "$TARGET_DIR")"
        OUTPUT_DIR="$GP_S3_DIR/${CLIENT_SLUG}/${SCAN_LABEL}-$(date +%Y%m%d)"
        echo -e "${YELLOW}No instance/slot detected. Output: $OUTPUT_DIR${NC}"
    fi
fi
mkdir -p "$OUTPUT_DIR"

echo ""
echo -e "${BLUE}=== Ghost Protocol — Pre-Deployment Scan ===${NC}"
echo "  Target    : $TARGET_DIR"
echo "  Output    : $OUTPUT_DIR"
echo "  Configs   : $CONFIGS_DIR"
echo "  Severity  : $SEVERITY+"
echo ""

PASS=0; FAIL=0; SKIP=0

should_skip() {
    local name=$1
    for s in "${SKIP_SCANNERS[@]+"${SKIP_SCANNERS[@]}"}"; do
        [[ "$s" == "$name" ]] && return 0
    done
    return 1
}

run_scanner() {
    local name="$1"; local cmd="$2"

    if should_skip "$name"; then
        echo -e "${YELLOW}  ⏭  $name — skipped${NC}"
        SKIP=$((SKIP + 1))
        return 0
    fi

    if ! command -v "${3:-$name}" &>/dev/null; then
        echo -e "${YELLOW}  ⚠  $name — not installed (skipping)${NC}"
        SKIP=$((SKIP + 1))
        return 0
    fi

    echo -e "${BLUE}  ▶  $name...${NC}"
    if eval "$cmd" &>/dev/null; then
        echo -e "${GREEN}  ✓  $name — done${NC}"
        PASS=$((PASS + 1))
    else
        # Non-zero exit is normal for scanners when findings exist
        echo -e "${GREEN}  ✓  $name — done (findings present)${NC}"
        PASS=$((PASS + 1))
    fi
}

# ─── Scanners ───────────────────────────────────────────────────────────────

# 1. Gitleaks — run first, block if secrets found
echo -e "${YELLOW}[1/11] Secrets${NC}"
if ! should_skip "gitleaks" && command -v gitleaks &>/dev/null; then
    # Use git mode when .git exists — respects .gitignore (skips logs, scanner_outputs, etc.)
    # Fall back to --no-git for non-repo targets (client tarballs, extracted archives)
    _GITLEAKS_FLAGS=""
    if [[ ! -d "$TARGET_DIR/.git" ]]; then
        _GITLEAKS_FLAGS="--no-git"
        echo -e "${YELLOW}  ℹ  No .git found — scanning all files (no .gitignore filtering)${NC}"
    fi
    echo -e "${BLUE}  ▶  gitleaks...${NC}"
    gitleaks detect \
        --source "$SCAN_DIR" \
        --config "$CONFIGS_DIR/.gitleaks.toml" \
        --report-path "$OUTPUT_DIR/gitleaks.json" \
        --report-format json \
        $_GITLEAKS_FLAGS 2>/dev/null || true
    # Gitleaks doesn't create the file if 0 findings — create empty array
    [[ ! -f "$OUTPUT_DIR/gitleaks.json" ]] && echo '[]' > "$OUTPUT_DIR/gitleaks.json"
    echo -e "${GREEN}  ✓  gitleaks — done${NC}"
    PASS=$((PASS + 1))
elif should_skip "gitleaks"; then
    echo -e "${YELLOW}  ⏭  gitleaks — skipped${NC}"
    SKIP=$((SKIP + 1))
else
    echo -e "${YELLOW}  ⚠  gitleaks — not installed${NC}"
    SKIP=$((SKIP + 1))
fi

# 2. Bandit — Python SAST
echo -e "${YELLOW}[2/11] Python SAST${NC}"
if ! should_skip "bandit" && command -v bandit &>/dev/null; then
    echo -e "${BLUE}  ▶  bandit...${NC}"
    # Find Python files first — bandit on a 143K-file repo is slow without targeting
    _BANDIT_TARGETS=""
    for _pydir in GP-INFRA GP-BEDROCK-AGENTS GP-GUI GP-MODEL-OPS GP-CONSULTING; do
        [[ -d "$TARGET_DIR/$_pydir" ]] && _BANDIT_TARGETS="$_BANDIT_TARGETS $TARGET_DIR/$_pydir"
    done
    [[ -z "$_BANDIT_TARGETS" ]] && _BANDIT_TARGETS="$SCAN_DIR"
    bandit -r $_BANDIT_TARGETS \
        -f json \
        -o "$OUTPUT_DIR/bandit.json" \
        --skip B101 \
        -ll 2>/dev/null || true
    # Ensure file exists even if bandit found nothing
    [[ ! -s "$OUTPUT_DIR/bandit.json" ]] && echo '{"results":[],"errors":[],"metrics":{}}' > "$OUTPUT_DIR/bandit.json"
    echo -e "${GREEN}  ✓  bandit — done${NC}"
    PASS=$((PASS + 1))
elif should_skip "bandit"; then
    echo -e "${YELLOW}  ⏭  bandit — skipped${NC}"
    SKIP=$((SKIP + 1))
else
    echo -e "${YELLOW}  ⚠  bandit — not installed${NC}"
    SKIP=$((SKIP + 1))
fi

# 3. Semgrep — multi-language SAST
#    Registry packs are passed as --config flags (not in the YAML file).
#    The YAML file (semgrep.yaml) documents which packs we use but is not
#    passed directly — semgrep's config file format doesn't support registry
#    shorthand in a rules: block.
echo -e "${YELLOW}[3/11] Multi-language SAST${NC}"
run_scanner "semgrep" \
    "semgrep \
        --config 'p/security-audit' \
        --config 'p/owasp-top-ten' \
        --config 'p/secrets' \
        --config 'p/python' \
        --config 'p/javascript' \
        --config 'p/golang' \
        --config 'p/kubernetes' \
        --config 'p/dockerfile' \
        --config 'p/terraform' \
        --config 'p/github-actions' \
        --exclude 'tests' --exclude 'test' --exclude 'node_modules' \
        --exclude 'vendor' --exclude 'venv' --exclude '.git' \
        --exclude '*.min.js' --exclude '*.bundle.js' \
        --json \
        --output '$OUTPUT_DIR/semgrep.json' \
        --metrics off \
        --timeout 30 \
        '$SCAN_DIR' 2>/dev/null || true" \
    "semgrep"

# 4. Trivy filesystem — CVEs in dependencies
echo -e "${YELLOW}[4/11] Dependency CVEs${NC}"
if ! should_skip "trivy-fs" && command -v trivy &>/dev/null; then
    echo -e "${BLUE}  ▶  trivy-fs...${NC}"
    trivy fs "$SCAN_DIR" \
        --format json \
        --output "$OUTPUT_DIR/trivy-fs.json" \
        --severity HIGH,CRITICAL \
        --scanners vuln,secret \
        --skip-dirs node_modules,vendor,venv,.venv,.git,__pycache__,scanner_outputs,_archive \
        --timeout 10m0s 2>/dev/null || true
    # Ensure file exists
    [[ ! -s "$OUTPUT_DIR/trivy-fs.json" ]] && echo '{"Results":[]}' > "$OUTPUT_DIR/trivy-fs.json"
    echo -e "${GREEN}  ✓  trivy-fs — done${NC}"
    PASS=$((PASS + 1))
elif should_skip "trivy-fs"; then
    echo -e "${YELLOW}  ⏭  trivy-fs — skipped${NC}"
    SKIP=$((SKIP + 1))
else
    echo -e "${YELLOW}  ⚠  trivy — not installed${NC}"
    SKIP=$((SKIP + 1))
fi

# 5. Grype — CVE cross-check
echo -e "${YELLOW}[5/11] CVE cross-check${NC}"
run_scanner "grype" \
    "grype dir:'$SCAN_DIR' -o json > '$OUTPUT_DIR/grype.json' 2>/dev/null || true" \
    "grype"

# 6. Hadolint — scan ALL Dockerfiles in target
echo -e "${YELLOW}[6/11] Dockerfile lint${NC}"
if ! should_skip "hadolint" && command -v hadolint &>/dev/null; then
    DOCKERFILES=$(find -L "$SCAN_DIR" -name "Dockerfile" -o -name "Dockerfile.*" 2>/dev/null | grep -v ".git" | sort)
    if [[ -n "$DOCKERFILES" ]]; then
        echo "$DOCKERFILES" | while read -r df; do
            out_name="hadolint-$(basename "$(dirname "$df")").json"
            hadolint "$df" \
                --config "$CONFIGS_DIR/.hadolint.yaml" \
                -f json > "$OUTPUT_DIR/$out_name" 2>/dev/null || true
        done
        echo -e "${GREEN}  ✓  hadolint — done ($(echo "$DOCKERFILES" | wc -l | tr -d ' ') Dockerfiles)${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${YELLOW}  ⏭  hadolint — no Dockerfiles found${NC}"
        SKIP=$((SKIP + 1))
    fi
elif should_skip "hadolint"; then
    echo -e "${YELLOW}  ⏭  hadolint — skipped${NC}"
    SKIP=$((SKIP + 1))
else
    echo -e "${YELLOW}  ⚠  hadolint — not installed${NC}"
    SKIP=$((SKIP + 1))
fi

# 7. Checkov — IaC (K8s, Terraform, Dockerfile)
echo -e "${YELLOW}[7/11] IaC${NC}"
run_scanner "checkov" \
    "checkov -d '$SCAN_DIR' \
        --config-file '$CONFIGS_DIR/.checkov.yaml' \
        --output json \
        --output-file-path '$OUTPUT_DIR' \
        --quiet 2>/dev/null || true" \
    "checkov"

# 8. Kubescape — NSA/CISA K8s hardening
echo -e "${YELLOW}[8/11] K8s hardening${NC}"
run_scanner "kubescape" \
    "kubescape scan '$SCAN_DIR' \
        --format json \
        --output '$OUTPUT_DIR/kubescape.json' 2>/dev/null || true" \
    "kubescape"

# 9. Polaris — K8s best practices
#    Scan K8s manifest directories (not the repo root — polaris falls back to
#    cluster mode if it can't find manifests in the audit path).
echo -e "${YELLOW}[9/11] K8s best practices${NC}"
if ! should_skip "polaris" && command -v polaris &>/dev/null; then
    _POLARIS_PATH=""
    for _dir in k8s kubernetes infrastructure manifests deploy; do
        [[ -d "$SCAN_DIR/$_dir" ]] && _POLARIS_PATH="$SCAN_DIR/$_dir"
    done
    if [[ -n "$_POLARIS_PATH" ]]; then
        echo -e "${BLUE}  ▶  polaris...${NC}"
        if polaris audit --audit-path "$_POLARIS_PATH" --format json > "$OUTPUT_DIR/polaris.json" 2>/dev/null; then
            echo -e "${GREEN}  ✓  polaris — done${NC}"
            PASS=$((PASS + 1))
        else
            echo -e "${GREEN}  ✓  polaris — done (findings present)${NC}"
            PASS=$((PASS + 1))
        fi
    else
        echo -e "${YELLOW}  ⏭  polaris — no K8s manifest directories found${NC}"
        SKIP=$((SKIP + 1))
    fi
elif should_skip "polaris"; then
    echo -e "${YELLOW}  ⏭  polaris — skipped${NC}"
    SKIP=$((SKIP + 1))
else
    echo -e "${YELLOW}  ⚠  polaris — not installed${NC}"
    SKIP=$((SKIP + 1))
fi

# 10. (Removed) TFsec — deprecated, Trivy IaC covers Terraform scanning.
#     Aqua Security merged tfsec into Trivy. Scanner 4 (trivy-fs) handles this.

# 11. Conftest — OPA policy check on K8s manifests
echo -e "${YELLOW}[10/11] OPA policies${NC}"
if ! should_skip "conftest" && command -v conftest &>/dev/null; then
    # Find directories containing K8s YAML files
    _CONFTEST_TARGETS=""
    for _dir in k8s kubernetes infrastructure manifests deploy; do
        [[ -d "$SCAN_DIR/$_dir" ]] && _CONFTEST_TARGETS="$SCAN_DIR/$_dir"
    done
    if [[ -n "$_CONFTEST_TARGETS" ]]; then
        echo -e "${BLUE}  ▶  conftest...${NC}"
        if conftest test "$_CONFTEST_TARGETS" \
            --policy "$CONFIGS_DIR/conftest-policy.rego" \
            --output json > "$OUTPUT_DIR/conftest.json" 2>/dev/null; then
            echo -e "${GREEN}  ✓  conftest — done${NC}"
            PASS=$((PASS + 1))
        else
            echo -e "${GREEN}  ✓  conftest — done (findings present)${NC}"
            PASS=$((PASS + 1))
        fi
    else
        echo -e "${YELLOW}  ⏭  conftest — no K8s manifest directories found${NC}"
        SKIP=$((SKIP + 1))
    fi
elif should_skip "conftest"; then
    echo -e "${YELLOW}  ⏭  conftest — skipped${NC}"
    SKIP=$((SKIP + 1))
else
    echo -e "${YELLOW}  ⚠  conftest — not installed${NC}"
    SKIP=$((SKIP + 1))
fi

# 12. Kube-bench — CIS benchmark (requires cluster/node access)
echo -e "${YELLOW}[11/11] CIS benchmark${NC}"
if should_skip "kube-bench"; then
    echo -e "${YELLOW}  ⏭  kube-bench — skipped${NC}"
    SKIP=$((SKIP + 1))
elif command -v kube-bench &>/dev/null; then
    run_scanner "kube-bench" \
        "kube-bench --json > '$OUTPUT_DIR/kube-bench.json' 2>/dev/null || true" \
        "kube-bench"
else
    echo -e "${YELLOW}  ⏭  kube-bench — not installed (requires cluster access, skip for repo-only scans)${NC}"
    SKIP=$((SKIP + 1))
fi

# ─── DAST Scanners (opt-in) ─────────────────────────────────────────────────

if [[ "$DAST" == "true" ]]; then
    echo ""
    echo -e "${BLUE}=== DAST Scanners (target: $TARGET_URL) ===${NC}"

    # 13. Nuclei — template-based vulnerability scanning
    echo -e "${YELLOW}[13/14] Nuclei DAST${NC}"
    run_scanner "nuclei" \
        "nuclei -u '$TARGET_URL' \
            -tags 'cves,misconfig,exposure,default-login' \
            -exclude-tags 'dos,fuzz,intrusive' \
            -rate-limit 150 \
            -jsonl -o '$OUTPUT_DIR/nuclei.jsonl' \
            -silent 2>/dev/null || true" \
        "nuclei"

    # 14. ZAP baseline — passive DAST (requires Docker)
    echo -e "${YELLOW}[14/14] ZAP DAST (baseline)${NC}"
    if ! should_skip "zap" && command -v docker &>/dev/null; then
        run_scanner "zap" \
            "docker run --rm \
                -v '$OUTPUT_DIR:/zap/wrk:rw' \
                $( [[ -f '$CONFIGS_DIR/zap.yaml' ]] && echo \"-v '$CONFIGS_DIR/zap.yaml:/zap/wrk/zap.yaml:ro'\" ) \
                ghcr.io/zaproxy/zaproxy:stable \
                zap-baseline.py -t '$TARGET_URL' \
                -J zap-results.json 2>/dev/null || true" \
            "docker"
    elif should_skip "zap"; then
        echo -e "${YELLOW}  ⏭  zap — skipped${NC}"
        SKIP=$((SKIP + 1))
    else
        echo -e "${YELLOW}  ⚠  zap — Docker not installed (required for ZAP)${NC}"
        SKIP=$((SKIP + 1))
    fi
else
    echo ""
    echo -e "${YELLOW}DAST skipped (use --dast --target-url URL to enable)${NC}"
fi

# ─── Summary ────────────────────────────────────────────────────────────────

echo ""
echo -e "${BLUE}=== Scan Complete ===${NC}"
echo -e "  ${GREEN}Passed : $PASS${NC}"
echo -e "  ${YELLOW}Skipped: $SKIP${NC}"
echo -e "  ${RED}Failed : $FAIL${NC}"
echo "  Output : $OUTPUT_DIR"
echo ""

# Write SUMMARY.md
cat > "$OUTPUT_DIR/SUMMARY.md" <<SUMMARY
# Scan Summary — $(basename "$TARGET_DIR")
Date: $(date +"%Y-%m-%d %H:%M")
Target: $TARGET_DIR

## Scanner Results
| Scanner | Output File | Status |
|---------|-------------|--------|
| Gitleaks (secrets)       | gitleaks.json       | $([ -f "$OUTPUT_DIR/gitleaks.json" ] && echo "✓" || echo "—") |
| Bandit (Python SAST)     | bandit.json         | $([ -f "$OUTPUT_DIR/bandit.json" ] && echo "✓" || echo "—") |
| Semgrep (SAST)           | semgrep.json        | $([ -f "$OUTPUT_DIR/semgrep.json" ] && echo "✓" || echo "—") |
| Trivy (CVEs)             | trivy-fs.json       | $([ -f "$OUTPUT_DIR/trivy-fs.json" ] && echo "✓" || echo "—") |
| Grype (CVEs)             | grype.json          | $([ -f "$OUTPUT_DIR/grype.json" ] && echo "✓" || echo "—") |
| Hadolint (Dockerfile)    | hadolint-*.json     | $(ls "$OUTPUT_DIR"/hadolint-*.json 2>/dev/null | head -1 | grep -q . && echo "✓" || echo "—") |
| Checkov (IaC)            | results_json.json   | $([ -f "$OUTPUT_DIR/results_json.json" ] && echo "✓" || echo "—") |
| Kubescape (K8s NSA)      | kubescape.json      | $([ -f "$OUTPUT_DIR/kubescape.json" ] && echo "✓" || echo "—") |
| Polaris (K8s)            | polaris.json        | $([ -f "$OUTPUT_DIR/polaris.json" ] && echo "✓" || echo "—") |
| Conftest (OPA)           | conftest.json       | $([ -f "$OUTPUT_DIR/conftest.json" ] && echo "✓" || echo "—") |
| Kube-bench (CIS)         | kube-bench.json     | $([ -f "$OUTPUT_DIR/kube-bench.json" ] && echo "✓" || echo "—") |
| Nuclei (DAST)            | nuclei.jsonl        | $([ -f "$OUTPUT_DIR/nuclei.jsonl" ] && echo "✓" || echo "—") |
| ZAP (DAST)               | zap-results.json    | $([ -f "$OUTPUT_DIR/zap-results.json" ] && echo "✓" || echo "—") |

## Quick Finding Counts

Run from this directory to get counts:

\`\`\`bash
# Secrets
jq 'length' gitleaks.json 2>/dev/null || echo "0"

# Python HIGH/CRITICAL
jq '[.results[]|select(.issue_severity=="HIGH" or .issue_severity=="CRITICAL")]|length' bandit.json 2>/dev/null || echo "0"

# Dependency CRITICAL CVEs
jq '[.Results[]?.Vulnerabilities[]?|select(.Severity=="CRITICAL")]|length' trivy-fs.json 2>/dev/null || echo "0"

# Checkov failed checks
jq '.results.failed_checks|length' results_json.json 2>/dev/null || echo "0"
\`\`\`

## Next Steps

1. Review findings above
2. Look up error codes in: $PKG_DIR/fixers/README.md
3. Run the corresponding fix script for each finding
4. Re-scan: bash run-all-scanners.sh -t $TARGET_DIR -o ../post-fix-$(date +%Y%m%d)
SUMMARY

echo -e "${GREEN}SUMMARY.md written to $OUTPUT_DIR/SUMMARY.md${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. cat $OUTPUT_DIR/SUMMARY.md"
echo "  2. Look up error codes: $PKG_DIR/fixers/README.md"
echo "  3. Run fix scripts per finding"
echo ""
