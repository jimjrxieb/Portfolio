# 01 — Application Security Package

What gets scanned, what gets caught, and how findings get fixed — every push, every PR.

---

## Pipeline Security Checklist

These scanners run automatically on every push to `main` via `.github/workflows/main.yml`.
No manual steps required — violations are caught before code reaches production.

### Code Scanning

- [x] **Semgrep** — SAST analysis across Python, JavaScript, TypeScript
  - OWASP Top 10 coverage
  - Secret detection patterns
  - Supply chain attack detection
  - GitHub Actions workflow security
- [x] **Bandit** — Python-specific security analysis
  - Command injection (B602, B603)
  - Weak cryptography (B303, B324)
  - Hardcoded passwords (B105, B106, B107)
  - Insecure random (B311)
- [x] **SonarCloud** — Code quality, bugs, vulnerabilities, code smells
  - Reliability rating
  - Security hotspot review
  - Technical debt tracking

### Dependency Scanning

- [x] **Safety** — Python dependency vulnerabilities (CVE database)
  - Scans `api/requirements.txt`
  - Flags packages with known CVEs + fix versions
- [x] **npm audit** — Node.js dependency vulnerabilities
  - Scans `ui/package.json`
  - Reports severity levels (critical, high, moderate, low)

### Secret Detection

- [x] **detect-secrets** — Baseline-aware secret scanning
  - Pre-commit hook + CI pipeline
  - Baseline file tracks known/accepted entries
  - New secrets block the pipeline
- [x] **Semgrep p/secrets** — Pattern-based secret detection
  - AWS keys, API tokens, private keys
  - Runs as part of SAST scan above

### Container Security

- [x] **Trivy** — Container image vulnerability scanning
  - Scans `ghcr.io/jimjrxieb/portfolio-api` and `portfolio-ui`
  - OS package + library CVEs (CRITICAL, HIGH, MEDIUM)
  - SBOM generation (CycloneDX)
  - Secret detection in image layers
- [x] **Checkov** — Infrastructure-as-Code scanning
  - Dockerfile best practices
  - Kubernetes manifest validation
  - GitHub Actions workflow checks

### Infrastructure Validation

- [x] **Conftest/OPA** — Policy-as-code validation (see `02-package/`)
  - 5 Rego policies enforced in CI
  - Helm chart rendering + validation
- [x] **Hadolint** — Dockerfile linting (config provided in `scanning-configs/`)
  - Non-root user enforcement
  - Version pinning
  - Trusted registry validation

---

## What Each Scanner Catches → How to Fix It

When a scanner flags a finding, use the matching fixer script. Each script creates a backup, applies the fix, and tells you what to do next.

### Python Code Findings

| Scanner | Finding | Error Code | Fix Script |
|---------|---------|------------|------------|
| Bandit | Weak hash (MD5/SHA1) | B303, B324 | `fixers/python/fix-md5.py` |
| Bandit | Shell injection risk | B602, B603 | `fixers/python/fix-shell-injection.sh` |
| Bandit | Insecure random | B311, B312 | `fixers/python/fix-weak-random.sh` |
| Bandit | Hardcoded password | B105, B106 | `fixers/secrets/fix-env-reference.sh` |

### Dockerfile Findings

| Scanner | Finding | Error Code | Fix Script |
|---------|---------|------------|------------|
| Hadolint / Trivy | Running as root | DL3002, DS002 | `fixers/dockerfile/add-nonroot-user.sh` |
| Checkov / Trivy | Missing HEALTHCHECK | CKV_DOCKER_3, DS026 | `fixers/dockerfile/add-healthcheck.sh` |

### Secret Findings

| Scanner | Finding | Fix Script |
|---------|---------|------------|
| detect-secrets / Gitleaks | Hardcoded credential | `fixers/secrets/fix-env-reference.sh` |
| Gitleaks | Secret in git history | `fixers/secrets/git-purge-secret.sh` |

### Dependency Findings

| Scanner | Finding | Fix Script |
|---------|---------|------------|
| Trivy / Safety / npm audit | Known CVE in package | `fixers/dependencies/bump-cves.sh` |

---

## Scanning Configs Provided

Tuned configurations for each scanner, tailored to Portfolio's directory structure and tech stack.

| Config File | Scanner | Key Settings |
|-------------|---------|-------------|
| `.bandit` | Bandit | Excludes tests/venv, skips B101 (assert), recursive |
| `.hadolint.yaml` | Hadolint | Trusted registries (ghcr.io, docker.io), severity overrides |
| `semgrep.yaml` | Semgrep | 11 rulesets (OWASP, secrets, Python, JS/TS, K8s, GHA), Portfolio paths |
| `trivy.yaml` | Trivy | CVE + config + secret + license scanning, forbidden GPL, SBOM output |
| `.checkov.yaml` | Checkov | K8s + Dockerfile + Helm + GHA frameworks, aligned skips with pipeline |
| `.gitleaks.toml` | Gitleaks | Default rules + custom (DB connection strings, Slack webhooks, JWT, PEM keys) |

---

## CI/CD Pipeline Overview

What happens on every push to `main`:

```
Push to main
  │
  ├── [parallel] Security Scanning
  │     ├── Semgrep (SAST + secrets)
  │     ├── Bandit (Python security)
  │     ├── Safety (Python deps)
  │     ├── detect-secrets (credential audit)
  │     ├── Checkov (IaC security)
  │     └── SonarCloud (code quality)
  │
  ├── [parallel] Code Quality
  │     ├── ESLint (TypeScript/JSX)
  │     ├── Flake8 (Python)
  │     ├── Prettier (formatting)
  │     └── npm audit (Node.js deps)
  │
  ├── [after scanning] Build & Push Images
  │     ├── portfolio-api → ghcr.io/jimjrxieb/portfolio-api
  │     └── portfolio-ui  → ghcr.io/jimjrxieb/portfolio-ui
  │
  ├── [after build] Container Scanning
  │     └── Trivy (CVE + secret + config scan on built images)
  │
  ├── [after build] Update Helm Values
  │     └── Auto-commit new image tags → ArgoCD picks up the change
  │
  └── [on PR] Policy Validation
        └── Conftest OPA (5 policies against rendered Helm manifests)
```

---

## Package Contents

```
01-package/
├── scanning-configs/          Tuned configs for each scanner
│   ├── .bandit                  Python SAST config
│   ├── .checkov.yaml            IaC scanner config
│   ├── .gitleaks.toml           Secret detection rules
│   ├── .hadolint.yaml           Dockerfile linter config
│   ├── semgrep.yaml             Multi-language SAST config
│   └── trivy.yaml               Container + filesystem scanner config
│
└── fixers/                    Fix scripts organized by finding category
    ├── python/
    │   ├── fix-md5.py             Replace MD5/SHA1 with SHA-256
    │   ├── fix-shell-injection.sh Fix subprocess shell=True
    │   └── fix-weak-random.sh     Replace random with secrets module
    ├── dockerfile/
    │   ├── add-nonroot-user.sh    Add USER instruction
    │   └── add-healthcheck.sh     Add HEALTHCHECK instruction
    ├── secrets/
    │   ├── fix-env-reference.sh   Replace hardcoded secret with env var
    │   └── git-purge-secret.sh    Remove secret from git history
    └── dependencies/
        └── bump-cves.sh          Upgrade vulnerable package (pip/npm/yarn/go/gem)
```
