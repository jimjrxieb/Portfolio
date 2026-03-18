#!/usr/bin/env bash
# cka-practice.sh — CKA practice scenarios with validation
# Usage: ./cka-practice.sh [scenario-number]
# Requires: kubectl access to a cluster (use a test cluster!)
set -euo pipefail

SCENARIO="${1:-0}"
NS="cka-practice"

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
║              CKA Practice Scenarios              ║
╠══════════════════════════════════════════════════╣
║  1. Deployment — Rolling update + rollback       ║
║  2. Services — Expose app, test DNS              ║
║  3. ConfigMap & Secret — Mount in pod            ║
║  4. PV + PVC — Persistent storage                ║
║  5. RBAC — Least privilege roles                 ║
║  6. Scheduling — Taints, tolerations, affinity   ║
║  7. Troubleshoot — Fix broken deployment         ║
║  8. etcd — Backup and restore                    ║
║  9. Node — Drain, cordon, uncordon               ║
║ 10. Sidecar — Log collector pattern              ║
║                                                  ║
║  0. Show this menu                               ║
║  cleanup. Remove practice namespace              ║
╚══════════════════════════════════════════════════╝
MENU
}

scenario_1() {
    echo -e "${BLUE}=== Scenario 1: Deployment Rolling Update ===${NC}"
    setup_ns

    echo "In namespace '${NS}':"
    echo "  1. Create deployment 'webapp' with image nginx:1.24, 3 replicas"
    echo "  2. Update image to nginx:1.25 (rolling update)"
    echo "  3. Verify rollout completed successfully"
    echo "  4. Rollback to previous version (nginx:1.24)"
    echo "  5. Verify rollback completed"
    echo ""
    echo "When ready, press Enter to validate..."
    read -r

    validate \
        "kubectl get deployment webapp -n $NS -o jsonpath='{.spec.replicas}' | grep -q '3'" \
        "Deployment has 3 replicas" \
        "spec.replicas = 3"
    validate \
        "kubectl get deployment webapp -n $NS -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -q 'nginx:1.24'" \
        "Image rolled back to nginx:1.24" \
        "Current image should be nginx:1.24 after rollback"
    validate \
        "kubectl rollout history deployment webapp -n $NS --revision=2 2>/dev/null | grep -q 'nginx:1.25'" \
        "Revision 2 shows nginx:1.25 in history" \
        "rollout history shows the update happened"
}

scenario_2() {
    echo -e "${BLUE}=== Scenario 2: Services & DNS ===${NC}"
    setup_ns

    kubectl create deployment backend --image=nginx:1.25 --replicas=2 -n "$NS" 2>/dev/null || true

    echo "A 'backend' deployment exists in '${NS}' with 2 replicas."
    echo ""
    echo "Tasks:"
    echo "  1. Expose 'backend' as ClusterIP service on port 80"
    echo "  2. Create a temporary pod and verify DNS resolution:"
    echo "     backend.${NS}.svc.cluster.local"
    echo "  3. Verify the service has 2 endpoints"
    echo ""
    echo "When ready, press Enter to validate..."
    read -r

    validate \
        "kubectl get svc backend -n $NS" \
        "Service 'backend' exists" \
        "Service in namespace ${NS}"
    validate \
        "kubectl get endpoints backend -n $NS -o jsonpath='{.subsets[0].addresses}' | jq -e 'length >= 2'" \
        "Service has >= 2 endpoints" \
        "Endpoints should match replica count"
}

scenario_4() {
    echo -e "${BLUE}=== Scenario 4: PV + PVC ===${NC}"
    setup_ns

    echo "Tasks:"
    echo "  1. Create PersistentVolume 'pv-data' with:"
    echo "     - 1Gi capacity, ReadWriteOnce, hostPath /tmp/pv-data"
    echo "     - storageClassName: manual"
    echo "  2. Create PersistentVolumeClaim 'pvc-data' in '${NS}' with:"
    echo "     - 500Mi request, ReadWriteOnce, storageClassName: manual"
    echo "  3. Create pod 'storage-pod' using the PVC mounted at /data"
    echo ""
    echo "When ready, press Enter to validate..."
    read -r

    validate \
        "kubectl get pv pv-data -o jsonpath='{.spec.capacity.storage}' | grep -q '1Gi'" \
        "PV pv-data has 1Gi capacity" \
        "spec.capacity.storage = 1Gi"
    validate \
        "kubectl get pvc pvc-data -n $NS -o jsonpath='{.status.phase}' | grep -q 'Bound'" \
        "PVC is Bound" \
        "PVC status.phase = Bound"
    validate \
        "kubectl get pod storage-pod -n $NS -o jsonpath='{.spec.volumes[0].persistentVolumeClaim.claimName}' | grep -q 'pvc-data'" \
        "Pod uses pvc-data" \
        "Pod volume references pvc-data"
}

scenario_7() {
    echo -e "${BLUE}=== Scenario 7: Troubleshoot Broken Deployment ===${NC}"
    setup_ns

    # Create intentionally broken deployment
    kubectl apply -n "$NS" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: broken-app
  template:
    metadata:
      labels:
        app: broken-app
    spec:
      containers:
      - name: app
        image: nginx:doesnotexist999
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: 100m
            memory: 64Mi
---
apiVersion: v1
kind: Service
metadata:
  name: broken-app
spec:
  selector:
    app: wrong-label
  ports:
  - port: 80
    targetPort: 80
EOF

    echo "A broken deployment 'broken-app' has been created in '${NS}'."
    echo "There are TWO issues:"
    echo "  1. Pods are not starting (check image)"
    echo "  2. Service has no endpoints (check selector)"
    echo ""
    echo "Fix both issues. When ready, press Enter to validate..."
    read -r

    validate \
        "kubectl get pods -n $NS -l app=broken-app --no-headers | grep -q 'Running'" \
        "Pods are Running" \
        "At least one pod in Running state"
    validate \
        "kubectl get endpoints broken-app -n $NS -o jsonpath='{.subsets[0].addresses}' | jq -e 'length >= 1'" \
        "Service has endpoints" \
        "Service selector matches pod labels"
}

# ─── Main ───

case "$SCENARIO" in
    0) scenario_menu ;;
    1) scenario_1 ;;
    2) scenario_2 ;;
    4) scenario_4 ;;
    7) scenario_7 ;;
    cleanup) cleanup ;;
    *)
        echo "Scenario $SCENARIO: Coming soon. Available: 1, 2, 4, 7"
        scenario_menu
        ;;
esac
