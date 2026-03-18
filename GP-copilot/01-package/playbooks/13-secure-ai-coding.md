# Playbook 13 — Secure AI Coding

> Enforce security at generation time — before scanners ever run. Drop these rules into any project's `CLAUDE.md` (or equivalent AI coding assistant config) to guard the entity that writes the code. This is shift-left taken to the final level.
>
> **When:** At project kickoff, before any AI-assisted development begins.
> **Audience:** Any developer using Claude Code, Copilot, Cursor, or similar AI coding tools.
> **Time:** ~15 min (initial config), then enforced automatically

---

## Part 1: Dependency Security Rules

### Rule 1: Never Add a Dependency Without CVE Check

Before adding ANY new dependency (pip, npm, go, cargo, etc.), check it for known vulnerabilities:

```bash
# Python
pip-audit --desc --requirement=requirements.txt
# or for a single package:
pip install pip-audit && pip-audit -r <(echo "package_name==version")

# Node.js
npm audit
# or before installing:
npx npm-audit-resolver

# Go
govulncheck ./...

# Rust
cargo audit

# Container images
trivy image <image_name>:<tag>
```

**AI assistant rule (paste into CLAUDE.md):**
```
BEFORE adding any new dependency to requirements.txt, package.json, go.mod, or Cargo.toml:
1. State the package name, version, and WHY it's needed
2. Check if an existing dependency already provides the functionality
3. Prefer standard library over third-party when possible
4. Pin to an exact version (never use >= or * without upper bound)
5. If the package has fewer than 1,000 GitHub stars or hasn't been updated in 12+ months, flag it for human review
```

### Rule 2: Pin Everything

```
# Python — pin exact versions
requests==2.32.3       # GOOD
requests>=2.0          # BAD — allows untested versions
requests               # BAD — no version at all

# GitHub Actions — pin to SHA, never tags
uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # GOOD (v4.1.1)
uses: actions/checkout@v4     # BAD — mutable tag
uses: actions/checkout@main   # TERRIBLE — tracks branch

# Docker — pin to digest or specific version
FROM python:3.12.8-slim@sha256:abc123...   # GOOD
FROM python:3.12-slim                       # ACCEPTABLE
FROM python:latest                          # BAD
FROM python                                 # TERRIBLE
```

### Rule 3: Dependency Change = Mandatory Scan

Any PR or commit that modifies dependency files MUST trigger:
```bash
# Add to pre-commit or CI
pip-audit --requirement=requirements.txt --desc --fix --dry-run
trivy fs --scanners vuln --severity CRITICAL,HIGH .
```

---

## Part 2: Secure Code Generation Rules

### Rule 4: Never Generate These Patterns

Paste into your AI assistant config to prevent known-vulnerable code at generation time:

```
NEVER generate code that:
1. Uses eval(), exec(), or compile() with user input
2. Uses os.system() or subprocess.shell=True with string interpolation
3. Constructs SQL queries with string concatenation or f-strings
4. Uses pickle.loads() on untrusted data
5. Uses yaml.load() without yaml.safe_load()
6. Uses MD5 or SHA1 for security purposes (passwords, signatures, tokens)
7. Uses random.random() for security tokens (use secrets module)
8. Hardcodes secrets, API keys, passwords, or tokens
9. Disables SSL/TLS verification (verify=False)
10. Uses innerHTML or dangerouslySetInnerHTML with user input
11. Sets CORS to allow all origins ("*") in production code
12. Uses JWT with algorithm "none"
13. Catches broad exceptions (except Exception) that swallow security errors
14. Creates world-readable files (chmod 777, mode=0o777)
15. Uses XML parsers without disabling external entities (XXE)
```

### Rule 5: Secure Defaults

```
ALWAYS use these patterns:
1. subprocess.run(["cmd", "arg"], shell=False, check=True)
2. parameterized queries for ALL database operations
3. yaml.safe_load() instead of yaml.load()
4. secrets.token_urlsafe() for tokens, not random
5. hashlib.sha256() minimum for hashing, bcrypt/argon2 for passwords
6. Input validation at every system boundary (user input, API responses, file reads)
7. Principle of least privilege for file permissions (0o600 for secrets, 0o644 for configs)
8. Context managers (with statements) for file and connection handling
9. Type hints on all function signatures for public APIs
10. Structured logging (JSON) not print() for security events
```

### Rule 6: Container Security Defaults

```
WHEN generating Dockerfiles:
1. Use specific base image tags, never :latest
2. Add a non-root USER directive
3. Add HEALTHCHECK instruction
4. Use multi-stage builds to minimize attack surface
5. Copy only needed files (use .dockerignore)
6. Don't store secrets in ENV or build args
7. Set read-only root filesystem where possible
8. Drop all capabilities, add back only what's needed

WHEN generating Kubernetes manifests:
1. Always include securityContext:
   runAsNonRoot: true
   readOnlyRootFilesystem: true
   allowPrivilegeEscalation: false
   capabilities:
     drop: ["ALL"]
2. Always set resource limits (CPU + memory)
3. Always include liveness and readiness probes
4. Never use hostNetwork, hostPID, or hostIPC
5. Set automountServiceAccountToken: false unless K8s API access is needed
6. Use NetworkPolicies to restrict pod-to-pod traffic
```

---

## Part 3: Pre-Commit Gates

### Rule 7: Local Validation Before Push

Install these as pre-commit hooks so AI-generated code gets caught locally:

```yaml
# .pre-commit-config.yaml
repos:
  # Secret detection
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks

  # Python SAST
  - repo: https://github.com/PyCQA/bandit
    rev: 1.8.3
    hooks:
      - id: bandit
        args: ["-c", ".bandit", "-r"]

  # Dependency CVE check
  - repo: https://github.com/pypa/pip-audit
    rev: v2.7.3
    hooks:
      - id: pip-audit
        args: ["--requirement=requirements.txt", "--desc"]

  # Dockerfile linting
  - repo: https://github.com/hadolint/hadolint
    rev: v2.12.0
    hooks:
      - id: hadolint-docker

  # YAML validation
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.35.1
    hooks:
      - id: yamllint

  # Terraform security
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.1
    hooks:
      - id: terraform_tfsec
      - id: terraform_checkov
```

### Rule 8: CI Pipeline Must-Haves

Every pipeline that deploys AI-generated code MUST include:

```yaml
# Minimum CI gates — block merge if any fail
security-gates:
  - name: SAST scan
    tool: semgrep --config=p/security-audit --config=p/owasp-top-ten --error
    fail_on: ERROR

  - name: Secret detection
    tool: gitleaks detect --source=. --verbose
    fail_on: any finding

  - name: Dependency CVE scan
    tool: trivy fs --scanners vuln --severity CRITICAL,HIGH --exit-code 1 .
    fail_on: CRITICAL or HIGH

  - name: Container image scan
    tool: trivy image --severity CRITICAL --exit-code 1 $IMAGE
    fail_on: CRITICAL

  - name: IaC scan
    tool: checkov -d . --framework kubernetes,terraform,dockerfile
    fail_on: CRITICAL or HIGH

  - name: License compliance
    tool: trivy fs --scanners license --severity CRITICAL .
    fail_on: GPL/AGPL in non-GPL project
```

---

## Part 4: AI-Specific Guardrails

### Rule 9: Scope Containment

```
AI coding assistant rules:
1. Do not modify files outside the current task scope
2. Do not delete shared/common modules without explicit approval
3. Do not change CI/CD pipeline files without showing the diff first
4. Do not add new external API calls without flagging for review
5. Do not change authentication/authorization logic without human review
6. Do not modify database schemas without showing migration plan
7. Do not change network configurations (ports, firewall rules, security groups)
8. Show diffs before applying changes to any file over 100 lines
```

### Rule 10: Supply Chain Verification

```
BEFORE using any third-party code pattern from training data:
1. Verify the import path is correct (don't hallucinate packages)
2. Verify the API/method signature matches the pinned version
3. Don't invent package names — if unsure, ask the developer
4. For security-critical operations (crypto, auth, parsing), use ONLY
   well-established libraries: cryptography, PyJWT, defusedxml, etc.
5. Never suggest installing packages from URLs or git repos in production
   requirements — use published registry versions only
```

### Rule 11: Audit Trail

```
For every code change, the AI assistant MUST:
1. State what was changed and why
2. List any new dependencies added
3. Flag any security-relevant changes (auth, crypto, network, permissions)
4. Note if the change affects shared/common code used by other components
5. Log structured output for security audit (JSONL format preferred)
```

---

## Part 5: Copy-Paste CLAUDE.md Block

Drop this entire block into any project's `CLAUDE.md` to activate all rules:

```markdown
## Secure Coding Rules

### Dependencies
- NEVER add a dependency without stating: package name, exact version, and justification
- NEVER use unpinned versions (>=, ~=, * without upper bound)
- PREFER standard library over third-party packages
- CHECK CVEs: run `pip-audit` / `npm audit` / `trivy fs` before committing dependency changes
- FLAG packages with <1,000 GitHub stars or >12 months since last release for human review
- NEVER install from git URLs or direct archives in production requirements

### Code Generation
- NEVER use eval/exec/compile with dynamic input
- NEVER use shell=True with string interpolation in subprocess
- NEVER construct SQL with string concatenation — use parameterized queries
- NEVER use pickle.loads, yaml.load (use yaml.safe_load), or XML without defusedxml
- NEVER use MD5/SHA1 for security, random for tokens, or hardcode secrets
- NEVER disable TLS verification or set CORS to "*" in production
- ALWAYS validate input at system boundaries
- ALWAYS use secrets module for token generation
- ALWAYS use parameterized queries for database operations
- ALWAYS use context managers for resources (files, connections)

### Containers
- ALWAYS pin base image versions (never :latest)
- ALWAYS add USER (non-root), HEALTHCHECK, and .dockerignore
- ALWAYS set securityContext in K8s manifests (runAsNonRoot, readOnlyRootFilesystem, drop ALL capabilities)
- ALWAYS set resource limits and health probes in K8s

### Scope Control
- Do NOT modify files outside current task scope
- Do NOT delete shared modules without asking
- Do NOT change CI/CD, auth, database schemas, or network config without showing diff first
- Show diffs before applying changes to files over 100 lines

### Audit
- State what changed and why for every modification
- List any new dependencies added
- Flag security-relevant changes explicitly
```

---

## Part 6: Validation Checklist

Before merging any AI-generated PR, verify:

```
[ ] No new dependencies added without CVE check
[ ] All dependencies pinned to exact versions
[ ] No hardcoded secrets, tokens, or credentials
[ ] No eval/exec/shell injection patterns
[ ] No SQL injection vectors
[ ] No disabled TLS or overly permissive CORS
[ ] Dockerfiles use non-root user and pinned base images
[ ] K8s manifests have securityContext and resource limits
[ ] Pre-commit hooks pass locally
[ ] CI security gates (SAST, secrets, deps, container scan) all green
[ ] Changes scoped to the requested task only
[ ] Shared/common code changes flagged for review
```

---

## Appendix: Tool Reference

| Check | Tool | Install |
|-------|------|---------|
| Python CVEs | `pip-audit` | `pip install pip-audit` |
| Node.js CVEs | `npm audit` | built-in |
| Go CVEs | `govulncheck` | `go install golang.org/x/vuln/cmd/govulncheck@latest` |
| Rust CVEs | `cargo-audit` | `cargo install cargo-audit` |
| Multi-language CVEs | `trivy fs` | `brew install trivy` or binary |
| Container CVEs | `trivy image` | same as above |
| SAST | `semgrep` | `pip install semgrep` |
| Python SAST | `bandit` | `pip install bandit` |
| Secrets | `gitleaks` | `brew install gitleaks` or binary |
| IaC | `checkov` | `pip install checkov` |
| Dockerfile | `hadolint` | `brew install hadolint` or binary |
| K8s policies | `conftest` | `brew install conftest` or binary |
| SBOM | `trivy fs --format cyclonedx` | same as trivy |
