#!/usr/bin/env bash
# watch-seccomp.sh — Seccomp profile auditor
# Part of GP-CONSULTING/03-DEPLOY-RUNTIME/watchers/
#
# Matches: GP-BEDROCK-AGENTS/jsa-infrasec/src/layer3_runtime/watchers/runtime_seccomp.py
#
# Checks:
#   1. Containers with NO seccomp profile (native field or annotation) → HIGH
#   2. Containers with seccomp Unconfined                               → CRITICAL
#   3. RuntimeDefault or Localhost profiles                             → PASS
#
# Dependencies: kubectl, python3
#
# References:
#   CKS: System Hardening - Seccomp
#   CIS 5.7.2: Ensure Seccomp profile is set

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

SYSTEM_NS="kube-system kube-public kube-node-lease"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Audit seccomp profiles on all running containers.

Options:
  --namespace NS    Scan a single namespace (default: all namespaces)
  --include-system  Include system namespaces
  --report FILE     Write markdown report to FILE
  --json            Output structured JSON findings (for piping to responders)
  -h, --help        Show this help

Examples:
  bash $SCRIPT_NAME                        # audit all namespaces
  bash $SCRIPT_NAME --namespace production # single namespace
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --namespace)      NAMESPACE="$2"; shift 2 ;;
        --include-system) SKIP_SYSTEM=false; shift ;;
        --report)         REPORT="$2"; shift 2 ;;
        --json)           JSON_OUTPUT=true; shift ;;
        -h|--help)        usage; exit 0 ;;
        *)                echo -e "${RED}Unknown option: $1${RESET}"; usage; exit 1 ;;
    esac
done

if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}ERROR: Cannot reach cluster.${RESET}"
    exit 1
fi

echo ""
echo -e "${BOLD}=== Seccomp Profile Audit ===${RESET}"
echo -e "  Cluster: $(kubectl config current-context)"
echo -e "  Time:    $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""

# Build kubectl command
if [[ -n "$NAMESPACE" ]]; then
    KUBECTL_CMD="kubectl get pods -n $NAMESPACE -o json"
else
    KUBECTL_CMD="kubectl get pods --all-namespaces -o json"
fi

# Run the full audit in Python — matches runtime_seccomp.py logic exactly
RESULTS=$($KUBECTL_CMD 2>/dev/null | python3 -c "
import sys, json

SYSTEM_NS = {'kube-system', 'kube-public', 'kube-node-lease'}
skip_system = $( [[ "$SKIP_SYSTEM" == "true" ]] && echo "True" || echo "False" )

pods = json.load(sys.stdin)

critical = []
high = []
passed = []
total_containers = 0

for pod in pods.get('items', []):
    ns = pod['metadata'].get('namespace', 'default')
    pod_name = pod['metadata']['name']
    annotations = pod['metadata'].get('annotations', {}) or {}

    if skip_system and ns in SYSTEM_NS:
        continue

    spec = pod.get('spec', {})
    pod_sc = spec.get('securityContext', {}) or {}

    # Pod-level seccomp (native field)
    pod_seccomp = pod_sc.get('seccompProfile', {}) or {}
    pod_seccomp_type = pod_seccomp.get('type', '')

    # Pod-level seccomp (deprecated annotation)
    pod_annotation = annotations.get('seccomp.security.alpha.kubernetes.io/pod', '')
    if pod_annotation == 'runtime/default':
        pod_annotation_type = 'RuntimeDefault'
    elif pod_annotation == 'unconfined':
        pod_annotation_type = 'Unconfined'
    elif pod_annotation:
        pod_annotation_type = 'Localhost'
    else:
        pod_annotation_type = ''

    containers = spec.get('containers', []) + spec.get('initContainers', [])
    for container in containers:
        c_name = container.get('name', '?')
        total_containers += 1

        c_sc = container.get('securityContext', {}) or {}

        # Container-level seccomp (native field)
        c_seccomp = c_sc.get('seccompProfile', {}) or {}
        c_seccomp_type = c_seccomp.get('type', '')

        # Container-level seccomp (deprecated annotation)
        c_annotation_key = f'container.seccomp.security.alpha.kubernetes.io/{c_name}'
        c_annotation = annotations.get(c_annotation_key, '')
        if c_annotation == 'runtime/default':
            c_annotation_type = 'RuntimeDefault'
        elif c_annotation == 'unconfined':
            c_annotation_type = 'Unconfined'
        elif c_annotation:
            c_annotation_type = 'Localhost'
        else:
            c_annotation_type = ''

        # Determine effective profile (container > pod)
        if c_seccomp_type:
            effective = c_seccomp_type
        elif c_annotation_type:
            effective = c_annotation_type
        elif pod_seccomp_type:
            effective = pod_seccomp_type
        elif pod_annotation_type:
            effective = pod_annotation_type
        else:
            effective = 'None'

        if effective == 'None':
            high.append(f'{ns}/{pod_name}/{c_name}')
        elif effective == 'Unconfined':
            critical.append(f'{ns}/{pod_name}/{c_name}')
        else:
            passed.append(f'{ns}/{pod_name}/{c_name}|{effective}')

# Output
for item in critical:
    print(f'CRITICAL|{item}|Unconfined')
for item in high:
    print(f'HIGH|{item}|None')
for item in passed:
    parts = item.split('|')
    print(f'PASS|{parts[0]}|{parts[1]}')
print(f'SUMMARY|{total_containers}|{len(critical)}|{len(high)}|{len(passed)}')
")

CRITICAL_COUNT=0
HIGH_COUNT=0
PASS_COUNT=0
TOTAL=0

# JSON findings collector (pipe-delimited: code|severity|namespace|resource|message|responder|args)
JSON_LINES=""
jf() { JSON_LINES+="$1|$2|$3|$4|$5|$6|$7"$'\n'; }

REPORT_LINES=""
report() { REPORT_LINES+="$1"$'\n'; }

report "# Seccomp Profile Audit — $(date -u '+%Y-%m-%d %H:%M UTC')"
report ""
report "Cluster: $(kubectl config current-context)"
report ""
report "| Namespace/Pod/Container | Profile | Severity |"
report "|------------------------|---------|----------|"

while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    SEVERITY=$(echo "$line" | cut -d'|' -f1)
    RESOURCE=$(echo "$line" | cut -d'|' -f2)
    PROFILE=$(echo "$line" | cut -d'|' -f3)

    if [[ "$SEVERITY" == "SUMMARY" ]]; then
        TOTAL=$(echo "$line" | cut -d'|' -f2)
        CRITICAL_COUNT=$(echo "$line" | cut -d'|' -f3)
        HIGH_COUNT=$(echo "$line" | cut -d'|' -f4)
        PASS_COUNT=$(echo "$line" | cut -d'|' -f5)
        continue
    fi

    case "$SEVERITY" in
        CRITICAL)
            echo -e "  ${RED}CRITICAL${RESET}  $RESOURCE — seccomp: Unconfined"
            report "| $RESOURCE | Unconfined | CRITICAL |"
            jf "SECCOMP_UNCONFINED" "CRITICAL" "" "$RESOURCE" "Seccomp profile is Unconfined — no syscall filtering" "patch-security-context.sh" "--target $RESOURCE --set seccompProfile.type=RuntimeDefault"
            ;;
        HIGH)
            echo -e "  ${YELLOW}HIGH${RESET}      $RESOURCE — no seccomp profile"
            report "| $RESOURCE | none | HIGH |"
            jf "SECCOMP_MISSING" "HIGH" "" "$RESOURCE" "No seccomp profile set" "patch-security-context.sh" "--target $RESOURCE --set seccompProfile.type=RuntimeDefault"
            ;;
        PASS)
            # Only show passed in verbose or report
            report "| $RESOURCE | $PROFILE | PASS |"
            ;;
    esac
done <<< "$RESULTS"

echo ""
echo -e "${BOLD}=== Summary ===${RESET}"
echo "  Containers checked: $TOTAL"
echo -e "  ${RED}CRITICAL${RESET}: $CRITICAL_COUNT (Unconfined — no syscall filtering)"
echo -e "  ${YELLOW}HIGH${RESET}    : $HIGH_COUNT (no profile set)"
echo -e "  ${GREEN}PASS${RESET}    : $PASS_COUNT (RuntimeDefault or Localhost)"
echo ""

if [[ $HIGH_COUNT -gt 0 || $CRITICAL_COUNT -gt 0 ]]; then
    echo "Fix: Add seccomp profile to pod spec:"
    echo '  spec:'
    echo '    securityContext:'
    echo '      seccompProfile:'
    echo '        type: RuntimeDefault'
    echo ""
fi

report ""
report "## Summary"
report ""
report "- Containers: $TOTAL"
report "- CRITICAL: $CRITICAL_COUNT (Unconfined)"
report "- HIGH: $HIGH_COUNT (no profile)"
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
    parts = line.split('|', 6)
    if len(parts) < 5:
        continue
    f = {'code': parts[0], 'severity': parts[1], 'namespace': parts[2], 'resource': parts[3], 'message': parts[4]}
    if len(parts) > 5 and parts[5]:
        f['responder'] = parts[5]
    if len(parts) > 6 and parts[6]:
        f['args'] = parts[6]
    findings.append(f)
json.dump({'watcher': 'watch-seccomp', 'findings': findings, 'summary': {'total': len(findings), 'critical': sum(1 for f in findings if f['severity'] == 'CRITICAL'), 'high': sum(1 for f in findings if f['severity'] == 'HIGH')}}, sys.stdout, indent=2)
print()
"
fi
