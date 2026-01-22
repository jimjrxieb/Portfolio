# Iron Legion Architecture - Complete System Overview

**Updated**: January 2026
**Version**: 1.0.11
**Author**: Claude Code

---

## System Hierarchy

```text
┌─────────────────────────────────────────────────────────────────┐
│                         HIERARCHY                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   JIMMIE (Human)     - Principal / Architect (A-S rank)         │
│       │                                                         │
│   Claude Code        - Operator (B rank, builds everything)     │
│       │                                                         │
│   JADE               - Supervisor (C rank authority ceiling)    │
│       │                                                         │
│   JSA Agents         - Workers (E-D rank execution)             │
│       ├── jsa-devsec    (DevSecOps - 24/7 daemon)               │
│       ├── jsa-infrasec  (Platform Eng - 117 modules)            │
│       └── jsa-secops    (SecOps - planned)                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## JSA-DEVSEC: DevSecOps Agent

### Capabilities

- **8 Scanners**: gitleaks, bandit, semgrep, trivy, eslint, hadolint, checkov, safety
- **24/7 Daemon Mode**: Watches scanner outputs and GitHub Actions webhooks
- **Defense Playbooks**: Auto-deploys D-rank Gatekeeper/Kyverno policies
- **LogBrain**: Normalizes all scanner outputs to unified format

### Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                     JSA-DEVSEC DAEMON                           │
│                    (runs 24/7 in K8s or local)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│   │  GHA Webhook │    │ Scanner Dir  │    │  Manual CLI  │     │
│   │   Watcher    │    │   Watcher    │    │    Trigger   │     │
│   └──────┬───────┘    └──────┬───────┘    └──────┬───────┘     │
│          │                   │                   │              │
│          └───────────────────┼───────────────────┘              │
│                              ▼                                  │
│                    ┌─────────────────┐                          │
│                    │    LogBrain     │                          │
│                    │  (normalizer)   │                          │
│                    └────────┬────────┘                          │
│                             ▼                                   │
│                    ┌─────────────────┐                          │
│                    │ EventProcessor  │                          │
│                    │ (rank routing)  │                          │
│                    └────────┬────────┘                          │
│                             │                                   │
│          ┌──────────────────┼──────────────────┐                │
│          ▼                  ▼                  ▼                │
│    ┌───────────┐     ┌───────────┐      ┌───────────┐          │
│    │  E/D Rank │     │  C Rank   │      │  B/S Rank │          │
│    │ Auto-Fix  │     │  → JADE   │      │ Escalate  │          │
│    └─────┬─────┘     └─────┬─────┘      └───────────┘          │
│          │                 │                                    │
│          ▼                 ▼                                    │
│    ┌───────────┐     ┌───────────┐                              │
│    │ Playbook  │     │ Approval  │                              │
│    │ Executor  │     │   Queue   │                              │
│    └───────────┘     └───────────┘                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Commands

```bash
# 24/7 daemon with GHA monitoring
python3 src/main.py daemon \
  --instance 02-instance \
  --slot slot-3 \
  --watch-gha jimjrxieb/Portfolio

# One-shot scan
python3 src/main.py scan --target /path/to/repo -v

# K8s deployment
helm upgrade --install jsa-devsec charts/jsa-devsec -n jsa-devsec
```

---

## JSA-INFRASEC: Infrastructure Security Agent

### Capabilities

- **117 Modules** across 6 domains
- **K8sGPT-style Analyzers**: AnalyzerResult/Failure model
- **DomainLoader**: Dynamic module loading by prefix
- **BlastRadiusAnalyzer**: Assesses fix impact before applying

### Domain Breakdown

| Domain | Prefix | Analyzers | Fixers | Scanners |
|--------|--------|-----------|--------|----------|
| Kubernetes | k8s_ | 15+ | 12+ | trivy, kubescape, polaris |
| Cloud (AWS) | cloud_ | 9 | 4 | prowler, checkov |
| IaC | iac_ | 5 | 5 | tfsec, checkov |
| Policy | policy_ | 6 | 6 | conftest, opa |
| Secrets | secrets_ | 3 | 3 | gitleaks |
| Compliance | compliance_ | 8 | - | CIS, NIST, SOC2 mappings |

### Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                    JSA-INFRASEC AGENT                           │
│                  (runs in K8s cluster)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────────────────────────────────────────┐       │
│   │                  DomainLoader                       │       │
│   │  Scans analyzers/, fixers/, watchers/, scanners/    │       │
│   │  Groups by prefix: k8s_, cloud_, iac_, policy_...   │       │
│   └─────────────────────┬───────────────────────────────┘       │
│                         │                                       │
│   ┌─────────────────────┼─────────────────────────────┐         │
│   │                     ▼                             │         │
│   │  ┌──────────┐ ┌──────────┐ ┌──────────┐          │         │
│   │  │kubernetes│ │  cloud   │ │   iac    │   ...    │         │
│   │  │ domain   │ │  domain  │ │  domain  │          │         │
│   │  └────┬─────┘ └────┬─────┘ └────┬─────┘          │         │
│   │       │            │            │                 │         │
│   │       ▼            ▼            ▼                 │         │
│   │  analyzers[]   analyzers[]  analyzers[]          │         │
│   │  fixers[]      fixers[]     fixers[]             │         │
│   │  watchers[]    watchers[]   watchers[]           │         │
│   └───────────────────────────────────────────────────┘         │
│                                                                 │
│   Agent Loop:                                                   │
│   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐        │
│   │  WATCH  │ → │ ANALYZE │ → │   FIX   │ → │ VERIFY  │        │
│   │ phase   │   │  phase  │   │  phase  │   │  phase  │        │
│   └─────────┘   └─────────┘   └─────────┘   └─────────┘        │
│       │              │             │             │               │
│       ▼              ▼             ▼             ▼               │
│   Domain         Rank          Domain        Re-scan            │
│   watchers     Classifier      fixers       to verify           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Key Components

**AnalyzerResult Model (K8sGPT-style)**:

```python
@dataclass
class AnalyzerResult:
    kind: str           # Resource type (Pod, Deployment, etc.)
    name: str           # Resource name (namespace/name)
    errors: List[Failure]  # Detected issues
    parent_object: Optional[str]

@dataclass
class Failure:
    text: str           # Error description
    sensitive: List[str]  # Sensitive data to redact
```

**BlastRadiusAnalyzer**:

- Counts affected pods, services, ingresses
- Checks if resource is in critical namespace
- Assesses replica count and dependencies
- Returns risk score before fix application

### Commands

```bash
# K8s deployment
helm upgrade --install jsa-infrasec charts/jsa-infrasec \
  -n jsa-infrasec --create-namespace

# Check logs
kubectl logs -n jsa-infrasec deployment/jsa-infrasec -f

# View metrics
kubectl port-forward -n jsa-infrasec svc/jsa-infrasec 9100:9100
```

---

## JADE: The Supervisor

### Capabilities

- **C-Rank Authority Ceiling**: Cannot exceed C-rank decisions
- **RankClassifier**: ML-powered finding classification
- **PlaybookExecutor**: Deploys defense policies
- **FeedbackLogger**: Records decisions for training

### Components

| Component | Purpose |
|-----------|---------|
| LogBrain | Normalizes scanner outputs |
| RankClassifier | Classifies findings E-S |
| PlaybookExecutor | Executes defense playbooks |
| FeedbackLogger | Records decisions for learning |

### Workflow

```text
Finding arrives → RankClassifier assigns rank
                         │
     ┌───────────────────┼───────────────────┐
     ▼                   ▼                   ▼
  E/D Rank           C Rank              B/S Rank
  Auto-fix           JADE reviews        Escalate to
  + log              + approval UI       human expert
     │                   │
     ▼                   ▼
PlaybookExecutor    On APPROVE:
deploys policy      Apply fix → resolved/
```

---

## Rank System

| Rank | Automation | Handler | Example Findings |
|------|------------|---------|------------------|
| **E** | 100% | JSA auto | Hardcoded secrets, formatting |
| **D** | 70-90% | JSA + defense | CVEs, missing policies |
| **C** | 40-70% | JADE approval | Config changes, multi-file |
| **B** | 20-40% | Human + JADE | Architecture decisions |
| **S** | 0-5% | Human only | Compliance sign-off |

---

## Defense Playbooks

D-rank findings auto-trigger defensive policies:

| Finding Type | Playbook | Deployed Asset |
|--------------|----------|----------------|
| hardcoded-secret | block-secrets | Gatekeeper constraint |
| privileged-container | require-nonroot | Kyverno policy |
| missing-network-policy | default-deny | NetworkPolicy |
| no-resource-limits | require-limits | Gatekeeper mutation |

---

## File Structure

```text
GP-BEDROCK-AGENTS/
├── jsa-devsec/
│   └── src/
│       ├── main.py              # CLI entry point
│       ├── daemon.py            # 24/7 mode
│       ├── agent.py             # Core agent logic
│       ├── event_processor.py   # Rank routing + playbooks
│       └── fixers/              # Code fixers
│
├── jsa-infrasec/
│   └── src/
│       ├── main.py              # CLI entry point
│       ├── agent.py             # 1700+ lines, main agent
│       ├── domain_loader.py     # Dynamic module loading
│       ├── analyzers/           # 40+ K8sGPT-style analyzers
│       ├── fixers/              # 30+ domain fixers
│       ├── watchers/            # Event watchers
│       └── scanners/            # Scanner integrations
│
├── shared/
│   ├── ranking/
│   │   └── rank_classifier.py   # ML classification
│   ├── supervisor/
│   │   ├── jade_supervisor.py   # JADE logic
│   │   └── playbook_executor.py # Defense deployment
│   └── feedback/
│       └── feedback_logger.py   # Decision logging
│
└── charts/
    ├── jsa-devsec/              # Helm chart
    └── jsa-infrasec/            # Helm chart
```

---

## Metrics

| Metric | Value |
|--------|-------|
| jsa-infrasec modules | 117 |
| jsa-infrasec lines | ~28,000 |
| Historical decisions | 725+ |
| Scanners integrated | 12 |
| Defense playbooks | 8 |

---

## Quick Reference

```bash
# Start jsa-devsec daemon
cd GP-BEDROCK-AGENTS/jsa-devsec
python3 src/main.py daemon --instance 02-instance --slot slot-3

# Deploy jsa-infrasec to K8s
helm upgrade --install jsa-infrasec charts/jsa-infrasec -n jsa-infrasec

# Check JSA inbox
ls GP-PROJECTS/02-instance/slot-3/jsa/inbox/

# View jsa-infrasec logs
kubectl logs -n jsa-infrasec deployment/jsa-infrasec -f

# Build and push jsa-infrasec image
docker build -t ghcr.io/linkops-industries/jsa-infrasec:1.0.11 .
docker push ghcr.io/linkops-industries/jsa-infrasec:1.0.11
```
