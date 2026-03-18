# Phase 4: Progressive Activation

Source playbook: `03-DEPLOY-RUNTIME/playbooks/06-enable-autonomous-agent.md`
Automation level: **33% autonomous (D-rank)**, 33% JADE (C-rank), 33% human (B-rank)

## The Key Concept: Progressive Trust

The agent doesn't get full authority on day 1. It earns trust through demonstrated
accuracy at each rank level before the next level is enabled.

```
Week 1:  E-rank ONLY   → Forensics capture, OOM fix, label patch, cleanup
Week 2:  E + D-rank    → ReadOnlyFS fix, ImagePull rollback, NetworkPolicy gen
Week 3+: E + D + C     → Pod isolation, pod kill, secret rotation, quarantine
```

## Step 1: Enable E-rank — D-rank (immediate)

```bash
export JSA_AUTO_APPROVE_E_RANK=true
export JSA_AUTO_APPROVE_D_RANK=false
export JSA_REQUIRE_APPROVAL_C_RANK=true
```

E-rank responses are:
- **Forensic capture** — logs, describe, yaml, events for every crash
- **OOM fix** — memory × 1.5, capped at 4Gi
- **Label patch** — add missing standard labels
- **Eviction cleanup** — delete lingering evicted pods

These are safe, reversible, well-understood. No blast radius.

Agent starts operating. Every action logged to FindingsStore + JSONL.

## Step 2: Enable D-rank — C-rank (JADE approves after 1 week)

After 1 week of E-rank operation:

```
ESCALATE to JADE:
  "E-rank has been running for ${DAYS} days."

  Activity report:
  - Auto-fixes applied: ${E_FIX_COUNT}
  - Success rate: ${E_SUCCESS_RATE}%
  - Rollbacks needed: ${E_ROLLBACK_COUNT}
  - False positives: ${E_FP_COUNT}

  D-rank would add these autonomous responses:
  - ReadOnlyFS fix (add emptyDir volumes)
  - ImagePullBackOff rollback (undo deployment)
  - Missing ConfigMap report (detect, don't fix)
  - NetworkPolicy generation (least-privilege)
  - SecurityContext patching (add nonroot, drop caps)
  - Health probe failure diagnosis
  - PSS violation reporting
  - FailedScheduling resource analysis

  JADE: if E-rank success rate >= 95%, approve D-rank activation.
```

```bash
export JSA_AUTO_APPROVE_D_RANK=true
```

## Step 3: Enable C-rank — B-rank (human approves after 2 weeks)

After 2 weeks of E+D-rank operation:

```
ESCALATE to human:
  "Ready to enable JADE-approved C-rank responses."

  Track record:
  - E-rank: ${E_DAYS} days, ${E_FIXES} fixes, ${E_RATE}% success
  - D-rank: ${D_DAYS} days, ${D_FIXES} fixes, ${D_RATE}% success

  C-rank adds (JADE must approve each instance):
  - Pod network isolation (deny-all NetworkPolicy)
  - Pod termination (kill after forensic capture)
  - Secret rotation flagging
  - Namespace quarantine (multi-pod isolation)
  - Unknown crash AI analysis

  This gives JADE authority to terminate pods and isolate namespaces.

  Options:
  1. Enable full C-rank (JADE gets isolation + kill authority)
  2. Enable C-rank for isolation only (not kill)
  3. Extend observation by 2 weeks

  Recommended: option_1 if both E+D rates >= 95%
```

## Agent Enters Daemon Mode

After activation, the agent runs the Phase 5 + Phase 6 loop continuously.

```
┌─────────────────────────────────────────────┐
│             DAEMON LOOP (24/7)              │
│                                              │
│  Ingest signals (8 sources)                  │
│    → Normalize to finding format             │
│    → Classify by rank (E/D/C/B/S)            │
│    → Route to response-playbook.yaml         │
│    → Execute response (or escalate)          │
│    → Verify response succeeded               │
│    → Generate shift-left cascade artifact    │
│    → Log to FindingsStore + JSONL            │
│                                              │
│  Every 5 min: self-health check              │
│  Every week: operations report               │
│  Every month: Falco retune                   │
└─────────────────────────────────────────────┘
```

## Phase 4 Gate

```
PASS if: E-rank active, D-rank scheduled, C-rank pending
Agent enters daemon mode.
```
