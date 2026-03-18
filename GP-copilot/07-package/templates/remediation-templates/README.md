# Remediation Templates

Kubernetes security hardening templates mapped to FedRAMP NIST 800-53 controls.

## Files

| Template | Controls | Purpose |
|----------|----------|---------|
| `audit-logging.yaml` | AU-2, AU-3 | K8s audit policy + Falco rules |
| `image-security.yaml` | SI-2, CM-2 | Registry allowlists, tag enforcement |
| `network-policies.yaml` | SC-7 | Default-deny + explicit allow rules |
| `pod-security-context.yaml` | AC-6 | PSS Restricted profile, security contexts |
| `rbac-templates.yaml` | AC-2, AC-3 | ServiceAccounts, Roles, RoleBindings |

## Placeholders

Replace before deploying:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{NAMESPACE}}` | Target Kubernetes namespace | `acme-prod` |
| `{{APP_NAME}}` | Application name | `acme-api` |
| `{{APP_IMAGE}}` | Container image | `ghcr.io/acme/api:v1.2` |
| `{{APP_PORT}}` | Application port | `8080` |
| `{{DB_NAME}}` | Database service name | `postgres` |
| `{{DB_PORT}}` | Database port | `5432` |
| `{{RUN_AS_USER}}` | Container UID | `1000` |
| `{{RUN_AS_GROUP}}` | Container GID | `1000` |
