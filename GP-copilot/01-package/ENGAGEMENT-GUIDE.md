# Application Security Engagement Guide

> Playbook for pre-deployment application security hardening.
> Human-readable. Agent-executable. jsa-devsec loads this as its brain.
>
> **Package location:** `GP-CONSULTING/01-APP-SEC/`
> **Agent:** `GP-BEDROCK-AGENTS/jsa-devsec/`
> **Lifecycle phase:** Pre-deploy (code → container → CI)

---

## Architecture

```
Developer writes code
       ↓
01-APP-SEC playbook (THIS FILE)          jsa-devsec agent
────────────────────────────────         ─────────────────
defines what to scan              →      runs the scanners
defines how to rank findings      →      classifies findings
defines which fixer to call       →      applies the fix
defines when to escalate          →      sends alert / blocks PR
       ↓
Findings land in FindingsStore
       ↓
E/D rank: auto-fixed, logged
C rank: JADE reviews, approves or escalates
B/S rank: human decides
```

Same tools. Same scripts. Same decision tree. Whether J runs it manually or jsa-devsec runs it at 3am.

---

## Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│           APPLICATION SECURITY ENGAGEMENT PHASES                      │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│   Phase 1          Phase 2           Phase 3          Phase 4         │
│   BASELINE         QUICK WINS        POLICY           CONTINUOUS      │
│   ASSESSMENT       (auto-fixable)    HARDENING        MONITORING      │
│   ──────────       ──────────        ──────────       ──────────      │
│   Week 1           Week 2            Week 3-4         Week 5+         │
│                                                                       │
│   • Run all        • Fix secrets     • Deploy         • Pre-commit    │
│     scanners       • Upgrade deps      admission        hooks         │
│   • Classify       • Fix SAST          policies      • CI/CD          │
│     findings       • Fix containers  • Custom OPA       pipelines     │
│   • Build          • Fix supply        rules         • Nightly        │
│     roadmap          chain           • B/S rank         rescans       │
│                                        discussion                     │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Baseline Assessment (Week 1)

**Goal:** Understand the client's current security posture.

**Playbook:** [playbooks/01-baseline-scan.md](playbooks/01-baseline-scan.md)

**Summary:**
1. Clone client repo into a GP-PROJECTS slot
2. Run `tools/run-all-scanners.sh` (16 scanners across 8 categories)
3. Run `tools/triage.py` to generate `REMEDIATION-PLAN.md`
4. Review findings, separate client code from GP-Copilot artifacts

### Scanner Pipeline

Scanners execute in this order. jsa-devsec follows the same sequence.

| # | Category | Scanner | What It Finds | Gate |
|---|----------|---------|---------------|------|
| 1 | **Secrets** | Gitleaks | Hardcoded secrets, API keys, tokens | Block |
| 2 | **SAST** | Bandit | Python — injection, crypto, shell | Block on HIGH |
| 3 | **SAST** | Semgrep | Cross-language (30+ langs), custom patterns | Block on ERROR |
| 4 | **SCA** | Trivy (fs) | CVEs in dependencies, license violations | Block on CRITICAL |
| 5 | **SCA** | Grype | CVE cross-check on SBOM | Warn |
| 6 | **Container** | Hadolint | Dockerfile best practices | Warn on ERROR |
| 7 | **Container** | Trivy (image) | Base image CVEs, embedded secrets | Block on CRITICAL |
| 8 | **IaC** | Checkov | Terraform, K8s, Dockerfile, CloudFormation misconfigs | Block on HIGH |
| 9 | **IaC** | TFsec | Terraform-specific security | Block on HIGH |
| 10 | **K8s Manifests** | Kubescape | NSA/CISA K8s hardening (pre-deploy manifest scan) | Warn |
| 11 | **K8s Manifests** | Polaris | K8s deployment best practices | Warn |
| 12 | **K8s Manifests** | Conftest | OPA policy violations against manifests | Block if policy defined |
| 13 | **Supply Chain** | Trivy (sbom) | SBOM generation, license compliance (GPL detection) | Warn |
| 14 | **CI/CD** | GHA Scanner | GitHub Actions misconfigs (unpinned actions, excessive permissions) | Warn |
| 15 | **DAST** | Nuclei | Known CVEs, misconfigs against running app (opt-in) | Warn |
| 16 | **DAST** | ZAP | OWASP Top 10 baseline scan against running app (opt-in) | Warn |

**CKS alignment:** Covers supply chain (image scanning, SBOM), admission prerequisites (manifest validation), and workload security (security context checks via Kubescape/Polaris/Checkov).

### Rank Classification

jsa-devsec classifies every finding using these rules, in order:

#### 1. Scanner Base Ranks

| Rank | Scanners | Why |
|------|----------|-----|
| **E** | Gitleaks (secrets only) | Secrets are always critical, always auto-fixable |
| **D** | Bandit, Semgrep, Trivy, Grype, Hadolint, Checkov, Kubescape, Polaris, Conftest, GHA Scanner | Pattern-based findings with deterministic fixes |
| **C** | TFsec, Helm (when added) | Context-dependent, may need architecture input |
| **B** | Prowler (cloud audit) | Cloud-level findings need human review |

#### 2. Rule ID Overrides (takes precedence over scanner base rank)

| Pattern | Rank | Rationale |
|---------|------|-----------|
| `hardcoded-secret`, `generic-api-key`, `private-key` | **D** | Auto-fixable via env var extraction |
| `CVE-*`, `GHSA-*` (CRITICAL/HIGH CVSS) | **D** | Auto-fixable via version bump |
| `CVE-*`, `GHSA-*` (MEDIUM/LOW CVSS) | **E** | Low-risk, auto-bump |
| `CKV_K8S_*` (securityContext) | **D** | Deterministic manifest patches |
| `CKV_DOCKER_*` | **D** | Deterministic Dockerfile fixes |
| `DL*`, `SC*` (Hadolint/ShellCheck) | **D** | Deterministic formatting fixes |
| `sql-injection`, `xss`, `ssrf` | **B** | Requires architecture understanding |
| `iam-wildcard`, `s3-public`, `rds-public` | **B** | Cloud blast radius, human decides |
| `pickle-load`, `exec-used` | **C** | Context-dependent — safe if input is trusted |
| `shell-injection` | **C** | May be intentional (build scripts) |

#### 3. Auto-Fix Confidence

| Rank | Auto-Fix Rate | Agent Authority | Approval |
|------|--------------|-----------------|----------|
| **E** | 95-100% | jsa-devsec runs autonomously | None |
| **D** | 70-90% | jsa-devsec runs autonomously, logged | None |
| **C** | 40-70% | jsa-devsec proposes, JADE approves | JADE (C-rank max) |
| **B** | 20-40% | jsa-devsec reports, human decides | Human + JADE intel |
| **S** | 0-5% | jsa-devsec reports only | Human only |

### What We Deliver (Week 1)

| Deliverable | Location |
|-------------|----------|
| Scanner JSON | `GP-S3/5-consulting-reports/<instance>/<slot>/baseline-YYYYMMDD/` |
| Summary | `SUMMARY.md` (in scan output dir) |
| Remediation Plan | `REMEDIATION-PLAN.md` (generated by `triage.py`) |

---

## Phase 2: Quick Wins (Week 2)

**Goal:** Fix all E-D tier findings using fixer scripts.

Each playbook covers one category. Work through them in order — secrets first, always.

### Fixer Routing

jsa-devsec routes findings to fixers using this table. First match wins.

| Priority | Finding Pattern | Fixer Script | Rank |
|----------|----------------|-------------|------|
| 1 | Scanner=gitleaks OR rule contains "secret" | `fixers/secrets/fix-env-reference.sh` | E |
| 2 | Scanner=gitleaks AND git history match | `fixers/secrets/git-purge-secret.sh` | D |
| 3 | Scanner∈{trivy,grype} AND rule matches CVE/GHSA | `fixers/dependencies/bump-cves.sh` | D |
| 4 | Scanner=bandit AND rule="B303" (MD5/SHA1) | `fixers/python/fix-md5.py` | E |
| 5 | Scanner=bandit AND rule="B311" (random) | `fixers/python/fix-weak-random.sh` | D |
| 6 | Scanner∈{bandit,semgrep} AND rule contains "shell" | `fixers/python/fix-shell-injection.sh` | D |
| 7 | Scanner∈{bandit,semgrep} AND rule contains "yaml" | `fixers/python/fix-yaml-load.sh` | E |
| 8 | Scanner∈{bandit,semgrep} AND rule contains "xml" | `fixers/python/fix-defusedxml.sh` | D |
| 9 | Scanner=hadolint AND rule="DL3002" (no USER) | `fixers/dockerfile/add-nonroot-user.sh` | D |
| 10 | Scanner=hadolint AND rule="DL3004" (no HEALTHCHECK) | `fixers/dockerfile/add-healthcheck.sh` | D |
| 11 | Scanner=hadolint AND rule="DL4000" (MAINTAINER) | `fixers/dockerfile/fix-maintainer.sh` | E |
| 12 | Scanner=hadolint AND rule="DL3003" (WORKDIR) | `fixers/dockerfile/fix-workdir.sh` | D |
| 13 | Scanner=hadolint AND rule="DL4006" (CMD) | `fixers/dockerfile/fix-cmd-format.sh` | D |
| 14 | Rule contains "security-header" | `fixers/web/add-security-headers.sh` | D |
| 15 | Rule contains "cookie" | `fixers/web/fix-cookie-flags.sh` | D |
| 16 | Rule contains "cors" | `fixers/web/fix-cors-config.sh` | D |
| 17 | Scanner∈{checkov,kubescape} AND rule matches CKV_K8S_6/20/22/28/37 | `fixers/k8s-manifests/add-security-context.sh` | D |
| 18 | Scanner∈{checkov,polaris} AND rule matches CKV_K8S_11/12/13 | `fixers/k8s-manifests/add-resource-limits.sh` | D |
| 19 | Scanner∈{polaris,kubescape} AND rule matches pullPolicy | `fixers/k8s-manifests/fix-image-pull-policy.sh` | D |
| 20 | Scanner∈{checkov,kubescape} AND rule matches CKV_K8S_43/C-0036 | `fixers/k8s-manifests/disable-service-account-token.sh` | D |
| 21 | Scanner=checkov AND rule="CKV_DOCKER_7" (unpinned image) | `fixers/supply-chain/pin-base-image.sh` | D |

#### Context-Dependent Fixers (C-rank — JADE approves)

| Finding Pattern | Fixer Script | Why C-rank |
|----------------|-------------|------------|
| Rule contains "pickle" | `fixers/python/fix-pickle.sh` | Safe if input is trusted basic types |
| Rule contains "exec" | `fixers/python/fix-exec.sh` | May be intentional (data parsing vs code exec) |
| Rule="SC2086" (shell quotes) | `fixers/dockerfile/fix-shell-quotes.sh` | Heuristic false positives in build scripts |
| Rule matches CKV_K8S_8/9 (probes) | `fixers/k8s-manifests/add-probes.sh` | Needs app endpoint verification |

#### Manual-Only Findings (B/S-rank — human decides)

These have NO fixer script. jsa-devsec reports them and stops.

| Finding Type | Why No Script | What Human Does |
|-------------|--------------|-----------------|
| SQL injection | Requires query refactoring to parameterized | Rewrite queries |
| XSS | Requires output encoding strategy | Choose framework-level fix |
| SSRF | Requires allowlist design | Define trusted URLs |
| SSL/TLS version | Requires infra coordination | Upgrade TLS config |
| Architecture auth flaws | Requires design change | Redesign auth flow |
| hostPath mounts | Requires volume strategy | Switch to PVC/CSI |

### Phase 2 Playbooks

| Priority | Playbook | What It Fixes |
|----------|----------|--------------|
| 1 | [Fix Secrets](playbooks/02-fix-secrets.md) | Hardcoded secrets → env vars, git history purge, credential rotation |
| 2 | [Fix Dependencies](playbooks/03-fix-dependencies.md) | CVEs → version bumps in pip/npm/go/gem |
| 3 | [Fix Python SAST](playbooks/04-fix-python-sast.md) | Weak hashing, shell injection, unsafe random, pickle, yaml.load |
| 4 | [Fix Dockerfiles](playbooks/05-fix-dockerfiles.md) | Non-root user, HEALTHCHECK, CMD format, pinned base images |
| 5 | [Fix Web Security](playbooks/06-fix-web-security.md) | Security headers, cookie flags, CORS config (DAST findings) |
| 6 | [Fix K8s Manifests](playbooks/10-fix-k8s-manifests.md) | SecurityContext, resource limits, image pull policy, SA tokens, probes |
| 7 | [Fix Supply Chain](playbooks/11-fix-supply-chain.md) | Image digest pinning, SBOM generation, license compliance |

### Expected Outcomes (End of Week 2)

- 0 hardcoded secrets in codebase
- 0 critical/high CVEs in dependencies
- 80%+ reduction in SAST findings
- All Dockerfiles have `USER` (non-root) and `HEALTHCHECK`
- All K8s manifests have `securityContext` and resource limits
- SBOM generated for all container images

---

## Phase 3: Policy Hardening (Week 3-4)

**Goal:** Deploy admission policies so violations are caught before merge, not after.

C-tier and above require human decision before applying — these are architectural choices.

| Step | Playbook | What It Deploys |
|------|----------|----------------|
| 3a | [Deploy CI Pipeline](playbooks/07-deploy-ci-pipeline.md) | GitHub Actions workflows + branch protection |
| 3b | [Deploy Security Configs](playbooks/07a-deploy-security-configs.md) | .gitleaks.toml, .hadolint.yaml, Conftest policies, allowlists |
| 3c | [Harden CI/CD Pipeline](playbooks/07b-harden-cicd-pipeline.md) | Image build → scan → sign → SBOM → push → GitOps trigger |
| 3d | [Deploy Pre-Commit](playbooks/08-deploy-pre-commit.md) | Gitleaks, validation hooks on every `git commit` |
| 3e | K8s Admission (see below) | Kyverno/Gatekeeper in-cluster enforcement (→ 02-CLUSTER-HARDENING) |

### 3a: Supply Chain Gates (CKS/CNPE alignment)

Pre-deploy supply chain validation — catches issues before they reach the cluster:

| Check | Tool | Gate | CKS Domain |
|-------|------|------|-----------|
| Image uses pinned digest (no `:latest`) | Checkov `CKV_DOCKER_7` | Block | Supply Chain Security |
| Base image has no CRITICAL CVEs | Trivy image scan | Block | Supply Chain Security |
| SBOM generated and archived | Trivy SBOM mode | Warn | Supply Chain Security |
| License compliance (no GPL in proprietary) | Trivy license scan | Warn | Supply Chain Security |
| Container runs as non-root | Hadolint `DL3002` + Checkov `CKV_K8S_6` | Block | Workload Security |
| SecurityContext present | Kubescape NSA framework | Warn | Workload Security |
| Resource limits defined | Polaris | Warn | Workload Security |

### 3b: Kubernetes Manifest Validation (pre-deploy)

These checks run against manifests in the repo, not the cluster. CKS exam expects you to know these:

| Control | Scanner | Rule ID | What It Validates |
|---------|---------|---------|-------------------|
| runAsNonRoot | Checkov | `CKV_K8S_6` | Pod doesn't run as root |
| readOnlyRootFilesystem | Checkov | `CKV_K8S_22` | Filesystem is immutable |
| Drop ALL capabilities | Checkov | `CKV_K8S_28` | No unnecessary Linux capabilities |
| No privilege escalation | Checkov | `CKV_K8S_20` | `allowPrivilegeEscalation: false` |
| No hostNetwork | Kubescape | `C-0041` | Pod doesn't share host network |
| No hostPID | Kubescape | `C-0038` | Pod doesn't share host PID namespace |
| No hostPath | Kubescape | `C-0045` | No host filesystem mounts |
| Seccomp profile set | Kubescape | `C-0210` | RuntimeDefault or custom seccomp |
| AppArmor annotation | Kubescape | `C-0261` | AppArmor profile referenced |
| Resource limits | Polaris | `resources` | CPU/memory limits set |
| Liveness probe | Polaris | `healthChecks` | Liveness probe configured |
| Readiness probe | Polaris | `healthChecks` | Readiness probe configured |
| Image pull policy | Polaris | `images` | `Always` or digest-based |
| Service account token | Kubescape | `C-0036` | `automountServiceAccountToken: false` |

### 3c: Kubernetes Admission Policies (if cluster access available)

```bash
# Kyverno (preferred — no OPA cluster required)
kubectl apply -f ci-templates/kyverno/

# Conftest (CI-only, no cluster required)
conftest test k8s/ --policy scanning-configs/conftest-policy.rego

# Gatekeeper (if OPA Gatekeeper already installed)
kubectl apply -f policies/gatekeeper/
```

For full Kyverno/Gatekeeper deployment, see [02-CLUSTER-HARDENING](../02-CLUSTER-HARDENING/ENGAGEMENT-GUIDE.md).

### C-Tier Findings — Human Review Checklist

For each C-tier finding:
- [ ] Read the finding description in the scan output
- [ ] Understand why the control matters (link in `fixers/README.md`)
- [ ] Run the relevant fix script and review its output
- [ ] Test in a non-production environment
- [ ] Get sign-off from client developer/architect
- [ ] Apply, re-scan, commit

### Expected Outcomes (End of Week 4)

- All C-tier findings resolved or documented as accepted risk
- Pre-commit hooks installed on all dev workstations
- CI pipeline deployed and required for merge
- Admission policies deployed (Kyverno or Conftest)
- Supply chain gates active (image scanning, SBOM, license check)

---

## Phase 4: Continuous Monitoring (Week 5+)

**Goal:** Ensure new code doesn't reintroduce findings. Set up reporting cadence.

**Playbook:** [Post-Fix Rescan](playbooks/09-post-fix-rescan.md)

### Monitoring Cadence

| Frequency | What Runs | Output |
|-----------|-----------|--------|
| Every commit | Pre-commit hooks (gitleaks, semgrep) | Blocked commit |
| Every PR | CI pipeline (all scanners) | PR check status |
| Nightly | Scheduled Trivy/Grype scan + SBOM refresh | Nightly output dir |
| Weekly | Full baseline rescan | Trend report |

### Success Metrics

| Metric | Baseline | Week 2 | Week 4 | Week 8 |
|--------|----------|--------|--------|--------|
| Critical/High Findings | {{COUNT}} | < 50% | < 10% | 0 |
| Hardcoded Secrets | {{COUNT}} | 0 | 0 | 0 |
| Vulnerable Dependencies | {{COUNT}} | < 25% | < 5% | 0 |
| Time to Detect (new issue) | N/A | N/A | < 1 day | < 1 hr |
| SBOM Coverage | 0% | 50% | 100% | 100% |

### Handoff to Runtime (02-CLUSTER-HARDENING → 03-DEPLOY-RUNTIME)

When Phase 4 is stable, the developer's code is secure. Next:
- **02-CLUSTER-HARDENING** (jsa-infrasec): Harden the cluster the code deploys into
- **03-DEPLOY-RUNTIME** (jsa-monitor): Watch the running workload for threats

01-APP-SEC catches it in code. 02 catches it at admission. 03 catches it at runtime. Three layers, three agents, zero gaps.

---

## Client Communication Templates

### Week 1 Kickoff Email

```
Subject: Security Baseline Assessment — {{CLIENT_NAME}}

Hi {{CLIENT_NAME}} team,

We've completed the baseline security assessment of your repositories.

Top-line findings:
- {{TOTAL}} total findings across 16 security scanners
- {{ED_COUNT}} findings are auto-fixable (E-D tier)
- {{C_COUNT}} findings require your team's review (C tier)
- {{BS_COUNT}} findings require architecture discussion (B-S tier)

Next steps:
1. Week 2: We'll submit PRs fixing all E-D tier findings
2. Week 3-4: We'll review C-tier findings together and deploy policies
3. Week 5+: Continuous monitoring and B-S tier review
```

### Week 2 Progress Report

```
Subject: Week 2 Progress — {{ED_FIXED}} Findings Fixed

Week 2 summary:
- {{SECRET_COUNT}} hardcoded secrets removed and rotated
- {{DEP_COUNT}} vulnerable dependencies upgraded
- {{SAST_COUNT}} code vulnerabilities fixed
- {{CONTAINER_COUNT}} Dockerfile hardening fixes applied

Before/After:
- Critical findings: {{BEFORE_CRIT}} → {{AFTER_CRIT}}
- High findings: {{BEFORE_HIGH}} → {{AFTER_HIGH}}
```

---

## Troubleshooting

### "Too many false positives"
Add allowlists to scanner configs in `scanning-configs/`. See each scanner's config file.

### "CI pipeline too slow (> 10 min)"
Split into individual workflows instead of `full-security-pipeline.yml`. They run in parallel.

### "Developers bypassing pre-commit with --no-verify"
CI pipeline + branch protection is the real gate. Pre-commit is convenience. See [08-deploy-pre-commit.md](playbooks/08-deploy-pre-commit.md).

### "Fix script broke the app"
All scripts create `.bak` backups. Restore with `cp file.bak file`. See the specific playbook for details.

---

## CKS/CKA/CNPE Coverage Map

What this package covers from each certification domain (pre-deploy scope only):

### CKS (Certified Kubernetes Security Specialist)

| CKS Domain | Covered By | Status |
|-----------|-----------|--------|
| Supply Chain Security — Image scanning | Trivy image, Grype | Done |
| Supply Chain Security — SBOM | Trivy SBOM mode | Done |
| Supply Chain Security — Image digest pinning | Checkov CKV_DOCKER_7 | Done |
| Supply Chain Security — License compliance | Trivy license scan | Done |
| Workload Security — SecurityContext | Checkov, Kubescape, Polaris | Done |
| Workload Security — Seccomp profiles | Kubescape C-0210 (detection) | Detection only |
| Workload Security — AppArmor | Kubescape C-0261 (detection) | Detection only |
| Secrets Management — Hardcoded secrets | Gitleaks | Done |
| Secrets Management — K8s Secret misuse | Checkov CKV_K8S_35 | Done |

**Not in scope (handled by 02-CLUSTER-HARDENING or 03-DEPLOY-RUNTIME):**
- etcd encryption, kubelet security, audit logging, PSA enforcement, NetworkPolicy, RBAC tightening, runtime threat detection

### CKA (Certified Kubernetes Administrator)

| CKA Domain | Covered By | Status |
|-----------|-----------|--------|
| Workload Scheduling — Resource limits | Polaris, Checkov | Done |
| Workload Scheduling — Health probes | Polaris | Done |
| Storage — No hostPath | Kubescape C-0045 | Done |
| Cluster Architecture — RBAC manifests | Kubescape, Checkov | Detection only |

### CNPE (Cloud Native Platform Engineer)

| CNPE Domain | Covered By | Status |
|------------|-----------|--------|
| Platform Security — CI/CD hardening | GHA Scanner, Conftest | Done |
| Platform Security — IaC scanning | Checkov, TFsec | Done |
| Platform Security — Pre-commit hooks | Gitleaks, Semgrep, Hadolint | Done |
| Observability — SBOM tracking | Trivy SBOM | Done |

---

## Engagement Deliverables Summary

| Phase | Deliverable | Format | Location |
|-------|-------------|--------|----------|
| 1 | Baseline Scan Report | JSON + SUMMARY.md | `GP-S3/5-consulting-reports/` |
| 1 | Remediation Plan | REMEDIATION-PLAN.md | Same directory |
| 2 | Fix commits with re-scan proof | Git history | PR per category |
| 2 | Post-fix scan results | JSON | `post-fix-YYYYMMDD/` |
| 3 | Pre-commit config | `.pre-commit-config.yaml` | Repo root |
| 3 | CI/CD pipeline | `security.yml` | `.github/workflows/` |
| 3 | SBOM artifacts | CycloneDX JSON | Build artifacts |
| 4 | Weekly trend reports | Markdown | Weekly scan dirs |
| 4 | POA&M for accepted risks | Markdown | `POAM.md` |

---

*Ghost Protocol — Pre-Deployment Application Security Package v2.0*
