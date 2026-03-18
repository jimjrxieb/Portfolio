# Kubernetes Templates

FedRAMP-compliant Kubernetes manifests with hardened security contexts, RBAC, and network policies.

## Files

| Template | Controls | Purpose |
|----------|----------|---------|
| `namespace.yaml` | AC-2, AC-3 | PSS-labeled isolated namespace |
| `deployment.yaml` | AC-6, CM-6, SI-2 | Hardened app + DB deployments |
| `networkpolicy.yaml` | SC-7 | Default-deny + explicit allows |
| `rbac.yaml` | AC-2, AC-3 | Least-privilege service accounts |
| `service.yaml` | SC-7 | ClusterIP-only services |

## Placeholders

Replace before deploying:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{NAMESPACE}}` | Target namespace | `acme-prod` |
| `{{APP_NAME}}` | Application name | `acme-api` |
| `{{APP_IMAGE}}` | Container image | `ghcr.io/acme/api:v1.2` |
| `{{APP_PORT}}` | Application port | `8080` |
| `{{DB_NAME}}` | Database name | `postgres` |
| `{{DB_IMAGE}}` | Database image | `postgres:15` |
| `{{DB_PORT}}` | Database port | `5432` |
| `{{RUN_AS_USER}}` | Container UID | `1000` |
| `{{RUN_AS_GROUP}}` | Container GID | `1000` |

## Quick Deploy

```bash
# Replace placeholders
export NS=acme-prod APP=acme-api
sed -i "s/{{NAMESPACE}}/$NS/g; s/{{APP_NAME}}/$APP/g" kubernetes-templates/*.yaml

# Apply in order
kubectl apply -f kubernetes-templates/namespace.yaml
kubectl apply -f kubernetes-templates/rbac.yaml
kubectl apply -f kubernetes-templates/deployment.yaml
kubectl apply -f kubernetes-templates/service.yaml
kubectl apply -f kubernetes-templates/networkpolicy.yaml
```
