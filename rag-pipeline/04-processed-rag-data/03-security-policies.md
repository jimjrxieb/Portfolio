# Comprehensive Guide to Conftest Security Policies

## Executive Summary

This document provides complete technical documentation of the **Conftest-based security policy framework** used in the Portfolio project. The system enforces Kubernetes security best practices at the CI/CD pipeline stage, preventing insecure configurations from reaching production.

**Key Components:**
- 4 Rego policy files enforcing security requirements
- Unit tests validating policy behavior
- CI/CD integration via GitHub Actions
- Test fixtures demonstrating secure vs. vulnerable configurations
- OPA (Open Policy Agent) for declarative policy enforcement

**Defense Strategy:** Policies run in two stages:
1. **Pre-deployment (Conftest)** - Blocks insecure manifests in CI/CD pipeline
2. **Runtime (Gatekeeper)** - Admission controller validates deployments at cluster level

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Policy Files (Rego)](#policy-files-rego)
3. [Testing Framework](#testing-framework)
4. [CI/CD Integration](#cicd-integration)
5. [Security Best Practices](#security-best-practices)
6. [Examples and Scenarios](#examples--scenarios)
7. [Policy Testing Approach](#policy-testing-approach)
8. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### System Context

```
SECURITY POLICY FRAMEWORK

1. Developer commits Kubernetes manifests
              DOWN ARROW
2. GitHub Actions triggered
              DOWN ARROW
3. Conftest validates against Rego policies
              DOWN ARROW
4. Pass: Merge allowed, Deploy to cluster
   Fail: Block merge, Show violations to developer
              DOWN ARROW
5. Gatekeeper admission webhook validates at runtime
   (Defense in depth - second layer)
```

### Policy Layers

Policy runs in layers:
- **CI/CD** - Conftest - Pre-deployment - Git commits, PRs - Block merge
- **Runtime** - Gatekeeper - Pod creation - Live cluster - Reject pod
- **Network** - NetworkPolicy - Traffic - Pod-to-pod - Drop packets

### Technology Stack

- **OPA (Open Policy Agent):** Policy enforcement engine
- **Conftest:** CLI tool for testing Kubernetes manifests against policies
- **Rego:** Declarative policy language (looks like JSON queries)
- **YAML:** Input format for policies (Kubernetes manifests)

---

## Policy Files (Rego)

### Directory Structure

```
conftest-policies/
├── conftest.yaml                    # Conftest CLI configuration
├── container-security.rego          # Container runtime security (56 lines)
├── image-security.rego              # Image registry and versioning (44 lines)
├── block-privileged.rego            # Privileged pod blocking (13 lines)
├── test-policy.rego                 # Basic validation rules (14 lines)
├── fixtures/
│   ├── secure-deployment.yaml       # Reference: passing manifest
│   └── vulnerable-deployment.yaml   # Reference: failing manifest
└── tests/
    ├── block-privileged_test.rego   # Test privileged pod denial
    ├── container_test.rego          # Container security tests
    └── test-policy.rego             # Basic policy tests
```

---

## container-security.rego

**Purpose:** Enforce container runtime security contexts and resource management

**File Location:** `/GP-copilot/conftest-policies/container-security.rego`

**Lines of Code:** 56

### Policy Rules

#### 1. No Root User Execution

```
POLICY: Deny runAsUser == 0
PURPOSE: Prevent privilege escalation by enforcing non-root
CHECKS: Container UID must not be 0 (root)
BENEFIT: Limits blast radius if compromised
BLOCKS:
  containers:
    - securityContext:
        runAsUser: 0
ALLOWS:
  containers:
    - securityContext:
        runAsUser: 1000
        runAsNonRoot: true
```

#### 2. Security Context Required

```
POLICY: Deny missing securityContext
PURPOSE: Ensure all containers explicitly define security boundaries
CHECKS: Every container must have securityContext block
BENEFIT: Prevents implicit/default insecure settings
BLOCKS:
  containers:
    - name: app
      image: myapp:v1.0
      (no securityContext)
ALLOWS:
  containers:
    - name: app
      image: myapp:v1.0
      securityContext:
        runAsUser: 1000
```

#### 3. No Privileged Containers

```
POLICY: Deny privileged == true
PURPOSE: Prevent container from accessing host kernel
CHECKS: privileged: true is blocked
BENEFIT: Prevents container escape, blocks /dev access
BLOCKS:
  securityContext:
    privileged: true
ALLOWS:
  securityContext:
    privileged: false
```

#### 4. No Privilege Escalation

```
POLICY: Deny allowPrivilegeEscalation == true
PURPOSE: Prevent process from gaining elevated privileges
CHECKS: allowPrivilegeEscalation must not be explicitly true
BENEFIT: Prevents setuid/setgid exploitation
BLOCKS:
  securityContext:
    allowPrivilegeEscalation: true
ALLOWS:
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop: [ALL]
```

#### 5. Resource Limits Required

```
POLICY: Deny missing resources.limits
PURPOSE: Prevent resource exhaustion DoS attacks
CHECKS: resources.limits block must exist
BENEFIT: Prevents noisy neighbor, limits blast radius
BLOCKS:
  containers:
    - name: app
      (no resources.limits)
ALLOWS:
  containers:
    - name: app
      resources:
        limits:
          cpu: 1
          memory: 1Gi
```

#### 6. Memory Limits Required

```
POLICY: Deny missing memory limit
PURPOSE: Prevent memory exhaustion DoS
CHECKS: resources.limits.memory must be specified
BENEFIT: Prevents OOM bomb attacks, protects node
BLOCKS:
  resources:
    limits:
      cpu: 1
      (no memory)
ALLOWS:
  resources:
    limits:
      cpu: 1
      memory: 512Mi
```

#### 7. CPU Limits Required

```
POLICY: Deny missing CPU limit
PURPOSE: Prevent CPU exhaustion DoS
CHECKS: resources.limits.cpu must be specified
BENEFIT: Prevents CPU starvation of other pods
BLOCKS:
  resources:
    limits:
      memory: 512Mi
      (no cpu)
ALLOWS:
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
```

---

## image-security.rego

**Purpose:** Enforce container image versioning and registry policies

**File Location:** `/GP-copilot/conftest-policies/image-security.rego`

**Lines of Code:** 44

### Policy Rules

#### 1. No Latest Tags in Production

```
POLICY: Deny endswith image ":latest"
PURPOSE: Enforce image version immutability
CHECKS: Image cannot end with :latest
BENEFIT: Prevents silent breaking changes, enables rollback
BLOCKS:
  containers:
    - image: ghcr.io/myorg/api:latest
ALLOWS:
  containers:
    - image: ghcr.io/myorg/api:v1.2.3
```

#### 2. Images Must Have Tags

```
POLICY: Deny image without : (tag separator)
PURPOSE: Prevent implicit latest tag usage
CHECKS: Image reference must contain :
BENEFIT: Forces explicit versioning
BLOCKS:
  containers:
    - image: myapp
ALLOWS:
  containers:
    - image: myapp:v1.0.0
```

#### 3. Trusted Registry Requirement

```
POLICY: Deny image not from trusted registries
PURPOSE: Enforce supply chain security
CHECKS: Must start with:
  - ghcr.io/
  - chromadb/
  - registry.k8s.io/
BENEFIT: Prevents pulling from untrusted sources
BLOCKS:
  containers:
    - image: docker.io/ubuntu:20.04
    - image: myregistry.azurecr.io/app:v1
ALLOWS:
  containers:
    - image: ghcr.io/jimjrxieb/portfolio-api:v1.0.0
    - image: chromadb/chroma:0.3.21
```

#### 4. Image Pull Policy Required

```
POLICY: Deny missing imagePullPolicy
PURPOSE: Enforce explicit image pull behavior
CHECKS: imagePullPolicy field must be present
BENEFIT: Forces decision about image freshness
BLOCKS:
  containers:
    - image: ghcr.io/myorg/app:v1.0.0
      (no imagePullPolicy)
ALLOWS:
  containers:
    - image: ghcr.io/myorg/app:v1.0.0
      imagePullPolicy: IfNotPresent
```

#### 5. Latest Tags Must Pull Always

```
POLICY: Deny :latest without imagePullPolicy: Always
PURPOSE: Consistency check for latest tags
CHECKS: If image ends with :latest, must use Always
NOTE: Complementary to rule 1 (latest is blocked anyway)
```

---

## block-privileged.rego

**Purpose:** Specialized policy blocking privileged Pod objects

**File Location:** `/GP-copilot/conftest-policies/block-privileged.rego`

**Lines of Code:** 13

### Policy Rule

```
POLICY: Deny Pod with privileged == true
PURPOSE: Blocks privileged containers at Pod level
CHECKS: Inspects kind: Pod manifests
SCOPE: Standalone Pod resources
DIFFERENCE: Complements container-security (Deployment-focused)
BLOCKS:
  apiVersion: v1
  kind: Pod
  spec:
    containers:
      - securityContext:
          privileged: true
ALLOWS:
  apiVersion: v1
  kind: Pod
  spec:
    containers:
      - securityContext:
          privileged: false
```

---

## test-policy.rego

**Purpose:** Basic validation rules for policy testing

**File Location:** `/GP-copilot/conftest-policies/test-policy.rego`

**Lines of Code:** 14

### Policy Rules

Basic versions of:
1. Latest tag detection
2. Root user detection

Used for smoke testing and debugging policy setup.

---

## Testing Framework

### Test Architecture

```
Unit Tests (OPA Test Engine)
  - test_deny_* rules
  - Test against fixtures
         DOWN ARROW
Integration Tests (Conftest)
  - Test secure-deployment.yaml (should PASS)
  - Test vulnerable-deployment.yaml (should FAIL)
         DOWN ARROW
CI/CD Tests (GitHub Actions)
  - Lint rendered Helm manifests
  - Test k8s/ directory manifests
  - Block merge if violations found
```

### Unit Test Files

#### block-privileged_test.rego

Tests:
1. Deny privileged pods with privileged: true
2. Allow non-privileged pods

#### container_test.rego

Tests (9 total):
1. Deny root user (UID 0)
2. Allow non-root user
3. Deny missing security context
4. Deny privileged container
5. Deny privilege escalation
6. Deny missing resource limits
7. Deny missing memory limit
8. Deny missing CPU limit
9. Allow complete secure deployment

Example secure configuration:
```yaml
kind: Deployment
metadata:
  name: secure-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: ghcr.io/myorg/app:v1.0.0
        imagePullPolicy: IfNotPresent
        securityContext:
          runAsUser: 10001
          runAsNonRoot: true
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 1
            memory: 1Gi
```

### Test Fixtures

#### secure-deployment.yaml (115 lines)

**Includes:**
- Pod-level security context (non-root, specific UID/GID)
- Container security context (no privilege, drop all caps)
- Resource limits (CPU and memory)
- Health checks (readiness and liveness probes)
- Specific image versions from trusted registries
- Read-only root filesystem
- Mounted volumes for /tmp, /var/cache
- Service with ClusterIP (not NodePort)
- Ingress with TLS enabled
- Service account with auto-mount disabled

**Why it passes all policies:**
- All containers have explicit securityContext
- Non-root user (UID 1000)
- No privileged or privilege escalation
- All capabilities dropped
- Specific image versions from trusted registries
- Resource limits defined
- Health checks configured
- TLS enabled on ingress

#### vulnerable-deployment.yaml (73 lines)

**Violations:**
1. Image uses :latest tag
2. Image from untrusted registry (docker.io)
3. Running as root (UID 0)
4. Privileged mode enabled
5. Privilege escalation allowed
6. Writable root filesystem
7. Dangerous capabilities added (SYS_ADMIN)
8. No resource limits defined
9. No health probes
10. Service account auto-mount enabled
11. Service type NodePort (direct exposure)
12. No TLS configuration on ingress

This manifest demonstrates all common security anti-patterns.


## CI/CD Integration

### GitHub Actions Workflow Integration

**File:** `.github/workflows/main.yml`

**Location in Workflow:** Lines 318-350

**Integration Step:**

The conftest policy validation runs during the GitHub Actions workflow. Key implementation details:

1. Check if conftest binary exists, otherwise download v0.46.0
2. Verify policy templates are valid
3. Test rendered Helm manifests
4. Test Method 1 Kubernetes manifests
5. Log results (continue-on-error: true allows workflow completion)

### Workflow Trigger Points

**When conftest policies run:**
1. Push to main or develop branch with changes to:
   - infrastructure/
   - k8s/
   - charts/
   - Dockerfile files
   - docker-compose.yml
   - package.json files
   - requirements.txt files
   - GitHub workflows

2. Pull request to main branch (any changes)

### Conftest Configuration

**File:** `conftest.yaml`

Configuration settings:
- **policy:** Current directory (.) for .rego files
- **output:** Both stdout and json formats
- **fail-on-warn:** false (only violations block, not warnings)
- **combine:** false (separate results per file)
- **namespace:** main (OPA namespace)
- **trace:** false (disabled for production)

### Manifest Testing Order

1. Helm charts rendered to YAML
2. Method 1 Kubernetes manifests (direct YAML)
3. Method 2 Terraform (if applicable)

### Failure Handling

- If violations found: GitHub Actions logs them
- continue-on-error: true allows workflow to complete
- **Recommendation:** Should be false in production to block merges

### Implementation Notes

- Conftest binary is 28MB, takes 2 seconds to download
- Policy verification is cached if binary exists
- Policies evaluated in parallel for speed
- Output visible in GitHub Actions logs

---

## Security Best Practices

### Policy Design Principles

#### 1. Defense in Depth

```
Layer 1: Pre-commit hooks (local)
  DOWN ARROW (optional)
Layer 2: Conftest in CI/CD (this system)
  DOWN ARROW BLOCKS insecure manifests
Layer 3: Gatekeeper admission controller
  DOWN ARROW REJECTS insecure pods at runtime
Layer 4: Network policies
  DOWN ARROW RESTRICTS pod communication
Layer 5: Pod Security Standards
  DOWN ARROW ENFORCES baseline security
```

All layers should be in place.

#### 2. Principle of Least Privilege

Applied by:
- Non-root user execution (UID greater than 0)
- No privilege escalation allowed
- All capabilities dropped
- Minimal resource requests
- Read-only filesystems where possible

#### 3. Fail Secure (Deny by Default)

Policy Design:
- Empty list means allow (not explicitly denied)
- Policies only block known-bad patterns
- Allow unknown patterns (whitelist approach)

#### 4. Clear Messaging

Good messages help developers:
- Understand what is wrong
- Know which container violated
- Know how to fix it

#### 5. Test Everything

Testing Strategy:
- Positive tests (should pass)
- Negative tests (should fail)
- Edge cases
- Real manifests

#### 6. Version Control

Critical for policies:
- Policies in Git
- Change history visible
- Code review before deployment
- Easy rollback

#### 7. Policy Documentation

In Code:
- Comment each rule
- Explain security rationale
- Link to external documentation

---

### Kubernetes Security Context Best Practices

**Complete Secure Configuration includes:**

Pod-level security context:
- runAsNonRoot: true
- runAsUser: specific UID (e.g., 1000)
- runAsGroup: specific GID
- fsGroup: for mounted volumes
- supplementalGroups: additional groups
- seLinuxOptions: SELinux context
- seccompProfile: restrict syscalls

Service account security:
- serviceAccountName: specific account
- automountServiceAccountToken: false

Container-level security context:
- runAsNonRoot: true
- runAsUser: specific UID
- runAsGroup: specific GID
- privileged: false
- allowPrivilegeEscalation: false
- readOnlyRootFilesystem: true
- capabilities drop ALL, add only needed

Resource management:
- requests: cpu, memory
- limits: cpu, memory

Health checks:
- startupProbe (if needed)
- readinessProbe
- livenessProbe

Volume mounts:
- Separate volumes for /tmp, /var/cache
- read-only where possible

---

### Resource Limits Guidelines

**Microservice/API:**
- CPU request: 50-100m
- CPU limit: 200-500m
- Memory request: 64-128Mi
- Memory limit: 256-512Mi

**Database:**
- CPU request: 500m-1000m
- CPU limit: 2000m-4000m
- Memory request: 512Mi-2Gi
- Memory limit: 2Gi-8Gi

**Cache/Redis:**
- CPU request: 100-200m
- CPU limit: 500m-1000m
- Memory request: 256Mi-512Mi
- Memory limit: 1Gi-4Gi

**ML/Heavy Computation:**
- CPU request: 1000m-2000m
- CPU limit: 4000m-8000m
- Memory request: 1Gi-4Gi
- Memory limit: 4Gi-16Gi

CPU unit explanation:
- 1 CPU = 1000 millicores
- 100m = 10% of one CPU
- 500m = 50% of one CPU

---

### Image Registry Strategy

**Approved Registries:**
- ghcr.io/ - GitHub Container Registry (source visible)
- chromadb/ - Upstream ChromaDB official
- registry.k8s.io/ - Kubernetes official

**Anti-Pattern Registries:**
- Personal Docker Hub accounts
- Unknown registries
- Non-HTTPS registries
- Registries without authentication

**Best Practice:**
1. Mirror images to private registry
2. Scan for vulnerabilities
3. Sign with Cosign/Notary
4. Use private registry only

---

## Examples and Scenarios

### Scenario 1: Deploying API Service

**Developer's Insecure Manifest:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portfolio-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: nginx:latest
        ports:
        - containerPort: 8080
```

**Conftest Results (FAILURES):**
- Container uses latest tag (not allowed)
- Must use images from trusted registries
- Must have securityContext defined
- Must have resource limits defined
- Must specify imagePullPolicy

**Developer Fixes:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portfolio-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: ghcr.io/jimjrxieb/portfolio-api:v1.2.3
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
        securityContext:
          runAsUser: 1000
          runAsNonRoot: true
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi
```

**Conftest Results:**
- PASS: No denials

**Can now merge and deploy!**

---

### Scenario 2: Privileged DaemonSet (Edge Case)

**Need:** DaemonSet that must run privileged (monitoring)

**Challenge:** Conftest blocks all privileged containers

**Solutions:**

Option 1: Exclude from policy
- Create separate policy file for DaemonSet
- Load conditionally

Option 2: Override in code review
- Document WHY privilege needed
- Explicit exceptions in comments
- Manual approval by security team

Option 3: Drop to container-scoped privilege
- Instead of privileged: true, use capabilities:

```yaml
securityContext:
  privileged: false
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
    add:
      - NET_ADMIN
      - SYS_PTRACE
```

This passes policies while enabling needed functionality!

---

### Scenario 3: Database Container

**Special Requirements:** Needs to manage own files

**Secure Manifest:**

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
      containers:
      - name: postgres
        image: registry.k8s.io/postgres:15.2
        imagePullPolicy: IfNotPresent
        securityContext:
          runAsUser: 999
          runAsGroup: 999
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          capabilities:
            drop: [ALL]
        resources:
          limits:
            cpu: 2000m
            memory: 2Gi
          requests:
            cpu: 500m
            memory: 512Mi
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
          subPath: postgres
```

**Passes all policies because:**
- Non-root user (UID 999)
- Specific version from official registry
- Resource limits defined
- Not privileged
- Writable filesystem allowed for data (legitimate)

---

## Policy Testing Approach

### Test-Driven Policy Development

**Process:**

1. Write test first
2. Verify test fails
3. Write policy to pass test
4. Verify test passes
5. Add negative test (allow case)
6. Run all tests

### Continuous Testing Strategy

**Local Development:**

Before committing:
- Run OPA tests
- Test specific manifest
- Watch mode (if available)

**CI/CD Pipeline:**

Test policies in GitHub Actions during build

**Code Review:**

Checklist:
- Policy tests pass
- Integration tests pass
- Manifests pass conftest
- Gatekeeper tests pass
- Documentation updated

### Test Coverage Measurement

Generate coverage report:
```
opa test conftest-policies/ --coverage
```

Interpret coverage:
- 80%+ is good
- 50-80% is acceptable
- Below 50% needs more tests

Target: 80%+ policy coverage

---

## Troubleshooting

### Common Problems and Solutions

#### Problem: "No policies found"

**Symptoms:**
- Error: Unable to find policy

**Causes:**
- Running from wrong directory
- Policy path incorrect
- .rego files not found

**Solutions:**
- Check current directory (should be project root)
- List policy files: find . -name "*.rego"
- Run with absolute path to conftest-policies
- Or change to correct directory before running

---

#### Problem: "Input is empty" or "Invalid input"

**Symptoms:**
- Error: Unable to read input: invalid character

**Causes:**
- Invalid YAML syntax
- Wrong file format
- Empty file

**Solutions:**
- Validate YAML with yamllint
- Check file is not empty (wc -l)
- Verify YAML structure
- Test with simple manifest

---

#### Problem: "Policy allows when should deny"

**Symptoms:**
- PASS deployment.yaml (but expected violations)

**Causes:**
- Rego logic error
- Missing conditions
- Type mismatch

**Solutions:**
- Test policy in isolation
- Debug with trace mode
- Check Rego syntax
- Simplify rule and test incrementally

---

#### Problem: "Latest tag check fails with different image"

**Symptoms:**
- Policy allows even though looks like latest
- Example: image: myapp:latest-stable

**Cause:**
- endswith only matches exact ":latest"
- Doesn't match ":latest-stable"

**Solution:**
- Use contains instead of endswith
- Or use regex.match pattern

---

#### Problem: "Resource limits work locally but fail in CI/CD"

**Symptoms:**
- Locally: PASS
- CI/CD: FAIL

**Causes:**
- Helm template rendering differs
- Environment variable differences
- Default values not applied

**Solutions:**
- Render Helm locally same as CI/CD
- Check rendered output
- Test rendered manifest
- Verify Helm defaults are set

---

#### Problem: "Conftest binary not found in CI/CD"

**Symptoms:**
- GitHub Actions: conftest: command not found

**Cause:**
- Binary not downloaded
- Path not set

**Solution:**
- Download conftest in workflow step
- Extract tar.gz
- Make executable
- Use in subsequent steps

---

#### Problem: "Namespace errors in OPA tests"

**Symptoms:**
- Error: Package name must match namespace

**Cause:**
- Wrong namespace in test file
- Test uses different package than policies

**Solution:**
- Use package main in all test files
- Match policy namespace exactly

---

## Advanced Topics

### Extending Policies

**Add Network Security Policy:**

Policy for blocking host networking:
```
Deny hostNetwork: true
Deny hostPID: true
Deny hostIPC: true
```

**Add Pod Security Policy:**

Policies for pod-level requirements:
```
Require runAsNonRoot at pod level
Require fsGroup defined
Require seccompProfile
```

---

### Policy as Code Best Practices

1. **Version Control**
   - All policies in Git
   - Code review before changes
   - Tag releases

2. **Documentation**
   - Comment each rule
   - Explain security rationale
   - Link to external docs

3. **Testing**
   - Unit tests (positive and negative)
   - Integration tests
   - Real manifest tests

4. **Monitoring**
   - Track policy violations
   - Trend analysis
   - Alert on evasion

5. **Evolution**
   - Regular policy audits
   - Update for vulnerabilities
   - Remove obsolete rules
   - Gather developer feedback

---

## Summary

### Key Takeaways

1. **Defense in Depth:** Conftest plus Gatekeeper plus NetworkPolicy plus Pod Security Standards

2. **Seven Container Security Rules:**
   - No root user (UID 0)
   - Security context required
   - No privileged mode
   - No privilege escalation
   - CPU limits required
   - Memory limits required
   - Resource limits required

3. **Five Image Security Rules:**
   - No latest tags
   - Image tags required
   - Trusted registries only
   - ImagePullPolicy required
   - Latest tags must use Always policy

4. **Policy Testing:**
   - Unit tests in OPA
   - Integration tests with conftest
   - CI/CD validation
   - Fixtures for documentation

5. **CI/CD Integration:**
   - Automatic validation on push
   - Blocks insecure manifests
   - Clear error messages
   - Visible in GitHub Actions logs

6. **Audit Trail:**
   - All policies in version control
   - Code review history
   - Policy violation logs
   - Compliance reporting

---

## References

- Conftest: https://www.conftest.dev/
- OPA Documentation: https://www.openpolicyagent.org/docs/latest/
- Rego Language: https://www.openpolicyagent.org/docs/latest/policy-language/
- Kubernetes Security Context: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- Pod Security Standards: https://kubernetes.io/docs/concepts/security/pod-security-standards/
- CIS Kubernetes Benchmark: https://www.cisecurity.org/cis-benchmarks/
- NIST Cybersecurity Framework: https://www.nist.gov/cyberframework
- Gatekeeper Policy: https://open-policy-agent.github.io/gatekeeper/

---

**Document Generated:** 2025-11-13
**Portfolio Project Security Documentation**
**For RAG System: Security Policy Knowledge Base**

