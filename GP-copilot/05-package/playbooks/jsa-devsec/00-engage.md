# Playbook 00: Full Autonomous Engagement

Master playbook. The agent reads this to execute a complete 01-APP-SEC engagement
from scan to deploy with zero human intervention on E/D-rank work.

## Inputs

| Variable | Source | Example |
|----------|--------|---------|
| `TARGET_REPO` | CLI arg or daemon config | `/home/jimmie/GP-PROJECTS/01-instance/slot-3/client-repo` |
| `PROJECT_ID` | Derived from repo name | `client-repo` |
| `OUTPUT_DIR` | `GP-S3/5-consulting-reports/${INSTANCE}/${SLOT}` | Standard report path |
| `INSTANCE` | CLI arg | `01-instance` |
| `SLOT` | CLI arg | `slot-3` |

## Execution Flow

```
START
  │
  ├─ Prerequisites check (scanners installed, repo exists)
  │   └─ FAIL → abort with missing tool list
  │
  ├─ Auto-detect project stack → .gp-project.yaml
  │
  ├─► PHASE 1: SCAN (playbooks/01-scan.md)
  │   ├─ Run all relevant scanners
  │   ├─ Triage + dedup
  │   ├─ Classify by rank
  │   ├─ Persist to FindingsStore
  │   └─ GATE: findings > 0? → Phase 2. Clean? → Skip to Phase 3.
  │
  ├─► PHASE 2: FIX (playbooks/02-fix.md)
  │   ├─ Execute all E/D-rank fixers (secrets, deps, SAST, Docker, web, K8s, supply chain)
  │   ├─ C-rank → queue for JADE approval
  │   ├─ B-rank → queue for human (agent continues other work)
  │   ├─ Verify each fix (re-run scanner on fixed file)
  │   └─ GATE: all D-rank fixes applied? → Phase 3. Failures? → retry once, then escalate.
  │
  ├─► PHASE 3: HARDEN (playbooks/03-harden.md)
  │   ├─ Deploy CI security pipeline
  │   ├─ Deploy scanner configs + allowlists
  │   ├─ Harden GHA (pin SHAs, least-privilege, block dangerous patterns)
  │   ├─ Deploy OPA/Conftest policy gate
  │   ├─ Deploy pre-commit hooks
  │   └─ GATE: CI + configs + conftest pass? → Phase 4.
  │
  ├─► PHASE 4: VERIFY (playbooks/04-verify.md)
  │   ├─ Full rescan with post-fix label
  │   ├─ Compare baseline vs post-fix
  │   ├─ Update FindingsStore with verification
  │   ├─ Generate cascade prevention policies → /tmp/jsa-cascade/
  │   └─ GATE: fix_rate >= 70%? → Phase 5. Below? → escalate with analysis.
  │
  ├─► PHASE 5: DEPLOY (playbooks/05-deploy.md) [optional, K8s only]
  │   ├─ Validate cluster access (check ArgoCD ownership!)
  │   ├─ Helm lint + template + scan rendered YAML
  │   ├─ Dry-run → install
  │   ├─ Verify pods + security posture
  │   └─ Smoke test (JADE C-rank)
  │
  └─ COMPLETION
      ├─ Generate ENGAGEMENT-SUMMARY.md
      ├─ Log to JSONL audit trail
      ├─ Update FindingsStore final status
      └─ Notify human of pending B-rank decisions
```

## Rank Distribution Across Phases

| Phase | E-rank | D-rank | C-rank | B-rank |
|-------|--------|--------|--------|--------|
| 1 Scan | 4 steps | 1 step | — | — |
| 2 Fix | 2 steps | 19 steps | 4 steps | 8 steps |
| 3 Harden | 4 steps | 7 steps | 3 steps | 1 step |
| 4 Verify | 3 steps | 2 steps | — | 1 step |
| 5 Deploy | — | 6 steps | 1 step | 1 step |
| **Total** | **13** | **35** | **8** | **11** |

**Autonomous (E+D): 48/67 steps = 72%**
**With JADE (E+D+C): 56/67 steps = 84%**
**Human required (B): 11/67 steps = 16%**

## Error Handling

1. **Scanner fails**: Skip that scanner, log warning, continue with others
2. **Fixer fails**: Rollback file change, log failure, try next finding
3. **Fixer fails twice on same file**: Escalate to C-rank (JADE reviews)
4. **JADE timeout (5 min)**: Escalate to human
5. **Deploy fails**: Capture diagnostics, escalate to human, do NOT retry blind
6. **Any step modifies files outside TARGET_REPO**: ABORT immediately

## Guardrails

- **Never modify GP-CONSULTING source files.** Read-only reference.
- **Never auto-approve B-rank.** Park and continue.
- **Never force-push.** History rewrites require human confirmation.
- **Never skip verification.** Every fix gets a re-scan.
- **Never deploy to ArgoCD-managed namespaces.** Check ownership first.
- **Always log to FindingsStore AND JSONL.** Dual audit trail.
- **Always generate cascade artifacts.** Prevention > detection.
