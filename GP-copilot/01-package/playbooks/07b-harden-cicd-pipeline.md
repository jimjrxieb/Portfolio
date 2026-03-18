# Playbook 07b: Harden CI/CD Pipeline & Image Delivery

> Secure the pipeline itself — from GitHub Actions through image build to registry push.
> This is the bridge between "code is scanned" (01-APP-SEC) and "cluster is ready" (02-CLUSTER-HARDENING).
>
> **When:** After CI pipeline is deployed (07) and configs are in place (07a)
> **Time:** ~30 min for initial setup
> **Agent:** jsa-devsec (D-rank for config checks, C-rank for workflow modifications)

---

## The Flow

```
Developer pushes code
       ↓
┌─────────────────────────────────────────────────────────┐
│ GITHUB ACTIONS (this playbook secures everything here)   │
│                                                          │
│  1. Scan code (gitleaks, semgrep, bandit, trivy, checkov)│
│  2. Build container image                                │
│  3. Scan the built image (trivy image)                   │
│  4. Sign the image (cosign)                              │
│  5. Generate + attach SBOM                               │
│  6. Push to secure registry                              │
│  7. Update manifest with new digest                      │
│                                                          │
└─────────────────────────────────────────────────────────┘
       ↓
ArgoCD detects manifest change → syncs to cluster
       ↓
02-CLUSTER-HARDENING admission policies validate:
  - Image is signed?
  - Image is from allowed registry?
  - Manifest passes policy checks?
       ↓
03-DEPLOY-RUNTIME: Falco watches the running workload
```

---

## Step 1: Harden the Workflow Files

### Pin ALL actions to SHA (not tags)

Tags can be mutated. SHA cannot. Same principle as image digest pinning.

```yaml
# BAD — tag can be changed by action maintainer
- uses: actions/checkout@v4

# GOOD — pinned to exact commit
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

**Find unpinned actions:**
```bash
grep -rn "uses:" .github/workflows/ | grep -v "@[a-f0-9]\{40\}" | grep -v "\./"
```

### Set least-privilege permissions

```yaml
# Workflow level — restrict all jobs by default
permissions:
  contents: read

# Job level — only what's needed
jobs:
  scan:
    permissions:
      contents: read
      security-events: write  # only if uploading SARIF

  build:
    permissions:
      contents: read
      packages: write  # only if pushing to GHCR
```

### Block dangerous patterns

```yaml
# NEVER use pull_request_target with checkout — script injection vector
# This lets external PR authors run arbitrary code with repo secrets
on:
  pull_request_target:  # DANGEROUS
    types: [opened]
steps:
  - uses: actions/checkout@...
    with:
      ref: ${{ github.event.pull_request.head.sha }}  # ATTACKER CODE

# NEVER interpolate event data in run: blocks
- run: echo "PR title: ${{ github.event.pull_request.title }}"  # INJECTION
# Use environment variables instead:
- run: echo "PR title: $PR_TITLE"
  env:
    PR_TITLE: ${{ github.event.pull_request.title }}
```

### Validate with GHA Scanner

```bash
# Run our GHA scanner against workflow files
python3 GP-CONSULTING/01-APP-SEC/scanners/gha_scanner_npc.py \
  --target .github/workflows/ \
  --output gha-findings.json
```

---

## Step 2: Add Image Build + Scan Stage

After code scanning passes, build the image and scan it before pushing:

```yaml
  build-and-scan:
    needs: [security-scan]
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - name: Build image
        run: |
          docker build -t ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} .

      - name: Scan built image for CVEs
        uses: aquasecurity/trivy-action@062f2592684a31eb3aa050cc61bb585dc798aaca  # v0.28.0
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-image.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'  # Fail if CRITICAL/HIGH CVEs found

      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-image.sarif'
```

---

## Step 3: Sign the Image (Cosign)

Image signing proves the image was built by your CI, not tampered with. The cluster admission controller (02-CLUSTER-HARDENING) verifies this signature before allowing deployment.

```yaml
      - name: Install cosign
        uses: sigstore/cosign-installer@dc72c7d5c4d10cd6bcb8cf6e3fd625a9e5e537da  # v3.7.0

      - name: Sign image
        run: |
          cosign sign --yes \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}
        env:
          COSIGN_EXPERIMENTAL: 1  # keyless signing via OIDC (GitHub Actions identity)
```

**Keyless signing** uses GitHub Actions' OIDC token — no private keys to manage. The signature proves:
- This image was built by THIS GitHub Actions workflow
- In THIS repository
- On THIS commit

---

## Step 4: Generate + Attach SBOM

```yaml
      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          format: cyclonedx-json
          output-file: sbom.cdx.json

      - name: Attach SBOM to image
        run: |
          cosign attach sbom \
            --sbom sbom.cdx.json \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}
```

---

## Step 5: Push to Registry

Only push after scan + sign + SBOM:

```yaml
      - name: Push image
        run: |
          docker push ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}

      - name: Tag as latest (main branch only)
        if: github.ref == 'refs/heads/main'
        run: |
          docker tag \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
          docker push ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
```

---

## Step 6: Update Manifest (GitOps Trigger)

For ArgoCD/Flux — update the manifest with the new image digest so GitOps picks it up:

```yaml
      - name: Update deployment manifest
        run: |
          # Update image tag in kustomization or values.yaml
          cd k8s/overlays/staging
          kustomize edit set image \
            ${{ env.IMAGE_NAME }}=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}

      - name: Commit manifest update
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add k8s/
          git commit -m "deploy: update image to ${{ github.sha }}"
          git push
```

**ArgoCD picks up the commit → syncs to cluster → admission policies validate → workload deploys.**

---

## Step 7: Protect Workflow Files

### CODEOWNERS

```bash
# Create .github/CODEOWNERS
cat >> .github/CODEOWNERS << 'EOF'

# Workflow files require security team review
.github/workflows/ @security-team
.github/CODEOWNERS @security-team
EOF
```

### Branch protection for workflow changes

```
GitHub repo → Settings → Branches → main
  [x] Require pull request reviews before merging
  [x] Require review from Code Owners
  [x] Include administrators
```

### Monitor workflow modifications

Add a CI step that alerts when workflow files change:

```yaml
  workflow-audit:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          fetch-depth: 0

      - name: Check for workflow changes
        run: |
          CHANGED=$(git diff --name-only origin/main...HEAD -- .github/workflows/)
          if [ -n "$CHANGED" ]; then
            echo "::warning::Workflow files modified — requires security team review"
            echo "Changed files:"
            echo "$CHANGED"
          fi
```

---

## Step 8: Verify

```bash
# Check all actions are SHA-pinned
grep -rn "uses:" .github/workflows/ | grep -v "@[a-f0-9]\{40\}" | grep -v "\./"
# Expected: 0 results

# Check permissions are set
grep -l "permissions:" .github/workflows/*.yml
# Expected: all workflow files

# Check no pull_request_target + checkout
grep -l "pull_request_target" .github/workflows/*.yml
# Expected: 0 results

# Check CODEOWNERS exists
cat .github/CODEOWNERS | grep workflows
# Expected: .github/workflows/ @security-team
```

---

## The Complete Chain

After this playbook, the delivery pipeline is:

| Step | What | Who Validates | Blocks On |
|------|------|---------------|-----------|
| Commit | Developer pushes | Pre-commit (08) | Secrets |
| PR | CI runs scanners | GHA workflow (07) | CRITICAL/HIGH findings |
| Build | Image built | Trivy image scan (this playbook) | Image CVEs |
| Sign | Image signed | Cosign keyless (this playbook) | — |
| SBOM | Attached to image | (this playbook) | — |
| Push | Image to registry | Only if scan + sign passed | — |
| Manifest | Updated with digest | GitOps commit (this playbook) | — |
| Admit | ArgoCD syncs | 02-CLUSTER-HARDENING admission | Unsigned/policy violation |
| Deploy | Workload runs | 03-DEPLOY-RUNTIME Falco | Runtime threats |

---

## Next Steps

- Deploy pre-commit hooks? → [08-deploy-pre-commit.md](08-deploy-pre-commit.md)
- Harden the cluster for deployment? → [02-CLUSTER-HARDENING](../../02-CLUSTER-HARDENING/ENGAGEMENT-GUIDE.md)
- Full rescan? → [09-post-fix-rescan.md](09-post-fix-rescan.md)

---

*Ghost Protocol — Pre-Deployment Security Package*
