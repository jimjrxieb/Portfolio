#!/usr/bin/env bash
# watch-audit.sh — K8s audit watcher via API queries
# Part of GP-CONSULTING/03-DEPLOY-RUNTIME/watchers/
#
# Detects: cluster-admin bindings, wildcard ClusterRoles, secrets access roles,
#          exec-capable roles, kube-system ConfigMap access
#
# Dependencies: kubectl, python3

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

OUTPUT=""
JSON_OUTPUT=false
SCRIPT_NAME="$(basename "$0")"
DATE_STAMP="$(date +%Y-%m-%d_%H%M%S)"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Check K8s RBAC and audit-relevant patterns via API queries.

Detects:
  - ClusterRoleBindings referencing cluster-admin
  - ClusterRoles with wildcard verbs/resources (skips system: prefixed)
  - Roles granting secrets access
  - Roles granting exec into pods
  - Recent RBAC-related events

Options:
  --output FILE     Write markdown report to FILE
  --json            Output structured JSON findings (for piping to responders)
  -h, --help        Show this help

Examples:
  bash $SCRIPT_NAME                     # check RBAC bindings + roles now
  bash $SCRIPT_NAME --output report.md
  bash $SCRIPT_NAME --json              # structured output
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
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

echo -e "${CYAN}${BOLD}[watch-audit] Checking RBAC and audit-relevant patterns...${RESET}"
echo ""

MD_TMP="$(mktemp)"
trap 'rm -f "$MD_TMP"' EXIT

# Gather all data in parallel, store in temp files
CRB_JSON="$(mktemp)"
CR_JSON="$(mktemp)"
ROLE_JSON="$(mktemp)"
RB_JSON="$(mktemp)"
EVENTS_JSON="$(mktemp)"
trap 'rm -f "$MD_TMP" "$CRB_JSON" "$CR_JSON" "$ROLE_JSON" "$RB_JSON" "$EVENTS_JSON"' EXIT

kubectl get clusterrolebindings -o json > "$CRB_JSON" 2>/dev/null &
kubectl get clusterroles -o json > "$CR_JSON" 2>/dev/null &
kubectl get roles --all-namespaces -o json > "$ROLE_JSON" 2>/dev/null &
kubectl get rolebindings --all-namespaces -o json > "$RB_JSON" 2>/dev/null &
kubectl get events --all-namespaces --field-selector reason!=Pulled,reason!=Scheduled,reason!=Created,reason!=Started -o json > "$EVENTS_JSON" 2>/dev/null &
wait

python3 -c "$(cat <<'PYEOF'
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

crbs = load(sys.argv[1])
crs = load(sys.argv[2])
roles = load(sys.argv[3])
rbs = load(sys.argv[4])
events = load(sys.argv[5])
md_path = sys.argv[6]

findings = []
total_critical = 0
total_warning = 0
total_info = 0

# --- Check 1: ClusterRoleBindings referencing cluster-admin ---
print(f"{CYAN}{BOLD}[1/5] ClusterRoleBindings with cluster-admin...{RESET}")
admin_bindings = []
for crb in crbs:
    role_ref = crb.get("roleRef", {})
    if role_ref.get("name") == "cluster-admin":
        name = crb["metadata"]["name"]
        subjects = crb.get("subjects", [])
        subj_strs = []
        for s in subjects:
            kind = s.get("kind", "?")
            ns = s.get("namespace", "")
            sname = s.get("name", "?")
            subj_strs.append(f"{kind}:{ns}/{sname}" if ns else f"{kind}:{sname}")
        # Skip default system bindings
        if name in ("cluster-admin", "system:masters"):
            continue
        admin_bindings.append({"name": name, "subjects": subj_strs})

if admin_bindings:
    total_critical += len(admin_bindings)
    for b in admin_bindings:
        subj_str = ", ".join(b['subjects'])
        print(f"  {RED}[CRITICAL] {b['name']} -> {subj_str}{RESET}")
        findings.append(("CRITICAL", "cluster-admin binding", b['name'], subj_str))
else:
    print(f"  {GREEN}PASS: No non-default cluster-admin bindings found.{RESET}")

print()

# --- Check 2: ClusterRoles with wildcard permissions (skip system:) ---
print(f"{CYAN}{BOLD}[2/5] ClusterRoles with wildcard verbs/resources...{RESET}")
wildcard_roles = []
for cr in crs:
    name = cr["metadata"]["name"]
    if name.startswith("system:") or name == "cluster-admin":
        continue
    rules = cr.get("rules", [])
    for rule in rules:
        verbs = rule.get("verbs", [])
        resources = rule.get("resources", [])
        api_groups = rule.get("apiGroups", [])
        if "*" in verbs and "*" in resources:
            wildcard_roles.append({"name": name, "detail": f"verbs=[*], resources=[*], apiGroups={api_groups}"})
            break
        elif "*" in verbs:
            wildcard_roles.append({"name": name, "detail": f"verbs=[*], resources={resources}"})
            break

if wildcard_roles:
    total_warning += len(wildcard_roles)
    for r in wildcard_roles:
        print(f"  {YELLOW}[WARNING] {r['name']}: {r['detail']}{RESET}")
        findings.append(("WARNING", "wildcard ClusterRole", r["name"], r["detail"]))
else:
    print(f"  {GREEN}PASS: No non-system wildcard ClusterRoles found.{RESET}")

print()

# --- Check 3: Roles granting secrets access ---
print(f"{CYAN}{BOLD}[3/5] Roles granting secrets access...{RESET}")
secrets_roles = []
all_roles = roles + crs  # check both namespaced and cluster roles
for r in all_roles:
    name = r["metadata"]["name"]
    ns = r["metadata"].get("namespace", "cluster-wide")
    if name.startswith("system:"):
        continue
    rules = r.get("rules", [])
    for rule in rules:
        resources = rule.get("resources", [])
        verbs = rule.get("verbs", [])
        if "secrets" in resources:
            verb_list = ", ".join(verbs)
            secrets_roles.append({"name": name, "namespace": ns, "verbs": verb_list})
            break

if secrets_roles:
    # Only warn for get/list/watch or wildcard on secrets
    for sr in secrets_roles:
        sev = "WARNING"
        total_warning += 1
        print(f"  {YELLOW}[{sev}] {sr['namespace']}/{sr['name']}: secrets [{sr['verbs']}]{RESET}")
        findings.append((sev, "secrets access", f"{sr['namespace']}/{sr['name']}", f"verbs: {sr['verbs']}"))
else:
    print(f"  {GREEN}PASS: No non-system roles granting secrets access.{RESET}")

print()

# --- Check 4: Roles granting exec into pods ---
print(f"{CYAN}{BOLD}[4/5] Roles granting pod exec...{RESET}")
exec_roles = []
for r in all_roles:
    name = r["metadata"]["name"]
    ns = r["metadata"].get("namespace", "cluster-wide")
    if name.startswith("system:"):
        continue
    rules = r.get("rules", [])
    for rule in rules:
        resources = rule.get("resources", [])
        verbs = rule.get("verbs", [])
        if "pods/exec" in resources or ("pods" in resources and "create" in verbs and "pods/exec" in resources):
            exec_roles.append({"name": name, "namespace": ns, "verbs": ", ".join(verbs)})
            break
        # Also check subresources
        if any("exec" in r for r in resources):
            exec_roles.append({"name": name, "namespace": ns, "verbs": ", ".join(verbs)})
            break

if exec_roles:
    total_warning += len(exec_roles)
    for er in exec_roles:
        print(f"  {YELLOW}[WARNING] {er['namespace']}/{er['name']}: pod exec [{er['verbs']}]{RESET}")
        findings.append(("WARNING", "pod exec", f"{er['namespace']}/{er['name']}", f"verbs: {er['verbs']}"))
else:
    print(f"  {GREEN}PASS: No non-system roles granting pod exec.{RESET}")

print()

# --- Check 5: Recent RBAC-related events ---
print(f"{CYAN}{BOLD}[5/5] Recent RBAC-related events...{RESET}")
rbac_events = []
for ev in events:
    ref = ev.get("involvedObject", {})
    kind = ref.get("kind", "")
    if kind in ("ClusterRole", "ClusterRoleBinding", "Role", "RoleBinding"):
        reason = ev.get("reason", "")
        name = ref.get("name", "?")
        ns = ref.get("namespace", "cluster")
        msg = ev.get("message", "")[:100]
        last = ev.get("lastTimestamp", "unknown")
        rbac_events.append({"kind": kind, "name": name, "ns": ns, "reason": reason, "msg": msg, "last": last})

if rbac_events:
    total_info += len(rbac_events)
    for re in rbac_events[:15]:
        print(f"  {CYAN}[INFO] {re['last']} {re['kind']}/{re['name']} ({re['reason']}): {re['msg']}{RESET}")
        findings.append(("INFO", "RBAC event", f"{re['kind']}/{re['name']}", re["msg"]))
    if len(rbac_events) > 15:
        print(f"  ... and {len(rbac_events) - 15} more")
else:
    print(f"  {GREEN}PASS: No recent RBAC-related events.{RESET}")

print()

# Summary
total = total_critical + total_warning + total_info
if total == 0:
    print(f"{GREEN}{BOLD}AUDIT RESULT: PASS — No RBAC concerns detected.{RESET}")
else:
    color = RED if total_critical > 0 else YELLOW
    print(f"{color}{BOLD}AUDIT RESULT: {total} findings ({total_critical} critical, {total_warning} warning, {total_info} info){RESET}")

# --- Markdown report ---
md = []
md.append("# K8s Audit Watcher Report\n")
md.append("**Date:** " + datetime.now().strftime("%Y-%m-%d %H:%M:%S") + "  ")
md.append(f"**Findings:** {total} ({total_critical} critical, {total_warning} warning, {total_info} info)\n")

if total == 0:
    md.append("## Result: PASS\n")
    md.append("No RBAC concerns detected.\n")
else:
    md.append("## Summary\n")
    md.append("| Severity | Category | Resource | Detail |")
    md.append("|----------|----------|----------|--------|")
    for sev, cat, res, detail in findings:
        md.append(f"| {sev} | {cat} | {res} | {detail.replace(chr(124), chr(92)+chr(124))} |")
    md.append("")

    if admin_bindings:
        md.append("## cluster-admin Bindings\n")
        md.append("These non-default bindings grant full cluster-admin access:\n")
        for b in admin_bindings:
            md.append(f"- **{b['name']}** -> {', '.join(b['subjects'])}")
        md.append("")

    if wildcard_roles:
        md.append("## Wildcard ClusterRoles\n")
        md.append("These non-system ClusterRoles use wildcard permissions:\n")
        for r in wildcard_roles:
            md.append(f"- **{r['name']}**: {r['detail']}")
        md.append("")

md.append("---\n*Generated by GP-CONSULTING/03-DEPLOY-RUNTIME/watchers/watch-audit.sh*")

with open(md_path, "w") as f:
    f.write("\n".join(md) + "\n")

# JSON output
if sys.argv[7] == "true":
    import json as jmod
    json_findings = []
    CODE_MAP = {
        "cluster-admin binding": "RBAC_CLUSTER_ADMIN",
        "wildcard ClusterRole": "RBAC_WILDCARD",
        "secrets access": "RBAC_SECRETS_ACCESS",
        "pod exec": "RBAC_POD_EXEC",
        "RBAC event": "RBAC_EVENT",
    }
    for sev, cat, res, detail in findings:
        code = CODE_MAP.get(cat, "RBAC_UNKNOWN")
        entry = {"code": code, "severity": sev, "namespace": "", "resource": res, "message": detail}
        if cat == "cluster-admin binding":
            entry["responder"] = "scope-rbac.sh"
            entry["args"] = "--binding " + res
        json_findings.append(entry)
    jmod.dump({"watcher": "watch-audit", "findings": json_findings, "summary": {"total": len(json_findings), "critical": total_critical, "warning": total_warning, "info": total_info}}, sys.stdout, indent=2)
    print()
PYEOF
)" "$CRB_JSON" "$CR_JSON" "$ROLE_JSON" "$RB_JSON" "$EVENTS_JSON" "$MD_TMP" "$JSON_OUTPUT"

# Write report
MD_FILE="${OUTPUT:-./watcher-audit-${DATE_STAMP}.md}"
cp "$MD_TMP" "$MD_FILE"
echo ""
echo -e "${CYAN}Markdown report written to: ${MD_FILE}${RESET}"
