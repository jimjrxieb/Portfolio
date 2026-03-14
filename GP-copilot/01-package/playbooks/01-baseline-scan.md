# Playbook 01: Baseline Security Scan

> Derived from [GP-CONSULTING/01-APP-SEC/playbooks/01-baseline-scan.md](https://github.com/jimjrxieb/GP-copilot)
> Tailored for the Portfolio application (linksmlm.com)

## What This Does

Runs 8 security scanners in parallel against the Portfolio codebase to establish a complete picture of the application's security posture. This is the first thing we do on any engagement — before fixing anything, we need to know what's broken.

## Scanners and What They Catch

| Scanner | What It Finds | CIS / CVE Mapping | Portfolio Target |
|---------|--------------|-------------------|-----------------|
| **Semgrep** | Code-level vulnerabilities: injection flaws, insecure deserialization, hardcoded secrets, unsafe regex | OWASP Top 10 (A01-A10), CWE-78/79/89/502 | `api/`, `ui/src/`, `rag-pipeline/` |
| **Bandit** | Python-specific security issues: `eval()`, `pickle.loads()`, weak crypto (MD5/SHA1), `shell=True` in subprocess | CWE-78 (OS Command Injection), CWE-327 (Broken Crypto), CWE-502 (Deserialization) | `api/`, `backend/`, `rag-pipeline/` |
| **detect-secrets** | Hardcoded API keys, passwords, tokens, private keys in source code | CIS Docker 4.10, NIST IA-5 (Authenticator Management) | Entire repo |
| **Safety** | Known CVEs in Python dependencies (checks against NVD + SafetyCLI DB) | Maps directly to CVE IDs (e.g., CVE-2024-XXXX) | `api/requirements.txt` |
| **Checkov** | Infrastructure-as-Code misconfigurations: Dockerfiles without USER, Terraform without encryption, missing resource limits | CIS Kubernetes 5.2.x, CIS Docker 4.x, CKV_DOCKER_2/3/7 | `api/Dockerfile`, `ui/Dockerfile`, `infrastructure/` |
| **Trivy** | Container image vulnerabilities (OS packages + application libraries), embedded secrets, misconfigurations | CVE database (NVD, Red Hat, Debian, Alpine), GHSA advisories | `ghcr.io/jimjrxieb/portfolio-api`, `ghcr.io/jimjrxieb/portfolio-ui` |
| **SonarCloud** | Code quality + security hotspots: bugs, code smells, duplication, maintainability, security vulnerabilities | OWASP Top 10, CWE taxonomy | Full repo analysis |
| **npm audit** | Known CVEs in Node.js dependencies | Maps directly to CVE IDs and GHSA advisories | `ui/package.json`, `ui/package-lock.json` |

## How It Runs in Portfolio

All 8 scanners execute in parallel via GitHub Actions (`main.yml`). The pipeline is structured as:

```
Push to main
  ├── sast-scanning (Semgrep)
  ├── python-security (Bandit + Safety)
  ├── secrets-scanning (detect-secrets)
  ├── iac-scanning (Checkov)
  ├── sonarcloud (SonarCloud)
  └── code-quality (ESLint + Flake8 + npm audit)
       ↓
  build-images (Docker build → GHCR)
       ↓
  security-scan (Trivy on built images)
       ↓
  validate-k8s (Conftest OPA policy check)
```

## What Blocks vs. What Warns

| Level | Scanner | Behavior |
|-------|---------|----------|
| **Blocks build** | Semgrep (ERROR severity) | Fails the `sast-scanning` job → images won't build |
| **Blocks deploy** | Conftest (any DENY) | Fails `validate-k8s` → ArgoCD won't sync |
| **Advisory** | Bandit, Safety, Checkov, Trivy, SonarCloud | Logged in CI output, visible in job summary |

## Sample Output

After a baseline scan, findings are grouped by severity:

```
CRITICAL: 0
HIGH:     3  (2 dependency CVEs, 1 Dockerfile missing USER)
MEDIUM:   7  (4 code quality, 2 config, 1 secret pattern)
LOW:      12 (informational)
```

## What Happens Next

Findings from this scan feed directly into:
- **Playbook 02** (Remediation Plan) — triage and prioritize
- **Playbook 03** (GP-Enhanced Security) — add policy-as-code guardrails
- **Playbook 04** (CI/CD Pipeline) — ensure nothing regresses
