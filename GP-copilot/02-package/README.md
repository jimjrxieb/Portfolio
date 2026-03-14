# 02-CLUSTER-HARDENING — Deploy-Time Kubernetes Hardening

Hardens Kubernetes clusters with policy-as-code, RBAC scoping, and admission control.

## Structure

```
golden-techdoc/   → Policy matrix, engagement guides, compliance mappings
playbooks/        → Step-by-step runbooks for audit → enforce progression
outputs/          → Sample audit results and policy coverage reports
summaries/        → Package overview and engagement summaries
```

## What This Package Does

- Deploys Kyverno/OPA policies for pod security, image validation, and resource limits
- Scopes RBAC with least-privilege roles and removes cluster-admin bindings
- Enforces Pod Security Standards (PSS) at the namespace level
- Audit-first approach: observe violations before switching to enforce mode
