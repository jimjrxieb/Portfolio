#!/usr/bin/env bash
# Quick Reference: etcd Backup & Restore
# CKA Domains: Cluster Architecture
set -euo pipefail

ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"
ENDPOINTS="https://127.0.0.1:2379"

# ── Backup ──
backup() {
    local BACKUP_FILE="${1:-/tmp/etcd-backup-$(date +%Y%m%d-%H%M%S).db}"
    ETCDCTL_API=3 etcdctl snapshot save "$BACKUP_FILE" \
        --endpoints="$ENDPOINTS" \
        --cacert="$ETCD_CACERT" \
        --cert="$ETCD_CERT" \
        --key="$ETCD_KEY"

    echo "Backup saved to: $BACKUP_FILE"
    ETCDCTL_API=3 etcdctl snapshot status "$BACKUP_FILE" --write-table
}

# ── Restore ──
restore() {
    local BACKUP_FILE="${1:?Usage: restore <backup-file>}"
    local RESTORE_DIR="/var/lib/etcd-restored"

    ETCDCTL_API=3 etcdctl snapshot restore "$BACKUP_FILE" \
        --data-dir="$RESTORE_DIR"

    echo "Restored to: $RESTORE_DIR"
    echo ""
    echo "Next steps:"
    echo "  1. Edit /etc/kubernetes/manifests/etcd.yaml"
    echo "  2. Change --data-dir to $RESTORE_DIR"
    echo "  3. Update volume hostPath to $RESTORE_DIR"
    echo "  4. Wait for etcd to restart (kubelet watches manifests)"
}

# ── Health ──
health() {
    ETCDCTL_API=3 etcdctl endpoint health \
        --endpoints="$ENDPOINTS" \
        --cacert="$ETCD_CACERT" \
        --cert="$ETCD_CERT" \
        --key="$ETCD_KEY"
}

case "${1:-help}" in
    backup)  backup "${2:-}" ;;
    restore) restore "${2:-}" ;;
    health)  health ;;
    *)
        echo "Usage: $0 {backup [file]|restore <file>|health}"
        ;;
esac
