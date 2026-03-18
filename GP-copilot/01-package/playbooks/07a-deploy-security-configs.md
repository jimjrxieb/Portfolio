# Playbook 07a: Deploy Scanner Configs & Allowlists

> Drop our scanning configs and allowlists into the client repo.
> These are the files that CI pipelines and pre-commit hooks reference.
>
> **When:** After CI pipeline is deployed (07), before pre-commit (08)
> **Time:** ~5 min
> **Agent:** jsa-devsec (D-rank — deterministic file copy + validation)
>
> **OPA / Conftest policy deployment is in a separate playbook:**
> → [07c-conftest.md](07c-conftest.md)

---

## Why This Matters

The CI workflow and pre-commit hooks reference config files:
- Gitleaks uses `.gitleaks.toml`
- Hadolint uses `.hadolint.yaml`
- Bandit uses `.bandit`
- Trivy uses `trivy.yaml`

Without these files in the client repo, scanners run with defaults (noisy) or fail silently. This playbook deploys our tuned configs — the ones we built and tested in Phase 1-2.

---

## Step 1: Copy Scanning Configs

```bash
cd <client-repo>

# Copy all scanning configs from our package
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/scanning-configs/.gitleaks.toml .
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/scanning-configs/.bandit .
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/scanning-configs/.hadolint.yaml .
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/scanning-configs/semgrep.yaml .
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/scanning-configs/trivy.yaml .

# Optional — only if client has K8s manifests
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/scanning-configs/kubescape.json .
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/scanning-configs/polaris.yaml .
```

---

## Step 2: Create Allowlists

### `.gitleaksignore` — False positive suppression

```bash
# Create from template
cat > .gitleaksignore << 'EOF'
# Documented false positives
# Format: fingerprint (file:rule:line)
# Add findings here after verifying they are NOT real secrets

# Example: test fixtures with fake credentials
# tests/fixtures/config.py:generic-api-key:42

# Example: documentation examples
# docs/api-guide.md:generic-api-key:15
EOF
```

### `.trivyignore` — Accepted CVE risks

```bash
# Create if needed (for CVEs with no fix available)
cat > .trivyignore << 'EOF'
# Accepted risks — CVEs with no fix or accepted by the team
# Format: CVE-YYYY-NNNNN
# Each entry must have a comment explaining why it's accepted

# Example:
# CVE-2024-12345  # No fix available as of 2026-03-14, transitive dep, not reachable in our code
EOF
```

---

## Step 3: Wire Configs Into CI

If the CI workflow (from playbook 07) doesn't already reference the configs, update it:

```yaml
# In .github/workflows/security.yml, ensure scanners use our configs:

    - name: Gitleaks
      uses: gitleaks/gitleaks-action@v2
      with:
        config: .gitleaks.toml

    - name: Hadolint
      run: hadolint --config .hadolint.yaml Dockerfile

    - name: Trivy
      run: trivy fs . --config trivy.yaml
```

Our `full-security-pipeline.yml` template already references these paths. If you used that template in playbook 07, this step is already done.

> OPA/Conftest CI wiring is in [07c-conftest.md](07c-conftest.md).

---

## Step 4: Add to .gitignore

Make sure scanning artifacts don't get committed:

```bash
# Add to .gitignore if not already present
cat >> .gitignore << 'EOF'

# Scanner outputs (generated, not source)
gp-scan-outputs/
*.sarif
*.sarif.json

# Scanner caches
.semgrep/
.trivy/
EOF
```

---

## Step 5: Verify Everything Works Together

```bash
# Test Gitleaks with config
gitleaks detect --source . --no-git --config .gitleaks.toml 2>&1 | tail -3

# Test Hadolint with config
hadolint --config .hadolint.yaml Dockerfile 2>&1 | head -5

# Test Trivy with config
trivy fs . --config trivy.yaml 2>&1 | tail -5

# Test pre-commit (references .gitleaks.toml)
pre-commit run --all-files 2>&1 | head -10

# Test CI locally (if act is installed)
# act -j security-scan --dryrun
```

> To verify Conftest policies and run OPA unit tests → [07c-conftest.md](07c-conftest.md)

---

## Step 6: Commit

```bash
git add \
  .gitleaks.toml \
  .gitleaksignore \
  .bandit \
  .hadolint.yaml \
  semgrep.yaml \
  trivy.yaml \
  .trivyignore

git commit -m "security: deploy scanner configs and allowlists"
```

---

## What Gets Deployed

| File | Purpose | Referenced By |
|------|---------|--------------|
| `.gitleaks.toml` | Secret detection patterns + allowlists | CI, pre-commit, `run-all-scanners.sh` |
| `.gitleaksignore` | Documented false positive suppression | Gitleaks |
| `.bandit` | Python SAST config (skips, severity) | CI, `run-all-scanners.sh` |
| `.hadolint.yaml` | Dockerfile lint rules | CI, pre-commit |
| `semgrep.yaml` | SAST ruleset documentation | Reference (CI uses `--config auto`) |
| `trivy.yaml` | CVE scanner config | `run-all-scanners.sh` |
| `.trivyignore` | Accepted CVE risks | Trivy |
| `policy/conftest-policy.rego` | OPA policy for K8s manifests | → see [07c-conftest.md](07c-conftest.md) |

---

## Client Conversation

> "What are all these config files?"
>
> These are the tuned scanner configurations we built during weeks 1-2. They reduce false positives, set the right severity thresholds, and ensure every scanner runs consistently — whether a developer runs it locally, pre-commit runs it on commit, or CI runs it on PR. Same rules everywhere, no gaps.

---

## Next Steps

- Deploy OPA/Conftest policy gate? → [07c-conftest.md](07c-conftest.md)
- Deploy pre-commit hooks? → [08-deploy-pre-commit.md](08-deploy-pre-commit.md)
- Full rescan to verify? → [09-post-fix-rescan.md](09-post-fix-rescan.md)

---

*Ghost Protocol — Pre-Deployment Security Package*
