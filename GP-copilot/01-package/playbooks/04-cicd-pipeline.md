# Playbook 04: CI/CD Pipeline

> Derived from [GP-CONSULTING/01-APP-SEC/playbooks/07-deploy-ci-pipeline.md](https://github.com/jimjrxieb/GP-copilot) + [GP-CONSULTING/01-APP-SEC/playbooks/07a-deploy-security-configs.md](https://github.com/jimjrxieb/GP-copilot)
> Tailored for the Portfolio application (linksmlm.com)

## What This Does

Deploys a security-hardened GitHub Actions pipeline that runs 8 scanners in parallel, builds container images, validates Kubernetes manifests against OPA policies, and triggers ArgoCD GitOps deployment. This is the regression prevention layer — once a vulnerability is fixed, the pipeline ensures it never comes back.

## Portfolio Pipeline Architecture

```
Push to main
  │
  ├── Stage 1: Security Scanning (parallel, ~2 min)
  │   ├── sast-scanning      → Semgrep (security-audit + secrets + python + javascript)
  │   ├── python-security    → Bandit (api/, rag-pipeline/) + Safety (requirements.txt)
  │   ├── secrets-scanning   → detect-secrets (baseline audit)
  │   ├── iac-scanning       → Checkov (Terraform + Dockerfiles)
  │   ├── sonarcloud         → SonarCloud (bugs, vulns, smells, coverage)
  │   └── code-quality       → ESLint + Flake8 + Prettier + npm audit
  │
  ├── Stage 2: Build (requires Stage 1 pass, ~1 min)
  │   ├── build-images (api)  → Docker build → ghcr.io/jimjrxieb/portfolio-api:main-<sha>
  │   └── build-images (ui)   → Docker build → ghcr.io/jimjrxieb/portfolio-ui:main-<sha>
  │
  ├── Stage 3: Post-Build Security (~1 min)
  │   ├── security-scan (api) → Trivy image scan (OS + library vulns, secrets, misconfig)
  │   └── security-scan (ui)  → Trivy image scan
  │
  ├── Stage 4: Kubernetes Validation
  │   └── validate-k8s        → Helm lint + kubeconform + Conftest (13 OPA policies)
  │
  ├── Stage 5: Deploy
  │   └── update-image-tags   → Auto-commit new tags to Helm values.yaml [skip ci]
  │                              ArgoCD detects change → syncs to k3s cluster
  │
  └── Stage 6: Notify
      └── Pipeline summary with all results
```

## Scanner Configuration

Each scanner is tuned with config files deployed from GP-CONSULTING:

| Scanner | Config File | Key Settings |
|---------|------------|-------------|
| Semgrep | Rulesets in workflow | `p/security-audit`, `p/secrets`, `p/python`, `p/javascript` |
| Bandit | `.bandit` | Target `api/`, `rag-pipeline/`, skip tests |
| detect-secrets | `.secrets.baseline` | Baseline comparison (new secrets only) |
| Checkov | `.checkov.yaml` | Skip CKV_DOCKER_2/3/43 (accepted risks) |
| Trivy | `trivy.yaml` | `severity: HIGH,CRITICAL`, scanners: `vuln,secret,config` |
| ESLint | `ui/.eslintrc.cjs` | Strict mode, `no-eval`, `eqeqeq` |
| Conftest | `conftest.yaml` | 13 policies: container, image, resource, pod security |

## What Blocks vs. What Warns

### Blocking (fails the pipeline)
- **Semgrep ERROR** — Any finding at ERROR severity stops the build
- **Conftest DENY** — Any OPA policy violation stops K8s validation
- **Docker build failure** — Lint errors, missing dependencies

### Advisory (logged, doesn't block)
- Bandit, Safety, Checkov, Trivy, SonarCloud, npm audit
- Results visible in CI job output and GitHub Actions summary
- Intention: these become blocking as the codebase matures

## GitOps Flow (CI → ArgoCD → Production)

```
Developer pushes to main
  → GitHub Actions builds images tagged main-<sha>
  → update-image-tags job runs sed on Helm values.yaml
  → Auto-commit with [skip ci] (prevents infinite loop)
  → ArgoCD polls repo every 3 min (or manual: argocd app sync portfolio)
  → Detects values.yaml change → rolling update on k3s
  → New pods pull images from ghcr.io → serve traffic via Cloudflare Tunnel
```

**End-to-end time: ~4-5 minutes from push to live on linksmlm.com**

## Enhanced Pipeline Features (from GP-CONSULTING)

What GP-Copilot adds beyond standard CI:

| Feature | Standard CI | GP-Enhanced |
|---------|-----------|-------------|
| Scanning | 1-2 tools | 8 tools in parallel |
| Policy gate | None | 13 OPA/Conftest policies |
| Image scanning | None or basic | Trivy (OS + libs + secrets + misconfig) |
| K8s validation | `kubectl --dry-run` | Helm lint + kubeconform + Conftest |
| Secret detection | Basic grep | detect-secrets baseline + Semgrep p/secrets |
| Deploy | Manual | ArgoCD GitOps (auto-sync, self-heal, prune) |
| Nightly scans | None | Catches new CVEs even without code changes |

## Branch Protection Rules

```
Require PR for main
  ├── Require status checks: sast-scanning, python-security, secrets-scanning
  ├── Require up-to-date branch
  └── Require conversation resolution
```

## Maintenance

- **Weekly**: Review advisory findings (Bandit, Trivy, SonarCloud)
- **Monthly**: Update scanner versions, re-pin base images
- **Quarterly**: Promote advisory scanners to blocking as codebase quality improves
