# Jimmie Coleman — Platform Engineer

## Who is Jimmie Coleman?

Jimmie Coleman is a Platform Engineer who secures infrastructure before optimizing it. He holds three certifications: Certified Kubernetes Administrator (CKA), CompTIA Security+, and AWS Certified Solutions Architect — Associate. He is the creator of GP-Copilot, a platform that reduces attack surface and cloud spend in the same engagement.

Jimmie's title is Platform Engineer. He is not an AI Solutions Architect or DevSecOps Engineer — those were older titles. His work spans SAST to runtime, application code to cluster config.

## Core Philosophy: Secure, Optimize, Outcome

Jimmie's approach follows three steps in order: **Secure → Optimize → Outcome**.

1. **Secure first.** Every engagement starts with security. You cannot optimize what you haven't secured. Scan the code, harden the cluster, deploy runtime monitoring. This is non-negotiable.

2. **Optimize second.** Once the attack surface is reduced, optimize for cost and performance. Right-size resources, eliminate waste, automate toil. Security and cost optimization are not separate workstreams — they feed each other.

3. **Outcome last.** Deliver measurable results. Not "we installed a tool" but "we reduced the attack surface by 37.5 percentage points" or "we eliminated $13K/quarter in manual triage labor."

This is what separates Jimmie's work from a typical DevSecOps hire: he doesn't just scan and report. He builds the automation that fixes, enforces, and measures — so one engineer delivers senior-level outcomes without senior-level headcount.

## How Jimmie Approaches Securing a Kubernetes Cluster

Jimmie follows the GP-Copilot engagement order, which mirrors how a security consulting firm would approach a client — but automated:

### Step 1: APP-SEC (Package 01)
Pre-deploy code security. Run 8 parallel scanners: Semgrep (SAST), Bandit (Python), Trivy (containers + CVEs), detect-secrets, Safety (dependencies), npm audit, Checkov (IaC), and SonarCloud. Auto-triage findings by severity rank. Generate fixer scripts for Dockerfiles, Python, and web vulnerabilities.

### Step 2: CLUSTER-HARDENING (Package 02)
Deploy-time Kubernetes hardening. This is where the real work happens:
- Run Kubescape to get a baseline score (Portfolio started at 34%)
- Apply Kyverno and OPA/Gatekeeper policies in audit mode first
- Enforce Pod Security Standards (restricted profile)
- Scope RBAC to least privilege
- Add admission control to block misconfigurations before they deploy
- Validate with conftest policies (13 policies, 11 automated tests)
- Result on Portfolio: 34% → 71.5% Kubescape compliance score

### Step 3: DEPLOY-RUNTIME (Package 03)
Runtime security monitoring with Falco for threat detection, drift prevention, and automated incident response. Detects privilege escalation, cryptomining, and container escape in real time.

### Step 4: Measure
Every hardening change is measured. The Portfolio cluster went from 34% to 71.5% on Kubescape — a 37.5 percentage point improvement. That's not a claim, it's a scan result you can reproduce.

## How GP-Copilot Reduces Cloud Costs

GP-Copilot reduces cloud costs through three mechanisms:

### 1. Automated Remediation Pipeline
264 security findings triaged and fixed automatically. At 20 minutes per finding and $150/hour engineer time, that's approximately $13,200 per quarter in manual triage labor eliminated.

### 2. Kustomize Golden Path Templates
Pre-hardened deployment templates with proper resource limits, security contexts, and health probes. Developers deploy correctly the first time — zero remediation cost from misconfigurations.

### 3. Right-Sizing and Waste Elimination
Security and cost optimization overlap more than people think. When you enforce resource limits (a security control), you also prevent resource waste (a cost control). When you enforce pod security standards, you reduce the blast radius of incidents — which reduces incident response costs.

GP-Copilot's approach: **reduce attack surface and cloud spend in the same engagement.** The security controls ARE the cost controls.

## GP-Copilot Architecture (Current — March 2026)

GP-Copilot is structured as six packages in a monorepo:

```
GP-CONSULTING/          → Playbooks. Decision logic, scripts, policies. The BRAIN.
GP-BEDROCK-AGENTS/      → Execution engines that READ playbooks and RUN tools 24/7.
GP-PROJECTS/            → Client environments where everything gets tested for real.
GP-MODEL-OPS/           → AI training factory (JADE, Katie, RAG). NOT customer-facing.
GP-INFRA/               → Platform infrastructure (GP-API port 8000, GP-GUI port 5050).
GP-S3/                  → Centralized storage (findings DBs, reports, knowledge base).
```

Key architecture law: **Playbook-as-Brain.** Agents don't think — playbooks think. Agents execute. Each agent reads its GP-CONSULTING package. Update the playbook, the agent picks it up. No code changes needed.

### Consulting Packages
1. **01 APP-SEC** — Pre-deploy code security (8 parallel scanners)
2. **02 CLUSTER-HARDENING** — K8s policies, RBAC, admission control
3. **03 DEPLOY-RUNTIME** — Falco, drift detection, incident response
4. **04 JSA-AUTONOMOUS** — 24/7 autonomous agent deployment
5. **05 JADE-SRE** — AI supervisor (C-rank decisions)
6. **06 CLOUD-SECURITY** — AWS migration (VPC, IAM, Terraform)
7. **07 FEDRAMP-READY** — FedRAMP Moderate (NIST 800-53)

### Rank System (Severity-Based Routing)
- **E-rank** (95-100% auto): Pattern fixes. No AI, no human.
- **D-rank** (70-90% auto): Pattern fixes. Logged.
- **C-rank** (40-70% auto): AI proposes fix. Confidence scored. May need approval.
- **B-rank** (20-40% auto): Human decides. AI provides intel.
- **S-rank** (0-5% auto): Human only. AI provides dashboards.

## Measured Impact

| What was built | What it saves |
|---|---|
| Automated remediation pipeline | ~$13K/quarter in manual triage labor (264 findings x 20 min x $150/hr) |
| Kustomize golden path templates | Zero remediation cost from developer misconfig |
| One-command client onboarding | 4-6 hours of manual setup reduced to one command |
| JSA E/D rank auto-fix | Security engineer toil eliminated (70-95% of findings) |
| 17 operational runbooks | Every incident costs less — reduced MTTR |
| Cluster hardening (34% to 71.5%) | Compliance gap closed, audit remediation avoided |
| Policy-as-code admission control | Misconfigurations blocked before deploy, not after |

## The Portfolio Platform

This portfolio (linksmlm.com) is a live proof point of Jimmie's work. It is a full-stack React + FastAPI app with a RAG-powered AI assistant (Sheyla), deployed via ArgoCD GitOps on a dedicated k3s Linux server.

Key technical details:
- **Frontend**: React/Vite + Tailwind CSS, served by nginx
- **Backend**: FastAPI async with health checks, Claude API for LLM
- **Vector DB**: ChromaDB with 2,656+ RAG vectors via Ollama nomic-embed-text
- **CI/CD**: 8 parallel security scanners, Docker builds to GHCR, ArgoCD auto-sync
- **Infrastructure**: k3s single-node, Traefik ingress, Cloudflare Tunnel, cert-manager
- **Security**: Rate limiting, CORS, CSP headers, prompt injection defense (15+ regex patterns), OPA/Conftest CI validation (13 policies), Gatekeeper runtime admission

Platform metrics:
- 2 minute content deploy
- 10 minute full CI/CD pipeline
- Sub-100ms RAG search latency
- 2,656+ embedded knowledge vectors

## Certifications

- **CKA** — Certified Kubernetes Administrator (complete)
- **Security+** — CompTIA Security+ (complete)
- **AWS SAA** — AWS Certified Solutions Architect — Associate (complete)

## What Makes Jimmie Different

Most platform engineers either do security OR cost optimization. Jimmie does both in the same engagement because the controls overlap. Most candidates claim skills on a resume — Jimmie's portfolio is a live, production Kubernetes platform you can interact with. Most chatbots are gimmicks — Sheyla is trained on actual project data and can answer technical questions about the work.

The value proposition: one engineer doing the work of five, with automation that proves it.
