# Playbook 17a — Deploy Staging Environment

> Deploy the application server and cluster workloads to the `staging` environment using Helm.
> Staging is the last gate before production — prod-like config, security validation, and promotion approval.
>
> **When:** After dev deployment is validated (Playbook 12-deploy-dev or 14-golden-path + 17-gitops-promotion).
> **Audience:** Platform engineer deploying or validating staging before prod promotion.
> **Time:** ~20 min (first deploy), ~5 min (upgrades)

---

## The Principle

Staging must be a mirror of production — same security context, same admission policies, same resource class. The only differences are replica count and ingress exposure. If it passes staging, it passes prod. If you relax staging "to make it easier," you've made prod deployments a gamble.

**ArgoCD rule:** If ArgoCD manages the staging namespace, do NOT use this playbook's `helm upgrade` commands. Use the GitOps promotion workflow (Playbook 17) instead. This playbook is for clusters without GitOps or for initial Helm bootstrapping.

---

## Prerequisites

- [ ] Dev deployment validated and stable
- [ ] Cluster hardened (Playbook 05 — admission control running)
- [ ] `kubectl` configured to reach the staging cluster/namespace
- [ ] `helm` v3.12+ installed
- [ ] Container images built, scanned, and pushed to registry
- [ ] Kyverno/Gatekeeper running in audit or enforce mode

```bash
# Verify prerequisites
kubectl cluster-info
helm version --short
kubectl get ns staging 2>/dev/null || echo "staging namespace does not exist"

# Check if ArgoCD manages staging — STOP if it does
kubectl get ns staging -o jsonpath='{.metadata.labels.app\.kubernetes\.io/instance}' 2>/dev/null
# Non-empty = ArgoCD-managed → use Playbook 17 (GitOps promotion), NOT this playbook
```

---

## Step 1: Pre-Flight Checks

```bash
PKG=~/linkops-industries/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING

# Run pre-flight to detect platform quirks, PSA conflicts, admission control state
bash $PKG/tools/hardening/pre-flight-check.sh
```

### Check admission control is running

Staging deploys must pass admission control. If Kyverno/Gatekeeper isn't running, your staging is lying to you about prod readiness.

```bash
# Kyverno
kubectl get pods -n kyverno
kubectl get clusterpolicy

# Or Gatekeeper
kubectl get pods -n gatekeeper-system
kubectl get constrainttemplate
```

If admission control isn't deployed yet, run Playbook 06 first.

---

## Step 2: Create Staging Namespace (Hardened)

```bash
# PSS labels are REQUIRED — Kyverno blocks namespaces without them
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
    environment: staging
EOF
```

> **Dev uses `baseline`. Staging uses `restricted`.** This is intentional. If your app can't run under `restricted` PSS, fix the app before promoting to prod.

---

## Step 3: Prepare Helm Values

Use the staging values template or generate from existing manifests:

```bash
# Option A: Use our staging values template
cp $PKG/tools/platform/helm-values-staging.yaml \
   <client-repo>/helm/values-staging.yaml

# Option B: Generate from dev values (customize resources + replicas)
bash $PKG/tools/platform/deploy-stage.sh \
  --generate-values \
  --from-values <client-repo>/helm/values-dev.yaml \
  --output <client-repo>/helm/values-staging.yaml
```

**Review and customize `values-staging.yaml`:**

| Field | Staging Default | Prod Equivalent | Why |
|-------|----------------|-----------------|-----|
| `replicaCount` | 2 | 3 | Test HA, save resources |
| `image.tag` | (promoted from dev) | same tag | Same artifact, different config |
| `resources.requests.cpu` | `250m` | `250m` | Match prod |
| `resources.requests.memory` | `256Mi` | `256Mi` | Match prod |
| `resources.limits.cpu` | `1` | `1` | Match prod |
| `resources.limits.memory` | `1Gi` | `1Gi` | Match prod |
| `securityContext.runAsNonRoot` | `true` | `true` | Enforced — same as prod |
| `securityContext.readOnlyRootFilesystem` | `true` | `true` | Enforced — same as prod |
| `ingress.enabled` | `true` | `true` | Test ingress before prod |
| `autoscaling.enabled` | `false` | `true` | HPA only in prod |
| `networkPolicy.enabled` | `true` | `true` | Test segmentation |

**The security context block is IDENTICAL to prod.** No exceptions. If the app can't run with these settings in staging, it can't run in prod.

---

## Step 4: Lint and Scan

```bash
cd <client-repo>

# Lint with staging values
helm lint helm/ -f helm/values-staging.yaml

# Template render — inspect what will be deployed
helm template <release-name> helm/ \
  -f helm/values-staging.yaml \
  --namespace staging \
  > /tmp/staging-rendered.yaml

# Scan rendered manifests with checkov
checkov -f /tmp/staging-rendered.yaml --framework kubernetes

# Scan with kubescape (use NSA + MITRE frameworks — staging must pass both)
kubescape scan /tmp/staging-rendered.yaml \
  --format pretty-printer \
  --frameworks nsa,mitre

# Validate against Kyverno policies (offline)
kubectl apply -f /tmp/staging-rendered.yaml --dry-run=server 2>&1 | grep -i "admission webhook"
```

**Gate:** Fix any CRITICAL or HIGH findings before deploying. Staging is the last chance to catch these.

---

## Step 5: Deploy with Helm

```bash
# Dry-run first — always
helm upgrade --install <release-name> helm/ \
  -f helm/values-staging.yaml \
  --namespace staging \
  --dry-run

# Deploy
helm upgrade --install <release-name> helm/ \
  -f helm/values-staging.yaml \
  --namespace staging \
  --wait \
  --timeout 5m

# Or use the deploy-stage.sh script (does lint + scan + deploy + verify)
bash $PKG/tools/platform/deploy-stage.sh \
  --chart <client-repo>/helm/ \
  --values <client-repo>/helm/values-staging.yaml \
  --release <release-name> \
  --namespace staging
```

---

## Step 6: Verify Deployment

```bash
# Pod status
kubectl get pods -n staging -l app.kubernetes.io/instance=<release-name> -o wide

# Verify security context is enforced
kubectl get pods -n staging -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].securityContext}{"\n"}{end}'

# Wait for readiness
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=<release-name> \
  -n staging --timeout=120s

# Helm release info (version, chart, status)
helm list -n staging
helm status <release-name> -n staging
```

---

## Step 7: Security Validation (Staging-Specific)

Staging gets deeper validation than dev. This is the prod dress rehearsal.

### 7a: Live Namespace Scan

```bash
# Kubescape on live workloads (must pass NSA + MITRE)
kubescape scan workload --namespace staging \
  --frameworks nsa,mitre \
  --format pretty-printer

# Check Kyverno policy reports for violations
kubectl get policyreport -n staging
kubectl get clusterpolicyreport
```

### 7b: Verify No :latest Tags

```bash
kubectl get pods -n staging \
  -o jsonpath='{range .items[*].spec.containers[*]}{.image}{"\n"}{end}' | \
  grep -E ':latest$' && echo "FAIL: :latest tag found — block prod promotion" || echo "PASS"
```

### 7c: Verify Network Policies

```bash
# Check NetworkPolicies exist
kubectl get networkpolicy -n staging

# Test default-deny works (run from a different namespace)
kubectl run nettest --rm -it --image=busybox -n default -- \
  wget -qO- --timeout=3 http://<release-name>.staging:80 2>&1 | \
  grep -q "timed out" && echo "PASS: NetworkPolicy blocks cross-ns traffic" || echo "FAIL"

# Test same-namespace access works
kubectl run nettest --rm -it --image=busybox -n staging -- \
  wget -qO- --timeout=3 http://<release-name>:80
```

### 7d: Verify RBAC

```bash
# Check ServiceAccount has no excess permissions
kubectl auth can-i --list --as=system:serviceaccount:staging:<release-name> -n staging
```

### 7e: Resource Compliance

```bash
# Verify resource limits match prod expectations
kubectl get pods -n staging \
  -o jsonpath='{range .items[*].spec.containers[*]}{.name}{"\tCPU:"}{.resources.limits.cpu}{"\tMEM:"}{.resources.limits.memory}{"\n"}{end}'

# Check LimitRange is applied
kubectl get limitrange -n staging -o yaml
```

---

## Step 8: Smoke Test

```bash
# Port-forward (local/Kind clusters)
kubectl port-forward svc/<release-name> 8080:80 -n staging &

# Health check
curl -sf http://localhost:8080/healthz && echo "HEALTHY" || echo "UNHEALTHY"

# API smoke test
curl -sf http://localhost:8080/api/status | jq .

# Kill port-forward
kill %1
```

For clusters with Gateway API / ingress:
```bash
# Test via staging URL
curl -sf https://staging.example.internal/healthz && echo "HEALTHY" || echo "UNHEALTHY"
```

---

## Step 9: Deploy via CI (Optional)

Copy the GitHub Actions workflow template:

```bash
mkdir -p <client-repo>/.github/workflows
cp $PKG/ci-templates/deploy-staging.yml \
   <client-repo>/.github/workflows/deploy-staging.yml
```

**Required secrets in the client repo:**

| Secret | Purpose |
|--------|---------|
| `KUBE_CONFIG_STAGING` | Base64-encoded kubeconfig for staging cluster |
| `REGISTRY_URL` | Container registry URL |
| `REGISTRY_USERNAME` | Registry auth username |
| `REGISTRY_PASSWORD` | Registry auth password |

**Trigger:** Manual dispatch or auto-trigger on dev success. Staging NEVER auto-deploys from develop branch — only promoted images.

---

## Step 10: Promotion to Prod

Once staging is validated:

### Option A: GitOps (ArgoCD — preferred)

```bash
bash $PKG/tools/platform/promote-image.sh \
  --app <app-name> \
  --from staging \
  --to prod

# Create a PR — prod promotion always requires review
git checkout -b promote/<app-name>-<tag>-prod
git add .
git commit -m "promote: <app-name> <tag> from staging to prod"
git push -u origin promote/<app-name>-<tag>-prod

# Senior reviews + approves → merge → ArgoCD syncs prod
```

### Option B: Helm (no GitOps)

```bash
helm upgrade --install <release-name> helm/ \
  -f helm/values-prod.yaml \
  --namespace prod \
  --wait \
  --timeout 5m
```

---

## Expected Outcomes

- Helm release deployed to `staging` namespace with status `deployed`
- PSS `restricted` enforced on namespace
- All pods running with hardened securityContext (same as prod)
- Resource limits match prod class (250m/256Mi requests, 1/1Gi limits)
- 2 replicas running
- No `:latest` image tags
- Kubescape NSA + MITRE: 0 critical/high findings
- Kyverno policy report: 0 violations
- NetworkPolicy: default-deny active, cross-namespace blocked
- Health probes passing
- Ready for prod promotion

---

## Rollback

```bash
# See Helm release history
helm history <release-name> -n staging

# Rollback to previous revision
helm rollback <release-name> <revision> -n staging --wait

# Nuclear option — uninstall completely
helm uninstall <release-name> -n staging
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Kyverno blocks deployment | Missing securityContext, no limits, or :latest tag | Fix the chart — staging enforces the same policies prod will |
| Pod `CrashLoopBackOff` | readOnlyRootFilesystem blocks writes | Add `emptyDir` volumes for `/tmp`, `/var/cache`, app write paths |
| `ImagePullBackOff` | Registry auth missing in staging namespace | `kubectl create secret docker-registry regcred -n staging ...` |
| `FailedScheduling` | Resource requests exceed node capacity | Check node resources: `kubectl describe nodes | grep -A5 Allocated` |
| NetworkPolicy blocks needed traffic | Missing egress rule to shared service (DB, cache) | Add egress rule to NetworkPolicy targeting the service namespace |
| PSS violation event | Container violates restricted PSS | Fix the container — staging uses restricted PSS, same as prod |
| Health probe fails | Different port/path than dev | Check values-staging.yaml probe config matches the app |
| Passes in dev but fails in staging | Dev uses `baseline` PSS, staging uses `restricted` | The failure IS the value — fix the container before prod |

---

## CNPA + CKS Exam Relevance

| Domain | Coverage |
|--------|----------|
| **Platform Engineering Core (36%)** | Staging as prod mirror, standardized delivery |
| **Continuous Delivery (16%)** | Helm + promotion workflow = progressive delivery |
| **Security & Conformance (20%)** | PSS restricted, NetworkPolicy, admission control validation |
| **Observability (16%)** | Health probes, policy reports, security scans |

**Exam pattern:** "How do you validate a deployment before production?" → Staging with identical security context, admission control, NetworkPolicy, and automated scanning. Not manual testing.

---

## Next Steps

- Set up the full GitOps promotion pipeline? → [17-gitops-promotion-workflow.md](17-gitops-promotion-workflow.md)
- Need golden path manifests first? → [14-golden-path-deployment.md](14-golden-path-deployment.md)
- Deploy runtime monitoring? → 03-DEPLOY-RUNTIME package

---

*Ghost Protocol — Platform Engineering (CNPA/CKS)*
