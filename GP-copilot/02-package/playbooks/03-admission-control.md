# Playbook 03: Admission Control & Policy-as-Code

> Derived from [GP-CONSULTING/02-CLUSTER-HARDENING/playbooks/05-deploy-admission-control.md + 07-audit-to-enforce.md](https://github.com/jimjrxieb/GP-copilot)
> Tailored for the Portfolio k3s cluster (portfolioserver)

## What This Does

Deploys admission controllers (Gatekeeper/Kyverno) that validate every `kubectl apply` against security policies. This is the layer that **prevents** insecure configs from reaching the cluster — even if someone bypasses CI.

## What's Running on Portfolio

Portfolio uses **OPA Gatekeeper** (already deployed in `gatekeeper-system` namespace):

```bash
kubectl get pods -n gatekeeper-system
# gatekeeper-audit-*        → Audits existing resources
# gatekeeper-controller-*   → Validates new admissions
```

## Policies Enforced

### Conftest (CI Gate — 13 Policies)

These run in GitHub Actions during `validate-k8s` stage. Helm renders → Conftest validates:

| Policy | What It Blocks | CIS |
|--------|---------------|-----|
| Privileged containers | `securityContext.privileged: true` | 5.2.1 |
| Privilege escalation | `allowPrivilegeEscalation: true` | 5.2.5 |
| Root user | Missing `runAsNonRoot: true` | 5.2.6 |
| Host namespaces | `hostNetwork`, `hostPID`, `hostIPC` | 5.2.2-4 |
| Latest tag | `:latest` or missing image tag | Supply chain |
| HostPath volumes | Volume mounts from host filesystem | 5.2.8 |
| Dangerous capabilities | `SYS_ADMIN`, `NET_ADMIN`, `SYS_PTRACE` | 5.2.7 |
| Missing resource limits | No CPU/memory limits | 5.7.7 |
| Missing probes | No liveness/readiness probes | Best practice |
| Cluster-admin binding | ClusterRoleBinding to cluster-admin | 5.1.1 |

### Gatekeeper (Runtime Admission)

Even if someone `kubectl apply`s directly, Gatekeeper blocks:

| Constraint | Action | Excluded Namespaces |
|-----------|--------|-------------------|
| block-privileged-containers | deny | kube-system, gatekeeper-system |
| require-non-root | deny | kube-system, gatekeeper-system |
| block-latest-tag | deny | kube-system |
| require-resource-limits | deny | kube-system, gatekeeper-system |
| block-host-namespaces | deny | kube-system |

## Progressive Enforcement Strategy

GP-CONSULTING uses a 3-week rollout:

| Week | Phase | What Changes |
|------|-------|-------------|
| **Week 1** | Audit (observe) | Policies log violations but don't block. Review PolicyReports. |
| **Week 2** | Enforce Critical | `disallow-privileged`, `disallow-privilege-escalation`, `require-run-as-nonroot` switch to Enforce |
| **Week 3** | Enforce All | Remaining policies switch to Enforce |

**Rollback:** Any single policy can revert to Audit independently if it breaks a workload.

## Defense in Depth (3 Independent Layers)

```
Layer 1: Conftest in CI         → Blocks bad manifests at PR time
Layer 2: Gatekeeper at admission → Blocks bad manifests at apply time
Layer 3: PSS on namespace        → Blocks bad pods at schedule time
```

All three must agree. A bad manifest has to bypass CI, bypass Gatekeeper, AND bypass PSS to run on the cluster. That doesn't happen accidentally.

## Kyverno Alternative

For clients preferring Kyverno (YAML-native, no Rego), GP-CONSULTING provides 13 equivalent ClusterPolicies:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged
spec:
  validationFailureAction: Audit  # → Enforce after observation
  rules:
    - name: privileged-containers
      match:
        any:
          - resources:
              kinds: ["Pod"]
      validate:
        message: "Privileged containers are not allowed (CIS 5.2.1)"
        pattern:
          spec:
            containers:
              - securityContext:
                  privileged: "!true"
```
