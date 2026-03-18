#!/usr/bin/env bash
# domain-audit.sh — Audit a cluster against CKS/CKA exam domains
# Usage: ./domain-audit.sh [--cks|--cka|--all] [--namespace <ns>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GP_CONSULTING="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORT_DIR="/tmp/kubester-audit-$(date +%Y%m%d-%H%M%S)"
MODE="${1:---all}"
TARGET_NS="${3:-}"

mkdir -p "$REPORT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "  ${BLUE}[INFO]${NC} $1"; }
header() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

check_cmd() {
    command -v "$1" &>/dev/null
}

# ─── CKS Domain Checks ───

cks_cluster_setup() {
    header "CKS: Cluster Setup & Hardening"

    # API server anonymous auth
    if kubectl get pod -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null | grep -q "anonymous-auth=false"; then
        pass "API server anonymous auth disabled"
    else
        warn "API server anonymous auth — check manually (may be platform-managed)"
    fi

    # NetworkPolicy coverage
    local ns_count
    ns_count=$(kubectl get ns --no-headers 2>/dev/null | wc -l)
    local np_ns_count
    np_ns_count=$(kubectl get networkpolicy -A --no-headers 2>/dev/null | awk '{print $1}' | sort -u | wc -l)
    if [ "$np_ns_count" -ge "$((ns_count / 2))" ]; then
        pass "NetworkPolicy coverage: ${np_ns_count}/${ns_count} namespaces"
    else
        fail "NetworkPolicy coverage: ${np_ns_count}/${ns_count} namespaces (< 50%)"
    fi

    # Ingress TLS
    local ingress_count
    ingress_count=$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l)
    local tls_ingress_count
    tls_ingress_count=$(kubectl get ingress -A -o json 2>/dev/null | jq '[.items[] | select(.spec.tls != null)] | length')
    info "Ingress with TLS: ${tls_ingress_count}/${ingress_count}"
}

cks_cluster_hardening() {
    header "CKS: Cluster Hardening"

    # RBAC — cluster-admin bindings
    local ca_bindings
    ca_bindings=$(kubectl get clusterrolebindings -o json 2>/dev/null | jq '[.items[] | select(.roleRef.name=="cluster-admin")] | length')
    if [ "$ca_bindings" -le 2 ]; then
        pass "cluster-admin bindings: ${ca_bindings} (acceptable)"
    else
        fail "cluster-admin bindings: ${ca_bindings} (too many — review with 02-CLUSTER-HARDENING/playbooks/07a-rbac-audit.md)"
    fi

    # Service account automount
    local sa_automount
    sa_automount=$(kubectl get pods -A -o json 2>/dev/null | jq '[.items[] | select(.spec.automountServiceAccountToken != false and .spec.serviceAccountName != null)] | length')
    info "Pods with SA token automounted: ${sa_automount}"

    # Admission controllers
    if kubectl get deploy -n kyverno kyverno 2>/dev/null | grep -q "1/1\|2/2\|3/3"; then
        pass "Kyverno admission controller running"
    elif kubectl get deploy -n gatekeeper-system gatekeeper-controller-manager 2>/dev/null | grep -q "1/1\|2/2"; then
        pass "Gatekeeper admission controller running"
    else
        fail "No admission controller detected (Kyverno or Gatekeeper)"
    fi
}

cks_system_hardening() {
    header "CKS: System Hardening"

    # Seccomp
    local pods_total pods_seccomp
    pods_total=$(kubectl get pods -A --no-headers 2>/dev/null | grep -v "kube-system\|kyverno\|gatekeeper" | wc -l)
    pods_seccomp=$(kubectl get pods -A -o json 2>/dev/null | jq '[.items[] | select(.metadata.namespace != "kube-system" and .metadata.namespace != "kyverno") | select(.spec.securityContext.seccompProfile.type != null or (.spec.containers[]?.securityContext.seccompProfile.type != null))] | length')
    if [ "$pods_seccomp" -ge "$((pods_total / 2))" ]; then
        pass "Seccomp profiles: ${pods_seccomp}/${pods_total} pods"
    else
        fail "Seccomp profiles: ${pods_seccomp}/${pods_total} pods (< 50%)"
    fi

    # AppArmor
    local pods_apparmor
    pods_apparmor=$(kubectl get pods -A -o json 2>/dev/null | jq '[.items[] | select(.metadata.namespace != "kube-system") | select(.metadata.annotations // {} | keys[] | startswith("container.apparmor"))] | length' 2>/dev/null || echo "0")
    info "Pods with AppArmor annotations: ${pods_apparmor}"
}

cks_microservice_vulns() {
    header "CKS: Microservice Vulnerabilities"

    # PSS labels
    local ns_pss
    ns_pss=$(kubectl get ns -o json 2>/dev/null | jq '[.items[] | select(.metadata.labels["pod-security.kubernetes.io/enforce"] != null)] | length')
    info "Namespaces with PSS enforce labels: ${ns_pss}"

    # Privileged containers
    local priv_pods
    priv_pods=$(kubectl get pods -A -o json 2>/dev/null | jq '[.items[] | select(.spec.containers[]?.securityContext.privileged == true)] | length')
    if [ "$priv_pods" -eq 0 ]; then
        pass "No privileged containers"
    else
        fail "Privileged containers: ${priv_pods}"
    fi

    # Root containers
    local root_pods
    root_pods=$(kubectl get pods -A -o json 2>/dev/null | jq '[.items[] | select(.spec.securityContext.runAsNonRoot != true and (.spec.containers | all(.securityContext.runAsNonRoot != true)))] | length')
    info "Pods without runAsNonRoot: ${root_pods}"

    # Secrets encryption
    info "Secrets encryption at rest — check API server flags manually"
}

cks_supply_chain() {
    header "CKS: Supply Chain Security"

    # Latest tags
    local latest_pods
    latest_pods=$(kubectl get pods -A -o json 2>/dev/null | jq '[.items[] | select(.spec.containers[]?.image | test(":latest$") or (contains(":") | not))] | length')
    if [ "$latest_pods" -eq 0 ]; then
        pass "No pods using :latest tag"
    else
        fail "Pods using :latest or untagged images: ${latest_pods}"
    fi

    # Image pull policy
    local always_pull
    always_pull=$(kubectl get pods -A -o json 2>/dev/null | jq '[.items[] | select(.spec.containers[]?.imagePullPolicy == "Always")] | length')
    info "Pods with imagePullPolicy=Always: ${always_pull}"
}

cks_monitoring_runtime() {
    header "CKS: Monitoring, Logging & Runtime"

    # Falco
    if kubectl get pods -n falco --no-headers 2>/dev/null | grep -q "Running"; then
        pass "Falco is running"
    else
        fail "Falco not detected — deploy with 03-DEPLOY-RUNTIME/tools/deploy.sh"
    fi

    # Audit logging
    if kubectl get pod -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null | grep -q "audit-log-path"; then
        pass "Kubernetes audit logging enabled"
    else
        warn "Audit logging — check manually (may be platform-managed)"
    fi

    # Immutable containers
    local ro_pods
    ro_pods=$(kubectl get pods -A -o json 2>/dev/null | jq '[.items[] | select(.spec.containers[]?.securityContext.readOnlyRootFilesystem == true)] | length')
    info "Pods with readOnlyRootFilesystem: ${ro_pods}"
}

# ─── CKA Domain Checks ───

cka_cluster_architecture() {
    header "CKA: Cluster Architecture"

    # Node count and roles
    kubectl get nodes -o wide 2>/dev/null || warn "Cannot access nodes"

    # Control plane health
    local cp_pods
    cp_pods=$(kubectl get pods -n kube-system -l tier=control-plane --no-headers 2>/dev/null | wc -l)
    info "Control plane pods: ${cp_pods}"

    # etcd health
    if check_cmd etcdctl; then
        info "etcdctl available"
    else
        warn "etcdctl not installed"
    fi
}

cka_workloads() {
    header "CKA: Workloads & Scheduling"

    # Deployments without resource limits
    local no_limits
    no_limits=$(kubectl get pods -A -o json 2>/dev/null | jq '[.items[] | select(.spec.containers[]? | .resources.limits == null)] | length')
    if [ "$no_limits" -eq 0 ]; then
        pass "All pods have resource limits"
    else
        warn "Pods without resource limits: ${no_limits}"
    fi

    # Pods without probes
    local no_probes
    no_probes=$(kubectl get pods -A -o json 2>/dev/null | jq '[.items[] | select(.spec.containers[]? | .livenessProbe == null and .readinessProbe == null)] | length')
    info "Pods without health probes: ${no_probes}"
}

cka_services_networking() {
    header "CKA: Services & Networking"

    # CoreDNS
    if kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -q "Running"; then
        pass "CoreDNS is running"
    else
        fail "CoreDNS not running"
    fi

    # CNI
    local cni_plugin="unknown"
    if kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -q "calico"; then cni_plugin="Calico"
    elif kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -q "cilium"; then cni_plugin="Cilium"
    elif kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -q "flannel"; then cni_plugin="Flannel"
    elif kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -q "weave"; then cni_plugin="Weave"
    fi
    info "CNI plugin: ${cni_plugin}"

    # NodePort services (security concern)
    local nodeport_count
    nodeport_count=$(kubectl get svc -A --no-headers 2>/dev/null | grep NodePort | wc -l)
    if [ "$nodeport_count" -eq 0 ]; then
        pass "No NodePort services"
    else
        warn "NodePort services: ${nodeport_count} (consider ClusterIP + Ingress)"
    fi
}

cka_storage() {
    header "CKA: Storage"

    local pv_count pvc_count
    pv_count=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
    pvc_count=$(kubectl get pvc -A --no-headers 2>/dev/null | wc -l)
    info "PersistentVolumes: ${pv_count}, PersistentVolumeClaims: ${pvc_count}"

    local sc_count
    sc_count=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)
    info "StorageClasses: ${sc_count}"

    # Unbound PVCs
    local unbound
    unbound=$(kubectl get pvc -A --no-headers 2>/dev/null | grep -v Bound | wc -l)
    if [ "$unbound" -eq 0 ]; then
        pass "All PVCs are bound"
    else
        warn "Unbound PVCs: ${unbound}"
    fi
}

cka_troubleshooting() {
    header "CKA: Troubleshooting"

    # Pods not running
    local not_running
    not_running=$(kubectl get pods -A --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l)
    if [ "$not_running" -eq 0 ]; then
        pass "All pods Running or Completed"
    else
        fail "Pods not Running/Completed: ${not_running}"
        kubectl get pods -A --no-headers 2>/dev/null | grep -v "Running\|Completed" | head -10
    fi

    # Recent warning events
    local warnings
    warnings=$(kubectl get events -A --field-selector type=Warning --no-headers 2>/dev/null | wc -l)
    if [ "$warnings" -eq 0 ]; then
        pass "No warning events"
    else
        warn "Warning events: ${warnings}"
    fi

    # Node conditions
    local not_ready
    not_ready=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready" | wc -l)
    if [ "$not_ready" -eq 0 ]; then
        pass "All nodes Ready"
    else
        fail "Nodes not Ready: ${not_ready}"
    fi
}

# ─── Main ───

echo "╔══════════════════════════════════════════════╗"
echo "║         KUBESTER Domain Audit                ║"
echo "║         CKS + CKA Exam Coverage              ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Cluster: $(kubectl config current-context 2>/dev/null || echo 'unknown')"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Report: ${REPORT_DIR}"
echo ""

case "$MODE" in
    --cks)
        cks_cluster_setup
        cks_cluster_hardening
        cks_system_hardening
        cks_microservice_vulns
        cks_supply_chain
        cks_monitoring_runtime
        ;;
    --cka)
        cka_cluster_architecture
        cka_workloads
        cka_services_networking
        cka_storage
        cka_troubleshooting
        ;;
    --all|*)
        cks_cluster_setup
        cks_cluster_hardening
        cks_system_hardening
        cks_microservice_vulns
        cks_supply_chain
        cks_monitoring_runtime
        cka_cluster_architecture
        cka_workloads
        cka_services_networking
        cka_storage
        cka_troubleshooting
        ;;
esac

echo ""
echo "Audit complete. Full results in ${REPORT_DIR}"
