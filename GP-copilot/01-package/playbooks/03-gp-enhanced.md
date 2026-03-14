# Playbook 03: GP-Enhanced Security

> Derived from [GP-CONSULTING/01-APP-SEC](https://github.com/jimjrxieb/GP-copilot) + [GP-CONSULTING/02-CLUSTER-HARDENING](https://github.com/jimjrxieb/GP-copilot)
> This is where GP-Copilot adds value beyond basic scanning — CKA/CKS/CNPA-level security guardrails

## What This Does

After baseline scanning and remediation (Playbooks 01-02), this playbook adds **policy-as-code guardrails** that prevent insecure configurations from ever reaching the cluster. This is the difference between finding problems and preventing them.

## What We Add

### 1. OPA/Conftest Policies (Pre-Deploy Gate)

Rego policies that validate Kubernetes manifests before they're applied. Portfolio runs 13 policies in CI via Conftest:

```rego
# Example: Deny privileged containers across all workload types
# From GP-CONSULTING/02-CLUSTER-HARDENING — block-privileged.rego

deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.securityContext.privileged == true
    msg := sprintf("Privileged container '%s' in Deployment '%s' — " +
        "CIS Kubernetes 5.2.1, NIST AC-6 (Least Privilege)",
        [container.name, input.metadata.name])
}
```

**Policies enforced in Portfolio:**

| Policy | What It Blocks | CIS/NIST Mapping |
|--------|---------------|-----------------|
| Container Security | `privileged: true`, missing `runAsNonRoot`, no resource limits, `hostPID`/`hostIPC`/`hostNetwork` | CIS 5.2.1-5.2.9, NIST AC-6 |
| Image Security | `:latest` tag, untrusted registries, `imagePullPolicy: Never` | CIS 5.5.1, NIST CM-6 |
| Resource Governance | Missing CPU/memory limits, missing health probes | CIS 5.4.1, NIST SC-6 |
| Pod Security Standards | Missing seccomp profile, capability escalation, writable root filesystem | CIS 5.7.1-5.7.4, NIST AC-6 |

### 2. Gatekeeper Constraints (Runtime Admission)

OPA Gatekeeper runs as an admission controller inside the cluster. Even if someone `kubectl apply`s directly (bypassing CI), Gatekeeper blocks it:

```yaml
# ConstraintTemplate: Require resource limits on all containers
# Enforced at admission time — cannot be bypassed

apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredResources
metadata:
  name: require-resource-limits
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet", "DaemonSet"]
  parameters:
    requireCPU: true
    requireMemory: true
```

### 3. Pod Security Standards (PSS)

Namespace-level enforcement that Kubernetes evaluates natively (no additional tooling):

```yaml
# Applied to the portfolio namespace
apiVersion: v1
kind: Namespace
metadata:
  name: portfolio
  labels:
    pod-security.kubernetes.io/enforce: restricted    # Block violations
    pod-security.kubernetes.io/audit: restricted      # Log violations
    pod-security.kubernetes.io/warn: restricted       # Warn on violations
```

**Restricted profile enforces:**
- `runAsNonRoot: true`
- No privilege escalation
- Drop ALL capabilities
- Seccomp profile required
- No hostPath volumes
- No host networking/PID/IPC

### 4. Kyverno Policies (Alternative/Complementary)

For clusters using Kyverno instead of Gatekeeper, we deploy equivalent policies:

```yaml
# Kyverno: Require non-root containers
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-run-as-nonroot
spec:
  validationFailureAction: Audit    # Start in audit, move to Enforce
  rules:
    - name: run-as-non-root
      match:
        any:
          - resources:
              kinds: ["Pod"]
      validate:
        message: "Containers must run as non-root (CIS 5.2.6)"
        pattern:
          spec:
            securityContext:
              runAsNonRoot: true
```

### 5. Network Policies (Zero-Trust Networking)

Default-deny with explicit allow rules:

```yaml
# Default deny all ingress + egress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: portfolio
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
```

Then explicit rules: UI → API (port 8000), API → ChromaDB (port 8000), API → Ollama (port 11434).

## CKA/CKS/CNPA Alignment

| Exam Domain | What We Implement | Evidence |
|------------|-------------------|---------|
| **CKA** — Cluster Architecture | RBAC scoping, resource quotas, namespace isolation | `infrastructure/shared-security/kubernetes/rbac/` |
| **CKS** — Supply Chain Security | Image pinning, Trivy scanning, OPA admission control | `main.yml` security-scan stage, Conftest policies |
| **CKS** — System Hardening | PSS enforcement, seccomp profiles, AppArmor | Namespace labels, security contexts |
| **CKS** — Minimize Microservice Vulnerabilities | NetworkPolicy, Secrets encryption, least-privilege RBAC | `default-deny-all.yaml`, RBAC roles |
| **CNPA** — Platform Engineering | GitOps (ArgoCD), IDP patterns, developer guardrails | ArgoCD Application CRD, pre-commit hooks |

## What This Means for Portfolio

Before GP-Enhanced:
- Scanners find problems **after** code is written
- Nothing stops a bad manifest from reaching the cluster

After GP-Enhanced:
- OPA policies block bad manifests **in CI** (Conftest)
- Gatekeeper blocks bad manifests **at admission** (even kubectl)
- PSS blocks bad pods **at the namespace level** (native K8s)
- Network policies enforce **zero-trust between services**
- Two independent layers: CI gate + runtime admission = defense in depth
