# GP-Copilot: Autonomous Security Platform

## What is GP-Copilot?

GP-Copilot is Jimmie's flagship project - an enterprise-grade AI-powered security consulting and automation platform. It runs 24/7 in a Kubernetes cluster namespace, automatically fixing security issues in Kubernetes manifests, OPA policies, and Infrastructure-as-Code without human intervention.

## Key Value Proposition

**The Problem**: Companies hire 1 DevOps Engineer expecting them to handle cloud security, code reviews, vulnerability scanning, disaster recovery, and regulatory compliance - work that typically requires 3-5 people.

**GP-Copilot Solution**: Automate junior/mid-level security work so 1 engineer can manage what would normally require 3-5 people. Replace 3-5 junior security engineers with autonomous agents running 24/7.

## JADE: The AI Brain

JADE stands for **J**unior **A**utonomous **D**evSecOps **E**ngineer. It's a specialized AI model fine-tuned on 144,245 security examples to make entry-to-mid level security decisions autonomously.

### How JADE Works:
1. **Natural Language Input**: User describes what they want ("fix the privileged container in my YAML")
2. **Decision Logic**: JADE determines severity and if auto-fix is safe
3. **Execution**: Generates and applies the fix
4. **Verification**: Re-scans to confirm the fix worked
5. **Learning**: Stores successful patterns for future use

### JADE Capabilities by Severity:
- **LOW Severity**: Auto-fix 100% (dependency updates, resource limits, naming conventions)
- **MEDIUM Severity**: Auto-fix with verification (RBAC scopes, security contexts, encryption)
- **HIGH/CRITICAL**: Escalate to human (privilege escalation, hardcoded secrets, RCE vulnerabilities)

## Core Statistics

| Metric | Value |
|--------|-------|
| Auto-Fix Success Rate | 70%+ |
| Fix Verification Accuracy | 92% |
| Time Savings | 8 hours → 15 minutes per assessment |
| Cost Savings | $120k+/year (replaces 1-2 junior engineers) |
| Security Scanners | 20+ tools |
| OPA Policies | 12 policies, 1,676 lines of Rego |
| Knowledge Base | 1,976 documents in RAG |
| Compliance Frameworks | 7 (CIS, SOC2, PCI-DSS, NIST, HIPAA, GDPR, SLSA) |

## Security Scanners (20+ Tools)

### CI/CD Application Scanners:
- **Bandit**: Python security issues
- **Semgrep**: Pattern-based code analysis (JavaScript, Python, Go, Java)
- **Gitleaks**: Hardcoded secrets and API keys

### Infrastructure/IaC Scanners:
- **Checkov**: Terraform/CloudFormation misconfigurations (400+ checks)
- **Trivy**: Container vulnerabilities + IaC scanning
- **OPA/Conftest**: Policy violations in YAML/JSON

### Cloud Runtime Monitoring:
- **AWS Config**: Continuous compliance monitoring
- **CloudTrail**: API activity logging and auditing

## Local-First Architecture (Privacy Focused)

GP-Copilot runs 100% locally with no cloud dependencies:
- **Ollama**: Local LLM inference with Qwen2.5-7B
- **ChromaDB**: Local vector database for RAG
- **SQLite**: Local findings database
- **No data sent to cloud** - HIPAA/GDPR compliant by design

Each project has its own RAG data that the LLM pulls from to make intelligent, context-aware decisions.

## Policy-as-Code with OPA

GP-Copilot enforces security through 12 OPA policies:

### Kubernetes Security (CKS-aligned):
- Deny privileged containers
- Require non-root users
- Enforce resource limits
- Require security contexts
- Mandate network policies

### AWS/Cloud Security (CIS-aligned):
- Deny public S3 buckets
- Enforce encryption at rest/transit
- Require VPC for RDS
- Enforce IMDSv2

## The Workflow

```
DISCOVERY → ANALYSIS → DECISION-MAKING → REMEDIATION → VERIFICATION → LEARNING
```

1. **Phase 1 (Scanners)**: Run all 20+ scanners in parallel
2. **Phase 2 (Analysis)**: JADE analyzes findings, scores severity
3. **Phase 3 (Remediation)**: Auto-fix what's safe, escalate what's not
4. **Phase 4 (Verification)**: Re-scan to confirm fixes
5. **Phase 5 (Learning)**: Store patterns in RAG for future

## Shadow Clone Architecture (Future Vision)

The ultimate goal is "Shadow Clone" capability - 1 engineer managing 30+ projects simultaneously through autonomous JADE clones, each with their own project-specific RAG knowledge.

## Technology Stack

- **LLM**: Qwen2.5-7B fine-tuned on 144k security examples
- **RAG**: ChromaDB with 1,976 embedded documents
- **Orchestration**: LangGraph for multi-step reasoning
- **Policies**: OPA/Gatekeeper for Kubernetes admission control
- **Deployment**: Kubernetes with 24/7 autonomous operation
- **Privacy**: 100% local, no cloud dependencies

## Key Differentiators

1. **Autonomous Operation**: Runs 24/7 without human intervention
2. **Local-First**: All processing happens on-premise, no data leaves
3. **Per-Project RAG**: Each project has dedicated knowledge for context-aware decisions
4. **Fine-Tuned Model**: Custom Qwen model trained on security-specific data
5. **Smart Escalation**: Only escalates complex issues, handles routine work automatically

## Links

- GitHub: https://github.com/jimjrxieb/Portfolio/tree/main/GP-copilot
- Full Documentation: PROJECT_SUMMARY.md in the GP-copilot directory