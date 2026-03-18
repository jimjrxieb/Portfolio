# Playbook: Network Perfection

> Verify every namespace has NetworkPolicies. Tighten service mesh mTLS. Close network paths that 02/03 left open.
>
> **When:** After pod security perfected. Network is the next layer out.
> **Time:** ~20 min

---

## Prerequisites

- 02-CLUSTER-HARDENING playbook 05 (automated fixes — NetworkPolicy generation) completed
- 03-DEPLOY-RUNTIME playbook 08 (service mesh) completed if applicable

---

## Step 1: NetworkPolicy Coverage Audit

```bash
# Namespaces WITHOUT any NetworkPolicy
ALL_NS=$(kubectl get ns --no-headers | awk '{print $1}' | grep -v -E 'kube-system|kube-public|kube-node-lease')
NP_NS=$(kubectl get networkpolicy -A --no-headers 2>/dev/null | awk '{print $1}' | sort -u)

echo "=== Namespaces WITHOUT NetworkPolicies ==="
for NS in $ALL_NS; do
    echo "$NP_NS" | grep -q "^${NS}$" || echo "  [MISSING] $NS"
done
```

### Fix: Deploy Default Deny

For every namespace missing NetworkPolicies:

```bash
# Reference template
cat ~/GP-copilot/GP-CONSULTING/04-KUBESTER/templates/quick-ref/networkpolicy-default-deny.yaml

# Or auto-generate per namespace
for NS in <missing-namespaces>; do
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: $NS
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: $NS
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
EOF
    echo "Default deny + DNS applied to $NS"
done
```

> **Tool:** `03-DEPLOY-RUNTIME/responders/generate-networkpolicy.sh` generates workload-specific policies.
> **Tool:** `02-CLUSTER-HARDENING/tools/hardening/fix-cluster-security.sh` does this at scale.

---

## Step 2: Verify No Exposed Services

```bash
# NodePort services (should be zero in production)
kubectl get svc -A --no-headers | grep NodePort
# Fix: Convert to ClusterIP + Ingress/Gateway

# LoadBalancer services (verify each is intentional)
kubectl get svc -A --no-headers | grep LoadBalancer

# Services with externalIPs (red flag)
kubectl get svc -A -o json | jq -r '
  .items[] | select(.spec.externalIPs != null) |
  "\(.metadata.namespace)/\(.metadata.name) — externalIPs: \(.spec.externalIPs)"'
```

Fix NodePort services:

```bash
bash ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/hardening/fix-nodeport.sh
```

---

## Step 3: Service Mesh mTLS Verification

If service mesh is deployed (from 03-DEPLOY-RUNTIME):

```bash
# Istio — check PeerAuthentication mode
kubectl get peerauthentication -A -o json | jq -r '
  .items[] | "\(.metadata.namespace)/\(.metadata.name): \(.spec.mtls.mode)"'

# Should be STRICT, not PERMISSIVE
# If PERMISSIVE, the mesh allows unencrypted traffic

# Verify mTLS is working
bash ~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME/tools/verify-mtls.sh
```

If mTLS is PERMISSIVE, migrate to STRICT:

```bash
# Apply STRICT mesh-wide
kubectl apply -f ~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME/templates/service-mesh/peer-authentication.yaml

# Verify no services broke
kubectl get pods -A | grep -v Running
```

> **Reference:** `03-DEPLOY-RUNTIME/playbooks/08-deploy-service-mesh.md` for the full progression.

---

## Step 4: Verify DNS Policies

```bash
# Ensure DNS egress is allowed in namespaces with default-deny
for NS in $(kubectl get networkpolicy -A --no-headers | awk '{print $1}' | sort -u); do
    DNS_POLICY=$(kubectl get networkpolicy -n "$NS" -o json | jq '[.items[] | select(.spec.egress[]?.ports[]?.port == 53)] | length')
    if [ "$DNS_POLICY" -eq 0 ]; then
        echo "[WARN] $NS has egress policies but no DNS allow — pods may lose DNS"
    fi
done
```

---

## Step 5: Dataplane Health Check

```bash
# Run the dataplane watcher from 03
bash ~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME/watchers/watch-dataplane.sh

# This checks:
# - Empty endpoints (service with no backing pods)
# - DNS resolution
# - CNI / kube-proxy health
# - Node readiness
```

---

## Outputs

- All namespaces: default-deny NetworkPolicy + DNS egress
- NodePort services: converted to ClusterIP
- Service mesh mTLS: STRICT (if mesh deployed)
- DNS policies: verified in all deny-all namespaces
- Dataplane: healthy

---

## Next

→ [08-secrets-perfection.md](08-secrets-perfection.md) — Encryption at rest, ESO, secret rotation
