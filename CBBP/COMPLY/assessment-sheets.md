# Control Assessment Sheets

These sheets follow the teaching template in `ssp/ssp-workpaper.md`. They show
how COMPLY turns system facts into control decisions and routes the remaining
work.

## AC-6: Least Privilege

**Control:** AC-6 Least Privilege

**Control Requirements:** Limit privileged access and give components only the
permissions needed to perform authorized functions.

**SSP Statement:** Portfolio pods run as non-root, drop Linux capabilities,
disable privilege escalation, and do not automount Kubernetes service account
tokens.

**Evidence Reviewed:**

- `infrastructure/charts/portfolio/values.yaml`
- `infrastructure/charts/portfolio/templates/deployment-api.yaml`
- `infrastructure/charts/portfolio/templates/serviceaccount.yaml`

**Test Performed:** Reviewed Helm values and rendered deployment intent for pod
security context, container security context, service account token automount,
and runtime privilege settings.

**Grade Result:** PASS

**Justification:** The chart codifies least-privilege defaults:
`runAsNonRoot=true`, `allowPrivilegeEscalation=false`,
`readOnlyRootFilesystem=true`, dropped capabilities, `RuntimeDefault` seccomp,
and `automountServiceAccountToken=false`.

**Gap Identified:** Runtime evidence should be packaged in PROVE if this is used
for external assurance.

**Risk Statement:** If these controls drift, a compromised pod could gain a
larger cluster or host-level blast radius.

**Finding Created:** No

**POA&M Created:** No

---

## CM-7: Least Functionality

**Control:** CM-7 Least Functionality

**Control Requirements:** Configure systems to provide only required
capabilities and disable unnecessary functions, ports, protocols, and services.

**SSP Statement:** FastAPI docs, ReDoc, and OpenAPI schema are disabled when the
environment is production.

**Evidence Reviewed:**

- `api/main.py`
- `infrastructure/charts/portfolio/values.yaml`
- `CBBP/BREAK/examples.md`

**Test Performed:** Reviewed source configuration and BREAK result narrative for
runtime docs endpoint behavior.

**Grade Result:** PASS after BREAK validation

**Justification:** `api/main.py` gates `docs_url`, `redoc_url`, and
`openapi_url` based on `ENVIRONMENT=production`, and the Helm values set
`ENVIRONMENT: "production"`. BREAK examples document that production docs
gating passed after runtime validation.

**Gap Identified:** None for current public teaching claim. PROVE can package
the raw endpoint evidence if needed.

**Risk Statement:** Exposed interactive docs can increase reconnaissance value
for attackers.

**Finding Created:** No

**POA&M Created:** No

---

## SC-7: Boundary Protection

**Control:** SC-7 Boundary Protection

**Control Requirements:** Monitor and control communications at external
boundaries and key internal boundaries.

**SSP Statement:** Public routes expose only the UI and API. ChromaDB remains an
internal ClusterIP service and is not publicly routed.

**Evidence Reviewed:**

- `infrastructure/charts/portfolio/templates/service.yaml`
- `infrastructure/charts/portfolio/templates/httproute.yaml`
- `infrastructure/charts/portfolio/templates/networkpolicy.yaml`
- `CBBP/BREAK/examples.md`

**Test Performed:** Reviewed Kubernetes service types, HTTPRoute backends, and
NetworkPolicy intent.

**Grade Result:** PASS

**Justification:** API, UI, and ChromaDB services are declared as ClusterIP.
HTTPRoutes point to API and UI only. NetworkPolicy limits ingress and allows
internal pod communication for the application boundary.

**Gap Identified:** Continue to package runtime route/service evidence for PROVE
when publishing assurance artifacts.

**Risk Statement:** If ChromaDB became externally reachable, the RAG data store
could become a retrieval-integrity and data exposure risk.

**Finding Created:** No

**POA&M Created:** No

---

## SI-10: Information Input Validation

**Control:** SI-10 Information Input Validation

**Control Requirements:** Validate information inputs and prevent malformed,
unsafe, or unauthorized input from causing unexpected behavior.

**SSP Statement:** Chat input passes through request validation, prompt-injection
detection, sanitization, response validation, output sanitization, rate limiting,
and audit logging.

**Evidence Reviewed:**

- `api/routes/chat.py`
- `api/routes/validation.py`
- `api/sheyla_security/llm_security.py`
- `CBBP/BREAK/examples.md`

**Test Performed:** Reviewed chat route flow and security guard implementation;
compared AI/RAG validation examples against expected refusal and grounding
behavior.

**Grade Result:** PASS / PARTIAL

**Justification:** The source code implements multiple layers of input and output
safety. BREAK examples show adversarial prompt validation passed after manual
review. The remaining partial is evidence maturity: exact prompt sets, outputs,
and review artifacts should be packaged in PROVE.

**Gap Identified:** Regression prompt set and validation results need final
evidence packaging.

**Risk Statement:** Weak input validation in an AI assistant can allow prompt
injection, unsupported claims, secret disclosure attempts, or unsafe behavior.

**Finding Created:** Yes, as evidence packaging follow-up

**POA&M Created:** No, unless external assurance requires packaged regression
evidence before closure

---

## IA-5: Authenticator Management

**Control:** IA-5 Authenticator Management

**Control Requirements:** Protect authenticators, rotate compromised
credentials, and prevent unauthorized disclosure.

**SSP Statement:** LLM API keys are injected at runtime through Kubernetes
Secret / ExternalSecret flow and are not committed into source code or public
evidence.

**Evidence Reviewed:**

- `infrastructure/charts/portfolio/values.yaml`
- `infrastructure/charts/portfolio/templates/deployment-api.yaml`
- `.gitignore`
- `.pre-commit-config.yaml`
- `SECURITY_INCIDENT_RESPONSE.md`

**Test Performed:** Reviewed secret injection model, git hygiene controls, and
public documentation for sensitive values.

**Grade Result:** PASS

**Justification:** The API deployment consumes `portfolio-api-secrets` with
`envFrom.secretRef`; Helm values list required secret keys but do not contain
secret values. Public docs were scrubbed of private server and tunnel details.

**Gap Identified:** Keep owner attestation and rotation proof outside public
docs or package it redacted in PROVE.

**Risk Statement:** Exposed LLM/API credentials could lead to cost abuse,
unauthorized API use, or broader compromise.

**Finding Created:** No for current state

**POA&M Created:** No

---

## AU-2 / SI-4: Event Logging And Monitoring

**Control:** AU-2 Event Logging; SI-4 System Monitoring

**Control Requirements:** Generate, review, and monitor security-relevant
events.

**SSP Statement:** The application logs AI security events locally and records
hashed-IP audit entries; runtime detection exists, but SIEM forwarding evidence
is not packaged.

**Evidence Reviewed:**

- `AuditLogger` in `api/sheyla_security/llm_security.py`
- `CBBP/BREAK/examples.md`

**Test Performed:** Reviewed audit logger fields and BREAK detection notes.

**Grade Result:** PARTIAL

**Justification:** Local audit logging exists and BREAK examples describe local
rate-limit and prompt-injection event visibility. However, local logs are not the
same as SIEM ingestion, saved searches, alerting, and retention evidence.

**Gap Identified:** Splunk/SIEM forwarding and query evidence not packaged.

**Risk Statement:** Without packaged detection evidence, operators and auditors
cannot prove that abuse events are searchable, retained, and reviewable.

**Finding Created:** Yes

**POA&M Created:** Recommended if SIEM evidence is required for the target
assurance level

---

## SR-4 / SI-12: RAG Corpus Provenance

**Control:** SR-4 Provenance; SI-12 Information Management and Retention

**Control Requirements:** Track source integrity and manage information used by
the system.

**SSP Statement:** RAG content is curated public-intent professional data, but
the active collection proof and owner-approved corpus manifest need stronger
packaging.

**Evidence Reviewed:**

- `rag-pipeline/`
- `backend/engines/rag_engine.py`
- `CBBP/COMPLY/ai-rmf-map.md`

**Test Performed:** Reviewed RAG architecture and data flow from corpus to
retrieval-backed responses.

**Grade Result:** PARTIAL

**Justification:** RAG provenance is recognized as a control requirement, and
ChromaDB is boundary-protected. The remaining gap is evidence maturity: a
specific manifest should be tied to active collection name, document count,
hashes, approval date, and ingestion run ID.

**Gap Identified:** Owner-approved manifest and active Chroma collection proof.

**Risk Statement:** Without provenance, RAG systems are more exposed to
unsupported claims, stale content, or retrieval poisoning.

**Finding Created:** Yes

**POA&M Created:** Recommended until active collection proof is packaged
