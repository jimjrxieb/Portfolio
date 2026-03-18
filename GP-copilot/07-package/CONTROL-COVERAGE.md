# NIST 800-53 Control Coverage

> How GP-Copilot tooling maps to FedRAMP NIST 800-53 Rev 5 controls.

---

## Core Mapping

| Component | FedRAMP Role | Tools | Primary Controls |
|-----------|-------------|-------|-----------------|
| **CI Pipeline** | Pre-deployment scanning | Trivy, Semgrep, Gitleaks, Conftest | RA-5 (Vulnerability Scanning) |
| **Runtime Monitoring** | Post-deployment monitoring | Falco, Kubescape, kube-bench | CA-7 (Continuous Monitoring) |
| **Assessment Pipeline** | Security assessment | scan-and-map.py, gap-analysis.py | CA-2 (Security Assessments) |
| **Risk Prioritization** | Severity classification | gap-analysis.py | RA-2 (Risk Categorization) |

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    FEDRAMP COMPLIANCE PIPELINE                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  SOURCE CODE                                                     │
│       │                                                          │
│       ▼                                                          │
│  ┌──────────────────────────────────────────┐                   │
│  │         CI SCANNERS (RA-5, SI-2)         │                   │
│  │  Trivy · Semgrep · Gitleaks · Conftest   │                   │
│  │  "Is this safe to deploy?"               │                   │
│  └──────────────────┬───────────────────────┘                   │
│                     │ findings                                   │
│                     ▼                                            │
│  ┌──────────────────────────────────────────┐                   │
│  │       RISK PRIORITIZATION (RA-2)         │                   │
│  │  E (auto) · D (auto+log) · C (review)   │                   │
│  │  B (human) · S (executive)               │                   │
│  └──────────┬───────────┬───────────────────┘                   │
│             │           │                                        │
│        E-D rank    C rank     B-S rank                          │
│             │           │         │                              │
│             ▼           ▼         ▼                              │
│        Auto-      Security    Human                             │
│        remediate  review      escalation                        │
│             │           │                                        │
│             └─────┬─────┘                                        │
│                   ▼                                              │
│  ┌──────────────────────────────────────────┐                   │
│  │       KUBERNETES CLUSTER                  │                   │
│  │  PSS (AC-6) · NetworkPolicy (SC-7)       │                   │
│  │  RBAC (AC-2, AC-3) · Audit (AU-2)       │                   │
│  └──────────────────┬───────────────────────┘                   │
│                     │                                            │
│                     ▼                                            │
│  ┌──────────────────────────────────────────┐                   │
│  │       RUNTIME MONITORING (CA-7)          │                   │
│  │  Falco · Kyverno · Gatekeeper · Drift    │                   │
│  │  "What's happening now?"                 │                   │
│  └──────────────────┬───────────────────────┘                   │
│                     │ evidence                                   │
│                     ▼                                            │
│  ┌──────────────────────────────────────────┐                   │
│  │       COMPLIANCE EVIDENCE                 │                   │
│  │  SSP · POA&M · SAR · Control Matrix      │                   │
│  │  "Here's the proof we're compliant"      │                   │
│  └──────────────────────────────────────────┘                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Control-to-Tool Mapping

### Access Control (AC)

| Control | Name | Implementation | Tool | Template |
|---------|------|---------------|------|----------|
| AC-2 | Account Management | Service account management | K8s RBAC | `kubernetes-templates/rbac.yaml` |
| AC-3 | Access Enforcement | Namespace isolation + RBAC | K8s RBAC | `kubernetes-templates/rbac.yaml` |
| AC-6 | Least Privilege | Pod security contexts, PSS | Kyverno | `policies/kyverno/` |
| AC-17 | Remote Access | API server access audit | K8s Audit | `remediation-templates/audit-logging.yaml` |

### Audit & Accountability (AU)

| Control | Name | Implementation | Tool | Template |
|---------|------|---------------|------|----------|
| AU-2 | Audit Events | Kubernetes audit policy + Falco | Falco | `remediation-templates/audit-logging.yaml` |
| AU-3 | Content of Audit Records | Structured audit log format | K8s Audit | `remediation-templates/audit-logging.yaml` |
| AU-9 | Protection of Audit Information | RBAC restricts log access, immutable storage (S3 Object Lock) | K8s RBAC | `remediation-templates/audit-logging.yaml` |
| AU-12 | Audit Record Generation | Falco DaemonSet + K8s audit policy generate events | Falco | `remediation-templates/audit-logging.yaml` |

### Security Assessment (CA)

| Control | Name | Implementation | Tool | Template |
|---------|------|---------------|------|----------|
| CA-2 | Security Assessments | Multi-scanner pipeline + scan-and-map.py classification | scan-and-map.py | `tools/scan-and-map.py` |
| CA-7 | Continuous Monitoring | GHA workflows + Falco + Kyverno | CI pipeline + Falco | `ci-templates/fedramp-compliance.yml` |

### Configuration Management (CM)

| Control | Name | Implementation | Tool | Template |
|---------|------|---------------|------|----------|
| CM-2 | Baseline Configuration | Git-tracked IaC baseline | Git | `kubernetes-templates/` |
| CM-6 | Configuration Settings | OPA/Kyverno admission control | Conftest/Kyverno | `policies/` |
| CM-7 | Least Functionality | Kyverno blocks privileged, Conftest validates minimal images | Kyverno/Conftest | `policies/kyverno/` |
| CM-8 | Component Inventory | Trivy SBOM + K8s API inventory | Trivy | `scanning-configs/trivy-fedramp.yaml` |

### Identification & Authentication (IA)

| Control | Name | Implementation | Tool | Template |
|---------|------|---------------|------|----------|
| IA-2 | Identification and Authentication (Org Users) | MFA required, OIDC/SAML federation, K8s RBAC user identity | App auth + K8s RBAC | `frontend/remediation/secure-authentication.md` |
| IA-5 | Authenticator Management | Secret detection + rotation | Gitleaks | `scanning-configs/gitleaks-fedramp.toml` |

### Incident Response (IR)

| Control | Name | Implementation | Tool | Template |
|---------|------|---------------|------|----------|
| IR-4 | Incident Handling | Falco alerts, automated response, documented runbooks | Falco | `03-DEPLOY-RUNTIME/ENGAGEMENT-GUIDE.md` |
| IR-5 | Incident Monitoring | Runtime monitoring via Falco, alert routing to PagerDuty/Slack | Falco + Prometheus | `03-DEPLOY-RUNTIME/ENGAGEMENT-GUIDE.md` |

### Risk Assessment (RA)

| Control | Name | Implementation | Tool | Template |
|---------|------|---------------|------|----------|
| RA-2 | Security Categorization | FIPS 199 categorization documented in SSP | Manual/SSP | `compliance-templates/ssp-skeleton.md` |
| RA-5 | Vulnerability Monitoring | Multi-scanner pipeline | Trivy/Semgrep/Gitleaks | `scanning-configs/` |

### System and Services Acquisition (SA)

| Control | Name | Implementation | Tool | Template |
|---------|------|---------------|------|----------|
| SA-10 | Developer Config Management | Git-tracked IaC, branch protection, Gitleaks pre-commit hooks | Git + CI | `ci-templates/fedramp-compliance.yml` |
| SA-11 | Developer Testing and Evaluation | SAST in CI (Semgrep, Trivy), policy validation (Conftest) | CI pipeline | `ci-templates/sast-analysis.yml` |

### System & Communications Protection (SC)

| Control | Name | Implementation | Tool | Template |
|---------|------|---------------|------|----------|
| SC-5 | Denial of Service Protection | Kyverno resource limits, ResourceQuota per namespace, LimitRange | Kyverno | `policies/kyverno/require-resource-limits.yaml` |
| SC-7 | Boundary Protection | Default-deny NetworkPolicy | K8s NetworkPolicy | `kubernetes-templates/networkpolicy.yaml` |
| SC-8 | Transmission Confidentiality and Integrity | TLS on ingress (cert-manager), mTLS between services (Istio/Linkerd) | Istio/cert-manager | `remediation-templates/network-policies.yaml` |
| SC-28 | Protection at Rest | Encryption at rest | KMS/EBS | (Cloud-specific) |

### System & Information Integrity (SI)

| Control | Name | Implementation | Tool | Template |
|---------|------|---------------|------|----------|
| SI-2 | Flaw Remediation | Container image scanning + auto-patch | Trivy | `scanning-configs/trivy-fedramp.yaml` |
| SI-3 | Malicious Code Protection | Trivy container image scanning at CI, Falco runtime syscall monitoring | Trivy + Falco | `ci-templates/container-scan.yml` |
| SI-4 | System Monitoring | Falco DaemonSet, Kubescape posture monitoring, Prometheus/Grafana alerting | Falco + Prometheus | `03-DEPLOY-RUNTIME/ENGAGEMENT-GUIDE.md` |

---

## Design Principles

1. **Policy-first**: Every security control is a policy before it's code. OPA/Kyverno enforce at admission; Conftest validates in CI.

2. **Rank-based automation**: Not everything can or should be auto-fixed. The E-S rank system ensures appropriate human oversight (C-rank ceiling for AI, B-S for humans).

3. **Evidence-driven**: Every scan produces artifacts linked to NIST controls. The auditor doesn't need to trust us — they can verify.

4. **Defense in depth**: Controls exist at CI (pre-deploy), admission (deploy-time), and runtime (post-deploy). A finding caught at any layer is still caught.

---

*GP-Copilot FedRAMP Ready — CKS | CKA | CCSP Certified Standards*
