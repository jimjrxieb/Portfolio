# Playbook 10: Fix Kubernetes Manifests

> Fix security findings in K8s YAML files **in the repo** (pre-deploy).
> These are code fixes — patching YAML before it reaches the cluster.
>
> **Agent:** jsa-devsec (E/D rank auto-fix, C rank JADE approves)
> **Scanners:** Checkov, Kubescape, Polaris
> **Phase:** 2 (Quick Wins)

---

## When to Run

After Phase 1 baseline scan flags K8s manifest findings:
- Checkov: `CKV_K8S_*` rules
- Kubescape: `C-00*` controls
- Polaris: workload audit warnings

## Prerequisites

- Baseline scan completed (playbook 01)
- Findings triaged — only E/D/C tier K8s findings here
- `yq` or `python3` available for YAML manipulation

---

## Step 1: Identify K8s Manifest Findings

```bash
# Filter K8s findings from triage output
python3 tools/triage.py --input outputs/baseline-*/checkov.json \
  --filter 'CKV_K8S' --output k8s-findings.csv

python3 tools/triage.py --input outputs/baseline-*/kubescape.json \
  --filter 'C-00' --output k8s-findings.csv --append
```

## Step 2: Fix SecurityContext (D-rank — auto-fix)

The most common finding. Adds `runAsNonRoot`, `readOnlyRootFilesystem`, `drop ALL`, `seccompProfile`.

```bash
# Dry-run first
bash fixers/k8s-manifests/add-security-context.sh k8s/deployment.yaml --dry-run

# Apply
bash fixers/k8s-manifests/add-security-context.sh k8s/deployment.yaml

# Re-scan to verify
checkov -f k8s/deployment.yaml --check CKV_K8S_6,CKV_K8S_20,CKV_K8S_22,CKV_K8S_28
```

**Covers:**
| Rule ID | Control | What Gets Fixed |
|---------|---------|----------------|
| CKV_K8S_6 | runAsNonRoot | Pod runs as non-root |
| CKV_K8S_20 | allowPrivilegeEscalation | No privilege escalation |
| CKV_K8S_22 | readOnlyRootFilesystem | Immutable filesystem |
| CKV_K8S_28 | drop ALL capabilities | No unnecessary Linux caps |
| CKV_K8S_37 | seccompProfile | Seccomp RuntimeDefault set |
| C-0017 | privileged containers | No privileged mode |
| C-0057 | privilege escalation | Blocks escalation |

## Step 3: Fix Resource Limits (D-rank — auto-fix)

```bash
# Default limits: 100m/128Mi requests, 500m/512Mi limits
bash fixers/k8s-manifests/add-resource-limits.sh k8s/deployment.yaml

# Custom limits for heavy workloads
CPU_REQUEST=500m CPU_LIMIT=2 MEM_REQUEST=512Mi MEM_LIMIT=2Gi \
  bash fixers/k8s-manifests/add-resource-limits.sh k8s/worker.yaml
```

**Covers:** CKV_K8S_11, CKV_K8S_12, CKV_K8S_13, C-0009, Polaris cpuLimitsMissing

## Step 4: Fix Image Pull Policy (D-rank — auto-fix)

```bash
bash fixers/k8s-manifests/fix-image-pull-policy.sh k8s/deployment.yaml
```

**Covers:** Polaris pullPolicyNotAlways, Kubescape C-0048

**Manual follow-up:** Replace any `:latest` tags flagged by the script with specific semver versions.

## Step 5: Disable ServiceAccount Token (D-rank — auto-fix)

Most app pods don't need the Kubernetes API token. Disabling it reduces blast radius if the pod is compromised.

```bash
bash fixers/k8s-manifests/disable-service-account-token.sh k8s/deployment.yaml
```

**Covers:** CKV_K8S_43, Kubescape C-0036

**Exception:** Don't run this on pods that call the K8s API (operators, controllers, monitoring agents).

## Step 6: Add Health Probes (C-rank — JADE approves)

This is C-rank because it requires knowing the app's health endpoint.

```bash
# Default: liveness → /healthz, readiness → /ready, port 8080
bash fixers/k8s-manifests/add-probes.sh k8s/deployment.yaml --port 8080

# Custom endpoints
bash fixers/k8s-manifests/add-probes.sh k8s/api.yaml --port 3000 \
  --liveness-path /api/health --readiness-path /api/ready
```

**Covers:** CKV_K8S_8, CKV_K8S_9, Polaris readinessProbeMissing, livenessProbeMissing

**Before applying:** Verify your app actually serves the health endpoints. Test:
```bash
kubectl port-forward deploy/<name> 8080:8080
curl http://localhost:8080/healthz
curl http://localhost:8080/ready
```

### Liveness vs Readiness — Get This Wrong and Pods Restart Forever

**Liveness** answers: "Is the process alive?" — check internal state only.
**Readiness** answers: "Can it serve traffic?" — check dependencies (DB, DNS, cache).

| | Liveness | Readiness |
|---|----------|-----------|
| **Purpose** | Restart stuck process | Remove from Service endpoints |
| **On failure** | kubelet kills the pod | Pod stops receiving traffic |
| **Should check** | Process health only (`/healthz`) | Dependencies too (`/ready`) |
| **Timeout** | Generous (5-10s) | Can be tighter (3-5s) |
| **Failure threshold** | High (5-6) | Lower is OK (3) |

**The mistake that causes restart loops:** Using a "deep" health check (e.g., `/healthz?full=true` that tests DB + DNS + cache) as the **liveness** probe. When an external dependency has a brief hiccup, kubelet thinks the process is dead and kills a perfectly healthy pod. With a 5-second timeout and only 3 failures allowed, even a brief network blip causes a restart cascade.

**The fix:**
```yaml
# WRONG — liveness checks external deps, causes unnecessary restarts
livenessProbe:
  httpGet:
    path: /healthz?full=true    # Tests DB, DNS, cache
    port: 8080
  timeoutSeconds: 5
  failureThreshold: 3

# RIGHT — liveness checks process only, readiness checks deps
livenessProbe:
  httpGet:
    path: /healthz              # Just "am I alive?"
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 20
  timeoutSeconds: 10
  failureThreshold: 6
readinessProbe:
  httpGet:
    path: /ready                # Checks DB, DNS, cache
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

**Rule of thumb:** If your app has a "deep" health check that validates external dependencies, that goes on **readiness**, never on **liveness**. Liveness should only fail if the process itself is hung or deadlocked.

## Step 7: Batch Fix All Manifests

For repos with many K8s YAML files:

```bash
# Find all K8s manifests
find k8s/ -name "*.yaml" -o -name "*.yml" | while read -r manifest; do
  if grep -q "^kind:" "$manifest"; then
    echo "=== $manifest ==="
    bash fixers/k8s-manifests/add-security-context.sh "$manifest"
    bash fixers/k8s-manifests/add-resource-limits.sh "$manifest"
    bash fixers/k8s-manifests/fix-image-pull-policy.sh "$manifest"
    bash fixers/k8s-manifests/disable-service-account-token.sh "$manifest"
  fi
done
```

## Step 8: Re-scan and Verify

```bash
# Full re-scan
checkov -d k8s/ --framework kubernetes
kubescape scan k8s/ --format pretty-printer
polaris audit --audit-path k8s/

# Validate YAML is still valid
for f in k8s/*.yaml; do
  kubectl --dry-run=client apply -f "$f" 2>&1 | grep -i error && echo "INVALID: $f"
done
```

---

## Expected Outcomes

- All Deployments/StatefulSets have securityContext (runAsNonRoot, drop ALL, readOnly)
- All containers have resource requests and limits
- All images use specific version tags (no :latest)
- ServiceAccount tokens disabled for app pods
- Health probes on all containers (after human verification)
- 0 Checkov CKV_K8S_* failures
- 0 Kubescape critical/high findings

---

## Rollback

All scripts create `.bak` backups:
```bash
# Restore single file
cp k8s/deployment.yaml.bak k8s/deployment.yaml

# Restore all
for bak in k8s/*.bak; do cp "$bak" "${bak%.bak}"; done
```

---

*Ghost Protocol — K8s Manifest Hardening Playbook v1.0*
