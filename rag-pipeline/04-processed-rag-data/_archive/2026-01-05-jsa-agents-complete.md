# JSA Agents - Complete Overview (January 2026)

## What is JSA?

JSA (JADE Secure Agent) is the autonomous security worker system in GP-Copilot. The Iron Legion consists of specialized agents that execute security scans, apply fixes, and deploy defense policies 24/7 without human intervention for low-risk (E/D rank) issues.

## The Iron Legion Hierarchy

```
JIMMIE (Human)     - Principal / Architect (A-S rank authority)
    |
Claude Code        - Operator (B rank, builds everything)
    |
JADE               - Supervisor (C rank authority ceiling)
    |
JSA Agents         - Workers (E-D rank autonomous execution)
    ├── jsa-devsec    (DevSecOps - 24/7 daemon)
    ├── jsa-infrasec  (Infrastructure Security - 117 modules)
    └── jsa-secops    (SecOps - planned)
```

## JSA Agent Variants

### jsa-devsec (DevSecOps Agent)
**Focus**: Application security scanning and CI/CD pipeline integration

**Key Features**:
- 24/7 daemon mode watching GitHub Actions webhooks
- LogBrain normalizes scanner outputs to unified format
- EventProcessor routes findings by rank (E/D/C/B/S)
- PlaybookExecutor auto-deploys D-rank defense policies

**8 Scanners**:
- Gitleaks (secrets detection)
- Bandit (Python SAST)
- Semgrep (multi-language SAST)
- Trivy (container/dependency scanning)
- ESLint (JavaScript security)
- Hadolint (Dockerfile linting)
- Checkov (IaC security)
- Safety (Python dependency CVEs)

**Commands**:
```bash
# 24/7 daemon with GHA monitoring
python3 src/main.py daemon --instance 02-instance --slot slot-3 --watch-gha jimjrxieb/Portfolio

# One-shot scan
python3 src/main.py scan --target /path/to/repo -v
```

### jsa-infrasec (Infrastructure Security Agent)
**Focus**: Kubernetes, Cloud, IaC, Policy, Secrets, and Compliance

**Key Features**:
- 117 modules across 6 security domains
- K8sGPT-style AnalyzerResult/Failure model
- DomainLoader for dynamic module loading
- BlastRadiusAnalyzer assesses fix impact before applying

**6 Security Domains**:

| Domain | Prefix | Analyzers | Fixers | Scanners |
|--------|--------|-----------|--------|----------|
| Kubernetes | k8s_ | 15+ | 12+ | trivy, kubescape, polaris |
| Cloud (AWS) | cloud_ | 9 | 4 | prowler, checkov |
| IaC | iac_ | 5 | 5 | tfsec, checkov |
| Policy | policy_ | 6 | 6 | conftest, opa |
| Secrets | secrets_ | 3 | 3 | gitleaks |
| Compliance | compliance_ | 8 | - | CIS, NIST, SOC2 mappings |

**Commands**:
```bash
# K8s deployment
helm upgrade --install jsa-infrasec charts/jsa-infrasec -n jsa-infrasec

# Check logs
kubectl logs -n jsa-infrasec deployment/jsa-infrasec -f
```

### jsa-secops (SecOps Agent) - Planned
**Focus**: Runtime security monitoring and incident response

**Planned Capabilities**:
- Falco runtime threat detection
- GuardDuty integration
- CloudTrail monitoring
- B/S-rank incident response automation

## How JSA Works

### Rank-Based Decision Routing

| Rank | Automation | Handler | Example Findings |
|------|------------|---------|------------------|
| **E** | 100% auto | JSA auto-fix | Hardcoded secrets, formatting issues |
| **D** | 70-90% auto | JSA + defense playbook | CVEs, missing policies, basic misconfigs |
| **C** | 40-70% | JADE approval | Config changes, multi-file edits |
| **B** | 20-40% | Human + JADE | Architecture decisions |
| **S** | 0-5% | Human only | Compliance sign-off, strategy |

### Defense Playbooks (D-Rank Auto-Deploy)

When jsa-devsec detects D-rank issues, it automatically deploys defensive policies:

| Finding Type | Playbook | Deployed Asset |
|--------------|----------|----------------|
| hardcoded-secret | block-secrets | Gatekeeper constraint |
| privileged-container | require-nonroot | Kyverno policy |
| missing-network-policy | default-deny | NetworkPolicy |
| no-resource-limits | require-limits | Gatekeeper mutation |

### Agent Loop Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     JSA-DEVSEC DAEMON                           │
├─────────────────────────────────────────────────────────────────┤
│   GHA Webhook    Scanner Dir    Manual CLI                      │
│   Watcher        Watcher        Trigger                         │
│       └──────────────┼──────────────┘                           │
│                      ▼                                          │
│                  LogBrain (normalizer)                          │
│                      ▼                                          │
│               EventProcessor (rank routing)                     │
│                      │                                          │
│     ┌────────────────┼────────────────┐                         │
│     ▼                ▼                ▼                         │
│  E/D Rank        C Rank           B/S Rank                      │
│  Auto-Fix        → JADE           Escalate                      │
│     │                │                                          │
│     ▼                ▼                                          │
│  Playbook        Approval                                       │
│  Executor        Queue                                          │
└─────────────────────────────────────────────────────────────────┘
```

## JADE - The Supervisor

JADE (JADE AI Decision Engine) is the C-rank supervisor that:
- Reviews C-rank findings from JSA agents
- Generates fix proposals
- Executes defense playbooks
- Has a hard authority ceiling at C-rank (cannot auto-approve B/S)

**Key Components**:
- LogBrain: Normalizes scanner outputs
- RankClassifier: ML-powered finding classification (sklearn + XGBoost)
- PlaybookExecutor: Deploys defense policies
- FeedbackLogger: Records decisions for learning (725+ historical entries)

## Resolution Types

| Type | When Used |
|------|-----------|
| **FIXED** | Code changed to remediate |
| **ACCEPTED_RISK** | Won't fix, documented why |
| **STALE** | Code no longer exists |
| **SKIP_INTENTIONAL** | Test fixture, archive |
| **ESCALATED** | Needs human expert |

## File Structure

```
GP-BEDROCK-AGENTS/
├── jsa-devsec/
│   └── src/
│       ├── main.py              # CLI entry point
│       ├── daemon.py            # 24/7 mode
│       ├── agent.py             # Core agent logic
│       ├── event_processor.py   # Rank routing + playbooks
│       └── fixers/              # Code fixers

├── jsa-infrasec/
│   └── src/
│       ├── main.py              # CLI entry point
│       ├── agent.py             # 1700+ lines, main agent
│       ├── domain_loader.py     # Dynamic module loading
│       ├── analyzers/           # 40+ K8sGPT-style analyzers
│       ├── fixers/              # 30+ domain fixers
│       ├── watchers/            # Event watchers
│       └── scanners/            # Scanner integrations

├── shared/
│   ├── ranking/
│   │   └── rank_classifier.py   # ML classification
│   ├── supervisor/
│   │   ├── jade_supervisor.py   # JADE logic
│   │   └── playbook_executor.py # Defense deployment
│   └── feedback/
│       └── feedback_logger.py   # Decision logging

└── charts/
    ├── jsa-devsec/              # Helm chart
    └── jsa-infrasec/            # Helm chart
```

## Platform Metrics

| Metric | Value |
|--------|-------|
| jsa-infrasec modules | 117 |
| jsa-infrasec lines | ~28,000 |
| Historical decisions | 725+ |
| Scanners integrated | 12 |
| Defense playbooks | 8 |

## What Makes JSA Special

1. **Truly Autonomous for Low-Risk**: E/D rank issues fixed 24/7 without human intervention
2. **Defense-First**: D-rank findings auto-trigger protective policies
3. **Rank-Based Intelligence**: Knows when to fix vs escalate vs block
4. **Comprehensive Coverage**: 117 modules across all security domains
5. **Learning Loop**: JADE improves from 725+ historical decisions
6. **K8sGPT-Style Analysis**: Structured AnalyzerResult/Failure model for consistent output
