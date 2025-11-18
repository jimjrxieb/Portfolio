# OPA Gatekeeper Policies Module

Terraform module for deploying OPA Gatekeeper security policies from the shared policy repository.

## Overview

This module deploys Gatekeeper ConstraintTemplates and Constraints to enforce security, compliance, and governance policies on Kubernetes deployments.

## Policies Deployed

### Security Policies

**Container Security** (`security/container-security.yaml`)
- ✅ Denies containers running as root (UID 0)
- ✅ Requires security context to be defined
- ✅ Denies privileged containers
- ✅ Denies privilege escalation
- ✅ Enforces read-only root filesystem (except ChromaDB)

**Image Security** (`security/image-security.yaml`)
- ✅ Blocks `:latest` tags in production
- ✅ Requires trusted registries (ghcr.io/jimjrxieb/, chromadb/, etc.)
- ✅ Requires image tags to be specified
- ✅ Requires imagePullPolicy to be set

### Compliance Policies

**Pod Security Standards** (`compliance/pod-security-standards.yaml`)
- ✅ Denies hostNetwork usage
- ✅ Denies hostPID namespace
- ✅ Denies hostIPC namespace
- ✅ Denies dangerous capabilities (SYS_ADMIN, NET_ADMIN, etc.)
- ✅ Requires non-root filesystem group
- ✅ Requires seccompProfile

### Governance Policies

**Resource Limits** (`governance/resource-limits.yaml`)
- ✅ Requires CPU limits and requests
- ✅ Requires memory limits and requests
- ✅ Enforces maximum CPU limit (2000m)
- ✅ Prevents resource exhaustion

## Usage

```hcl
module "opa_policies" {
  source = "./modules/opa-policies"

  namespace = "portfolio"
  enabled   = true
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `namespace` | Namespace to deploy constraints to | `string` | `"portfolio"` |
| `enabled` | Enable OPA policy deployment | `bool` | `true` |

## Outputs

| Name | Description |
|------|-------------|
| `policy_files_deployed` | Number of policy files deployed |
| `policy_files` | List of deployed policy file paths |
| `policies_enabled` | Whether policies are enabled |
| `policies_hash` | Hash for change detection |

## How It Works

1. Module scans `/infrastructure/shared-gk-policies/` for all YAML files
2. Uses `kubectl apply` via `null_resource` to deploy policies
3. Tracks file changes via SHA256 hash - re-deploys on changes
4. Deploys ConstraintTemplates first, then Constraints
5. On destroy, cleanly removes all deployed policies

## Prerequisites

- OPA Gatekeeper must be installed in the cluster
- kubectl must be configured and authenticated
- Gatekeeper CRDs must be present

## Verification

Check deployed policies:
```bash
# List ConstraintTemplates
kubectl get constrainttemplates

# List Constraints
kubectl get portfoliosecuritycontext,portfolioimagesecurity,portfoliopodsecurity,portfolioresourcelimits -n portfolio

# Check policy status
kubectl describe portfoliosecuritycontext portfolio-security-context -n portfolio
```

## Policy Enforcement

When a deployment violates a policy, you'll see:

```
Error from server (Forbidden): admission webhook "validation.gatekeeper.sh" denied the request:
[portfolio-security-context] Container 'api' cannot run as root (UID 0). Use runAsUser: 10001
```

## Troubleshooting

### Policies not applying
```bash
# Check Gatekeeper is running
kubectl get pods -n gatekeeper-system

# Check ConstraintTemplates are created
kubectl get constrainttemplates
```

### Policy violations not blocking
```bash
# Check Constraint status
kubectl get constraints -A

# Check Gatekeeper audit results
kubectl logs -n gatekeeper-system -l control-plane=audit-controller
```

## File Structure

```
shared-gk-policies/
├── compliance/
│   └── pod-security-standards.yaml
├── governance/
│   └── resource-limits.yaml
└── security/
    ├── container-security.yaml
    └── image-security.yaml
```

Each file contains:
1. **ConstraintTemplate** - Defines the Rego policy logic
2. **Constraint** - Applies the template to specific resources

## Customization

To add new policies:
1. Create YAML file in `/infrastructure/shared-gk-policies/`
2. Define ConstraintTemplate with Rego logic
3. Define Constraint to apply the template
4. Terraform will auto-detect and deploy on next apply

## Dependencies

This module depends on:
- Gatekeeper installed and running
- Portfolio namespace existing
- kubectl access to cluster
