# Phase 5: 24/7 Operations (Daemon Mode)

Source playbook: `03-DEPLOY-RUNTIME/playbooks/07-operations.md`
**This phase runs forever.** It IS the autonomous agent.

## The Loop

```
EVERY EVENT (continuous):
  1. INGEST  — signal arrives from any of 8 sources
  2. NORMALIZE — convert to standard finding format
  3. CLASSIFY — rank (E/D/C/B/S) via RankClassifier
  4. RESPOND  — execute from response-playbook.yaml
  5. VERIFY   — confirm response worked
  6. CASCADE  — generate shift-left prevention artifact
  7. LOG      — FindingsStore + JSONL audit trail

EVERY 5 MINUTES:
  Agent self-health check (watchers alive, Falco producing, store writable)

EVERY WEEK:
  Operations report (findings, fixes, escalations, MTTD, MTTF)

EVERY MONTH:
  Falco retune (new allowlist candidates from observation)
```

## Signal Processing Pipeline

```
                    ┌─────────────┐
                    │ Falco gRPC  │ ──┐
                    └─────────────┘   │
                    ┌─────────────┐   │
                    │ K8s Events  │ ──┤
                    └─────────────┘   │
                    ┌─────────────┐   │     ┌───────────┐     ┌──────────┐
                    │ Pod Logs    │ ──┤────→│ NORMALIZE │────→│ CLASSIFY │
                    └─────────────┘   │     └───────────┘     └────┬─────┘
                    ┌─────────────┐   │                            │
                    │ Audit Logs  │ ──┤                     ┌──────┴──────┐
                    └─────────────┘   │                     │             │
                    ┌─────────────┐   │               ┌─────▼─────┐ ┌────▼─────┐
                    │ Prometheus  │ ──┤               │ AUTO-FIX  │ │ ESCALATE │
                    └─────────────┘   │               │ (E/D)     │ │ (C/B/S)  │
                    ┌─────────────┐   │               └─────┬─────┘ └────┬─────┘
                    │ Admission   │ ──┤                     │            │
                    └─────────────┘   │               ┌─────▼─────┐     │
                    ┌─────────────┐   │               │  VERIFY   │     │
                    │ Network     │ ──┤               └─────┬─────┘     │
                    └─────────────┘   │                     │            │
                    ┌─────────────┐   │               ┌─────▼────────────▼────┐
                    │ Drift       │ ──┘               │    SHIFT-LEFT CASCADE  │
                    └─────────────┘                   └───────────────────────┘
```

## Auto-Fix Decision Tree

When a signal arrives, the agent follows this tree:

```
Is it a CRASH? (CrashLoopBackOff, Error, OOMKilled)
  ├─ OOMKilled?
  │   └─ E-rank: memory × 1.5 (cap 4Gi)
  ├─ Read-only filesystem?
  │   └─ D-rank: add emptyDir volumes for blocked paths
  ├─ ImagePullBackOff?
  │   └─ D-rank: rollback to previous image
  ├─ Missing ConfigMap/Secret?
  │   └─ D-rank: report (don't fabricate)
  ├─ Health probe failure?
  │   └─ D-rank: diagnose (wrong path? slow start?)
  └─ Unknown crash?
      └─ C-rank: JADE analyzes logs

Is it a SECURITY THREAT? (Falco alert)
  ├─ MITRE: Execution/Discovery?
  │   └─ E-rank: capture forensics, log
  ├─ MITRE: Collection/Initial Access?
  │   └─ D-rank: capture + alert
  ├─ MITRE: Priv Escalation/Persistence/Evasion/Creds/Exfil?
  │   └─ C-rank: JADE decides (isolate, kill, rotate)
  ├─ MITRE: Lateral Movement/Impact?
  │   └─ B-rank: human decides
  └─ Active exfiltration / supply chain / node compromise?
      └─ S-rank: PAGE IMMEDIATELY

Is it a DRIFT? (config changed outside git)
  ├─ ArgoCD-managed?
  │   └─ D-rank: ArgoCD self-heals (just log)
  ├─ Security-relevant (securityContext, NetworkPolicy, PSS)?
  │   └─ D-rank: flag for git fix
  └─ Non-security (labels, annotations)?
      └─ E-rank: log, no action

Is it a POLICY VIOLATION? (admission audit mode)
  └─ D-rank: log violation, track trend
      If violation persists > 7 days → escalate to B-rank

Is it a METRIC BREACH? (Prometheus alert)
  ├─ FalcoSilent?
  │   └─ D-rank: restart Falco DaemonSet, verify events resume
  ├─ WatcherDown?
  │   └─ D-rank: restart watcher, verify signal flow
  ├─ AutoFixFailureRateHigh?
  │   └─ B-rank: something is wrong with fix logic, human reviews
  └─ ErrorRateSpike?
      └─ D-rank: correlate with recent deployments
```

## SLO Tracking

| Metric | Target | How Measured |
|--------|--------|-------------|
| MTTD (Mean Time to Detect) | <60 seconds | Signal timestamp → finding created |
| MTTF (Mean Time to Fix) | <5 minutes (E/D) | Finding created → fix verified |
| Auto-Fix Success Rate | >95% (E), >90% (D) | Verified fixes / attempted fixes |
| False Positive Rate | <10% | Suppressed findings / total findings |
| Cascade Coverage | >80% | Verified fixes with shift-left artifact |
| Watcher Uptime | >99% | Watcher heartbeat every 5 min |

## Weekly Report

Generated every Monday, delivered to `${OUTPUT_DIR}/weekly/`:

```markdown
# Weekly Runtime Operations — ${WEEK_START} to ${WEEK_END}

## Summary
| Metric | This Week | Last Week | Trend |
|--------|-----------|-----------|-------|
| Findings detected | ${DETECTED} | ${PREV_DETECTED} | ${TREND} |
| E-rank auto-fixed | ${E_FIXES} | ${PREV_E} | |
| D-rank auto-fixed | ${D_FIXES} | ${PREV_D} | |
| C-rank JADE-approved | ${C_FIXES} | ${PREV_C} | |
| B-rank escalated | ${B_ESC} | ${PREV_B} | |
| S-rank alerts | ${S_ALERTS} | ${PREV_S} | |
| MTTD (avg) | ${MTTD}s | ${PREV_MTTD}s | |
| MTTF (avg) | ${MTTF}s | ${PREV_MTTF}s | |
| Shift-left artifacts | ${CASCADE} | ${PREV_CASCADE} | |

## Top Triggered Rules
${TOP_10_RULES}

## Cascade Failures (prevention gaps)
${CASCADE_FAILURES}
```

## Monthly Tuning

```bash
# Collect last 30 days of alert patterns
03-DEPLOY-RUNTIME/tools/tune-falco.sh --retune

# New allowlist candidates → JADE reviews (C-rank)
# Updated rule priorities based on frequency + impact
```
