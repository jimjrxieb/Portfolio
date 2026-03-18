#!/usr/bin/env bash
# scan-fix-rescan.sh
# Full playbook orchestrator: scan → triage → auto-fix E/D → re-scan → report delta.
#
# This is what jsa-devsec does autonomously. This script does it manually.
#
# Usage:
#   bash scan-fix-rescan.sh --target-dir /path/to/repo --output-dir /path/to/results
#   bash scan-fix-rescan.sh --target-dir /path/to/repo --output-dir /path/to/results --dry-run
#   bash scan-fix-rescan.sh --target-dir /path/to/repo --output-dir /path/to/results --skip-scanner kube-bench
#
# Flow:
#   1. Run all scanners (baseline)
#   2. Triage findings → generate REMEDIATION-PLAN.md + fix-auto.sh
#   3. Run fix-auto.sh (E/D rank only, unless --dry-run)
#   4. Re-scan (post-fix)
#   5. Report delta (before vs after)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

TARGET_DIR=""
OUTPUT_DIR=""
PROJECT="self-scan"
DRY_RUN=false
SCANNER_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-dir)    TARGET_DIR="$2"; shift 2 ;;
    --output-dir)    OUTPUT_DIR="$2"; shift 2 ;;
    --project)       PROJECT="$2"; shift 2 ;;
    --dry-run)       DRY_RUN=true; shift ;;
    --skip-scanner)  SCANNER_ARGS+=("--skip-scanner" "$2"); shift 2 ;;
    --include-dir)   SCANNER_ARGS+=("--include-dir" "$2"); shift 2 ;;
    -h|--help)
      echo "Usage: bash scan-fix-rescan.sh --target-dir PATH --output-dir PATH [--project NAME] [--dry-run] [--skip-scanner NAME]"
      echo ""
      echo "Flow: scan → triage → auto-fix E/D → re-scan → delta report"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$TARGET_DIR" || -z "$OUTPUT_DIR" ]]; then
  echo "ERROR: --target-dir and --output-dir required"
  echo "Usage: bash scan-fix-rescan.sh --target-dir PATH --output-dir PATH"
  exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
BASELINE_DIR="$OUTPUT_DIR/1-baseline"
POSTFIX_DIR="$OUTPUT_DIR/2-post-fix"

mkdir -p "$BASELINE_DIR" "$POSTFIX_DIR"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Ghost Protocol — Scan → Fix → Rescan Orchestrator  ║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC}  Target  : $TARGET_DIR"
echo -e "${BLUE}║${NC}  Output  : $OUTPUT_DIR"
echo -e "${BLUE}║${NC}  Project : $PROJECT"
echo -e "${BLUE}║${NC}  Dry-run : $DRY_RUN"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ── STEP 1: Baseline Scan ─────────────────────────────────────────────────

echo -e "${BLUE}═══ STEP 1/5: Baseline Scan ═══${NC}"
echo ""

bash "$SCRIPT_DIR/run-all-scanners.sh" \
  --target-dir "$TARGET_DIR" \
  --output-dir "$BASELINE_DIR" \
  --label baseline \
  "${SCANNER_ARGS[@]+"${SCANNER_ARGS[@]}"}"

# ── STEP 2: Triage ────────────────────────────────────────────────────────

echo ""
echo -e "${BLUE}═══ STEP 2/5: Triage Findings ═══${NC}"
echo ""

python3 "$SCRIPT_DIR/triage.py" \
  --scan-dir "$BASELINE_DIR" \
  --project "$PROJECT" \
  --target-dir "$TARGET_DIR" \
  --csv

# ── STEP 3: Auto-Fix E/D ──────────────────────────────────────────────────

echo ""
echo -e "${BLUE}═══ STEP 3/5: Auto-Fix (E/D rank) ═══${NC}"
echo ""

FIX_SCRIPT="$BASELINE_DIR/fix-auto.sh"

if [[ ! -f "$FIX_SCRIPT" ]]; then
  echo -e "${YELLOW}No fix-auto.sh generated — no auto-fixable findings.${NC}"
elif $DRY_RUN; then
  echo -e "${YELLOW}DRY RUN — showing commands without executing:${NC}"
  echo ""
  bash "$FIX_SCRIPT" --dry
else
  echo -e "${GREEN}Running auto-fixes...${NC}"
  echo ""
  bash "$FIX_SCRIPT" || true
fi

# ── STEP 4: Re-scan ───────────────────────────────────────────────────────

if ! $DRY_RUN; then
  echo ""
  echo -e "${BLUE}═══ STEP 4/5: Post-Fix Re-scan ═══${NC}"
  echo ""

  bash "$SCRIPT_DIR/run-all-scanners.sh" \
    --target-dir "$TARGET_DIR" \
    --output-dir "$POSTFIX_DIR" \
    --label post-fix \
    "${SCANNER_ARGS[@]+"${SCANNER_ARGS[@]}"}"

  # Triage post-fix too
  python3 "$SCRIPT_DIR/triage.py" \
    --scan-dir "$POSTFIX_DIR" \
    --project "$PROJECT" \
    --target-dir "$TARGET_DIR" \
    --csv
else
  echo ""
  echo -e "${YELLOW}═══ STEP 4/5: Re-scan skipped (dry-run) ═══${NC}"
fi

# ── STEP 5: Delta Report ──────────────────────────────────────────────────

echo ""
echo -e "${BLUE}═══ STEP 5/5: Delta Report ═══${NC}"
echo ""

python3 - "$BASELINE_DIR" "$POSTFIX_DIR" "$DRY_RUN" "$OUTPUT_DIR" <<'PYEOF'
import json, glob, sys
from pathlib import Path

baseline_dir = Path(sys.argv[1])
postfix_dir = Path(sys.argv[2])
dry_run = sys.argv[3] == "true"
output_dir = Path(sys.argv[4])

def count_findings(scan_dir):
    """Count findings from all scanner outputs in a directory."""
    counts = {}

    # Gitleaks
    gl = scan_dir / "gitleaks.json"
    if gl.exists() and gl.stat().st_size > 0:
        try:
            counts["gitleaks"] = len(json.load(open(gl)))
        except: counts["gitleaks"] = 0
    else:
        counts["gitleaks"] = 0

    # Bandit
    bn = scan_dir / "bandit.json"
    if bn.exists() and bn.stat().st_size > 0:
        try:
            counts["bandit"] = len(json.load(open(bn)).get("results", []))
        except: counts["bandit"] = 0
    else:
        counts["bandit"] = 0

    # Semgrep
    sg = scan_dir / "semgrep.json"
    if sg.exists() and sg.stat().st_size > 0:
        try:
            counts["semgrep"] = len(json.load(open(sg)).get("results", []))
        except: counts["semgrep"] = 0
    else:
        counts["semgrep"] = 0

    # Trivy
    tv = scan_dir / "trivy-fs.json"
    if tv.exists() and tv.stat().st_size > 0:
        try:
            d = json.load(open(tv))
            counts["trivy"] = sum(len(r.get("Vulnerabilities", [])) for r in d.get("Results", []))
        except: counts["trivy"] = 0
    else:
        counts["trivy"] = 0

    # Hadolint
    hl_total = 0
    for f in scan_dir.glob("hadolint-*.json"):
        try:
            data = json.load(open(f))
            if isinstance(data, list): hl_total += len(data)
        except: pass
    counts["hadolint"] = hl_total

    # Checkov
    ck = scan_dir / "results_json.json"
    if ck.exists() and ck.stat().st_size > 0:
        try:
            d = json.load(open(ck))
            if isinstance(d, list):
                counts["checkov"] = sum(len(c.get("results", {}).get("failed_checks", [])) for c in d)
            else:
                counts["checkov"] = len(d.get("results", {}).get("failed_checks", []))
        except: counts["checkov"] = 0
    else:
        counts["checkov"] = 0

    return counts

baseline = count_findings(baseline_dir)

if dry_run:
    postfix = {k: "—" for k in baseline}
    print("DRY RUN — no post-fix scan to compare.")
    print("")
else:
    postfix = count_findings(postfix_dir)

# Print delta table
print("╔════════════════════════════════════════════════════════════╗")
print("║              SCAN → FIX → RESCAN RESULTS                  ║")
print("╠════════════════════════════════════════════════════════════╣")
print("║  Scanner          │ Before  │ After   │ Delta             ║")
print("║───────────────────┼─────────┼─────────┼───────────────────║")

total_before = 0
total_after = 0

for scanner in ["gitleaks", "bandit", "semgrep", "trivy", "hadolint", "checkov"]:
    before = baseline.get(scanner, 0)
    total_before += before
    if dry_run:
        after_str = "—"
        delta_str = "—"
    else:
        after = postfix.get(scanner, 0)
        total_after += after
        delta = after - before
        if delta < 0:
            delta_str = f"\033[0;32m{delta}\033[0m"
        elif delta > 0:
            delta_str = f"\033[0;31m+{delta}\033[0m"
        else:
            delta_str = "0"
        after_str = str(after)

    print(f"║  {scanner:<17}│ {before:>7} │ {after_str:>7} │ {delta_str:<18}║")

print("║───────────────────┼─────────┼─────────┼───────────────────║")
if dry_run:
    print(f"║  TOTAL            │ {total_before:>7} │ —       │ —                 ║")
else:
    total_delta = total_after - total_before
    if total_delta < 0:
        total_delta_str = f"\033[0;32m{total_delta}\033[0m"
    else:
        total_delta_str = str(total_delta)
    print(f"║  TOTAL            │ {total_before:>7} │ {total_after:>7} │ {total_delta_str:<18}║")
print("╚════════════════════════════════════════════════════════════╝")

# Write delta report
report_path = output_dir / "DELTA-REPORT.md"
lines = [
    f"# Scan → Fix → Rescan Delta Report",
    f"",
    f"| Scanner | Before | After | Delta |",
    f"|---------|--------|-------|-------|",
]
for scanner in ["gitleaks", "bandit", "semgrep", "trivy", "hadolint", "checkov"]:
    before = baseline.get(scanner, 0)
    if dry_run:
        lines.append(f"| {scanner} | {before} | — | — |")
    else:
        after = postfix.get(scanner, 0)
        delta = after - before
        lines.append(f"| {scanner} | {before} | {after} | {delta:+d} |")

if not dry_run:
    lines.append(f"| **TOTAL** | **{total_before}** | **{total_after}** | **{total_delta:+d}** |")
else:
    lines.append(f"| **TOTAL** | **{total_before}** | — | — |")

report_path.write_text("\n".join(lines) + "\n")
print(f"\nDelta report: {report_path}")
print(f"Baseline:     {baseline_dir}/REMEDIATION-PLAN.md")
if not dry_run:
    print(f"Post-fix:     {postfix_dir}/REMEDIATION-PLAN.md")

PYEOF

echo ""
echo -e "${GREEN}Done.${NC}"
echo ""
