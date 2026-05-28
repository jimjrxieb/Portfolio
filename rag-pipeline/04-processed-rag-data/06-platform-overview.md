# GP-Copilot Platform Overview

## What GP-Copilot Is

GP-Copilot is an open-source MSSP (Managed Security Services Provider) engagement framework. Built to do what GuidePoint, Deloitte, and PwC do manually — encoded into runbooks, automation, and agents.

It is not a product. It is a methodology with tooling behind it. The target clients are GuidePoint Security (MSSP alignment), Big 4 consulting firms (FedRAMP and compliance engagements), Federal and DoD (air-gap deployments, NIST 800-53), and Healthcare (HIPAA, audit readiness).

## Component Map

### GP-CONSULTING — The Brain

NIST 800-53 control families are the spine. Each directory is a control family. Navigate by control, not by tool.

```
AC/   Access Control         → RBAC, PSA, admission control
AU/   Audit and Accountability → logging, SIEM
CA/   Assessment, Authorization → gap analysis, kubescape, 3PAO
CM/   Configuration Management → platform setup, kube-bench, Kyverno, ArgoCD
CP/   Contingency Planning    → Velero restore
IA/   Identification and Auth → secrets, IAM, OIDC
IR/   Incident Response       → PICERL, Falco responders, forensics
PM/   Program Management      → Karpenter, cost optimization, SLOs
RA/   Risk Assessment         → Prowler, DAST, infra scan
SA/   System and Services Acq → SAST, CI/CD hardening
SC/   System and Comms Prot   → NetworkPolicy, mTLS, encryption
SI/   System and Info Integrity → Falco, Trivy, Semgrep
SR/   Supply Chain Risk Mgmt  → vendor integrations, SBOM, cosign
```

GP-CONSULTING contains playbooks (decision logic), scripts, and policies. It is the playbook-as-brain for every agent. Update a playbook and the agent behavior changes — no code changes needed.

### GP-MODEL-OPS — AI Training Factory

Where models get built. Not customer-facing.

- `0-data-lab/` — 40+ data generators, synthetic pipeline (7,095 real JSA findings)
- `1-local-pipeline/` — ETL, chunk, train, merge, convert, eval, feedback loops
- `2-rag-ingestion/` — ChromaDB (33k+ docs, 7 collections), nomic-embed-text 768-dim
- `3-model-registry/` — Weights, GGUFs, Modelfiles
- `4-eval-clarify/` — 667 benchmark questions, 24 domains
- `JADE-AI/`, `KATIE-AI/`, `BERU-AI/`, `RANK-AI/` — model directories

Model lifecycle is separate from engagement assessment. Training data goes to GP-MODEL-OPS. Red-team runs against a model go to GP-S3/engagements/models/.

### GP-S3 — Output Sink

Every engagement's artifacts land here. Three engagement buckets:
- `engagements/apps/` — internal apps (portfolio-prod, etc.)
- `engagements/models/` — AI model assessments (beru-ai, jade-ai)
- `engagements/clients/` — external client engagements

Plus cross-engagement infrastructure:
- `databases/` — 4 C's findings DBs (code.db, container.db, cluster.db, cloud.db) queryable with SQLite
- `mlops/` — model-build data (RAG staging, training chunks, eval reports)
- `knowledge-base/` — remediation patterns, security graph, AI-sec evidence library
- `Jimjr-RUNBOOKS/` — personal reference library (hands-off, not touched by agents)

### GP-SECLAB — Target Applications

Where CBBP engagements are run against real systems. Organized by slot number (legacy) and target name.

The Portfolio-Prod application (this system, linksmlm.com) lives at:
`GP-SECLAB/target-application/slot-1/Portfolio-Prod/`

The SecLab is where security assessments happen against real targets — not simulated environments.

### GP-INFRA — Platform Infrastructure

FastAPI on port 8000, GP-GUI on port 5050. The platform infrastructure that serves JADE's HTTP endpoints and provides the GUI for human operators.

## Production Infrastructure (Portfolio)

The portfolio application at linksmlm.com runs on:

- **k3s** — single-node Kubernetes cluster on a private host
- **ArgoCD** — GitOps continuous deployment, polls GitHub every ~3 minutes
- **Traefik** — Ingress controller (Gateway API HTTPRoutes)
- **Cloudflare Tunnel** — Zero-trust access, http2 protocol (QUIC disabled on this network)
- **cert-manager** — Automatic TLS via Let's Encrypt

Three services in the portfolio namespace:
- `portfolio-portfolio-app-api` — FastAPI on :8000
- `portfolio-portfolio-app-ui` — Nginx on :80 (internal :8080)
- `portfolio-portfolio-app-chroma` — ChromaDB on :8000

ArgoCD GitOps flow: push to main → GitHub Actions builds and tags images → auto-commits updated image tags to values.yaml → ArgoCD detects → syncs cluster → rolling update.

## CBBP Engagement — Portfolio Self-Assessment

The portfolio is both the product and the target. Running CBBP against your own production system is the most honest demonstration of the methodology.

Open POAM items from the Portfolio engagement include:
- POAM-COMPLY-PORT-010: SIEM forwarding gap (Fluent Bit/Falcosidekick not deployed)
- POAM-COMPLY-PORT-003: RAG corpus validation (embedding drift check not automated)
- external-secrets-cert-controller: health probe HTTP 500 (cert-controller pod issue)

These are not swept under the rug. They are tracked, dated, and in the POA&M. That is the "prove it" culture from 13 years of compliance work applied to the home lab.

## The Understand → Secure → Optimize → Outcome Loop

Every engagement, including internal ones, follows this progression:

**Understand** — discover, inventory, assess maturity before touching anything. COMPLY phase.

**Secure** — harden, remediate, enforce policy-as-code. BUILD phase plus BREAK validation.

**Optimize** — right-size, automate, reduce cost and toil. Security without efficiency is shelfware. If it requires too much manual effort, it will be abandoned. Optimization is what makes security stick.

**Outcome** — evidence, reporting, and business value delivered. PROVE phase. Every engagement ends with proof — auditor-ready evidence, measurable before-and-after metrics, and a clear answer to "what did we get for this work?"

This is not a consulting slide deck. It is an operational methodology encoded in git.
