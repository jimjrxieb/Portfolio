# Playbook: Supply Chain Perfection

> Verify all images are from trusted registries, properly tagged, and scanned. Ensure admission control blocks untrusted images.
>
> **When:** After secrets perfected. Supply chain is the entry point for most compromises.
> **Time:** ~20 min

---

## Prerequisites

- 01-APP-SEC scanners (Trivy, Grype) available
- Admission policies enforcing (from [05-admission-perfection](05-admission-perfection.md))
- Image inventory from [02-platform-integrity](02-platform-integrity.md)

---

## Step 1: Image Registry Audit

```bash
# All unique images in the cluster
kubectl get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u > /tmp/kubester-audit/all-images.txt

echo "Total unique images: $(wc -l < /tmp/kubester-audit/all-images.txt)"

# Images from untrusted registries
echo ""
echo "=== Untrusted Registries ==="
cat /tmp/kubester-audit/all-images.txt | grep -v -E 'registry.k8s.io|docker.io|gcr.io|quay.io|ghcr.io|public.ecr.aws' || echo "None found"

# Images without tags or using :latest
echo ""
echo "=== Untagged / :latest ==="
cat /tmp/kubester-audit/all-images.txt | grep -E ':latest$|^[^:]+$' || echo "None found"

# Images without digest pinning
echo ""
echo "=== Without Digest Pin ==="
cat /tmp/kubester-audit/all-images.txt | grep -v '@sha256:' | head -20
echo "(Only critical images need digest pinning)"
```

---

## Step 2: Scan All Running Images

```bash
# Scan each unique image for CVEs
while read IMAGE; do
    echo "Scanning: $IMAGE"
    trivy image "$IMAGE" --severity HIGH,CRITICAL --quiet 2>/dev/null | tail -5
    echo "---"
done < /tmp/kubester-audit/all-images.txt > /tmp/kubester-audit/image-scan.txt 2>&1

# Summary
echo ""
echo "Scan results: /tmp/kubester-audit/image-scan.txt"
grep -c "CRITICAL" /tmp/kubester-audit/image-scan.txt && echo "CRITICAL vulnerabilities found" || echo "No CRITICAL vulnerabilities"
```

For faster scanning, use the orchestrator from 01-APP-SEC:

```bash
bash ~/GP-copilot/GP-CONSULTING/01-APP-SEC/tools/run-all-scanners.sh --mode container --target <image>
```

---

## Step 3: Verify imagePullPolicy

```bash
# Pods NOT using Always pull policy (may run stale cached images)
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.metadata.namespace | test("kube-system") | not) |
  select(.spec.containers[]?.imagePullPolicy != "Always") |
  "\(.metadata.namespace)/\(.metadata.name): \(.spec.containers[].imagePullPolicy // "default")"' | head -20
```

Fix:

```bash
bash ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/hardening/fix-pull-policy.sh
```

---

## Step 4: Verify Admission Blocks Bad Images

```bash
# Test: :latest should be denied
kubectl run test-latest --image=nginx:latest --dry-run=server 2>&1
# Expected: denied by policy

# Test: untrusted registry should be denied (if policy exists)
kubectl run test-untrusted --image=evil-registry.com/backdoor:1.0 --dry-run=server 2>&1

# Verify these Kyverno policies are enforcing:
for POLICY in disallow-latest-tag require-semver-tags; do
    MODE=$(kubectl get clusterpolicy "$POLICY" -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null)
    echo "$POLICY: ${MODE:-NOT DEPLOYED}"
done
```

---

## Step 5: SBOM Check (If Required)

For engagements requiring Software Bill of Materials:

```bash
# Generate SBOM for a running image
command -v syft &>/dev/null && syft <image> -o cyclonedx-json > /tmp/kubester-audit/sbom.json

# Scan SBOM for vulnerabilities
command -v grype &>/dev/null && grype sbom:/tmp/kubester-audit/sbom.json
```

> **Reference:** `04-KUBESTER/reference/cks/05-supply-chain-security.md` for Dockerfile best practices, image signing, and SBOM details.

---

## Outputs

- Image inventory: all images catalogued with registries
- Untrusted images: flagged or removed
- CVE scan: all images scanned, CRITICAL findings documented
- imagePullPolicy: set to Always on all application pods
- Admission: verified blocking :latest and untrusted registries
- SBOM: generated if required

---

## Next

→ [10-runtime-perfection.md](10-runtime-perfection.md) — Tune Falco, verify watchers, test incident response
