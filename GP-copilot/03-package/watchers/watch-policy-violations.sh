#!/usr/bin/env bash
# watch-policy-violations.sh — Admission control violation checker
# Part of GP-CONSULTING/03-DEPLOY-RUNTIME/watchers/
#
# Works with both Kyverno (PolicyReport/ClusterPolicyReport CRDs) and
# Gatekeeper (constraint resources with violations).
#
# Dependencies: kubectl, python3

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

ENGINE=""
OUTPUT=""
JSON_OUTPUT=false
SCRIPT_NAME="$(basename "$0")"
DATE_STAMP="$(date +%Y-%m-%d_%H%M%S)"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Check current admission control violations from Kyverno or Gatekeeper.

Options:
  --engine ENGINE   Force engine: kyverno or gatekeeper (default: auto-detect)
  --output FILE     Write markdown report to FILE
  --json            Output structured JSON findings (for piping to responders)
  -h, --help        Show this help

Examples:
  bash $SCRIPT_NAME                          # auto-detect engine
  bash $SCRIPT_NAME --engine kyverno
  bash $SCRIPT_NAME --engine gatekeeper
  bash $SCRIPT_NAME --output report.md
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --engine)  ENGINE="$2"; shift 2 ;;
        --output)  OUTPUT="$2"; shift 2 ;;
        --json)    JSON_OUTPUT=true; shift ;;
        -h|--help) usage ;;
        *)         echo "Unknown option: $1"; usage ;;
    esac
done

if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}ERROR: kubectl not found in PATH${RESET}" >&2; exit 1
fi
if ! kubectl cluster-info &>/dev/null 2>&1; then
    echo -e "${RED}ERROR: Cannot connect to Kubernetes cluster${RESET}" >&2; exit 1
fi

# --- Detect engine ---
HAS_KYVERNO=false
HAS_GATEKEEPER=false

if [[ -z "$ENGINE" || "$ENGINE" == "kyverno" ]]; then
    if kubectl api-resources --api-group=wgpolicyk8s.io 2>/dev/null | grep -q policyreport; then
        HAS_KYVERNO=true
    fi
fi
if [[ -z "$ENGINE" || "$ENGINE" == "gatekeeper" ]]; then
    if kubectl get crd 2>/dev/null | grep -q constrainttemplates.templates.gatekeeper.sh; then
        HAS_GATEKEEPER=true
    fi
fi

if [[ "$HAS_KYVERNO" == "false" && "$HAS_GATEKEEPER" == "false" ]]; then
    echo -e "${YELLOW}${BOLD}[watch-policy-violations] No admission control engine detected.${RESET}"
    echo ""
    if [[ -n "$ENGINE" ]]; then
        echo -e "${RED}Engine '$ENGINE' is not installed or CRDs are not available.${RESET}"
    else
        echo -e "${YELLOW}Neither Kyverno PolicyReport CRDs nor Gatekeeper ConstraintTemplate CRDs found.${RESET}"
    fi
    echo ""
    echo -e "${CYAN}To deploy admission control policies, run:${RESET}"
    echo -e "  bash 02-CLUSTER-HARDENING/tools/deploy-policies.sh"
    exit 1
fi

echo -e "${CYAN}${BOLD}[watch-policy-violations] Checking admission control violations...${RESET}"
[[ "$HAS_KYVERNO" == "true" ]] && echo -e "${CYAN}  Kyverno: detected${RESET}"
[[ "$HAS_GATEKEEPER" == "true" ]] && echo -e "${CYAN}  Gatekeeper: detected${RESET}"
echo ""

MD_TMP="$(mktemp)"
JSON_TMP="$(mktemp)"
echo "[]" > "$JSON_TMP"
trap 'rm -f "$MD_TMP" "$JSON_TMP"' EXIT

# --- Kyverno ---
KYVERNO_DATA=""
if [[ "$HAS_KYVERNO" == "true" ]]; then
    echo -e "${CYAN}${BOLD}Querying Kyverno PolicyReports...${RESET}"
    PR_JSON="$(mktemp)"
    CPR_JSON="$(mktemp)"
    trap 'rm -f "$MD_TMP" "$PR_JSON" "$CPR_JSON"' EXIT

    kubectl get policyreports --all-namespaces -o json > "$PR_JSON" 2>/dev/null || echo '{"items":[]}' > "$PR_JSON"
    kubectl get clusterpolicyreports -o json > "$CPR_JSON" 2>/dev/null || echo '{"items":[]}' > "$CPR_JSON"

    python3 -c '
import json, sys
from datetime import datetime

RED = "\033[0;31m"
YELLOW = "\033[1;33m"
GREEN = "\033[0;32m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
RESET = "\033[0m"

def load(path):
    try:
        with open(path) as f:
            return json.load(f).get("items", [])
    except Exception:
        return []

prs = load(sys.argv[1])
cprs = load(sys.argv[2])
md_path = sys.argv[3]
has_gk = sys.argv[4] == "true"

all_reports = prs + cprs
findings = []
pass_count = 0
fail_count = 0
warn_count = 0
error_count = 0
skip_count = 0

for report in all_reports:
    ns = report["metadata"].get("namespace", "cluster-wide")
    results = report.get("results", [])
    summary = report.get("summary", {})
    pass_count += summary.get("pass", 0)
    fail_count += summary.get("fail", 0)
    warn_count += summary.get("warn", 0)
    error_count += summary.get("error", 0)
    skip_count += summary.get("skip", 0)

    for result in results:
        status = result.get("result", "")
        if status not in ("fail", "error", "warn"):
            continue
        policy = result.get("policy", "unknown")
        rule = result.get("rule", "unknown")
        message = result.get("message", "")[:150]
        resources = result.get("resources", [])
        for res in resources:
            res_name = res.get("name", "?")
            res_kind = res.get("kind", "?")
            res_ns = res.get("namespace", ns)
            sev = "CRITICAL" if status == "error" else "WARNING" if status == "fail" else "INFO"
            findings.append({
                "severity": sev,
                "status": status,
                "policy": policy,
                "rule": rule,
                "resource": f"{res_kind}/{res_name}",
                "namespace": res_ns,
                "message": message,
            })

# Terminal output
total_violations = fail_count + error_count
print(f"{CYAN}{BOLD}Kyverno Summary:{RESET}")
print(f"  Pass: {pass_count}  Fail: {fail_count}  Warn: {warn_count}  Error: {error_count}  Skip: {skip_count}")
print()

if not findings:
    print(f"  {GREEN}PASS: No Kyverno policy violations found.{RESET}")
else:
    # Group by policy
    by_policy = {}
    for f in findings:
        p = f["policy"]
        if p not in by_policy:
            by_policy[p] = []
        by_policy[p].append(f)

    for policy, violations in sorted(by_policy.items()):
        fail_v = [v for v in violations if v["status"] == "fail"]
        err_v = [v for v in violations if v["status"] == "error"]
        warn_v = [v for v in violations if v["status"] == "warn"]
        color = RED if err_v else YELLOW
        print(f"  {color}{BOLD}{policy}{RESET} ({len(violations)} violations)")
        for v in violations[:5]:
            sev_color = RED if v["severity"] == "CRITICAL" else YELLOW
            print(f"    {sev_color}[{v['status'].upper()}] {v['namespace']}/{v['resource']}{RESET}")
            if v["message"]:
                print(f"      {v['message']}")
        if len(violations) > 5:
            print(f"    ... and {len(violations) - 5} more")

print()

# Write partial markdown (will be combined with gatekeeper if present)
md = []
md.append("## Kyverno Policy Violations\n")
md.append(f"| Metric | Count |")
md.append(f"|--------|-------|")
md.append(f"| Pass | {pass_count} |")
md.append(f"| Fail | {fail_count} |")
md.append(f"| Warn | {warn_count} |")
md.append(f"| Error | {error_count} |")
md.append(f"| Skip | {skip_count} |")
md.append("")

if findings:
    md.append("### Violations\n")
    md.append("| Severity | Policy | Rule | Namespace | Resource | Message |")
    md.append("|----------|--------|------|-----------|----------|---------|")
    for f in findings:
        msg = f["message"].replace("|", "\\|")
        md.append(f"| {f['severity']} | {f['policy']} | {f['rule']} | {f['namespace']} | {f['resource']} | {msg} |")
    md.append("")
else:
    md.append("No violations found.\n")

with open(md_path, "w") as fp:
    fp.write("\n".join(md) + "\n")

# Write JSON findings
if sys.argv[5] == "true":
    import json as jmod
    json_findings = []
    for f in findings:
        json_findings.append({
            "code": "POLICY_KYVERNO_" + f["status"].upper(),
            "severity": f["severity"],
            "namespace": f["namespace"],
            "resource": f["resource"],
            "message": f"[{f['policy']}/{f['rule']}] {f['message']}"
        })
    with open(sys.argv[6], "w") as jf:
        jmod.dump(json_findings, jf)
' "$PR_JSON" "$CPR_JSON" "$MD_TMP" "$HAS_GATEKEEPER" "$JSON_OUTPUT" "$JSON_TMP"

    KYVERNO_DATA="$(cat "$MD_TMP")"
fi

# --- Gatekeeper ---
GATEKEEPER_DATA=""
if [[ "$HAS_GATEKEEPER" == "true" ]]; then
    echo -e "${CYAN}${BOLD}Querying Gatekeeper constraints...${RESET}"

    # Get all constraint kinds from constraint templates
    CONSTRAINT_KINDS=$(kubectl get constrainttemplates -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

    if [[ -z "$CONSTRAINT_KINDS" ]]; then
        echo -e "${YELLOW}  No ConstraintTemplates found.${RESET}"
        GATEKEEPER_DATA="## Gatekeeper Policy Violations\n\nNo ConstraintTemplates found.\n"
    else
        GK_TMP="$(mktemp)"
        trap 'rm -f "$MD_TMP" "$GK_TMP"' EXIT

        # Collect all constraints and their violations
        ALL_CONSTRAINTS='{"items":[]}'
        for kind in $CONSTRAINT_KINDS; do
            CONSTRAINTS=$(kubectl get "$kind" -o json 2>/dev/null || echo '{"items":[]}')
            echo "$CONSTRAINTS" >> "$GK_TMP"
        done

        python3 -c '
import json, sys
from datetime import datetime

RED = "\033[0;31m"
YELLOW = "\033[1;33m"
GREEN = "\033[0;32m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
RESET = "\033[0m"

gk_path = sys.argv[1]
md_path = sys.argv[2]

# Parse all constraint JSONs (one per line, multiple items arrays)
all_constraints = []
with open(gk_path) as f:
    content = f.read()

# Split by JSON objects
import re
jsons = re.findall(r"\{[^{}]*\"items\"\s*:\s*\[.*?\]\s*\}", content, re.DOTALL)
for j in jsons:
    try:
        data = json.loads(j)
        all_constraints.extend(data.get("items", []))
    except json.JSONDecodeError:
        pass

# Also try loading as newline-separated JSON
if not all_constraints:
    with open(gk_path) as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    data = json.loads(line)
                    all_constraints.extend(data.get("items", []))
                except json.JSONDecodeError:
                    pass

findings = []
total_enforced = 0
total_with_violations = 0

for constraint in all_constraints:
    name = constraint.get("metadata", {}).get("name", "?")
    kind = constraint.get("kind", "?")
    enforcement = constraint.get("spec", {}).get("enforcementAction", "deny")
    status = constraint.get("status", {})
    violations = status.get("violations", [])
    total_enforced += 1

    if violations:
        total_with_violations += 1
        for v in violations:
            findings.append({
                "constraint": name,
                "kind": kind,
                "enforcement": enforcement,
                "namespace": v.get("namespace", "cluster"),
                "resource": v.get("kind", "?") + "/" + v.get("name", "?"),
                "message": v.get("message", "")[:150],
            })

# Terminal output
print(f"{CYAN}{BOLD}Gatekeeper Summary:{RESET}")
print(f"  Constraints: {total_enforced}  With violations: {total_with_violations}  Total violations: {len(findings)}")
print()

if not findings:
    print(f"  {GREEN}PASS: No Gatekeeper constraint violations found.{RESET}")
else:
    by_constraint = {}
    for f in findings:
        k = f"{f['kind']}/{f['constraint']}"
        if k not in by_constraint:
            by_constraint[k] = []
        by_constraint[k].append(f)

    for ckey, violations in sorted(by_constraint.items()):
        color = RED if violations[0]["enforcement"] == "deny" else YELLOW
        print(f"  {color}{BOLD}{ckey} [{violations[0]['enforcement']}]{RESET} ({len(violations)} violations)")
        for v in violations[:5]:
            print(f"    {color}{v['namespace']}/{v['resource']}{RESET}")
            if v["message"]:
                print(f"      {v['message']}")
        if len(violations) > 5:
            print(f"    ... and {len(violations) - 5} more")
    print()

# Markdown
md = []
md.append("## Gatekeeper Policy Violations\n")
md.append(f"| Metric | Count |")
md.append(f"|--------|-------|")
md.append(f"| Constraints | {total_enforced} |")
md.append(f"| With violations | {total_with_violations} |")
md.append(f"| Total violations | {len(findings)} |")
md.append("")

if findings:
    md.append("### Violations\n")
    md.append("| Constraint | Kind | Enforcement | Namespace | Resource | Message |")
    md.append("|------------|------|-------------|-----------|----------|---------|")
    for f in findings:
        msg = f["message"].replace("|", "\\|")
        md.append(f"| {f['constraint']} | {f['kind']} | {f['enforcement']} | {f['namespace']} | {f['resource']} | {msg} |")
    md.append("")
else:
    md.append("No violations found.\n")

with open(md_path, "w") as fp:
    fp.write("\n".join(md) + "\n")

# Append JSON findings
if sys.argv[3] == "true":
    import json as jmod
    # Load existing findings (from Kyverno)
    existing = []
    try:
        with open(sys.argv[4]) as jf:
            existing = jmod.load(jf)
    except Exception:
        pass
    for f in findings:
        sev = "CRITICAL" if f["enforcement"] == "deny" else "WARNING"
        existing.append({
            "code": "POLICY_GATEKEEPER_VIOLATION",
            "severity": sev,
            "namespace": f["namespace"],
            "resource": f["resource"],
            "message": f"[{f['kind']}/{f['constraint']}] {f['message']}"
        })
    with open(sys.argv[4], "w") as jf:
        jmod.dump(existing, jf)
' "$GK_TMP" "$MD_TMP" "$JSON_OUTPUT" "$JSON_TMP"

        GATEKEEPER_DATA="$(cat "$MD_TMP")"
    fi
fi

# --- Combine markdown report ---
MD_FILE="${OUTPUT:-./watcher-policy-violations-${DATE_STAMP}.md}"

{
    echo "# Policy Violations Watcher Report"
    echo ""
    echo "**Date:** $(date '+%Y-%m-%d %H:%M:%S')  "
    engines=""
    [[ "$HAS_KYVERNO" == "true" ]] && engines="Kyverno"
    [[ "$HAS_GATEKEEPER" == "true" ]] && engines="${engines:+$engines, }Gatekeeper"
    echo "**Engines detected:** ${engines}  "
    echo ""
    [[ -n "$KYVERNO_DATA" ]] && echo "$KYVERNO_DATA"
    [[ -n "$GATEKEEPER_DATA" ]] && echo "$GATEKEEPER_DATA"
    echo "---"
    echo "*Generated by GP-CONSULTING/03-DEPLOY-RUNTIME/watchers/watch-policy-violations.sh*"
} > "$MD_FILE"

echo ""
echo -e "${CYAN}Markdown report written to: ${MD_FILE}${RESET}"

# JSON output mode
if [[ "$JSON_OUTPUT" == "true" ]]; then
    python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    findings = json.load(f)
total = len(findings)
crit = sum(1 for f in findings if f.get('severity') == 'CRITICAL')
warn = sum(1 for f in findings if f.get('severity') == 'WARNING')
json.dump({'watcher': 'watch-policy-violations', 'findings': findings, 'summary': {'total': total, 'critical': crit, 'warning': warn}}, sys.stdout, indent=2)
print()
" "$JSON_TMP"
fi
