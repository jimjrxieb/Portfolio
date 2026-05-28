# CBBP Methodology — The Engagement Framework

## What CBBP Is

CBBP is the core engagement methodology: **Comply → Build → Break → Prove**.

Every security engagement, whether against an internal application, a Kubernetes cluster, or an external client environment, follows the same four-phase progression. No exceptions. The phases map directly to the NIST Risk Management Framework (RMF) and produce auditor-ready artifacts at each step.

CBBP is not a product. It is a methodology with tooling behind it. Every piece of automation started as a senior engineer running commands by hand, documenting what worked, and then encoding that into something repeatable. Human point of view first. Always.

## The Four Phases

### 00-COMPLY — Before You Touch Anything

Comply means: discover, inventory, and assess maturity before touching anything. You do not harden what you have not mapped. You do not remediate what you have not measured.

The temptation is to jump straight to fixing. Resist it. A senior engineer walks the environment first.

What COMPLY produces:
- System Security Plan (SSP) — what controls are in place, what is the system boundary
- Control gap analysis — what is missing or partial against the target framework
- NIST 800-53 control mappings — which controls apply to this system
- Governance playbooks — the rules of engagement for this engagement

COMPLY covers the "Compliance" C in the 5 C's framework.

### 01-BUILD — Make It Secure

Build means: harden, remediate, and enforce policy-as-code. Fix what is broken. Prevent what should never have been allowed. Make the guardrails automatic so the next team that deploys cannot regress what you just fixed.

What BUILD produces:
- Infrastructure as code (Terraform, Helm charts, Kubernetes manifests) — the hardened state, version-controlled
- CI/CD pipeline configuration — security scanning baked into the delivery pipeline
- Policy-as-code (Kyverno, Gatekeeper OPA, Conftest) — admission control that blocks non-compliant workloads
- Remediation artifacts — exactly what was changed, when, by whom

BUILD covers Code, Container, and Cluster from the 5 C's.

### 02-BREAK — Find What Was Missed

Break means: adversarial validation. After hardening, attack the system to find what the build phase missed. Security without adversarial validation is wishful thinking.

What BREAK produces:
- SAST output (Semgrep, Bandit) — source code vulnerabilities
- Secret scanning (Gitleaks, detect-secrets) — leaked credentials and tokens
- Container scanning (Trivy, Grype) — CVEs in images and base layers
- Kubernetes benchmarking (kube-bench, Kubescape, Polaris) — cluster misconfigurations
- IaC scanning (Checkov, Tfsec, Terrascan) — cloud configuration flaws
- Dynamic application security testing (DAST) — runtime behavior

BREAK drives the CySA+ skill set — adversarial thinking, understanding attack paths, validating that controls actually work.

### 03-PROVE — Evidence Package

Prove means: every engagement ends with auditor-ready proof. Not a slide deck. Not "we fixed it." A traceable chain of custody from finding to remediation to validation.

What PROVE produces:
- Security Assessment Report (SAR) — formal finding report
- Plan of Action and Milestones (POA&M) — open items with owners and due dates
- CISO executive summary — business-language risk summary
- Nightshift handoff — what the next analyst needs to know to continue
- Evidence package — all raw scanner JSON, timestamps, run IDs, analyst attribution

The audit trail standard requires every finding to have a unique POAM ID, every fix to have an applied_by record, and every validation to reference the run ID that confirmed closure.

## CBBP Agents

Each phase has a dedicated AI agent:

- **Comply Engineer** — reads SSP templates, control cards, framework maps; produces governance artifacts
- **Build Engineer** — reads IaC, CI/CD configs, K8s manifests; hardens and enforces policy-as-code
- **Break Engineer** — reads scanner outputs, CVE databases, attack patterns; validates security controls
- **Prove Engineer** — reads all phase outputs; produces SAR, POA&M, CISO report, evidence packages

Agents are platform-agnostic. They run as Claude Code subagents today and are forward-compatible with CrewAI for autonomous operation tomorrow.

## NIST RMF Mapping

| CBBP Phase | NIST RMF Step | Activity |
|---|---|---|
| COMPLY | Categorize + Select | System boundary, control selection, SSP |
| BUILD | Implement | Controls deployed, policy-as-code enforced |
| BREAK | Assess | Security control assessment, adversarial validation |
| PROVE | Authorize + Monitor | SAR, POA&M, ongoing monitoring |

## GP-S3 Output Structure

Every engagement's artifacts land in a structured directory:

```
GP-S3/engagements/<bucket>/<target>/<run-id>/
  00-comply/     SSP sections, control mappings, gap analysis
  01-build/      IaC, CI/CD configs, implementation diffs
  02-break/      Scanner JSONs, attack-sim outputs, validation procedures
  03-prove/      SAR, POA&M, CISO summary, nightshift handoff, evidence packages
  memory/        poam-registry.jsonl, audit-runs.jsonl, remediation-log.jsonl
  MANIFEST.md    Target, git SHA, date, scope
```

The memory/ directory is machine-readable audit trail — the 3PAO-ready evidence chain.

## The Non-Negotiable Rules

1. Never harden what you have not mapped (COMPLY before BUILD).
2. Never stop at BUILD — adversarial validation (BREAK) is required.
3. Never call an engagement done without a PROVE package.
4. Every finding has a POAM ID. Every fix has an applied_by. Every validation has a run ID.
5. Fix in git. Never kubectl patch ArgoCD-managed resources. The config in git IS the system state.
