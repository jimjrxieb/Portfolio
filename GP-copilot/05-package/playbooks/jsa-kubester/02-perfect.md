# Phase 2: Domain Perfection

Source: `04-KUBESTER/playbooks/02-11`
Automation: **74% autonomous (E/D-rank)**, 14% JADE (C-rank), 10% human (B-rank), 2% S-rank

## Execution Rule

Only run playbooks where the gap report (Phase 1) shows findings.
Each playbook targets a specific CKS/CKA domain. Run in order.

## Playbook 02: Platform Integrity — 100% D-rank

```bash
# Detect platform
02-CLUSTER-HARDENING/tools/hardening/pre-flight-check.sh --platform-only

# Verify binary checksums
for bin in kubectl kubelet kubeadm; do
  EXPECTED=$(curl -sL "https://dl.k8s.io/release/$(${bin} version --client -o json | jq -r .clientVersion.gitVersion)/bin/linux/amd64/${bin}.sha256")
  ACTUAL=$(sha256sum $(which ${bin}) | cut -d' ' -f1)
  [ "$EXPECTED" = "$ACTUAL" ] && echo "[PASS] ${bin}" || echo "[FAIL] ${bin}: checksum mismatch"
done

# Check certificate expiry
kubeadm certs check-expiration 2>/dev/null || echo "Not kubeadm cluster"

# Verify trusted registries
kubectl get pods -A -o jsonpath='{range .items[*].spec.containers[*]}{.image}{"\n"}{end}' | sort -u
```

**CKS exam tip**: Binary verification is a quick exam question. Know the SHA256 workflow.

## Playbook 03: API Server & etcd — B-rank (control plane)

```bash
# Audit API server flags
kubectl get pod kube-apiserver-* -n kube-system -o yaml | grep -E 'anonymous-auth|authorization-mode|profiling|audit-log|encryption-provider|insecure-port'

# Test etcd backup
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup-test.db \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup-test.db
```

**B-rank escalation**: API server flag changes and etcd encryption require human approval.
These are control plane changes — wrong values = cluster down.

**CKS exam tip**: Know every critical API server flag by heart. etcd backup is guaranteed.

## Playbook 04: RBAC Perfection — S-rank for cluster-admin

```bash
# S-RANK: User cluster-admin bindings → HUMAN ONLY
kubectl get clusterrolebindings -o json | jq '[.items[] | select(.roleRef.name=="cluster-admin") | select(.metadata.name | test("^system:") | not)]'

# C-RANK: Wildcard RBAC → JADE proposes scoped replacement
kubectl get clusterroles -o json | jq '[.items[] | select(.rules[]?.verbs[]? == "*")]'

# E-RANK: Disable automount on default SAs
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  kubectl patch serviceaccount default -n $ns -p '{"automountServiceAccountToken": false}' 2>/dev/null
done
```

**CKS exam tip**: RBAC is 15% of CKS. Always create least-privilege. Never wildcard.

## Playbook 05: Admission Perfection — B-rank for enforce

```bash
# List policies and modes
kubectl get clusterpolicies -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.validationFailureAction}{"\n"}{end}'

# Check violations per audit-mode policy
kubectl get policyreports -A -o json | jq '[.items[].results[] | select(.result=="fail")] | group_by(.policy) | map({policy: .[0].policy, count: length})'

# D-RANK: Deploy missing policies
02-CLUSTER-HARDENING/tools/admission/deploy-policies.sh --engine kyverno --mode audit

# B-RANK: Promote zero-violation to enforce → HUMAN approves
```

## Playbook 06: Pod Security — D/C-rank

```bash
# PSS labels (D-rank)
kubectl get ns --show-labels | grep -v pod-security

# Seccomp audit (D-rank)
kubectl get pods -A -o json | jq '[.items[] | select(.spec.securityContext.seccompProfile == null) | {name:.metadata.name, ns:.metadata.namespace}]'

# Add seccomp RuntimeDefault (D-rank)
# Add AppArmor annotations (D-rank)
# RuntimeClass for untrusted (C-rank → JADE)
```

## Playbook 07: Network Perfection — D-rank

```bash
# Find namespaces without NetworkPolicy (D-rank)
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v kube-); do
  count=$(kubectl get networkpolicy -n $ns --no-headers 2>/dev/null | wc -l)
  [ "$count" = "0" ] && echo "[FAIL] $ns: no NetworkPolicy"
done

# Deploy default-deny (D-rank)
# Flag NodePort services (D-rank)
# mTLS STRICT (C-rank → JADE)
```

**CKS exam tip**: NetworkPolicy default-deny is the #1 most tested CKS concept.

## Playbook 08: Secrets — B/C-rank

```bash
# Verify encryption at rest (B-rank: control plane)
kubectl create secret generic kubester-enc-test -n default --from-literal=test=verified
# Then: etcdctl get /registry/secrets/default/kubester-enc-test → should be encrypted

# Count secrets by namespace (D-rank)
kubectl get secrets -A --no-headers | awk '{print $1}' | sort | uniq -c | sort -rn

# Flag old secrets (D-rank)
kubectl get secrets -A -o json | jq '[.items[] | select(.metadata.creationTimestamp < "'$(date -d '-90 days' -Iseconds)'")]'

# ESO migration plan (C-rank → JADE)
```

## Playbook 09: Supply Chain — 100% D-rank

```bash
# Registry audit
kubectl get pods -A -o jsonpath='{range .items[*].spec.containers[*]}{.image}{"\n"}{end}' | sort -u | grep -vE 'docker.io|gcr.io|quay.io|ghcr.io|registry.k8s.io'

# CVE scan all unique images
for img in $(kubectl get pods -A -o jsonpath='{range .items[*].spec.containers[*]}{.image}{"\n"}{end}' | sort -u); do
  trivy image $img --severity CRITICAL,HIGH --no-progress -f json 2>/dev/null
done

# Flag :latest
kubectl get pods -A -o jsonpath='{range .items[*].spec.containers[*]}{.image}{"\n"}{end}' | grep ':latest\|@' | grep -v '@'
```

## Playbook 10: Runtime — 100% D-rank

```bash
# Falco health
kubectl get pods -n falco
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=5

# Test all watchers
for watcher in events audit drift secrets policy-violations pss seccomp apparmor network-coverage supply-chain dataplane; do
  03-DEPLOY-RUNTIME/watchers/watch-${watcher}.sh --once 2>/dev/null && echo "[PASS] ${watcher}" || echo "[FAIL] ${watcher}"
done

# IR drill: spawn shell → Falco detects → isolate → capture → delete
kubectl run ir-test --image=busybox --restart=Never -- sleep 300
kubectl exec ir-test -- sh -c "cat /etc/shadow" 2>/dev/null  # Falco should fire
03-DEPLOY-RUNTIME/responders/capture-forensics.sh ir-test default
03-DEPLOY-RUNTIME/responders/isolate-pod.sh ir-test default
kubectl delete pod ir-test --grace-period=0
```

## Playbook 11: Storage & Workloads — D/C-rank

```bash
# Pods without limits (D-rank)
kubectl get pods -A -o json | jq '[.items[] | select(.spec.containers[].resources.limits == null)] | length'

# Probes missing (C-rank → JADE for correct endpoints)
kubectl get deployments -A -o json | jq '[.items[] | select(.spec.template.spec.containers[].livenessProbe == null)] | length'

# Dangerous PVs (D-rank)
kubectl get pv -o json | jq '[.items[] | select(.spec.persistentVolumeReclaimPolicy=="Recycle")]'

# hostPath (D-rank)
kubectl get pods -A -o json | jq '[.items[] | select(.spec.volumes[]?.hostPath != null) | {name:.metadata.name, ns:.metadata.namespace}]'
```

## Phase 2 Gate

```
PASS: all applicable playbooks executed
Continue to Phase 3 (verification)
```
