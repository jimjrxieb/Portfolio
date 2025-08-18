# Portfolio Fine-Tuning Runbook
*Senior-level checklist for production-ready portfolio*

## Pre-flight (2-minute sanity)
- [ ] **Verify images exist** `ghcr.io/jimjrxieb/portfolio-{api,ui}:main-e12b3fd`
- [ ] **Deploy** `./scripts/deploy-from-registry.sh main-e12b3fd`
- [ ] **Ingress** `kubectl -n portfolio get ingress`
- [ ] **Open** [https://linksmlm.com](https://linksmlm.com) → confirm the new build is live

> If any step fails: check `kubectl -n portfolio get events`, and `kubectl -n portfolio logs deploy/<api|ui>`.

---

## U1 — UX/UI polish (truthful + snappy)
- [ ] **Model banner** reflects health endpoint fields (provider/model, RAG namespace).
- [ ] **Citations drawer**: dedupe, clickable source IDs, graceful "no sources" state.
- [ ] **Error UX**: friendly, actionable messages for: RAG offline, LLM unavailable, rate limit hit.
- [ ] **Accessibility**: focus states, ARIA roles on chat input/buttons, keyboard submit, skip-to-content link.
- [ ] **Loading states**: optimistic send + spinner with timeout fallback (10s) → message: "Still working…".

**Acceptance:** 5 quick questions render <2.0s p95 on UI (excluding LLM latency).

---

## P1 — Performance & cost (laptop-safe)
- [ ] **Disable heavy deps in dev** (Chroma/Ollama off unless needed).
- [ ] **HTTP keep-alive** & **gzip/br** on server responses.
- [ ] **Cache** static assets (immutable + content hash).
- [ ] **Chunked streaming** from API to UI (if supported).
- [ ] Set tiny **resources** per pod (e.g., ui/api requests 50m/128Mi, limits 250m/256Mi).

**Acceptance:** p95 end-to-end (UI click → first token) < 2.5s on Spectre; CPU stays <70%.

---

## R1 — RAG quality & guardrails
- [ ] **Namespace discipline**: `portfolio` only for public answers.
- [ ] **Prompt contract**: "Use context only; cite; refuse when missing numbers."
- [ ] **Golden set**: rerun 20/20; store outputs & latencies.
- [ ] **Negative tests**: numeric bait ("How many X this month?") → **refusal + next step**.
- [ ] **Retrieval debug (locked)**: doc IDs + scores; NO content leakage.

**Acceptance:** 100% on golden set; 0 hallucinated numerics; each answer shows ≥1 valid citation when expected.

---

## S1 — Security essentials (minimum bar)
- [ ] **CORS**: allow only `https://linksmlm.com`.
- [ ] **Rate limit** chat (simple in-proc).
- [ ] **Headers**: HSTS, X-Content-Type-Options, X-Frame-Options (deny), Referrer-Policy, and a **CSP** (at least script-src 'self').
- [ ] **Secrets**: none in logs; redact `authorization`, `api_key`.
- [ ] **Containers**: `runAsNonRoot`, `readOnlyRootFilesystem`, `capabilities: drop: [ALL]`, probes on all pods.
- [ ] **ImagePullSecret** for GHCR with read scope only.
- [ ] **NetworkPolicy** (even one simple rule): deny egress by default; allow DNS + required egress.

**Acceptance:** Security headers present; CORS blocked for non-origin; pods show securityContext; pulling from GHCR succeeds with limited token.

---

## O1 — Observability & operability
- [ ] **Health endpoint**: provider/model, RAG namespace, avatar mode.
- [ ] **Structured logs** (JSON) with request id; no PII.
- [ ] **One-page runbook**: "If chat fails → H1 health → H2 events → H3 logs."
- [ ] **Simple counters**: total chats, refused answers, avg latency (even log-based).

**Acceptance:** You can diagnose a failure in <2 minutes from CLI + logs, no extra stack needed.

---

## F1 — Failure drills (prove resilience)
- [ ] **Bad image tag** → deploy → observe failure → fix via new tag.
- [ ] **Kill API** → verify graceful UI error + recovery after redeploy.
- [ ] **RAG offline** → UI refusal path + message "upload docs or retry later".

**Acceptance:** All recoveries done via the script or a new push; no manual cluster surgery.

---

## DX — CI/Deploy ergonomics
- [ ] **Tag handoff**: workflow outputs the tag (e.g., `main-e12b3fd`) prominently.
- [ ] **Deploy script**: idempotent, validates namespace/ingress; fails fast with clear exit codes.
- [ ] **Release notes**: workflow summary comment (image digests, tag, link to site).
- [ ] **Rollback**: one-liner to redeploy previous tag.

**Acceptance:** From commit to live takes one human step (run script) with zero guesswork.

---

## Interview Ammo (capture these)
- [ ] **Screen recording**: push → GH Actions build → local deploy script → site update.
- [ ] **Metrics**: p95 chat latency, golden-set score 20/20, refusal demo.
- [ ] **Architecture slide**: GHA → GHCR → local Helm → Cloudflare Tunnel (`linksmlm.com`).

---

## Security Review Snapshot
**Risks:** token leakage, open CORS, root containers, missing probes, over-egress.
**Mitigations:** GHA secrets only; strict CORS; non-root + read-only FS + dropped caps; probes; deny-egress; redacted logs.
**Follow-ups:** sign images (cosign) and optionally add a basic Kyverno policy ("no root, probes required").

---

## Progress Tracking
- **Started:** [Date]
- **Pre-flight:** [ ] Complete
- **U1:** [ ] Complete  
- **P1:** [ ] Complete
- **R1:** [ ] Complete
- **S1:** [ ] Complete
- **O1:** [ ] Complete
- **F1:** [ ] Complete
- **DX:** [ ] Complete
- **Interview Ready:** [ ] Complete