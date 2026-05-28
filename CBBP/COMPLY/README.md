# COMPLY: Portfolio-Prod Security Scope

This folder documents the COMPLY phase for Portfolio-Prod. COMPLY answers the
question:

```text
What should be true, and where are we today?
```

The goal is to scope the system, map controls, identify gaps, and route work to
BUILD, BREAK, or PROVE. COMPLY does not prove that a control works at runtime.
That is the job of BREAK. COMPLY also does not package final audit evidence. That
is the job of PROVE.

## What This System Is

Portfolio-Prod is a public AI/RAG portfolio application:

- React/Vite frontend
- FastAPI backend
- ChromaDB vector database
- Claude/Anthropic LLM integration
- RAG retrieval over curated portfolio knowledge
- Helm + ArgoCD GitOps deployment
- Cloudflare-fronted public access
- Kubernetes security controls and network boundaries

The system is categorized as LOW impact because it is a public portfolio site
with no user accounts, no PHI, no payment data, and no intended storage of
visitor personal data.

## COMPLY Outputs

| File | Purpose |
|---|---|
| [scope.md](scope.md) | System boundary, data types, assumptions, and in-scope controls. |
| [nist-800-53-map.md](nist-800-53-map.md) | Control-by-control NIST 800-53 Rev. 5 alignment summary. |
| [ai-rmf-map.md](ai-rmf-map.md) | AI RMF alignment for RAG, prompt security, AI validation, and monitoring. |
| [assessment-sheets.md](assessment-sheets.md) | Teaching-style control assessment sheets using PASS/PARTIAL/FAIL. |
| [ssp/system-security-plan.md](ssp/system-security-plan.md) | Formal SSP working document. |

## How To Read The Results

This COMPLY package uses three plain result labels:

| Result | Meaning |
|---|---|
| PASS | The control has source evidence and the current claim is reasonable for this system. |
| PARTIAL | The control exists, but needs runtime validation, owner approval, stronger evidence, or a PROVE package. |
| FAIL | The claim is not supported by current evidence or the system behavior contradicts it. |

For public portfolio purposes, the most important part is the routing discipline:

- Gaps in implementation go to BUILD.
- Gaps in runtime proof go to BREAK.
- Gaps in evidence packaging go to PROVE.
- Accepted risks stay visible instead of being hidden.

## Current High-Level Posture

| Area | COMPLY posture | Reason |
|---|---|---|
| Access control | PASS | Public visitors have no accounts; app pods use restricted service accounts and disabled service-account token automount. |
| Configuration management | PASS / PARTIAL | Secure defaults are codified; some claims require runtime evidence before external assurance. |
| Secrets management | PASS | Runtime secrets are injected through Kubernetes Secret / ExternalSecret flow; public docs do not include secret values. |
| Boundary protection | PASS | Public routes target UI/API; ChromaDB is internal-only by design. |
| AI input/output safety | PASS / PARTIAL | Prompt injection, input validation, output sanitization, and response validation exist; adversarial evidence belongs to BREAK. |
| Audit and monitoring | PARTIAL | Local audit logs and runtime events exist; SIEM forwarding evidence remains a PROVE/BREAK gap. |
| RAG provenance | PARTIAL | Corpus provenance exists conceptually, but active collection proof and owner approval are needed for stronger evidence. |

## Teaching Point

COMPLY is not the same thing as "secure." COMPLY creates the map. It says which
controls apply, what evidence exists, what is missing, and who should handle the
next step.

For this project, the important lesson is that AI security compliance includes
both traditional system controls and AI-specific behavior controls:

- Traditional controls: access, secrets, network boundaries, CI scanning,
  configuration, logging, rate limiting, and incident response.
- AI controls: prompt injection handling, refusal behavior, grounding,
  hallucination checks, RAG source provenance, and AI abuse detection.
