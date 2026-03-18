# Policy Coverage Matrix

> **Comprehensive Security Policy Coverage**
>
> CKS Policy Framework

---

## Coverage Summary

| Category | Policies | Conftest | Gatekeeper | Kyverno |
|----------|----------|----------|------------|---------|
| Pod Security | 10 | 10 | 8 | 8 |
| Supply Chain | 3 | 3 | 3 | 2 |
| Resources | 4 | 4 | 2 | 2 |
| Filesystem | 2 | 2 | 1 | 1 |
| Network | 2 | 2 | - | - |
| RBAC | 2 | 2 | 1 | - |
| Availability | 3 | 3 | - | 2 |
| **Total** | **26** | **26** | **15** | **15** |

---

## Detailed Policy Matrix

### Pod Security Standards (PSS)

| Policy | Severity | Conftest | Gatekeeper | Kyverno | Runtime |
|--------|----------|----------|------------|---------|---------|
| Block privileged containers | CRITICAL | `deny` | K8sBlockPrivileged | disallow-privileged-containers | Falco |
| Block privilege escalation | CRITICAL | `deny` | K8sBlockPrivilegeEscalation | disallow-privilege-escalation | Falco |
| Require runAsNonRoot | HIGH | `deny` | K8sRequireNonRoot | require-run-as-nonroot | Falco |
| Block hostNetwork | HIGH | `deny` | K8sBlockHostNamespaces | disallow-host-namespaces | Falco |
| Block hostPID | HIGH | `deny` | K8sBlockHostNamespaces | disallow-host-namespaces | Falco |
| Block hostIPC | HIGH | `deny` | K8sBlockHostNamespaces | disallow-host-namespaces | Falco |
| Drop ALL capabilities | HIGH | `warn` | - | add-default-securitycontext (mutation) | - |
| Block SYS_ADMIN | CRITICAL | `deny` | - | - | Falco |
| Block NET_ADMIN | CRITICAL | `deny` | - | - | Falco |
| Block SYS_PTRACE | CRITICAL | `deny` | - | - | Falco |

### Supply Chain Security

| Policy | Severity | Conftest | Gatekeeper | Kyverno | Runtime |
|--------|----------|----------|------------|---------|---------|
| Block :latest tag | HIGH | `deny` | K8sBlockLatestTag | disallow-latest-tag | - |
| Require image tag | HIGH | `deny` | K8sBlockLatestTag | - | - |
| Allowed registries only | MEDIUM | `warn` | K8sAllowedRegistries | - | - |

### Resource Management

| Policy | Severity | Conftest | Gatekeeper | Kyverno | Runtime |
|--------|----------|----------|------------|---------|---------|
| Require memory limits | MEDIUM | `warn` | K8sRequireLimits | require-resource-limits | - |
| Require CPU limits | MEDIUM | `warn` | K8sRequireLimits | require-resource-limits | - |
| Require memory requests | MEDIUM | `warn` | - | - | - |
| Require CPU requests | LOW | `warn` | - | - | - |

### Filesystem Security

| Policy | Severity | Conftest | Gatekeeper | Kyverno | Runtime |
|--------|----------|----------|------------|---------|---------|
| Block hostPath volumes | HIGH | `deny` | - | disallow-host-path | Falco |
| Recommend readOnlyRootFilesystem | MEDIUM | `warn` | - | - | - |

### Network Security

| Policy | Severity | Conftest | Gatekeeper | Kyverno | Runtime |
|--------|----------|----------|------------|---------|---------|
| Warn on externalIPs | MEDIUM | `warn` | - | - | - |
| Recommend NetworkPolicy | LOW | `warn` | - | - | - |

### RBAC Security

| Policy | Severity | Conftest | Gatekeeper | Kyverno | Runtime |
|--------|----------|----------|------------|---------|---------|
| Block cluster-admin binding | HIGH | `deny` | - | - | Audit |
| Warn on wildcard permissions | MEDIUM | `warn` | - | - | Audit |

### Availability

| Policy | Severity | Conftest | Gatekeeper | Kyverno | Runtime |
|--------|----------|----------|------------|---------|---------|
| Require liveness probes | MEDIUM | `warn` | - | require-probes (audit) | - |
| Require readiness probes | MEDIUM | `warn` | - | require-probes (audit) | - |
| Require app labels | LOW | `warn` | K8sRequireLabels | require-labels (audit) | - |

---

## Policy Details by Tool

### Conftest Policies (kubernetes.rego)

```
Package: kubernetes

deny rules (block PR):
├── privileged containers (Pod, Deployment, StatefulSet, DaemonSet, Job)
├── privilege escalation
├── root user (missing runAsNonRoot)
├── hostNetwork
├── hostPID
├── hostIPC
├── :latest tag
├── missing image tag
├── hostPath volumes
├── dangerous capabilities (SYS_ADMIN, NET_ADMIN, etc.)
└── cluster-admin binding

warn rules (warn on PR):
├── untrusted registries
├── missing memory limits
├── missing CPU limits
├── missing memory requests
├── missing drop ALL capabilities
├── missing readOnlyRootFilesystem
├── externalIPs on Services
├── missing NetworkPolicy for namespaces
├── missing liveness probes
├── missing readiness probes
└── wildcard RBAC permissions
```

### Gatekeeper Constraints

| Constraint | Template | Action |
|------------|----------|--------|
| block-privileged-containers | K8sBlockPrivileged | deny |
| require-non-root | K8sRequireNonRoot | deny |
| block-latest-tag | K8sBlockLatestTag | deny |
| require-resource-limits | K8sRequireLimits | deny |
| block-host-namespaces | K8sBlockHostNamespaces | deny |
| allowed-registries | K8sAllowedRegistries | deny |
| block-privilege-escalation | K8sBlockPrivilegeEscalation | deny |
| require-app-labels | K8sRequireLabels | audit |

### Kyverno Policies

| Policy | Type | Action |
|--------|------|--------|
| disallow-privileged-containers | ClusterPolicy | Enforce |
| disallow-privilege-escalation | ClusterPolicy | Enforce |
| require-run-as-nonroot | ClusterPolicy | Enforce |
| disallow-latest-tag | ClusterPolicy | Enforce |
| require-resource-limits | ClusterPolicy | Enforce |
| disallow-host-namespaces | ClusterPolicy | Enforce |
| disallow-host-path | ClusterPolicy | Enforce |
| require-labels | ClusterPolicy | Audit |
| require-probes | ClusterPolicy | Audit |
| add-default-securitycontext | ClusterPolicy | Mutate |

---

## Compliance Framework Mapping

### CIS Kubernetes Benchmark v1.8.0

| CIS Control | Policy |
|-------------|--------|
| 5.2.1 | Block privileged containers |
| 5.2.2 | Block hostPID |
| 5.2.3 | Block hostIPC |
| 5.2.4 | Block hostNetwork |
| 5.2.5 | Block privilege escalation |
| 5.2.6 | Require runAsNonRoot |
| 5.2.7 | Drop ALL capabilities |
| 5.2.8 | Block dangerous capabilities |
| 5.2.9 | Block hostPath |
| 5.2.10 | Block hostPort |
| 5.2.11 | Limit AppArmor profiles |
| 5.2.12 | Limit Seccomp profiles |
| 5.4.1 | Require NetworkPolicy |
| 5.7.1 | Require resource limits |

### NSA/CISA Kubernetes Hardening Guide

| Control | Policy |
|---------|--------|
| Use containers built to run as non-root | require-run-as-nonroot |
| Use read-only file systems | readOnlyRootFilesystem |
| Limit container resources | require-resource-limits |
| Use signed images | (future: image signatures) |
| Use private registries | allowed-registries |
| Implement network segmentation | NetworkPolicy |
| Scan images for vulnerabilities | (jsa-devsec) |

### MITRE ATT&CK for Containers

| Technique | Detection Policy |
|-----------|------------------|
| T1611 Escape to Host | Block privileged, hostPID, hostNetwork |
| T1610 Deploy Container | allowed-registries |
| T1612 Build Image on Host | (runtime: Falco) |
| T1613 Container & Resource Discovery | (runtime: Falco) |
| T1609 Container Admin Command | Block privilege escalation |

---

## Excluded Namespaces

All policies exclude these namespaces by default:

| Namespace | Reason |
|-----------|--------|
| kube-system | System components require privileges |
| gatekeeper-system | Gatekeeper needs access |
| gp-security | Security tools need access |
| falco-system | Falco needs kernel access |
| kyverno | Kyverno needs access |

---

## Adding Custom Policies

### Conftest

Add new rules to `kubernetes.rego`:

```rego
deny[msg] {
  input.kind == "Deployment"
  some condition
  msg := "Custom violation message"
}
```

### Gatekeeper

1. Create ConstraintTemplate
2. Create Constraint instance

### Kyverno

Add new ClusterPolicy:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: custom-policy
spec:
  validationFailureAction: Enforce
  rules:
    - name: custom-rule
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Custom violation message"
        pattern:
          spec:
            # pattern here
```

---

*Part of the CKS Policy Framework*
