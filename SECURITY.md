# Portfolio Security Documentation

## 🛡️ DevSecOps Implementation

This Portfolio application implements comprehensive DevSecOps practices with multiple layers of security controls.

## Security Architecture

### 1. Container Security
- **Read-only root filesystem** enabled for all containers
- **Non-root user** execution (UID 10001)
- **Dropped capabilities** (ALL capabilities dropped, minimal additions for init containers)
- **Seccomp profiles** (RuntimeDefault) enforced
- **No privilege escalation** allowed
- **Resource limits** enforced on all containers

### 2. Pod Security Standards
- **Pod Security Standards** (PSS) "restricted" enforcement at namespace level
- **Deprecated PSP removed** (K8s 1.25+ compatibility)
- **Service account tokens** auto-mounting disabled
- **Security contexts** applied consistently across all workloads

### 3. Network Security
- **Default-deny NetworkPolicies** implemented
- **Microsegmentation** with specific ingress/egress rules
- **DNS-only egress** for most pods
- **External API access** limited to API pods only
- **Inter-service communication** explicitly allowed

### 4. Image Security
- **Signed container images** with Cosign
- **SBOM generation** for all images
- **Vulnerability scanning** with Trivy (fails on HIGH/CRITICAL)
- **Registry restrictions** (ghcr.io allowlist)
- **No latest tags** policy enforced

### 5. Admission Control
- **Gatekeeper (OPA)** policies for runtime enforcement:
  - Allowed registries validation
  - Signed image requirements
  - Privileged container blocking
  - Resource limit enforcement
- **Conftest** for CI/CD policy validation

## Security Tools Integration

### CI/CD Pipeline (GitHub Actions)
```yaml
# .github/workflows/devsecops.yml provides:
- Container image vulnerability scanning (Trivy)
- SBOM generation (Anchore Syft)
- Kubernetes manifest validation (kubeconform)
- Security policy enforcement (Conftest)
- Image signing (Cosign)
- SARIF upload to GitHub Security tab
```

### Local Development
```bash
# Security scanning
make security-scan          # Run full security scan
make scan-images            # Trivy vulnerability scan
make generate-sbom          # Generate SBOM reports

# Helm security validation
make helm-security          # Full Helm security validation
make render-helm           # Render Helm templates
make kubeconform           # Validate K8s manifests
make conftest              # Run OPA security policies

# Image signing (requires cosign)
make sign-images           # Sign container images
make verify-images         # Verify image signatures

# Tool installation
make install-security-tools # Install all security tools
```

## Security Policies

### OPA/Conftest Policies
Located in `charts/portfolio/policies/`:
- `security.rego`: Container security requirements
- `network.rego`: Network security policies
- `images.rego`: Image security and registry policies

### Gatekeeper Constraints
- **K8sAllowedRegistries**: Restricts container registries
- **K8sRequireSignedImages**: Enforces signed images
- **K8sBlockPrivileged**: Prevents privileged containers
- **K8sRequireResources**: Enforces resource limits

## Security Evidence

### Generated Artifacts
- **SBOM Reports**: `evidence/sbom-*.json` (SPDX format)
- **Vulnerability Reports**: Trivy SARIF output
- **Rendered Manifests**: `rendered-manifests.yaml`
- **Image Signatures**: Cosign keyless signatures

### Security Gates
1. **Build-time**: Trivy fails build on HIGH/CRITICAL vulnerabilities
2. **Deploy-time**: Kubeconform validates manifest structure
3. **Policy-time**: Conftest enforces security policies
4. **Runtime**: Gatekeeper blocks non-compliant resources

## Compliance & Standards

### Frameworks Addressed
- **NIST Cybersecurity Framework**
- **CIS Kubernetes Benchmark**
- **Pod Security Standards (restricted)**
- **SLSA Supply Chain Security**

### Key Controls
- Supply chain security (SBOM, signatures)
- Vulnerability management (scanning, patching)
- Access control (RBAC, service accounts)
- Network segmentation (NetworkPolicies)
- Runtime security (PSS, Gatekeeper)

## Deployment Security

### Namespace Hardening
```yaml
labels:
  pod-security.kubernetes.io/enforce: "restricted"
  pod-security.kubernetes.io/audit: "restricted"
  pod-security.kubernetes.io/warn: "restricted"
```

### Container Security Context
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: RuntimeDefault
```

## Monitoring & Alerting

### Security Monitoring
- GitHub Security tab integration (SARIF)
- Vulnerability alerts on new CVEs
- Policy violation reporting
- Failed deployment alerts

### Metrics Tracked
- Vulnerability count by severity
- Policy compliance percentage
- Image signature verification status
- Security scan duration

## Incident Response

### Security Event Handling
1. **Vulnerability Discovery**: Automated Trivy scanning
2. **Policy Violations**: Gatekeeper admission denials
3. **Network Anomalies**: NetworkPolicy monitoring
4. **Image Tampering**: Cosign verification failures

### Response Procedures
1. Review security alerts in GitHub Security tab
2. Examine CI/CD pipeline failures for security blocks
3. Investigate Gatekeeper admission controller logs
4. Validate image signatures and SBOM attestations

## Security Contacts

- **Security Team**: [Insert contact information]
- **DevSecOps Lead**: [Insert contact information]
- **Incident Response**: [Insert contact information]

---

**Last Updated**: $(date)
**Security Review Cycle**: Monthly
**Next Security Audit**: [Schedule next audit]