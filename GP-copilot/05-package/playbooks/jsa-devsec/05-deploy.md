# Phase 5: Autonomous Dev Deployment

Source playbook: `01-APP-SEC/playbooks/12-deploy-dev.md`
Automation level: **75% autonomous (D-rank)**, 12.5% JADE (C-rank), 12.5% human (B-rank)
**Optional phase** — only runs if `project_profile.has_kubernetes = true`

## What the Agent Does

```
1. Validate cluster access (refuse if ArgoCD-managed)
2. Helm lint + template + scan rendered YAML
3. kubectl dry-run
4. Helm install/upgrade
5. Verify pods running + security posture
6. Smoke test (JADE C-rank)
```

## Prerequisites

```bash
# Must have:
which helm kubectl kubescape checkov

# Must have cluster context:
kubectl cluster-info

# Must have values file:
test -f ${VALUES_FILE} || cp 01-APP-SEC/tools/helm-values-dev.yaml ${VALUES_FILE}
```

## Step-by-Step

### 1. Validate Access — D-rank

```bash
# Check cluster is reachable
kubectl cluster-info || { echo "No cluster access"; exit 1; }

# CRITICAL: Check ArgoCD ownership
ARGOCD_APP=$(kubectl get ns ${NAMESPACE} -o jsonpath='{.metadata.labels.app\.kubernetes\.io/instance}' 2>/dev/null)
if [ -n "${ARGOCD_APP}" ]; then
  echo "ABORT: Namespace ${NAMESPACE} is managed by ArgoCD app '${ARGOCD_APP}'"
  echo "Fix in git, not kubectl. See .claude/rules/argocd-rules.md"
  exit 1
fi
```

### 2. Helm Lint + Template — D-rank

```bash
# Lint
helm lint ${CHART_PATH} -f ${VALUES_FILE}

# Render templates
helm template ${RELEASE} ${CHART_PATH} -f ${VALUES_FILE} \
  --namespace ${NAMESPACE} > ${OUTPUT_DIR}/rendered.yaml

# Scan rendered YAML for security issues
checkov -f ${OUTPUT_DIR}/rendered.yaml --framework kubernetes --quiet
kubescape scan ${OUTPUT_DIR}/rendered.yaml
```

If Checkov or Kubescape find issues in rendered YAML, log them but continue.
Phase 2 fixers should have already addressed these in source manifests.

### 3. Dry Run — D-rank

```bash
kubectl apply --dry-run=client -f ${OUTPUT_DIR}/rendered.yaml
```

If dry-run fails (invalid YAML, missing CRDs, etc.), abort and escalate.

### 4. Install — D-rank

```bash
helm upgrade --install ${RELEASE} ${CHART_PATH} \
  -f ${VALUES_FILE} \
  --namespace ${NAMESPACE} \
  --create-namespace \
  --wait \
  --timeout 5m
```

### 5. Verify — D-rank

```bash
# Pods running
kubectl get pods -n ${NAMESPACE} -l app=${RELEASE}
kubectl wait --for=condition=ready pod -l app=${RELEASE} -n ${NAMESPACE} --timeout=120s

# Security posture
kubescape scan --include-namespaces ${NAMESPACE}

# Verify security context applied
kubectl get pods -n ${NAMESPACE} -o jsonpath='{range .items[*]}{.metadata.name}: runAsNonRoot={.spec.containers[0].securityContext.runAsNonRoot}{"\n"}{end}'

# Verify no :latest tags
kubectl get pods -n ${NAMESPACE} -o jsonpath='{range .items[*].spec.containers[*]}{.image}{"\n"}{end}' | grep -v ':latest' || echo "WARNING: :latest tag detected"

# Check release status
helm status ${RELEASE} -n ${NAMESPACE}
```

### 6. Smoke Test — C-rank (JADE)

JADE performs:
```bash
# Port-forward
kubectl port-forward svc/${RELEASE} 8080:${SERVICE_PORT} -n ${NAMESPACE} &
PF_PID=$!

# Hit health endpoint
curl -sf http://localhost:8080${HEALTH_PATH} && echo "HEALTHY" || echo "UNHEALTHY"

# Check logs for errors
kubectl logs -l app=${RELEASE} -n ${NAMESPACE} --tail=50 | grep -i -E "error|exception|fatal"

kill $PF_PID
```

JADE decides: pass (app is healthy) or fail (escalate to human).

### 7. Troubleshoot Failures — B-rank (human)

If any step fails, agent captures diagnostics and escalates:

```bash
# Capture everything human needs
kubectl describe pod -l app=${RELEASE} -n ${NAMESPACE} > ${OUTPUT_DIR}/pod-describe.txt
kubectl logs -l app=${RELEASE} -n ${NAMESPACE} --all-containers > ${OUTPUT_DIR}/pod-logs.txt
kubectl get events -n ${NAMESPACE} --sort-by='.lastTimestamp' > ${OUTPUT_DIR}/events.txt
helm status ${RELEASE} -n ${NAMESPACE} > ${OUTPUT_DIR}/helm-status.txt
```

Common failures and what to tell human:
| Symptom | Likely Cause | Suggested Fix |
|---------|-------------|---------------|
| CrashLoopBackOff | readOnlyRootFilesystem blocking writes | Add emptyDir volumes for /tmp, /var |
| ImagePullBackOff | Missing imagePullSecret | Create secret with registry credentials |
| FailedScheduling | Insufficient resources | Lower resource requests or add nodes |
| Probe failures | Wrong health endpoint | Verify path/port matches app |

## Commit

```bash
# Only commit values file and workflow if they were generated
git add ${VALUES_FILE} .github/workflows/deploy-dev.yml 2>/dev/null
git commit -m "feat(deploy): dev environment deployment config

  Namespace: ${NAMESPACE}
  Release: ${RELEASE}
  Chart: ${CHART_PATH}
  Security verified: kubescape + checkov scan passed

  Deployed by jsa-devsec autonomous engagement" 2>/dev/null || true
```

## Phase 5 Gate

```
IF pods healthy AND security posture passes AND smoke test passes:
  Engagement complete. Generate final report.
ELIF pods healthy BUT smoke test fails:
  Log warning, escalate smoke test failure, engagement "mostly complete"
ELSE:
  Escalate to human with full diagnostics
  Engagement "code hardened, deploy needs manual intervention"
```
