# Playbook 12: Deploy Dev Environment

> Deploy the application server and Kubernetes cluster for the `dev/` environment using Helm.
>
> **When:** After Phase 2 fixes are committed and CI pipeline is green.
> **Agent:** jsa-devsec (E/D rank auto, C rank Katie approves)
> **Time:** ~15-20 min (first deploy), ~5 min (upgrades)

---

## The Principle

Dev is the first environment where hardened code runs in a real cluster. It validates that security fixes (securityContext, resource limits, probes) actually work at runtime — not just in YAML linting. If it breaks in dev, it never reaches staging.

---

## Prerequisites

- Playbooks 01-11 completed (code hardened, CI pipeline deployed)
- `kubectl` configured to reach the dev cluster
- `helm` v3.12+ installed
- Container images built and pushed to registry
- Namespace `dev` exists or you have permission to create it

```bash
# Verify prerequisites
kubectl cluster-info
helm version --short
docker images | grep <app-name>
```

---

## Step 1: Validate Cluster Access

```bash
# Confirm context is the dev cluster — NOT staging or prod
kubectl config current-context

# Verify namespace
kubectl get ns dev 2>/dev/null || kubectl create ns dev

# Check for ArgoCD ownership before doing anything
kubectl get ns dev -o jsonpath='{.metadata.labels.app\.kubernetes\.io/instance}' 2>/dev/null
# If this returns an ArgoCD app name → STOP. Fix in git, not kubectl.
```

---

## Step 2: Prepare Helm Values

Use the provided template or create from scratch:

```bash
# Option A: Use our dev values template
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/tools/helm-values-dev.yaml \
   <client-repo>/helm/values-dev.yaml

# Option B: Generate from existing deployment manifests
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/tools/deploy-dev.sh \
  --generate-values --target-dir <client-repo>/k8s/ --output <client-repo>/helm/values-dev.yaml
```

**Review and customize `values-dev.yaml`:**

| Field | Dev Default | Why |
|-------|------------|-----|
| `replicaCount` | 1 | Save resources in dev |
| `image.tag` | `dev-latest` | Tracks dev branch builds |
| `resources.limits.cpu` | `500m` | Enough for testing, not wasteful |
| `resources.limits.memory` | `512Mi` | Enough for testing, not wasteful |
| `securityContext.runAsNonRoot` | `true` | Enforced — matches prod |
| `securityContext.readOnlyRootFilesystem` | `true` | Enforced — matches prod |
| `ingress.enabled` | `false` | Port-forward for dev access |
| `autoscaling.enabled` | `false` | No HPA in dev |

---

## Step 3: Lint the Chart

```bash
cd <client-repo>

# Lint with dev values
helm lint helm/ -f helm/values-dev.yaml

# Template render — inspect what will be deployed
helm template <release-name> helm/ \
  -f helm/values-dev.yaml \
  --namespace dev \
  > /tmp/dev-rendered.yaml

# Scan the rendered manifests with checkov
checkov -f /tmp/dev-rendered.yaml --framework kubernetes

# Scan with kubescape
kubescape scan /tmp/dev-rendered.yaml --format pretty-printer
```

Fix any findings before deploying. The rendered YAML should pass the same checks as the source manifests.

---

## Step 4: Deploy with Helm

```bash
# Dry-run first — always
helm upgrade --install <release-name> helm/ \
  -f helm/values-dev.yaml \
  --namespace dev \
  --create-namespace \
  --dry-run

# Deploy for real
helm upgrade --install <release-name> helm/ \
  -f helm/values-dev.yaml \
  --namespace dev \
  --create-namespace \
  --wait \
  --timeout 5m

# Or use the deploy-dev.sh script (does all of the above)
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/tools/deploy-dev.sh \
  --chart <client-repo>/helm/ \
  --values <client-repo>/helm/values-dev.yaml \
  --release <release-name> \
  --namespace dev
```

---

## Step 5: Verify Deployment

```bash
# Check pod status
kubectl get pods -n dev -l app.kubernetes.io/instance=<release-name>

# Verify security context is applied
kubectl get pods -n dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].securityContext}{"\n"}{end}'

# Check for readiness
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=<release-name> -n dev --timeout=120s

# Verify Helm release status
helm status <release-name> -n dev

# Check Helm version deployed
helm list -n dev
```

---

## Step 6: Validate Security Posture

```bash
# Kubescape scan the live namespace
kubescape scan workload --namespace dev --format pretty-printer

# Verify no privileged containers
kubectl get pods -n dev -o jsonpath='{range .items[*].spec.containers[*]}{.name}{"\t"}{.securityContext.privileged}{"\n"}{end}'

# Verify resource limits are set
kubectl get pods -n dev -o jsonpath='{range .items[*].spec.containers[*]}{.name}{"\tCPU:"}{.resources.limits.cpu}{"\tMEM:"}{.resources.limits.memory}{"\n"}{end}'

# Verify no :latest tags
kubectl get pods -n dev -o jsonpath='{range .items[*].spec.containers[*]}{.image}{"\n"}{end}' | grep -E ':latest$' && echo "FAIL: :latest tag found" || echo "PASS: No :latest tags"

# Verify service account token not mounted (for app pods)
kubectl get pods -n dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.automountServiceAccountToken}{"\n"}{end}'
```

---

## Step 7: Smoke Test the Application

```bash
# Port-forward to local
kubectl port-forward svc/<release-name> 8080:80 -n dev &

# Health check
curl -sf http://localhost:8080/healthz && echo "HEALTHY" || echo "UNHEALTHY"

# Basic API test (if applicable)
curl -sf http://localhost:8080/api/status | jq .

# Kill the port-forward
kill %1
```

---

## Step 8: Deploy via CI (Optional)

If using the CI pipeline for dev deploys, copy the template:

```bash
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/ci-templates/deploy-dev.yml \
   <client-repo>/.github/workflows/deploy-dev.yml
```

**Required secrets in the client repo:**

| Secret | Purpose |
|--------|---------|
| `KUBE_CONFIG_DEV` | Base64-encoded kubeconfig for dev cluster |
| `REGISTRY_URL` | Container registry URL |
| `REGISTRY_USERNAME` | Registry auth username |
| `REGISTRY_PASSWORD` | Registry auth password |

---

## Expected Outcomes

- Helm release deployed to `dev` namespace with status `deployed`
- All pods running with hardened securityContext (runAsNonRoot, drop ALL, readOnly)
- Resource limits set on all containers
- No `:latest` image tags
- Health probes passing
- Kubescape scan shows 0 critical/high findings on live workloads
- Application responds to health checks

---

## Rollback

```bash
# See Helm release history
helm history <release-name> -n dev

# Rollback to previous revision
helm rollback <release-name> <revision> -n dev --wait

# Nuclear option — uninstall completely
helm uninstall <release-name> -n dev
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Pod `CrashLoopBackOff` | readOnlyRootFilesystem blocks writes | Add `emptyDir` volumes for `/tmp`, `/var/cache`, app write paths |
| Pod `CreateContainerConfigError` | Missing secrets/configmaps | Create secrets: `kubectl create secret generic <name> -n dev --from-file=...` |
| `ImagePullBackOff` | Registry auth missing | Create imagePullSecret: `kubectl create secret docker-registry regcred -n dev ...` |
| `FailedScheduling` | Resource requests exceed node capacity | Lower resource requests in values-dev.yaml or add a node |
| Health probe fails | Wrong port or path in values | Check `livenessProbe.httpGet.path` and `port` match your app |
| Helm lint fails | Invalid YAML or missing required values | Run `helm template` and fix errors one at a time |

---

## Next Steps

- Post-fix rescan? -> [09-post-fix-rescan.md](09-post-fix-rescan.md)
- Harden the cluster itself? -> 02-CLUSTER-HARDENING package
- Deploy runtime monitoring? -> 03-DEPLOY-RUNTIME package

---

*Ghost Protocol — Dev Environment Deployment Playbook v1.0*
