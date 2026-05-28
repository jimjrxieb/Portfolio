# BREAK: AI Security Validation Notes

This folder documents the BREAK phase for Portfolio-Prod, a production AI/RAG
portfolio application. It is written as a public teaching artifact: enough detail
to show the security engineering method, without publishing secrets, tokens, raw
customer data, or instructions for unsanctioned testing.

## Why BREAK Exists

My CBBP workflow is:

| Phase | Question |
|---|---|
| COMPLY | What should be true? |
| BUILD | How do we make it true? |
| BREAK | Does it still hold when tested? |
| PROVE | Can we package the evidence or route the gap? |

BREAK exists because a control can look compliant in a document and still fail
when tested in a running system. The purpose is not to "break things for show."
The purpose is to validate the claim, preserve the evidence, and route anything
unfinished back into remediation.

## Personal Operating Model

I am applying the same discipline I learned from 13 years in
HAZWOPER-regulated environments:

- Define the hazard before touching the system.
- Establish the scope boundary and stop conditions.
- Use documented procedures, not improvisation.
- Treat evidence quality as part of the work.
- Escalate or stop when the result is unexpected.
- Do not call a condition safe just because it did not obviously fail.

That maps cleanly into AI security work. Prompt injection, unsafe retrieval,
credential leakage, weak boundaries, and missing detection are hazards. The
control must be tested, not assumed.

## Guardrails

The BREAK guardrail I use for AI-assisted testing is:

```text
Agent writes. Human executes. Both review.
```

For this project that means:

- Codex and Claude Code can help scope tests, write scripts, map controls, and
  analyze evidence.
- Production-active or cluster-active testing stays human-approved.
- No secrets, tokens, key suffixes, or unredacted sensitive screenshots are
  stored in the public repo.
- No broad internet scanning or destructive testing is part of this artifact.
- Ambiguous results are marked inconclusive or patchwork needed, not passed.
- Every meaningful test maps back to a control, expected behavior, and evidence.

## What Was Tested

The Portfolio-Prod BREAK plan focuses on the parts of an AI/RAG application that
matter operationally:

| Test area | Security question | Example control anchors |
|---|---|---|
| Production docs gating | Are `/docs`, `/redoc`, and `/openapi.json` unavailable in production? | CM-7, SC-7, AC-3, SA-11 |
| CORS enforcement | Are only approved origins accepted? | SC-7, SC-8, CM-6, SI-10 |
| Vault / External Secrets | Are runtime secrets delivered without exposing values? | IA-5, SC-12, AC-6, CM-6 |
| ChromaDB boundary | Is the vector database internal-only? | SC-7, SC-5, CM-2, CA-3 |
| Rate limiting | Does chat-path traffic get throttled under bounded pressure? | SC-5, SC-7, CM-7 |
| AI/RAG validation | Does the assistant resist prompt injection, credential requests, and unsupported claims? | SI-10, SA-11, SR-4, SI-12, NIST AI RMF MEASURE |
| Detection review | Are security events observable beyond local logs? | AU-2, AU-6, AU-12, SI-4, IR-4 |

## Current Results

| Area | Result | Teaching point |
|---|---|---|
| Production docs gating | Passed | Runtime checks showed docs endpoints disabled in production. |
| CORS behavior | Passed | Approved origin was allowed; untrusted origin was denied. |
| Vault-backed secrets | Passed | External Secrets sync was healthy; no secret values were captured. |
| ChromaDB boundary | Passed | ChromaDB stayed internal-only with no public route. |
| Rate limiting | Passed | Bounded validation returned HTTP 429 after the threshold. |
| AI/RAG adversarial prompts | Passed after manual review | A script false positive was reviewed manually; refusal behavior was safe. |
| Splunk/SIEM forwarding | Patchwork needed | Local logs and Falco existed, but SIEM packaging was not proven. |
| External Secrets cert-controller health | Patchwork needed | App secret sync worked, but a platform component needed remediation or risk acceptance. |

## Evidence Routing

The result folders use plain language on purpose:

| Folder | Meaning |
|---|---|
| `greatsuccess` | The control passed with usable evidence. |
| `patchworkneeded` | The control failed, was incomplete, or needs remediation/risk acceptance. |
| `inprogress` | The validation is still running or awaiting review. |

This is the practical lesson: evidence routing matters. A system can have strong
security controls and still have honest open work. For example, local application
logs can show prompt-injection detection and rate-limit events, but that does not
automatically prove Splunk/SIEM ingestion, retention, search, and alerting.

## Evidence Quality Rubric

I use a simple evidence standard:

| Tier | Criteria |
|---|---|
| Bad | Screenshot dump, stale export, missing control mapping, or no chain of custody. |
| Good | Dated, labeled, control-keyed evidence with source, collector, scope, and reviewer. |
| Great | Good evidence plus reproducible steps, immutable reference or hash, exceptions, and retest linkage. |

The goal is not just to run a test. The goal is to produce evidence that a
security engineer, auditor, or operator can understand later.

## How To Read This Folder

Start here:

1. Read this file for the method and guardrails.
2. Read [examples.md](examples.md) for the concrete Portfolio-Prod examples.
3. Compare passed controls with patchwork-needed items.
4. Notice that the open items are documented instead of hidden.

That is the main lesson from this BREAK phase: AI security is not just policy
language or model behavior. It is scoped testing, control mapping, evidence
quality, and honest handoff when something is not proven yet.
