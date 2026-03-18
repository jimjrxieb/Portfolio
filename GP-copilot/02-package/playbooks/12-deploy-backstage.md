# Playbook 11 — Deploy Backstage Internal Developer Platform

## Objective

Deploy Backstage as the Internal Developer Platform (IDP) portal, giving dev teams
self-service access to software templates, service catalog, TechDocs, and Kubernetes
visibility — all through a single pane of glass.

## Prerequisites

- [ ] Kubernetes cluster with `kubectl` and `helm` access
- [ ] Gateway API deployed (Playbook 09) — for external access
- [ ] External Secrets Operator running (Playbook 10) — for secret sync
- [ ] Namespace-as-a-Service operator running (Playbook 12) — for self-service namespaces
- [ ] PostgreSQL will be deployed automatically (Helm subchart)

## Quick Reference

| Tool | Purpose |
|------|---------|
| `tools/platform/setup-backstage.sh` | Deploy Backstage via Helm |
| `tools/platform/register-service.sh` | Register existing services in the catalog |
| `backstage/app-config.yaml` | Backstage application configuration |
| `backstage/helm-values.yaml` | Helm chart values |
| `backstage/software-templates/` | Golden path templates |
| `backstage/techdocs/` | Platform documentation site |

---

## Phase 1 — Deploy Backstage

### Step 1: Review Configuration

```bash
# Check the app-config — update domain, GitHub org, auth settings
cat backstage/app-config.yaml

# Check Helm values — resource limits, PostgreSQL config
cat backstage/helm-values.yaml
```

### Step 2: Dry Run

```bash
bash tools/platform/setup-backstage.sh --dry-run
```

Verify:
- [ ] Namespace creation planned
- [ ] ConfigMap source path is correct
- [ ] Helm values path is correct

### Step 3: Deploy

```bash
# Default (backstage.local)
bash tools/platform/setup-backstage.sh

# With custom domain
bash tools/platform/setup-backstage.sh --domain portal.client.com --namespace backstage
```

### Step 4: Verify Deployment

```bash
# Check pods
kubectl get pods -n backstage

# Check logs
kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=50

# Port-forward to access locally
kubectl port-forward -n backstage svc/backstage 7007:7007
# Open: http://localhost:7007
```

---

## Phase 2 — Register Existing Services

### Step 1: Generate catalog-info.yaml

```bash
# Preview without pushing
bash tools/platform/register-service.sh \
  --app-name payments-api \
  --team payments \
  --repo-url https://github.com/org/payments-api \
  --description "Payment processing API" \
  --output-only
```

### Step 2: Add to Repo

```bash
# Generate and get instructions
bash tools/platform/register-service.sh \
  --app-name payments-api \
  --team payments \
  --repo-url https://github.com/org/payments-api

# Copy the generated file to the service repo root
cp /tmp/catalog-info-*.yaml /path/to/payments-api/catalog-info.yaml
```

### Step 3: Verify in Backstage

1. Open Backstage UI → Catalog
2. Click "Register Existing Component"
3. Enter: `https://github.com/org/payments-api/blob/main/catalog-info.yaml`
4. Confirm the component appears in the catalog

---

## Phase 3 — Software Templates (Golden Paths)

### Available Templates

| Template | What It Creates |
|----------|----------------|
| Secure Microservice | Hardened Go/Python/Node service with CI, K8s manifests, NetworkPolicy |

### Using the Template

1. Open Backstage → Create → "Secure Microservice"
2. Fill in: service name, team, language, environment
3. Template scaffolds:
   - Dockerfile (non-root, healthcheck, pinned base)
   - K8s manifests (security context, resource limits, network policy)
   - CI pipeline (Semgrep, Gitleaks, Conftest, Trivy)
   - catalog-info.yaml (auto-registered)
4. Pushes to GitHub, registers in Backstage catalog

### Customizing Templates

```bash
# Templates live here
ls backstage/software-templates/secure-microservice/

# Skeleton files use Nunjucks templating
# ${{ values.serviceName }} — replaced at scaffold time
```

---

## Phase 4 — Expose via Gateway API

### Create HTTPRoute for Backstage

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: backstage-route
  namespace: backstage
spec:
  parentRefs:
    - name: platform-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - portal.client.com
  rules:
    - backendRefs:
        - name: backstage
          port: 7007
```

```bash
kubectl apply -f backstage-route.yaml
```

---

## Phase 5 — Enable TechDocs

TechDocs are pre-configured for local builder (no external storage needed).

### Verify TechDocs

1. Open Backstage → Docs
2. Platform documentation should appear automatically
3. Content comes from `backstage/techdocs/docs/`

### Add TechDocs to a Service

1. Add `mkdocs.yml` to the service repo root
2. Add `backstage.io/techdocs-ref: dir:.` annotation to catalog-info.yaml
3. Backstage auto-generates the docs site

---

## Phase 6 — Production Hardening

### Enable GitHub OAuth

Edit `backstage/app-config.yaml`:

```yaml
auth:
  providers:
    github:
      development:
        clientId: ${GITHUB_CLIENT_ID}
        clientSecret: ${GITHUB_CLIENT_SECRET}
```

Store credentials via External Secrets:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: backstage-github-oauth
  namespace: backstage
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: backstage-github-oauth
  data:
    - secretKey: GITHUB_CLIENT_ID
      remoteRef:
        key: prod/backstage/github-client-id
    - secretKey: GITHUB_CLIENT_SECRET
      remoteRef:
        key: prod/backstage/github-client-secret
```

### Enable Kubernetes Plugin

The Helm values already configure the K8s plugin. Backstage will show pod status,
logs, and events for any service with the `backstage.io/kubernetes-label-selector`
annotation in its catalog-info.yaml.

---

## Troubleshooting

### Backstage pod not starting

```bash
# Check events
kubectl describe pod -n backstage -l app.kubernetes.io/name=backstage

# Common issues:
# - PostgreSQL not ready → check: kubectl get pods -n backstage -l app=postgresql
# - ConfigMap missing → check: kubectl get configmap backstage-app-config -n backstage
# - Image pull error → check registry access
```

### PostgreSQL connection refused

```bash
# Verify PostgreSQL is running
kubectl get pods -n backstage -l app.kubernetes.io/name=postgresql

# Check password secret exists
kubectl get secret backstage-db-creds -n backstage
```

### TechDocs not rendering

```bash
# TechDocs uses local builder — check logs for mkdocs errors
kubectl logs -n backstage -l app.kubernetes.io/name=backstage | grep -i techdocs

# Verify mkdocs.yml exists in the docs source
```

### Software template fails

```bash
# Check scaffolder logs
kubectl logs -n backstage -l app.kubernetes.io/name=backstage | grep -i scaffolder

# Common issues:
# - GitHub token not configured → add GITHUB_TOKEN to Backstage secret
# - Template syntax error → validate Nunjucks in template.yaml
```

---

## Validation Checklist

- [ ] Backstage pod running and healthy
- [ ] PostgreSQL pod running
- [ ] UI accessible via port-forward (http://localhost:7007)
- [ ] At least one service registered in catalog
- [ ] Software template visible in "Create" page
- [ ] TechDocs rendering platform documentation
- [ ] Gateway API route configured (if external access needed)
- [ ] GitHub OAuth enabled (production)

## CNPA Domain Coverage

| Domain | Coverage |
|--------|----------|
| Internal Developer Platforms (8%) | Software templates, service catalog, TechDocs |
| Platform APIs (12%) | Gateway API integration, catalog API |
| Continuous Delivery (16%) | Golden path CI pipeline in templates |
| Measuring Platforms (8%) | Service catalog as ownership registry |
