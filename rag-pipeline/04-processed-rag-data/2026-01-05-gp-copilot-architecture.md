# GP-Copilot - Complete Architecture

## What is GP-Copilot?

GP-Copilot is an AI-powered security automation platform built by Jimmie Coleman. It combines:
- **JADE**: An offline 7B LLM fine-tuned for security
- **JSA Agents**: Autonomous security workers
- **14+ Scanner NPCs**: Security tool integrations
- **Policy-as-Code**: OPA, Gatekeeper, Kyverno enforcement

The mission: Automate security engineering tasks from E-Rank (basic) to S-Rank (expert) so humans can focus on architecture and strategy.

## Architecture Overview

```
GP-copilot/
├── JADE-AI/              # JADE Core (the brain)
├── GP-BEDROCK-AGENTS/    # JSA Agents (the workers)
├── GP-CONSULTING/        # Security Toolkit (5 phases)
├── GP-SAGEMAKER/         # JADE Training Pipeline
├── GP-OPENSEARCH/        # RAG Pipeline
├── GP-GUI/               # Web Dashboard
├── GP-INFRA/             # Infrastructure configs
└── GP-PROJECTS/          # Target projects
```

## The Five Phases of Security Consulting

GP-Copilot follows a structured security consulting methodology:

### Phase 1: Security Assessment
Scan everything with 14 scanner NPCs:
- Secrets detection (Gitleaks)
- SAST (Bandit, Semgrep)
- SCA (Trivy, Grype, Snyk)
- Kubernetes (Kubescape, Polaris, Kube-bench)
- IaC (Checkov, tfsec, Conftest)

### Phase 2: Application Security Fixes
Fixer NPCs remediate findings:
- Remove hardcoded secrets
- Fix SQL injection, XSS
- Upgrade vulnerable dependencies
- Patch insecure configurations

### Phase 3: Hardening
JSA Core + compliance enforcement:
- Apply Pod Security Standards
- Implement NetworkPolicies
- Configure RBAC properly
- Enable audit logging

### Phase 4: Cloud Migration
Infrastructure modernization:
- LocalStack for local development
- Terraform for IaC
- Kubernetes deployment automation

### Phase 5: Compliance Audit
Framework mapping:
- SOC2 controls
- PCI-DSS requirements
- HIPAA safeguards

## Key Components Explained

### JADE-AI (The Brain)
Location: `JADE-AI/`

JADE is a fine-tuned Qwen2.5-Coder-7B model that:
- Analyzes security findings
- Recommends fixes
- Classifies finding severity
- Generates remediation code

Current version: v0.9 (85% benchmark score)

### JSA Agents (The Workers)
Location: `GP-BEDROCK-AGENTS/`

Two agent variants:
- **jsa-ci**: CI/CD pipeline security
- **jsa-devsecops**: Infrastructure security

Run 24/7 as Kubernetes pods, autonomously scanning and fixing.

### GP-CONSULTING (The Toolkit)
Location: `GP-CONSULTING/`

Organized by phase:
- `1-Security-Assessment/`: Scanner NPCs
- `2-App-Sec-Fixes/`: Fixer NPCs
- `3-Hardening/`: JSA Core engine
- `4-Cloud-Migration/`: Terraform/LocalStack
- `5-Compliance-Audit/`: Framework mapping

### GP-SAGEMAKER (Training Pipeline)
Location: `GP-SAGEMAKER/`

JADE training infrastructure:
- Data processing (GP-GLUE)
- Model versions (jade-v0.4 through v0.9)
- Evaluation benchmarks (GP-CLARIFY)

### GP-OPENSEARCH (RAG Pipeline)
Location: `GP-OPENSEARCH/`

Knowledge base for JADE:
- Document ingestion
- ChromaDB vector storage
- Semantic search for context

### GP-GUI (Dashboard)
Location: `GP-GUI/`

Web interface showing:
- JSA agent status
- Pending approvals
- Escalation queue
- JADE explanations

## Technology Stack

### Core Technologies
- **Python**: Primary language
- **Kubernetes**: Deployment platform
- **Terraform**: Infrastructure as Code
- **Helm**: K8s package management
- **ChromaDB**: Vector database
- **Ollama**: Local LLM inference

### AI/ML Stack
- **Base Model**: Qwen2.5-Coder-7B
- **Fine-tuning**: LoRA adapters
- **Embeddings**: nomic-embed-text
- **Inference**: Ollama (local)

### Security Tools
- 14 scanner integrations
- 7 fixer NPCs
- OPA/Rego policies
- Gatekeeper constraints
- Kyverno policies

## Why GP-Copilot Matters

1. **Reduces Manual Work**: Automates 70%+ of routine security tasks
2. **24/7 Coverage**: JSA agents never sleep
3. **Consistent Quality**: Same checks every time
4. **Learning System**: Gets better with each fix
5. **Cost Effective**: Runs on local hardware (no API costs)
6. **Air-Gap Capable**: Works offline for sensitive environments
