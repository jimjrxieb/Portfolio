# Conftest Policies - CI/CD Validation

**CI/CD security validation using OPA/Conftest** - catches security issues **before deployment**.

## Purpose

This directory contains **pure Rego policies** for validating Kubernetes manifests in the CI/CD pipeline. These policies run with `conftest` to enforce security standards **before** code is deployed.

## Directory Structure

```
conftest-policies/
├── conftest.yaml              # Conftest configuration
├── container-security.rego    # Container security policies
├── image-security.rego        # Image validation policies
├── test-policy.rego           # Basic test policies
└── tests/                     # Test fixtures & unit tests
    ├── secure-deployment.yaml      # Positive test case
    ├── vulnerable-deployment.yaml  # Negative test case
    └── *_test.rego                 # OPA unit tests
```

## How It Works

### 1. Developer commits code
```bash
git add infrastructure/charts/
git commit -m "Update deployment"
git push
```

### 2. GitHub Actions runs conftest
```yaml
# .github/workflows/main.yml
- name: Policy Validation
  run: |
    helm template charts/ > manifests.yaml
    conftest test manifests.yaml --policy conftest-policies/
```

### 3. Conftest validates against policies
```bash
FAIL - manifests.yaml - Container must not run as root
FAIL - manifests.yaml - Image 'nginx:latest' uses banned :latest tag
```

### 4. Deployment blocked if violations found ❌

---

## vs. Gatekeeper Policies

| Aspect | **Conftest** (This directory) | **Gatekeeper** (`infrastructure/gk-policies/`) |
|--------|-------------------------------|-----------------------------------------------|
| **When** | CI/CD pipeline (pre-deployment) | Runtime (admission controller) |
| **Tool** | `conftest` command | Gatekeeper admission webhook |
| **Format** | Pure Rego (.rego files) | ConstraintTemplates (YAML + Rego) |
| **Speed** | ⚡ Fast (seconds) | 🐢 Slower (cluster API call) |
| **Scope** | Git commits, PRs | Live cluster deployments |
| **Blocking** | Blocks merge/deploy | Blocks pod creation |

**Both are needed** for defense in depth!

---

## Usage

### Test Local Manifests

```bash
# Test a single file
conftest test deployment.yaml --policy conftest-policies/

# Test directory
conftest test k8s/ --policy conftest-policies/

# Test Helm charts (render first)
helm template charts/portfolio > /tmp/manifests.yaml
conftest test /tmp/manifests.yaml --policy conftest-policies/
```

### Run Unit Tests

```bash
# Run OPA unit tests
opa test conftest-policies/

# Run with coverage
opa test --coverage conftest-policies/

# Verbose output
opa test -v conftest-policies/
```

### Test Against Fixtures

```bash
# Should PASS ✅
conftest test conftest-policies/tests/secure-deployment.yaml \
  --policy conftest-policies/

# Should FAIL ❌
conftest test conftest-policies/tests/vulnerable-deployment.yaml \
  --policy conftest-policies/
```

---

## Policies Included

### `container-security.rego`
- ✅ No containers running as root (UID 0)
- ✅ Security context required
- ✅ No privileged containers
- ✅ No privilege escalation
- ✅ Resource limits required (CPU, memory)

### `image-security.rego`
- ✅ No `:latest` tags in production
- ✅ Only trusted registries allowed
- ✅ Image tags must be specified
- ✅ ImagePullPolicy required

### `test-policy.rego`
- ✅ Basic validation rules for testing

---

## Writing New Policies

### 1. Create Rego file

```rego
# conftest-policies/network-security.rego
package main

# Deny hostNetwork
deny[msg] {
  input.kind == "Deployment"
  input.spec.template.spec.hostNetwork == true
  msg := "Pods cannot use host networking"
}
```

### 2. Add unit test

```rego
# conftest-policies/tests/network_test.rego
package main

test_deny_host_network {
  deny["Pods cannot use host networking"] with input as {
    "kind": "Deployment",
    "spec": {"template": {"spec": {"hostNetwork": true}}}
  }
}
```

### 3. Test it

```bash
opa test conftest-policies/
```

### 4. It runs automatically in CI/CD!

---

## CI/CD Integration

Integrated in `.github/workflows/main.yml`:

```yaml
- name: Policy Validation
  run: |
    # Render Helm charts
    helm template infrastructure/charts/portfolio > /tmp/rendered.yaml

    # Test with conftest
    conftest test /tmp/rendered.yaml --policy conftest-policies/

    # Find and test raw K8s manifests
    find k8s/ -name "*.yaml" -exec conftest test {} --policy conftest-policies/ \;
```

**Pipeline fails** if any policy violations found!

---

## Debugging

### Verbose mode
```bash
conftest test deployment.yaml --policy conftest-policies/ --trace
```

### See all rules evaluated
```bash
conftest test deployment.yaml --policy conftest-policies/ -o table
```

### JSON output for parsing
```bash
conftest test deployment.yaml --policy conftest-policies/ -o json
```

---

## Common Issues

### Issue: "No policies found"
**Solution**: Run from project root, not inside conftest-policies/

### Issue: "Policy passes but should fail"
**Solution**: Check your Rego logic, add unit tests

### Issue: "Input is empty"
**Solution**: Ensure YAML is valid Kubernetes manifest

---

## Best Practices

1. ✅ **Keep policies simple** - One concern per file
2. ✅ **Write unit tests** - Test positive AND negative cases
3. ✅ **Use descriptive messages** - Help developers fix issues
4. ✅ **Test locally** - Run `conftest test` before pushing
5. ✅ **Version control** - All policies in Git
6. ✅ **Document rules** - Explain WHY a policy exists

---

## Resources

- [Conftest Documentation](https://www.conftest.dev/)
- [OPA Documentation](https://www.openpolicyagent.org/docs/latest/)
- [Rego Playground](https://play.openpolicyagent.org/)
- [Policy Examples](https://github.com/open-policy-agent/conftest/tree/master/examples)

---

**🎯 This is your first line of defense - catch issues in CI/CD before they reach production!**
