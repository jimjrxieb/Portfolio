# Enterprise Policy-as-Code Implementation

## Overview

The Portfolio platform implements a comprehensive **Policy-as-Code** strategy using **Open Policy Agent (OPA)** and **Conftest** to enforce security, governance, and compliance policies across the entire software development lifecycle.

## Architecture

### **Multi-Stage Policy Enforcement**

```
┌─────────────────────────────────────────────────────────────┐
│                    Policy Enforcement Layers                │
├─────────────────────────────────────────────────────────────┤
│  Pre-commit       │  CI Pipeline      │  Runtime Admission  │
│  • Local validation│  • Policy checks  │  • OPA Gatekeeper   │
│  • Developer UX   │  • Build gates    │  • Hard enforcement  │
│  • Fast feedback  │  • Security scans │  • Cluster boundary │
└─────────────────────────────────────────────────────────────┘
```

## Policy Categories

### **1. Security Policies** (`policies/security/`)

#### **Container Security Context**

- **Template**: `portfoliosecuritycontext`
- **Enforcement**:
  - ❌ No root containers (UID 0)
  - ✅ Required security contexts
  - ❌ No privileged containers
  - ❌ No privilege escalation
  - ✅ Read-only root filesystem (where applicable)

#### **Image Security**

- **Template**: `portfolioimagesecurity`
- **Enforcement**:
  - ❌ No `latest` tags in production
  - ✅ Trusted registries only (`ghcr.io/jimjrxieb/`, `chromadb/`, `registry.k8s.io/`)
  - ✅ Image tags must be specified
  - ✅ Image pull policies required

### **2. Governance Policies** (`policies/governance/`)

#### **Resource Limits**

- **Template**: `portfolioresourcelimits`
- **Enforcement**:
  - ✅ CPU limits mandatory
  - ✅ Memory limits mandatory
  - ✅ Resource requests required
  - ⚠️ Maximum 2 CPU cores per container
  - ⚠️ Maximum 2Gi memory per container

### **3. Compliance Policies** (`policies/compliance/`)

#### **Pod Security Standards**

- **Template**: `portfoliopodsecurity`
- **Enforcement**:
  - ❌ No host networking
  - ❌ No host PID/IPC namespaces
  - ❌ No privileged pods
  - ❌ No dangerous capabilities
  - ✅ Non-root filesystem groups
  - ✅ Seccomp profiles required

## Implementation Strategy

### **Stage 1: Pre-commit Validation**

**Location**: `.pre-commit-config.yaml`

```yaml
hooks:
  - id: conftest-policies
    name: Validate OPA Policies
    entry: conftest verify --policy policies/

  - id: conftest-kubernetes
    name: Validate Kubernetes Manifests
    entry: conftest test k8s/ helm/ --policy policies/
```

**Benefits**:

- ⚡ Fast developer feedback
- 🔧 Catch issues before commit
- 📚 Educational (developers learn policies)

**Limitations**:

- ⚠️ Can be bypassed with `--no-verify`
- ⚠️ Requires developer tool installation

### **Stage 2: CI Pipeline Enforcement**

**Location**: `.github/workflows/main.yml`

```yaml
- name: Run Enterprise OPA Policy Validation
  run: |
    conftest verify --policy policies/
    conftest test helm-output/ --policy policies/
```

**Benefits**:

- 🚨 Hard gate before deployment
- 📊 Centralized reporting
- 🔒 Cannot be bypassed
- 📈 Audit trail in CI logs

**Coverage**:

- All Helm chart outputs
- Kubernetes manifests
- ArgoCD applications
- Policy template validation

### **Stage 3: Runtime Admission Control**

**Location**: OPA Gatekeeper in Kubernetes cluster

```yaml
# Install via script
./scripts/setup-opa-gatekeeper.sh
```

**Benefits**:

- 🛡️ **Ultimate security boundary**
- 🚫 Prevents non-compliant deployments
- 📊 Real-time violation reporting
- 🔄 Continuous compliance monitoring

**Enforcement**:

- Resources violating policies are **rejected at admission**
- Existing resources audited for compliance drift
- Violations logged and reported

## File Structure

```
Portfolio/
├── policies/
│   ├── security/
│   │   ├── container-security.yaml    # Security contexts, privilege
│   │   └── image-security.yaml        # Registry trust, tag policies
│   ├── governance/
│   │   └── resource-limits.yaml       # CPU/memory governance
│   └── compliance/
│       └── pod-security-standards.yaml # Pod Security Standards
├── .pre-commit-config.yaml            # Pre-commit hooks
├── .github/workflows/main.yml         # CI policy validation
└── scripts/
    └── setup-opa-gatekeeper.sh        # Runtime enforcement setup
```

## Policy Development Workflow

### **1. Policy Creation**

```bash
# Create new policy template
vim policies/security/new-policy.yaml

# Validate policy syntax
conftest verify --policy policies/security/new-policy.yaml
```

### **2. Local Testing**

```bash
# Test against sample manifests
conftest test k8s/sample.yaml --policy policies/

# Test Helm chart output
helm template portfolio helm/portfolio/ | conftest test - --policy policies/
```

### **3. CI Integration**

```bash
# Commit policy (triggers CI validation)
git add policies/security/new-policy.yaml
git commit -m "Add new security policy"
git push origin main
```

### **4. Runtime Deployment**

```bash
# Apply to cluster (automatic via CI or manual)
kubectl apply -f policies/security/new-policy.yaml
```

## Monitoring & Compliance

### **Policy Violations**

```bash
# View constraint violations
kubectl get constraints -A

# Check specific policy violations
kubectl describe portfoliosecuritycontext portfolio-security-context -n portfolio

# View Gatekeeper logs
kubectl logs -n gatekeeper-system deployment/gatekeeper-controller-manager
```

### **Compliance Reporting**

```bash
# Generate compliance report
kubectl get constraints -A -o json | jq '.items[] | {name: .metadata.name, violations: .status.violations}'

# Audit existing resources
kubectl get pods -n portfolio -o yaml | conftest test - --policy policies/
```

## Enterprise Integration Examples

### **Integration with ArgoCD**

```yaml
# argocd/portfolio-application.yaml
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - Validate=true # Enables server-side validation
    retry:
      limit: 5
```

### **Integration with Helm**

```yaml
# helm/portfolio/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "portfolio.fullname" . }}-api
  annotations:
    policy.gatekeeper.sh/controlled: "true"
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
```

## Benefits Demonstrated

### **DevSecOps Excellence**

- ✅ **Shift-Left Security**: Early policy validation
- ✅ **Defense in Depth**: Multiple enforcement layers
- ✅ **Continuous Compliance**: Runtime monitoring
- ✅ **GitOps Integration**: Policies as code in Git

### **Enterprise Readiness**

- ✅ **Scalable Governance**: Template-based policies
- ✅ **Audit Compliance**: Complete violation tracking
- ✅ **Developer Experience**: Clear feedback loops
- ✅ **Operational Security**: Hard runtime enforcement

### **Technical Sophistication**

- ✅ **OPA/Rego Expertise**: Custom policy development
- ✅ **Kubernetes Admission Controllers**: Deep cluster integration
- ✅ **CI/CD Security Gates**: Automated policy enforcement
- ✅ **Multi-tool Integration**: Conftest, Gatekeeper, ArgoCD

## Maintenance

### **Policy Updates**

```bash
# Update policy
vim policies/security/container-security.yaml

# Test changes
conftest verify --policy policies/

# Deploy via CI/CD
git commit -am "Update container security policy"
git push origin main
```

### **Monitoring**

```bash
# Regular compliance checks
./scripts/policy-compliance-report.sh

# Policy performance monitoring
kubectl top pods -n gatekeeper-system
```

---

**Last Updated**: September 26, 2025
**Version**: Enterprise 1.0
**Status**: Production Ready
**Coverage**: Pre-commit → CI → Runtime
