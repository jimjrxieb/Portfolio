# Playbook 11: ArgoCD Integration

## Purpose

Wire runtime security into ArgoCD's sync lifecycle. After this playbook:

- ArgoCD manages Falco's lifecycle (self-heal, auto-prune, version pinning)
- PreSync hooks block deployments that fail conftest policy checks
- PostSync hooks verify Falco health and check for new critical alerts
- Prometheus alerts fire when syncs fail, apps degrade, or someone deploys with Falco down

## Prerequisites

- ArgoCD installed (`02-CLUSTER-HARDENING/tools/platform/setup-argocd.sh`)
- ArgoCD CLI installed (included in setup script, or see Phase 0 below)
- Falco deployed (`03-DEPLOY-RUNTIME/tools/deploy.sh`)
- Prometheus Operator installed (for alert rules)
- `kubectl` and `helm` available

Verify ArgoCD is running:

```bash
kubectl get pods -n argocd
# Expected: argocd-server, argocd-repo-server, argocd-application-controller all Running
```

## Phase 0: ArgoCD CLI Setup (2 min)

The setup script (`02-CLUSTER-HARDENING/tools/platform/setup-argocd.sh`) installs the CLI automatically. If it's missing or you need to install/upgrade manually:

### Install CLI

```bash
# Latest release
sudo curl -sSL -o /usr/local/bin/argocd \
    https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo chmod +x /usr/local/bin/argocd

# Verify
argocd version --client
```

### Login

On single-node clusters (k3s, minikube), the ClusterIP is reachable from the node:

```bash
# Get the ArgoCD server ClusterIP
kubectl -n argocd get svc argocd-server -o jsonpath='{.spec.clusterIP}'

# Login using ClusterIP (no port-forward needed)
argocd login <CLUSTER_IP> --insecure --username admin \
    --password $(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d)
```

If ClusterIP is not reachable (multi-node clusters, cloud providers):

```bash
# Port-forward first
kubectl -n argocd port-forward svc/argocd-server 8443:443 &

# Then login via localhost
argocd login localhost:8443 --insecure --username admin \
    --password $(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d)
```

### Common CLI Commands

```bash
# List all apps
argocd app list

# Get detailed status for an app
argocd app get <app-name>

# Force sync (when auto-sync is too slow or OutOfSync)
argocd app sync <app-name>

# View diff between live and desired state
argocd app diff <app-name>

# View sync history
argocd app history <app-name>

# Hard refresh (force re-read from git)
argocd app get <app-name> --hard-refresh
```

### Why install the CLI?

Without the CLI, manual sync requires awkward kubectl patches:

```bash
# Without CLI (works but fragile)
kubectl -n argocd patch app portfolio --type merge \
    -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# With CLI (clean, auditable)
argocd app sync portfolio
```

The CLI also gives you `diff`, `history`, `rollback`, and `logs` — none of which have clean kubectl equivalents.

## Phase 1: Deploy Core Integration (10 min)

### Step 1: Review what will be deployed

```bash
bash tools/deploy-argocd-hooks.sh --dry-run
```

Expected output shows: AppProject creation, Falco Application CRD, sync-fail alerts.

### Step 2: Deploy

```bash
bash tools/deploy-argocd-hooks.sh
```

If Falco is already managed by Helm and you don't want ArgoCD to take over:

```bash
bash tools/deploy-argocd-hooks.sh --skip-falco-app
```

### Step 3: Verify AppProject

```bash
kubectl get appproject runtime-security -n argocd -o yaml
```

Confirm allowed destinations include: `falco`, `jsa-infrasec`, `gp-security`, `monitoring`.

### Step 4: Verify Falco Application (if deployed)

```bash
# Check sync status
argocd app get falco

# Expected:
#   Name:       falco
#   Project:    runtime-security
#   Sync:       Synced
#   Health:     Healthy
```

If ArgoCD shows OutOfSync, it means your Helm-installed Falco differs from the declared state. Let ArgoCD reconcile:

```bash
argocd app sync falco
```

### Step 5: Verify alerts

```bash
kubectl get prometheusrule argocd-sync-alerts -n monitoring
```

Check Prometheus targets include ArgoCD metrics:

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# In browser: http://localhost:9090/targets
# Look for: argocd-application-controller, argocd-server
```

## Phase 2: Add PreSync Gate to an Application (15 min)

The PreSync gate runs conftest against manifests before ArgoCD applies them.

### Step 1: Create conftest policies ConfigMap

```bash
bash tools/deploy-argocd-hooks.sh --policies-configmap
```

This loads `01-APP-SEC/scanning-configs/conftest-policy.rego` into a ConfigMap that the PreSync Job mounts.

### Step 2: Add PreSync hook to your Application

Copy the template into your Application's manifest directory:

```bash
cp templates/argocd/pre-sync-security-gate.yaml /path/to/your-app/manifests/
```

Edit the file:
- Replace `{{ .Release.Namespace }}` with your app's namespace
- Replace `{{ .Release.Name }}` with your app's name

### Step 3: Test with a known-bad manifest

Create a test manifest with a privileged container:

```yaml
# test-bad-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-bad
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-bad
  template:
    metadata:
      labels:
        app: test-bad
    spec:
      containers:
        - name: bad
          image: nginx:latest        # DENY: latest tag
          securityContext:
            privileged: true         # DENY: privileged
            runAsUser: 0             # DENY: root user
```

Push to git. ArgoCD detects the change, runs PreSync hook, which fails on 3 DENY rules. Sync is blocked.

### Step 4: Fix and retry

Update the manifest to be compliant:

```yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: good
          image: nginx:1.27.3
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
```

Push to git. PreSync passes. ArgoCD applies. PostSync verifies.

## Phase 3: Add PostSync Verification (10 min)

### Step 1: Add PostSync hook to your Application

```bash
cp templates/argocd/post-sync-runtime-verify.yaml /path/to/your-app/manifests/
```

Edit: replace `{{ .Release.Namespace }}` with your app's namespace.

### Step 2: Apply the RBAC

The PostSync hook needs read access to Falco namespace and exec access to jsa-infrasec. The ClusterRole and ClusterRoleBinding are in the same file — apply them:

```bash
kubectl apply -f templates/argocd/post-sync-runtime-verify.yaml
```

### Step 3: Trigger a sync and watch

```bash
argocd app sync your-app-name

# Watch the PostSync Job
kubectl get jobs -n your-namespace -l phase=post-sync -w

# Check logs
kubectl logs -n your-namespace -l app=runtime-verify
```

Expected output:

```
=== PostSync Runtime Verification ===
  PASS  Falco DaemonSet: 3/3 pods ready
  PASS  falco-exporter: 1 pod(s) Running
  PASS  No critical Falco alerts in last 90s
  PASS  All pods in your-namespace have runAsNonRoot: true
  PASS  No privileged containers in your-namespace
  SKIP  jsa-infrasec not deployed (expected if package 04 not enabled)

=== Verification Summary ===
  Passed:  5
  Warned:  0
  Failed:  0

RESULT: HEALTHY — all checks passed
```

## Phase 4: Sync Wave Configuration (5 min)

If you want Falco to deploy before your application workloads, add sync wave annotations:

```yaml
# In your Application's manifest:
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"   # App deploys at wave 0
                                          # Falco is wave -2 (already running)
                                          # falco-exporter is wave -1 (metrics ready)
```

The Falco Application CRD (`falco-application.yaml`) already has `sync-wave: "-2"`. If both are in the same ArgoCD project, ArgoCD ensures Falco is healthy before syncing your app.

## Verification Checklist

After completing all phases:

- [ ] `argocd app list` shows falco + falco-exporter as Synced/Healthy
- [ ] `kubectl get appproject runtime-security -n argocd` exists with correct scoping
- [ ] `kubectl get prometheusrule argocd-sync-alerts -n monitoring` shows 6 rules
- [ ] PreSync gate blocks known-bad manifests (test with privileged container)
- [ ] PostSync verify passes after clean deploy
- [ ] Sync-fail alert fires in Prometheus when you force a bad sync

## Troubleshooting

**PreSync Job not running:**
- Check the hook annotation is exactly `argocd.argoproj.io/hook: PreSync`
- Verify the Job manifest is in the same directory ArgoCD is watching
- Check: `kubectl get jobs -n <namespace> -l phase=pre-sync`

**PostSync shows Falco not found:**
- Falco may be in a different namespace. Set `FALCO_NAMESPACE` env var in the Job spec
- Default is `falco` — if you used a custom namespace, update the template

**Sync succeeds but PostSync fails:**
- This is by design — PostSync failure marks the app as Degraded, not failed
- Check the verification logs: `kubectl logs -n <namespace> -l app=runtime-verify`
- If Falco alerts fired: investigate with `bash tools/debug-finding.sh`

**conftest-policies ConfigMap missing:**
- Run: `bash tools/deploy-argocd-hooks.sh --policies-configmap`
- The PreSync gate gracefully skips if the ConfigMap doesn't exist (falls back to admission control)

## Next Steps

- **Playbook 06**: Enable jsa-infrasec for autonomous response to PostSync findings
- **Playbook 07**: Operations guide for monitoring sync health long-term
- **02-CLUSTER-HARDENING/ENGAGEMENT-GUIDE.md**: Audit-to-enforce progression for Kyverno policies
