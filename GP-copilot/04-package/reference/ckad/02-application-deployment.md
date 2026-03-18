# CKAD Domain 2: Application Deployment (20%)

Use Kubernetes primitives to implement common deployment strategies (e.g. blue/green or canary). Understand Deployments and how to perform rolling updates. Use the Helm package manager to deploy existing packages. Kustomize.

## CKAD Exam Quick Reference

### Rolling Update (Default)
```bash
# Update image
kubectl set image deployment/web web=nginx:1.26

# Control rollout speed
kubectl patch deployment web -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}}}'

# Watch rollout
kubectl rollout status deployment/web

# Rollback
kubectl rollout undo deployment/web
kubectl rollout undo deployment/web --to-revision=2

# Pause/resume (canary-like)
kubectl rollout pause deployment/web
kubectl set image deployment/web web=nginx:1.26
# Test the new pod...
kubectl rollout resume deployment/web
```

### Deployment Strategy YAML
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1           # 1 extra pod during update
      maxUnavailable: 0      # Zero downtime
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
        version: v2
    spec:
      containers:
      - name: web
        image: nginx:1.26
```

### Blue/Green Deployment
```bash
# Blue is running
kubectl get deployment web-blue -o wide

# Deploy green
kubectl create deployment web-green --image=myapp:2.0 --replicas=3

# Wait for green to be ready
kubectl rollout status deployment/web-green

# Switch service to green
kubectl patch service web-svc -p '{"spec":{"selector":{"version":"green"}}}'

# Verify, then delete blue
kubectl delete deployment web-blue
```

### Canary Deployment
```yaml
# Stable deployment (90% traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-stable
spec:
  replicas: 9
  selector:
    matchLabels:
      app: web
      track: stable
  template:
    metadata:
      labels:
        app: web
        track: stable
    spec:
      containers:
      - name: web
        image: myapp:1.0
---
# Canary deployment (10% traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
      track: canary
  template:
    metadata:
      labels:
        app: web
        track: canary
    spec:
      containers:
      - name: web
        image: myapp:2.0
---
# Service selects BOTH (by shared label)
apiVersion: v1
kind: Service
metadata:
  name: web-svc
spec:
  selector:
    app: web          # Matches both stable AND canary
  ports:
  - port: 80
```

### Helm
```bash
# Add repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Search
helm search repo nginx

# Install
helm install my-nginx bitnami/nginx -n web --create-namespace

# Install with custom values
helm install my-nginx bitnami/nginx -f values.yaml
helm install my-nginx bitnami/nginx --set replicaCount=3

# Upgrade
helm upgrade my-nginx bitnami/nginx --set replicaCount=5

# Rollback
helm rollback my-nginx 1

# List releases
helm list -A

# Uninstall
helm uninstall my-nginx -n web

# Show values
helm show values bitnami/nginx

# Template (dry-run)
helm template my-nginx bitnami/nginx --set replicaCount=3
```

### Kustomize
```bash
# Directory structure
# base/
#   kustomization.yaml
#   deployment.yaml
#   service.yaml
# overlays/
#   dev/kustomization.yaml
#   prod/kustomization.yaml

# Apply base
kubectl apply -k base/

# Apply overlay
kubectl apply -k overlays/prod/

# Preview
kubectl kustomize overlays/prod/
```

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
commonLabels:
  app: myapp

---
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../base
namePrefix: prod-
namespace: production
patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: myapp
    spec:
      replicas: 5
images:
- name: myapp
  newTag: "2.0"
```

## Cross-Reference to GP-CONSULTING

| Need | Location |
|------|----------|
| Golden path (Kustomize) | `02-CLUSTER-HARDENING/templates/golden-path/` |
| ArgoCD setup | `02-CLUSTER-HARDENING/tools/platform/setup-argocd.sh` |
| Image promotion | `02-CLUSTER-HARDENING/tools/platform/promote-image.sh` |
| GitOps workflow | `02-CLUSTER-HARDENING/playbooks/17-gitops-promotion-workflow.md` |
| Gateway API canary | `02-CLUSTER-HARDENING/templates/gateway-api/httproute-canary.yaml` |
| Helm chart deploy | `03-DEPLOY-RUNTIME/tools/deploy.sh` |

## Practice Scenarios

1. **Rolling update**: Deploy v1 with 4 replicas, update to v2 with maxUnavailable=0, verify zero-downtime
2. **Blue/green**: Run blue and green simultaneously, switch traffic via service selector
3. **Canary**: 9 stable + 1 canary replica, verify ~10% traffic hits canary
4. **Rollback**: Deploy a broken image, rollback, verify correct revision
5. **Helm**: Install nginx from bitnami, customize replica count, upgrade, rollback
6. **Kustomize**: Create base + dev/prod overlays, apply prod with different replica count and image tag
