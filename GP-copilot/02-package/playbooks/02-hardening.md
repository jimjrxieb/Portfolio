# Playbook 02: Cluster Hardening

> Derived from [GP-CONSULTING/02-CLUSTER-HARDENING/playbooks/03-automated-fixes.md + 04-fix-manifests.md](https://github.com/jimjrxieb/GP-copilot)
> Tailored for the Portfolio k3s cluster (portfolioserver)

## What This Does

Takes the findings from Playbook 01 (Cluster Audit) and applies automated fixes: NetworkPolicies, LimitRanges, ResourceQuotas, PSS labels, and per-deployment security contexts.

## Cluster-Wide Fixes (Automated)

### 1. Default-Deny NetworkPolicies

Every namespace gets a default-deny policy. Traffic is blocked unless explicitly allowed:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: portfolio
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
```

Then explicit allow rules for Portfolio's service topology:
- **UI → API** (port 8000) — frontend calls backend
- **API → ChromaDB** (port 8000) — RAG vector queries
- **API → Ollama** (port 11434) — embedding generation
- **All → DNS** (port 53) — CoreDNS resolution

The script auto-detects services (Vault, Prometheus, ArgoCD) before applying deny rules to avoid breaking cross-namespace communication.

### 2. LimitRanges (Per Namespace)

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: portfolio
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      default:
        cpu: 500m
        memory: 512Mi
```

Prevents any container from running without resource bounds.

### 3. Pod Security Standards (PSS)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: portfolio
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

Native K8s enforcement — no tooling required. Restricted profile blocks privileged containers, root users, host networking, and capability escalation.

### 4. ResourceQuotas

Caps total resource consumption per namespace to prevent noisy-neighbor issues on the single-node cluster.

## Per-Deployment Fixes

| Deployment | Fix Applied | CIS | Before → After |
|------------|-----------|-----|----------------|
| portfolio-api | Security context (runAsNonRoot, drop ALL, readOnly) | 5.2.4-5.2.7 | Missing → Applied |
| portfolio-ui | Security context + resource limits | 5.2.4, 5.7.7 | Missing → Applied |
| portfolio-chroma | Security context (limited — ChromaDB needs write) | 5.2.6 | Root → Non-root |

## CKA/CKS/CNPA Alignment

| Exam Domain | What We Implement |
|------------|-------------------|
| **CKA** — Networking | NetworkPolicy default-deny + explicit allow |
| **CKA** — Scheduling | LimitRanges + ResourceQuotas |
| **CKS** — System Hardening | PSS restricted, security contexts |
| **CKS** — Minimize Attack Surface | Drop ALL capabilities, readOnlyRootFilesystem |
| **CNPA** — Platform Engineering | Guardrails that work without developer action |
