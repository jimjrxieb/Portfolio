# Playbook 05: CI/CD Monitoring & Build Health

> Derived from [GP-CONSULTING/01-APP-SEC/playbooks/09-post-fix-rescan.md](https://github.com/jimjrxieb/GP-copilot) + [GP-CONSULTING/03-DEPLOY-RUNTIME/playbooks/11-argocd-integration.md](https://github.com/jimjrxieb/GP-copilot)
> Tailored for the Portfolio application (linksmlm.com)

## What This Does

Monitors the GitHub Actions pipeline and ArgoCD sync health post-deployment. When builds break, this playbook defines how we diagnose, fix, and verify — ensuring the pipeline stays green and the production site stays live.

## What We Monitor

### GitHub Actions Pipeline Health

| Check | What It Means | Response |
|-------|--------------|----------|
| `sast-scanning` fails | Semgrep found ERROR-severity code vulnerability | Fix the code pattern flagged in Semgrep output |
| `python-security` fails | Bandit or Safety found HIGH+ finding | Update dependency or fix code pattern |
| `secrets-scanning` fails | New secret detected vs. baseline | Remove secret, rotate credential, update `.secrets.baseline` |
| `iac-scanning` fails | Checkov found Dockerfile/Terraform misconfiguration | Fix the IaC finding (usually missing USER, HEALTHCHECK, or resource limits) |
| `build-images` fails | Docker build error | Check Dockerfile syntax, missing deps, or base image availability |
| `security-scan` fails | Trivy found CRITICAL image vulnerability | Update base image or patch the vulnerable package |
| `validate-k8s` fails | OPA/Conftest policy violation in Helm manifests | Fix the K8s manifest to comply with security policies |

### ArgoCD Sync Health

| Status | What It Means | Response |
|--------|--------------|----------|
| **Synced + Healthy** | All good — desired state matches live state | No action |
| **OutOfSync** | Git has changes ArgoCD hasn't applied yet | Wait for auto-sync or run `argocd app sync portfolio` |
| **Synced + Degraded** | Pods are running but failing health checks | Check pod logs: `kubectl -n portfolio logs <pod>` |
| **SyncFailed** | ArgoCD tried to apply but K8s rejected it | Check `argocd app get portfolio` for error details |
| **Missing** | Resource was deleted outside ArgoCD | ArgoCD self-heal will recreate it (if enabled) |

## Common Build Failures and Fixes

### 1. Semgrep ERROR — Code Vulnerability

```
Error: semgrep found issues at severity ERROR
```

**Diagnose:**
```bash
# Check the CI log for the specific finding
gh run view <run-id> --repo jimjrxieb/Portfolio --log | grep "ERROR"
```

**Fix:** Address the code pattern Semgrep flagged. Common ones:
- `eval()` with user input → refactor to safe alternative
- SQL string concatenation → parameterized queries
- Hardcoded secret pattern → move to environment variable

### 2. Conftest DENY — Policy Violation

```
FAIL - deployment.yaml - Privileged container 'api' in Deployment 'portfolio-api'
```

**Diagnose:**
```bash
# Test locally before pushing
helm template portfolio infrastructure/charts/portfolio/ | conftest test -
```

**Fix:** Update the Helm values or templates to comply:
- Add `securityContext.runAsNonRoot: true`
- Add resource limits
- Pin image tags (no `:latest`)

### 3. Docker Build Failure

```
ERROR: failed to solve: process "/bin/sh -c pip install..." exited with code 1
```

**Diagnose:** Usually a dependency issue. Check:
- Base image still available? (pin versions, not `:latest`)
- New dependency has system-level requirements? (add `apt-get install`)
- Network issue pulling packages? (retry)

### 4. ArgoCD OutOfSync After Deploy

```bash
# Check current state
argocd app get portfolio

# Force sync if auto-sync is slow
argocd app sync portfolio

# Check what's different
argocd app diff portfolio
```

### 5. White Page After Deploy

The UI image built but `index.html` references JS/CSS assets with new hashes that haven't loaded:

```bash
# Check UI pod logs for 404s
kubectl -n portfolio logs -l app.kubernetes.io/component=ui

# Force browser refresh: Ctrl+Shift+R
# If persistent, check the image tag actually updated:
kubectl -n portfolio get deploy portfolio-portfolio-app-ui \
    -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Monitoring Commands

### Quick Health Check
```bash
# Pipeline status (last 5 runs)
gh run list --repo jimjrxieb/Portfolio --limit 5

# ArgoCD status
argocd app get portfolio

# Pod health
kubectl -n portfolio get pods

# Live site
curl -s -o /dev/null -w "%{http_code}" https://linksmlm.com
```

### Deeper Diagnostics
```bash
# Full CI run details
gh run view <run-id> --repo jimjrxieb/Portfolio --log

# ArgoCD sync history
argocd app history portfolio

# Pod events (crash loops, OOMKilled, image pull errors)
kubectl -n portfolio describe pod <pod-name>

# Recent deployments
kubectl -n portfolio rollout history deployment/portfolio-portfolio-app-api
```

## Escalation Path

| Severity | Example | Response Time | Who Handles |
|----------|---------|--------------|-------------|
| **P1 — Site down** | ArgoCD SyncFailed, all pods CrashLooping | Immediate | Platform engineer |
| **P2 — Pipeline broken** | Build fails on every push | Same day | Developer + platform engineer |
| **P3 — Advisory finding** | New Trivy CVE, Bandit warning | Next sprint | Developer |
| **P4 — Informational** | SonarCloud code smell, minor lint | Backlog | Developer |

## Continuous Improvement

- **Promote advisory → blocking**: As the codebase matures, move Bandit/Trivy/Checkov from advisory to blocking
- **Add DAST scanning**: ZAP/Nuclei against staging environment (Playbook 06 in GP-CONSULTING)
- **Nightly CVE scans**: Scheduled workflow catches new CVEs even without code changes
- **Slack/PagerDuty alerts**: Wire ArgoCD sync-fail alerts to notification channels
