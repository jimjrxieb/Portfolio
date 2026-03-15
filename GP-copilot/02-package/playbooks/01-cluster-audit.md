# Playbook 01: Cluster Security Audit

> Derived from [GP-CONSULTING/02-CLUSTER-HARDENING/playbooks/01-cluster-audit.md](https://github.com/jimjrxieb/GP-copilot)
> Tailored for the Portfolio k3s cluster (portfolioserver, 100.116.11.56)

## What This Does

Runs 5 audit tools against the Portfolio k3s cluster to establish a baseline security posture. This answers: "How hardened is the cluster before we touch anything?"

## Audit Tools and What They Check

| Tool | What It Checks | CIS/Framework | Portfolio Context |
|------|---------------|---------------|-------------------|
| **kubescape** | Risk score 0-100, MITRE ATT&CK gap analysis, NSA/CISA hardening guide | NSA/CISA K8s Hardening Guide, MITRE ATT&CK | Scans all namespaces: portfolio, argocd, cert-manager, monitoring, vault, gatekeeper-system |
| **kube-bench** | CIS Kubernetes Benchmark v1.8 — pass/fail per control (API server, etcd, kubelet, policies) | CIS Benchmark 1.x-5.x | k3s single-node: some control plane checks differ from kubeadm |
| **polaris** | Best practices score (security, reliability, efficiency) per workload | K8s best practices | Checks all deployments: API, UI, ChromaDB, ArgoCD components |
| **RBAC audit** | cluster-admin bindings, wildcard roles, overly permissive service accounts | CIS 5.1.x, NIST AC-6 | Checks: how many cluster-admins? Should be 2 (admin + argocd) |
| **Resource cliff** | Pods without limits, root pods, namespaces without NetworkPolicy | CIS 5.4.1, 5.7.7 | Identifies pods in portfolio namespace missing limits/probes |

## What the Portfolio Cluster Looks Like

```
Namespaces on portfolioserver:
├── portfolio          → API + UI + ChromaDB (production workloads)
├── argocd             → GitOps controller
├── cert-manager       → TLS certificate management
├── external-secrets   → Vault/AWS secrets sync
├── gatekeeper-system  → OPA admission control
├── jsa-infrasec       → Security agent (GP-Copilot)
├── monitoring         → Prometheus + Grafana
└── vault              → HashiCorp Vault
```

## Key Findings to Watch For

| Finding | Severity | What It Means | CIS Control |
|---------|----------|--------------|-------------|
| Pods running as root | CRITICAL | Containers can escape to host | 5.2.6 |
| No NetworkPolicy on namespace | HIGH | Any pod can talk to any pod | 5.4.1 |
| No resource limits | HIGH | Pod can OOM the node | 5.7.7 |
| cluster-admin over-provisioned | HIGH | Too many admin bindings | 5.1.1 |
| Missing seccomp profile | MEDIUM | No syscall filtering | 5.7.2 |
| No readiness/liveness probes | MEDIUM | K8s can't health-check the pod | Best practice |

## What Happens Next

Audit results feed into:
- **Playbook 02** (Hardening) — apply fixes for each finding
- **Playbook 03** (Admission Control) — prevent findings from recurring
- **Playbook 05** (Compliance Report) — before/after comparison as deliverable
