#!/usr/bin/env bash
# watch-network-coverage.sh — NetworkPolicy coverage and exposure auditor
# Part of GP-CONSULTING/03-DEPLOY-RUNTIME/watchers/
#
# Matches: GP-BEDROCK-AGENTS/jsa-infrasec/src/layer4_network/watchers/network_security_watcher.py
#
# Checks:
#   1. Namespaces with pods but NO NetworkPolicies                 → HIGH
#   2. Production namespaces without default-deny policy           → CRITICAL
#   3. Services exposed via LoadBalancer/NodePort                  → MEDIUM
#   4. Overly permissive NetworkPolicies (allow from all NS)       → MEDIUM
#   5. Istio installed but no AuthorizationPolicies                → HIGH
#
# Dependencies: kubectl, python3
#
# References:
#   CKS: Minimize Microservice Vulnerabilities - Network Policies
#   CIS 5.3.2: Ensure default deny NetworkPolicy

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
CHECK_MESH=true
JSON_OUTPUT=false
SCRIPT_NAME="$(basename "$0")"

SYSTEM_NS="kube-system kube-public kube-node-lease"
PROD_PATTERNS="production prod default"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Audit NetworkPolicy coverage, default-deny, exposed services, and permissive rules.

Options:
  --namespace NS    Scan a single namespace (default: all namespaces)
  --include-system  Include system namespaces
  --skip-mesh       Skip Istio/service mesh checks
  --report FILE     Write markdown report to FILE
  --json            Output structured JSON findings (for piping to responders)
  -h, --help        Show this help

Examples:
  bash $SCRIPT_NAME                        # full cluster audit
  bash $SCRIPT_NAME --namespace production # single namespace
  bash $SCRIPT_NAME --skip-mesh            # skip Istio checks
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --namespace)      NAMESPACE="$2"; shift 2 ;;
        --include-system) SKIP_SYSTEM=false; shift ;;
        --skip-mesh)      CHECK_MESH=false; shift ;;
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
echo -e "${BOLD}=== Network Security Audit ===${RESET}"
echo -e "  Cluster: $(kubectl config current-context)"
echo -e "  Time:    $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""

CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
PASS_COUNT=0
TOTAL_NS=0

REPORT_LINES=""
report() { REPORT_LINES+="$1"$'\n'; }

# JSON findings collector (pipe-delimited: code|severity|namespace|resource|message|responder|args)
JSON_LINES=""
jf() { JSON_LINES+="$1|$2|$3|$4|$5|$6|$7"$'\n'; }

report "# Network Security Audit — $(date -u '+%Y-%m-%d %H:%M UTC')"
report ""
report "Cluster: $(kubectl config current-context)"
report ""

is_system_ns() {
    local ns="$1"
    for sys in $SYSTEM_NS; do
        [[ "$ns" == "$sys" ]] && return 0
    done
    return 1
}

is_prod_ns() {
    local ns="$1"
    for pat in $PROD_PATTERNS; do
        [[ "$ns" == "$pat" ]] && return 0
    done
    return 1
}

# Get namespaces
if [[ -n "$NAMESPACE" ]]; then
    NAMESPACES="$NAMESPACE"
else
    NAMESPACES=$(kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
fi

report "## Per-Namespace Findings"
report ""
report "| Namespace | Pods | NetPols | Default Deny | Severity | Issue |"
report "|-----------|------|---------|-------------|----------|-------|"

echo -e "${BOLD}--- NetworkPolicy Coverage ---${RESET}"
echo ""

while IFS= read -r ns; do
    [[ -z "$ns" ]] && continue
    [[ "$SKIP_SYSTEM" == "true" ]] && is_system_ns "$ns" && continue

    TOTAL_NS=$((TOTAL_NS + 1))

    # Count pods and policies
    POD_COUNT=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l || echo "0")
    NETPOL_COUNT=$(kubectl get networkpolicies -n "$ns" --no-headers 2>/dev/null | wc -l || echo "0")

    # Skip namespaces with no pods
    if [[ "$POD_COUNT" -eq 0 ]]; then
        continue
    fi

    # Check 1: No NetworkPolicies at all
    if [[ "$NETPOL_COUNT" -eq 0 ]]; then
        echo -e "  ${YELLOW}HIGH${RESET}      $ns — $POD_COUNT pods, 0 NetworkPolicies"
        report "| $ns | $POD_COUNT | 0 | no | HIGH | No NetworkPolicies |"
        jf "NETPOL_MISSING" "HIGH" "$ns" "" "$POD_COUNT pods, 0 NetworkPolicies" "generate-networkpolicy.sh" "--namespace $ns --mode deny-all"
        HIGH_COUNT=$((HIGH_COUNT + 1))

        # Check 2: Production namespace without default-deny (even worse)
        if is_prod_ns "$ns"; then
            echo -e "  ${RED}CRITICAL${RESET}  $ns — production namespace with no default-deny"
            report "| $ns | $POD_COUNT | 0 | no | CRITICAL | Production, no default-deny |"
            jf "NETPOL_PROD_NO_DENY" "CRITICAL" "$ns" "" "Production namespace with no default-deny" "generate-networkpolicy.sh" "--namespace $ns --mode deny-all --apply"
            CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
        fi
        continue
    fi

    # Check 2: Has policies but is it default-deny?
    HAS_DEFAULT_DENY=$(kubectl get networkpolicies -n "$ns" -o json 2>/dev/null | python3 -c "
import sys, json
policies = json.load(sys.stdin)
for pol in policies.get('items', []):
    spec = pol.get('spec', {})
    selector = spec.get('podSelector', {})
    match_labels = selector.get('matchLabels', None)
    match_expressions = selector.get('matchExpressions', None)

    # Empty selector = matches all pods
    if match_labels is None and match_expressions is None:
        policy_types = spec.get('policyTypes', [])
        ingress = spec.get('ingress')
        egress = spec.get('egress')

        # Default deny: empty selector + policyType declared + no rules
        if 'Ingress' in policy_types and ingress is None:
            print('yes')
            sys.exit(0)
        if 'Egress' in policy_types and egress is None:
            print('yes')
            sys.exit(0)
        # Also catch: no ingress/egress keys at all with policyTypes set
        if ('Ingress' in policy_types or 'Egress' in policy_types) and ingress is None and egress is None:
            print('yes')
            sys.exit(0)
print('no')
" 2>/dev/null || echo "no")

    if [[ "$HAS_DEFAULT_DENY" == "no" ]]; then
        if is_prod_ns "$ns"; then
            echo -e "  ${RED}CRITICAL${RESET}  $ns — production namespace, $NETPOL_COUNT policies but no default-deny"
            report "| $ns | $POD_COUNT | $NETPOL_COUNT | no | CRITICAL | Production, no default-deny |"
            jf "NETPOL_PROD_NO_DENY" "CRITICAL" "$ns" "" "Production namespace, $NETPOL_COUNT policies but no default-deny" "generate-networkpolicy.sh" "--namespace $ns --mode deny-all --apply"
            CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
        else
            echo -e "  ${CYAN}INFO${RESET}      $ns — $NETPOL_COUNT policies, no default-deny (non-prod)"
            report "| $ns | $POD_COUNT | $NETPOL_COUNT | no | INFO | No default-deny |"
        fi
    else
        echo -e "  ${GREEN}PASS${RESET}      $ns — $NETPOL_COUNT policies, default-deny present"
        report "| $ns | $POD_COUNT | $NETPOL_COUNT | yes | PASS | Covered |"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi

    # Check 4: Permissive policies (allow from all namespaces)
    PERMISSIVE=$(kubectl get networkpolicies -n "$ns" -o json 2>/dev/null | python3 -c "
import sys, json
policies = json.load(sys.stdin)
permissive = []
for pol in policies.get('items', []):
    name = pol['metadata']['name']
    spec = pol.get('spec', {})
    for rule in spec.get('ingress', []):
        for from_rule in rule.get('from', []):
            ns_sel = from_rule.get('namespaceSelector')
            if ns_sel is not None and ns_sel == {}:
                permissive.append(name)
                break
for p in set(permissive):
    print(p)
" 2>/dev/null || true)

    if [[ -n "$PERMISSIVE" ]]; then
        while IFS= read -r pol_name; do
            [[ -z "$pol_name" ]] && continue
            echo -e "  ${YELLOW}MEDIUM${RESET}    $ns/$pol_name — allows ingress from ALL namespaces"
            report "| $ns | - | - | - | MEDIUM | $pol_name allows all NS ingress |"
            jf "NETPOL_PERMISSIVE" "MEDIUM" "$ns" "$pol_name" "Allows ingress from ALL namespaces" "" ""
            MEDIUM_COUNT=$((MEDIUM_COUNT + 1))
        done <<< "$PERMISSIVE"
    fi

done <<< "$NAMESPACES"

# Check 3: Exposed services (LoadBalancer, NodePort)
echo ""
echo -e "${BOLD}--- Exposed Services ---${RESET}"
echo ""

report ""
report "## Exposed Services"
report ""
report "| Namespace | Service | Type | Ports | Severity |"
report "|-----------|---------|------|-------|----------|"

if [[ -n "$NAMESPACE" ]]; then
    SVC_CMD="kubectl get services -n $NAMESPACE -o json"
else
    SVC_CMD="kubectl get services --all-namespaces -o json"
fi

EXPOSED=$($SVC_CMD 2>/dev/null | python3 -c "
import sys, json

SYSTEM_NS = {'kube-system', 'kube-public', 'kube-node-lease'}
skip_system = $( [[ "$SKIP_SYSTEM" == "true" ]] && echo "True" || echo "False" )

services = json.load(sys.stdin)
for svc in services.get('items', []):
    ns = svc['metadata'].get('namespace', 'default')
    if skip_system and ns in SYSTEM_NS:
        continue
    name = svc['metadata']['name']
    svc_type = svc['spec'].get('type', 'ClusterIP')
    if svc_type in ('LoadBalancer', 'NodePort'):
        ports = ','.join([f\"{p.get('port')}/{p.get('protocol','TCP')}\" for p in svc['spec'].get('ports', [])])
        print(f'{ns}|{name}|{svc_type}|{ports}')
" 2>/dev/null || true)

if [[ -z "$EXPOSED" ]]; then
    echo -e "  ${GREEN}PASS${RESET}      No LoadBalancer/NodePort services found"
else
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        E_NS=$(echo "$line" | cut -d'|' -f1)
        E_NAME=$(echo "$line" | cut -d'|' -f2)
        E_TYPE=$(echo "$line" | cut -d'|' -f3)
        E_PORTS=$(echo "$line" | cut -d'|' -f4)
        echo -e "  ${YELLOW}MEDIUM${RESET}    $E_NS/$E_NAME — $E_TYPE ($E_PORTS)"
        report "| $E_NS | $E_NAME | $E_TYPE | $E_PORTS | MEDIUM |"
        jf "SVC_EXPOSED" "MEDIUM" "$E_NS" "$E_NAME" "$E_TYPE service ($E_PORTS)" "" ""
        MEDIUM_COUNT=$((MEDIUM_COUNT + 1))
    done <<< "$EXPOSED"
fi

# Check 5: Istio AuthorizationPolicies
if [[ "$CHECK_MESH" == "true" ]]; then
    echo ""
    echo -e "${BOLD}--- Service Mesh Policies ---${RESET}"
    echo ""

    report ""
    report "## Service Mesh"
    report ""

    if kubectl get namespace istio-system &>/dev/null 2>&1; then
        AUTHZ_COUNT=$(kubectl get authorizationpolicies.security.istio.io -A --no-headers 2>/dev/null | wc -l || echo "0")

        if [[ "$AUTHZ_COUNT" -eq 0 ]]; then
            echo -e "  ${YELLOW}HIGH${RESET}      Istio installed but no AuthorizationPolicies found"
            report "Istio installed, 0 AuthorizationPolicies — HIGH"
            jf "MESH_NO_AUTHZ" "HIGH" "istio-system" "" "Istio installed but no AuthorizationPolicies found" "" ""
            HIGH_COUNT=$((HIGH_COUNT + 1))
        else
            echo -e "  ${GREEN}PASS${RESET}      Istio: $AUTHZ_COUNT AuthorizationPolicies active"
            report "Istio: $AUTHZ_COUNT AuthorizationPolicies — PASS"
            PASS_COUNT=$((PASS_COUNT + 1))
        fi
    else
        echo -e "  ${CYAN}SKIP${RESET}      Istio not installed"
        report "Istio: not installed — skipped"
    fi
fi

echo ""
echo -e "${BOLD}=== Summary ===${RESET}"
echo "  Namespaces checked: $TOTAL_NS"
echo -e "  ${RED}CRITICAL${RESET}: $CRITICAL_COUNT (production without default-deny)"
echo -e "  ${YELLOW}HIGH${RESET}    : $HIGH_COUNT (no NetworkPolicies / no mesh policies)"
echo -e "  ${YELLOW}MEDIUM${RESET}  : $MEDIUM_COUNT (exposed services / permissive rules)"
echo -e "  ${GREEN}PASS${RESET}    : $PASS_COUNT"
echo ""

if [[ $CRITICAL_COUNT -gt 0 ]]; then
    echo "Fix: Apply default-deny to production namespaces:"
    echo "  bash responders/generate-networkpolicy.sh --namespace <NS> --mode deny-all --apply"
    echo ""
fi

report ""
report "## Summary"
report ""
report "- Namespaces: $TOTAL_NS"
report "- CRITICAL: $CRITICAL_COUNT"
report "- HIGH: $HIGH_COUNT"
report "- MEDIUM: $MEDIUM_COUNT"
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
json.dump({'watcher': 'watch-network-coverage', 'findings': findings, 'summary': {'total': len(findings), 'critical': sum(1 for f in findings if f['severity'] == 'CRITICAL'), 'high': sum(1 for f in findings if f['severity'] == 'HIGH'), 'medium': sum(1 for f in findings if f['severity'] == 'MEDIUM')}}, sys.stdout, indent=2)
print()
"
fi
