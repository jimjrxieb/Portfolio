#!/usr/bin/env bash
# ckad-practice.sh — CKAD practice scenarios with validation
# Usage: ./ckad-practice.sh [scenario-number]
# Requires: kubectl access to a cluster (use a test cluster!)
set -euo pipefail

SCENARIO="${1:-0}"
NS="ckad-practice"

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
╔══════════════════════════════════════════════════════╗
║               CKAD Practice Scenarios                ║
╠══════════════════════════════════════════════════════╣
║  1. Multi-container — Init + sidecar pod             ║
║  2. Jobs — Parallel batch processing                 ║
║  3. ConfigMap & Secret — Mount in pod                ║
║  4. Rolling update — Deploy, update, rollback        ║
║  5. Services — Expose app, verify DNS                ║
║  6. Ingress — Path-based routing                     ║
║  7. NetworkPolicy — Restrict pod traffic             ║
║  8. Probes — Liveness + readiness                    ║
║  9. Resource limits — Requests, limits, quota        ║
║ 10. Kustomize — Base + overlay deployment            ║
║                                                      ║
║  0. Show this menu                                   ║
║  cleanup. Remove practice namespace                  ║
╚══════════════════════════════════════════════════════╝
MENU
}

scenario_1() {
    echo -e "${BLUE}=== Scenario 1: Multi-Container Pod ===${NC}"
    setup_ns

    echo "Create a pod named 'multi-pod' in namespace '${NS}' with:"
    echo "  1. Init container: busybox, command: 'echo initializing > /work/status'"
    echo "  2. Main container: nginx:1.25, mounts /work"
    echo "  3. Sidecar container: busybox, command: 'tail -f /work/status'"
    echo "  4. All containers share an emptyDir volume at /work"
    echo ""
    echo "When ready, press Enter to validate..."
    read -r

    validate \
        "kubectl get pod multi-pod -n $NS -o jsonpath='{.spec.initContainers[0].name}' | grep -q ." \
        "Init container exists" \
        "Pod has at least one init container"
    validate \
        "kubectl get pod multi-pod -n $NS -o jsonpath='{.spec.containers}' | jq -e 'length >= 2'" \
        "At least 2 main containers (app + sidecar)" \
        "spec.containers has >= 2 entries"
    validate \
        "kubectl get pod multi-pod -n $NS -o jsonpath='{.spec.volumes[0].emptyDir}' | grep -q ." \
        "Shared emptyDir volume exists" \
        "spec.volumes contains emptyDir"
}

scenario_2() {
    echo -e "${BLUE}=== Scenario 2: Jobs ===${NC}"
    setup_ns

    echo "Create a Job named 'batch-job' in namespace '${NS}' with:"
    echo "  - Image: busybox"
    echo "  - Command: 'echo processing item \$RANDOM && sleep 2'"
    echo "  - completions: 6"
    echo "  - parallelism: 3"
    echo "  - backoffLimit: 2"
    echo "  - restartPolicy: Never"
    echo ""
    echo "When ready, press Enter to validate..."
    read -r

    validate \
        "kubectl get job batch-job -n $NS" \
        "Job batch-job exists" \
        "Job in namespace ${NS}"
    validate \
        "kubectl get job batch-job -n $NS -o jsonpath='{.spec.completions}' | grep -q '6'" \
        "completions: 6" \
        "spec.completions = 6"
    validate \
        "kubectl get job batch-job -n $NS -o jsonpath='{.spec.parallelism}' | grep -q '3'" \
        "parallelism: 3" \
        "spec.parallelism = 3"
}

scenario_3() {
    echo -e "${BLUE}=== Scenario 3: ConfigMap & Secret ===${NC}"
    setup_ns

    echo "In namespace '${NS}':"
    echo "  1. Create ConfigMap 'app-config' with: APP_ENV=production, LOG_LEVEL=warn"
    echo "  2. Create Secret 'db-creds' with: DB_USER=admin, DB_PASS=s3cret"
    echo "  3. Create pod 'config-pod' (image: nginx:1.25) that:"
    echo "     - Loads ALL ConfigMap keys as env vars (envFrom)"
    echo "     - Mounts Secret as volume at /etc/secrets (readOnly)"
    echo ""
    echo "When ready, press Enter to validate..."
    read -r

    validate \
        "kubectl get configmap app-config -n $NS -o jsonpath='{.data.APP_ENV}' | grep -q 'production'" \
        "ConfigMap has APP_ENV=production" \
        "ConfigMap data.APP_ENV = production"
    validate \
        "kubectl get secret db-creds -n $NS" \
        "Secret db-creds exists" \
        "Secret in namespace ${NS}"
    validate \
        "kubectl get pod config-pod -n $NS -o json | jq -e '.spec.containers[0].envFrom[] | select(.configMapRef.name==\"app-config\")'" \
        "Pod loads ConfigMap via envFrom" \
        "Container has envFrom with configMapRef"
    validate \
        "kubectl get pod config-pod -n $NS -o json | jq -e '.spec.volumes[] | select(.secret.secretName==\"db-creds\")'" \
        "Pod mounts Secret as volume" \
        "Volume references secret db-creds"
}

scenario_4() {
    echo -e "${BLUE}=== Scenario 4: Rolling Update & Rollback ===${NC}"
    setup_ns

    echo "In namespace '${NS}':"
    echo "  1. Create deployment 'webapp' with nginx:1.24, 4 replicas"
    echo "  2. Set strategy: maxSurge=1, maxUnavailable=0"
    echo "  3. Update image to nginx:1.25"
    echo "  4. Verify rollout completed"
    echo "  5. Rollback to nginx:1.24"
    echo ""
    echo "When ready, press Enter to validate..."
    read -r

    validate \
        "kubectl get deployment webapp -n $NS -o jsonpath='{.spec.replicas}' | grep -q '4'" \
        "4 replicas" \
        "spec.replicas = 4"
    validate \
        "kubectl get deployment webapp -n $NS -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -q 'nginx:1.24'" \
        "Image rolled back to nginx:1.24" \
        "Current image = nginx:1.24"
    validate \
        "kubectl get deployment webapp -n $NS -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' | grep -q '0'" \
        "maxUnavailable: 0" \
        "spec.strategy.rollingUpdate.maxUnavailable = 0"
}

scenario_5() {
    echo -e "${BLUE}=== Scenario 5: Services ===${NC}"
    setup_ns

    kubectl create deployment backend --image=nginx:1.25 --replicas=2 -n "$NS" 2>/dev/null || true
    kubectl create deployment frontend --image=nginx:1.25 --replicas=2 -n "$NS" 2>/dev/null || true

    echo "Deployments 'backend' (2 replicas) and 'frontend' (2 replicas) exist in '${NS}'."
    echo ""
    echo "Tasks:"
    echo "  1. Expose 'backend' as ClusterIP on port 80 -> targetPort 80"
    echo "  2. Expose 'frontend' as NodePort on port 80 -> targetPort 80"
    echo "  3. Verify backend service has 2 endpoints"
    echo ""
    echo "When ready, press Enter to validate..."
    read -r

    validate \
        "kubectl get svc backend -n $NS -o jsonpath='{.spec.type}' | grep -q 'ClusterIP'" \
        "backend service is ClusterIP" \
        "Service type = ClusterIP"
    validate \
        "kubectl get svc frontend -n $NS -o jsonpath='{.spec.type}' | grep -q 'NodePort'" \
        "frontend service is NodePort" \
        "Service type = NodePort"
    validate \
        "kubectl get endpoints backend -n $NS -o jsonpath='{.subsets[0].addresses}' | jq -e 'length >= 2'" \
        "backend has >= 2 endpoints" \
        "Endpoints match replica count"
}

scenario_8() {
    echo -e "${BLUE}=== Scenario 8: Probes ===${NC}"
    setup_ns

    echo "Create a deployment 'probed-app' in namespace '${NS}' with:"
    echo "  - Image: nginx:1.25, 2 replicas"
    echo "  - Liveness probe: HTTP GET /healthz on port 80, period 10s"
    echo "  - Readiness probe: HTTP GET / on port 80, initialDelay 5s"
    echo "  - Startup probe: HTTP GET / on port 80, failureThreshold 30"
    echo ""
    echo "When ready, press Enter to validate..."
    read -r

    validate \
        "kubectl get deployment probed-app -n $NS -o json | jq -e '.spec.template.spec.containers[0].livenessProbe.httpGet'" \
        "Liveness probe configured (httpGet)" \
        "Container has livenessProbe.httpGet"
    validate \
        "kubectl get deployment probed-app -n $NS -o json | jq -e '.spec.template.spec.containers[0].readinessProbe.httpGet'" \
        "Readiness probe configured (httpGet)" \
        "Container has readinessProbe.httpGet"
    validate \
        "kubectl get deployment probed-app -n $NS -o json | jq -e '.spec.template.spec.containers[0].startupProbe'" \
        "Startup probe configured" \
        "Container has startupProbe"
}

scenario_9() {
    echo -e "${BLUE}=== Scenario 9: Resource Limits & Quota ===${NC}"
    setup_ns

    echo "In namespace '${NS}':"
    echo "  1. Create a ResourceQuota 'team-quota' with:"
    echo "     - requests.cpu: 2, requests.memory: 2Gi"
    echo "     - limits.cpu: 4, limits.memory: 4Gi"
    echo "     - pods: 10"
    echo "  2. Create a LimitRange 'defaults' with:"
    echo "     - default cpu: 200m, memory: 256Mi"
    echo "     - defaultRequest cpu: 100m, memory: 128Mi"
    echo "  3. Create deployment 'limited-app' (nginx:1.25, 2 replicas)"
    echo "     WITHOUT specifying resources — verify LimitRange defaults applied"
    echo ""
    echo "When ready, press Enter to validate..."
    read -r

    validate \
        "kubectl get resourcequota team-quota -n $NS -o jsonpath='{.spec.hard.pods}' | grep -q '10'" \
        "ResourceQuota pods: 10" \
        "spec.hard.pods = 10"
    validate \
        "kubectl get limitrange defaults -n $NS" \
        "LimitRange 'defaults' exists" \
        "LimitRange in namespace ${NS}"
    validate \
        "kubectl get pods -n $NS -l app=limited-app -o json | jq -e '.items[0].spec.containers[0].resources.limits.cpu'" \
        "LimitRange defaults applied to pod" \
        "Pod should have resource limits from LimitRange defaults"
}

# ─── Main ───

case "$SCENARIO" in
    0) scenario_menu ;;
    1) scenario_1 ;;
    2) scenario_2 ;;
    3) scenario_3 ;;
    4) scenario_4 ;;
    5) scenario_5 ;;
    8) scenario_8 ;;
    9) scenario_9 ;;
    cleanup) cleanup ;;
    *)
        echo "Scenario $SCENARIO: Coming soon. Available: 1, 2, 3, 4, 5, 8, 9"
        scenario_menu
        ;;
esac
