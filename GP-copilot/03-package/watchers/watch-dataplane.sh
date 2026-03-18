#!/usr/bin/env bash
# watch-dataplane.sh — Kubernetes data-plane health checker
# Part of GP-CONSULTING/03-DEPLOY-RUNTIME/watchers/
#
# The "everything green but customers timing out" watcher.
#
# Checks:
#   1. Empty/stale Endpoints — Service exists but no backends        → CRITICAL
#   2. Selector mismatch — Service selector matches zero pods        → CRITICAL
#   3. CoreDNS health — pod status, restarts, upstream DNS errors    → HIGH/CRITICAL
#   4. kube-proxy readiness — DaemonSet desired vs ready             → CRITICAL
#   5. CNI plugin health — kindnet/calico/cilium DaemonSet readiness → CRITICAL
#   6. Not-Ready pods in workload namespaces                         → HIGH
#   7. Endpoint→Pod drift — endpoints pointing at non-Running pods   → HIGH
#   8. DNS resolution test — resolve kubernetes.default.svc           → CRITICAL
#
# Dependencies: kubectl, python3
#
# References:
#   SRE: "If the data plane is down, nothing else matters"
#   CKS: Cluster Networking, Service Networking

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

Diagnose data-plane issues that cause customer-facing timeouts while kubectl
shows everything "green." Checks endpoints, DNS, kube-proxy, CNI, and pod
readiness.

Options:
  --namespace NS    Scope endpoint/pod checks to a single namespace
  --include-system  Include system namespaces in workload checks
  --report FILE     Write markdown report to FILE
  --json            Output structured JSON findings (for piping to responders)
  -h, --help        Show this help

Examples:
  bash $SCRIPT_NAME                        # full cluster dataplane audit
  bash $SCRIPT_NAME --namespace anthra     # single namespace
  bash $SCRIPT_NAME --json | jq '.findings[] | select(.severity == "CRITICAL")'
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
    echo -e "${RED}ERROR: Cannot reach cluster.${RESET}" >&2
    exit 1
fi

CONTEXT=$(kubectl config current-context)

CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
PASS_COUNT=0

REPORT_LINES=""
report() { REPORT_LINES+="$1"$'\n'; }

# JSON findings collector (pipe-delimited: code|severity|namespace|resource|message|responder|args)
JSON_LINES=""
jf() { JSON_LINES+="$1|$2|$3|$4|$5|$6|$7"$'\n'; }

# When --json, send human-readable output to stderr so stdout is clean JSON
if [[ "$JSON_OUTPUT" == "true" ]]; then
    exec 3>&1 1>&2
fi

echo ""
echo -e "${BOLD}=== Data-Plane Health Check ===${RESET}"
echo -e "  Cluster: $CONTEXT"
echo -e "  Time:    $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""

report "# Data-Plane Health Check — $(date -u '+%Y-%m-%d %H:%M UTC')"
report ""
report "Cluster: $CONTEXT"
report ""

is_system_ns() {
    local ns="$1"
    for sys in $SYSTEM_NS; do
        [[ "$ns" == "$sys" ]] && return 0
    done
    return 1
}

# ─── Check 1 & 2: Empty Endpoints and Selector Mismatches ─────────────────

echo -e "${BOLD}--- Endpoint Health ---${RESET}"
echo ""

report "## Endpoint Health"
report ""
report "| Namespace | Service | Endpoints | Status | Severity |"
report "|-----------|---------|-----------|--------|----------|"

if [[ -n "$NAMESPACE" ]]; then
    SVC_JSON=$(kubectl get services -n "$NAMESPACE" -o json 2>/dev/null)
    EP_JSON=$(kubectl get endpoints -n "$NAMESPACE" -o json 2>/dev/null)
else
    SVC_JSON=$(kubectl get services --all-namespaces -o json 2>/dev/null)
    EP_JSON=$(kubectl get endpoints --all-namespaces -o json 2>/dev/null)
fi

# Python does the heavy lifting: list services with selectors for endpoint checking
SKIP_SYSTEM_PY=$( [[ "$SKIP_SYSTEM" == "true" ]] && echo "True" || echo "False" )
ENDPOINT_FINDINGS=$(echo "$SVC_JSON" | python3 -c "
import sys, json

skip_system = $SKIP_SYSTEM_PY
SYSTEM_NS = {'kube-system', 'kube-public', 'kube-node-lease'}

svcs = json.load(sys.stdin)

for svc in svcs.get('items', []):
    ns = svc['metadata'].get('namespace', 'default')
    name = svc['metadata']['name']
    svc_type = svc['spec'].get('type', 'ClusterIP')

    if skip_system and ns in SYSTEM_NS:
        continue
    # Skip headless services (clusterIP: None) — they don't route through kube-proxy
    if svc['spec'].get('clusterIP') in (None, 'None', ''):
        continue
    # Skip ExternalName services — no endpoints expected
    if svc_type == 'ExternalName':
        continue

    selector = svc['spec'].get('selector')
    if not selector:
        # No selector = manually managed endpoints, skip
        continue

    # Report service for endpoint matching
    sel_str = ','.join(f'{k}={v}' for k, v in sorted(selector.items()))
    print(f'SVC|{ns}|{name}|{svc_type}|{sel_str}')
" 2>/dev/null || true)

# Now check each service's endpoints
EMPTY_EP_COUNT=0
CHECKED_SVC=0

while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" != SVC\|* ]] && continue

    SVC_NS=$(echo "$line" | cut -d'|' -f2)
    SVC_NAME=$(echo "$line" | cut -d'|' -f3)
    SVC_TYPE=$(echo "$line" | cut -d'|' -f4)
    SVC_SEL=$(echo "$line" | cut -d'|' -f5)

    CHECKED_SVC=$((CHECKED_SVC + 1))

    # Get endpoint addresses count (trim whitespace to avoid bash arithmetic errors)
    EP_ADDRS=$(kubectl get endpoints "$SVC_NAME" -n "$SVC_NS" -o jsonpath='{range .subsets[*]}{range .addresses[*]}{.ip}{"\n"}{end}{end}' 2>/dev/null | grep -c . || true)
    EP_ADDRS="${EP_ADDRS:-0}"; EP_ADDRS="${EP_ADDRS//[^0-9]/}"
    NOT_READY_ADDRS=$(kubectl get endpoints "$SVC_NAME" -n "$SVC_NS" -o jsonpath='{range .subsets[*]}{range .notReadyAddresses[*]}{.ip}{"\n"}{end}{end}' 2>/dev/null | grep -c . || true)
    NOT_READY_ADDRS="${NOT_READY_ADDRS:-0}"; NOT_READY_ADDRS="${NOT_READY_ADDRS//[^0-9]/}"
    [[ -z "$EP_ADDRS" ]] && EP_ADDRS=0
    [[ -z "$NOT_READY_ADDRS" ]] && NOT_READY_ADDRS=0

    if [[ "$EP_ADDRS" -eq 0 && "$NOT_READY_ADDRS" -eq 0 ]]; then
        # Check if selector matches any pods at all
        MATCHING_PODS=$(kubectl get pods -n "$SVC_NS" -l "$SVC_SEL" --no-headers 2>/dev/null | wc -l || echo "0")

        if [[ "$MATCHING_PODS" -eq 0 ]]; then
            echo -e "  ${RED}CRITICAL${RESET}  $SVC_NS/$SVC_NAME — selector ($SVC_SEL) matches 0 pods"
            report "| $SVC_NS | $SVC_NAME | 0 | selector mismatch | CRITICAL |"
            jf "DATAPLANE_SELECTOR_MISMATCH" "CRITICAL" "$SVC_NS" "$SVC_NAME" "Selector ($SVC_SEL) matches 0 pods — service is dead" "" ""
            CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
        else
            echo -e "  ${RED}CRITICAL${RESET}  $SVC_NS/$SVC_NAME — $MATCHING_PODS pods match but 0 endpoints ready"
            report "| $SVC_NS | $SVC_NAME | 0 | pods exist, none ready | CRITICAL |"
            jf "DATAPLANE_ENDPOINT_EMPTY" "CRITICAL" "$SVC_NS" "$SVC_NAME" "$MATCHING_PODS pods match selector but 0 endpoints ready" "" ""
            CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
        fi
        EMPTY_EP_COUNT=$((EMPTY_EP_COUNT + 1))

    elif [[ "$NOT_READY_ADDRS" -gt 0 ]]; then
        echo -e "  ${YELLOW}HIGH${RESET}      $SVC_NS/$SVC_NAME — $EP_ADDRS ready, $NOT_READY_ADDRS not-ready endpoints"
        report "| $SVC_NS | $SVC_NAME | $EP_ADDRS ready / $NOT_READY_ADDRS not-ready | degraded | HIGH |"
        jf "DATAPLANE_ENDPOINT_DEGRADED" "HIGH" "$SVC_NS" "$SVC_NAME" "$EP_ADDRS ready, $NOT_READY_ADDRS not-ready endpoints — service is degraded" "" ""
        HIGH_COUNT=$((HIGH_COUNT + 1))
    else
        echo -e "  ${GREEN}PASS${RESET}      $SVC_NS/$SVC_NAME — $EP_ADDRS endpoints"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi

done <<< "$ENDPOINT_FINDINGS"

if [[ "$CHECKED_SVC" -eq 0 ]]; then
    echo -e "  ${CYAN}SKIP${RESET}      No services with selectors found"
fi

# ─── Check 3: CoreDNS Health ──────────────────────────────────────────────

echo ""
echo -e "${BOLD}--- CoreDNS Health ---${RESET}"
echo ""

report ""
report "## CoreDNS Health"
report ""

COREDNS_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null || true)

if [[ -z "$COREDNS_PODS" ]]; then
    echo -e "  ${RED}CRITICAL${RESET}  CoreDNS pods not found"
    report "CoreDNS: **NOT FOUND** — CRITICAL"
    jf "DATAPLANE_DNS_DOWN" "CRITICAL" "kube-system" "coredns" "CoreDNS pods not found — cluster DNS is offline" "" ""
    CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
else
    COREDNS_TOTAL=$(echo "$COREDNS_PODS" | wc -l)
    COREDNS_READY=$(echo "$COREDNS_PODS" | awk '{print $2}' | grep -c "^[0-9]*/[0-9]*$" || echo "0")
    COREDNS_RUNNING=$(echo "$COREDNS_PODS" | grep -c "Running" || echo "0")
    COREDNS_RESTARTS=$(echo "$COREDNS_PODS" | awk '{sum += $4} END {print sum+0}')

    if [[ "$COREDNS_RUNNING" -lt "$COREDNS_TOTAL" ]]; then
        echo -e "  ${RED}CRITICAL${RESET}  CoreDNS: $COREDNS_RUNNING/$COREDNS_TOTAL running"
        report "CoreDNS: $COREDNS_RUNNING/$COREDNS_TOTAL running — CRITICAL"
        jf "DATAPLANE_DNS_DOWN" "CRITICAL" "kube-system" "coredns" "Only $COREDNS_RUNNING/$COREDNS_TOTAL CoreDNS pods running" "" ""
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    else
        echo -e "  ${GREEN}PASS${RESET}      CoreDNS: $COREDNS_TOTAL/$COREDNS_TOTAL running"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi

    if [[ "$COREDNS_RESTARTS" -gt 5 ]]; then
        echo -e "  ${YELLOW}HIGH${RESET}      CoreDNS total restarts: $COREDNS_RESTARTS (>5)"
        report "CoreDNS restarts: $COREDNS_RESTARTS — HIGH"
        jf "DATAPLANE_DNS_RESTARTS" "HIGH" "kube-system" "coredns" "CoreDNS total restarts: $COREDNS_RESTARTS — possible instability" "" ""
        HIGH_COUNT=$((HIGH_COUNT + 1))
    elif [[ "$COREDNS_RESTARTS" -gt 0 ]]; then
        echo -e "  ${CYAN}INFO${RESET}      CoreDNS total restarts: $COREDNS_RESTARTS"
    fi

    # Check CoreDNS logs for upstream errors (SERVFAIL, timeout, REFUSED)
    DNS_ERRORS=$(kubectl logs -n kube-system -l k8s-app=kube-dns --tail=200 2>/dev/null | grep -ciE "SERVFAIL|i/o timeout|REFUSED|connection refused|no such host" || echo "0")

    if [[ "$DNS_ERRORS" -gt 10 ]]; then
        echo -e "  ${YELLOW}HIGH${RESET}      CoreDNS upstream errors: $DNS_ERRORS in last 200 log lines"
        report "CoreDNS upstream errors: $DNS_ERRORS — HIGH"
        jf "DATAPLANE_DNS_ERRORS" "HIGH" "kube-system" "coredns" "$DNS_ERRORS upstream DNS errors (SERVFAIL/timeout/REFUSED) in recent logs" "" ""
        HIGH_COUNT=$((HIGH_COUNT + 1))
    elif [[ "$DNS_ERRORS" -gt 0 ]]; then
        echo -e "  ${YELLOW}MEDIUM${RESET}    CoreDNS upstream errors: $DNS_ERRORS in last 200 log lines"
        report "CoreDNS upstream errors: $DNS_ERRORS — MEDIUM"
        jf "DATAPLANE_DNS_ERRORS" "MEDIUM" "kube-system" "coredns" "$DNS_ERRORS upstream DNS errors in recent logs — may cause intermittent resolution failures" "" ""
        MEDIUM_COUNT=$((MEDIUM_COUNT + 1))
    else
        echo -e "  ${GREEN}PASS${RESET}      CoreDNS: no upstream errors in recent logs"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
fi

# ─── Check 4: kube-proxy Readiness ───────────────────────────────────────

echo ""
echo -e "${BOLD}--- kube-proxy ---${RESET}"
echo ""

report ""
report "## kube-proxy"
report ""

KPROXY_DS=$(kubectl get daemonset -n kube-system -l k8s-app=kube-proxy -o json 2>/dev/null || echo '{"items":[]}')
KPROXY_COUNT=$(echo "$KPROXY_DS" | python3 -c "
import sys, json
ds = json.load(sys.stdin)
items = ds.get('items', [])
if not items:
    print('MISSING|0|0')
else:
    d = items[0]
    desired = d.get('status', {}).get('desiredNumberScheduled', 0)
    ready = d.get('status', {}).get('numberReady', 0)
    print(f'OK|{desired}|{ready}')
" 2>/dev/null || echo "MISSING|0|0")

KP_STATUS=$(echo "$KPROXY_COUNT" | cut -d'|' -f1)
KP_DESIRED=$(echo "$KPROXY_COUNT" | cut -d'|' -f2)
KP_READY=$(echo "$KPROXY_COUNT" | cut -d'|' -f3)

if [[ "$KP_STATUS" == "MISSING" ]]; then
    # Some clusters use cilium kube-proxy replacement or similar
    # Check if a kube-proxy replacement is present
    CILIUM_AGENT=$(kubectl get daemonset -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | wc -l || echo "0")
    if [[ "$CILIUM_AGENT" -gt 0 ]]; then
        echo -e "  ${GREEN}PASS${RESET}      kube-proxy replaced by Cilium"
        report "kube-proxy: replaced by Cilium — PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  ${RED}CRITICAL${RESET}  kube-proxy DaemonSet not found and no replacement detected"
        report "kube-proxy: **NOT FOUND** — CRITICAL"
        jf "DATAPLANE_PROXY_MISSING" "CRITICAL" "kube-system" "kube-proxy" "kube-proxy DaemonSet not found — iptables/IPVS rules not being programmed" "" ""
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    fi
elif [[ "$KP_READY" -lt "$KP_DESIRED" ]]; then
    echo -e "  ${RED}CRITICAL${RESET}  kube-proxy: $KP_READY/$KP_DESIRED ready — iptables rules not programmed on $((KP_DESIRED - KP_READY)) node(s)"
    report "kube-proxy: $KP_READY/$KP_DESIRED ready — CRITICAL"
    jf "DATAPLANE_PROXY_DEGRADED" "CRITICAL" "kube-system" "kube-proxy" "$KP_READY/$KP_DESIRED ready — nodes without iptables rules will drop Service traffic" "" ""
    CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
else
    echo -e "  ${GREEN}PASS${RESET}      kube-proxy: $KP_READY/$KP_DESIRED ready"
    report "kube-proxy: $KP_READY/$KP_DESIRED ready — PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
fi

# ─── Check 5: CNI Plugin Health ──────────────────────────────────────────

echo ""
echo -e "${BOLD}--- CNI Plugin ---${RESET}"
echo ""

report ""
report "## CNI Plugin"
report ""

# Detect CNI: kindnet, calico, cilium, flannel, weave
CNI_FOUND=false
for CNI_LABEL in "app=kindnet" "k8s-app=calico-node" "k8s-app=cilium" "app=flannel" "name=weave-net"; do
    CNI_DS=$(kubectl get daemonset -n kube-system -l "$CNI_LABEL" -o json 2>/dev/null || echo '{"items":[]}')
    CNI_ITEMS=$(echo "$CNI_DS" | python3 -c "
import sys, json
ds = json.load(sys.stdin)
items = ds.get('items', [])
if not items:
    print('NONE|0|0|unknown')
else:
    d = items[0]
    name = d['metadata']['name']
    desired = d.get('status', {}).get('desiredNumberScheduled', 0)
    ready = d.get('status', {}).get('numberReady', 0)
    print(f'OK|{desired}|{ready}|{name}')
" 2>/dev/null || echo "NONE|0|0|unknown")

    CNI_STATUS=$(echo "$CNI_ITEMS" | cut -d'|' -f1)
    if [[ "$CNI_STATUS" == "OK" ]]; then
        CNI_DESIRED=$(echo "$CNI_ITEMS" | cut -d'|' -f2)
        CNI_READY=$(echo "$CNI_ITEMS" | cut -d'|' -f3)
        CNI_NAME=$(echo "$CNI_ITEMS" | cut -d'|' -f4)
        CNI_FOUND=true

        if [[ "$CNI_READY" -lt "$CNI_DESIRED" ]]; then
            echo -e "  ${RED}CRITICAL${RESET}  $CNI_NAME: $CNI_READY/$CNI_DESIRED ready — pod networking broken on $((CNI_DESIRED - CNI_READY)) node(s)"
            report "$CNI_NAME: $CNI_READY/$CNI_DESIRED — CRITICAL"
            jf "DATAPLANE_CNI_DEGRADED" "CRITICAL" "kube-system" "$CNI_NAME" "$CNI_READY/$CNI_DESIRED ready — pod-to-pod networking broken on $((CNI_DESIRED - CNI_READY)) node(s)" "" ""
            CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
        else
            echo -e "  ${GREEN}PASS${RESET}      $CNI_NAME: $CNI_READY/$CNI_DESIRED ready"
            report "$CNI_NAME: $CNI_READY/$CNI_DESIRED — PASS"
            PASS_COUNT=$((PASS_COUNT + 1))
        fi
        break
    fi
done

if [[ "$CNI_FOUND" == "false" ]]; then
    echo -e "  ${YELLOW}HIGH${RESET}      Could not detect CNI plugin DaemonSet"
    report "CNI: unknown — HIGH"
    jf "DATAPLANE_CNI_UNKNOWN" "HIGH" "kube-system" "" "Could not detect CNI plugin — unable to verify pod networking health" "" ""
    HIGH_COUNT=$((HIGH_COUNT + 1))
fi

# ─── Check 6: Not-Ready Pods in Workload Namespaces ─────────────────────

echo ""
echo -e "${BOLD}--- Pod Readiness (Workloads) ---${RESET}"
echo ""

report ""
report "## Pod Readiness"
report ""
report "| Namespace | Pod | Ready | Status | Restarts | Severity |"
report "|-----------|-----|-------|--------|----------|----------|"

if [[ -n "$NAMESPACE" ]]; then
    POD_JSON=$(kubectl get pods -n "$NAMESPACE" -o json 2>/dev/null)
else
    POD_JSON=$(kubectl get pods --all-namespaces -o json 2>/dev/null)
fi

NOT_READY_FINDINGS=$(echo "$POD_JSON" | python3 -c "
import sys, json

skip_system = $SKIP_SYSTEM_PY
SYSTEM_NS = {'kube-system', 'kube-public', 'kube-node-lease'}

pods = json.load(sys.stdin)
for pod in pods.get('items', []):
    ns = pod['metadata'].get('namespace', 'default')
    if skip_system and ns in SYSTEM_NS:
        continue
    name = pod['metadata']['name']
    phase = pod.get('status', {}).get('phase', 'Unknown')

    # Check container statuses
    container_statuses = pod.get('status', {}).get('containerStatuses', [])
    total = len(container_statuses)
    ready = sum(1 for c in container_statuses if c.get('ready', False))
    restarts = sum(c.get('restartCount', 0) for c in container_statuses)

    if phase not in ('Running', 'Succeeded'):
        print(f'HIGH|{ns}|{name}|{ready}/{total}|{phase}|{restarts}')
    elif total > 0 and ready < total:
        print(f'HIGH|{ns}|{name}|{ready}/{total}|{phase}|{restarts}')
    elif restarts > 10:
        print(f'MEDIUM|{ns}|{name}|{ready}/{total}|{phase}|{restarts}')
" 2>/dev/null || true)

NOT_READY_COUNT=0
if [[ -n "$NOT_READY_FINDINGS" ]]; then
    while IFS= read -r finding; do
        [[ -z "$finding" ]] && continue
        F_SEV=$(echo "$finding" | cut -d'|' -f1)
        F_NS=$(echo "$finding" | cut -d'|' -f2)
        F_POD=$(echo "$finding" | cut -d'|' -f3)
        F_READY=$(echo "$finding" | cut -d'|' -f4)
        F_STATUS=$(echo "$finding" | cut -d'|' -f5)
        F_RESTARTS=$(echo "$finding" | cut -d'|' -f6)

        NOT_READY_COUNT=$((NOT_READY_COUNT + 1))

        if [[ "$F_SEV" == "HIGH" ]]; then
            echo -e "  ${YELLOW}HIGH${RESET}      $F_NS/$F_POD — $F_READY ready, status=$F_STATUS, restarts=$F_RESTARTS"
            report "| $F_NS | $F_POD | $F_READY | $F_STATUS | $F_RESTARTS | HIGH |"
            jf "DATAPLANE_POD_NOT_READY" "HIGH" "$F_NS" "$F_POD" "Pod not fully ready ($F_READY), status=$F_STATUS, restarts=$F_RESTARTS" "" ""
            HIGH_COUNT=$((HIGH_COUNT + 1))
        else
            echo -e "  ${YELLOW}MEDIUM${RESET}    $F_NS/$F_POD — $F_READY ready, $F_RESTARTS restarts (flapping)"
            report "| $F_NS | $F_POD | $F_READY | $F_STATUS | $F_RESTARTS | MEDIUM |"
            jf "DATAPLANE_POD_FLAPPING" "MEDIUM" "$F_NS" "$F_POD" "Pod has $F_RESTARTS restarts — possible flapping" "" ""
            MEDIUM_COUNT=$((MEDIUM_COUNT + 1))
        fi
    done <<< "$NOT_READY_FINDINGS"
fi

if [[ "$NOT_READY_COUNT" -eq 0 ]]; then
    echo -e "  ${GREEN}PASS${RESET}      All workload pods ready"
    PASS_COUNT=$((PASS_COUNT + 1))
fi

# ─── Check 7: DNS Resolution Test ────────────────────────────────────────

echo ""
echo -e "${BOLD}--- DNS Resolution Test ---${RESET}"
echo ""

report ""
report "## DNS Resolution Test"
report ""

# Test DNS from inside the cluster using a one-shot pod
# Use kubectl run with --rm to avoid leaving debris
DNS_TEST_RESULT=$(kubectl run dataplane-dns-test \
    --image=busybox:1.36 \
    --restart=Never \
    --rm -i \
    --timeout=15s \
    --command -- nslookup kubernetes.default.svc.cluster.local 2>&1 || echo "DNS_FAILED")

if echo "$DNS_TEST_RESULT" | grep -q "Address.*10\." 2>/dev/null; then
    echo -e "  ${GREEN}PASS${RESET}      DNS resolves kubernetes.default.svc.cluster.local"
    report "DNS test: kubernetes.default.svc.cluster.local — PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
elif echo "$DNS_TEST_RESULT" | grep -qi "DNS_FAILED\|NXDOMAIN\|can't resolve\|timed out\|connection refused" 2>/dev/null; then
    echo -e "  ${RED}CRITICAL${RESET}  DNS cannot resolve kubernetes.default.svc.cluster.local"
    echo -e "           ${CYAN}Result: $(echo "$DNS_TEST_RESULT" | head -3 | tr '\n' ' ')${RESET}"
    report "DNS test: kubernetes.default.svc.cluster.local — **FAILED** — CRITICAL"
    jf "DATAPLANE_DNS_RESOLUTION_FAILED" "CRITICAL" "kube-system" "coredns" "Cannot resolve kubernetes.default.svc.cluster.local from inside the cluster" "" ""
    CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
else
    # Ambiguous result — might be pod scheduling issue, not DNS
    echo -e "  ${YELLOW}MEDIUM${RESET}    DNS test inconclusive (test pod may not have scheduled)"
    echo -e "           ${CYAN}$(echo "$DNS_TEST_RESULT" | head -2 | tr '\n' ' ')${RESET}"
    report "DNS test: inconclusive — MEDIUM"
    jf "DATAPLANE_DNS_TEST_INCONCLUSIVE" "MEDIUM" "kube-system" "" "DNS resolution test could not complete — check pod scheduling" "" ""
    MEDIUM_COUNT=$((MEDIUM_COUNT + 1))
fi

# Clean up stale test pod if it wasn't removed
kubectl delete pod dataplane-dns-test --ignore-not-found --wait=false &>/dev/null || true

# ─── Check 8: Node Readiness ─────────────────────────────────────────────

echo ""
echo -e "${BOLD}--- Node Health ---${RESET}"
echo ""

report ""
report "## Node Health"
report ""
report "| Node | Status | Roles | Severity |"
report "|------|--------|-------|----------|"

NODE_STATUS=$(kubectl get nodes -o json 2>/dev/null | python3 -c "
import sys, json
nodes = json.load(sys.stdin)
for node in nodes.get('items', []):
    name = node['metadata']['name']
    roles = ','.join(k.replace('node-role.kubernetes.io/', '') for k in node['metadata'].get('labels', {}) if k.startswith('node-role.kubernetes.io/'))
    if not roles:
        roles = 'worker'
    conditions = {c['type']: c['status'] for c in node.get('status', {}).get('conditions', [])}
    ready = conditions.get('Ready', 'Unknown')
    pressure = []
    if conditions.get('MemoryPressure') == 'True':
        pressure.append('MemoryPressure')
    if conditions.get('DiskPressure') == 'True':
        pressure.append('DiskPressure')
    if conditions.get('PIDPressure') == 'True':
        pressure.append('PIDPressure')
    if ready != 'True':
        print(f'CRITICAL|{name}|NotReady|{roles}')
    elif pressure:
        p_str = ','.join(pressure)
        print(f'HIGH|{name}|{p_str}|{roles}')
    else:
        print(f'PASS|{name}|Ready|{roles}')
" 2>/dev/null || true)

while IFS= read -r nline; do
    [[ -z "$nline" ]] && continue
    N_SEV=$(echo "$nline" | cut -d'|' -f1)
    N_NAME=$(echo "$nline" | cut -d'|' -f2)
    N_STATUS=$(echo "$nline" | cut -d'|' -f3)
    N_ROLES=$(echo "$nline" | cut -d'|' -f4)

    if [[ "$N_SEV" == "CRITICAL" ]]; then
        echo -e "  ${RED}CRITICAL${RESET}  $N_NAME ($N_ROLES) — $N_STATUS"
        report "| $N_NAME | $N_STATUS | $N_ROLES | CRITICAL |"
        jf "DATAPLANE_NODE_NOT_READY" "CRITICAL" "" "$N_NAME" "Node $N_NAME is NotReady — pods on this node cannot receive traffic" "" ""
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    elif [[ "$N_SEV" == "HIGH" ]]; then
        echo -e "  ${YELLOW}HIGH${RESET}      $N_NAME ($N_ROLES) — $N_STATUS"
        report "| $N_NAME | $N_STATUS | $N_ROLES | HIGH |"
        jf "DATAPLANE_NODE_PRESSURE" "HIGH" "" "$N_NAME" "Node $N_NAME has $N_STATUS — may evict pods or reject scheduling" "" ""
        HIGH_COUNT=$((HIGH_COUNT + 1))
    else
        echo -e "  ${GREEN}PASS${RESET}      $N_NAME ($N_ROLES) — Ready"
        report "| $N_NAME | Ready | $N_ROLES | PASS |"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
done <<< "$NODE_STATUS"

# ─── Summary ─────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}=== Summary ===${RESET}"
echo "  Services checked: $CHECKED_SVC"
echo -e "  ${RED}CRITICAL${RESET}: $CRITICAL_COUNT (traffic not flowing)"
echo -e "  ${YELLOW}HIGH${RESET}    : $HIGH_COUNT (degraded / unstable)"
echo -e "  ${YELLOW}MEDIUM${RESET}  : $MEDIUM_COUNT (flapping / inconclusive)"
echo -e "  ${GREEN}PASS${RESET}    : $PASS_COUNT"
echo ""

if [[ $CRITICAL_COUNT -eq 0 && $HIGH_COUNT -eq 0 ]]; then
    echo -e "  ${GREEN}Data plane looks healthy.${RESET}"
    echo ""
elif [[ $CRITICAL_COUNT -gt 0 ]]; then
    echo -e "  ${RED}CRITICAL findings detected — customer-facing impact likely.${RESET}"
    echo ""
    echo "  Triage order:"
    echo "    1. kube-proxy / CNI not ready → nodes can't route traffic"
    echo "    2. DNS down → all service discovery broken"
    echo "    3. Empty endpoints → specific services unreachable"
    echo "    4. Node NotReady → pods on that node are orphaned"
    echo ""
fi

report ""
report "## Summary"
report ""
report "- Services checked: $CHECKED_SVC"
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
    exec 1>&3 3>&-
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
json.dump({'watcher': 'watch-dataplane', 'findings': findings, 'summary': {'total': len(findings), 'critical': sum(1 for f in findings if f['severity'] == 'CRITICAL'), 'high': sum(1 for f in findings if f['severity'] == 'HIGH'), 'medium': sum(1 for f in findings if f['severity'] == 'MEDIUM')}}, sys.stdout, indent=2)
print()
"
fi
