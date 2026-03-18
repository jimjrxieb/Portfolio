# Phase 2: Autonomous Fix

Source playbooks: `01-APP-SEC/playbooks/02-06, 10, 11`
Automation level: **72% autonomous (D-rank)**, 12% JADE (C-rank), 16% human (B-rank)

## Execution Order

The agent processes findings in this order (highest impact first):

```
1. Secrets       (Playbook 02) — Highest risk. Exposure is active.
2. Dependencies  (Playbook 03) — Known CVEs with public exploits.
3. Python SAST   (Playbook 04) — Code-level vulnerabilities.
4. Dockerfiles   (Playbook 05) — Container security baseline.
5. Web Security  (Playbook 06) — Header/cookie/CORS fixes.
6. K8s Manifests (Playbook 10) — Runtime security posture.
7. Supply Chain  (Playbook 11) — Image pinning, SBOM, licenses.
```

## Fix Loop (per finding category)

```
FOR each finding in category (sorted by severity DESC):
  1. Look up fixer in scanner_fixer_map.yaml
  2. Check rank:
     - E/D → execute fixer immediately
     - C   → queue for JADE, continue other work
     - B   → queue for human, continue other work
  3. Execute fixer:
     a. Create backup: cp ${FILE} ${FILE}.bak
     b. Run fixer command
     c. Verify: re-run scanner on fixed file
     d. IF verify passes → update FindingsStore to "verified"
     e. IF verify fails  → rollback from backup, log failure
  4. After all E/D fixes in category: batch commit
```

## Category: Secrets (Playbook 02)

### D-rank (autonomous)
```bash
# For each secret finding:
01-APP-SEC/fixers/secrets/fix-env-reference.sh ${FILE} ${LINE} ${VAR_NAME}

# Verify:
gitleaks detect --source ${TARGET_REPO} --no-banner -f json | jq '. | length'
# Expected: count decreased
```

### B-rank (escalate)
- **Credential rotation**: Agent presents secret type, file, line, exposure window.
  Human rotates in AWS/GitHub/DB, then confirms. Agent waits.
- **Git history purge**: Agent presents files to purge, commit count.
  Human approves force-push. Agent runs `git-purge-secret.sh`.

## Category: Dependencies (Playbook 03)

### D-rank (autonomous)
```bash
# For each vulnerable package WITH a fix:
01-APP-SEC/fixers/dependencies/bump-cves.sh ${PKG_MANAGER} ${PACKAGE} ${FIXED_VERSION}

# Test:
${TEST_COMMAND}  # pytest, npm test, go test — from project_profile

# Verify:
trivy fs ${TARGET_REPO} --severity HIGH,CRITICAL -f json
```

**Rollback rule**: If tests fail after bump, revert that single bump and log.
Do NOT revert all bumps — they're independent.

### B-rank (escalate)
- **No-fix CVEs**: Agent presents CVE, CVSS score, reachability analysis.
  Human decides: accept risk, replace package, or isolate.

## Category: Python SAST (Playbook 04)

### D-rank (autonomous) — 7 fixers

| Finding | Fixer | What It Does |
|---------|-------|-------------|
| B303/B324 (MD5/SHA1) | `fix-md5.py` | Replace with `hashlib.sha256` |
| B602/B603 (shell=True) | `fix-shell-injection.sh` | Use `subprocess.run([...])` list form |
| B311 (weak random) | `fix-weak-random.sh` | Replace `random` with `secrets` |
| B301 (pickle) | `fix-pickle.sh` | Replace `pickle` with `json` |
| B506 (yaml.load) | `fix-yaml-load.sh` | Use `yaml.safe_load()` |
| B313/B314 (xml) | `fix-defusedxml.sh` | Use `defusedxml` |
| B102/B307 (exec/eval) | `fix-exec.sh` | Flag only (no auto-fix for dynamic code) |

### B-rank (escalate)
- **B608 (SQL injection)**: Agent shows query pattern, suggests parameterized version.
- **B501 (SSL config)**: Agent shows current TLS settings, recommends fix.

## Category: Dockerfiles (Playbook 05)

### E/D-rank (autonomous) — 6 fixers

| Finding | Fixer | Rank |
|---------|-------|------|
| CKV_DOCKER_3 / DL3002 (root user) | `add-nonroot-user.sh` | D |
| DL3025 (CMD format) | `fix-cmd-format.sh` | D |
| DL4000 (MAINTAINER) | `fix-maintainer.sh` | E |
| DL3003 (cd instead of WORKDIR) | `fix-workdir.sh` | E |
| SC2086 (unquoted vars) | `fix-shell-quotes.sh` | D |
| CKV_DOCKER_2 (HEALTHCHECK) | `add-healthcheck.sh` | C |

### C-rank (JADE)
- **HEALTHCHECK**: Agent runs fixer (auto-detects port from EXPOSE).
  JADE verifies the health endpoint actually exists in app code.

### B-rank (escalate)
- **Base image version selection**: Agent lists available versions + CVE counts.
  Human chooses version based on project requirements.

## Category: Web Security (Playbook 06)

### D-rank (autonomous) — 3 fixers

```bash
# Security headers (auto-detects framework):
01-APP-SEC/fixers/web/add-security-headers.sh ${FILE} ${FRAMEWORK}

# Cookie flags:
01-APP-SEC/fixers/web/fix-cookie-flags.sh ${FILE} ${FRAMEWORK}

# CORS config (replaces * with placeholder):
01-APP-SEC/fixers/web/fix-cors-config.sh ${FILE} ${FRAMEWORK}
```

### B-rank (escalate)
- **XSS/SQLi/SSRF**: Application-level vulnerabilities. Agent shows
  input source, sink, and suggested fix pattern. Human reviews.
- **CORS origin list**: Agent can't know legitimate client domains.

## Category: K8s Manifests (Playbook 10)

### D-rank (autonomous) — 5 fixers

```bash
# Security context (runAsNonRoot, drop ALL, readOnly, seccomp):
01-APP-SEC/fixers/k8s-manifests/add-security-context.sh ${FILE}

# Resource limits:
01-APP-SEC/fixers/k8s-manifests/add-resource-limits.sh ${FILE}

# Image pull policy:
01-APP-SEC/fixers/k8s-manifests/fix-image-pull-policy.sh ${FILE}

# Disable SA token mount:
01-APP-SEC/fixers/k8s-manifests/disable-service-account-token.sh ${FILE}
# EXCEPTION: skip for operators, controllers, monitoring agents
```

### C-rank (JADE)
- **Health probes**: JADE inspects app code for /health endpoints,
  determines probe type (httpGet vs tcpSocket), sets timing values.

## Category: Supply Chain (Playbook 11)

### D-rank (autonomous) — 3 fixers

```bash
# Pin images to digests:
01-APP-SEC/fixers/supply-chain/pin-base-image.sh ${FILE}

# Generate SBOM:
01-APP-SEC/fixers/supply-chain/generate-sbom.sh --fs ${TARGET_REPO} --output ${OUTPUT_DIR}/sbom/

# License compliance:
01-APP-SEC/fixers/supply-chain/check-licenses.sh ${TARGET_REPO} --strict
```

### C-rank (JADE)
- **Base image upgrade**: JADE compares CVE counts between versions.

### B-rank (escalate)
- **Copyleft license**: Legal decision — depends on project type.

## Commit Strategy

```
After each category completes:
  1. git add -A (within TARGET_REPO only)
  2. git commit -m "fix(security): [category] auto-remediation by jsa-devsec

     Findings fixed: {count}
     Fixers used: {fixer_list}
     Verified: {verified_count}/{total_count}"
  3. Do NOT push. Human reviews PR.
```

## Phase 2 Gate

```
IF all D-rank fixes applied AND verified:
  Continue to Phase 3
ELIF some D-rank fixes failed:
  Retry failed fixes once
  IF still failing → escalate to C-rank (JADE reviews)
  Continue to Phase 3 regardless (don't block on fix failures)
```
