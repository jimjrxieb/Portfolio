# Playbook 11: Fix Supply Chain

> Secure the software supply chain — image pinning, SBOM generation, license compliance.
> CKS exam domain: Supply Chain Security.
>
> **Agent:** jsa-devsec (D rank auto-fix)
> **Scanners:** Trivy (SBOM, license, image), Checkov (CKV_DOCKER_7)
> **Phase:** 2 (Quick Wins) + Phase 3 (CI gates)

---

## When to Run

After Phase 1 baseline scan identifies:
- Unpinned base images (`:latest`, `:v1.0` without digest)
- Missing SBOM (no dependency inventory)
- Copyleft license issues in proprietary projects
- Base image CVEs that need upgrading

## Prerequisites

- Baseline scan completed (playbook 01)
- `trivy` installed (for SBOM + license scanning)
- `skopeo` or `docker` available (for digest resolution)

---

## Step 1: Pin Base Images to Digests (D-rank — auto-fix)

Tags can be mutated. Digests can't. Pin every FROM and image reference.

```bash
# Dockerfiles
find . -name "Dockerfile*" | while read -r df; do
  bash fixers/supply-chain/pin-base-image.sh "$df" --dry-run
done

# Apply
find . -name "Dockerfile*" | while read -r df; do
  bash fixers/supply-chain/pin-base-image.sh "$df"
done

# K8s manifests
find k8s/ -name "*.yaml" | while read -r manifest; do
  if grep -q "image:" "$manifest"; then
    bash fixers/supply-chain/pin-base-image.sh "$manifest"
  fi
done
```

**Covers:** Checkov CKV_DOCKER_7

**Maintenance:** Re-run monthly or use Renovate/Dependabot to auto-update digests when base images get security patches.

## Step 2: Generate SBOM (D-rank — auto-fix)

Know what's in your software. Required for supply chain audits.

```bash
# Filesystem SBOM (project dependencies)
bash fixers/supply-chain/generate-sbom.sh --fs . --output sbom/

# Container image SBOM
bash fixers/supply-chain/generate-sbom.sh --image myapp:v1.0 --output sbom/

# With license check
bash fixers/supply-chain/generate-sbom.sh --fs . --check-licenses
```

**Output:** CycloneDX JSON in `sbom/sbom-YYYYMMDD-HHMMSS.cdx.json`

**CI integration:** Add to build pipeline so every release has an SBOM artifact.

## Step 3: Check License Compliance (D-rank — auto-fix)

Flag copyleft licenses before they cause legal issues.

```bash
# Advisory mode (report only)
bash fixers/supply-chain/check-licenses.sh .

# Strict mode (fail CI if copyleft found)
bash fixers/supply-chain/check-licenses.sh . --strict

# Generate report
bash fixers/supply-chain/check-licenses.sh . --output license-report.md
```

**Copyleft licenses flagged:** GPL, AGPL, LGPL, SSPL, EUPL, OSL

**If copyleft found:**
- Internal-only projects: usually fine, document the decision
- Proprietary/SaaS: replace the dependency or get legal review
- Open-source: verify compatibility with your project license

## Step 4: Upgrade Base Images with CVEs (D-rank — auto-fix)

```bash
# Scan base images for CVEs
trivy image python:3.11-slim --severity CRITICAL,HIGH

# If CVEs found, upgrade to patched version
# Example: python:3.11.7-slim → python:3.11.8-slim
# Then re-pin the digest:
bash fixers/supply-chain/pin-base-image.sh Dockerfile
```

**Decision tree:**
```
Base image has CRITICAL CVE?
  ├── Newer version available → upgrade + pin digest (D-rank)
  ├── No fix available → document as accepted risk (B-rank)
  └── Can switch distro (slim → alpine) → evaluate + switch (C-rank)
```

## Step 5: CI Gate Setup (Phase 3)

Add supply chain checks to CI pipeline:

```yaml
# Add to .github/workflows/security.yml
supply-chain:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4

    - name: Pin check (no :latest tags)
      run: |
        if grep -rn ':latest' Dockerfile* k8s/*.yaml 2>/dev/null; then
          echo "::error::Found :latest tags — pin to specific versions"
          exit 1
        fi

    - name: Generate SBOM
      run: |
        trivy fs . --format cyclonedx --output sbom.cdx.json

    - name: License compliance
      run: |
        bash GP-CONSULTING/01-APP-SEC/fixers/supply-chain/check-licenses.sh . --strict

    - name: Upload SBOM
      uses: actions/upload-artifact@v4
      with:
        name: sbom
        path: sbom.cdx.json
```

---

## Expected Outcomes

- All base images pinned to `@sha256:` digests (no mutable tags)
- SBOM generated for every build (CycloneDX format)
- License compliance verified (no copyleft in proprietary)
- Base image CVEs addressed (upgrade or documented risk)
- CI gate blocks unpinned images and license violations

## CKS Exam Alignment

| CKS Topic | What This Playbook Covers |
|-----------|--------------------------|
| Minimize base image footprint | Base image CVE scanning + upgrade |
| Secure supply chain | Image digest pinning, SBOM generation |
| Image scanning | Trivy image + fs scanning |
| Use static analysis of workloads | Checkov CKV_DOCKER_7 (Dockerfile checks) |

---

## Rollback

```bash
# Restore pinned files
cp Dockerfile.bak Dockerfile
cp k8s/deployment.yaml.bak k8s/deployment.yaml
```

---

*Ghost Protocol — Supply Chain Security Playbook v1.0*
