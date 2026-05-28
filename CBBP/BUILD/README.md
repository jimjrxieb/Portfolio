# BUILD: DevSecOps Implementation Summary

BUILD answers the question:

```text
How do we make the COMPLY requirements true in the system?
```

For Portfolio-Prod, BUILD is the implementation phase. It turns the COMPLY
scope into working controls across the application, containers, Kubernetes,
CI/CD, secrets handling, and AI/RAG runtime.

## What Was Built

| Area | Implementation | Primary files |
|---|---|---|
| Production API hardening | FastAPI security headers, strict CORS, production docs gating, chat rate limiting. | `api/main.py` |
| AI/RAG safety controls | Prompt injection detection, input validation, output sanitization, hashed-IP audit logging, AI response validation. | `api/sheyla_security/llm_security.py`, `api/routes/chat.py`, `api/routes/validation.py` |
| Container hardening | Separate API/UI containers, non-root runtime intent, read-only root filesystem at deployment, resource requests/limits. | `api/Dockerfile`, `ui/Dockerfile`, `infrastructure/charts/portfolio/templates/deployment-api.yaml` |
| Kubernetes baseline | Helm chart for API, UI, ChromaDB, services, Gateway/HTTPRoute, NetworkPolicy, PVC, service account. | `infrastructure/charts/portfolio/` |
| GitOps deployment | ArgoCD watches the Helm chart and reconciles the production namespace from Git. | `infrastructure/method3-helm-argocd/argocd/portfolio-application.yaml` |
| Network boundary | UI/API are public-routed; ChromaDB stays internal as ClusterIP with no public HTTPRoute. | `templates/service.yaml`, `templates/httproute.yaml`, `templates/networkpolicy.yaml` |
| Secrets path | Runtime secrets come from the expected Kubernetes Secret / ExternalSecret path; secret values are not stored in public docs. | `values.yaml`, `deployment-api.yaml`, `.gitignore`, `.pre-commit-config.yaml` |
| CI/CD security gates | SAST, dependency scanning, secret scanning, IaC checks, container scanning, policy checks, image build/push, Helm tag update. | `.github/workflows/main.yml`, `.github/workflows/policy-check.yml` |
| Pipeline security review | CI workflow scanner checks unpinned actions, dangerous permissions, hardcoded secrets, command injection, and risky triggers. | `.github/workflows/jsa-ci-security.yml` |
| Policy as code | OPA/Conftest policies enforce Kubernetes and CI/CD security expectations before deploy. | `policies/conftest/` |

See [policy-as-code.md](policy-as-code.md) for the policy inventory and why the
active Rego files stay at the repo root.

## DevSecOps Flow

```text
Developer change
  -> pre-commit / pre-push checks
  -> GitHub Actions security scans
  -> policy-as-code validation
  -> Docker image build
  -> Trivy image scan
  -> image tag pushed to GHCR
  -> Helm values updated
  -> ArgoCD syncs production
  -> BREAK validates runtime behavior
```

The key design is that security is not a separate manual step at the end. It is
built into the path from commit to runtime.

## CKS-Style Build Themes

Portfolio-Prod is not a CKS exam lab, but the BUILD work maps closely to CKS
skills:

| CKS theme | Portfolio-Prod implementation |
|---|---|
| Cluster setup and hardening | k3s deployment model, kubelet hardening scripts, restricted namespace intent. |
| Minimize microservice vulnerabilities | Non-root pods, dropped capabilities, read-only root filesystem, resource limits, service account token disabled. |
| Supply chain security | detect-secrets, Semgrep, Bandit, Safety, npm audit, Checkov, SonarCloud, Trivy, trusted registries, immutable-ish image tags. |
| Runtime security | Kubernetes probes, NetworkPolicy, Falco references in the broader BREAK evidence, local audit logging. |
| Monitoring, logging, and remediation | Audit logger, ArgoCD drift visibility, security reports, patchwork/POA&M routing. |

## Implementation Highlights

### Application Security

The FastAPI app implements:

- production-gated docs endpoints
- strict CORS origins
- security headers
- HSTS when served over HTTPS
- chat-path rate limiting
- static route separation

The Sheyla AI route adds:

- Pydantic request validation
- prompt injection detection
- input sanitization
- RAG retrieval timeout handling
- response validation before return
- output sanitization
- hashed audit logging

### Kubernetes Security

The Helm chart implements:

- `runAsNonRoot`
- fixed user/group IDs
- `readOnlyRootFilesystem`
- `allowPrivilegeEscalation: false`
- `privileged: false`
- dropped Linux capabilities
- `seccompProfile: RuntimeDefault`
- `automountServiceAccountToken: false`
- resource requests and limits
- ClusterIP services
- NetworkPolicy

### GitOps And CI/CD

The pipeline implements:

- parallel security scanning
- container builds for API and UI
- Trivy image scans
- Helm value tag updates
- ArgoCD reconciliation
- policy-as-code checks for rendered manifests

This is the BUILD side of the CBBP loop: create the controls, encode them in
source, and make the deployment path repeatable.

## What BUILD Does Not Claim

BUILD does not prove the controls work in production. It implements them.

Examples:

- BUILD can disable docs in code and Helm.
- BREAK must show `/docs`, `/redoc`, and `/openapi.json` are unavailable at runtime.
- BUILD can configure ChromaDB as internal-only.
- BREAK must confirm there is no public route to ChromaDB.
- BUILD can add prompt-injection detection.
- BREAK must test adversarial prompts and review the output.

That is the purpose of the next phase: BUILD creates the control; BREAK validates
the claim.
