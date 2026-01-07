# JSA Agents - Complete Overview

## What is JSA?

JSA (JADE Secure Agent) is the autonomous security worker system in GP-Copilot. While JADE is the brain making decisions, JSA agents are the hands doing the work - they execute security scans, apply fixes, and report results 24/7 without human intervention.

## The Iron Legion Analogy

In the Iron Man analogy:
- JADE = Tony Stark (the decision maker)
- JSA agents = Iron Legion (autonomous drones executing missions)

JSA agents are deployed as Kubernetes pods that continuously monitor, scan, and remediate security issues across target projects.

## JSA Agent Variants

### jsa-ci (CI/CD Security Agent)
**Focus**: Application security in CI/CD pipelines

**Responsibilities**:
- SAST (Static Application Security Testing)
- Secrets detection in code
- Dependency vulnerability scanning
- Code quality enforcement

**Scanners Used**:
- Gitleaks (secrets)
- Bandit (Python SAST)
- Semgrep (multi-language SAST)
- ESLint (JavaScript security)
- Hadolint (Dockerfile linting)
- Trivy, Grype, Snyk (dependencies)

**Workload**: ~30% of security automation tasks

### jsa-devsecops (DevSecOps Agent)
**Focus**: Infrastructure and runtime security

**Responsibilities**:
- Kubernetes security posture
- Infrastructure as Code scanning
- Runtime security monitoring
- Compliance enforcement

**Scanners Used**:
- Kubescape (K8s security)
- Polaris (K8s best practices)
- Kube-bench (CIS benchmarks)
- Checkov (Terraform/CloudFormation)
- tfsec (Terraform security)
- Conftest (OPA policy testing)
- Prowler (AWS security)

**Workload**: ~70% of security automation tasks

## How JSA Works

### The 24/7 Autonomous Loop

```
ScanOrchestrator → RankClassifier → Decision Router
    (14 NPCs)       (JADE-powered)

         ┌────────────────┬─────────────────┬──────────────┐
         ▼                ▼                 ▼
   ┌──────────────┐ ┌──────────────┐ ┌─────────────────┐
   │ E-D Rank     │ │ C Rank       │ │ B-S Rank        │
   │ AUTO-FIX     │ │ SLACK APPROVE│ │ ESCALATE        │
   │              │ │              │ │                 │
   │ FixOrchestrator │ Approve=Fix  │ │ Human Review    │
   │ (8 Fixer NPCs)  │ Deny=Escalate│ │ + Context       │
   └──────────────┘ └──────────────┘ └─────────────────┘
```

### Rank-Based Decision Routing

| Rank | Automation Level | Action | Example |
|------|------------------|--------|---------|
| **E** | 95-100% | Auto-fix immediately | Hardcoded secrets, missing resource limits |
| **D** | 70-90% | Auto-fix with logging | SQL injection, XSS, dependency CVEs |
| **C** | 40-70% | Slack approval required | Network policies, multi-file IaC changes |
| **B** | 20-40% | Escalate to human | Architecture changes, compliance gaps |
| **S** | 0-5% | Escalate immediately | Org-wide policy, incident response |

## NPCs (Non-Player Characters)

JSA uses NPCs as its tools. NPCs are deterministic wrappers around security tools - they don't make decisions, they just run tools and normalize output.

### Scanner NPCs (14 total)
- **Secrets**: GitleaksNPC
- **SAST**: BanditNPC, SemgrepNPC, EslintNPC
- **Dependencies**: TrivyNPC, GrypeNPC, SnykNPC
- **Kubernetes**: KubescapeNPC, PolarisNPC, KubeBenchNPC
- **IaC**: CheckovNPC, TfsecNPC, ConftestNPC
- **Quality**: HadolintNPC

### Fixer NPCs (7 total)
- SecretsFixerNPC
- CodeFixerNPC
- DependencyFixerNPC
- KubernetesFixerNPC
- CIFixerNPC
- ConftestFixerNPC
- GHAFixerNPC

## JSA Deployment

JSA agents run as Kubernetes deployments with Helm charts:

```bash
# Deploy jsa-ci
helm upgrade --install jsa-ci ./charts/jsa-ci -n portfolio

# Deploy jsa-devsecops
helm upgrade --install jsa-devsecops ./charts/jsa-devsecops -n portfolio
```

Each agent includes:
- Main agent pod (continuous scanning loop)
- Health report CronJob (daily status reports)
- Log sync CronJob (sync logs to central storage)

## Target Slots

JSA organizes work into "slots" - each slot is a project being monitored:

```
GP-PROJECTS/
├── 01-instance/
│   ├── slot-1/kubernetes-goat/  # K8s security training
│   └── slot-2/DEFENSE-project/  # Defense project
└── 02-instance/
    └── slot-3/Portfolio/        # This portfolio site
```

Logs are stored per-slot in `target-slot-logs/`.

## What Makes JSA Special

1. **Truly Autonomous**: Runs 24/7 without human intervention
2. **Rank-Based Intelligence**: Knows when to fix vs escalate
3. **Comprehensive Coverage**: 14 scanners across all security domains
4. **Audit Trail**: Every action is logged for compliance
5. **Learning Loop**: Successful fixes become JADE training data
