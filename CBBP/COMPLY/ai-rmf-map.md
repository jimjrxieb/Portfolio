# NIST AI RMF Map

This map applies the NIST AI RMF lens to Portfolio-Prod as an AI/RAG system.
The system is not a high-risk decisioning system. It is a public portfolio
assistant that answers questions about professional background, skills, and
projects. The AI risk focus is therefore reliability, grounding, prompt safety,
retrieval integrity, and evidence of control behavior.

## AI System Summary

| Item | Description |
|---|---|
| AI function | Conversational portfolio assistant named Sheyla. |
| Model/provider | Claude/Anthropic LLM integration through the FastAPI backend. |
| Retrieval | ChromaDB vector search over curated portfolio knowledge. |
| Users | Anonymous public visitors. |
| Data sensitivity | Public-intent professional content; secrets and internal paths must never be disclosed. |
| Primary AI risks | Prompt injection, hallucination, credential disclosure, unsupported claims, RAG poisoning, weak detection evidence. |

## AI RMF Function Mapping

| AI RMF function | Portfolio-Prod implementation | Evidence | Status |
|---|---|---|---|
| GOVERN | System purpose, owner, low-impact categorization, and POA&M tracking are documented. | `CBBP/COMPLY/ssp/system-security-plan.md`; `scope.md` | PASS / PARTIAL |
| MAP | AI/RAG use case, users, data sensitivity, retrieval boundary, and expected behavior are scoped. | `scope.md`; `README.md`; `api/routes/chat.py` | PASS |
| MEASURE | Response validation, prompt-injection checks, rate limiting, and BREAK adversarial examples measure behavior. | `api/routes/validation.py`; `api/sheyla_security/llm_security.py`; `CBBP/BREAK/examples.md` | PASS / PARTIAL |
| MANAGE | Unsafe inputs are blocked, outputs are sanitized, secrets are kept out of source, and gaps route to patchwork/POA&M. | `SheylaSecurityGuard`; `OutputSanitizer`; `CBBP/BREAK/README.md` | PASS / PARTIAL |

## AI Risk Controls

| AI risk | Control implemented | Evidence | Result | Next step |
|---|---|---|---|---|
| Prompt injection | Regex-based injection detection blocks common override, role hijack, delimiter, and jailbreak patterns before LLM call. | `PromptInjectionDetector` in `api/sheyla_security/llm_security.py` | PASS | Continue adversarial expansion in BREAK |
| Unsafe or malformed input | Input validation enforces length and removes dangerous characters. | `InputValidator`; Pydantic `ChatRequest` | PASS | Add test cases to PROVE package |
| Credential disclosure | Output sanitizer redacts sensitive patterns; adversarial validation includes credential-disclosure prompts. | `OutputSanitizer`; `CBBP/BREAK/examples.md` | PASS | Keep raw secrets out of evidence |
| Hallucination | Response validation checks known hallucination traps, grounding score, and context consistency. | `api/routes/validation.py`; `api/routes/chat.py` | PASS / PARTIAL | Package exact prompt/eval set |
| Unsupported private claims | Validation and adversarial prompts check that unsupported private/financial/residential claims are refused. | `validation.py`; BREAK examples | PASS | Keep regression set current |
| RAG poisoning | ChromaDB is internal-only and RAG corpus provenance is tracked as a compliance requirement. | `service.yaml`; `httproute.yaml`; `networkpolicy.yaml` | PARTIAL | Owner-approved corpus manifest and active collection proof |
| Retrieval outage or weak grounding | RAG failures are handled with fallback behavior; response validation still runs. | `api/routes/chat.py` | PARTIAL | Improve active RAG health and collection evidence |
| Abuse / high-cost usage | Chat-path rate limiting exists at middleware and Sheyla security layer. | `api/main.py`; `RateLimiter`; BREAK examples | PASS with condition | Reopen if replicas increase |
| AI event observability | Blocked injections and rate-limit activity are logged locally with hashed IPs. | `AuditLogger`; BREAK examples | PARTIAL | SIEM forwarding/search evidence needed |

## AI RMF Teaching Notes

### GOVERN

Governance is visible through ownership, categorization, scope, and routing.
Portfolio-Prod has a system owner, a LOW-impact categorization, a formal SSP
working document, and open gaps that route to BUILD, BREAK, or PROVE. The main
GOVERN improvement is to turn the current internal evidence into a cleaner
review package with explicit owner approvals.

### MAP

The AI use case is narrow: answer questions about the owner's public portfolio
and technical experience. That boundary matters. It means the assistant should
not answer unsupported private claims, reveal secrets, or pretend to have access
to information outside the curated corpus.

### MEASURE

Measurement is implemented through three layers:

- Source-level checks: validation code, prompt-injection detector, sanitizer,
  Pydantic models.
- Runtime checks: rate-limit, docs gating, CORS, Chroma boundary, and AI prompt
  tests in BREAK.
- Evidence checks: pass results go to `greatsuccess`; unproven claims go to
  `patchworkneeded`.

### MANAGE

Risk management is the handoff discipline. If a control fails, it does not get
rounded up to "secure." It goes to remediation. If evidence is missing, it stays
open. If a risk is accepted because the system is LOW impact, the acceptance is
documented.

## AI RMF Open Items

| Open item | Reason | Route |
|---|---|---|
| Active Chroma collection proof | Needed to tie RAG corpus provenance to the running system. | PROVE / BREAK |
| SIEM forwarding evidence | Needed to prove AI abuse events are searchable beyond local logs. | BREAK / PROVE |
| Prompt change control | System prompt changes affect AI behavior and should have review evidence. | BUILD / PROVE |
| Regression prompt set packaging | BREAK has examples; PROVE should package the exact test set and results. | PROVE |
