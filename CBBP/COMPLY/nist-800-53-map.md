# NIST 800-53 Rev. 5 Control Map

This map summarizes how Portfolio-Prod aligns to selected NIST SP 800-53 Rev. 5
controls. It is a COMPLY artifact: it maps claims and evidence. BREAK validates
runtime behavior, and PROVE packages final evidence.

## Summary

| Family | Representative controls | Current posture |
|---|---|---|
| AC - Access Control | AC-2, AC-3, AC-6, AC-17 | Mostly PASS |
| AU - Audit and Accountability | AU-2, AU-6, AU-12 | PARTIAL |
| CA - Assessment | CA-2, CA-7 | PASS / PARTIAL |
| CM - Configuration Management | CM-2, CM-6, CM-7, CM-8 | PASS |
| IA - Identification and Authentication | IA-2, IA-5, IA-8 | PASS |
| IR - Incident Response | IR-1, IR-4, IR-6 | PASS / PARTIAL |
| RA - Risk Assessment | RA-3, RA-5 | PASS |
| SA - System and Services Acquisition | SA-11, SA-15 | PASS |
| SC - System and Communications Protection | SC-5, SC-7, SC-8, SC-28, SC-39 | PASS / PARTIAL |
| SI - System and Information Integrity | SI-2, SI-3, SI-4, SI-10, SI-12 | PASS / PARTIAL |
| SR - Supply Chain Risk Management | SR-4 | PARTIAL |

## Control Details

| Control | COMPLY claim | Evidence in repo | Result | Route |
|---|---|---|---|---|
| AC-2 | Public visitors do not have managed accounts; owner/admin access is separate from public user access. | `CBBP/COMPLY/ssp/system-security-plan.md`; app has no registration/login routes. | PASS | PROVE if packaging externally |
| AC-3 | Kubernetes service account and namespace scoping enforce access boundaries. | `infrastructure/charts/portfolio/templates/serviceaccount.yaml`; `deployment-api.yaml`; `values.yaml` | PASS | BREAK for runtime review if needed |
| AC-6 | Containers run with least privilege: non-root, no privilege escalation, capabilities dropped, service account token automount disabled. | `infrastructure/charts/portfolio/values.yaml`; `deployment-api.yaml` | PASS | BREAK validates running pods |
| AC-17 | Remote admin access is private-network managed and not exposed as public SSH. | `CBBP/COMPLY/ssp/system-security-plan.md` | PASS | PROVE owner attestation if needed |
| AU-2 | App and AI security events are logged, including blocked prompts and rate-limit activity. | `api/sheyla_security/llm_security.py`; `api/routes/chat.py` | PARTIAL | BREAK/PROVE for SIEM packaging |
| AU-6 | Security events can be reviewed locally, but centralized review evidence is not fully packaged. | `CBBP/BREAK/examples.md`; local audit logger code | PARTIAL | PROVE/SIEM evidence needed |
| AU-12 | Audit records are generated for AI interactions with hashed IPs and block reasons. | `AuditLogger` in `api/sheyla_security/llm_security.py` | PASS / PARTIAL | PROVE retention story needed |
| CA-2 | The system has assessment artifacts and control review material. | `CBBP/COMPLY/ssp/`; `CBBP/BREAK/` | PASS | PROVE if external package |
| CA-7 | CI security scanning and GitOps drift detection support continuous monitoring. | `.github/workflows/`; `infrastructure/method3-helm-argocd/`; `values.yaml` | PASS / PARTIAL | PROVE dashboards/log exports |
| CM-2 | Baseline configuration is declared in Git through Helm, Dockerfiles, and app config. | `infrastructure/charts/portfolio/`; `api/main.py`; `README.md` | PASS | BREAK validates live state |
| CM-6 | Secure settings are codified: production env, CORS origins, security contexts, resource limits. | `values.yaml`; `deployment-api.yaml`; `api/main.py` | PASS | BREAK validates runtime |
| CM-7 | FastAPI docs/OpenAPI are disabled in production by environment-gated config. | `api/main.py`; `values.yaml`; `CBBP/BREAK/examples.md` | PASS after BREAK | PROVE evidence package |
| CM-8 | Components are identifiable through Helm chart, image tags, services, and deployment manifests. | `values.yaml`; `templates/service.yaml`; `Chart.yaml` | PASS | PROVE inventory export |
| IA-2 | Admin identity is separate from public visitor use; public users are unauthenticated. | `ssp/system-security-plan.md`; no public login endpoints | PASS | Owner attestation if needed |
| IA-5 | API keys are injected from secrets and not stored in public docs. | `values.yaml`; `deployment-api.yaml`; `.gitignore`; pre-commit config | PASS | PROVE redacted secret-flow evidence |
| IA-8 | Non-organizational users do not receive credentials; abuse is controlled through rate limiting. | `api/main.py`; `SheylaSecurityGuard` | PASS | BREAK rate-limit evidence |
| IR-1 | Incident response procedure exists. | `SECURITY_INCIDENT_RESPONSE.md` | PASS | PROVE packaging |
| IR-4 | Prior credential exposure was remediated and secret hygiene controls were added. | `SECURITY_INCIDENT_RESPONSE.md`; `.gitignore`; pre-commit config | PASS | Owner attestation retained privately |
| IR-6 | External reporting obligations are limited for this LOW system; internal reporting exists. | SSP and incident response docs | PARTIAL | PROVE decision record |
| RA-3 | Risks are assessed through COMPLY findings and POA&M routing. | `CBBP/COMPLY/assessment-sheets.md`; SSP POA&M | PASS | Continue updates |
| RA-5 | Security scanning exists across SAST, dependency, container, IaC, and secrets checks. | `.github/workflows/`; `.pre-commit-config.yaml`; `.secrets.baseline` | PASS | PROVE scan exports |
| SA-11 | Developer testing includes CI scans, policy-as-code, response validation, and BREAK validation. | `.github/workflows/`; `api/routes/validation.py`; `CBBP/BREAK/` | PASS / PARTIAL | Keep BREAK evidence linked |
| SA-15 | Development practices use Docker, GitOps, typed request models, and documented secure defaults. | `README.md`; `api/routes/chat.py`; infrastructure docs | PASS | PROVE process narrative |
| SC-5 | Rate limiting and Cloudflare-fronted ingress reduce abuse and availability risk. | `api/main.py`; `RateLimiter`; `CBBP/BREAK/examples.md` | PASS with condition | Reopen if API scales |
| SC-7 | Boundary protection separates public UI/API from internal ChromaDB. | `httproute.yaml`; `service.yaml`; `networkpolicy.yaml` | PASS | BREAK boundary evidence |
| SC-8 | External traffic is TLS-protected and security headers are applied. | `api/main.py`; Cloudflare/TLS architecture in SSP | PASS | PROVE cert evidence if needed |
| SC-28 | Vector data is public-intent portfolio content; stronger at-rest encryption is not claimed. | SSP accepted-risk notes | PARTIAL / accepted | POA&M if impact changes |
| SC-39 | Pods are isolated and run under restricted security contexts. | `deployment-api.yaml`; `values.yaml` | PASS | Runtime pod evidence |
| SI-2 | Dependency and container vulnerabilities are scanned and routed. | CI workflow, security docs | PARTIAL | Open findings stay tracked |
| SI-3 | Container/image scanning and policy checks reduce malicious-code risk. | Trivy, Semgrep, Bandit, OPA/Conftest workflow references | PASS | PROVE scan outputs |
| SI-4 | Monitoring exists locally; SIEM packaging remains open. | `AuditLogger`; `CBBP/BREAK/examples.md` | PARTIAL | BREAK/PROVE |
| SI-10 | User input and LLM output are validated, sanitized, and checked for injection/hallucination patterns. | `api/sheyla_security/llm_security.py`; `api/routes/validation.py`; `api/routes/chat.py` | PASS / PARTIAL | BREAK adversarial evidence |
| SI-12 | Chat input is transient and audit logs use hashed IPs; RAG corpus retention/provenance needs stronger evidence. | `AuditLogger`; `CBBP/COMPLY/ai-rmf-map.md` | PARTIAL | PROVE provenance package |
| SR-4 | RAG corpus integrity is relevant because retrieved data affects AI output. | RAG pipeline files; ChromaDB architecture; AI RMF map | PARTIAL | Owner-approved manifest and active collection proof |

## Main Gaps To Keep Visible

| Gap | Why it matters | Route |
|---|---|---|
| SIEM forwarding evidence not packaged | Local logs are not the same as searchable, retained detection evidence. | BREAK + PROVE |
| RAG active collection proof | A manifest is stronger when tied to a specific active Chroma collection and ingestion run. | PROVE + BREAK |
| Rate limiter scale condition | In-memory limiting is acceptable for one replica but not for horizontal scale. | BUILD if scaling |
| Evidence maturity | Some controls are implemented but need dated, reproducible evidence packages. | PROVE |
