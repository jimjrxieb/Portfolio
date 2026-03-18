# Phase 3: Autonomous Hardening

Source playbooks: `01-APP-SEC/playbooks/07, 07a, 07b, 07c, 08`
Automation level: **73% autonomous (E/D-rank)**, 20% JADE (C-rank), 7% human (B-rank)

## What the Agent Does

Deploys prevention infrastructure so fixed issues never come back:

```
1. CI security pipeline       → Scanners run on every PR
2. Scanner configs            → Consistent scan behavior
3. GHA hardening              → Pin actions, least-privilege
4. OPA/Conftest policy gate   → Block bad manifests at CI
5. Pre-commit hooks           → Catch issues before commit
```

## Step-by-Step

### 3a: Deploy CI Pipeline (Playbook 07) — E/D-rank

```bash
# Select template based on project stack
if project_profile.ci_platform == "github-actions":
  cp 01-APP-SEC/ci-templates/full-security-pipeline.yml \
     ${TARGET_REPO}/.github/workflows/security.yml
fi

# Configure severity threshold (default: fail on HIGH+CRITICAL)
# Configure DAST target (if project has staging URL in profile)
```

**B-rank escalation**: Branch protection rules need GitHub admin.
Agent presents recommended config, human applies in GitHub UI.

### 3b: Deploy Scanner Configs (Playbook 07a) — E-rank

```bash
# Copy configs (all are E-rank mechanical copies)
cp 01-APP-SEC/scanning-configs/.gitleaks.toml  ${TARGET_REPO}/
cp 01-APP-SEC/scanning-configs/.hadolint.yaml  ${TARGET_REPO}/
cp 01-APP-SEC/scanning-configs/semgrep.yaml    ${TARGET_REPO}/
cp 01-APP-SEC/scanning-configs/trivy.yaml      ${TARGET_REPO}/
cp 01-APP-SEC/scanning-configs/.checkov.yaml   ${TARGET_REPO}/

# K8s projects only:
if project_profile.has_kubernetes:
  mkdir -p ${TARGET_REPO}/policy/
  cp 01-APP-SEC/scanning-configs/conftest-policy.rego ${TARGET_REPO}/policy/
fi

# Add scanner output dirs to .gitignore
echo -e "\n# Scanner outputs\nscanner-results/\n.trivy-cache/\n.semgrep/" >> ${TARGET_REPO}/.gitignore
```

Validate each config:
```bash
gitleaks detect --source ${TARGET_REPO} --config ${TARGET_REPO}/.gitleaks.toml --no-banner
hadolint --config ${TARGET_REPO}/.hadolint.yaml ${TARGET_REPO}/Dockerfile 2>/dev/null
trivy fs ${TARGET_REPO} --config ${TARGET_REPO}/trivy.yaml 2>/dev/null
```

### 3c: Harden CI/CD (Playbook 07b) — D/C-rank

#### D-rank (autonomous)
```bash
# Pin all GitHub Actions to SHA
# Before: uses: actions/checkout@v4
# After:  uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4
pin_gha_actions_to_sha ${TARGET_REPO}/.github/workflows/*.yml

# Set least-privilege permissions per job
# Add: permissions: { contents: read } at job level
set_gha_permissions ${TARGET_REPO}/.github/workflows/*.yml

# Block dangerous patterns
# Scan for: pull_request_target + checkout, ${{ github.event.* }} interpolation
python3 01-APP-SEC/scanners/gha_scanner_npc.py ${TARGET_REPO}/.github/workflows/
```

#### C-rank (JADE)
- **Image signing**: JADE selects keyless (OIDC) vs key-based, generates workflow YAML.
- **SBOM attestation**: JADE selects format (CycloneDX), generates attach step.

### 3d: Deploy OPA/Conftest (Playbook 07c) — D/C-rank

#### D-rank (autonomous)
```bash
# Deploy policy
mkdir -p ${TARGET_REPO}/policy/
cp 01-APP-SEC/scanning-configs/conftest-policy.rego ${TARGET_REPO}/policy/

# Verify policy itself
conftest verify --policy ${TARGET_REPO}/policy/

# Test against project manifests
conftest test ${TARGET_REPO}/k8s/ --policy ${TARGET_REPO}/policy/ --output json

# Wire into CI
# Add conftest step to security.yml workflow
```

#### C-rank (JADE)
- **Policy exceptions**: If conftest denies a legitimate workload (DaemonSet
  needing SYS_ADMIN, init container as root), JADE reviews and approves/denies
  the exception with documented justification.

### 3e: Deploy Pre-Commit (Playbook 08) — E-rank

```bash
# Select config based on stack
if "python" in project_profile.languages:
  config="python"
elif "javascript" in project_profile.languages:
  config="javascript"
elif "go" in project_profile.languages:
  config="go"
else:
  config="full"
fi

# Install
cp 01-APP-SEC/pre-commit-hooks/${config}.pre-commit-config.yaml \
   ${TARGET_REPO}/.pre-commit-config.yaml
cd ${TARGET_REPO}
pip install pre-commit 2>/dev/null
pre-commit install

# Test
pre-commit run --all-files || true  # log failures but don't block
```

## Commit

```bash
git add .github/workflows/security.yml \
        .gitleaks.toml .hadolint.yaml semgrep.yaml trivy.yaml .checkov.yaml \
        policy/ .pre-commit-config.yaml .gitignore
git commit -m "feat(security): deploy CI pipeline, scanner configs, pre-commit hooks

  CI pipeline: full-security-pipeline.yml (11 scanners)
  Scanner configs: 5 configs deployed
  OPA policy: conftest-policy.rego (20 rules)
  Pre-commit: ${config} config
  GHA hardened: actions pinned to SHA, least-privilege permissions

  Deployed by jsa-devsec autonomous engagement"
```

## Phase 3 Gate

```
PASS if:
  - .github/workflows/security.yml exists AND valid YAML
  - At least 3 scanner configs deployed
  - conftest verify passes (if K8s project)
  - pre-commit install succeeded

FAIL action:
  - Report which components failed to deploy
  - Continue to Phase 4 anyway (hardening is additive, not blocking)
```
