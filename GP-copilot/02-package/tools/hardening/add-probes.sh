#!/usr/bin/env bash
# add-probes.sh
# Add liveness and readiness probes to Kubernetes Deployment manifests.
#
# Usage:
#   bash add-probes.sh <manifest.yaml> [port] [path]
#
# Error codes: Checkov CKV_K8S_8 (livenessProbe), CKV_K8S_9 (readinessProbe)
#              Kubescape C-0018 (readinessProbe)
#
# What it does:
#   - Detects if probes already exist
#   - Auto-detects common ports (8080, 3000, 5000, 80, 443) from containerPort
#   - Adds httpGet probes on /healthz (liveness) and /ready (readiness)
#   - Falls back to tcpSocket if no HTTP path is appropriate
#
# Probe defaults:
#   livenessProbe:  /healthz, initialDelaySeconds: 15, periodSeconds: 10
#   readinessProbe: /ready,   initialDelaySeconds: 5,  periodSeconds: 5

set -euo pipefail

MANIFEST="${1:-}"
PORT="${2:-}"
HEALTH_PATH="${3:-/healthz}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$MANIFEST" || ! -f "$MANIFEST" ]]; then
  echo "Usage: bash add-probes.sh <manifest.yaml> [port] [path]"
  echo ""
  echo "Examples:"
  echo "  bash add-probes.sh infrastructure/api-deployment.yaml 8080 /healthz"
  echo "  bash add-probes.sh infrastructure/ui-deployment.yaml 3000 /health"
  echo "  bash add-probes.sh infrastructure/db-deployment.yaml 5432  # tcpSocket mode"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — K8s Health Probes ===${NC}"
echo "  File : $MANIFEST"
echo ""

# Check existing probes
HAS_LIVENESS=$(grep -c 'livenessProbe:' "$MANIFEST" || true)
HAS_READINESS=$(grep -c 'readinessProbe:' "$MANIFEST" || true)

if [[ $HAS_LIVENESS -gt 0 && $HAS_READINESS -gt 0 ]]; then
  echo -e "${GREEN}Both livenessProbe and readinessProbe already present.${NC}"
  exit 0
fi

[[ $HAS_LIVENESS -gt 0 ]] && echo -e "  ${GREEN}✓ livenessProbe — present${NC}" || echo -e "  ${RED}✗ livenessProbe — MISSING${NC}"
[[ $HAS_READINESS -gt 0 ]] && echo -e "  ${GREEN}✓ readinessProbe — present${NC}" || echo -e "  ${RED}✗ readinessProbe — MISSING${NC}"
echo ""

# Auto-detect port from containerPort if not specified
if [[ -z "$PORT" ]]; then
  PORT=$(grep -oP 'containerPort:\s*\K\d+' "$MANIFEST" | head -1 || true)
  if [[ -z "$PORT" ]]; then
    PORT=8080
    echo -e "${YELLOW}No containerPort found. Defaulting to $PORT.${NC}"
  else
    echo -e "${GREEN}Auto-detected containerPort: $PORT${NC}"
  fi
fi

# Determine probe type: HTTP for web ports, TCP for database/non-HTTP ports
DB_PORTS="5432 3306 27017 6379 9200 9042 2181"
USE_TCP=false
for db_port in $DB_PORTS; do
  if [[ "$PORT" == "$db_port" ]]; then
    USE_TCP=true
    break
  fi
done

echo ""

cp "$MANIFEST" "$MANIFEST.bak"
echo -e "${YELLOW}Backup created: $MANIFEST.bak${NC}"
echo ""

if command -v yq &>/dev/null; then
  echo -e "${GREEN}yq detected — applying probes automatically.${NC}"
  echo ""

  if [[ $HAS_LIVENESS -eq 0 ]]; then
    if [[ "$USE_TCP" == "true" ]]; then
      yq -i "(.spec.template.spec.containers[0].livenessProbe) = {
        \"tcpSocket\": {\"port\": ${PORT}},
        \"initialDelaySeconds\": 15,
        \"periodSeconds\": 10,
        \"timeoutSeconds\": 5,
        \"failureThreshold\": 3
      }" "$MANIFEST"
      echo "  Added livenessProbe (tcpSocket:${PORT})"
    else
      yq -i "(.spec.template.spec.containers[0].livenessProbe) = {
        \"httpGet\": {\"path\": \"${HEALTH_PATH}\", \"port\": ${PORT}},
        \"initialDelaySeconds\": 15,
        \"periodSeconds\": 10,
        \"timeoutSeconds\": 5,
        \"failureThreshold\": 3
      }" "$MANIFEST"
      echo "  Added livenessProbe (httpGet:${HEALTH_PATH}:${PORT})"
    fi
  fi

  if [[ $HAS_READINESS -eq 0 ]]; then
    if [[ "$USE_TCP" == "true" ]]; then
      yq -i "(.spec.template.spec.containers[0].readinessProbe) = {
        \"tcpSocket\": {\"port\": ${PORT}},
        \"initialDelaySeconds\": 5,
        \"periodSeconds\": 5,
        \"timeoutSeconds\": 3,
        \"failureThreshold\": 3
      }" "$MANIFEST"
      echo "  Added readinessProbe (tcpSocket:${PORT})"
    else
      READY_PATH="/ready"
      yq -i "(.spec.template.spec.containers[0].readinessProbe) = {
        \"httpGet\": {\"path\": \"${READY_PATH}\", \"port\": ${PORT}},
        \"initialDelaySeconds\": 5,
        \"periodSeconds\": 5,
        \"timeoutSeconds\": 3,
        \"failureThreshold\": 3
      }" "$MANIFEST"
      echo "  Added readinessProbe (httpGet:${READY_PATH}:${PORT})"
    fi
  fi

  echo ""
  echo -e "${GREEN}Done. Probes applied.${NC}"
else
  echo -e "${YELLOW}yq not installed. Printing probe blocks to add manually:${NC}"
  echo ""

  if [[ $HAS_LIVENESS -eq 0 ]]; then
    echo -e "${BLUE}--- livenessProbe (add under containers[].name) ---${NC}"
    if [[ "$USE_TCP" == "true" ]]; then
      cat <<YAML
            livenessProbe:
              tcpSocket:
                port: ${PORT}
              initialDelaySeconds: 15
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 3
YAML
    else
      cat <<YAML
            livenessProbe:
              httpGet:
                path: ${HEALTH_PATH}
                port: ${PORT}
              initialDelaySeconds: 15
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 3
YAML
    fi
    echo ""
  fi

  if [[ $HAS_READINESS -eq 0 ]]; then
    echo -e "${BLUE}--- readinessProbe (add under containers[].name) ---${NC}"
    if [[ "$USE_TCP" == "true" ]]; then
      cat <<YAML
            readinessProbe:
              tcpSocket:
                port: ${PORT}
              initialDelaySeconds: 5
              periodSeconds: 5
              timeoutSeconds: 3
              failureThreshold: 3
YAML
    else
      cat <<YAML
            readinessProbe:
              httpGet:
                path: /ready
                port: ${PORT}
              initialDelaySeconds: 5
              periodSeconds: 5
              timeoutSeconds: 3
              failureThreshold: 3
YAML
    fi
    echo ""
  fi
fi

echo ""
echo -e "${YELLOW}Important:${NC}"
echo "  - Your app MUST implement ${HEALTH_PATH} and /ready endpoints"
echo "  - If it doesn't have health endpoints, use tcpSocket instead:"
echo "    bash add-probes.sh $MANIFEST $PORT  # and edit probe type"
echo ""
echo -e "${YELLOW}Probe behavior:${NC}"
echo "  livenessProbe  — Kubelet restarts container if this fails"
echo "  readinessProbe — Kubelet removes pod from Service endpoints if this fails"
echo "  startupProbe   — Use for slow-starting apps (not added by default)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Verify app has health endpoints"
echo "  2. Dry run: kubectl apply -f $MANIFEST --dry-run=client"
echo "  3. Re-scan: checkov -f $MANIFEST --check CKV_K8S_8,CKV_K8S_9"
echo "  4. Commit: git commit -m 'k8s: add liveness and readiness probes (CKV_K8S_8/9)'"
echo ""
