# Playbook 13 — Golden Path Deployment

> Stamp out a production-ready Kustomize deployment for any service in 30 seconds.
>
> **When:** A developer needs a new service deployed. Or you're onboarding an existing app onto the platform.
> **Time:** ~5 min (generate + review + apply)

---

## What This Does

The golden path is a templatized set of Kustomize manifests. You run one script, pass it an app name and image, and it generates a complete deployment structure — hardened, with overlays for dev/staging/prod, and ArgoCD applications ready to go.

The developer never writes YAML. You stamp it out. Kyverno validates it. ArgoCD deploys it.

```
You run:
  bash tools/platform/create-app-deployment.sh \
    --app-name payments-api \
    --image ghcr.io/acme/payments-api:v1.0

You get:
  payments-api/
  ├── base/                    # Hardened base (non-root, drop ALL, read-only rootfs)
  │   ├── kustomization.yaml
  │   ├── namespace.yaml       # PSS restricted labels
  │   ├── deployment.yaml      # Security context, probes, resources
  │   ├── service.yaml         # ClusterIP
  │   ├── rbac.yaml            # Dedicated ServiceAccount
  │   ├── networkpolicy.yaml   # Default-deny + DNS + app ingress
  │   ├── resourcequota.yaml   # Namespace resource ceiling
  │   ├── limitrange.yaml      # Per-pod defaults
  │   └── pdb.yaml             # Pod disruption budget
  ├── overlays/
  │   ├── dev/                 # 1 replica, relaxed resources
  │   ├── staging/             # 2 replicas, prod-like
  │   └── prod/                # 3 replicas, full resources
  └── argocd/
      ├── application-dev.yaml
      ├── application-staging.yaml
      └── application-prod.yaml
```

---

## What's Baked In (Security Defaults)

Every deployment stamped from the golden path includes these by default. The developer doesn't choose them — you chose for them:

| Setting | Value | Why |
|---------|-------|-----|
| `runAsNonRoot` | `true` | CIS 5.2.7 — no root containers |
| `runAsUser` | `10001` | Non-privileged UID |
| `allowPrivilegeEscalation` | `false` | CIS 5.2.5 — block privesc |
| `readOnlyRootFilesystem` | `true` | CIS 5.2.4 — immutable container |
| `capabilities.drop` | `ALL` | CIS 5.2.9 — zero Linux capabilities |
| `seccompProfile` | `RuntimeDefault` | CIS 5.7.2 — syscall filtering |
| `automountServiceAccountToken` | `false` | CIS 5.1.6 — no token unless needed |
| `livenessProbe` | HTTP GET | Restart on crash |
| `readinessProbe` | HTTP GET | Don't route traffic until ready |
| `resources.requests` | 128Mi / 100m | Scheduler can bin-pack |
| `resources.limits` | 512Mi / 500m | OOM protection |
| `NetworkPolicy` | default-deny + DNS + app | Zero-trust networking |
| `PodDisruptionBudget` | `minAvailable: 1` | Survive node drains |
| `RollingUpdate` | `maxUnavailable: 0` | Zero-downtime deploys |
| `/tmp` volume | emptyDir | Writable tmp without writable rootfs |

---

## Prerequisites

- [ ] `kubectl` configured with cluster access
- [ ] Kustomize installed (`kubectl` v1.14+ has it built in)
- [ ] Admission control deployed (Playbook 05) — Kyverno validates the output
- [ ] ArgoCD deployed (Playbook via `tools/platform/setup-argocd.sh`) — if using GitOps

---

## Step 1: Generate the Deployment

### Minimal (defaults everything)

```bash
bash tools/platform/create-app-deployment.sh \
  --app-name myapp \
  --image ghcr.io/org/myapp:v1.0
```

### Full options

```bash
bash tools/platform/create-app-deployment.sh \
  --app-name payments-api \
  --image ghcr.io/acme/payments-api:v1.0 \
  --port 3000 \
  --namespace payments \
  --health-path /api/health \
  --manifests-repo https://github.com/acme/k8s-manifests.git \
  --output-dir ~/deployments/payments-api
```

| Flag | Default | What it does |
|------|---------|-------------|
| `--app-name` | (required) | Names everything: deployment, service, namespace, labels |
| `--image` | (required) | Container image with tag |
| `--port` | 8080 | Container port, service port, probe port, NetworkPolicy port |
| `--namespace` | same as app-name | Kubernetes namespace |
| `--health-path` | `/health` | Liveness + readiness probe path |
| `--manifests-repo` | placeholder URL | Git repo for ArgoCD Application |
| `--output-dir` | `./<app-name>` | Where to write the output |

---

## Step 2: Review the Output

```bash
# Look at the generated manifests
cat payments-api/base/deployment.yaml

# Verify security context is correct
grep -A 15 "securityContext" payments-api/base/deployment.yaml

# Dry-run apply to check for errors
kubectl apply -k payments-api/overlays/dev/ --dry-run=client
```

**What to check:**
- [ ] Image tag is correct (not `:latest`)
- [ ] Port matches your app's actual listen port
- [ ] Health path matches your app's actual health endpoint
- [ ] Namespace doesn't conflict with existing namespaces

---

## Step 3: Deploy

### Option A: Manual (kubectl)

```bash
# Start with dev
kubectl apply -k payments-api/overlays/dev/

# Verify
kubectl get pods -n payments
kubectl get svc -n payments

# Promote to staging
kubectl apply -k payments-api/overlays/staging/

# Promote to prod
kubectl apply -k payments-api/overlays/prod/
```

### Option B: GitOps (ArgoCD)

```bash
# Push manifests to a git repo
cd payments-api
git init && git add . && git commit -m "initial deployment"
git remote add origin https://github.com/acme/payments-api-manifests.git
git push -u origin main

# Tell ArgoCD to watch the repo
kubectl apply -f argocd/application-dev.yaml

# ArgoCD auto-syncs. To promote:
kubectl apply -f argocd/application-staging.yaml
kubectl apply -f argocd/application-prod.yaml
```

### Option C: Backstage (developer self-service)

The Backstage "Secure Microservice" template calls this script behind the scenes. Developer fills a form → Backstage scaffolds → ArgoCD deploys. You never run this manually.

See: [Playbook 11 — Deploy Backstage](11-deploy-backstage.md)

---

## Step 4: Verify the Deployment

```bash
# Pods running?
kubectl get pods -n payments -o wide

# Service reachable?
kubectl port-forward -n payments svc/payments-api 8080:3000
curl http://localhost:8080/api/health

# NetworkPolicy working? (should block traffic from other namespaces)
kubectl run test --rm -it --image=busybox -n default -- wget -qO- http://payments-api.payments:3000/api/health
# Expected: timeout (blocked by NetworkPolicy)

kubectl run test --rm -it --image=busybox -n payments -- wget -qO- http://payments-api:3000/api/health
# Expected: success (same namespace allowed)

# Kyverno didn't complain?
kubectl get policyreport -n payments
```

---

## Step 5: Update Image Tag (Day 2)

```bash
# Manual
cd payments-api/overlays/prod
kustomize edit set image ghcr.io/acme/payments-api:v1.0=ghcr.io/acme/payments-api:v1.1
kubectl apply -k .

# GitOps
cd payments-api/overlays/prod
kustomize edit set image ghcr.io/acme/payments-api:v1.0=ghcr.io/acme/payments-api:v1.1
git add . && git commit -m "deploy: payments-api v1.1" && git push
# ArgoCD auto-syncs
```

---

## Overlay Differences

| Setting | Dev | Staging | Prod |
|---------|-----|---------|------|
| Replicas | 1 | 2 | 3 |
| CPU request | 50m | 128Mi | 250m |
| CPU limit | 250m | 512Mi | 1 |
| Memory request | 64Mi | 128Mi | 256Mi |
| Memory limit | 256Mi | 512Mi | 1Gi |
| ResourceQuota pods | 10 | 20 | 50 |

Security context is the SAME across all overlays. Non-root, drop ALL, read-only rootfs — no exceptions, not even in dev.

---

## Customizing the Golden Path

The templates live at `templates/golden-path/`. If you need to change the defaults for ALL future deployments:

```
templates/golden-path/
├── base/                    # Base manifests with APP_NAME, APP_IMAGE, APP_PORT placeholders
│   ├── deployment.yaml      # Security context, probes, resources
│   ├── namespace.yaml       # PSS restricted labels
│   ├── networkpolicy.yaml   # Default-deny
│   ├── rbac.yaml            # ServiceAccount
│   ├── resourcequota.yaml   # Namespace ceiling
│   ├── limitrange.yaml      # Per-pod defaults
│   ├── pdb.yaml             # Disruption budget
│   ├── service.yaml         # ClusterIP
│   └── kustomization.yaml   # Bundles everything
├── overlays/
│   ├── dev/kustomization.yaml       # Patches for dev (1 replica, relaxed)
│   ├── staging/kustomization.yaml   # Patches for staging (2 replicas)
│   └── prod/kustomization.yaml      # Patches for prod (3 replicas, full)
└── argocd/
    └── application.yaml     # ArgoCD Application template
```

Placeholders: `APP_NAME`, `APP_IMAGE`, `APP_PORT`, `APP_NAMESPACE`, `MANIFESTS_REPO_URL`, `APP_ENV`

The script does `sed` replacement — no Helm, no Jinja, just find-and-replace. Simple.

**Examples of real output:** `examples/anthra-deployment/` has 3 Anthra services (anthra-api, anthra-ui, anthra-log-ingest) generated from this exact golden path.

---

## Troubleshooting

### Pod stuck in CrashLoopBackOff

```bash
kubectl logs -n payments payments-api-xxx --previous
```

Common causes:
- App writes to filesystem but rootfs is read-only → mount an emptyDir to the write path
- App needs to listen on port < 1024 but runs as non-root → change app to listen on 8080+
- Health check path wrong → app returns 404 on `/health`

### Kyverno blocks the deployment

```bash
kubectl get events -n payments --field-selector reason=PolicyViolation
```

The golden path should pass all Kyverno policies. If something blocks, either:
1. You customized the template and broke a security default
2. A new Kyverno policy was added that the template doesn't satisfy yet → update `templates/golden-path/base/`

### NetworkPolicy too restrictive

```bash
# Check what's allowed
kubectl describe networkpolicy -n payments
```

The default NetworkPolicy allows:
- DNS (port 53 UDP/TCP to kube-system)
- Same-namespace traffic on app port
- Everything else is denied

If the app needs to talk to another namespace (e.g., a shared database), add an egress rule to the base NetworkPolicy or create an overlay patch.

---

## CNPA Exam Relevance

| Domain | Coverage |
|--------|----------|
| **Platform Engineering Core (36%)** | Golden paths = standardized delivery, reduced cognitive load |
| **Continuous Delivery (16%)** | Kustomize overlays + ArgoCD = GitOps promotion |
| **Platform APIs (12%)** | Kustomize as the platform API — dev changes image tag, platform handles the rest |
| **Security & Conformance (20%)** | PSS restricted, NetworkPolicy, RBAC — all baked in, not optional |

**Exam question pattern:** "How do you ensure consistency across services?" → Golden path templates (not wiki docs, not code review, not training).

---

## Next Steps

- Deploy admission control first? → [05-deploy-admission-control.md](05-deploy-admission-control.md)
- Set up ArgoCD? → Run `bash tools/platform/setup-argocd.sh`
- Expose via Gateway API? → [09-deploy-gateway-api.md](09-deploy-gateway-api.md)
- Want devs to self-service this? → [11-deploy-backstage.md](11-deploy-backstage.md)

---

*Ghost Protocol — Platform Engineering (CNPA)*
