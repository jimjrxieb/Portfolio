# CKA Domain 1: Cluster Architecture, Installation & Configuration (25%)

Manage role-based access control (RBAC). Use kubeadm to install a basic cluster. Manage a highly-available Kubernetes cluster. Provision underlying infrastructure to deploy a Kubernetes cluster. Perform a version upgrade on a Kubernetes cluster using kubeadm. Implement etcd backup and restore.

## CKA Exam Quick Reference

### kubeadm Cluster Bootstrap
```bash
# Initialize control plane
kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=<IP>

# Save join command
kubeadm token create --print-join-command

# Join worker node
kubeadm join <control-plane>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# Configure kubectl
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
```

### Cluster Upgrade (kubeadm)
```bash
# --- ON CONTROL PLANE ---
# 1. Drain node
kubectl drain <cp-node> --ignore-daemonsets --delete-emptydir-data

# 2. Upgrade kubeadm
apt-mark unhold kubeadm
apt-get update && apt-get install -y kubeadm=1.30.0-1.1
apt-mark hold kubeadm

# 3. Plan + apply
kubeadm upgrade plan
kubeadm upgrade apply v1.30.0

# 4. Upgrade kubelet + kubectl
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.30.0-1.1 kubectl=1.30.0-1.1
apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet

# 5. Uncordon
kubectl uncordon <cp-node>

# --- ON EACH WORKER ---
kubectl drain <worker> --ignore-daemonsets --delete-emptydir-data
# (SSH to worker)
apt-mark unhold kubeadm kubelet kubectl
apt-get update && apt-get install -y kubeadm=1.30.0-1.1 kubelet=1.30.0-1.1 kubectl=1.30.0-1.1
apt-mark hold kubeadm kubelet kubectl
kubeadm upgrade node
systemctl daemon-reload && systemctl restart kubelet
# (back on control plane)
kubectl uncordon <worker>
```

### etcd Backup & Restore
```bash
# Backup
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db --write-table

# Restore
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restored

# Update etcd manifest to use new data dir
# Edit /etc/kubernetes/manifests/etcd.yaml:
#   - --data-dir=/var/lib/etcd-restored
# and update the volume hostPath
```

### RBAC Essentials
```bash
# Create role (namespaced)
kubectl create role deploy-manager \
  --verb=get,list,watch,create,update,delete \
  --resource=deployments \
  -n app-ns

# Bind role to user
kubectl create rolebinding deploy-manager-binding \
  --role=deploy-manager \
  --user=alice \
  -n app-ns

# Create cluster role
kubectl create clusterrole node-reader \
  --verb=get,list,watch \
  --resource=nodes

# Bind cluster role
kubectl create clusterrolebinding node-reader-binding \
  --clusterrole=node-reader \
  --user=bob

# Test permissions
kubectl auth can-i create deployments -n app-ns --as=alice    # yes
kubectl auth can-i delete nodes --as=alice                     # no
kubectl auth can-i get nodes --as=bob                          # yes
```

### High Availability
```bash
# Stacked etcd HA (3 control planes)
kubeadm init --control-plane-endpoint "lb.example.com:6443" \
  --upload-certs \
  --pod-network-cidr=10.244.0.0/16

# Join additional control planes
kubeadm join lb.example.com:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <cert-key>
```

## Cross-Reference to GP-CONSULTING

| Need | Location |
|------|----------|
| RBAC templates | `02-CLUSTER-HARDENING/templates/remediation/rbac-templates.yaml` |
| RBAC audit playbook | `02-CLUSTER-HARDENING/playbooks/07a-rbac-audit.md` |
| Platform detection | `02-CLUSTER-HARDENING/tools/hardening/pre-flight-check.sh` |
| Cluster report | `02-CLUSTER-HARDENING/tools/hardening/collect-cluster-report.sh` |
| ArgoCD setup | `02-CLUSTER-HARDENING/tools/platform/setup-argocd.sh` |

## Practice Scenarios

1. **kubeadm install**: Bootstrap a 3-node cluster from scratch
2. **Cluster upgrade**: Upgrade from 1.29 to 1.30 (control plane + workers)
3. **etcd backup/restore**: Backup etcd, delete a namespace, restore from backup
4. **RBAC**: Create roles for dev/ops/security teams with least privilege
5. **HA**: Set up 3 control planes behind a load balancer
