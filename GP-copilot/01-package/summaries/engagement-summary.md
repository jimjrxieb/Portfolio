# 01-APP-SEC Engagement Summary — Portfolio

**Client:** Portfolio (linksmlm.com)
**Package:** 01-APP-SEC (Pre-Deploy Application Security)
**Date:** 2026-03-14
**Performed by:** GP-Copilot platform using GP-CONSULTING/01-APP-SEC playbooks

## Executive Summary

GP-Copilot ran a full pre-deploy security assessment against the Portfolio application — a production React + FastAPI platform deployed via ArgoCD GitOps on a dedicated k3s server. The assessment used 7 automated security scanners, identified 73 unique findings across 6 severity categories, and determined that 31 (42%) are auto-fixable using GP-CONSULTING fixer scripts.

**Key finding: The application code is clean.** Zero HIGH/CRITICAL vulnerabilities in Python or JavaScript. All findings are in infrastructure-as-code and transitive npm dependencies.

## What Was Scanned

| Layer | Target | Scanner(s) |
|-------|--------|-----------|
| Source code | `api/`, `backend/`, `ui/src/`, `rag-pipeline/` | Semgrep, Bandit |
| Secrets | Entire repository | Gitleaks |
| Dependencies | `requirements.txt`, `package-lock.json` | Trivy |
| Dockerfiles | `api/Dockerfile`, `ui/Dockerfile`, `data/chromadb-config/Dockerfile` | Hadolint |
| Infrastructure | Terraform modules, K8s manifests, Helm charts, GitHub Actions | Checkov |

## Results at a Glance

```
234 raw findings → 73 unique (after deduplication)

CRITICAL:  6  (all secrets — test/example data, not real exposure)
HIGH:      5  (4 npm CVEs in tar@7.5.6, 1 Dockerfile :latest tag)
MEDIUM:   59  (IaC: Terraform AWS + K8s manifests + GHA permissions)
LOW:       3  (Dockerfile lint: pin versions, shell quoting)

Auto-fixable: 31 (42%)
Manual:       42 (58%)
```

## Playbooks Executed

| Playbook | Status | Result |
|----------|--------|--------|
| 01-baseline-scan | Complete | 73 unique findings across 7 scanners |
| 02-remediation-plan | Complete | Triage map with fixer commands for all 31 auto-fixable findings |
| 03-gp-enhanced | Active | 13 OPA/Conftest policies running in CI, Gatekeeper on cluster |
| 04-cicd-pipeline | Complete | 8-scanner parallel pipeline, ArgoCD GitOps, auto image tag updates |
| 05-monitor | Active | Pipeline health monitoring, ArgoCD sync tracking |

## What GP-Copilot Added

### Already in place (before engagement):
- 8-scanner CI pipeline (Semgrep, Bandit, Safety, detect-secrets, Checkov, Trivy, SonarCloud, npm audit)
- ArgoCD GitOps deployment
- Non-root containers
- Security headers (CSP, HSTS, X-Frame-Options)

### Added by GP-CONSULTING:
- 13 OPA/Conftest policies validating K8s manifests in CI
- Gatekeeper runtime admission control on cluster
- Pod Security Standards (restricted) on portfolio namespace
- Network policies (default-deny + explicit allow)
- Automated baseline scan with `run-all-scanners.sh`
- Triage automation with `triage.py` (234 → 73 deduplication)
- Fixer script mapping for 31 auto-fixable findings
- Before/after scan comparison as proof of work

## Recommendations

1. **Immediate (P1):** Bump `tar` to `>=7.5.11` — resolves all 4 HIGH CVEs
2. **Short-term (P2):** Harden Terraform AWS modules (encryption, versioning, logging)
3. **Short-term (P2):** Add security contexts to Helm chart templates (ChromaDB, API, UI)
4. **Ongoing:** Promote advisory scanners (Bandit, Trivy, Checkov) to blocking in CI
5. **Future:** Add DAST scanning (ZAP/Nuclei) against staging environment

## Deliverables

| Deliverable | Location |
|-------------|----------|
| Baseline scan results | `outputs/baseline-scan-20260314.md` |
| Post-fix scan results | `outputs/post-fix-scan-20260314.md` |
| Remediation plan | `GP-S3/5-consulting-reports/02-instance/slot-3/baseline-20260314/REMEDIATION-PLAN.md` |
| Raw scanner output (JSON) | `GP-S3/5-consulting-reports/02-instance/slot-3/baseline-20260314/*.json` |
| Playbooks | `playbooks/01-05` |
