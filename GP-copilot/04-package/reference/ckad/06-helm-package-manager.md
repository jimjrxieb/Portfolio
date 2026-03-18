# CKAD/CKA: Helm Package Manager

Helm is the package manager for Kubernetes. Every package in GP-CONSULTING uses it (Falco, Kyverno, ArgoCD, Istio, Cilium) but until now there was no "how to use Helm" guide.

## Concepts

| Term | What It Is |
|------|-----------|
| **Chart** | Package of K8s manifests + templates + values |
| **Release** | An installed instance of a chart |
| **Repository** | Where charts are hosted |
| **Values** | Configuration that customizes a chart |
| **Revision** | A versioned snapshot of a release (for rollback) |

## Helm Quick Reference

### Repository Management
```bash
# Add a repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo add jetstack https://charts.jetstack.io
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add istio https://istio-release.storage.googleapis.com/charts

# Update repo index
helm repo update

# List repos
helm repo list

# Search for charts
helm search repo nginx
helm search repo kyverno --versions    # Show all versions
helm search hub prometheus              # Search Artifact Hub
```

### Install
```bash
# Basic install
helm install my-release bitnami/nginx

# Install into specific namespace (create if missing)
helm install kyverno kyverno/kyverno -n kyverno --create-namespace

# Install with custom values file
helm install falco falcosecurity/falco -n falco --create-namespace -f custom-values.yaml

# Install with inline value overrides
helm install my-app bitnami/nginx \
  --set replicaCount=3 \
  --set service.type=ClusterIP \
  --set resources.limits.memory=256Mi

# Install specific chart version
helm install cert-manager jetstack/cert-manager --version v1.14.0

# Dry run (show manifests without installing)
helm install my-app bitnami/nginx --dry-run --debug

# Generate manifests only (no cluster needed)
helm template my-app bitnami/nginx --set replicaCount=3
```

### Inspect Before Installing
```bash
# Show default values (critical — always check before installing)
helm show values bitnami/nginx
helm show values bitnami/nginx > default-values.yaml

# Show chart metadata
helm show chart bitnami/nginx

# Show README
helm show readme bitnami/nginx

# Show everything
helm show all bitnami/nginx
```

### Upgrade
```bash
# Upgrade with new values
helm upgrade my-app bitnami/nginx --set replicaCount=5

# Upgrade with values file
helm upgrade my-app bitnami/nginx -f updated-values.yaml

# Upgrade OR install if not exists
helm upgrade --install my-app bitnami/nginx -f values.yaml

# Upgrade with --reuse-values (keep previous values, override specific ones)
helm upgrade my-app bitnami/nginx --reuse-values --set image.tag=1.26

# Upgrade with --reset-values (start from chart defaults)
helm upgrade my-app bitnami/nginx --reset-values -f new-values.yaml
```

### Rollback
```bash
# Show release history
helm history my-app

# Rollback to previous revision
helm rollback my-app

# Rollback to specific revision
helm rollback my-app 2

# Check current revision
helm list -A
```

### List and Status
```bash
# List all releases
helm list -A

# List in specific namespace
helm list -n kyverno

# Show release status
helm status my-app

# Show release values (what was actually applied)
helm get values my-app
helm get values my-app --all        # Including defaults
helm get values my-app --revision 2  # Specific revision

# Show deployed manifests
helm get manifest my-app

# Show release notes
helm get notes my-app
```

### Uninstall
```bash
# Remove release
helm uninstall my-app

# Remove release in namespace
helm uninstall kyverno -n kyverno

# Keep history (allows rollback after uninstall)
helm uninstall my-app --keep-history
```

### Values Override Precedence
```
Chart defaults (values.yaml in chart)
  ↓ overridden by
-f custom-values.yaml
  ↓ overridden by
--set key=value (highest priority)
```

```bash
# Multiple -f files (later files win)
helm install my-app bitnami/nginx \
  -f base-values.yaml \
  -f env-overrides.yaml \
  --set replicaCount=5

# Nested values with --set
helm install my-app bitnami/nginx \
  --set "nodeSelector.disktype=ssd" \
  --set "tolerations[0].key=env" \
  --set "tolerations[0].operator=Equal" \
  --set "tolerations[0].value=prod" \
  --set "tolerations[0].effect=NoSchedule"
```

### Create Your Own Chart
```bash
# Scaffold a new chart
helm create my-chart

# Structure:
# my-chart/
#   Chart.yaml          # Chart metadata (name, version, appVersion)
#   values.yaml         # Default values
#   templates/          # K8s manifest templates
#     deployment.yaml
#     service.yaml
#     ingress.yaml
#     _helpers.tpl      # Template helpers
#     NOTES.txt         # Post-install instructions
#   charts/             # Sub-chart dependencies

# Lint (validate)
helm lint my-chart/

# Package
helm package my-chart/

# Install from local chart
helm install my-app ./my-chart -f values.yaml
```

### Template Syntax (Exam Essentials)
```yaml
# values.yaml
replicaCount: 3
image:
  repository: nginx
  tag: "1.25"

# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-app
  labels:
    app: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  template:
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        {{- if .Values.resources }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
        {{- end }}
```

### Built-in Objects
```
{{ .Release.Name }}       # Release name (helm install NAME)
{{ .Release.Namespace }}  # Namespace
{{ .Release.Revision }}   # Revision number
{{ .Chart.Name }}         # Chart name from Chart.yaml
{{ .Chart.Version }}      # Chart version
{{ .Values.key }}         # Values from values.yaml / --set / -f
```

## How GP-CONSULTING Uses Helm

Every tool that installs something uses Helm under the hood:

| What | Script | Helm Chart |
|------|--------|-----------|
| Kyverno | `02-CLUSTER-HARDENING/tools/admission/deploy-policies.sh` | `kyverno/kyverno` |
| ArgoCD | `02-CLUSTER-HARDENING/tools/platform/setup-argocd.sh` | `argo/argo-cd` |
| External Secrets | `02-CLUSTER-HARDENING/tools/platform/setup-external-secrets.sh` | `external-secrets/external-secrets` |
| Falco | `03-DEPLOY-RUNTIME/tools/deploy.sh` | `falcosecurity/falco` |
| Istio | `03-DEPLOY-RUNTIME/tools/deploy-service-mesh.sh` | `istio/istiod` |
| Backstage | `02-CLUSTER-HARDENING/tools/platform/setup-backstage.sh` | `backstage/backstage` |

## Practice Scenarios

1. **Install + customize**: Install nginx chart with 3 replicas, ClusterIP service, custom resource limits
2. **Inspect values**: Download default values for a chart, identify all security-relevant settings
3. **Upgrade + rollback**: Install v1, upgrade to v2 with new values, rollback to v1, verify
4. **Template**: Create a simple chart from scratch with deployment + service, install it
5. **Multi-values**: Install with base values file + environment override file + inline --set
6. **Dry run**: Use `helm template` and `--dry-run` to preview manifests without touching the cluster
