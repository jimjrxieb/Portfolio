#!/usr/bin/env bash
# ============================================================================
# Node-Level Hardening — CIS Kubernetes Benchmark (Node Controls)
#
# This runs BEFORE any Kubernetes policies are applied.
# It hardens the OS underneath the cluster: sysctl, auditd, kubelet config.
#
# Execution order inside 02-CLUSTER-HARDENING:
#   1. harden-nodes.sh        ← YOU ARE HERE (Ansible — OS layer)
#   2. run-cluster-audit.sh   ← then audit the cluster (kubectl)
#   3. deploy-policies.sh     ← then enforce policies (Kyverno/Gatekeeper)
#
# Usage:
#   bash harden-nodes.sh                        # Run all playbooks
#   bash harden-nodes.sh --check                # Dry-run (audit only, no changes)
#   bash harden-nodes.sh --tags cis             # Only CIS sysctl hardening
#   bash harden-nodes.sh --tags auditd          # Only auditd configuration
#   bash harden-nodes.sh --tags kubelet         # Only kubelet hardening
#   bash harden-nodes.sh --inventory custom.ini # Custom inventory file
#
# Prerequisites:
#   - Ansible installed on your rig (pip install ansible)
#   - SSH access to cluster nodes (key-based auth)
#   - sudo/root on target nodes
#   - Inventory file configured (inventory/eks-nodes.ini)
#
# NIST 800-53 Controls:
#   CM-6   Configuration Settings (sysctl, kernel params)
#   AU-2   Event Logging (auditd rules for k8s)
#   AC-6   Least Privilege (kubelet auth, read-only port)
#   SC-7   Boundary Protection (IP forwarding, ICMP)
#   SI-6   Security and Privacy Function Verification
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${SCRIPT_DIR}/inventory/eks-nodes.ini"
EXTRA_ARGS=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --check)
            EXTRA_ARGS="${EXTRA_ARGS} --check --diff"
            echo "[DRY RUN] Audit mode — no changes will be made"
            shift
            ;;
        --tags)
            EXTRA_ARGS="${EXTRA_ARGS} --tags $2"
            shift 2
            ;;
        --inventory)
            INVENTORY="$2"
            shift 2
            ;;
        --limit)
            EXTRA_ARGS="${EXTRA_ARGS} --limit $2"
            shift 2
            ;;
        --ask-become-pass|-K)
            EXTRA_ARGS="${EXTRA_ARGS} --ask-become-pass"
            shift
            ;;
        -v|-vv|-vvv)
            EXTRA_ARGS="${EXTRA_ARGS} $1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Verify prerequisites
if ! command -v ansible-playbook &>/dev/null; then
    echo "ERROR: ansible-playbook not found. Install with: pip install ansible"
    exit 1
fi

if [[ ! -f "${INVENTORY}" ]]; then
    echo "ERROR: Inventory file not found: ${INVENTORY}"
    echo "Copy inventory/eks-nodes.ini.example to inventory/eks-nodes.ini and configure your nodes."
    exit 1
fi

echo "============================================"
echo "  Node-Level Hardening — CIS K8s Benchmark  "
echo "============================================"
echo "Inventory:  ${INVENTORY}"
echo "Playbooks:  $(dirname "${SCRIPT_DIR}")/playbooks/ansible/"
echo "Extra args: ${EXTRA_ARGS:-none}"
echo ""

# Phase 1: CIS node-level hardening (sysctl, kernel modules, file permissions)
echo "--- Phase 1: CIS Node Hardening (sysctl, kernel, filesystem) ---"
ansible-playbook \
    -i "${INVENTORY}" \
    "$(dirname "${SCRIPT_DIR}")/playbooks/ansible/cis-node-hardening.yml" \
    ${EXTRA_ARGS}

# Phase 2: Auditd configuration (kubernetes-specific audit rules)
echo ""
echo "--- Phase 2: Auditd Configuration (K8s audit rules) ---"
ansible-playbook \
    -i "${INVENTORY}" \
    "$(dirname "${SCRIPT_DIR}")/playbooks/ansible/auditd-config.yml" \
    ${EXTRA_ARGS}

# Phase 3: Kubelet hardening (authentication, authorization, read-only port)
echo ""
echo "--- Phase 3: Kubelet Hardening (auth, authorization, ports) ---"
ansible-playbook \
    -i "${INVENTORY}" \
    "$(dirname "${SCRIPT_DIR}")/playbooks/ansible/kubelet-hardening.yml" \
    ${EXTRA_ARGS}

echo ""
echo "============================================"
echo "  Node hardening complete.                   "
echo "                                              "
echo "  Next steps:                                 "
echo "  1. Verify: bash harden-nodes.sh --check     "
echo "  2. Audit:  bash ../tools/hardening/run-cluster-audit.sh"
echo "  3. Policy: bash ../tools/admission/deploy-policies.sh  "
echo "============================================"
