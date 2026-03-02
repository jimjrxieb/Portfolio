# OPA Policy Implementation with JADE

**How GP-Copilot implements Policy-as-Code for any application**

This directory demonstrates JADE's approach to implementing OPA/Conftest policies. It serves as a reference for how we enforce security standards in CI/CD pipelines.

---

## JADE's Policy-as-Code Workflow

```
Scan Project → Identify Gaps → Generate Policies → Validate → Deploy → Monitor
     │              │                │              │          │         │
   trivy      JADE ranks         JADE writes    conftest   GitHub    jsa-devsecops
   checkov    findings as        Rego based    validates   Actions   monitors
   kubescape  E/D/C/B/S          on finding    manifests   blocks    runtime
```

### Step 1: JADE Scans the Project

```bash
# JADE uses jsa-devsecops to scan Kubernetes manifests
@JADE scan kubernetes manifests in Portfolio

# JADE runs multiple scanners
trivy config --severity HIGH,CRITICAL .
checkov -d infrastructure/ --framework kubernetes
kubescape scan .
```

### Step 2: JADE Ranks Findings

| Finding | Example | Rank | Action |
|---------|---------|------|--------|
| Missing securityContext | No runAsNonRoot | D | Auto-generate policy |
| Privileged container | privileged: true | D | Auto-generate policy |
| :latest tag | image: nginx:latest | E | Auto-generate warning |
| Host network access | hostNetwork: true | C | Approval required |
| Missing NetworkPolicy | No egress rules | B | Escalate to security team |

### Step 3: JADE Generates Rego Policies

For each D-rank finding, JADE generates corresponding Rego:

```rego
# JADE-generated policy for CKV_K8S_22
# Finding: Container missing readOnlyRootFilesystem
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.securityContext.readOnlyRootFilesystem
  msg := sprintf("Container '%s' should use readOnlyRootFilesystem: true", [container.name])
}
```

### Step 4: Conftest Validates in CI/CD

```yaml
# .github/workflows/main.yml
- name: Policy Validation
  run: |
    conftest test infrastructure/ --policy conftest-policies/
```

### Step 5: jsa-devsecops Monitors Runtime

```bash
# Deploy Gatekeeper constraints for runtime enforcement
kubectl apply -f infrastructure/gk-policies/
```

---

## Policies in This Directory

### container-security.rego

Enforces container security best practices. Maps to Checkov findings:

| Rego Rule | Checkov ID | What It Catches |
|-----------|------------|-----------------|
| runAsUser != 0 | CKV_K8S_20 | Containers running as root |
| runAsNonRoot: true | CKV_K8S_22 | Missing non-root flag |
| privileged: false | CKV_K8S_1 | Privileged containers |
| allowPrivilegeEscalation: false | CKV_K8S_20 | Privilege escalation |
| readOnlyRootFilesystem: true | CKV_K8S_22 | Writable root filesystem |
| capabilities.drop: ["ALL"] | CKV_K8S_25 | Dangerous capabilities |
| resources.limits | CKV_K8S_13 | Missing resource limits |

### block-privileged.rego

Blocks privileged mode across all workload types:

```rego
# Applies to: Deployment, StatefulSet, DaemonSet, Pod
deny[msg] {
  container.securityContext.privileged == true
  msg := "Container cannot run in privileged mode"
}
```

### image-security.rego

Controls image sources and tags:

| Rule | Severity | Rationale |
|------|----------|-----------|
| No :latest tag | WARN | Unpinned versions break reproducibility |
| Require image tag | DENY | Untagged images default to :latest |
| Trusted registries only | DENY | Prevent supply chain attacks |
| Require imagePullPolicy | DENY | Control image caching behavior |

**Trusted registries configured:**
- `ghcr.io/jimjrxieb/` - Your GitHub Container Registry
- `registry.k8s.io/` - Official Kubernetes images
- `gcr.io/distroless/` - Distroless base images
- `chromadb/` - ChromaDB (for JADE's RAG)

---

## How JADE Implements OPA in Any Project

### 1. Initial Assessment

```bash
# Ask JADE to assess a project
@JADE assess kubernetes security for /path/to/project

# JADE runs comprehensive scan
JADE: Running jsa-devsecops assessment...
      - Trivy: 12 findings (3 HIGH, 9 MEDIUM)
      - Checkov: 8 failed checks
      - Kubescape: 85% compliance score

      Generating policies for 7 auto-fixable findings...
```

### 2. Policy Generation

JADE generates Rego based on the project's findings:

```bash
# JADE creates policies/kubernetes/security.rego
@JADE generate opa policies for checkov findings

# Output structure:
conftest-policies/
├── container-security.rego    # From CKV_K8S_* findings
├── network-security.rego      # From CKV_K8S_* network findings
├── image-security.rego        # From CKV_K8S_* image findings
└── tests/
    └── *_test.rego            # Unit tests for each policy
```

### 3. CI/CD Integration

JADE adds the validation step to your pipeline:

```yaml
# JADE adds this to .github/workflows/main.yml
jobs:
  security:
    steps:
      - name: OPA Policy Validation
        run: |
          # Render manifests
          helm template charts/ > /tmp/manifests.yaml

          # Validate against policies
          conftest test /tmp/manifests.yaml \
            --policy conftest-policies/ \
            --output table

          # Fail pipeline on violations
          if [ $? -ne 0 ]; then
            echo "Policy violations found - blocking deployment"
            exit 1
          fi
```

### 4. Runtime Enforcement (Optional)

For production clusters, JADE can generate Gatekeeper constraints:

```bash
@JADE convert conftest policies to gatekeeper constraints

# JADE generates:
infrastructure/gk-policies/
├── templates/
│   └── k8s-container-security.yaml  # ConstraintTemplate
└── constraints/
    └── require-security-context.yaml  # Constraint
```

---

## Running Policies Locally

### Test Against Your Manifests

```bash
# Single file
conftest test deployment.yaml --policy conftest-policies/

# Directory
conftest test k8s/ --policy conftest-policies/

# Helm charts
helm template charts/portfolio > /tmp/manifests.yaml
conftest test /tmp/manifests.yaml --policy conftest-policies/
```

### Run Unit Tests

```bash
# All tests
opa test conftest-policies/

# With coverage
opa test --coverage conftest-policies/

# Verbose
opa test -v conftest-policies/
```

### Test Fixtures

```bash
# Should PASS
conftest test fixtures/secure-deployment.yaml --policy .

# Should FAIL
conftest test fixtures/vulnerable-deployment.yaml --policy .
```

---

## Writing Custom Policies with JADE

### Ask JADE to Write a Policy

```bash
@JADE write rego policy to block hostNetwork access

# JADE generates:
package main

deny[msg] {
  input.kind == "Deployment"
  input.spec.template.spec.hostNetwork == true
  msg := "Pods cannot use host networking - security risk"
}
```

### JADE Adds Unit Tests

```rego
# tests/network_test.rego
package main

test_deny_host_network {
  deny["Pods cannot use host networking - security risk"] with input as {
    "kind": "Deployment",
    "spec": {"template": {"spec": {"hostNetwork": true}}}
  }
}

test_allow_no_host_network {
  count(deny) == 0 with input as {
    "kind": "Deployment",
    "spec": {"template": {"spec": {"hostNetwork": false}}}
  }
}
```

---

## Conftest vs Gatekeeper

| Aspect | Conftest (CI/CD) | Gatekeeper (Runtime) |
|--------|------------------|---------------------|
| When | Before deployment | During deployment |
| Speed | Fast (seconds) | Slower (API call) |
| Scope | Git commits, PRs | Live cluster |
| Blocking | Blocks merge | Blocks pod creation |
| Tool | `conftest` CLI | Admission webhook |
| Format | Pure Rego | ConstraintTemplate YAML |

**Defense in Depth:** Use both for complete coverage.

---

## JADE Rank Classification for Policy Tasks

| Task | Rank | JADE Action |
|------|------|-------------|
| Generate standard security policy | D | Auto-generate + commit |
| Add trusted registry | D | Auto-update image-security.rego |
| Create custom business logic policy | C | Generate + request approval |
| Implement compliance framework | B | Escalate to security team |
| Design org-wide policy governance | S | Escalate immediately |

---

## Files

```
conftest-policies/
├── README.md                  # This file
├── conftest.yaml              # Conftest configuration
├── container-security.rego    # Container hardening policies
├── block-privileged.rego      # Privileged container blocking
├── image-security.rego        # Image source/tag validation
├── fixtures/                  # Test manifests
│   ├── secure-deployment.yaml     # Passes all policies
│   └── vulnerable-deployment.yaml # Fails policies (for testing)
└── tests/                     # OPA unit tests
    ├── container_test.rego
    ├── block-privileged_test.rego
    └── test-policy.rego
```

---

## Resources

- [Conftest Documentation](https://www.conftest.dev/)
- [OPA Policy Language (Rego)](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [Rego Playground](https://play.openpolicyagent.org/)
- [Checkov Policy Index](https://www.checkov.io/5.Policy%20Index/kubernetes.html)

---

**GP-Copilot: Policy-as-Code, automated from scan to enforcement.**
