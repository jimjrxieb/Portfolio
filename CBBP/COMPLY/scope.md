# COMPLY Scope

## Assessment Boundary

Portfolio-Prod is assessed as a public, LOW-impact AI/RAG application. The
COMPLY boundary includes the application code, deployment manifests, CI/CD
security controls, Kubernetes runtime posture, RAG data path, and AI safety
logic contained in this repository.

## In Scope

| Area | Included components |
|---|---|
| Frontend | React/Vite UI, Nginx container, public portfolio pages, chat interface. |
| API | FastAPI app, chat route, health route, security middleware, rate limiting, CORS, docs gating. |
| AI/RAG | Sheyla chat flow, RAG retrieval, ChromaDB, response validation, prompt-injection detection, output sanitization. |
| Infrastructure | Helm chart, ArgoCD deployment model, Kubernetes services, service account, network policy, Gateway/HTTPRoute. |
| Security engineering | Pre-commit hooks, CI scanning, secrets hygiene, incident response docs, SSP working document. |
| Evidence routing | COMPLY findings, BREAK validation examples, POA&M/patchwork routing. |

## Out of Scope

| Area | Reason |
|---|---|
| Enterprise 3PAO audit | This is a portfolio teaching artifact, not a formal authorization package. |
| User account lifecycle | The public app has no visitor accounts, registration, or login workflow. |
| Payment, PHI, or regulated customer data | The app is not designed to process these data types. |
| Broad internet scanning | BREAK validation is scoped and owner-authorized only. |
| Full SIEM certification | Local logs and Falco are considered, but packaged SIEM evidence remains a separate gap. |

## Data Classification

| Data type | Classification | Notes |
|---|---|---|
| Portfolio content | Public | Intended to be visible to site visitors. |
| Chat prompts | Low sensitivity / transient | Processed for response generation; not intended as persistent user records. |
| RAG corpus | Public-intent professional data | Requires provenance to prevent poisoning or unsupported claims. |
| API keys and tokens | Sensitive | Must remain in secret stores and never appear in source, logs, or public evidence. |
| Audit logs | Internal | Should avoid raw secrets and use privacy-preserving identifiers where possible. |

## Assumptions

- The system remains single-operator and LOW impact.
- Public visitors are unauthenticated and read-only.
- The API remains single-replica unless the rate-limit design is revisited.
- ChromaDB remains internal-only and is not publicly routed.
- Secrets are injected from the approved runtime secret path.
- Final closure of runtime claims requires BREAK evidence.

## Primary Frameworks

| Framework | Use in this folder |
|---|---|
| NIST SP 800-53 Rev. 5 | Main control language for access, audit, configuration, incident response, risk, system integrity, and boundary protection. |
| NIST AI RMF | AI governance lens for mapping, measuring, managing, and governing AI/RAG behavior. |
| MITRE ATLAS / OWASP LLM concepts | Supporting threat vocabulary for prompt injection, data leakage, retrieval issues, and AI misuse. |

## CBBP Routing

| Finding type | Route |
|---|---|
| Missing control or weak implementation | BUILD |
| Control implemented but untested | BREAK |
| Evidence exists but is not packaged | PROVE |
| Risk accepted by owner | PROVE / POA&M |
