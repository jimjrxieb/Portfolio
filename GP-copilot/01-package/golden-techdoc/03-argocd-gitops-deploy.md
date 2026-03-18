# 03 — ArgoCD GitOps Deployment

Deploy your app through Git, not `kubectl`. Push to your repo,
ArgoCD syncs it to the cluster automatically.

## Prerequisites (Platform Engineer Provides)

- ArgoCD installed and accessible
- Your Git repo reachable from the cluster
- Namespace creation enabled (`CreateNamespace=true` in sync options)

---

## Step 1: Helm Chart Structure

Your repo should have this layout:

```
your-app/
├── infrastructure/
│   └── charts/
│       └── your-app/
│           ├── Chart.yaml
│           ├── values.yaml
│           └── templates/
│               ├── _helpers.tpl
│               ├── namespace.yaml
│               ├── serviceaccount.yaml
│               ├── deployment.yaml
│               ├── service.yaml
│               ├── gateway.yaml
│               ├── httproute.yaml
│               ├── networkpolicy.yaml
│               └── pvc.yaml (if needed)
├── src/
├── Dockerfile
└── .github/
    └── workflows/
        └── main.yml
```

---

## Step 2: ArgoCD Application Manifest

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: your-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/name: your-app
spec:
  project: default
  source:
    repoURL: https://github.com/yourorg/your-app.git
    targetRevision: HEAD
    path: infrastructure/charts/your-app
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: your-app
  syncPolicy:
    automated:
      prune: true          # Delete resources removed from Git
      selfHeal: true       # Revert manual changes on cluster
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m0s
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas    # HPA controls replicas, not Git
```

Apply it:
```bash
kubectl apply -f infrastructure/method3-helm-argocd/argocd/your-app-application.yaml
```

---

## Step 3: CI/CD Image Tag Updates

Your CI pipeline builds images and updates `values.yaml` with the new tag.
ArgoCD detects the change and rolls out the update.

### GitHub Actions Pattern

```yaml
# .github/workflows/main.yml (relevant job)
update-image-tags:
  needs: [build-api, build-ui]
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
      with:
        token: ${{ secrets.GITHUB_TOKEN }}

    - name: Update Helm values with new image tags
      run: |
        SHORT_SHA=$(echo "${{ github.sha }}" | cut -c1-8)
        TAG="main-${SHORT_SHA}"
        sed -i "s|tag: \"main-.*\"|tag: \"${TAG}\"|g" \
          infrastructure/charts/your-app/values.yaml

    - name: Commit and push
      run: |
        git config user.name "github-actions[bot]"
        git config user.email "github-actions[bot]@users.noreply.github.com"
        git add infrastructure/charts/your-app/values.yaml
        git commit -m "chore: update image tags to ${TAG} [skip ci]"
        git push
```

**Important:** The commit message must contain `[skip ci]` to prevent
infinite CI loops (push triggers build triggers push...).

---

## Step 4: Verify Deployment

```bash
# Check ArgoCD app status
kubectl get application your-app -n argocd
# SYNC STATUS should be "Synced", HEALTH STATUS should be "Healthy"

# Check pods
kubectl get pods -n your-app
# All pods should be Running, READY x/x

# Check ArgoCD UI (if available)
# https://argocd.yourdomain.com/applications/your-app

# Force sync if needed
kubectl -n argocd patch application your-app \
  --type merge -p '{"operation":{"sync":{"source":{}}}}'
```

---

## Namespace Template

Include a namespace template in your chart so ArgoCD creates it:

```yaml
# templates/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: {{ .Values.global.namespace }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

PSS labels are required — the platform may enforce them via Kyverno.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| OutOfSync / Missing | Namespace doesn't exist | Ensure `CreateNamespace=true` in syncOptions AND namespace.yaml template |
| SyncFailed: "not found" | Resource ordering issue | Namespace must sync before other resources — add namespace.yaml to chart |
| Degraded / Progressing | Pods not ready | Check pod logs: `kubectl logs -n your-app <pod>` |
| ComparisonError | Helm template error | Run `helm template` locally to debug |
| 502 Bad Gateway | Gateway not accepted | Check GatewayClass exists: `kubectl get gatewayclass` |

---

## Chart Version Bumps

Bump `Chart.yaml` version on every infrastructure change:

```yaml
# Chart.yaml
version: 0.3.0    # Bump this on infra changes
appVersion: "1.0.0"  # Bump this on app code changes
```

ArgoCD uses chart version for diff detection. If you change templates
but not the version, sync may not detect the change.
