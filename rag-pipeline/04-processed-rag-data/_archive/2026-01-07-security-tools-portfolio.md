# Security Tools Used in Portfolio: How Jimmie Uses Each Tool

## Overview

This document explains each security tool used in Jimmie's Portfolio project and specifically HOW it's configured and used - not just what the tool does generally.

---

## Static Application Security Testing (SAST)

### Bandit

**What it is:** Python static analysis tool for security issues

**How Jimmie uses it in Portfolio:**
- Runs in GitHub Actions CI pipeline on every push
- Configured with `--severity-level medium` to catch medium+ issues
- Scans the entire `api/` directory (FastAPI backend)
- Fails the build if ANY security issue is found

**Example findings Bandit catches:**
- B102: exec used (dangerous)
- B307: eval used (dangerous)
- B602: subprocess with shell=True
- B608: SQL injection via string formatting

**Portfolio config:**
```yaml
- name: Run Bandit
  run: bandit -r api/ --severity-level medium -f json -o bandit-results.json
```

### Semgrep

**What it is:** Pattern-matching security scanner supporting 30+ languages

**How Jimmie uses it in Portfolio:**
- Uses the `p/security-audit` ruleset for comprehensive coverage
- Scans both Python (api/) and TypeScript (ui/) code
- Configured to fail on HIGH severity findings only
- Results uploaded to GitHub Security tab

**What Semgrep catches in this project:**
- React XSS vulnerabilities in JSX
- SQL injection patterns in Python
- Insecure deserialization
- Path traversal vulnerabilities
- Hardcoded credentials

**Portfolio config:**
```yaml
- name: Run Semgrep
  uses: returntocorp/semgrep-action@v1
  with:
    config: p/security-audit
```

---

## Software Composition Analysis (SCA) / Dependency Scanning

### Trivy

**What it is:** All-in-one security scanner for containers, filesystems, git repos

**How Jimmie uses it in Portfolio:**
- **Filesystem scan**: Checks Python requirements.txt and package.json for CVEs
- **Image scan**: Scans built Docker images before pushing to registry
- Configured to fail on HIGH and CRITICAL vulnerabilities
- Generates SARIF output for GitHub Security integration

**Portfolio config:**
```yaml
# Filesystem scan
- name: Run Trivy FS Scan
  run: trivy fs . --severity HIGH,CRITICAL --exit-code 1

# Image scan
- name: Run Trivy Image Scan
  run: trivy image ghcr.io/jimjrxieb/portfolio-api:${{ github.sha }} --severity HIGH,CRITICAL
```

**What Trivy catches:**
- CVEs in Python packages (e.g., Pillow, urllib3, requests)
- CVEs in npm packages
- Vulnerable base image components
- Misconfigurations in IaC files

### Snyk

**What it is:** Commercial vulnerability scanner with fix recommendations

**How Jimmie uses it in Portfolio:**
- Integrated as GitHub App for automatic PR checks
- Provides specific upgrade commands to fix vulnerabilities
- Monitors dependencies continuously (not just at build time)
- Creates automatic fix PRs for vulnerable dependencies

**Why both Trivy AND Snyk?**
- Trivy is fast and catches most issues
- Snyk provides better fix recommendations and continuous monitoring
- Defense in depth - if one misses something, the other catches it

### npm audit

**What it is:** Built-in npm security scanner

**How Jimmie uses it in Portfolio:**
- Runs in CI before building the React frontend
- Uses `npm audit --audit-level=high` to fail on high+ severity
- Part of the standard `npm ci` workflow

---

## Infrastructure as Code (IaC) Security

### Checkov

**What it is:** Policy-as-code scanner for Terraform, Kubernetes, Dockerfiles, CloudFormation

**How Jimmie uses it in Portfolio:**
- Scans all Kubernetes manifests in `infrastructure/`
- Scans Dockerfiles for security best practices
- Uses default CIS benchmark rules
- Fails build on any failed check

**Specific Checkov checks fixed in Portfolio:**

| Check ID | What it checks | How Jimmie fixed it |
|----------|----------------|---------------------|
| CKV_K8S_22 | readOnlyRootFilesystem | Added `securityContext.readOnlyRootFilesystem: true` |
| CKV_K8S_40 | High UID | Set `runAsUser: 10001` |
| CKV_K8S_43 | Image digest | Pinned images to `@sha256:...` |
| CKV_K8S_8 | Liveness probe | Added liveness probes to all deployments |
| CKV_K8S_9 | Readiness probe | Added readiness probes |
| CKV_K8S_28 | Drop capabilities | Added `drop: [ALL]` to capabilities |
| CKV_K8S_37 | NET_RAW capability | Dropped NET_RAW explicitly |
| CKV_K8S_38 | Service account token | Disabled automount where not needed |

**Portfolio config:**
```yaml
- name: Run Checkov
  uses: bridgecrewio/checkov-action@v12
  with:
    directory: infrastructure/
    framework: kubernetes,dockerfile
    quiet: true
```

### Kubescape

**What it is:** Kubernetes security scanner based on NSA/CISA and CIS benchmarks

**How Jimmie uses it in Portfolio:**
- Runs NSA-CISA framework by default
- Scans live cluster and manifest files
- Provides remediation guidance
- Used as secondary validation after Checkov

**What Kubescape catches:**
- Privileged containers
- Host namespace sharing
- Missing network policies
- Weak RBAC configurations
- Missing resource limits

### Conftest

**What it is:** OPA-based policy testing tool

**How Jimmie uses it in Portfolio:**
- Uses custom Rego policies for organization-specific rules
- Validates Kubernetes manifests against custom policies
- Checks for required labels, annotations, security contexts

**Example custom policy:**
```rego
# Deny containers without security context
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.securityContext
  msg := sprintf("Container %s missing securityContext", [container.name])
}
```

---

## Container Security

### Hadolint

**What it is:** Dockerfile linter

**How Jimmie uses it in Portfolio:**
- Runs on all Dockerfiles in the repo
- Enforces best practices like pinned versions, no curl|bash
- Configured to fail on warning level or higher

**What Hadolint catches:**
- DL3007: Using :latest tag
- DL3008: Not pinning apt package versions
- DL3009: Deleting apt lists after install
- DL4006: Set SHELL for piped commands
- SC2086: Double quote to prevent globbing

---

## Secret Detection

### Gitleaks

**What it is:** Secret scanner for git repos

**How Jimmie uses it in Portfolio:**
- Runs in pre-commit hook (local)
- Runs in CI pipeline (backup)
- Scans entire git history for leaked secrets
- Uses custom config to reduce false positives

**What Gitleaks catches:**
- API keys (AWS, GCP, Azure)
- Database connection strings
- JWT secrets
- Private keys
- OAuth tokens

**Portfolio config:**
```yaml
- name: Run Gitleaks
  uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### detect-secrets

**What it is:** Entropy-based secret detection

**How Jimmie uses it in Portfolio:**
- Additional layer beyond Gitleaks
- Uses entropy analysis to find high-randomness strings
- Maintains a `.secrets.baseline` file to track known false positives

---

## JSA Agents and NPCs

Jimmie built custom security automation tools as part of GP-Copilot:

### What are NPCs?

**NPCs (Non-Player Characters)** are deterministic tool wrappers:
- They wrap security tools (Trivy, Bandit, etc.)
- They normalize output to a common format
- They DON'T make decisions - just run tools

**Example NPC:**
```python
from npcs import TrivyNPC

scanner = TrivyNPC()
results = scanner.run(target="/path/to/project")
# Returns normalized findings
```

### What are JSA Agents?

**JSA (JADE Secure Agent)** variants are AI-powered security agents:

| Agent | Purpose | Deployment |
|-------|---------|------------|
| jsa-ci | CI/CD pipeline security | GitHub Actions + CLI |
| jsa-devsecops | Kubernetes runtime security | In-cluster (Helm) |
| jsa-secops (GRIGENT) | Log analysis and threat detection | CLI + Container |

### How JSA-CI Works in Portfolio

1. Scans detect issues using NPCs (Bandit, Trivy, etc.)
2. Findings are classified by rank (E through S)
3. E/D rank: Auto-fix if possible
4. C rank: Request approval via Slack
5. B/S rank: Escalate to human immediately

### The E-S Ranking System

| Rank | Automation Level | Example |
|------|------------------|---------|
| E | 95-100% auto-fix | Missing .gitignore entry |
| D | 70-90% auto-fix | Dependency CVE with clear upgrade path |
| C | 40-70% needs approval | Multi-file IaC changes |
| B | 20-40% human required | Architecture decisions |
| S | 0-5% immediate escalation | Active breach detected |

---

## CIS Benchmarks

**What is CIS?** Center for Internet Security - provides security configuration benchmarks.

**How Jimmie uses CIS:**
- Checkov includes CIS Kubernetes Benchmark checks
- Kubescape runs NSA-CISA framework (based on CIS)
- Docker images follow CIS Docker Benchmark guidelines

**Key CIS controls implemented:**
- 1.1.1: Ensure API server pod specification file ownership
- 4.1.1: Ensure that the cluster-admin role is only used where required
- 5.1.1: Ensure that the cluster-admin role is only used where required
- 5.2.2: Minimize the admission of privileged containers
- 5.2.3: Minimize the admission of containers wishing to share the host process ID namespace

---

## Summary: The Complete CI/CD Security Pipeline

```
git push
    │
    ▼
┌───────────────────────────────────────────────────┐
│            GITHUB ACTIONS CI PIPELINE              │
├───────────────────────────────────────────────────┤
│                                                    │
│  1. SECRET DETECTION                               │
│     └─ Gitleaks (blocks if secrets found)          │
│                                                    │
│  2. SAST (Static Analysis)                         │
│     ├─ Bandit (Python)                             │
│     └─ Semgrep (multi-language)                    │
│                                                    │
│  3. DEPENDENCY SCANNING                            │
│     ├─ Trivy filesystem scan                       │
│     ├─ Snyk (continuous monitoring)                │
│     └─ npm audit                                   │
│                                                    │
│  4. IAC SECURITY                                   │
│     ├─ Checkov (K8s, Dockerfile)                   │
│     ├─ Kubescape (CIS benchmark)                   │
│     └─ Conftest (custom policies)                  │
│                                                    │
│  5. CONTAINER BUILD                                │
│     ├─ Hadolint (Dockerfile lint)                  │
│     ├─ Docker build                                │
│     └─ Trivy image scan                            │
│                                                    │
│  6. DEPLOY (if all pass)                           │
│     └─ kubectl apply to k3s cluster                │
│                                                    │
└───────────────────────────────────────────────────┘
```

Every tool has a specific job, and together they form a comprehensive security gate.
