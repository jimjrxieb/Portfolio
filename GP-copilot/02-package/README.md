# 02 — Cluster Hardening Package

What was hardened, how it's enforced, and what to do when violations are found.

---

## Coverage Summary

| Layer | What | Enforcement Point |
|-------|------|-------------------|
| **CI/CD (shift-left)** | 5 OPA/Rego policies block bad manifests before merge | `policy-check.yml` on every PR |
| **Admission control** | 4 Gatekeeper constraints reject non-compliant resources at deploy time | OPA Gatekeeper in `gatekeeper-system` namespace |
| **Cluster audit** | 5-tool scan (kubescape, kube-bench, polaris, RBAC, resource cliff) | On-demand via `run-cluster-audit.sh` |
| **Remediation** | Copy-paste fix templates for every finding category | `remediation-templates/` |

---

## Policies Delivered

### CI/CD Policies (`conftest-policies/`)

Evaluated by conftest against every Kubernetes manifest in PRs and in the main pipeline.

| Policy | What It Catches | Compliance |
|--------|----------------|------------|
| `container-security.rego` | Root UID, missing security context, no resource limits | CIS 5.2.6, PSS Restricted |
| `block-privileged.rego` | Privileged mode, host namespaces | CIS 5.2.1, PSS Baseline |
| `image-security.rego` | Untagged images, `:latest`, untrusted registries | CIS 5.5.1, NIST CM-7 |
| `secrets-management.rego` | Secrets in env vars, hardcoded creds, SA token automount, volume permissions | CIS 5.4.1, SOC2 CC6.1, NIST SC-28, PCI-DSS 3.4 |
| `service-security.rego` | NodePort and LoadBalancer services (must use ClusterIP + Ingress) | NIST 800-53 SC-7 |

Tests: `conftest-policies/tests/` — run with `conftest verify`.

### Admission Control (`gatekeeper-constraints/`)

Deployed to the cluster. These are the last line of defense — if something bypasses CI, Gatekeeper blocks it at the API server.

| Constraint | What It Blocks |
|------------|----------------|
| `container-security.yaml` | Containers without security contexts, running as root |
| `image-security.yaml` | Images from untrusted registries, missing tags |
| `pod-security-standards.yaml` | Privilege escalation, host PID/network, unsafe sysctls |
| `resource-limits.yaml` | Pods without CPU/memory requests and limits |

---

## When a Violation Is Found

Each finding category maps to a remediation template. The audit script references these directly in its report output.

| Finding | Fix Template | What It Contains |
|---------|-------------|------------------|
| Running as root / privilege escalation | `remediation-templates/pod-security-context.yaml` | PSS restricted pod template, 8 deployment patches (non-root, drop caps, read-only FS, etc.) |
| No resource limits / OOM risk | `remediation-templates/resource-management.yaml` | LimitRange (namespace defaults) + ResourceQuota (hard caps) |
| No NetworkPolicy / flat network | `remediation-templates/network-policies.yaml` | 9 templates: default-deny, DNS egress, same-namespace, ingress controller, external HTTPS, database, prometheus, quarantine |

---

## Hardening Tools Used

These tools assess the cluster against CKS and CKA benchmarks.

| Tool | Standard | What It Measures |
|------|----------|------------------|
| **Kubescape** | NSA/CISA + MITRE ATT&CK | Overall cluster risk score, failing controls |
| **kube-bench** | CIS Kubernetes Benchmark | Control plane, etcd, kubelet, policies — pass/fail/warn per check |
| **Polaris** | Fairwinds best practices | Deployment config scoring (security, reliability, efficiency) |
| **Conftest** | Custom OPA/Rego | Manifest-level policy validation (the 5 policies above) |
| **Trivy** | CVE databases | Container image vulnerabilities + SBOM generation |
| **OPA Gatekeeper** | Custom constraints | Runtime admission control (the 4 constraints above) |

---

## How to Run

```bash
# Full cluster audit — produces a markdown report
bash GP-copilot/02-package/tools/run-cluster-audit.sh

# Policy check against local manifests (Helm chart + infrastructure YAMLs)
bash GP-copilot/02-package/tools/test-policies.sh

# Test a single manifest
conftest test <file>.yaml --policy GP-copilot/02-package/conftest-policies/ --all-namespaces

# Policy unit tests
conftest verify --policy GP-copilot/02-package/conftest-policies/
```

## CI/CD Enforcement

Two workflows enforce these policies automatically:

- **`policy-check.yml`** — Triggers on PRs that touch `infrastructure/**/*.yaml` or policy files. Renders Helm charts, runs conftest, blocks merge on violations.
- **`main.yml`** (`validate-k8s` job) — Runs conftest as part of the main pipeline on pushes to `main`.

---

## Package Contents

```
02-package/
├── conftest-policies/               5 OPA/Rego policies + tests + fixtures
├── gatekeeper-constraints/          4 admission control constraint templates
├── remediation-templates/           Fix templates (pod security, resources, network)
└── tools/                           Cluster audit script + local policy runner
```
