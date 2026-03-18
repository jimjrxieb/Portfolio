# Phase 1: Autonomous Baseline Scan

Source playbook: `01-APP-SEC/playbooks/01-baseline-scan.md`
Automation level: **100% autonomous (E-rank)**

## What the Agent Does

```
1. Detect project stack (languages, frameworks, CI, Docker, K8s)
2. Select relevant scanners based on stack
3. Run all scanners → JSON output
4. Triage: deduplicate, group by severity
5. Classify each finding by rank (E/D/C/B/S)
6. Persist to FindingsStore
7. Generate baseline report
```

## Step-by-Step

### 1. Project Profile Detection

```bash
# Auto-detect stack if .gp-project.yaml doesn't exist
python3 project_profile.py --target ${TARGET_REPO} --output ${TARGET_REPO}/.gp-project.yaml
```

Profile determines which scanners to run:
- Python detected → Bandit, Semgrep
- JavaScript detected → ESLint (if installed)
- Docker detected → Hadolint, Trivy image
- K8s manifests detected → Checkov, Kubescape, Polaris, Conftest
- Any language → Gitleaks, Trivy-fs, Grype

### 2. Run Scanners

```bash
01-APP-SEC/tools/run-all-scanners.sh \
  --target ${TARGET_REPO} \
  --label baseline \
  --output ${OUTPUT_DIR}/baseline \
  --parallel
```

Expected outputs per scanner:
| Scanner | Output File | What It Finds |
|---------|------------|---------------|
| Gitleaks | `gitleaks.json` | Hardcoded secrets, API keys |
| Bandit | `bandit.json` | Python SAST (B-codes) |
| Semgrep | `semgrep.json` | Multi-language SAST |
| Trivy-fs | `trivy-fs.json` | Dependency CVEs |
| Grype | `grype.json` | Dependency CVEs (second opinion) |
| Hadolint | `hadolint.json` | Dockerfile linting |
| Checkov | `checkov.json` | IaC + K8s misconfigs |
| Kubescape | `kubescape.json` | K8s security benchmarks |
| Polaris | `polaris.json` | K8s best practices |
| Conftest | `conftest.json` | OPA policy violations |

### 3. Triage

```bash
python3 01-APP-SEC/tools/triage.py \
  --scan-dir ${OUTPUT_DIR}/baseline \
  --project ${PROJECT_ID}
```

Triage produces:
- `REMEDIATION-PLAN.md` — Human-readable fix plan
- `findings-by-severity.json` — Machine-readable, deduplicated

### 4. Rank Classification

```python
from shared.ranking.rank_classifier import RankClassifier

classifier = RankClassifier()
ranked = classifier.classify_batch(findings_path)
# Output: findings-ranked.json with rank field (E/D/C/B/S) per finding
```

### 5. Persist

```python
from shared.findings_store import FindingsStore

store = FindingsStore()
store.bulk_upsert(ranked_findings, agent="jsa-devsec", status="detected")
```

### 6. Gate Decision

```
IF findings_count == 0:
  Log "Clean scan — no findings"
  Skip to Phase 3 (still deploy CI + configs for prevention)
ELSE:
  Log "Found {count} findings: {E}E {D}D {C}C {B}B {S}S"
  Continue to Phase 2
```

## Failure Modes

| Failure | Action |
|---------|--------|
| Scanner binary missing | Skip scanner, log warning, continue |
| Scanner timeout (>2 min per scanner) | Kill, log timeout, continue |
| Scanner crashes | Log stderr, continue with others |
| Triage fails | Fallback: use raw scanner output, skip dedup |
| All scanners fail | Abort engagement, report tool installation needed |

## Outputs

```
${OUTPUT_DIR}/baseline/
├── gitleaks.json
├── bandit.json
├── semgrep.json
├── trivy-fs.json
├── grype.json
├── hadolint.json
├── checkov.json
├── kubescape.json (if K8s detected)
├── polaris.json (if K8s detected)
├── conftest.json (if K8s detected)
├── SUMMARY.md
├── REMEDIATION-PLAN.md
├── findings-by-severity.json
├── findings-ranked.json
└── BASELINE-REPORT.md
```
