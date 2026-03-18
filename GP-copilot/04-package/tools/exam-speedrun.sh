#!/usr/bin/env bash
# exam-speedrun.sh — Timed CKS/CKA exam simulation with imperative commands
# Usage: ./exam-speedrun.sh [--cks|--cka]
set -euo pipefail

MODE="${1:---cks}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

header() { echo -e "\n${BLUE}=== $1 ===${NC}"; }
task() { echo -e "${YELLOW}TASK:${NC} $1"; }
hint() { echo -e "${GREEN}HINT:${NC} $1"; }

echo "╔══════════════════════════════════════════════╗"
echo "║         KUBESTER Exam Speedrun               ║"
echo "║         Imperative Command Practice          ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ─── Imperative Commands Cheat Sheet ───

header "IMPERATIVE COMMANDS — Muscle Memory"

cat <<'CHEAT'

# ── Resource Creation ──
kubectl run nginx --image=nginx:1.25                              # Pod
kubectl create deployment nginx --image=nginx:1.25 --replicas=3   # Deployment
kubectl expose deployment nginx --port=80 --type=ClusterIP        # Service
kubectl create service nodeport nginx --tcp=80:80                 # NodePort
kubectl create configmap app --from-literal=KEY=VALUE             # ConfigMap
kubectl create secret generic db --from-literal=PASS=secret       # Secret
kubectl create job backup --image=busybox -- echo done            # Job
kubectl create cronjob nightly --image=busybox --schedule="0 2 * * *" -- echo done  # CronJob
kubectl create sa app-sa                                          # ServiceAccount
kubectl create ns secure-ns                                       # Namespace
kubectl create quota mem-quota --hard=memory=1Gi -n ns            # ResourceQuota
kubectl create role dev --verb=get,list --resource=pods           # Role
kubectl create rolebinding dev-bind --role=dev --user=alice       # RoleBinding
kubectl create clusterrole reader --verb=get --resource=nodes     # ClusterRole
kubectl create clusterrolebinding reader-bind --clusterrole=reader --user=bob  # ClusterRoleBinding
kubectl create ingress app --rule="host/path=svc:port"            # Ingress

# ── Generate YAML (don't apply) ──
kubectl run nginx --image=nginx:1.25 --dry-run=client -o yaml > pod.yaml
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deploy.yaml

# ── Quick Edits ──
kubectl set image deployment/app app=nginx:1.26                   # Update image
kubectl scale deployment/app --replicas=5                         # Scale
kubectl rollout undo deployment/app                               # Rollback
kubectl rollout status deployment/app                             # Check rollout
kubectl label pod nginx env=prod                                  # Add label
kubectl annotate pod nginx desc="web server"                      # Add annotation
kubectl taint nodes node1 env=prod:NoSchedule                     # Taint
kubectl taint nodes node1 env=prod:NoSchedule-                    # Remove taint
kubectl cordon node1                                              # Mark unschedulable
kubectl drain node1 --ignore-daemonsets --delete-emptydir-data    # Drain
kubectl uncordon node1                                            # Mark schedulable

# ── Debugging ──
kubectl describe pod nginx                                        # Full pod info
kubectl logs nginx --previous                                     # Crashed container logs
kubectl exec -it nginx -- /bin/sh                                 # Shell into pod
kubectl debug -it nginx --image=busybox --target=nginx            # Debug container
kubectl get events --sort-by='.lastTimestamp'                      # Recent events
kubectl top pods --sort-by=cpu                                    # Resource usage
kubectl auth can-i create pods --as=alice                         # RBAC test

# ── Quick Lookups ──
kubectl get pods -o wide                                          # Pod IPs and nodes
kubectl get pods -o jsonpath='{.items[*].metadata.name}'          # Just names
kubectl get pods --sort-by='.status.containerStatuses[0].restartCount'  # By restarts
kubectl get pods -l app=nginx                                     # By label
kubectl explain pod.spec.securityContext                          # API docs
kubectl api-resources                                             # All resource types

CHEAT

if [ "$MODE" = "--cks" ]; then
    header "CKS-SPECIFIC COMMANDS"
    cat <<'CKS'

# ── Security Context (from memory) ──
# runAsNonRoot: true, readOnlyRootFilesystem: true, allowPrivilegeEscalation: false
# capabilities: drop: ["ALL"]
# seccompProfile: type: RuntimeDefault

# ── NetworkPolicy (default deny template) ──
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: TARGET
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
EOF

# ── PSS Labels ──
kubectl label ns TARGET pod-security.kubernetes.io/enforce=restricted

# ── Falco ──
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20

# ── Audit Logs ──
cat /var/log/kubernetes/audit.log | jq 'select(.verb=="delete")'

# ── AppArmor ──
# annotation: container.apparmor.security.beta.kubernetes.io/CONTAINER: localhost/PROFILE

# ── Trivy ──
trivy image IMAGE:TAG --severity HIGH,CRITICAL

# ── Kyverno ──
kubectl get policyreport -A
kubectl get clusterpolicyreport

CKS
fi

if [ "$MODE" = "--cka" ]; then
    header "CKA-SPECIFIC COMMANDS"
    cat <<'CKA'

# ── etcd Backup ──
ETCDCTL_API=3 etcdctl snapshot save /tmp/backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# ── Cluster Upgrade ──
kubeadm upgrade plan
kubeadm upgrade apply v1.30.0

# ── Static Pod ──
# Manifest dir: /etc/kubernetes/manifests/
# Create YAML there → kubelet auto-creates the pod

# ── DNS Debug ──
kubectl run test --image=busybox --rm -it -- nslookup kubernetes.default

# ── PV/PVC ──
kubectl get pv,pvc -A

CKA
fi

echo ""
echo "Practice these until they're muscle memory."
echo "Target: complete any command in < 10 seconds."
