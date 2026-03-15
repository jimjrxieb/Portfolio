# Playbook 02: FedRAMP Remediation

> Derived from [GP-CONSULTING/07-FEDRAMP-READY/playbooks/01-06](https://github.com/jimjrxieb/GP-copilot) (access control, audit, config mgmt, comms, integrity, identity)
> Tailored for the Portfolio application (linksmlm.com)

## What This Does

Closes the gaps identified in Playbook 01 (Gap Assessment). Each MISSING or PARTIAL control gets a specific remediation action. Controls are grouped by what can be automated vs. what requires manual documentation.

## Remediation by Control Family

### AC — Access Control

| Control | Gap | Remediation | Tool |
|---------|-----|-------------|------|
| AC-2 | No quarterly account review process | Establish RBAC audit schedule; disable inactive ServiceAccounts | `kubectl`, RBAC audit script |
| AC-6 | Some pods may still run as root | Enforce via PSS restricted + Gatekeeper | Security context patches |
| AC-17 | kubectl accessible without VPN | Restrict API server access; use OIDC for auth | Tailnet already provides this |

### AU — Audit & Accountability

| Control | Gap | Remediation | Tool |
|---------|-----|-------------|------|
| AU-2 | K8s audit policy not centralized | Deploy K8s audit policy with 4-level logging | Audit policy YAML |
| AU-3 | Logs lack structured format | Enforce JSON logging in FastAPI + Nginx | App config |
| AU-6 | No weekly audit review process | Set up weekly Grafana review dashboard | Prometheus + Grafana |
| AU-12 | Falco not yet deployed | Deploy Falco (03-DEPLOY-RUNTIME) | Helm chart |

### CM — Configuration Management

| Control | Gap | Remediation | Tool |
|---------|-----|-------------|------|
| CM-2 | Baseline not formally documented | Git is the baseline; ArgoCD self-heal enforces it | Already in place |
| CM-7 | Debug tools may exist in images | Use distroless/slim base images; scan with Trivy | Dockerfile updates |
| CM-8 | No formal component inventory | Generate SBOMs per image; document cloud resources | Trivy SBOM, `kubectl get` |

### SC — System & Communications Protection

| Control | Gap | Remediation | Tool |
|---------|-----|-------------|------|
| SC-7 | NetworkPolicy gaps | Verify default-deny on all namespaces | `watch-network-coverage.sh` |
| SC-8 | No mTLS between pods | Deploy Istio Ambient or Cilium WireGuard | Service mesh |
| SC-12 | Key rotation not automated | Set up AWS KMS with annual rotation | AWS CLI |
| SC-28 | Verify encryption at rest | Check StorageClass encryption, Secrets encryption | `kubectl get sc` |

### SI — System & Information Integrity

| Control | Gap | Remediation | Tool |
|---------|-----|-------------|------|
| SI-2 | No formal SLA on CVE remediation | Define: Critical ≤30d, High ≤90d, Medium ≤180d | Process documentation |
| SI-4 | No runtime monitoring | Deploy Falco + Prometheus alerts | 03-DEPLOY-RUNTIME |
| SI-10 | Input validation not formally verified | Semgrep rules for SQLi/XSS/injection in CI | Already running |

### IA — Identification & Authentication

| Control | Gap | Remediation | Tool |
|---------|-----|-------------|------|
| IA-2 | No MFA documentation | Document MFA enforcement (GitHub, AWS, kubectl via Tailnet) | Process doc |
| IA-5 | Secret rotation not automated | External Secrets Operator syncs from Vault | Already deployed |

### IR — Incident Response

| Control | Gap | Remediation | Tool |
|---------|-----|-------------|------|
| IR-4 | No formal incident response plan | Write IR plan: roles, severity levels, containment playbooks | Template from GP-CONSULTING |
| IR-5 | No incident tracking | Set up incident tracker (spreadsheet or ticketing) | Process doc |

## Remediation Timeline

| Week | Focus | Expected Coverage |
|------|-------|------------------|
| Week 1 | AC + CM (RBAC, config, inventory) | 42% → 55% |
| Week 2 | AU + SI (logging, scanning, Falco) | 55% → 65% |
| Week 3 | SC + IA (network, encryption, secrets) | 65% → 75% |
| Week 4 | IR + documentation | 75% → 80%+ |

## Re-scan After Remediation

```bash
bash run-fedramp-scan.sh \
    --client-name "Portfolio" \
    --target-dir /path/to/Portfolio \
    --output-dir ./evidence-post-fix
```

Compare control-matrix.md before/after to prove improvement.
