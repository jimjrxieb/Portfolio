# Playbook 00: Full Autonomous Runtime Engagement

Master playbook. Two modes: **engagement** (deploy the stack) then **daemon** (run forever).

## The Difference

jsa-devsec and jsa-infrasec run engagements with a start and end.
jsa-monitor runs an engagement to DEPLOY, then becomes a **24/7 daemon**.

```
ENGAGEMENT (one-time)          DAEMON (forever)
Phase 1: Deploy stack          Phase 5: 24/7 detect→respond loop
Phase 2: Configure detection   Phase 6: Shift-left cascade
Phase 3: Deploy observability
Phase 4: Progressive activation
```

## Execution Flow

```
START
  │
  ├─ Prerequisites (cluster, helm, 02-CLUSTER-HARDENING ideally done)
  │
  ├─► PHASE 1: DEPLOY (playbooks/01-deploy.md)
  │   ├─ Install prerequisites
  │   ├─ Deploy Falco (DaemonSet) + exporter
  │   ├─ Load 65 custom Falco rules (MITRE-tagged)
  │   ├─ Verify Falco producing events
  │   └─ Run 15-point container hardening audit
  │
  ├─► PHASE 2: DETECT (playbooks/02-detect.md)
  │   ├─ Collect Falco baseline (24h)
  │   ├─ Generate + apply allowlist (JADE C-rank)
  │   ├─ Deploy Fluent Bit + log backend (JADE C-rank: Loki vs ES)
  │   ├─ Start 8 watchers (events, drift, secrets, network, PSS, policy, supply chain, dataplane)
  │   └─ Verify end-to-end log pipeline
  │
  ├─► PHASE 3: OBSERVE (playbooks/03-observe.md)
  │   ├─ Deploy Prometheus + Alertmanager (if not present)
  │   ├─ Deploy Grafana (if not present)
  │   ├─ Import 6 dashboards (runtime, Falco, JADE, response, logs, tracing)
  │   ├─ Deploy 30 alert rules
  │   └─ Optional: OTel Collector + tracing backend
  │
  ├─► PHASE 4: ACTIVATE (playbooks/04-activate.md)
  │   ├─ Enable E-rank (immediate) — forensics, OOM fix, label patch
  │   ├─ Enable D-rank (after 1 week) — ReadOnlyFS, ImagePull, NetworkPolicy, SecurityContext
  │   ├─ Enable C-rank (after 2 weeks, B-rank human approval)
  │   └─ Agent enters daemon mode
  │
  ├─► PHASE 5: OPERATE (playbooks/05-operate.md) [DAEMON — runs forever]
  │   ├─ Ingest → Classify → Respond → Verify (continuous loop)
  │   ├─ Weekly operations report
  │   ├─ Monthly Falco tuning
  │   ├─ 5-minute self-health check
  │   └─ SLO tracking (MTTD, MTTF, false positive rate)
  │
  └─► PHASE 6: SHIFT-LEFT (playbooks/06-shift-left.md) [DAEMON — runs forever]
      ├─ Every response → prevention artifact for jsa-devsec + jsa-infrasec
      ├─ Cascade failure detection (same issue at both layers)
      └─ Shift-left effectiveness metrics

ENGAGEMENT COMPLETE → DAEMON RUNNING
```

## The Log Universe (What jsa-monitor Sees)

```
SOURCE                 │ SIGNAL TYPE          │ AUTO-FIX POTENTIAL
───────────────────────┼──────────────────────┼────────────────────
Falco syscall alerts   │ Threat detection     │ C-rank (isolate/kill)
K8s events             │ Health/crash         │ E/D-rank (OOM, crash fixes)
Pod stdout/stderr      │ Application errors   │ D-rank (ReadOnlyFS, config)
K8s audit logs         │ RBAC/API activity    │ B-rank (human reviews)
Prometheus metrics     │ Threshold breach     │ D-rank (auto-scale hints)
Admission violations   │ Policy drift         │ D-rank (report)
Network flows          │ Traffic anomalies    │ C-rank (isolate)
Config drift           │ State mismatch       │ D-rank (flag for git fix)
```

## Rank Distribution

| Rank | % of Events | Response SLO | Examples |
|------|------------|-------------|----------|
| E    | 40%        | <30 sec     | Forensic capture, OOM fix, eviction cleanup |
| D    | 25%        | <2 min      | ReadOnlyFS fix, ImagePull rollback, NetworkPolicy gen |
| C    | 15%        | <5 min      | Pod isolation, pod kill, secret rotation |
| B    | 15%        | <30 min     | Lateral movement, persistence, cascade failure |
| S    | 5%         | IMMEDIATE   | Active exfil, supply chain compromise, node compromise |

## Guardrails

- **Evidence first, action second.** Always capture forensics before any response.
- **Progressive activation.** E-rank day 1. D-rank week 2. C-rank week 3+ (human approves).
- **Never suppress CRITICAL Falco alerts.** Tune the rule, don't silence it.
- **Never auto-kill production pods without JADE approval.** C-rank minimum.
- **Never destroy evidence.** Even when killing a pod, capture logs/describe/yaml first.
- **ArgoCD rule still applies.** Runtime patches on ArgoCD-managed resources → fix in git.
- **Shift-left EVERYTHING.** Every runtime fix generates prevention for earlier stages.
