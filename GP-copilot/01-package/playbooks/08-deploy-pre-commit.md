# Playbook: Deploy Pre-Commit Hooks

> Install pre-commit hooks on developer workstations so findings are caught before they hit the repo.
>
> **When:** After Phase 2 fixes are done. Prevents new findings at the source.
> **Time:** ~5 min to install per developer

---

## The Principle

CI catches findings on PRs. Pre-commit catches them on `git commit` — before they even leave the developer's machine. This is the fastest feedback loop possible.

---

## Step 1: Choose Your Config

| Config | File | What It Runs | Speed | Best For |
|--------|------|-------------|-------|----------|
| **Full** | `.pre-commit-config.yaml` | Gitleaks, Semgrep, Hadolint, Conftest, Bandit | ~10 sec | Default |
| **Minimal** | `minimal.yaml` | Gitleaks + trailing whitespace only | ~3 sec | Large repos, impatient devs |
| **Python** | `python.yaml` | Gitleaks, Bandit, Semgrep (Python rules) | ~8 sec | Python-only projects |
| **JavaScript** | `javascript.yaml` | Gitleaks, Semgrep (JS rules) | ~8 sec | Node.js projects |
| **Go** | `go.yaml` | Gitleaks, Semgrep (Go rules) | ~8 sec | Go projects |

---

## Step 2: Install

### Option A: Use Our Install Script (Recommended)

```bash
cd <client-repo>

# Full config (default)
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/pre-commit-hooks/install.sh

# Specific config
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/pre-commit-hooks/install.sh --config minimal
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/pre-commit-hooks/install.sh --config python

# With auto-update
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/pre-commit-hooks/install.sh --auto-update
```

### Option B: Manual Install

```bash
cd <client-repo>

# Install pre-commit framework
pip install pre-commit

# Copy our config
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/pre-commit-hooks/.pre-commit-config.yaml \
   .pre-commit-config.yaml

# Install the hooks
pre-commit install

# Test against all current files (first run downloads hooks — takes ~30 sec)
pre-commit run --all-files
```

---

## Step 3: Test It

**Passing commit:**
```bash
$ git commit -m "Add feature"
Gitleaks................................................Passed
Semgrep (security)......................................Passed
Hadolint................................................Passed
[main abc123] Add feature
```

**Blocked commit:**
```bash
$ git commit -m "Add config"
Gitleaks................................................Failed
─── Finding ──────────────────────────────────────
  RuleID: aws-access-token
  File:   config.py, line 42
  Secret: AKIA...

Action: Remove the secret, add to .env, re-commit.
```

---

## Step 4: Handle the "--no-verify" Problem

Developers can bypass pre-commit hooks with `git commit --no-verify`. You can't prevent this locally. The defense is layered:

1. **Pre-commit hooks** — catches 90% of issues (good developers use them)
2. **CI pipeline** — catches what slips past (required status checks on PRs)
3. **Branch protection** — makes CI mandatory (can't merge without passing)

If a developer uses `--no-verify`, CI will still block the PR. The hook is a convenience, not the only gate.

**For teams that want to track compliance:**
```bash
# Add to team onboarding docs:
# 1. Clone the repo
# 2. Run: pre-commit install
# 3. Done — hooks run automatically on every commit
```

---

## Step 5: Commit the Config

```bash
# The .pre-commit-config.yaml should be checked into the repo
# so every developer gets the same hooks
git add .pre-commit-config.yaml
git commit -m "ci: add pre-commit security hooks (gitleaks, semgrep, hadolint)"
```

---

## Updating Hooks

```bash
# Update hook versions to latest
pre-commit autoupdate

# Test after updating
pre-commit run --all-files

# Commit the updated config
git add .pre-commit-config.yaml
git commit -m "ci: update pre-commit hook versions"
```

---

## Troubleshooting

**"pre-commit: command not found"**
```bash
pip install pre-commit
# or
brew install pre-commit
```

**"Hook takes too long (>30 sec)"**
- Switch to the minimal config: `--config minimal`
- Exclude large directories in the hook config (node_modules, vendor, etc.)

**"Hook fails on files I didn't change"**
- First run scans all staged files. Fix existing issues or use `--all-files` once to baseline.
- After that, hooks only run on changed files.

---

## Next Steps

- Full rescan to verify everything? → [09-post-fix-rescan.md](09-post-fix-rescan.md)
- Back to engagement overview? → [ENGAGEMENT-GUIDE.md](../ENGAGEMENT-GUIDE.md)

---

*Ghost Protocol — Pre-Deployment Security Package*
