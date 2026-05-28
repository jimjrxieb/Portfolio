# How Jimmie Secured This Application: The Portfolio Security Journey

## Overview

Jimmie's Portfolio website (linksmlm.com) demonstrates enterprise-grade security practices applied to a personal project. This document explains the step-by-step security journey, tools used, and defense-in-depth strategy implemented.

## The Security Philosophy

Jimmie follows a **shift-left security** approach:
1. **Prevent** vulnerabilities from entering the codebase (pre-commit, CI gates)
2. **Detect** issues that slip through (continuous scanning)
3. **Protect** the runtime environment (Kubernetes hardening, network policies)
4. **Monitor** for threats (observability, logging)

## Step-by-Step Security Implementation

### Phase 1: Source Code Security (Shift-Left)

**Pre-Commit Hooks:**
- Gitleaks runs before every commit to catch hardcoded secrets
- ESLint with security rules for TypeScript/React code
- Prettier for consistent formatting (reduces diff noise in security reviews)

**Secrets Management:**
- No secrets in code - all stored in GitHub Secrets
- Kubernetes Secrets for runtime credentials
- `.gitignore` configured to prevent accidental secret commits

### Phase 2: CI/CD Pipeline Security

The GitHub Actions pipeline (`main.yml`) runs 12+ security scans on every push:

**Static Application Security Testing (SAST):**
- **Bandit**: Python code analysis for security issues
- **Semgrep**: Multi-language pattern matching for vulnerabilities
- Both fail the build on HIGH severity findings

**Dependency Scanning (SCA):**
- **Trivy**: Container image and filesystem vulnerability scanning
- **Snyk**: Dependency vulnerability detection with fix suggestions
- **npm audit**: JavaScript dependency security checks

**Infrastructure as Code (IaC) Security:**
- **Checkov**: Scans Kubernetes manifests, Terraform, Dockerfiles
- **Kubescape**: Kubernetes security posture assessment
- **Conftest**: OPA policy validation for custom rules

**Container Security:**
- **Hadolint**: Dockerfile best practices and security
- **Trivy image scan**: Scans built Docker images for CVEs

**Secret Detection:**
- **Gitleaks**: Prevents secrets from being committed
- **detect-secrets**: Additional entropy-based secret detection

### Phase 3: Container Hardening

All containers follow CIS Docker Benchmark guidelines:

**Dockerfile Security:**
```dockerfile
# Non-root user
RUN addgroup --system appgroup && adduser --system appuser --ingroup appgroup
USER appuser

# Minimal base image
FROM python:3.11-slim

# No unnecessary packages
# Health checks included
HEALTHCHECK CMD curl -f http://localhost:8000/health || exit 1
```

**Image Security:**
- Base images pinned to SHA256 digests (not just tags)
- Multi-stage builds to minimize attack surface
- No package managers in final image
- Images stored in private GHCR with vulnerability scanning

### Phase 4: Kubernetes Security

**Pod Security:**
- `runAsNonRoot: true` - No containers run as root
- `readOnlyRootFilesystem: true` - Immutable container filesystems
- `allowPrivilegeEscalation: false` - Prevents privilege escalation
- `runAsUser: 10001` - High UID to avoid conflicts
- Dropped all capabilities except what's needed

**Network Policies:**
- Default deny all ingress/egress
- Explicit allow rules for required traffic only
- API can only talk to ChromaDB on port 8000
- UI served through Cloudflare Tunnel only

**Resource Limits:**
- CPU and memory limits on all pods
- Prevents resource exhaustion attacks
- Enables fair scheduling

**RBAC:**
- ServiceAccounts with minimal permissions
- No cluster-admin access for workloads
- Separate namespaces for isolation

### Phase 5: Runtime Security

**Cloudflare Protection:**
- Cloudflare Tunnel (cloudflared) - no public IPs exposed
- WAF rules blocking common attacks
- DDoS protection included
- Bot management enabled

**TLS Everywhere:**
- cert-manager for automatic certificate management
- Let's Encrypt certificates auto-renewed
- HTTPS enforced at Cloudflare edge

**Observability:**
- Structured logging to stdout (12-factor app)
- Health endpoints for liveness/readiness probes
- Prometheus metrics for monitoring

### Phase 6: AI/RAG Security (Sheyla)

The AI assistant Sheyla has specific security measures:

**Input Validation:**
- All user queries sanitized before processing
- Rate limiting to prevent abuse
- Maximum query length enforced

**Prompt Injection Prevention:**
- System prompts separated from user input
- No code execution from user queries
- Output filtering for sensitive information

**Data Security:**
- ChromaDB runs in isolated namespace
- RAG data is curated and reviewed
- No PII in training data

## Security Scan Results

Current security posture (as of deployment):

| Tool | Status | Findings |
|------|--------|----------|
| Checkov | PASS | 0 failures (after fixes) |
| Trivy | PASS | No HIGH/CRITICAL CVEs |
| Bandit | PASS | No security issues |
| Semgrep | PASS | All findings addressed |
| Gitleaks | PASS | No secrets detected |
| Kubescape | PASS | CIS benchmark compliant |

## Security Fixes Applied

Jimmie fixed several Checkov findings during development:

1. **CKV_K8S_22**: Added `readOnlyRootFilesystem: true` to all containers
2. **CKV_K8S_40**: Set `runAsUser: 10001` (high UID)
3. **CKV_K8S_43**: Pinned images to SHA256 digests
4. **CKV_K8S_8**: Added liveness and readiness probes
5. **CKV_K8S_9**: Added readiness probes
6. **CKV_K8S_28**: Dropped all capabilities
7. **CKV_K8S_37**: Dropped NET_RAW capability

## Defense in Depth Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEFENSE IN DEPTH                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Layer 1: CODE                                                   │
│  └─ Pre-commit hooks, ESLint security rules, code review        │
│                                                                  │
│  Layer 2: BUILD                                                  │
│  └─ SAST (Bandit, Semgrep), SCA (Trivy, Snyk), IaC (Checkov)   │
│                                                                  │
│  Layer 3: CONTAINER                                              │
│  └─ Minimal base images, non-root, SHA256 pinning               │
│                                                                  │
│  Layer 4: KUBERNETES                                             │
│  └─ Pod security, NetworkPolicies, RBAC, resource limits        │
│                                                                  │
│  Layer 5: NETWORK                                                │
│  └─ Cloudflare Tunnel, WAF, TLS everywhere                      │
│                                                                  │
│  Layer 6: RUNTIME                                                │
│  └─ Health checks, logging, monitoring, rate limiting           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Key Takeaways

1. **Security is continuous** - Not a one-time activity but integrated into every phase
2. **Automation is essential** - CI/CD scans catch issues before humans see them
3. **Defense in depth** - Multiple layers ensure one failure doesn't compromise everything
4. **Compliance matters** - CIS benchmarks provide baseline security standards
5. **Visibility is crucial** - You can't secure what you can't see (observability)

This Portfolio project demonstrates that enterprise security practices can be applied to any project, regardless of size.
