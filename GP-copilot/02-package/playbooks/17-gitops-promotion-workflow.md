# Playbook 17 — GitOps Promotion Workflow

> Set up ArgoCD, connect manifests repos, and establish the dev → staging → prod promotion pipeline.
>
> **When:** After Playbook 14 (golden path generated) and cluster is hardened (02 complete).
> **Audience:** Platform engineer setting up the delivery pipeline for developers.

---

## What This Playbook Establishes

```
Developer pushes code → CI builds image → image tag lands in dev overlay
        │
        ▼
   ┌─────────┐     ArgoCD      ┌─────────┐
   │   DEV   │ ──── syncs ───→ │ cluster │  Developer sees results
   └─────────┘                  └─────────┘
        │
        │  promote-image.sh --from dev --to staging
        ▼
   ┌─────────┐     ArgoCD      ┌─────────┐
   │ STAGING │ ──── syncs ───→ │ cluster │  QA + pentest + load test
   └─────────┘                  └─────────┘
        │
        │  promote-image.sh --from staging --to prod (requires PR approval)
        ▼
   ┌─────────┐     ArgoCD      ┌─────────┐
   │  PROD   │ ──── syncs ───→ │ cluster │  Customers see results
   └─────────┘                  └─────────┘
```

**Git history = audit trail.** Every promotion is a commit. Every commit has an author. FedRAMP CM-3 (Change Control) is satisfied by git log alone.

---

## Prerequisites

- [ ] Cluster hardened (Playbook 05 — admission control running)
- [ ] Golden path deployments generated (Playbook 14)
- [ ] `kubectl` and `git` access
- [ ] GitHub repo for manifests (or the app repo with `infrastructure/`)

---

## Step 1: Install ArgoCD

```bash
PKG=~/linkops-industries/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING
```

### Create the namespace FIRST (Kyverno blocks namespaces without PSS labels)

If Kyverno admission control is running (it should be after 02), you must create the namespace with PSS labels before ArgoCD install. The install script's `kubectl create namespace` will be rejected without them.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
EOF
```

### Create PolicyExceptions for ArgoCD (Kyverno blocks upstream manifests)

ArgoCD's upstream manifests don't include resource limits, seccomp profiles, or semver image tags. Your Kyverno policies will block every Deployment and StatefulSet. This is expected — ArgoCD is infrastructure, not app code. Grant it exceptions:

```bash
kubectl apply -f - <<'EOF'
apiVersion: kyverno.io/v2beta1
kind: PolicyException
metadata:
  name: argocd-infra-exception
  namespace: kyverno
spec:
  exceptions:
  - policyName: require-resource-limits
    ruleNames:
    - autogen-validate-cpu-limits
    - autogen-validate-memory-limits
    - validate-cpu-limits
    - validate-memory-limits
  - policyName: require-seccomp-strict
    ruleNames:
    - autogen-check-seccomp-strict
    - check-seccomp-strict
  - policyName: require-apparmor-profile
    ruleNames:
    - autogen-check-apparmor
    - check-apparmor
  - policyName: require-semver-tags
    ruleNames:
    - semver-tags-only
  match:
    any:
    - resources:
        namespaces:
        - argocd
        kinds:
        - Deployment
        - StatefulSet
        - Pod
        - Job
        - CronJob
        - ReplicaSet
EOF
```

> **Why exceptions instead of weakening policies?** Your app namespaces still get full enforcement. Only the `argocd` namespace is exempted — and only for the specific rules that upstream ArgoCD manifests violate. This is the standard pattern for third-party infrastructure on a hardened cluster.

### Install ArgoCD

```bash
# Dry run first
bash $PKG/tools/platform/setup-argocd.sh --dry-run

# Install
bash $PKG/tools/platform/setup-argocd.sh
```

This installs ArgoCD v2.13.3, waits for pods, and prints the admin credentials.

**Save the admin password.** Change it immediately after first login (Step 2 below).

### Login to ArgoCD CLI (core mode)

On Kind clusters, port-forward to the ArgoCD server is unreliable. Use **core mode** instead — the CLI talks directly to the K8s API, no server connection needed:

```bash
# Core mode — no port-forward required
argocd login --core

# Core mode requires the argocd namespace as default
kubectl config set-context --current --namespace=argocd
```

> **Why core mode?** Kind runs inside Docker containers. Port-forwarding through Docker→Kind→Pod has networking issues on WSL2. Core mode bypasses all of this — the CLI reads ArgoCD CRDs directly from the K8s API.

After you're done with ArgoCD commands, reset your namespace:
```bash
kubectl config set-context --current --namespace=default
```

### Change admin password

```bash
kubectl config set-context --current --namespace=argocd
argocd account update-password
kubectl config set-context --current --namespace=default
```

### Harden ArgoCD namespace (NetworkPolicies + LimitRange)

The PSS labels are already set from the namespace creation above. Now add NetworkPolicies:

```bash
# fix-cluster-security.sh auto-detects ArgoCD and adds service-aware NetworkPolicies
bash $PKG/tools/hardening/fix-cluster-security.sh --skip-limits --skip-pss --skip-certmgr
```

---

## Step 2: Connect the Manifests Repo

**IMPORTANT:** If you have a `GH_TOKEN` environment variable, unset it first. Stale tokens override the working `gh` credential helper:

```bash
unset GH_TOKEN
```

```bash
# Switch to argocd namespace for core mode
kubectl config set-context --current --namespace=argocd

# HTTPS (using gh CLI credential helper — recommended)
argocd repo add https://github.com/your-org/your-manifests.git \
  --username git \
  --password "$(gh auth token)"

# Or SSH
argocd repo add git@github.com:your-org/your-manifests.git \
  --ssh-private-key-path ~/.ssh/id_ed25519

# Verify
argocd repo list

# Reset namespace
kubectl config set-context --current --namespace=default
```

---

## Step 3: Register ArgoCD Applications

Each service gets one Application per environment. The golden path script already generated these.

```bash
INFRA=/path/to/your-app/infrastructure

# Register all environments for all services
for svc in anthra-api anthra-ui anthra-log-ingest anthra-db; do
  for env in dev staging prod; do
    kubectl apply -f $INFRA/$svc/argocd/application-${env}.yaml
  done
done

# Verify
argocd app list
```

**What you'll see in ArgoCD UI:**

| App Name | Path | Status |
|----------|------|--------|
| anthra-api-dev | overlays/dev | Synced |
| anthra-api-staging | overlays/staging | Synced |
| anthra-api-prod | overlays/prod | Synced |
| anthra-ui-dev | overlays/dev | Synced |
| ... | ... | ... |

Each app watches its own overlay folder. They don't know about each other.

---

## Step 4: Developer Workflow (Day-to-Day)

### Two separate actions — don't confuse them

There are two completely independent things happening:

1. **`promote-image.sh`** — changes what VERSION runs in an environment (edits YAML, commits to git, ArgoCD syncs)
2. **`kubectl port-forward`** — changes what YOU'RE LOOKING AT in your browser

They don't know about each other. Promotion is a git operation. Viewing is a network operation.

### Developer pushes a new image

The developer's CI pipeline builds the image and pushes it to the registry. Then:

```bash
cd your-manifests-repo/infrastructure

# Option A: kustomize CLI
cd anthra-api/overlays/dev
kustomize edit set image anthra/api:v1.42.0=anthra/api:v1.43.0

# Option B: edit the file directly — add/update the images block
# overlays/dev/kustomization.yaml:
#   images:
#     - name: anthra/api
#       newTag: "v1.43.0"

git add .
git commit -m "deploy: anthra-api v1.43.0 to dev"
git push
```

ArgoCD detects the change in `overlays/dev/`, syncs, pods roll out. Developer sees their changes.

### Accessing each environment (local lab)

On a local Kind cluster, each environment runs in its own namespace. You switch between them with port-forward:

```bash
# View dev
kubectl port-forward svc/novasec-ui -n anthra-dev 8080:8080 &
# → http://localhost:8080

# Done with dev, switch to staging
pkill -f "port-forward.*novasec-ui"
kubectl port-forward svc/novasec-ui -n anthra-staging 8080:8080 &
# → http://localhost:8080  (now showing staging)

# Switch to prod
pkill -f "port-forward.*novasec-ui"
kubectl port-forward svc/novasec-ui -n anthra-prod 8080:8080 &
# → http://localhost:8080  (now showing prod)
```

Or run them on different ports simultaneously:

```bash
kubectl port-forward svc/novasec-ui -n anthra-dev 8080:8080 &      # dev on :8080
kubectl port-forward svc/novasec-ui -n anthra-staging 8081:8080 &   # staging on :8081
kubectl port-forward svc/novasec-ui -n anthra-prod 8082:8080 &      # prod on :8082
```

### Accessing each environment (real clusters)

On real infrastructure with DNS and Gateway API, no port-forward is needed. Each environment has its own URL, all running simultaneously:

```
Dev:     https://dev.anthra.internal         ← developer sees this
Staging: https://staging.anthra.internal     ← QA/pentest team sees this
Prod:    https://anthra.novasec.com          ← customers see this (EKS + ALB)
```

The Gateway API + DNS config is what makes this work. The app, the overlays, and ArgoCD are identical — only the network entry point changes.

### What the developer CAN touch

```
overlays/dev/kustomization.yaml
  ├── images:          ← change image tag ✓
  ├── replicas:        ← change replica count ✓ (dev only)
  └── patches:         ← add env vars ✓
```

### What the developer CANNOT touch

```
base/*                 ← security contexts, networkpolicy, rbac
overlays/staging/*     ← platform engineer promotes
overlays/prod/*        ← requires PR approval from senior + platform
```

Enforce this with GitHub branch protection + CODEOWNERS:

```
# .github/CODEOWNERS
infrastructure/*/base/              @platform-team
infrastructure/*/overlays/staging/  @platform-team
infrastructure/*/overlays/prod/     @platform-team @senior-dev
```

---

## Step 5: Promotion Workflow

### Dev → Staging (platform engineer)

```bash
bash $PKG/tools/platform/promote-image.sh \
  --app anthra-api \
  --from dev \
  --to staging \
  --auto-commit

git push
```

Or manually — open a PR, review the diff (it's one line: the image tag), merge.

### Staging → Prod (requires senior approval)

```bash
# Platform engineer runs:
bash $PKG/tools/platform/promote-image.sh \
  --app anthra-api \
  --from staging \
  --to prod

# Review the diff — DON'T auto-commit to prod
# Instead, create a PR:
git checkout -b promote/anthra-api-v1.43.0-prod
git add .
git commit -m "promote: anthra-api v1.43.0 from staging to prod"
git push -u origin promote/anthra-api-v1.43.0-prod

# Senior reviews + approves the PR
# You merge → ArgoCD syncs prod → customers see v1.43.0
```

### Promotion approval chain

| Promotion | Who Opens PR | Who Approves | Auto-commit OK? |
|-----------|-------------|-------------|-----------------|
| dev → staging | Platform engineer | Platform engineer | Yes |
| staging → prod | Platform engineer | Senior dev + platform | **No — always PR** |
| Hotfix → prod | Senior dev | Platform engineer | **No — always PR** |

---

## Step 6: Rollback

Rollback = promote the old tag. Git history makes this trivial.

```bash
# What's running in prod right now?
argocd app get anthra-api-prod -o json | jq '.status.summary.images'

# Rollback to previous version
bash $PKG/tools/platform/promote-image.sh \
  --app anthra-api \
  --to prod \
  --tag v1.42.0

git add . && git commit -m "rollback: anthra-api prod to v1.42.0" && git push
```

ArgoCD syncs. Pods roll back. The rollback is a commit too — auditable.

---

## Step 7: Verify the Audit Trail

```bash
# Every promotion is a git commit
git log --oneline -- infrastructure/anthra-api/overlays/prod/
# f3a2b1c promote: anthra-api v1.43.0 from staging to prod
# a1b2c3d promote: anthra-api v1.42.0 from staging to prod
# 9d8e7f6 initial deployment

# Who approved what?
git log --format="%h %an %s" -- infrastructure/anthra-api/overlays/prod/

# ArgoCD also tracks sync history
argocd app history anthra-api-prod
```

For FedRAMP:
- **CM-3 (Change Control)**: git log shows every change, who made it, when
- **CM-5 (Access Restrictions)**: CODEOWNERS + branch protection = enforced separation
- **AU-2 (Audit Events)**: ArgoCD sync history + git log = complete audit trail
- **AC-6 (Least Privilege)**: Developer can only touch dev overlay, not prod

---

## All Tools

| Tool | Purpose |
|------|---------|
| `setup-argocd.sh` | Install ArgoCD on cluster |
| `create-app-deployment.sh` | Generate golden path Kustomize structure |
| `promote-image.sh` | Copy image tag between overlays |
| `fix-cluster-security.sh` | Harden ArgoCD namespace (auto-detects) |

---

## Troubleshooting

### ArgoCD shows "OutOfSync" but won't sync

```bash
argocd app get anthra-api-dev --hard-refresh
argocd app sync anthra-api-dev
```

### Developer committed to base/ by accident

```bash
# Revert the base change
git revert <commit-hash>
git push
# ArgoCD self-heals
```

### Image tag didn't change in cluster after push

```bash
# Check ArgoCD detected the repo change
argocd app get anthra-api-dev
# If "Unknown" — repo credentials may be wrong
argocd repo list
```

### Need to see what's different between environments

```bash
diff <(kubectl kustomize infrastructure/anthra-api/overlays/dev) \
     <(kubectl kustomize infrastructure/anthra-api/overlays/prod)
```

---

## CNPA + CKS Exam Relevance

| Domain | Coverage |
|--------|----------|
| **Platform Engineering Core (36%)** | GitOps promotion = standardized delivery |
| **Continuous Delivery (16%)** | ArgoCD + Kustomize overlays = progressive delivery |
| **Security & Conformance (20%)** | Git audit trail, CODEOWNERS, branch protection |

**Exam pattern:** "How do you ensure only reviewed changes reach production?" → GitOps with ArgoCD, branch protection, CODEOWNERS. Not manual kubectl.

---

*Ghost Protocol — Platform Engineering (CNPA/CKS)*
