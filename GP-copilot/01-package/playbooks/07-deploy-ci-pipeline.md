# Playbook: Deploy CI/CD Security Pipeline

> Add security scanning to the client's GitHub Actions so findings are caught on every PR.
>
> **When:** After Phase 2 fixes are done. Prevents regression.
> **Time:** ~10 min to deploy, then it runs automatically

---

## The Principle

Pre-commit hooks catch issues on the developer's machine. CI pipelines catch what slips past. Branch protection makes it mandatory. Three layers, no gaps.

---

## Step 1: Choose Your Pipeline

| Option | File | What It Runs | Run Time | Best For |
|--------|------|-------------|----------|----------|
| **Full pipeline** | `full-security-pipeline.yml` | All 12 scanners | 5-10 min | Default for all engagements |
| **Gitleaks only** | `gitleaks.yml` | Secret detection | ~30 sec | Quick secret gate |
| **Semgrep only** | `semgrep.yml` | Multi-lang SAST | ~2 min | SAST-focused teams |
| **Trivy only** | `trivy-fs.yml` | Dependency CVEs | ~2 min | Dependency-focused teams |
| **Policy check** | `policy-check.yml` | Conftest OPA | ~30 sec | K8s policy enforcement |
| **DAST scan** | `dast-scan.yml` | Nuclei + ZAP | ~5 min | After staging deploy |

**Recommendation:** Start with the full pipeline. Split into individual workflows later if run time becomes an issue.

---

## Step 2: Copy the Workflow

```bash
cd <client-repo>

# Option A: Full pipeline (recommended)
mkdir -p .github/workflows
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/ci-templates/full-security-pipeline.yml \
   .github/workflows/security.yml

# Option B: Individual workflows (pick what you need)
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/ci-templates/gitleaks.yml .github/workflows/
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/ci-templates/semgrep.yml .github/workflows/
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/ci-templates/trivy-fs.yml .github/workflows/
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/ci-templates/policy-check.yml .github/workflows/
```

---

## Step 3: Configure (If Needed)

The workflows work out of the box for most repos. Customize if needed:

```yaml
# In the workflow file, adjust these if needed:

# Change severity threshold
env:
  SEVERITY: "HIGH"  # Options: LOW, MEDIUM, HIGH, CRITICAL

# Add scanner-specific configs by copying our configs into the repo
# (optional — workflows use sensible defaults without them)
```

**For DAST scanning,** you need a staging URL:
```yaml
# In dast-scan.yml, set the target
env:
  TARGET_URL: "https://staging.example.com"
```

---

## Step 4: Set Up Branch Protection

The workflows are useless if developers can merge without them passing.

```
GitHub repo → Settings → Branches → Branch protection rules → Add rule

Branch name pattern: main

Check these boxes:
  [x] Require a pull request before merging
  [x] Require status checks to pass before merging
      Required checks:
        - gitleaks (or "security" if using full pipeline)
        - semgrep
        - trivy
  [x] Require branches to be up to date before merging
```

---

## Step 5: What Blocks vs What Warns

| Scanner | Blocks PR | Warns Only |
|---------|-----------|------------|
| Gitleaks | Any finding | — |
| Semgrep | ERROR severity | WARNING severity |
| Trivy | CRITICAL CVE | HIGH CVE |
| Checkov | HIGH IaC finding | MEDIUM |
| Conftest | Any policy violation | — |
| Kubescape | — | All (advisory) |
| Polaris | — | All (advisory) |
| Nuclei | — | All (advisory, DAST) |
| ZAP | — | All (advisory, DAST) |

---

## Step 6: Test the Pipeline

```bash
# Create a test branch and PR
git checkout -b test/security-pipeline
git add .github/workflows/
git commit -m "ci: add security scanning pipeline"
git push -u origin test/security-pipeline

# Create PR and watch the checks run
gh pr create --title "Add security scanning" --body "Test security pipeline"
```

Watch the Actions tab. All scanners should run and report status.

---

## Step 7: Verify It Actually Blocks

Intentionally introduce a finding to confirm blocking works:

```bash
# Create a test file with a fake secret
echo 'API_KEY = "AKIA1234567890ABCDEF"' > test_secret.py
git add test_secret.py
git commit -m "test: verify gitleaks blocks"
git push

# The PR check should fail with a Gitleaks finding
# After confirming, remove the test file
git rm test_secret.py
git commit -m "test: remove test secret"
git push
```

---

## Step 8: Commit

```bash
git add .github/workflows/
git commit -m "ci: deploy security scanning pipeline (gitleaks, semgrep, trivy, checkov)"
```

---

## Nightly Scans

The full pipeline template includes a scheduled run:

```yaml
on:
  schedule:
    - cron: '0 2 * * *'   # nightly at 2am UTC
```

This catches new CVEs disclosed overnight — even if no code changed, a new CVE might affect an existing dependency.

---

## Next Steps

- Pre-commit hooks for developer workstations? → [08-deploy-pre-commit.md](08-deploy-pre-commit.md)
- Full rescan to verify everything? → [09-post-fix-rescan.md](09-post-fix-rescan.md)

---

*Ghost Protocol — Pre-Deployment Security Package*
