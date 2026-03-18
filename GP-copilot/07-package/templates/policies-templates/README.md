# FedRAMP Policy Templates

Defense-in-depth policies that enforce FedRAMP NIST 800-53 controls at CI, admission, and runtime.

## Policy Stack

| Layer | Tool | Usage | Controls |
|-------|------|-------|----------|
| **CI/CD** | Conftest/OPA | `conftest test manifests/ --policy policies/conftest/` | AC-2, AC-6, AU-2, CM-6, SC-7 |
| **Admission** | Kyverno | `kubectl apply -f policies/kyverno/` | AC-6, CM-6 |
| **Admission** | Gatekeeper | `kubectl apply -f policies/gatekeeper/` | AC-6, CM-6 |

## Conftest (CI)

12 rules validating Kubernetes manifests before merge:

```bash
conftest test your-manifests/ --policy policies/conftest/
```

## Kyverno (Admission)

5 ClusterPolicies enforcing at deploy time:

| Policy | Control | What It Blocks |
|--------|---------|---------------|
| `require-run-as-nonroot.yaml` | AC-6 | Containers running as root |
| `require-resource-limits.yaml` | CM-6 | Missing CPU/memory limits |
| `require-drop-all.yaml` | AC-6 | Missing capability drops |
| `disallow-privilege-escalation.yaml` | AC-6 | setuid/setgid escalation |
| `disallow-privileged.yaml` | AC-6 | Privileged container mode |

## Gatekeeper (Admission)

3 ConstraintTemplates with matching constraints:

| Template | Control | What It Blocks |
|----------|---------|---------------|
| `FedRAMPNoPrivileged` | AC-6 | Privileged containers |
| `FedRAMPResourceLimits` | CM-6 | Missing resource limits |
| `FedRAMPRunAsNonRoot` | AC-6 | Root containers |

## Choose Your Admission Controller

Use **either** Kyverno or Gatekeeper, not both. Kyverno is simpler to configure; Gatekeeper is more powerful with Rego.
