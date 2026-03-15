# Baseline Scan Results — Portfolio

**Date:** 2026-03-14
**Target:** Portfolio application (linksmlm.com)
**Scanners:** 7 of 13 available (Gitleaks, Bandit, Semgrep, Trivy, Hadolint, Checkov, findings.csv)
**Source:** `GP-S3/5-consulting-reports/02-instance/slot-3/baseline-20260314/`

## Aggregate Findings

**234 raw findings → 73 unique** (after deduplication)

| Severity | Count | Auto-Fixable | Manual |
|----------|-------|-------------|--------|
| CRITICAL | 6 | 6 | 0 |
| HIGH | 5 | 5 | 0 |
| MEDIUM | 59 | 20 | 39 |
| LOW | 3 | 0 | 3 |
| **Total** | **73** | **31** | **42** |

## Findings by Scanner

### Gitleaks (Secrets) — 132 raw matches, 6 unique CRITICAL

| Finding | File | Severity |
|---------|------|----------|
| generic-api-key | `.secrets.baseline:303` | CRITICAL |
| stripe-access-token | `rag-pipeline/.../sanitize_npc.py:465` | CRITICAL |
| generic-api-key | `.env:25` | CRITICAL |
| github-pat | `.env:39` | CRITICAL |
| database-connection-string | `GP-copilot/security-before-after-examples.yaml:616` | CRITICAL |
| hashicorp-tf-password | `terraform/secure.tf:282` | CRITICAL |

> Note: 132 raw matches deduplicate to 6 unique secrets. Many are repeated across files or represent the same credential in different contexts.

### Trivy (CVEs) — 4 HIGH vulnerabilities

| CVE | Package | Version | Fixed In | Severity |
|-----|---------|---------|----------|----------|
| CVE-2026-24842 | tar (npm) | 7.5.6 | 7.5.7 | HIGH |
| CVE-2026-26960 | tar (npm) | 7.5.6 | 7.5.8 | HIGH |
| CVE-2026-29786 | tar (npm) | 7.5.6 | 7.5.10 | HIGH |
| CVE-2026-31802 | tar (npm) | 7.5.6 | 7.5.11 | HIGH |

All 4 CVEs affect the same package (`tar@7.5.6` in `ui/package-lock.json`). Single dependency bump to `7.5.11` resolves all.

### Semgrep (SAST) — 4 findings

| Rule | File | Severity |
|------|------|----------|
| aws-provider-static-credentials | `terraform/.../main.tf` | MEDIUM |
| aws-dynamodb-table-unencrypted | `terraform/.../storage/main.tf` | MEDIUM |
| 2 additional | Terraform modules | MEDIUM |

### Hadolint (Dockerfile) — 7 findings across 3 Dockerfiles

| Dockerfile | Findings | Key Issues |
|------------|----------|-----------|
| `api/Dockerfile` | 2 | DL3008 (pin apt versions), DL3013 (pin pip) |
| `ui/Dockerfile` | 1 | SC2016 (shell quoting) |
| `data/chromadb-config/Dockerfile` | 4 | DL3007 (latest tag), DL3008, DL3015, SC2015 |

### Checkov (IaC) — 53 findings

| Category | Count | Key Rules |
|----------|-------|-----------|
| K8s manifests (kubectl) | 9 | CKV_K8S_43 (service account), CKV_K8S_15 (pull policy), CKV_K8S_35 (env secrets) |
| K8s manifests (Helm) | 16 | CKV_K8S_22/25 (security context), CKV_K8S_43, CKV_K8S_15, CKV_K8S_21/38/40 |
| Terraform (AWS) | 12 | CKV_AWS_27/28/145/149/338, CKV2_AWS_6/57/61/62/64 |
| Terraform (K8s) | 5 | CKV_K8S_14/15/35/43 |
| Dockerfiles | 4 | CKV_DOCKER_2 (USER), CKV_DOCKER_3 (HEALTHCHECK), CKV_DOCKER_7 (digest) |
| GitHub Actions | 4 | CKV_GHA_7, CKV2_GHA_1 (permissions) |
| Other | 3 | Various |

### Bandit (Python SAST) — 1 finding

| Rule | File | Severity |
|------|------|----------|
| B108 (hardcoded tmp) | `api/sheyla_security/llm_security.py` | MEDIUM |

## Key Takeaways

1. **All 6 CRITICAL findings are secrets** — all auto-fixable with `fix-env-reference.sh`
2. **All 4 HIGH findings are the same npm package** (`tar@7.5.6`) — single bump fixes all
3. **59 MEDIUM findings are mostly IaC misconfigurations** — Terraform AWS + K8s manifests
4. **Zero Python code vulnerabilities at HIGH/CRITICAL** — application code is clean
5. **31 of 73 findings (42%) are auto-fixable** with GP-CONSULTING fixer scripts
