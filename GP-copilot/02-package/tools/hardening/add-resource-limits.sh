#!/usr/bin/env bash
# add-resource-limits.sh
# Add resource requests and limits to a Kubernetes Deployment manifest.
#
# Usage:
#   bash add-resource-limits.sh <manifest.yaml> [cpu-request] [cpu-limit] [mem-request] [mem-limit]
#
# Error codes: Checkov CKV_K8S_11, CKV_K8S_12, CKV_K8S_13 | Trivy KSV011, KSV016
#
# Defaults: 250m/500m CPU, 256Mi/512Mi memory

set -euo pipefail

MANIFEST="${1:-}"
CPU_REQ="${2:-250m}"
CPU_LIM="${3:-500m}"
MEM_REQ="${4:-256Mi}"
MEM_LIM="${5:-512Mi}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$MANIFEST" || ! -f "$MANIFEST" ]]; then
  echo "Usage: bash add-resource-limits.sh <manifest.yaml> [cpu-req] [cpu-lim] [mem-req] [mem-lim]"
  echo ""
  echo "Defaults: 250m/500m CPU | 256Mi/512Mi memory"
  echo ""
  echo "Examples:"
  echo "  bash add-resource-limits.sh infrastructure/api-deployment.yaml"
  echo "  bash add-resource-limits.sh infrastructure/db-deployment.yaml 500m 1000m 512Mi 1Gi"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — K8s Resource Limits ===${NC}"
echo "  File        : $MANIFEST"
echo "  CPU         : request=$CPU_REQ limit=$CPU_LIM"
echo "  Memory      : request=$MEM_REQ limit=$MEM_LIM"
echo ""

HAS_LIMITS=$(grep -c "limits:" "$MANIFEST" || true)
HAS_REQUESTS=$(grep -c "requests:" "$MANIFEST" || true)

if [[ $HAS_LIMITS -gt 0 && $HAS_REQUESTS -gt 0 ]]; then
  echo -e "${GREEN}Resource limits and requests already present in $MANIFEST.${NC}"
  echo "Current values:"
  grep -A6 "resources:" "$MANIFEST" || true
  exit 0
fi

[[ $HAS_LIMITS -eq 0 ]] && echo -e "  ${RED}✗ limits — MISSING${NC}"
[[ $HAS_REQUESTS -eq 0 ]] && echo -e "  ${RED}✗ requests — MISSING${NC}"
echo ""

cp "$MANIFEST" "$MANIFEST.bak"
echo -e "${YELLOW}Backup created: $MANIFEST.bak${NC}"
echo ""

echo -e "${GREEN}Add the following under each container spec:${NC}"
echo ""
cat <<YAML
          resources:
            requests:
              cpu: "${CPU_REQ}"
              memory: "${MEM_REQ}"
            limits:
              cpu: "${CPU_LIM}"
              memory: "${MEM_LIM}"
YAML
echo ""

echo -e "${BLUE}Placement guide:${NC}"
cat <<'GUIDE'
  containers:
    - name: app
      image: app:v1.0.0
      ports:
        - containerPort: 8080
      resources:          ← ADD HERE (same indentation level as ports/image)
        requests:
          cpu: "250m"
          memory: "256Mi"
        limits:
          cpu: "500m"
          memory: "512Mi"
GUIDE
echo ""

if command -v yq &>/dev/null; then
  echo -e "${YELLOW}yq detected. Applying resource limits to first container...${NC}"
  echo ""
  # Apply to first container only — multi-container deployments need manual review
  yq -i ".spec.template.spec.containers[0].resources.requests.cpu = \"${CPU_REQ}\"" "$MANIFEST"
  yq -i ".spec.template.spec.containers[0].resources.requests.memory = \"${MEM_REQ}\"" "$MANIFEST"
  yq -i ".spec.template.spec.containers[0].resources.limits.cpu = \"${CPU_LIM}\"" "$MANIFEST"
  yq -i ".spec.template.spec.containers[0].resources.limits.memory = \"${MEM_LIM}\"" "$MANIFEST"
  echo -e "${GREEN}Resource limits applied to containers[0].${NC}"
  echo -e "${YELLOW}If you have multiple containers, apply to each manually.${NC}"
else
  echo -e "${YELLOW}yq not installed — manual application required.${NC}"
  echo "  Install: brew install yq  OR  snap install yq"
fi

echo ""
echo -e "${YELLOW}Sizing guide:${NC}"
echo "  Small API/frontend  : cpu 100m/250m  | memory 128Mi/256Mi"
echo "  Medium API          : cpu 250m/500m  | memory 256Mi/512Mi"
echo "  Large API           : cpu 500m/1000m | memory 512Mi/1Gi"
echo "  Database (Postgres) : cpu 500m/1000m | memory 512Mi/1Gi"
echo "  Cache (Redis)       : cpu 100m/250m  | memory 256Mi/512Mi"
echo ""
echo "  Profile actual usage with: kubectl top pods -n <namespace>"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Adjust values based on actual app profiling"
echo "  2. Test: kubectl apply -f $MANIFEST --dry-run=client"
echo "  3. Re-scan: checkov -f $MANIFEST --check CKV_K8S_11,CKV_K8S_12,CKV_K8S_13"
echo "  4. Commit: git commit -m 'security: add resource limits to deployment (CKV_K8S_11)'"
echo ""
