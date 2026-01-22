# JADE + JSA Quick Reference

> Updated: January 2026 | Iron Legion v1.0

## The Analogy
- **JADE** = Team Lead (C-rank authority, approves/denies)
- **Claude Code** = Operator (B-rank, builds everything)
- **JSA Agents** = Workers (E/D-rank autonomous execution)

## Agent Capabilities

| Agent | Capabilities | Where It Runs |
|-------|-------------|---------------|
| **jsa-devsec** | 8 scanners, GHA webhooks, defense playbooks, 24/7 daemon | Local CLI, K8s, GHA |
| **jsa-infrasec** | 117 modules, K8sGPT analyzers, 6 domains, blast radius | K8s cluster |
| **jsa-secops** | Runtime monitoring, incident response | K8s (planned) |
| **JADE** | C-rank approvals, fix generation, playbook execution | Local via shared/ |

## JSA-DEVSEC Details

**Scanners:** gitleaks, bandit, semgrep, trivy, eslint, hadolint, checkov, safety

**Modes:**
- `daemon` - 24/7 monitoring with GHA webhooks
- `scan` - One-shot repository scan
- `autonomous` - K8s deployment mode

**Key Features:**
- LogBrain normalizes scanner outputs
- EventProcessor routes findings by rank
- PlaybookExecutor deploys D-rank defenses automatically

## JSA-INFRASEC Details

**Domains (117 modules):**
| Domain | Analyzers | Fixers | Scanners |
|--------|-----------|--------|----------|
| Kubernetes | 15+ | 12+ | trivy, kubescape |
| Cloud (AWS) | 9 | 4 | prowler, checkov |
| IaC | 5 | 5 | tfsec, checkov |
| Policy | 6 | 6 | conftest, opa |
| Secrets | 3 | 3 | gitleaks |
| Compliance | 8 | - | CIS/NIST/SOC2 |

**Key Features:**
- DomainLoader dynamically loads all components
- BlastRadiusAnalyzer assesses fix impact
- K8sGPT-style AnalyzerResult/Failure model

## Rank System

| Rank | Auto-Fix? | Who Handles | Example |
|------|-----------|-------------|---------|
| **E** | 100% auto | JSA | Hardcoded secrets, formatting |
| **D** | 70-90% auto | JSA + logging | Dependency CVEs, defense policies |
| **C** | Approval needed | JADE | Config changes, multi-file edits |
| **B** | Human review | Claude Code | Architecture decisions |
| **S** | Human only | Jimmie | Compliance sign-off, strategy |

## Resolution Types

| Type | When Used |
|------|-----------|
| **FIXED** | Code changed to remediate |
| **ACCEPTED_RISK** | Won't fix, documented why |
| **STALE** | Code no longer exists |
| **SKIP_INTENTIONAL** | Test fixture, archive |
| **ESCALATED** | Needs human expert |

## Key Paths

```
GP-BEDROCK-AGENTS/
├── jsa-devsec/src/           # DevSecOps agent (daemon mode)
├── jsa-infrasec/src/         # Infrastructure agent (117 modules)
│   ├── analyzers/            # K8sGPT-style analyzers
│   ├── fixers/               # Domain-specific fixers
│   ├── watchers/             # Event watchers
│   └── domain_loader.py      # Dynamic module loading
├── shared/
│   ├── ranking/              # RankClassifier
│   ├── supervisor/           # PlaybookExecutor
│   └── feedback/             # Decision logging
└── charts/                   # Helm charts

GP-PROJECTS/{instance}/{slot}/jsa/
├── inbox/          # New findings
├── resolved/       # Fixed findings
└── escalated/      # B/S-rank for humans
```

## Quick Commands

```bash
# jsa-devsec daemon (24/7)
python3 src/main.py daemon --instance 02-instance --slot slot-3 --watch-gha jimjrxieb/Portfolio

# jsa-devsec one-shot scan
python3 src/main.py scan --target /path/to/repo -v

# jsa-infrasec in K8s
helm upgrade --install jsa-infrasec charts/jsa-infrasec -n jsa-infrasec

# Check findings
ls GP-PROJECTS/02-instance/slot-3/jsa/inbox/

# View logs
kubectl logs -n jsa-infrasec deployment/jsa-infrasec -f
```

## Defense Playbooks

D-rank findings auto-trigger playbooks:
- `hardcoded-secret` → Gatekeeper constraint
- `missing-network-policy` → NetworkPolicy template
- `privileged-container` → Pod Security mutation

C-rank playbooks require JADE approval before deployment.

## Workflow

```
Scanner outputs → jsa-devsec/infrasec → RankClassifier
                                              │
        ┌─────────────────────────────────────┼─────────────────────┐
        ▼                                     ▼                     ▼
   E/D: Auto-fix                        C: JADE review         B/S: Escalate
   + deploy defense                     + approval UI          to human
        │                                     │
        ▼                                     ▼
   PlaybookExecutor                    Fix applied on approve
   deploys policy                      → resolved/
```
