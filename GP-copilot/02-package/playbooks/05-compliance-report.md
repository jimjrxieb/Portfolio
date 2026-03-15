# Playbook 05: Compliance Report

> Derived from [GP-CONSULTING/02-CLUSTER-HARDENING/playbooks/08-compliance-report.md](https://github.com/jimjrxieb/GP-copilot)
> Tailored for the Portfolio k3s cluster (portfolioserver)

## What This Does

Generates a before/after compliance report showing what was hardened and how the cluster's security posture improved. This is the client deliverable — proof the engagement produced measurable results.

## Frameworks Covered

| Framework | What It Measures | Portfolio Relevance |
|-----------|-----------------|-------------------|
| **CIS Kubernetes Benchmark v1.8** | 123 controls across 5 sections (control plane, etcd, node, policies, general) | Primary benchmark for k3s hardening |
| **NIST 800-53** | Federal security controls (AC, AU, CM, SC, SI families) | Maps to FedRAMP if client needs compliance |
| **CKS Exam Domains** | Cluster hardening, system hardening, supply chain, runtime, network | Validates CKS-level security |
| **NSA/CISA K8s Guide** | Non-root, read-only FS, resource limits, signed images, network segmentation | Government hardening standard |

## Before/After Comparison Template

| Category | Before | After | Improvement |
|----------|--------|-------|-------------|
| **kubescape risk score** | X/100 | Y/100 | -Z risk |
| **kube-bench pass rate** | X PASS / Y FAIL | X PASS / Y FAIL | +N controls |
| **Polaris score** | X/100 | Y/100 | +Z points |
| **NetworkPolicies** | X namespaces covered | Y namespaces covered | +N policies |
| **LimitRanges** | X namespaces | Y namespaces | +N ranges |
| **ResourceQuotas** | X namespaces | Y namespaces | +N quotas |
| **PSS-labeled namespaces** | X | Y | +N labeled |
| **Pods running as root** | X | Y | -N root pods |
| **Admission control policies** | X enforcing | Y enforcing | +N policies |

## CIS Control Mapping for Portfolio

| CIS Section | Control | Status | Evidence |
|-------------|---------|--------|----------|
| 5.1.1 | RBAC enabled | MET | `kubectl api-versions \| grep rbac` |
| 5.1.3 | Minimize wildcard use | CHECK | RBAC audit output |
| 5.2.1 | No privileged containers | MET | Gatekeeper constraint enforcing |
| 5.2.4 | No root containers | MET | PSS restricted + security contexts |
| 5.2.5 | No privilege escalation | MET | Gatekeeper constraint enforcing |
| 5.2.6 | runAsNonRoot enforced | MET | PSS restricted label |
| 5.2.7 | Capabilities dropped | MET | Security contexts drop ALL |
| 5.4.1 | NetworkPolicy in every NS | CHECK | Audit result |
| 5.7.2 | Seccomp profiles | CHECK | Audit result |
| 5.7.7 | Resource limits | MET | LimitRanges deployed |

## Report Generation

GP-CONSULTING provides `policy-coverage-report.py` which auto-generates this report:

```bash
python3 policy-coverage-report.py \
    --framework all \
    --output compliance-report.md
```

Outputs detailed coverage percentages per framework with evidence pointers.

## What This Proves to a Client/Manager

1. **Measurable improvement** — not just "we hardened things" but specific numbers
2. **Framework alignment** — maps to CIS/NIST/CKS standards they care about
3. **Audit trail** — before/after snapshots with timestamps
4. **Ongoing compliance** — admission control prevents regression
