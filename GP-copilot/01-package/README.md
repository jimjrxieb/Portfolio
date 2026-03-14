# 01-APP-SEC — Pre-Deploy Application Security

Scans code, dependencies, Dockerfiles, and CI pipelines before anything ships.

## Structure

```
golden-techdoc/   → Engagement guides, scanner capabilities, decision trees
playbooks/        → Step-by-step runbooks for scan → triage → fix workflows
outputs/          → Sample scan results and triage reports
summaries/        → Package overview and engagement summaries
```

## What This Package Does

- Runs 8 parallel security scanners (Semgrep, Bandit, Trivy, gitleaks, Checkov, hadolint, Safety, npm audit)
- Auto-triages findings by severity with fixer scripts for Dockerfiles, Python, and web vulnerabilities
- Integrates into GitHub Actions CI as a blocking gate
