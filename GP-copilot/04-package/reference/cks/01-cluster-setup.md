# CKS Domain 1: Cluster Setup & Hardening (15%)

Use CIS benchmarks to review security configuration. Verify platform security. Use ingress objects securely.

## What You Need to Know

- CIS Kubernetes Benchmark (kube-bench)
- Network Policies (default deny, workload-specific)
- Ingress/Gateway API with TLS
- Kubeconfig security

## Pre-Built Tools (Already in GP-CONSULTING)

### Scanners
| Tool | Location | What It Checks |
|------|----------|---------------|
| kube-bench | `01-APP-SEC/scanners/kubebench_scan_npc.py` | CIS sections 1.x (API server), 2.x (etcd), 3.x (controller-manager), 4.x (worker) |
| Kubescape | `01-APP-SEC/scanners/kubescape_scan_npc.py` | NSA/CISA hardening guide, CIS-EKS, MITRE ATT&CK |
| Polaris | `01-APP-SEC/scanners/polaris_scan_npc.py` | Best practices: security, reliability, networking |

### Audit Scripts
| Script | Location | What It Does |
|--------|----------|-------------|
| `run-cluster-audit.sh` | `02-CLUSTER-HARDENING/tools/hardening/` | Runs all three scanners, generates baseline report |
| `pre-flight-check.sh` | `02-CLUSTER-HARDENING/tools/hardening/` | Detects platform (k3s/EKS/kubeadm), checks prerequisites |
| `collect-cluster-report.sh` | `02-CLUSTER-HARDENING/tools/hardening/` | Full cluster state dump (versions, resources, configs) |

### Playbooks
| Playbook | Location | When to Use |
|----------|----------|-------------|
| `03-cluster-audit.md` | `02-CLUSTER-HARDENING/playbooks/` | First-time cluster assessment |
| `01-identify-management.md` | `02-CLUSTER-HARDENING/playbooks/` | Determine ArgoCD vs kubectl ownership |
| `01a-platform-quirks.md` | `02-CLUSTER-HARDENING/playbooks/` | Platform-specific configs (k3s, EKS, etc.) |

## CKS Exam Quick Reference

### Verify API Server Security
```bash
# Check API server flags
kubectl -n kube-system get pod kube-apiserver-* -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n'

# Critical flags to verify:
# --anonymous-auth=false
# --authorization-mode=Node,RBAC
# --enable-admission-plugins=NodeRestriction,...
# --audit-log-path=/var/log/kubernetes/audit.log
# --encryption-provider-config=<path>

# kube-bench automated check
kube-bench run --targets master
```

### Verify etcd Security
```bash
# Check etcd encryption
kubectl -n kube-system get pod etcd-* -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | grep -E 'cert|key|peer'

# Verify encryption at rest
kubectl get secrets -A -o json | kubectl get --raw /api/v1/namespaces/kube-system/secrets/test 2>/dev/null

# kube-bench etcd check
kube-bench run --targets etcd
```

### Network Policies — Default Deny
```yaml
# Default deny all ingress+egress for a namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: TARGET_NS
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Ingress with TLS
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - app.example.com
    secretName: tls-secret
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-svc
            port:
              number: 443
```

### Gateway API (newer, role-separated)
See: `02-CLUSTER-HARDENING/templates/gateway-api/` for full templates.

```bash
# Quick setup
bash 02-CLUSTER-HARDENING/tools/platform/setup-gateway-api.sh
```

## Practice Scenarios

1. **Harden a fresh cluster**: Run `run-cluster-audit.sh`, fix all CRITICAL findings
2. **Lock down a namespace**: Apply default-deny NetworkPolicy, verify pod isolation
3. **Secure ingress**: Create TLS-terminated Ingress, verify HTTPS redirect
4. **Audit API server**: Use kube-bench to find and fix API server misconfigs
5. **Encrypt etcd**: Create EncryptionConfiguration, verify secrets are encrypted at rest
