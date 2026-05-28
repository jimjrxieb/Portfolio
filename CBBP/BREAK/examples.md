# BREAK Examples: Portfolio-Prod

These examples summarize what was validated during the Portfolio-Prod BREAK
phase. They are intentionally written for public review and portfolio teaching.
Raw secrets, tokens, private infrastructure details, and unredacted operational
outputs are not included.

## Example 1: Production Docs Gating

**Claim:** Interactive API documentation should not be exposed in production.

**Why it matters:** Public docs and OpenAPI schemas can accelerate attacker
reconnaissance by exposing routes, request formats, and internal assumptions.

**Expected behavior:**

- `/docs` should not return HTTP 200.
- `/redoc` should not return HTTP 200.
- `/openapi.json` should not return HTTP 200.

**Observed result:** Passed after GitOps redeploy. Production docs endpoints
returned unavailable responses.

**Control anchors:** CM-7, SC-7, AC-3, SA-11

**Lesson:** A source-code fix is not enough. The control only moved to
`greatsuccess` after the running deployment matched the claim.

## Example 2: CORS Enforcement

**Claim:** The API should allow the approved production origin and reject
untrusted origins.

**Why it matters:** CORS drift can quietly turn into a browser-side trust
boundary failure.

**Expected behavior:**

- Approved origin receives the expected `access-control-allow-origin` header.
- Untrusted origin is rejected and not reflected.

**Observed result:** Passed. The approved origin was accepted and the untrusted
origin was denied.

**Control anchors:** SC-7, SC-8, CM-6, SI-10

**Lesson:** Behavior and configuration both matter. Earlier validation caught
environment-variable drift; the result only passed once runtime behavior and the
documented config contract aligned.

## Example 3: Vault / External Secrets Runtime Path

**Claim:** Application secrets should come from the approved secret-management
path and should not be printed into evidence.

**Why it matters:** A secrets control is only useful if the runtime path is
healthy and the evidence process does not create a new exposure.

**Expected behavior:**

- ExternalSecret is synced and ready.
- ClusterSecretStore is valid and ready.
- The application consumes the managed Kubernetes Secret.
- No secret values are captured.

**Observed result:** Passed for the Portfolio application secret path.

**Control anchors:** IA-5, SC-12, AC-6, CM-6

**Lesson:** The evidence proves metadata and delivery health, not secret values.
That distinction is important in audit work.

## Example 4: ChromaDB Boundary

**Claim:** The vector database should remain internal-only.

**Why it matters:** A RAG system can expose sensitive retrieval data or create
data-poisoning risk if the vector store is reachable from outside the approved
boundary.

**Expected behavior:**

- ChromaDB service remains internal.
- Public routes point only to approved API/UI backends.
- No public route points directly to ChromaDB.

**Observed result:** Passed. ChromaDB remained internal-only.

**Control anchors:** SC-7, SC-5, CM-2, CA-3

**Lesson:** AI security is still system security. The model is not the only
asset; retrieval stores and service boundaries matter.

## Example 5: Rate-Limit Validation

**Claim:** Chat-path traffic should be throttled under bounded pressure.

**Why it matters:** AI endpoints can be expensive and can also be abused for
denial-of-wallet, denial-of-service, or prompt-spam testing.

**Expected behavior:** After the configured threshold, the API should return a
throttling response such as HTTP 429.

**Observed result:** Passed. The bounded validation returned HTTP 429 after the
threshold.

**Control anchors:** SC-5, SC-7, CM-7

**Lesson:** The result is valid for the current single-replica posture. If the
API scales horizontally, the in-memory limiter must be replaced or fronted by a
shared limiter such as Redis, gateway middleware, or ingress/controller rate
limiting.

## Example 6: AI/RAG Adversarial Prompt Validation

**Claim:** The assistant should resist common unsafe prompt patterns and avoid
unsupported private claims.

**Why it matters:** AI security validation must include behavior under pressure,
not only static code review.

**Prompt families tested:**

- Supported grounded portfolio answer.
- System prompt disclosure request.
- Credential disclosure request.
- Instruction override.
- Unsupported private claim.
- Citation and grounding behavior.

**Observed result:** Passed after manual review. One automated check produced a
false positive because the refusal text mentioned terms like "API keys" and
"tokens." Manual review showed the response refused disclosure and did not reveal
secret values.

**Control anchors:** SI-10, SI-3, SA-11, SR-4, SI-12, NIST AI RMF MEASURE

**Lesson:** Automation is useful, but human review still matters. A keyword hit
inside a safe refusal is not the same thing as a secret disclosure.

## Example 7: Detection And SIEM Review

**Claim:** Security-relevant events should be observable and packageable as
detection evidence.

**Why it matters:** A control that blocks an event but leaves no searchable or
retained evidence is hard to operate and hard to prove.

**Observed result:** Patchwork needed.

What was proven:

- Local application logs captured rate-limit events.
- Local application logs captured prompt-injection detection events.
- Falco was running and producing runtime events.

What was not proven:

- Splunk/SIEM forwarding.
- Saved searches or alert packaging.
- End-to-end event generation, ingestion, search, and review workflow.

**Control anchors:** AU-2, AU-6, AU-12, SI-4, IR-4

**Lesson:** Local logs are not the same as SIEM evidence. This stayed
`patchworkneeded` because the detection story was partial.

## Example 8: Platform Health Follow-Up

**Claim:** The secrets platform should be healthy enough to support ongoing
secret delivery and certificate/webhook maintenance.

**Observed result:** Patchwork needed. The Portfolio application secret sync was
healthy, but one External Secrets platform component had a readiness issue.

**Control anchors:** SI-2, CM-6, CA-7, IA-5, SC-12

**Lesson:** A specific app path can pass while the supporting platform still has
operational debt. BREAK should document that difference instead of flattening
everything into pass/fail.

## Summary Matrix

| Test | Result | Evidence disposition |
|---|---|---|
| Production docs gating | Pass | `greatsuccess` |
| CORS enforcement | Pass | `greatsuccess` |
| Vault / External Secrets app path | Pass | `greatsuccess` |
| ChromaDB boundary | Pass | `greatsuccess` |
| Rate limiting | Pass | `greatsuccess` |
| AI/RAG adversarial prompts | Pass after manual review | `greatsuccess` |
| Splunk/SIEM forwarding | Not proven | `patchworkneeded` |
| External Secrets cert-controller health | Degraded component | `patchworkneeded` |

## What This Demonstrates

This BREAK phase demonstrates a senior security habit: do not stop at the policy
or the implementation. Test the running system, preserve the evidence, and keep
open items visible.

For AI systems, that means validating both sides:

- Traditional security controls: boundaries, secrets, CORS, docs, rate limiting,
  logs, and runtime health.
- AI-specific controls: prompt injection handling, unsupported-claim behavior,
  credential refusal, RAG grounding, and retrieval boundaries.

The result is a clearer story than "secure" or "not secure." It shows which
claims passed, which claims need more proof, and what should happen next.
