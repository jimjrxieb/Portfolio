#!/usr/bin/env bash
# cks-practice.sh — CKS practice scenarios with validation
# Usage: ./cks-practice.sh [scenario-number]
# Requires: kubectl access to a cluster (use a test cluster!)
set -euo pipefail

SCENARIO="${1:-0}"
NS="cks-practice"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

setup_ns() {
    kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -
}

cleanup() {
    echo -e "${YELLOW}Cleaning up namespace ${NS}...${NC}"
    kubectl delete ns "$NS" --ignore-not-found --wait=false
}

validate() {
    if eval "$1" &>/dev/null; then
        echo -e "${GREEN}[PASS]${NC} $2"
    else
        echo -e "${RED}[FAIL]${NC} $2"
        echo -e "  Expected: $3"
    fi
}

scenario_menu() {
    cat <<'MENU'
╔══════════════════════════════════════════════════╗
║              CKS Practice Scenarios              ║
╠══════════════════════════════════════════════════╣
║  1. Pod Security — Create hardened deployment    ║
║  2. NetworkPolicy — Isolate a namespace          ║
║  3. RBAC — Create scoped service account         ║
║  4. Secrets — Encrypt at rest                    ║
║  5. AppArmor — Apply profile to pod              ║
║  6. Seccomp — Apply RuntimeDefault               ║
║  7. Audit Policy — Write K8s audit config        ║
║  8. Falco — Detect shell in container            ║
║  9. Image Policy — Block :latest with Kyverno    ║
║ 10. Incident Response — Isolate compromised pod  ║
║                                                  ║
║  0. Show this menu                               ║
║  cleanup. Remove practice namespace              ║
╚══════════════════════════════════════════════════╝
MENU
}

scenario_1() {
    echo -e "${BLUE}=== Scenario 1: Pod Security ===${NC}"
    echo "Create a Deployment named 'secure-app' in namespace '${NS}' with:"
    echo "  - Image: nginx:1.25"
    echo "  - runAsNonRoot: true"
    echo "  - runAsUser: 1000"
    echo "  - readOnlyRootFilesystem: true"
    echo "  - allowPrivilegeEscalation: false"
    echo "  - capabilities drop ALL"
    echo "  - seccompProfile: RuntimeDefault"
    echo "  - CPU limit: 200m, Memory limit: 128Mi"
    echo ""
    echo "When ready, press Enter to validate..."
    read -r

    setup_ns
    validate \
        "kubectl get deployment secure-app -n $NS -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}' | grep -q 'true'" \
        "runAsNonRoot: true" \
        "spec.template.spec.securityContext.runAsNonRoot = true"
    validate \
        "kubectl get deployment secure-app -n $NS -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}' | grep -q 'true'" \
        "readOnlyRootFilesystem: true" \
        "spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem = true"
    validate \
        "kubectl get deployment secure-app -n $NS -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}' | grep -q 'false'" \
        "allowPrivilegeEscalation: false" \
        "spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation = false"
    validate \
        "kubectl get deployment secure-app -n $NS -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' | grep -q '200m'" \
        "CPU limit: 200m" \
        "spec.template.spec.containers[0].resources.limits.cpu = 200m"
}

scenario_2() {
    echo -e "${BLUE}=== Scenario 2: NetworkPolicy ===${NC}"
    setup_ns

    # Create target pods
    kubectl run frontend --image=nginx:1.25 -n "$NS" -l app=frontend --dry-run=client -o yaml | kubectl apply -f -
    kubectl run backend --image=nginx:1.25 -n "$NS" -l app=backend --dry-run=client -o yaml | kubectl apply -f -

    echo "Two pods created in '${NS}': frontend and backend"
    echo ""
    echo "Create NetworkPolicies that:"
    echo "  1. Default deny all ingress AND egress in namespace '${NS}'"
    echo "  2. Allow frontend -> backend on port 80"
    echo "  3. Allow DNS egress for all pods (port 53 UDP/TCP)"
    echo ""
    echo "When ready, press Enter to validate..."
    read -r

    validate \
        "kubectl get networkpolicy -n $NS --no-headers | wc -l | grep -qE '[2-9]|[0-9]{2}'" \
        "At least 2 NetworkPolicies exist" \
        "Multiple NetworkPolicies in namespace"
    validate \
        "kubectl get networkpolicy -n $NS -o json | jq -e '.items[] | select(.spec.podSelector == {} and .spec.policyTypes | contains([\"Ingress\",\"Egress\"]))'" \
        "Default deny-all policy exists" \
        "NetworkPolicy with empty podSelector and both Ingress+Egress policyTypes"
}

scenario_3() {
    echo -e "${BLUE}=== Scenario 3: RBAC ===${NC}"
    setup_ns

    echo "Create the following in namespace '${NS}':"
    echo "  1. ServiceAccount named 'app-sa'"
    echo "  2. Role named 'pod-reader' with get,list,watch on pods"
    echo "  3. RoleBinding binding 'pod-reader' to 'app-sa'"
    echo "  4. Verify: app-sa CAN list pods but CANNOT delete pods"
    echo ""
    echo "When ready, press Enter to validate..."
    read -r

    validate \
        "kubectl get sa app-sa -n $NS" \
        "ServiceAccount app-sa exists" \
        "ServiceAccount in namespace ${NS}"
    validate \
        "kubectl get role pod-reader -n $NS" \
        "Role pod-reader exists" \
        "Role in namespace ${NS}"
    validate \
        "kubectl auth can-i list pods -n $NS --as=system:serviceaccount:${NS}:app-sa | grep -q 'yes'" \
        "app-sa can list pods" \
        "auth can-i list pods = yes"
    validate \
        "kubectl auth can-i delete pods -n $NS --as=system:serviceaccount:${NS}:app-sa | grep -q 'no'" \
        "app-sa cannot delete pods" \
        "auth can-i delete pods = no"
}

scenario_10() {
    echo -e "${BLUE}=== Scenario 10: Incident Response ===${NC}"
    setup_ns

    kubectl run compromised --image=nginx:1.25 -n "$NS" -l app=compromised --dry-run=client -o yaml | kubectl apply -f -
    echo "A 'compromised' pod is running in '${NS}'."
    echo ""
    echo "Perform incident response:"
    echo "  1. Capture pod logs to /tmp/evidence-compromised.txt"
    echo "  2. Isolate the pod with a deny-all NetworkPolicy targeting app=compromised"
    echo "  3. (Do NOT delete the pod yet — forensics first)"
    echo ""
    echo "When ready, press Enter to validate..."
    read -r

    validate \
        "test -f /tmp/evidence-compromised.txt" \
        "Evidence file exists at /tmp/evidence-compromised.txt" \
        "File at /tmp/evidence-compromised.txt"
    validate \
        "kubectl get networkpolicy -n $NS -o json | jq -e '.items[] | select(.spec.podSelector.matchLabels.app == \"compromised\")'" \
        "Isolation NetworkPolicy targets compromised pod" \
        "NetworkPolicy with podSelector app=compromised"
    validate \
        "kubectl get pod compromised -n $NS -o jsonpath='{.status.phase}' | grep -q 'Running'" \
        "Pod still running (not deleted before forensics)" \
        "Pod should still exist"
}

# ─── Main ───

case "$SCENARIO" in
    0) scenario_menu ;;
    1) scenario_1 ;;
    2) scenario_2 ;;
    3) scenario_3 ;;
    10) scenario_10 ;;
    cleanup) cleanup ;;
    *)
        echo "Scenario $SCENARIO: Coming soon. Available: 1, 2, 3, 10"
        scenario_menu
        ;;
esac
