#!/usr/bin/env bash
# watch-pss.sh — Pod Security Standards label auditor
# Part of GP-CONSULTING/03-DEPLOY-RUNTIME/watchers/
#
# Matches: GP-BEDROCK-AGENTS/jsa-infrasec/src/layer3_runtime/watchers/runtime_pss.py
#
# Checks:
#   1. Namespaces with NO PSS labels (enforce/audit/warn)        → CRITICAL
#   2. Namespaces using privileged enforcement level              → HIGH
#   3. Namespaces with audit/warn but NO enforce                  → MEDIUM
#   4. Namespaces on baseline that could use restricted           → LOW
#
# Dependencies: kubectl, python3
#
# References:
#   CKS: Minimize Microservice Vulnerabilities - Pod Security Standards
#   CIS 5.2.1: Minimize privileged containers

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
JSON_OUTPUT=false
SCRIPT_NAME="$(basename "$0")"
DATE_STAMP="$(date +%Y-%m-%d_%H%M%S)"

SYSTEM_NS="kube-system kube-public kube-node-lease"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Audit Pod Security Standards labels on namespaces.

Options:
  --namespace NS    Check a single namespace (default: all namespaces)
  --include-system  Include system namespaces (kube-system, kube-public, kube-node-lease)
  --report FILE     Write markdown report to FILE
  --json            Output structured JSON findings (for piping to responders)
  -h, --help        Show this help

Examples:
  bash $SCRIPT_NAME                        # audit all namespaces
  bash $SCRIPT_NAME --namespace production # single namespace
  bash $SCRIPT_NAME --report pss-audit.md  # generate report
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --namespace)    NAMESPACE="$2"; shift 2 ;;
        --include-system) SKIP_SYSTEM=false; shift ;;
        --report)       REPORT="$2"; shift 2 ;;
        --json)         JSON_OUTPUT=true; shift ;;
        -h|--help)      usage; exit 0 ;;
        *)              echo -e "${RED}Unknown option: $1${RESET}"; usage; exit 1 ;;
    esac
done

if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}ERROR: Cannot reach cluster.${RESET}"
    exit 1
fi

CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0
PASS_COUNT=0
TOTAL_NS=0

# JSON findings collector (pipe-delimited: code|severity|namespace|message|responder|args)
JSON_LINES=""
jf() { JSON_LINES+="$1|$2|$3|$4|$5|$6"$'\n'; }

REPORT_LINES=""
report() {
    REPORT_LINES+="$1"$'\n'
}

is_system_ns() {
    local ns="$1"
    for sys in $SYSTEM_NS; do
        if [[ "$ns" == "$sys" ]]; then return 0; fi
    done
    return 1
}

echo ""
echo -e "${BOLD}=== Pod Security Standards Audit ===${RESET}"
echo -e "  Cluster: $(kubectl config current-context)"
echo -e "  Time:    $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""

report "# PSS Label Audit — $(date -u '+%Y-%m-%d %H:%M UTC')"
report ""
report "Cluster: $(kubectl config current-context)"
report ""
report "| Namespace | Enforce | Audit | Warn | Severity | Issue |"
report "|-----------|---------|-------|------|----------|-------|"

# Get namespaces
if [[ -n "$NAMESPACE" ]]; then
    NS_JSON=$(kubectl get namespace "$NAMESPACE" -o json 2>/dev/null)
    if [[ -z "$NS_JSON" ]]; then
        echo -e "${RED}ERROR: Namespace '$NAMESPACE' not found.${RESET}"
        exit 1
    fi
    NAMESPACES=$(echo "$NS_JSON" | python3 -c "
import sys, json
ns = json.load(sys.stdin)
print(ns['metadata']['name'])
")
else
    NAMESPACES=$(kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
fi

# Check each namespace
while IFS= read -r ns; do
    [[ -z "$ns" ]] && continue

    if [[ "$SKIP_SYSTEM" == "true" ]] && is_system_ns "$ns"; then
        continue
    fi

    TOTAL_NS=$((TOTAL_NS + 1))

    # Get PSS labels
    LABELS_JSON=$(kubectl get namespace "$ns" -o json 2>/dev/null | python3 -c "
import sys, json
ns = json.load(sys.stdin)
labels = ns.get('metadata', {}).get('labels', {})
prefix = 'pod-security.kubernetes.io'
enforce = labels.get(f'{prefix}/enforce', '')
audit = labels.get(f'{prefix}/audit', '')
warn = labels.get(f'{prefix}/warn', '')
print(f'{enforce}|{audit}|{warn}')
" 2>/dev/null || echo "||")

    ENFORCE=$(echo "$LABELS_JSON" | cut -d'|' -f1)
    AUDIT=$(echo "$LABELS_JSON" | cut -d'|' -f2)
    WARN=$(echo "$LABELS_JSON" | cut -d'|' -f3)

    # Display values for table
    ENFORCE_DISPLAY="${ENFORCE:-none}"
    AUDIT_DISPLAY="${AUDIT:-none}"
    WARN_DISPLAY="${WARN:-none}"

    # Check 1: No PSS labels at all
    if [[ -z "$ENFORCE" && -z "$AUDIT" && -z "$WARN" ]]; then
        echo -e "  ${RED}CRITICAL${RESET}  $ns — no PSS labels (enforce/audit/warn all missing)"
        report "| $ns | none | none | none | CRITICAL | No PSS labels |"
        jf "PSS_NO_LABELS" "CRITICAL" "$ns" "No PSS labels (enforce/audit/warn all missing)" "" "kubectl label namespace $ns pod-security.kubernetes.io/enforce=baseline pod-security.kubernetes.io/audit=restricted pod-security.kubernetes.io/warn=restricted"
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
        continue
    fi

    # Check 2: Enforce == privileged
    if [[ "$ENFORCE" == "privileged" ]]; then
        echo -e "  ${RED}HIGH${RESET}     $ns — enforce: privileged (allows everything)"
        report "| $ns | privileged | $AUDIT_DISPLAY | $WARN_DISPLAY | HIGH | Enforce is privileged |"
        jf "PSS_PRIVILEGED" "HIGH" "$ns" "Enforce level is privileged (allows everything)" "" "kubectl label namespace $ns pod-security.kubernetes.io/enforce=baseline --overwrite"
        HIGH_COUNT=$((HIGH_COUNT + 1))
        continue
    fi

    # Check 3: No enforce but has audit/warn
    if [[ -z "$ENFORCE" && ( -n "$AUDIT" || -n "$WARN" ) ]]; then
        echo -e "  ${YELLOW}MEDIUM${RESET}   $ns — audit/warn set but no enforce (violations logged, not blocked)"
        report "| $ns | none | $AUDIT_DISPLAY | $WARN_DISPLAY | MEDIUM | No enforce mode |"
        jf "PSS_NO_ENFORCE" "MEDIUM" "$ns" "Audit/warn set but no enforce (violations logged, not blocked)" "" "kubectl label namespace $ns pod-security.kubernetes.io/enforce=baseline"
        MEDIUM_COUNT=$((MEDIUM_COUNT + 1))
        continue
    fi

    # Check 4: Enforce == baseline — could it be restricted?
    if [[ "$ENFORCE" == "baseline" ]]; then
        # Check if pods would pass restricted
        VIOLATIONS=$(kubectl get pods -n "$ns" -o json 2>/dev/null | python3 -c "
import sys, json
pods = json.load(sys.stdin)
violations = 0
for pod in pods.get('items', []):
    spec = pod.get('spec', {})
    sc = spec.get('securityContext', {})

    # Pod-level checks
    if not sc.get('runAsNonRoot', False):
        violations += 1
        continue

    seccomp = sc.get('seccompProfile', {})
    if not seccomp.get('type'):
        violations += 1
        continue

    # Container-level checks
    for container in spec.get('containers', []) + spec.get('initContainers', []):
        csc = container.get('securityContext', {})
        if csc.get('allowPrivilegeEscalation', True) is not False:
            violations += 1
            break
        caps = csc.get('capabilities', {})
        drop = [c.upper() for c in caps.get('drop', [])]
        if 'ALL' not in drop:
            violations += 1
            break

print(violations)
" 2>/dev/null || echo "999")

        if [[ "$VIOLATIONS" == "0" ]]; then
            echo -e "  ${CYAN}LOW${RESET}      $ns — baseline enforced, but all pods pass restricted (upgrade possible)"
            report "| $ns | baseline | $AUDIT_DISPLAY | $WARN_DISPLAY | LOW | Could upgrade to restricted |"
            jf "PSS_UPGRADE_AVAILABLE" "LOW" "$ns" "Baseline enforced but all pods pass restricted — upgrade possible" "" "kubectl label namespace $ns pod-security.kubernetes.io/enforce=restricted --overwrite"
            LOW_COUNT=$((LOW_COUNT + 1))
        else
            echo -e "  ${GREEN}PASS${RESET}     $ns — baseline enforced ($VIOLATIONS pod(s) would fail restricted)"
            report "| $ns | baseline | $AUDIT_DISPLAY | $WARN_DISPLAY | PASS | Baseline appropriate |"
            PASS_COUNT=$((PASS_COUNT + 1))
        fi
        continue
    fi

    # Enforce == restricted — best possible
    if [[ "$ENFORCE" == "restricted" ]]; then
        echo -e "  ${GREEN}PASS${RESET}     $ns — restricted enforced"
        report "| $ns | restricted | $AUDIT_DISPLAY | $WARN_DISPLAY | PASS | Fully hardened |"
        PASS_COUNT=$((PASS_COUNT + 1))
        continue
    fi

    # Unknown enforce level
    echo -e "  ${YELLOW}MEDIUM${RESET}   $ns — unknown enforce level: $ENFORCE"
    report "| $ns | $ENFORCE | $AUDIT_DISPLAY | $WARN_DISPLAY | MEDIUM | Unknown level |"
    MEDIUM_COUNT=$((MEDIUM_COUNT + 1))

done <<< "$NAMESPACES"

echo ""
echo -e "${BOLD}=== Summary ===${RESET}"
echo "  Namespaces checked: $TOTAL_NS"
echo -e "  ${RED}CRITICAL${RESET}: $CRITICAL_COUNT (no PSS labels)"
echo -e "  ${RED}HIGH${RESET}    : $HIGH_COUNT (privileged enforce)"
echo -e "  ${YELLOW}MEDIUM${RESET}  : $MEDIUM_COUNT (no enforce / unknown)"
echo -e "  ${CYAN}LOW${RESET}     : $LOW_COUNT (could upgrade to restricted)"
echo -e "  ${GREEN}PASS${RESET}    : $PASS_COUNT"
echo ""

if [[ $CRITICAL_COUNT -gt 0 ]]; then
    echo "Fix CRITICAL namespaces:"
    echo "  kubectl label namespace <NS> pod-security.kubernetes.io/enforce=baseline"
    echo "  kubectl label namespace <NS> pod-security.kubernetes.io/audit=restricted"
    echo "  kubectl label namespace <NS> pod-security.kubernetes.io/warn=restricted"
    echo ""
fi

report ""
report "## Summary"
report ""
report "- Namespaces: $TOTAL_NS"
report "- CRITICAL: $CRITICAL_COUNT"
report "- HIGH: $HIGH_COUNT"
report "- MEDIUM: $MEDIUM_COUNT"
report "- LOW: $LOW_COUNT"
report "- PASS: $PASS_COUNT"

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
    parts = line.split('|', 5)
    if len(parts) < 4:
        continue
    f = {'code': parts[0], 'severity': parts[1], 'namespace': parts[2], 'message': parts[3]}
    if len(parts) > 4 and parts[4]:
        f['responder'] = parts[4]
    if len(parts) > 5 and parts[5]:
        f['args'] = parts[5]
    findings.append(f)
json.dump({'watcher': 'watch-pss', 'findings': findings, 'summary': {'total': len(findings), 'critical': sum(1 for f in findings if f['severity'] == 'CRITICAL'), 'high': sum(1 for f in findings if f['severity'] == 'HIGH'), 'medium': sum(1 for f in findings if f['severity'] == 'MEDIUM'), 'low': sum(1 for f in findings if f['severity'] == 'LOW')}}, sys.stdout, indent=2)
print()
"
fi
