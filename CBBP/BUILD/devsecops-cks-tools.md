# DevSecOps And CKS Tool Map

This file summarizes the tools and implementation patterns used in the BUILD
phase. The focus is practical: what each tool does, where it appears in the
repo, and what security control it supports.

## CI/CD Security Tools

| Tool | Purpose | Repo evidence | Security value |
|---|---|---|---|
| GitHub Actions | CI/CD orchestration for scans, builds, image pushes, and deployment metadata. | `.github/workflows/main.yml` | Makes security checks part of the deployment path. |
| Semgrep | SAST for Python, JavaScript, secrets, and security-audit rules. | `sast-scanning` job in `main.yml` | Finds code-level security issues before build. |
| Bandit | Python security scanning. | `python-security` job in `main.yml` | Finds risky Python patterns. |
| Safety | Python dependency vulnerability checks. | `python-security` job in `main.yml` | Flags vulnerable Python packages. |
| npm audit | Node dependency vulnerability checks. | `code-quality` job in `main.yml` | Flags vulnerable frontend packages. |
| detect-secrets | Secret detection with a baseline. | `.pre-commit-config.yaml`, `.secrets.baseline`, `secrets-scanning` job | Prevents API keys and credentials from entering commits. |
| Checkov | IaC and Dockerfile security scanning. | `iac-scanning` job in `main.yml` | Reviews infrastructure and container definitions. |
| SonarCloud | Code quality and vulnerability analysis. | `sonarcloud` job in `main.yml` | Adds continuous code-quality and security review. |
| Trivy | Container vulnerability, secret, and config scanning. | `security-scan` job in `main.yml` | Scans built API/UI images before deploy. |
| JSA-CI scanner | CI/CD workflow security review. | `.github/workflows/jsa-ci-security.yml` | Checks workflow permissions, action pinning, secrets, and injection risks. |

## Policy-As-Code Tools

| Tool | Purpose | Repo evidence | Security value |
|---|---|---|---|
| OPA / Rego | Security policy language. | `policies/conftest/*.rego` | Encodes Kubernetes and CI/CD expectations as reviewable policy. |
| Conftest | Runs OPA policies against YAML/manifests. | `.github/workflows/policy-check.yml` | Blocks or warns on insecure manifests before deployment. |
| Helm template validation | Renders chart output for testing. | `policy-check.yml`; `main.yml` validation job | Tests what Kubernetes will actually receive. |
| Gatekeeper setup scripts | Runtime admission-control setup. | `scripts/setup-opa-gatekeeper.sh`; `scripts/demo-policy-enforcement.sh` | Extends policy checks toward cluster admission control. |

## Kubernetes And CKS-Aligned Controls

| CKS area | Tool / control | Repo evidence | Notes |
|---|---|---|---|
| Pod security | Security contexts | `infrastructure/charts/portfolio/values.yaml`, `deployment-api.yaml` | Non-root, no privilege escalation, read-only root filesystem, dropped capabilities. |
| Service account hardening | Token automount disabled | `serviceaccount.yaml`, `values.yaml`, `deployment-api.yaml` | Reduces default Kubernetes API credential exposure. |
| Network policy | Default-deny and allowlist patterns | `infrastructure/charts/portfolio/templates/networkpolicy.yaml`; `infrastructure/shared-security/kubernetes/network-policies/` | Limits pod ingress/egress paths. |
| Boundary protection | ClusterIP services and HTTPRoutes | `service.yaml`, `httproute.yaml` | Public routes target UI/API, not ChromaDB. |
| Resource governance | CPU/memory requests and limits | `values.yaml`; `05-require-resource-limits.rego` | Reduces noisy-neighbor and exhaustion risk. |
| Image security | Trusted registries and tag rules | `policies/conftest/image-security.rego`; `main.yml` image tagging | Reduces supply-chain and rollback ambiguity. |
| Node hardening | Kubelet hardening scripts/config | `infrastructure/shared-security/kubernetes/node-hardening/` | CKS-style node and kubelet security practice. |
| CIS benchmarking | kube-bench remediation script | `infrastructure/shared-security/scripts/kube-bench-remediation.sh` | Supports CIS Kubernetes Benchmark remediation practice. |
| Runtime visibility | Falco references and audit logging | `infrastructure/shared-security/README.md`; `api/sheyla_security/llm_security.py` | Runtime events and AI interactions need review paths. |

## Rego Policy Examples

| Policy file | What it checks |
|---|---|
| `policies/conftest/kubernetes.rego` | Privileged containers, privilege escalation, run-as-root, host networking, host namespaces, latest tags, registry trust. |
| `policies/conftest/03-prohibit-insecure-services.rego` | Blocks NodePort and unauthorized LoadBalancer services. |
| `policies/conftest/05-require-resource-limits.rego` | Requires CPU and memory limits on containers. |
| `policies/conftest/gateway-api.rego` | Checks Gateway/HTTPRoute boundary and TLS expectations. |
| `policies/conftest/image-security.rego` | Enforces trusted registries, tag discipline, and image security expectations. |
| `policies/conftest/secrets-management.rego` | Detects hardcoded secrets and risky secret handling patterns. |
| `policies/conftest/cicd-security.rego` | Models CI/CD pipeline security expectations. |

## DevSecOps Control Chain

| Stage | Control |
|---|---|
| Developer workstation | Pre-commit/pre-push secret and large-file checks. |
| Pull request / push | SAST, dependency scans, secret scans, IaC checks, code quality checks. |
| Manifest review | Helm render plus Conftest policy evaluation. |
| Image build | API/UI Docker images built with repeatable tags. |
| Image review | Trivy vulnerability/config/secret scan. |
| Deployment | Helm values updated and ArgoCD reconciles. |
| Runtime | Kubernetes probes, NetworkPolicy, service boundaries, audit logging. |
| Validation | BREAK tests prove whether the BUILD controls hold. |

## Senior Takeaway

The point of the BUILD phase is repeatability. A control that only exists as a
manual command is fragile. A stronger control is encoded in source, checked by
CI, applied by GitOps, and then validated by BREAK.

That is the DevSecOps lesson this repo is meant to show:

```text
policy -> code -> pipeline -> runtime -> validation -> evidence
```
