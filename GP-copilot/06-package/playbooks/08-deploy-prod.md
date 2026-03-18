# Playbook 08 — Deploy Production (Helm + EKS)

> Deploy the application to the production EKS cluster using Helm. This is the final promotion
> after dev (01-APP-SEC/12) and staging (02-CLUSTER-HARDENING/17a) have been validated.
>
> **When:** Staging has been validated, security scans are clean, and promotion is approved.
> **Audience:** Platform engineer executing the prod cutover. Senior approval required.
> **Time:** ~30 min (first deploy), ~10 min (upgrades)

---

## The Principle

Production is not where you find problems — it's where you prove you already fixed them. Every security control that was validated in staging must be identical in prod. The only differences are replica count, resource allocation, autoscaling, and ingress configuration.

**Three gates before prod:**
1. Dev: Does the code work? (01-APP-SEC Playbook 12)
2. Staging: Does it work under production-class security? (02-CLUSTER-HARDENING Playbook 17a)
3. Prod: Same artifact, same security, scaled for real traffic (this playbook)

**ArgoCD rule:** If ArgoCD manages the prod namespace, use the GitOps promotion workflow (02-CLUSTER-HARDENING Playbook 17, `promote-image.sh`). This playbook is for Helm-based deploys without GitOps.

---

## Prerequisites

- [ ] Staging deployment validated and stable (02-CLUSTER-HARDENING Playbook 17a)
- [ ] Same image tag that ran in staging — never build a new image for prod
- [ ] EKS cluster deployed and hardened (Playbooks 04 + 05)
- [ ] IAM roles created, IRSA configured (Playbook 02 + 05)
- [ ] KMS keys created, encryption enabled (Playbook 03)
- [ ] Monitoring and logging active (Playbook 07)
- [ ] `kubectl` + `helm` v3.12+ configured for prod cluster
- [ ] Senior approval documented (git commit, Slack message, or PR approval)

```bash
PKG=~/linkops-industries/GP-copilot/GP-CONSULTING/06-CLOUD-SECURITY

# Verify prerequisites
kubectl cluster-info
helm version --short
aws eks describe-cluster --name <cluster-name> --query "cluster.status"
aws eks describe-cluster --name <cluster-name> --query "cluster.resourcesVpcConfig.endpointPublicAccess"
# Must be false for prod

# Confirm this is the PROD context — not dev, not staging
kubectl config current-context
```

---

## Step 1: Pre-Flight Security Audit

Before touching prod, verify the EKS cluster meets security requirements.

```bash
# EKS security posture
bash $PKG/tools/validate-aws-security.sh --cluster <cluster-name> --region us-east-1

# Or manual checks:
# Private endpoint?
aws eks describe-cluster --name <cluster-name> \
  --query "cluster.resourcesVpcConfig.endpointPublicAccess" --output text
# Must be: False

# All logging enabled?
aws eks describe-cluster --name <cluster-name> \
  --query "cluster.logging.clusterLogging[?enabled==\`true\`].types[]" --output text
# Must be: api audit authenticator controllerManager scheduler

# Envelope encryption?
aws eks describe-cluster --name <cluster-name> \
  --query "cluster.encryptionConfig[0].resources" --output text
# Must be: secrets

# OIDC provider?
aws eks describe-cluster --name <cluster-name> \
  --query "cluster.identity.oidc.issuer" --output text
# Must return a URL
```

**STOP if any check fails.** Fix it in Playbook 05 before deploying to prod.

---

## Step 2: Create Production Namespace (Hardened)

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: prod
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
    environment: production
EOF
```

### Create ImagePullSecret (if using private ECR)

```bash
# Get ECR login token
ECR_TOKEN=$(aws ecr get-login-password --region us-east-1)
REGISTRY="<account-id>.dkr.ecr.us-east-1.amazonaws.com"

kubectl create secret docker-registry ecr-cred \
  --docker-server="$REGISTRY" \
  --docker-username=AWS \
  --docker-password="$ECR_TOKEN" \
  -n prod

# Note: ECR tokens expire every 12 hours. For production, use:
# - IRSA with ECR pull permissions on the node role (preferred)
# - Or a CronJob that refreshes the secret
```

---

## Step 3: Prepare Helm Values

```bash
# Option A: Use our prod values template
cp $PKG/tools/helm-values-prod.yaml <client-repo>/helm/values-prod.yaml

# Option B: Generate from staging values (upgrade replicas + enable HPA)
bash $PKG/tools/deploy-prod.sh \
  --generate-values \
  --from-values <client-repo>/helm/values-staging.yaml \
  --output <client-repo>/helm/values-prod.yaml
```

**Production values must include:**

| Field | Prod Value | Why |
|-------|-----------|-----|
| `replicaCount` | 3 | HA — survives node failure |
| `image.tag` | exact semver | Same tag validated in staging |
| `image.pullPolicy` | `IfNotPresent` | Don't re-pull on restart |
| `resources.requests.cpu` | `250m` | Match staging (prod class) |
| `resources.requests.memory` | `256Mi` | Match staging (prod class) |
| `resources.limits.cpu` | `1` | Match staging (prod class) |
| `resources.limits.memory` | `1Gi` | Match staging (prod class) |
| `securityContext` | (identical to staging) | No relaxation in prod |
| `autoscaling.enabled` | `true` | HPA for traffic spikes |
| `autoscaling.minReplicas` | 3 | Never drop below HA threshold |
| `autoscaling.maxReplicas` | 10 | Cap resource consumption |
| `ingress.enabled` | `true` | Public-facing via ALB |
| `networkPolicy.enabled` | `true` | Default-deny + explicit allow |
| `podDisruptionBudget.minAvailable` | 2 | Survive rolling updates |
| `serviceAccount.annotations` | IRSA role ARN | Pod-level AWS permissions |

### IRSA ServiceAccount Annotation

```yaml
serviceAccount:
  create: true
  automount: false
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::<account-id>:role/<app-name>-prod-role"
```

---

## Step 4: Lint, Render, and Scan

```bash
cd <client-repo>

# Lint
helm lint helm/ -f helm/values-prod.yaml

# Render
helm template <release-name> helm/ \
  -f helm/values-prod.yaml \
  --namespace prod \
  > /tmp/prod-rendered.yaml

# Checkov scan
checkov -f /tmp/prod-rendered.yaml --framework kubernetes --compact

# Kubescape NSA + MITRE (both frameworks required for prod)
kubescape scan /tmp/prod-rendered.yaml \
  --frameworks nsa,mitre \
  --format pretty-printer

# Validate against cluster admission control (dry-run=server hits Kyverno/Gatekeeper)
kubectl apply -f /tmp/prod-rendered.yaml --dry-run=server --namespace prod 2>&1 | grep -i "denied\|error"
```

**Gate:** Zero CRITICAL findings. Zero admission denials. Fix before deploying.

---

## Step 5: Deploy with Helm

### Dry-run first

```bash
helm upgrade --install <release-name> helm/ \
  -f helm/values-prod.yaml \
  --namespace prod \
  --dry-run
```

### Deploy

```bash
# Using the deploy-prod.sh script (recommended — includes all validation)
bash $PKG/tools/deploy-prod.sh \
  --chart <client-repo>/helm/ \
  --values <client-repo>/helm/values-prod.yaml \
  --release <release-name> \
  --namespace prod

# Or manual helm upgrade
helm upgrade --install <release-name> helm/ \
  -f helm/values-prod.yaml \
  --namespace prod \
  --wait \
  --timeout 10m \
  --atomic
```

**`--atomic` is critical for prod.** If the deploy fails, Helm automatically rolls back to the previous release. In staging we don't use it (we want to debug failures). In prod we always use it.

---

## Step 6: Verify Deployment

```bash
# Pod status — all must be Running
kubectl get pods -n prod -l app.kubernetes.io/instance=<release-name> -o wide

# Wait for full readiness
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=<release-name> \
  -n prod --timeout=180s

# Helm release info
helm list -n prod
helm status <release-name> -n prod

# Check rollout status
kubectl rollout status deployment/<release-name> -n prod

# Verify HPA is active
kubectl get hpa -n prod
```

---

## Step 7: Security Validation (Production-Specific)

### 7a: Core Security Checks

```bash
# No :latest tags
kubectl get pods -n prod \
  -o jsonpath='{range .items[*].spec.containers[*]}{.image}{"\n"}{end}' | \
  grep -E ':latest$' && echo "FAIL — BLOCK" || echo "PASS"

# runAsNonRoot on all pods
kubectl get pods -n prod -l app.kubernetes.io/instance=<release-name> \
  -o jsonpath='{range .items[*].spec.securityContext}{.runAsNonRoot}{"\n"}{end}'

# readOnlyRootFilesystem on all containers
kubectl get pods -n prod -l app.kubernetes.io/instance=<release-name> \
  -o jsonpath='{range .items[*].spec.containers[*].securityContext}{.readOnlyRootFilesystem}{"\n"}{end}'

# Resource limits set
kubectl get pods -n prod \
  -o jsonpath='{range .items[*].spec.containers[*]}{.name}{"\tCPU:"}{.resources.limits.cpu}{"\tMEM:"}{.resources.limits.memory}{"\n"}{end}'

# PSS restricted on namespace
kubectl get ns prod -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'
# Must be: restricted
```

### 7b: AWS-Specific Checks

```bash
# IRSA working? Pod can reach AWS without node-level creds
kubectl exec -n prod deploy/<release-name> -- \
  aws sts get-caller-identity 2>/dev/null | jq .Arn
# Should show the IRSA role, NOT the node role

# ServiceAccount token not mounted (for non-AWS pods)
kubectl get pods -n prod \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.automountServiceAccountToken}{"\n"}{end}'
```

### 7c: Network Validation

```bash
# NetworkPolicies exist
kubectl get networkpolicy -n prod

# Test default-deny (from another namespace — should be blocked)
kubectl run nettest --rm -it --image=busybox -n default -- \
  wget -qO- --timeout=3 http://<release-name>.prod:80 2>&1
# Expected: timeout

# Test same-namespace (should work)
kubectl run nettest --rm -it --image=busybox -n prod -- \
  wget -qO- --timeout=3 http://<release-name>:80
# Expected: success
```

### 7d: Kyverno/Gatekeeper Policy Report

```bash
kubectl get policyreport -n prod
kubectl get policyreport -n prod -o jsonpath='{range .items[*]}{.summary}{"\n"}{end}'
# fail count must be 0
```

### 7e: Live Kubescape Scan

```bash
kubescape scan workload --namespace prod \
  --frameworks nsa,mitre \
  --format pretty-printer
```

---

## Step 8: Smoke Test

```bash
# Via ALB/Ingress (production URL)
curl -sf https://app.example.com/healthz && echo "HEALTHY" || echo "UNHEALTHY"
curl -sf https://app.example.com/api/status | jq .

# Or port-forward if no ingress yet
kubectl port-forward svc/<release-name> 8080:80 -n prod &
curl -sf http://localhost:8080/healthz && echo "HEALTHY" || echo "UNHEALTHY"
kill %1
```

---

## Step 9: Enable Monitoring & Alerts

```bash
# Verify Container Insights
aws cloudwatch list-metrics \
  --namespace ContainerInsights \
  --dimensions Name=ClusterName,Value=<cluster-name> \
  --query "Metrics[0].MetricName"

# Create billing alarm for prod namespace costs
aws cloudwatch put-metric-alarm \
  --alarm-name "prod-cost-anomaly" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 1000 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:us-east-1:<account-id>:critical-alerts

# Verify EKS control plane logs flowing
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/eks/<cluster-name>/cluster" \
  --query "logGroups[].logGroupName"
```

---

## Step 10: Deploy via CI (Optional)

```bash
mkdir -p <client-repo>/.github/workflows
cp $PKG/ci-templates/deploy-prod.yml \
   <client-repo>/.github/workflows/deploy-prod.yml
```

**Required GitHub secrets:**

| Secret | Purpose |
|--------|---------|
| `KUBE_CONFIG_PROD` | Base64-encoded kubeconfig for prod EKS cluster |
| `AWS_ROLE_ARN` | OIDC role for CI (Playbook 06) |
| `REGISTRY_URL` | ECR registry URL |

**Trigger:** Manual dispatch ONLY. Prod deploys are never automatic.

**Environment protection:** Configure `prod` environment in GitHub with:
- Required reviewers (senior + platform engineer)
- Wait timer (optional — 15 min cooldown)
- Branch restriction (main only)

---

## Expected Outcomes

- Helm release deployed to `prod` namespace with status `deployed` and `--atomic` rollback safety
- PSS `restricted` enforced on namespace
- All pods running with hardened securityContext (identical to staging)
- 3+ replicas with HPA configured (min 3, max 10)
- PodDisruptionBudget (minAvailable: 2)
- No `:latest` image tags — exact semver from staging
- IRSA working — pod uses role, not node credentials
- NetworkPolicy: default-deny active, cross-namespace blocked
- Kubescape NSA + MITRE: 0 critical/high findings
- Kyverno policy report: 0 violations
- CloudWatch metrics flowing, alarms configured
- Health probes passing, ALB health checks green
- Application responding on production URL

---

## Rollback

```bash
# Helm history — see all revisions
helm history <release-name> -n prod

# Rollback to previous revision (--atomic already did this if deploy failed)
helm rollback <release-name> <revision> -n prod --wait --timeout 5m

# Verify rollback
kubectl rollout status deployment/<release-name> -n prod
helm status <release-name> -n prod
```

### Emergency Rollback (skip validation)

```bash
# Last resort — rolls back immediately
helm rollback <release-name> 0 -n prod --wait
# 0 = previous release
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `--atomic` rolled back automatically | Deploy failed (probe timeout, crash) | Check `helm status`, `kubectl logs`, fix in staging first |
| Pods `CrashLoopBackOff` | readOnlyRootFilesystem, missing secrets, wrong port | Should have been caught in staging — fix and re-promote |
| `ImagePullBackOff` | ECR token expired or IRSA not configured | Refresh ECR secret or fix node role permissions |
| HPA not scaling | Metrics server not installed or wrong CPU target | `kubectl get hpa -n prod` — check TARGETS column |
| ALB 502/504 | Pod not ready, probe misconfigured | Check readiness probe, target group health |
| IRSA not working | Wrong trust policy or SA annotation | `kubectl describe sa <name> -n prod` — check annotation |
| NetworkPolicy blocks legitimate traffic | Missing egress rule for external service | Add egress rule targeting the service CIDR |
| PSS violation event | Container violates restricted PSS | Fix the container — should have been caught in staging |
| CloudWatch metrics missing | Container Insights not enabled | `aws eks update-cluster-config --name <cluster> --logging` |

---

## Production Cutover Checklist

Use this for the first prod deploy (Day 1 cutover):

```
PRE-DEPLOY:
  [ ] Staging validated and signed off
  [ ] Same image tag as staging (never rebuild for prod)
  [ ] Senior approval documented
  [ ] Rollback plan reviewed
  [ ] On-call engineer identified
  [ ] Communication sent to stakeholders

DEPLOY:
  [ ] Pre-flight security audit passed (Step 1)
  [ ] Namespace created with PSS restricted
  [ ] Helm deploy with --atomic succeeded
  [ ] All pods Running + Ready
  [ ] HPA configured and responsive

POST-DEPLOY:
  [ ] Security validation passed (Step 7)
  [ ] Smoke test passed (Step 8)
  [ ] Monitoring active (Step 9)
  [ ] DNS cutover (if applicable)
  [ ] Load test (if first deploy)
  [ ] Stakeholder notification sent

NEXT 24 HOURS:
  [ ] Monitor error rates
  [ ] Monitor latency P50/P95/P99
  [ ] Monitor pod restarts
  [ ] Monitor HPA scaling events
  [ ] Review CloudTrail for unusual API calls
```

---

## Next Steps

- Set up incident response runbooks? → [09-incident-response.md](09-incident-response.md)
- Full security validation audit? → [10-security-validation.md](10-security-validation.md)
- Runtime monitoring with Falco? → 03-DEPLOY-RUNTIME package

---

*Ghost Protocol — Cloud Security Package*
