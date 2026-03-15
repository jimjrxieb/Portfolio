# Playbook 02: Verify Container Hardening

> Derived from [GP-CONSULTING/03-DEPLOY-RUNTIME/playbooks/03-verify-container-hardening.md](https://github.com/jimjrxieb/GP-copilot)
> Tailored for the Portfolio k3s cluster (portfolioserver)

## What This Does

Audits that the hardening from 01-APP-SEC + 02-CLUSTER-HARDENING is actually applied to running containers. There's a difference between "the Helm chart says runAsNonRoot" and "the running pod is actually non-root." This playbook verifies the live state.

## 15 Runtime Checks

| # | Check | Severity | CIS | NIST | What We're Looking For |
|---|-------|----------|-----|------|----------------------|
| 1 | Privileged container | CRITICAL | 5.2.1 | CM-6 | `securityContext.privileged != true` |
| 2 | Running as UID 0 | CRITICAL | 5.2.4 | AC-6 | Process not running as root inside container |
| 3 | hostNetwork enabled | CRITICAL | 5.2.5 | SC-7 | Pod not sharing host network stack |
| 4 | hostPID enabled | CRITICAL | 5.2.6 | SC-7 | Pod not sharing host PID namespace |
| 5 | runAsNonRoot not set | HIGH | 5.2.4 | AC-6 | Security context explicitly sets non-root |
| 6 | allowPrivilegeEscalation | HIGH | 5.2.10 | CM-6 | Set to `false` |
| 7 | Capabilities not dropped | HIGH | 5.2.7 | CM-6 | `drop: ["ALL"]` present |
| 8 | No resource limits | HIGH | 5.1.5 | SI-2 | CPU + memory limits defined |
| 9 | `:latest` tag | HIGH | — | CM-6 | Image pinned to specific version |
| 10 | No image tag | HIGH | — | CM-6 | Image has explicit tag |
| 11 | readOnlyRootFilesystem | MEDIUM | 5.2.3 | CM-6 | Container filesystem is read-only |
| 12 | No seccomp profile | MEDIUM | 5.3.5 | CM-6 | RuntimeDefault seccomp applied |
| 13 | No resource requests | MEDIUM | 5.1.5 | SI-2 | CPU + memory requests defined |
| 14 | No liveness probe | MEDIUM | — | — | K8s can detect crashes |
| 15 | No readiness probe | MEDIUM | — | — | K8s routes traffic only to ready pods |

## Portfolio Workloads to Verify

| Deployment | Namespace | Expected State |
|------------|-----------|---------------|
| portfolio-portfolio-app-api | portfolio | Non-root, drop ALL, resource limits, probes |
| portfolio-portfolio-app-ui | portfolio | Non-root, drop ALL, resource limits, read-only FS |
| portfolio-portfolio-app-chroma | portfolio | Non-root (ChromaDB needs write access for data dir) |

## Target

**100% pass rate** before enabling autonomous response (Playbook 03). If hardening is incomplete, Falco will fire false positives on every legitimate operation.
