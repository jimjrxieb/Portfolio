# Playbooks — Step-by-Step Guides

> Each playbook walks through one specific workflow using the scripts in `tools/` and `fixers/`.
>
> **Three-tier rule:** Runbook (diagnose) → Script (automate) → Playbook (guide)

---

## Playbook Index

| # | Playbook | When to Use | Time | Type |
|---|----------|-------------|------|------|
| 01 | [Baseline Scan](01-baseline-scan.md) | First day of any engagement | ~15 min | Industry Standard |
| 02 | [Fix Secrets](02-fix-secrets.md) | Gitleaks/Bandit found hardcoded secrets | ~30 min | **GP-Copilot** |
| 03 | [Fix Dependencies](03-fix-dependencies.md) | Trivy/Grype found CVEs | ~20 min | **GP-Copilot** |
| 04 | [Fix Python SAST](04-fix-python-sast.md) | Bandit/Semgrep found code issues | ~20 min | **GP-Copilot** |
| 05 | [Fix Dockerfiles](05-fix-dockerfiles.md) | Hadolint/Trivy found Dockerfile issues | ~10 min/file | **GP-Copilot** |
| 06 | [Fix Web Security](06-fix-web-security.md) | ZAP/Nuclei found DAST issues | ~15 min | **GP-Copilot** |
| 07 | [Deploy CI Pipeline](07-deploy-ci-pipeline.md) | After fixes, prevent regression | ~10 min | Industry Standard |
| 08 | [Deploy Pre-Commit](08-deploy-pre-commit.md) | Shift-left to developer workstations | ~5 min | Industry Standard |
| 09 | [Post-Fix Rescan](09-post-fix-rescan.md) | Prove the work, produce deliverable | ~15 min | Industry Standard |
| 10 | [Fix K8s Manifests](10-fix-k8s-manifests.md) | Checkov/Kubescape K8s findings | ~20 min | **GP-Copilot** |
| 11 | [Fix Supply Chain](11-fix-supply-chain.md) | Supply chain security | ~15 min | **GP-Copilot** |
| 12 | [Deploy Dev](12-deploy-dev.md) | Deploy to dev/ cluster with Helm | ~15-20 min | **GP-Copilot** |

### What's the difference?

**Industry Standard** = Any security team should be doing this. Running scanners, setting up CI gates, pre-commit hooks, rescanning after fixes. These are best practices — we just make them easier with scripts and playbooks.

**GP-Copilot Value-Add** = This is what we bring to the table. The scanners find problems — everyone has scanners. GP-Copilot writes the fixer scripts, generates the remediation patches, and auto-applies E/D rank fixes. The client pays for the fix, not the scan.

---

## Typical Engagement Flow

```
01-baseline-scan
  ├── 02-fix-secrets        (if secrets found)
  ├── 03-fix-dependencies   (if CVEs found)
  ├── 04-fix-python-sast    (if Python SAST findings)
  ├── 05-fix-dockerfiles    (if Dockerfile issues)
  ├── 06-fix-web-security   (if DAST findings)
  ├── 07-deploy-ci-pipeline (prevent regression)
  ├── 08-deploy-pre-commit  (shift-left to devs)
  ├── 09-post-fix-rescan    (prove the work)
  ├── 10-fix-k8s-manifests  (if K8s manifest findings)
  ├── 11-fix-supply-chain   (if supply chain findings)
  └── 12-deploy-dev         (deploy hardened code to dev)
```

---

## Where Things Live

| Layer | Directory | What It Is |
|-------|-----------|-----------|
| **Playbooks** | `playbooks/` (you are here) | Step-by-step guides |
| **Scripts** | `tools/` | Automation (`run-all-scanners.sh`, `triage.py`) |
| **Fixers** | `fixers/` | Per-finding fix scripts (secrets, python, dockerfile, web, deps) |
| **Scanner Configs** | `scanning-configs/` | Drop-in configs for all scanners |
| **CI Templates** | `ci-templates/` | GitHub Actions workflows |
| **Pre-commit** | `pre-commit-hooks/` | Pre-commit hook configs + installer |

---

*Ghost Protocol — Pre-Deployment Security Package*
