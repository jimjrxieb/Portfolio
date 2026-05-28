# AI Models — JADE, KATIE, and BERU

## Overview

GP-Copilot includes three purpose-built AI models, each fine-tuned for a specific domain and authority level. These are not wrappers around external APIs — they are fine-tuned language models trained on real security engineering data, deployed locally via Ollama, and integrated into the CBBP engagement workflow.

All three models run on-premise. No engagement data leaves the environment when using local models. This is a core architectural requirement for federal and air-gap deployments.

## JADE — DevSecOps Intelligence (8B)

**Base model**: LLaMA 3.1-8B  
**Authority**: C-rank maximum (hardcoded, never changes)  
**Domain**: DevSecOps — Code, Container, Cluster phases of CBBP  
**Status**: In active development  

JADE is the fleet commander in the authority chain. JADE reads from the SA/ (System and Services Acquisition), CM/ (Configuration Management), SI/ (System and Information Integrity), AC/ (Access Control), AU/ (Audit and Accountability), and RA/ (Risk Assessment) control families.

What JADE does:
- Analyzes SAST output, CVEs, Kubernetes misconfigurations, and IaC flaws
- Provides risk scoring and severity classification
- Proposes C-rank remediations for KATIE to execute
- RAG-augmented: queries 33k+ security documents for similar findings and past decisions
- Multi-step reasoning via LangGraph before producing a recommendation

What JADE never does:
- Makes B-rank or S-rank decisions (those require human judgment)
- Executes remediations directly (KATIE executes, JADE proposes)
- Accesses production systems without human approval above C-rank

The JADE system is more than an LLM. It is: the FastAPI endpoint, the ChromaDB RAG engine with 8,800+ security documents, the RANK-AI ML classifier for verification, the LangGraph reasoning chain, and the LLaMA 8B model as the final decision layer.

## KATIE — Platform Operations (3B)

**Base model**: LLaMA 3.2-3B  
**Authority**: C-rank maximum (hardcoded, never changes)  
**Domain**: Kubernetes operations, k8sgpt, kubectl-ai, NIST-backed fixes  
**Status**: Training complete (v1: 36 chunks, 294,998 examples)  

KATIE is the only deployed agent. KATIE reads from the CM/ (Configuration Management) control family and has K8s operational knowledge baked in.

What KATIE does:
- Triage and classification of findings (routes to correct rank level)
- Kubernetes health checks, configuration fixes, CKS audit responses
- Executes JADE-proposed C-rank remediations after confidence scoring
- Every fix KATIE makes is NIST-backed — mapped to a specific control

What KATIE never does:
- Makes decisions above C-rank
- Takes action without confidence scoring and logging
- Operates without a JADE intelligence feed for context

KATIE is intentionally small (3B) — fast classification and execution, not deep reasoning. Deep reasoning is JADE's job.

## BERU — GRC Analyst (8B)

**Base model**: LLaMA 3.1-8B  
**Authority**: Read-only — BERU never fixes anything  
**Domain**: NIST 800-53 internal auditor, SSP authorship, POA&M generation, CISO reports  
**Status**: Scaffold complete, training in progress  

BERU is the auditor. BERU's name reflects the 13 years of compliance DNA behind the project — the mindset that every security control needs evidence, not just implementation.

What BERU does:
- Assesses systems against NIST 800-53 control families
- Writes SSP narratives (System Security Plans)
- Generates POA&M entries with proper POAM IDs, responsible parties, and milestone dates
- Produces CISO-level executive summaries
- Creates evidence packages for 3PAO review

What BERU never does:
- Fixes anything (BERU is assess-only)
- Makes implementation decisions
- Claims a control is satisfied without traceable evidence

BERU reads from NIST-800-53/controls/, NIST-800-53/3POA/, CA/ (Assessment, Authorization, Monitoring), IR/ (Incident Response), SC/ (System and Communications Protection), SI/ (System and Information Integrity), and RA/ (Risk Assessment).

## RANK-AI — The Classifier (sklearn)

**Type**: scikit-learn rule-based classifier  
**Latency**: Sub-millisecond  
**Domain**: Finding severity → rank routing (E/D/C/B/S)  

RANK-AI is not a language model. It is a fast sklearn classifier with 60+ Kubernetes patterns that routes findings to the correct authority level before any LLM sees them. This prevents expensive model calls on simple pattern-match issues.

The rank system:
- **E-rank (95-100% auto)**: Pattern NPCs. No AI, no human. Pin the dependency. Set the security context. Rotate the secret.
- **D-rank (70-90% auto)**: Logged, automated. RANK-AI handles.
- **C-rank (40-70% auto)**: KATIE proposes, confidence-scored, may need approval.
- **B-rank (20-40% auto)**: Human decides. JADE provides intelligence.
- **S-rank (0-5% auto)**: Human only. JADE provides dashboards. No automation.

## Authority Chain

```
J (Human — all ranks, final authority)
  → JADE (C-rank max — DevSecOps intelligence, RAG, reasoning)
    → KATIE (C-rank max — K8s ops, classification, execution)
      → JSA Agents (E/D-rank — pattern execution, Iron Legion)
        → Iron Legion (fully automated, no reasoning)
```

The boundary between C and B rank is architectural, not aspirational. It cannot be changed without human sign-off and a documented ADR.

## RAG Knowledge Base

All three models are augmented by a ChromaDB vector database:
- 33,000+ documents across 7 collections
- Embeddings: nomic-embed-text 768-dimensional vectors via Ollama
- Collections: jade-general, jade-consulting, jade-nist-800-53, jade-terraform-iac, jade-operational
- Fed by a multi-stage pipeline: raw docs → prepare (chunk/sanitize) → ingest (embed/store)

The RAG pipeline runs locally (WSL + Ollama for embeddings) and syncs to the production Kubernetes PVC. This is the same infrastructure Sheyla uses for semantic search over the portfolio knowledge base.

## What This Means for Job Seekers and Hiring Managers

These are not demo projects. They are working systems with:
- Real training data (7,095 real JSA security findings, not synthetic benchmarks)
- Production deployment on k3s with ArgoCD GitOps
- Documented model cards, MLflow experiment tracking, champion/challenger evaluation
- Three distinct model types to discuss: 2 fine-tuned LLMs (JADE/BERU at 8B, KATIE at 3B) + 1 sklearn classifier (RANK-AI)

The AI engineering work is the practical proof of the AI engineer track. The models solve real security engineering problems.
