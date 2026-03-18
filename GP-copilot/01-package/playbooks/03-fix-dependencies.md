# Playbook: Fix Dependency Vulnerabilities

> Remediate CVEs found by Trivy and Grype in pip, npm, go, yarn, and gem packages.
>
> **When:** After baseline scan shows dependency CVEs (Trivy-fs, Grype output)
> **Time:** ~20 min per repo (most bumps are straightforward)

---

## The Rule

Dependency CVEs are D-rank — high auto-fix rate. The fixer bumps the version in the manifest file. You test, you commit. The scanner tells you the exact fixed version.

---

## Step 1: Identify What's Vulnerable

```bash
# From the remediation plan
grep -A3 "CVE-" <scan-output>/REMEDIATION-PLAN.md

# Or from raw Trivy output — CRITICAL and HIGH CVEs with fix versions
jq -r '.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL" or .Severity=="HIGH") | "\(.Severity) \(.PkgName)@\(.InstalledVersion) → \(.FixedVersion // "NO FIX") \(.VulnerabilityID)"' \
  <scan-output>/trivy-fs.json

# From Grype — same info, different format
jq -r '.matches[] | select(.vulnerability.severity=="Critical" or .vulnerability.severity=="High") | "\(.vulnerability.severity) \(.artifact.name)@\(.artifact.version) → \(.vulnerability.fix.versions[0] // "NO FIX") \(.vulnerability.id)"' \
  <scan-output>/grype.json
```

---

## Step 2: Bump Each Package

```bash
# Usage: bash bump-cves.sh <package-manager> <package-name> <fixed-version>

# Python (pip)
bash fixers/dependencies/bump-cves.sh pip python-multipart 0.0.20
bash fixers/dependencies/bump-cves.sh pip cryptography 42.0.4
bash fixers/dependencies/bump-cves.sh pip werkzeug 3.0.6

# Node.js (npm)
bash fixers/dependencies/bump-cves.sh npm lodash 4.17.21
bash fixers/dependencies/bump-cves.sh npm express 4.19.2

# Go
bash fixers/dependencies/bump-cves.sh go golang.org/x/net v0.23.0

# Ruby (gem)
bash fixers/dependencies/bump-cves.sh gem nokogiri 1.16.2

# Yarn
bash fixers/dependencies/bump-cves.sh yarn axios 1.7.4
```

**What the script does:**
- Creates a `.bak` backup of the manifest file (requirements.txt, package.json, go.mod, Gemfile)
- Updates the version pin to the fixed version
- Prints what changed

---

## Step 3: Install and Test

After bumping, install the updated dependencies and run tests:

```bash
# Python
pip install -r requirements.txt
pytest tests/

# Node.js
npm install
npm test

# Go
go mod tidy
go test ./...
```

**Watch for breaking changes.** Major version bumps (1.x → 2.x) can break APIs. Check the package changelog if tests fail.

---

## Step 4: Handle "No Fix Available"

Some CVEs have no patched version yet. For each:

1. **Check if it's actually reachable** — does your code call the vulnerable function?
   ```bash
   # Example: CVE in a transitive dependency you never import directly
   # If your code never calls the vulnerable path, risk is lower
   ```

2. **Document as accepted risk:**
   ```markdown
   | CVE-2024-XXXXX | package@1.2.3 | No fix available as of 2026-03-11 | Review monthly |
   ```

3. **Look for alternative packages** that provide the same functionality

4. **Pin and isolate** — if you must keep it, ensure the component has minimal attack surface

---

## Step 5: Verify

```bash
# Re-run Trivy
trivy fs . --severity HIGH,CRITICAL --format json 2>/dev/null \
  | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL" or .Severity=="HIGH")] | length'
# Expected: 0 (or only "no fix available" entries)

# Re-run Grype
grype dir:. -o json 2>/dev/null \
  | jq '[.matches[] | select(.vulnerability.severity=="Critical" or .vulnerability.severity=="High")] | length'
# Expected: 0
```

---

## Step 6: Commit

```bash
git add requirements.txt package.json package-lock.json go.mod go.sum Gemfile Gemfile.lock
git commit -m "security: bump vulnerable dependencies (CVE remediation)"
```

---

## Edge Cases

**"Bumping package X breaks package Y"**
- Check if both have compatible version ranges: `pip check` or `npm ls <package>`
- Sometimes you need to bump both simultaneously

**"The CVE is in a dev dependency only"**
- Still fix it — devDependencies run in CI and on developer machines
- Lower priority than production dependencies, but don't ignore

**"Lock file conflicts after bump"**
- Regenerate: `pip freeze > requirements.txt` or `npm install` (regenerates package-lock.json)
- Don't hand-edit lock files

---

## Next Steps

- Python SAST findings? → [04-fix-python-sast.md](04-fix-python-sast.md)
- Dockerfile issues? → [05-fix-dockerfiles.md](05-fix-dockerfiles.md)
- Ready to rescan? → [09-post-fix-rescan.md](09-post-fix-rescan.md)

---

*Ghost Protocol — Pre-Deployment Security Package*
