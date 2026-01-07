# JADE AI - Complete Overview

## What is JADE?

JADE (name derived from the gemstone, symbolizing wisdom and protection) is an offline 7B parameter Large Language Model fine-tuned specifically for cloud security and DevSecOps tasks. JADE is the "brain" of GP-Copilot - the AI that makes security decisions, analyzes vulnerabilities, and guides remediation.

## The Tony Stark Analogy

Think of it like Iron Man:
- **Tony Stark** = JADE (the AI doing the work, making security decisions)
- **Jarvis** = Claude Code (orchestrating, providing context, refining JADE's capabilities)
- **Iron Legion** = JSA agents (autonomous workers executing the fixes)

JADE is Tony Stark - the genius making the calls. Claude Code helps train and improve JADE over time.

## JADE Model Versions

JADE is continuously improved through incremental fine-tuning:

| Version | Training Focus | Benchmark Score |
|---------|----------------|-----------------|
| v0.4 | Security fundamentals (291k examples) | 58% |
| v0.5 | OPA/Rego + refinements | 60% |
| v0.6 | Hallucination fixes (PSS, Kyverno, Gatekeeper) | 62.6% |
| v0.7 | General training data refresh | 63% |
| v0.8 | Log diagnosis & structured responses | 65% |
| v0.9 | Agentic tool use, conversational mode | 85% |

**Current Version: JADE v0.9** - The latest version with agentic capabilities, tested on Portfolio K8s security hardening.

## What JADE Can Do

### E-D Rank Tasks (Highly Automated)
- Run security scans (Gitleaks, Bandit, Trivy, Checkov)
- Detect hardcoded secrets
- Identify pod status issues
- Apply pre-written security manifests
- Basic vulnerability analysis

### C-B Rank Tasks (Assisted Automation)
- Build CI/CD security pipelines
- Implement OPA Gatekeeper/Kyverno policies
- Debug complex Kubernetes cluster issues
- Coordinate multi-tool vulnerability remediation
- Generate security fix recommendations

### A-S Rank Tasks (Human-Guided)
- Define organization-wide security guardrails
- Design zero-trust architecture
- Build policy-as-code governance frameworks
- Lead incident response

## How JADE Works

1. **Receives Task**: User or JSA agent presents a security task
2. **Analyzes Context**: JADE uses RAG to retrieve relevant security knowledge
3. **Reasons Through Problem**: Applies security domain expertise
4. **Recommends Actions**: Suggests specific fixes with reasoning
5. **Learns from Outcomes**: Successful fixes become training data

## JADE's Training Pipeline

JADE is fine-tuned from Qwen2.5-Coder-7B using:
- **Base Model**: Qwen2.5-Coder-7B-Instruct
- **Method**: LoRA (Low-Rank Adaptation)
- **Data**: Security-specific examples from real operations
- **Format**: Alpaca/ChatML instruction format

Training happens in GP-SAGEMAKER:
```
GP-SAGEMAKER/
├── 1-GP-GLUE/           # Data processing
├── 3-jade-model-versions/ # Model artifacts
└── 4-GP-CLARIFY/        # Evaluation
```

## JADE's Personality

JADE is designed to be:
- **Direct**: Gets to the point quickly
- **Technical**: Speaks in security engineering terms
- **Confident**: Makes clear recommendations
- **Humble**: Acknowledges when escalation is needed
- **Educational**: Explains the "why" behind security decisions

## Running JADE

```bash
cd JADE-AI
python3 jade.py
```

JADE runs locally using Ollama, requiring no external API calls for inference. This makes it suitable for air-gapped or security-sensitive environments.
