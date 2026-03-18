# Playbook: Deploy Service Mesh

> Encrypt all pod-to-pod traffic with mTLS + enforce zero-trust networking.
>
> **When:** After cluster hardening (02) is complete. Before going to production.
> **Time:** ~30 min (Istio) or ~15 min (Cilium)

---

## Choose Your Mesh

| | Istio Ambient | Cilium WireGuard |
|---|--------------|-----------------|
| **mTLS** | Application-layer (L7) | Kernel-layer (L4) |
| **Overhead** | ~10-15% CPU | ~3% CPU |
| **L7 policies** | Yes (AuthorizationPolicy) | Limited (CiliumNetworkPolicy) |
| **Traffic splitting** | Yes (canary, blue-green) | No |
| **Tracing integration** | Native | Via Hubble |
| **Best for** | Full control, compliance | Already using Cilium CNI, simplicity |

**Recommendation:** Istio ambient for FedRAMP/compliance environments. Cilium for teams that want "just encrypt everything" with minimal ops burden.

---

## Option A: Istio Ambient

### Step 1: Install

```bash
PKG=~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME

# Install Istio ambient mode (PERMISSIVE — no breakage)
bash $PKG/tools/deploy-service-mesh.sh --mesh istio

# What this deploys:
#   istio-base    → CRDs (PeerAuthentication, AuthorizationPolicy, etc.)
#   istiod        → Control plane (cert management, config distribution)
#   ztunnel       → L4 proxy DaemonSet (transparent mTLS, no sidecars)
```

### Step 2: Enroll namespaces

```bash
# Add namespaces to the mesh one at a time
bash $PKG/tools/deploy-service-mesh.sh --mesh istio --enroll payments
bash $PKG/tools/deploy-service-mesh.sh --mesh istio --enroll api
bash $PKG/tools/deploy-service-mesh.sh --mesh istio --enroll frontend

# Verify enrollment
kubectl get namespaces -L istio.io/dataplane-mode

# What this does:
#   Labels namespace with istio.io/dataplane-mode=ambient
#   ztunnel starts encrypting traffic for pods in that namespace
#   No pod restarts needed (ambient mode = no sidecar injection)
```

### Step 3: Verify mTLS

```bash
# Run the verification script
bash $PKG/tools/verify-mtls.sh

# What it checks:
#   ✓ istiod running
#   ✓ ztunnel running (ambient mode)
#   ✓ PeerAuthentication policies
#   ✓ All namespaces with pods are enrolled
#   ✓ Certificate health
```

### Step 4: Enforce STRICT mTLS

```bash
# Only after verify-mtls.sh shows "READY FOR STRICT"
bash $PKG/tools/deploy-service-mesh.sh --mesh istio --enforce

# What this does:
#   Changes PeerAuthentication from PERMISSIVE → STRICT
#   All pod-to-pod traffic MUST be mTLS
#   Plaintext connections are REJECTED
#   Any service not in the mesh will lose connectivity
```

### Step 5: Apply AuthorizationPolicy (optional, recommended)

```bash
# Default-deny + explicit allow list
kubectl apply -f $PKG/templates/service-mesh/authorization-policy.yaml

# WARNING: This denies ALL traffic by default.
# Edit authorization-policy.yaml to add allow rules for your services FIRST.

# Template for adding a service path:
# kubectl apply -f - <<EOF
# apiVersion: security.istio.io/v1
# kind: AuthorizationPolicy
# metadata:
#   name: allow-frontend-to-api
#   namespace: production
# spec:
#   selector:
#     matchLabels:
#       app: api-server
#   action: ALLOW
#   rules:
#     - from:
#         - source:
#             principals: ["cluster.local/ns/production/sa/frontend"]
#       to:
#         - operation:
#             methods: ["GET", "POST"]
#             paths: ["/api/v1/*"]
# EOF
```

---

## Option B: Cilium WireGuard

### Step 1: Install (or upgrade existing Cilium)

```bash
PKG=~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME

# Install Cilium with WireGuard encryption
bash $PKG/tools/deploy-service-mesh.sh --mesh cilium

# What this does:
#   Enables encryption.enabled=true, encryption.type=wireguard
#   ALL pod-to-pod traffic is encrypted at the kernel level
#   No namespace enrollment needed — it's automatic
#   Hubble (observability) is enabled for flow visibility
```

### Step 2: Verify

```bash
# Check encryption status
CILIUM_POD=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium -o name | head -1)
kubectl exec -n kube-system $CILIUM_POD -- cilium encrypt status

# Check Hubble flows
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
# Open http://localhost:12000
```

---

## Step 6: Deploy Falco Rules (both meshes)

```bash
# Detect mesh tampering, mTLS bypass, unauthorized proxies
kubectl apply -f $PKG/templates/falco-rules/service-mesh.yaml

# Rules:
#   CRITICAL: Envoy proxy config tampering
#   CRITICAL: mTLS certificate access by non-proxy process
#   CRITICAL: Shell spawned in Istio control plane
#   WARNING:  Unauthorized sidecar injection
#   WARNING:  PeerAuthentication weakened to PERMISSIVE
#   WARNING:  AuthorizationPolicy deleted
#   NOTICE:   Mesh egress to unregistered host
```

---

## Troubleshooting

### mTLS not working after STRICT

```bash
# Check which pods are NOT in the mesh
bash tools/verify-mtls.sh --fix

# Common cause: namespace not enrolled
bash tools/deploy-service-mesh.sh --mesh istio --enroll <namespace>

# Common cause: external service (DB, API) can't do mTLS
# Fix: Create a PeerAuthentication exception for that workload
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: allow-plaintext-to-external-db
  namespace: production
spec:
  selector:
    matchLabels:
      app: legacy-db-client
  mtls:
    mode: PERMISSIVE
EOF
```

### Services can't communicate after AuthorizationPolicy

```bash
# Check what's being denied
kubectl logs -n istio-system -l app=istiod --tail=50 | grep "RBAC"

# Quick fix: remove the deny-all and debug
kubectl delete authorizationpolicy deny-all -n istio-system

# Proper fix: add the missing allow rule (see authorization-policy.yaml)
```

### Istio control plane high CPU

```bash
# Check istiod resource usage
kubectl top pods -n istio-system

# Fix: increase resources in istio-values.yaml
# pilot.resources.limits.cpu: 1000m
# pilot.resources.limits.memory: 1Gi
```

---

## Completion Checklist

```
[ ] Mesh installed (Istio ambient or Cilium WireGuard)
[ ] All application namespaces enrolled
[ ] mTLS verified (verify-mtls.sh shows READY)
[ ] STRICT mode enforced
[ ] AuthorizationPolicy applied (optional but recommended)
[ ] Falco service-mesh.yaml rules deployed
[ ] DestinationRule applied for circuit breaking (if needed)
[ ] Exceptions documented for services that can't do mTLS
```

---

## Next Steps

- Deploy tracing → [09-deploy-tracing.md](09-deploy-tracing.md) (works with Istio's built-in tracing)
- Deploy logging → [10-deploy-logging.md](10-deploy-logging.md)
- Operations → [07-operations.md](07-operations.md)

---

*Ghost Protocol — Runtime Security Package (CKS)*
