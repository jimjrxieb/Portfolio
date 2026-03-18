# CKS Domain 4: Minimize Microservice Vulnerabilities (20%)

Set up appropriate OS-level security domains. Manage Kubernetes secrets. Use container runtime sandboxes. Implement pod-to-pod encryption.

## What You Need to Know

- Pod Security Standards (PSS) / Pod Security Admission (PSA)
- SecurityContext (runAsNonRoot, readOnlyRootFilesystem, capabilities)
- NetworkPolicy (ingress, egress, default deny)
- Secrets management (encryption at rest, external secrets)
- Service mesh mTLS (Istio, Cilium)
- RuntimeClass (gVisor, kata)
- OPA/Gatekeeper for custom policies

## Pre-Built Tools (Already in GP-CONSULTING)

### Pod Security
| Resource | Location | What It Provides |
|----------|----------|-----------------|
| 9 Kyverno pod security policies | `02-CLUSTER-HARDENING/templates/policies/kyverno/` | PSS enforcement via admission |
| PSS namespace labels template | `02-CLUSTER-HARDENING/templates/remediation/pss-namespace-labels.yaml` | enforce/audit/warn labels |
| Pod security context template | `02-CLUSTER-HARDENING/templates/remediation/pod-security-context.yaml` | Complete securityContext |
| `add-security-context.sh` | `02-CLUSTER-HARDENING/tools/hardening/` | Auto-add securityContext to manifests |
| `patch-security-context.sh` | `03-DEPLOY-RUNTIME/responders/` | Live pod security patching |
| `watch-pss.sh` | `03-DEPLOY-RUNTIME/watchers/` | PSS label coverage monitoring |

### Network Policies
| Resource | Location | What It Provides |
|----------|----------|-----------------|
| NetworkPolicy templates | `02-CLUSTER-HARDENING/templates/remediation/network-policies.yaml` | Deny-all + workload egress |
| `generate-networkpolicy.sh` | `03-DEPLOY-RUNTIME/responders/` | Auto-generate policies per workload |
| `fix-cluster-security.sh` | `02-CLUSTER-HARDENING/tools/hardening/` | Auto-generate NetworkPolicy per namespace |
| `watch-network-coverage.sh` | `03-DEPLOY-RUNTIME/watchers/` | Missing NetworkPolicy detection |

### Secrets
| Resource | Location | What It Provides |
|----------|----------|-----------------|
| External Secrets templates | `02-CLUSTER-HARDENING/templates/external-secrets/` | ESO + ClusterSecretStore |
| `require-external-secrets.yaml` | `02-CLUSTER-HARDENING/templates/policies/kyverno/` | Block native Secret creation |
| `watch-secrets.sh` | `03-DEPLOY-RUNTIME/watchers/` | Orphaned, rotation-due secrets |
| `cleanup-orphaned-secrets.sh` | `02-CLUSTER-HARDENING/tools/hardening/` | Remove unused secrets |

### Service Mesh (mTLS)
| Resource | Location | What It Provides |
|----------|----------|-----------------|
| Istio values | `03-DEPLOY-RUNTIME/templates/service-mesh/istio-values.yaml` | Ambient mode config |
| Cilium values | `03-DEPLOY-RUNTIME/templates/service-mesh/cilium-values.yaml` | WireGuard encryption |
| PeerAuthentication | `03-DEPLOY-RUNTIME/templates/service-mesh/peer-authentication.yaml` | mTLS STRICT enforcement |
| AuthorizationPolicy | `03-DEPLOY-RUNTIME/templates/service-mesh/authorization-policy.yaml` | L7 traffic rules |
| `deploy-service-mesh.sh` | `03-DEPLOY-RUNTIME/tools/` | One-command mesh install |
| `verify-mtls.sh` | `03-DEPLOY-RUNTIME/tools/` | mTLS verification |

### Playbooks
| Playbook | Location | When to Use |
|----------|----------|-------------|
| `04-fix-manifests.md` | `02-CLUSTER-HARDENING/playbooks/` | Fix securityContext, limits, probes |
| `05-automated-fixes.md` | `02-CLUSTER-HARDENING/playbooks/` | Auto-generate NetworkPolicy, LimitRange, PSS |
| `08-deploy-service-mesh.md` | `03-DEPLOY-RUNTIME/playbooks/` | Deploy Istio/Cilium mTLS |
| `11-setup-external-secrets.md` | `02-CLUSTER-HARDENING/playbooks/` | ESO integration |
| `15-secrets-hygiene.md` | `02-CLUSTER-HARDENING/playbooks/` | Secrets audit and cleanup |

## CKS Exam Quick Reference

### Complete SecurityContext
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: nginx:1.25
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
```

### Pod Security Standards (PSA Labels)
```bash
# Label namespace for enforcement
kubectl label ns production \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted

# Verify
kubectl get ns production -o jsonpath='{.metadata.labels}' | jq
```

### NetworkPolicy — Allow Specific Traffic
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: app
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - port: 8080
      protocol: TCP
```

### Encrypt Secrets at Rest
```yaml
# /etc/kubernetes/enc/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: <base64-encoded-32-byte-key>
  - identity: {}
```

```bash
# Generate key
head -c 32 /dev/urandom | base64

# Add to API server
# --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml

# Re-encrypt existing secrets
kubectl get secrets -A -o json | kubectl replace -f -
```

### RuntimeClass (gVisor)
```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
---
apiVersion: v1
kind: Pod
metadata:
  name: sandboxed-pod
spec:
  runtimeClassName: gvisor
  containers:
  - name: app
    image: nginx:1.25
```

## Practice Scenarios

1. **Pod security**: Create a Deployment with full securityContext, verify it passes restricted PSS
2. **NetworkPolicy**: Write deny-all + allow-specific for a 3-tier app (frontend/backend/db)
3. **Secrets**: Enable encryption at rest, create a secret, verify it's encrypted in etcd
4. **mTLS**: Deploy Istio, enable STRICT PeerAuthentication, verify traffic is encrypted
5. **RuntimeClass**: Deploy gVisor, run untrusted workload in sandbox
6. **OPA**: Write Gatekeeper constraint that blocks pods without resource limits
