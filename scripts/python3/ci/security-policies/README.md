# Security Policy Testing

This directory contains OPA/Conftest policies and test fixtures for CI security validation.

## Files

### Policy Files
- `test-policy.rego` - OPA policy for Kubernetes security validation
  - Prevents `:latest` tags
  - Blocks running as root user
  - Can be extended with additional security rules

### Test Fixtures
- `vulnerable-deployment.yaml` - Intentionally vulnerable deployment for testing security controls
  - Contains multiple security violations to validate policy enforcement
  - Used as negative test case

- `secure-deployment.yaml` - Best-practice secure deployment example
  - Demonstrates proper security configurations
  - Used as positive test case

## Usage

```bash
# Test policies against vulnerable deployment (should fail)
./conftest test vulnerable-deployment.yaml --policy test-policy.rego

# Test policies against secure deployment (should pass)
./conftest test secure-deployment.yaml --policy test-policy.rego

# Run as part of CI pipeline
./conftest test ../../../k8s/manifests/*.yaml --policy test-policy.rego
```

## Integration

These policies integrate with:
- Pre-commit hooks for manifest validation
- CI pipeline security gates
- ArgoCD/GitOps deployment validation
- Kubernetes admission controllers

## Policy Extensions

Add new security rules to `test-policy.rego`:
- Resource limits enforcement
- Image registry restrictions
- Network policy requirements
- Service account token restrictions