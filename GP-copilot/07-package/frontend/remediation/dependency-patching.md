# Dependency Patching — FedRAMP SI-2, CM-8

## The Problem

Known CVEs in third-party dependencies are FedRAMP findings.
SI-2 requires flaw remediation; CM-8 requires component inventory (SBOM).

## Step 1: Scan

```bash
# Python
pip-audit --require-hashes --desc
trivy fs --config ../scanning-configs/trivy-fedramp.yaml --scanners vuln .

# Node.js
npm audit --production
trivy fs --config ../scanning-configs/trivy-fedramp.yaml --scanners vuln .

# Go
trivy fs --config ../scanning-configs/trivy-fedramp.yaml --scanners vuln .
```

## Step 2: Prioritize by Severity

| Severity | FedRAMP SLA | Action |
|----------|-------------|--------|
| CRITICAL | 30 days | Patch immediately, escalate if blocked |
| HIGH | 30 days | Patch in current sprint |
| MEDIUM | 90 days | Patch in next sprint |
| LOW | 180 days | Track in POA&M |

## Step 3: Patch

```bash
# Python — update specific package
pip install package-name==X.Y.Z
pip freeze > requirements.txt

# Node.js — update specific package
npm install package-name@X.Y.Z --save-exact

# Verify no new CVEs introduced
pip-audit  # or npm audit
```

## Step 4: Generate SBOM

```bash
# Trivy SBOM (CycloneDX format — FedRAMP accepted)
trivy fs --format cyclonedx --output sbom.json .

# Syft (alternative)
syft dir:. -o cyclonedx-json > sbom.json
```

## Step 5: Pin Everything

```
# requirements.txt — GOOD
flask==3.1.0
gunicorn==23.0.0
pyotp==2.9.0

# requirements.txt — BAD
flask>=3.0
gunicorn
pyotp~=2.9
```

```json
// package.json — GOOD
{
  "dependencies": {
    "express": "4.21.1",
    "helmet": "7.1.0"
  }
}
```

## CI Integration

Add to your pipeline (see `ci-templates/sast-analysis.yml`):

```yaml
- name: Dependency audit
  run: |
    pip-audit --require-hashes --desc || exit 1
    trivy fs --exit-code 1 --severity CRITICAL,HIGH .
```

## Evidence Artifacts for 3PAO

- [ ] Clean dependency audit (zero CRITICAL/HIGH)
- [ ] SBOM in CycloneDX or SPDX format
- [ ] Pinned dependency files (`requirements.txt`, `package-lock.json`)
- [ ] CI logs showing automated scanning on every PR

## Remediation Priority: D — Auto-Remediate

Dependency updates are pattern-based. Automated tooling can auto-bump and verify.
