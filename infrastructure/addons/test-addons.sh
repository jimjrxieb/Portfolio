#!/bin/bash
# Test script to verify all infrastructure addons are running correctly
set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║      Infrastructure Addons - Health Check                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track failures
FAILURES=0

# Function to check namespace exists
check_namespace() {
    local namespace=$1
    if kubectl get namespace ${namespace} &> /dev/null; then
        echo -e "${GREEN}✅${NC} Namespace: ${namespace}"
        return 0
    else
        echo -e "${RED}❌${NC} Namespace: ${namespace} (not found)"
        ((FAILURES++))
        return 1
    fi
}

# Function to check pods are running
check_pods() {
    local namespace=$1
    local label=$2
    local name=$3

    local pods=$(kubectl get pods -n ${namespace} -l ${label} --no-headers 2>/dev/null | wc -l)
    local running=$(kubectl get pods -n ${namespace} -l ${label} --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

    if [ ${pods} -gt 0 ] && [ ${running} -eq ${pods} ]; then
        echo -e "${GREEN}✅${NC} ${name}: ${running}/${pods} pods running"
        return 0
    elif [ ${pods} -gt 0 ]; then
        echo -e "${YELLOW}⚠️${NC}  ${name}: ${running}/${pods} pods running"
        ((FAILURES++))
        return 1
    else
        echo -e "${RED}❌${NC} ${name}: No pods found"
        ((FAILURES++))
        return 1
    fi
}

# Function to check service endpoint
check_endpoint() {
    local url=$1
    local name=$2

    if curl -s -f ${url} &> /dev/null; then
        echo -e "${GREEN}✅${NC} ${name}: ${url} (reachable)"
        return 0
    else
        echo -e "${RED}❌${NC} ${name}: ${url} (unreachable)"
        ((FAILURES++))
        return 1
    fi
}

echo "🔍 Checking infrastructure addons..."
echo ""

# Check OPA Gatekeeper
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 OPA Gatekeeper"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_namespace "gatekeeper-system"
check_pods "gatekeeper-system" "control-plane=audit-controller" "Audit Controller"
check_pods "gatekeeper-system" "control-plane=controller-manager" "Controller Manager"
echo ""

# Check LocalStack
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 LocalStack"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_namespace "localstack"
check_pods "localstack" "app=localstack" "LocalStack"
check_endpoint "http://localhost:4566/_localstack/health" "LocalStack Health"
echo ""

# Check Prometheus
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Prometheus"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_namespace "monitoring"
check_pods "monitoring" "app.kubernetes.io/name=prometheus,app.kubernetes.io/component=server" "Prometheus Server"
check_pods "monitoring" "app.kubernetes.io/name=prometheus-node-exporter" "Node Exporter"
echo ""

# Check Grafana
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Grafana"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_pods "monitoring" "app.kubernetes.io/name=grafana" "Grafana"
echo ""

# Check ArgoCD
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 ArgoCD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_namespace "argocd"
check_pods "argocd" "app.kubernetes.io/name=argocd-server" "ArgoCD Server"
check_pods "argocd" "app.kubernetes.io/name=argocd-repo-server" "ArgoCD Repo Server"
check_pods "argocd" "app.kubernetes.io/name=argocd-application-controller" "ArgoCD Application Controller"
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                   HEALTH CHECK SUMMARY                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

if [ ${FAILURES} -eq 0 ]; then
    echo -e "${GREEN}🎉 All addons are healthy! (0 failures)${NC}"
    echo ""
    echo "📊 Resource Summary:"
    kubectl get pods --all-namespaces | grep -E 'gatekeeper|localstack|monitoring|argocd' | wc -l | xargs echo "   Total pods:"
    echo ""
    echo "🌐 Access URLs:"
    echo "   - LocalStack: http://localhost:4566"
    echo "   - Prometheus: kubectl port-forward -n monitoring svc/prometheus-server 9090:80"
    echo "   - Grafana: kubectl port-forward -n monitoring svc/grafana 3000:80"
    echo "   - ArgoCD: kubectl port-forward -n argocd svc/argocd-server 8080:443"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Health check failed with ${FAILURES} error(s)${NC}"
    echo ""
    echo "🔍 Troubleshooting:"
    echo "   1. Check pod status: kubectl get pods --all-namespaces"
    echo "   2. Check pod logs: kubectl logs -n <namespace> <pod-name>"
    echo "   3. Check events: kubectl get events -n <namespace> --sort-by='.lastTimestamp'"
    echo ""
    exit 1
fi
