# Playbook: Runtime Perfection

> Tune Falco rules. Verify all watchers and responders are functioning. Test incident response procedures end-to-end.
>
> **When:** After supply chain verified. Runtime is the last line of defense.
> **Time:** ~25 min

---

## Prerequisites

- 03-DEPLOY-RUNTIME playbooks 02-07 completed (Falco, monitoring, operations)
- Falco running and generating alerts

---

## Step 1: Falco Health Check

```bash
PKG=~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME

# Verify Falco is healthy
bash $PKG/tools/health-check.sh

# Check Falco alert volume (too many = noisy, too few = misconfigured)
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=100 --since=1h | wc -l
echo "alerts in the last hour"

# Top firing rules
kubectl logs -n falco -l app.kubernetes.io/name=falco --since=1h | jq -r '.rule' 2>/dev/null | sort | uniq -c | sort -rn | head -10
```

If alerts are too noisy:

```bash
# Tune Falco
bash $PKG/tools/tune-falco.sh
```

> **Reference:** `03-DEPLOY-RUNTIME/playbooks/04-tune-falco.md` for the full tuning process.

---

## Step 2: Verify Watchers

Run each watcher and confirm it produces output:

```bash
WATCHERS=$PKG/watchers

echo "=== Testing Watchers ==="
for WATCHER in watch-events.sh watch-audit.sh watch-drift.sh watch-secrets.sh watch-policy-violations.sh watch-pss.sh watch-seccomp.sh watch-apparmor.sh watch-network-coverage.sh watch-supply-chain.sh watch-dataplane.sh; do
    if [ -f "$WATCHERS/$WATCHER" ]; then
        echo "Running: $WATCHER"
        timeout 10 bash "$WATCHERS/$WATCHER" 2>/dev/null | head -5
        echo "---"
    else
        echo "[MISSING] $WATCHER"
    fi
done
```

Any watcher that produces no output or errors needs investigation.

---

## Step 3: Test Incident Response

Simulate a security event and verify the response chain works:

```bash
# Create a test namespace
kubectl create ns kubester-ir-test

# Deploy a test pod
kubectl run ir-test --image=nginx:1.25 -n kubester-ir-test

# Wait for it to run
kubectl wait --for=condition=Ready pod/ir-test -n kubester-ir-test --timeout=30s
```

### Test 1: Shell Detection (Falco)

```bash
# Exec into the pod — Falco should detect this
kubectl exec -n kubester-ir-test ir-test -- /bin/sh -c 'whoami'

# Check Falco logs for the alert
sleep 5
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20 | grep -i "terminal\|shell\|exec"
```

### Test 2: Pod Isolation (Responder)

```bash
# Isolate the pod
bash $PKG/responders/isolate-pod.sh kubester-ir-test ir-test 2>/dev/null || \
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-ir-test
  namespace: kubester-ir-test
spec:
  podSelector:
    matchLabels:
      run: ir-test
  policyTypes:
  - Ingress
  - Egress
EOF

# Verify isolation — this should fail (no egress)
kubectl exec -n kubester-ir-test ir-test -- wget -qO- --timeout=3 http://kubernetes.default.svc 2>&1 || echo "Isolation confirmed — egress blocked"
```

### Test 3: Forensic Capture

```bash
# Capture forensics
bash $PKG/responders/capture-forensics.sh kubester-ir-test ir-test 2>/dev/null || {
    echo "Manual forensic capture:"
    kubectl logs -n kubester-ir-test ir-test > /tmp/kubester-audit/ir-test-logs.txt
    kubectl get pod ir-test -n kubester-ir-test -o yaml > /tmp/kubester-audit/ir-test-manifest.yaml
    echo "Saved to /tmp/kubester-audit/"
}
```

### Cleanup

```bash
kubectl delete ns kubester-ir-test
```

---

## Step 4: Verify Audit Logging Pipeline

```bash
# If audit logging was configured in playbook 03
if kubectl -n kube-system get pod -l component=kube-apiserver \
  -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null | grep -q audit-log-path; then
    echo "[PASS] Audit logging enabled"

    # Check log file is being written (on control plane node)
    # ls -la /var/log/kubernetes/audit.log
else
    echo "[WARN] Audit logging not enabled — configure in playbook 03-apiserver-etcd"
fi

# If Falco is sending to Prometheus
kubectl get svc -n falco falco-exporter 2>/dev/null && echo "[PASS] falco-exporter running" || echo "[WARN] falco-exporter not found"
```

---

## Step 5: Verify Monitoring Stack

```bash
# Prometheus
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers 2>/dev/null

# Grafana
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null

# Alert rules loaded
kubectl get prometheusrule -A --no-headers 2>/dev/null | wc -l
echo "Prometheus alert rules"
```

> **Reference:** `03-DEPLOY-RUNTIME/playbooks/05-deploy-monitoring.md` if monitoring needs deployment.

---

## Outputs

- Falco: healthy, tuned, not noisy
- Watchers: all 11 producing output
- Incident response: tested end-to-end (detect → isolate → capture)
- Audit logging: verified writing
- Monitoring: Prometheus + Grafana running, alert rules loaded

---

## Next

→ [11-storage-workloads.md](11-storage-workloads.md) — Storage security, probes, resource limits
