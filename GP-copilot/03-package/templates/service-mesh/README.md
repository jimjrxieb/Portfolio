# Service Mesh Templates

> mTLS encryption and zero-trust networking for pod-to-pod traffic.

---

## Two Options

| Mesh | How mTLS Works | Best For |
|------|---------------|----------|
| **Istio (ambient)** | L4 ztunnel + L7 waypoint proxies | Full L7 control, AuthorizationPolicy, tracing |
| **Cilium** | WireGuard kernel-level encryption | Teams already on Cilium CNI, minimal overhead |

Pick one. Don't run both.

---

## Files

| File | What It Does |
|------|-------------|
| `istio-values.yaml` | Istio ambient mode Helm values (istiod) |
| `cilium-values.yaml` | Cilium with WireGuard encryption Helm values |
| `peer-authentication.yaml` | mTLS enforcement: PERMISSIVE → STRICT progression |
| `authorization-policy.yaml` | Default-deny + allow rules (zero-trust L7) |
| `destination-rule.yaml` | mTLS outbound + circuit breaking + canary subsets |

---

## Quick Start

```bash
# Deploy service mesh
bash tools/deploy-service-mesh.sh --mesh istio

# Verify mTLS is working
bash tools/verify-mtls.sh

# After verification — enforce STRICT
bash tools/deploy-service-mesh.sh --mesh istio --enforce
```

---

## Progression

```
1. Install mesh (PERMISSIVE mode)
2. Verify all services can communicate
3. Check mTLS status per namespace (verify-mtls.sh)
4. Enable STRICT on sensitive namespaces first (payments, PII)
5. Enable STRICT mesh-wide
6. Add AuthorizationPolicy (default-deny + allow list)
7. Monitor with Falco rules (service-mesh.yaml)
```

---

*Ghost Protocol — Runtime Security Package (CKS)*
