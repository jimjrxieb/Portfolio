# Playbook 02: Remediation Plan

> Derived from [GP-CONSULTING/01-APP-SEC/playbooks/02-09](https://github.com/jimjrxieb/GP-copilot) (fix-secrets, fix-dependencies, fix-python-sast, fix-dockerfiles, fix-web-security, post-fix-rescan)
> Tailored for the Portfolio application (linksmlm.com)

## What This Does

Takes the findings from Playbook 01 (Baseline Scan) and maps each one to a remediation action. Findings are triaged by risk rank, matched to automated fixer scripts where possible, and tracked through resolution.

## Triage Process

Every finding gets classified using the GP-Copilot rank system:

| Rank | Automation | Action | Portfolio Example |
|------|-----------|--------|-------------------|
| **E-rank** | 95-100% auto | Pattern-match fix, no review needed | Trailing whitespace, formatting |
| **D-rank** | 70-90% auto | Fixer script runs, logged for audit | `yaml.load()` → `yaml.safe_load()`, weak random → `secrets` module |
| **C-rank** | 40-70% auto | Fix proposed, needs approval | Dependency version bump (test impact), Dockerfile base image pin |
| **B-rank** | 20-40% auto | Human decides with AI intel | SQL injection refactor, CORS policy redesign |
| **S-rank** | 0-5% auto | Human only | Architecture changes, auth system redesign |

## Fixer Scripts by Category

### Secrets (E/D-rank — highest priority)
| Finding | Fixer | What It Does |
|---------|-------|-------------|
| Hardcoded API key | `fix-env-reference.sh` | Replaces inline values with `os.environ.get("VAR")` or `process.env.VAR` |
| Secret in git history | `git-purge-secret.sh` | Rewrites git history to remove the committed secret |
| **Manual step** | — | Rotate the exposed credential immediately (AWS keys, API tokens, DB passwords) |

### Dependencies (D-rank)
| Finding | Fixer | What It Does |
|---------|-------|-------------|
| CVE in Python package | `bump-cves.sh pip <pkg> <version>` | Updates `requirements.txt` to the patched version |
| CVE in npm package | `bump-cves.sh npm <pkg> <version>` | Runs `npm install <pkg>@<version>` and updates lockfile |
| No fix available | — | Document as accepted risk in `.trivyignore`, monitor monthly |

### Python SAST (D/C-rank)
| Finding | Fixer | What It Does |
|---------|-------|-------------|
| `yaml.load()` (B506) | `fix-yaml-load.sh` | Replaces with `yaml.safe_load()` — prevents arbitrary code execution |
| `random.random()` for tokens (B311) | `fix-weak-random.sh` | Replaces with `secrets.token_hex()` — cryptographically secure |
| `pickle.loads()` (B301) | `fix-pickle.sh` | Replaces with `json.loads()` — prevents deserialization attacks |
| `subprocess` with `shell=True` (B602) | `fix-shell-injection.sh` | Converts to list form `subprocess.run(["cmd", "arg"])` |
| Weak hash MD5/SHA1 (B303) | `fix-md5.py` | Replaces with `hashlib.sha256()` |

### Dockerfiles (D/C-rank)
| Finding | Fixer | What It Does |
|---------|-------|-------------|
| No USER directive (DS002) | `add-nonroot-user.sh` | Adds `RUN adduser` + `USER appuser` — containers run non-root |
| No HEALTHCHECK (DS026) | `add-healthcheck.sh` | Adds `HEALTHCHECK CMD curl -f http://localhost:PORT/health` |
| Shell form CMD (DL3025) | `fix-cmd-format.sh` | Converts `CMD python app.py` → `CMD ["python", "app.py"]` |
| `:latest` tag (DL3007) | — | Manual: pin to specific version (e.g., `python:3.11-slim`) |

### Kubernetes Manifests (D/C-rank)
| Finding | Fixer | What It Does |
|---------|-------|-------------|
| No security context (CKV_K8S_20/22/28) | `add-security-context.sh` | Adds `runAsNonRoot`, `readOnlyRootFilesystem`, `drop: ["ALL"]`, seccomp |
| No resource limits (CKV_K8S_11/12/13) | `add-resource-limits.sh` | Adds CPU/memory requests and limits |
| Missing health probes | `add-probes.sh` | Adds liveness + readiness probes (requires knowing the health endpoint) |

## Auto-Fix Workflow

```
Scanner output (JSON/SARIF)
  → triage.py (classify by rank, deduplicate, group by category)
  → REMEDIATION-PLAN.md (human-readable action items)
  → Fixer scripts (D/E-rank auto-applied, C-rank proposed)
  → Post-fix rescan (Playbook 09 — prove the work)
```

## Verification

After all fixes are applied, we re-run the full scanner suite and compare:

| Category | Before | After | Target |
|----------|--------|-------|--------|
| Secrets | 0 | 0 | Zero tolerance |
| Critical CVEs | 0 | 0 | Zero tolerance |
| High CVEs | X | 0 | Zero tolerance |
| Python SAST (HIGH) | X | 80%+ reduction | Best effort |
| Dockerfile issues | X | 0 | Full remediation |
| K8s misconfigs | X | 90%+ reduction | Policy-gated |

The before/after comparison is the client deliverable — proof that the engagement produced measurable results.
