# PracticeMakesPerfect - Self-Training Environment

## Overview

PracticeMakesPerfect is Jimmie's immersive self-training environment that simulates working as a consultant at GuidePoint Security. Every day, Jimmie completes 10 realistic tickets covering cloud security, DevSecOps, and automation topics - the same work a Junior Cloud Security Automation Engineer would handle at a consulting firm.

## Target Role

**Company**: GuidePoint Security (federal consulting firm)
**Position**: Junior Cloud Security Automation Engineer
**Focus**: Cloud security, DevSecOps, policy-as-code, automation, compliance

## The 5 Golden Topics

Every training day covers these core competencies:

| Topic | Description | Example Tasks |
|-------|-------------|---------------|
| **Kubernetes Security** | K8s hardening, RBAC, Network Policies, Pod Security | OOMKilled troubleshooting, PodSecurityStandards, admission control |
| **Policy-as-Code** | OPA/Rego, Gatekeeper, Kyverno, Conftest | Write deny rules, ConstraintTemplates, mutation policies |
| **CI/CD Security** | GitHub Actions, pipeline hardening, SAST/DAST | Workflow reviews, secret scanning, parallel security jobs |
| **Scripting/Automation** | Python, Bash, YAML, JSON processing | Automate reports, parse scanner output, build CLI tools |
| **Compliance Mapping** | NIST, CIS, SOC2, FedRAMP, HIPAA | Map findings to controls, gap analysis, evidence collection |

## Daily Ticket Distribution

Each day generates exactly 10 tickets:

| Category | Count | Purpose |
|----------|-------|---------|
| Golden Topics | 5 | One per core competency |
| Random Domain | 2 | Exposure to broader security topics |
| Interview Prep | 3 | Technical interview questions |

## Rank Distribution (Difficulty Levels)

Tickets follow the Iron Legion rank system:

| Rank | Percentage | Difficulty | Time Estimate |
|------|------------|------------|---------------|
| **E** | 15% | Entry-level, straightforward | 5-10 min |
| **D** | 35% | Standard tasks, some complexity | 10-20 min |
| **C** | 30% | Intermediate, requires research | 15-25 min |
| **B** | 15% | Advanced, multi-step solutions | 20-30 min |
| **S** | 5% | Expert-level, architectural decisions | 25-35 min |

**Daily Time Budget**: 180 minutes total (3 hours)

## Domain Scenarios

The training covers real-world scenarios across multiple domains:

### Kubernetes
- Pod OOMKilled troubleshooting
- RBAC misconfiguration analysis
- NetworkPolicy design
- PodSecurityStandards implementation
- Container escape detection
- Ingress security hardening

### Terraform/IaC
- S3 bucket security (encryption, public access)
- IAM policy least-privilege analysis
- VPC security group reviews
- State file security
- Module security scanning

### GitHub Actions
- Workflow security reviews
- Secret management
- OIDC federation setup
- Reusable workflow patterns
- Supply chain security

### Cloud Security (AWS/Azure/GCP)
- IAM access key rotation
- CloudTrail analysis
- GuardDuty finding triage
- Security Hub remediation
- Cross-account access patterns

### Compliance
- NIST 800-53 control mapping
- CIS benchmark remediation
- SOC2 evidence collection
- FedRAMP boundary documentation
- HIPAA PHI handling

## Daily Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                    DAILY WORKFLOW                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Step 1: GET TASKS                                          │
│  └── Generate day's 10 tickets from config                  │
│                                                             │
│  Step 2: JIMMIE ANSWERS                                     │
│  └── Complete each ticket within time budget                │
│                                                             │
│  Step 3: JADE ANSWERS                                       │
│  └── JADE provides reference answers for comparison         │
│                                                             │
│  Step 4: CLAUDE VALIDATES                                   │
│  └── Claude Code scores and provides feedback               │
│                                                             │
│  Step 5: GENERATE TRAINING DATA                             │
│  └── Create fine-tuning data from session                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Example Training Day (Day 1)

A sample training day includes tickets like:

1. **Kubernetes** (D-rank, 15 min): Troubleshoot OOMKilled pods, identify memory limits
2. **Terraform** (C-rank, 20 min): Secure an S3 bucket module with encryption and access controls
3. **Policy-as-Code** (C-rank, 20 min): Write Gatekeeper ConstraintTemplate for registry allowlisting
4. **CI/CD** (D-rank, 15 min): Review GitHub Actions workflow for security improvements
5. **Compliance** (B-rank, 25 min): Create IAM key rotation runbook mapped to CIS benchmarks

## Interview Question Types

The 3 daily interview questions cover:

| Type | Examples |
|------|----------|
| **Behavioral** | "Tell me about a time you automated a security process" |
| **Technical Deep-Dive** | "Explain Kubernetes admission controllers" |
| **Scenario-Based** | "How would you respond to a compromised container?" |
| **Architecture** | "Design a multi-tenant security boundary" |
| **Tool Comparison** | "Compare Gatekeeper vs Kyverno for policy enforcement" |

## Why This Training Approach?

1. **Consulting Simulation**: Real consulting work involves varied tickets, time pressure, and client communication
2. **Breadth + Depth**: Golden topics ensure depth; random domains provide breadth
3. **Interview Ready**: Daily interview practice builds confidence and articulation
4. **Self-Assessment**: JADE comparison reveals knowledge gaps
5. **Training Data Generation**: Sessions become fine-tuning data for JADE improvement

## Integration with GP-Copilot

PracticeMakesPerfect feeds into the broader GP-Copilot ecosystem:

- **JADE Supervisor** learns from Jimmie's validated responses
- **JSA Agents** get improved through training data
- **Rank Classifier** calibrates on real task difficulty assessments
- **Defense Playbooks** incorporate lessons learned

## Key Metrics

| Metric | Value |
|--------|-------|
| Daily tickets | 10 |
| Golden topics | 5 |
| Time budget | 180 minutes |
| Interview questions | 3 per day |
| Rank distribution | E(15%), D(35%), C(30%), B(15%), S(5%) |
