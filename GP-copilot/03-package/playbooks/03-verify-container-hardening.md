# Playbook: Verify Container Hardening

> Confirm that hardening from 01-APP-SEC and 02-CLUSTER-HARDENING is actually applied to running containers.
> Bridges the gap between policy (what should be true) and reality (what is true).
>
> **When:** After deploying any workload. Before enabling auto-fix.
> **Time:** ~5 min

---

## The Principle

Container security is the 3rd layer of the 4 C's (Cloud, Cluster, **Container**, Code):
- **01-APP-SEC** defines image-level hardening (Dockerfile best practices, image scanning)
- **02-CLUSTER-HARDENING** defines runtime constraints (security contexts, admission policies)
- **03-DEPLOY-RUNTIME** verifies it's actually applied to running containers

---

## Step 1: Run the Verifier

```bash
PKG=~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME

# Full cluster scan
bash $PKG/tools/verify-container-hardening.sh

# Skip system namespaces + show fix commands
bash $PKG/tools/verify-container-hardening.sh --skip-system --fix-hints

# Single namespace
bash $PKG/tools/verify-container-hardening.sh --namespace production
```

---

## What It Checks (15 Controls)

| Check | Source Package | Severity | Policy ID |
|-------|---------------|----------|-----------|
| Privileged container | 02-CLUSTER-HARDENING | CRITICAL | CKV_K8S_16, C-0057 |
| Running as UID 0 | 02-CLUSTER-HARDENING | CRITICAL | CKV_K8S_6, C-0013 |
| hostNetwork enabled | 02-CLUSTER-HARDENING | CRITICAL | CKV_K8S_19, C-0041 |
| hostPID enabled | 02-CLUSTER-HARDENING | CRITICAL | CKV_K8S_17, C-0038 |
| runAsNonRoot not set | 02-CLUSTER-HARDENING | HIGH | CKV_K8S_22, C-0013 |
| allowPrivilegeEscalation | 02-CLUSTER-HARDENING | HIGH | CKV_K8S_20, C-0016 |
| Capabilities not dropped | 02-CLUSTER-HARDENING | HIGH | CKV_K8S_28, C-0046 |
| No resource limits | 02-CLUSTER-HARDENING | HIGH | CKV_K8S_13, C-0009 |
| :latest tag | 01-APP-SEC | HIGH | Dockerfile best practice |
| No image tag | 01-APP-SEC | HIGH | Dockerfile best practice |
| readOnlyRootFilesystem | 02-CLUSTER-HARDENING | MEDIUM | CKV_K8S_25, C-0017 |
| No seccomp profile | 02-CLUSTER-HARDENING | MEDIUM | C-0055 |
| No resource requests | 02-CLUSTER-HARDENING | MEDIUM | CKV_K8S_11, C-0009 |
| No liveness probe | 02-CLUSTER-HARDENING | MEDIUM | CKV_K8S_8 |
| No readiness probe | 02-CLUSTER-HARDENING | MEDIUM | CKV_K8S_9 |

---

## Step 2: Fix Violations

The `--fix-hints` flag shows which fixer script or Kyverno policy to apply:

- Security context issues → `02-CLUSTER-HARDENING/tools/hardening/add-security-context.sh`
- Resource limits → `02-CLUSTER-HARDENING/tools/hardening/add-resource-limits.sh`
- Image tags → `01-APP-SEC/fixers/dockerfile/` fixers
- Probes → `02-CLUSTER-HARDENING/tools/hardening/add-probes.sh`

---

## Step 3: Re-verify

```bash
bash $PKG/tools/verify-container-hardening.sh --skip-system
```

**Target:** 100% score before enabling auto-fix in [06-enable-autonomous-agent](06-enable-autonomous-agent.md).

---

## When to Run

- After deploying any workload (Phase 1 verification)
- Before enabling auto-fix in Phase 4
- On a schedule as a drift check (cron or CI)

---

## Next Steps

- Tune Falco → [04-tune-falco.md](04-tune-falco.md)

---

*Ghost Protocol — Runtime Security Package (CKS)*
