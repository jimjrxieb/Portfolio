# 05-JSA-AUTONOMOUS — Autonomous Agent Fleet

> **"Four agents. Zero overnight engineers. The platform runs itself."**

---

## How 05-JSA-AUTONOMOUS Saves Money

Companies pay **$150-250K/year per security engineer**. Most of that engineer's time goes to E/D rank grunt work: running scanners, patching known CVEs, fixing manifest misconfigs, responding to alerts that have a known playbook. That's toil — high-cost labor doing low-complexity work.

JSA-AUTONOMOUS replaces that toil with four agents that run 24/7 at the cost of compute, not headcount:

| What 05-JSA-AUTONOMOUS Does | Cost Impact |
|-----------------------------|-------------|
| **jsa-devsec: 80% of AppSec tasks autonomous** | Scans, triages, and fixes E/D rank findings with zero human time — replaces the bulk of a junior AppSec engineer's workload |
| **jsa-infrasec: 74% of cluster hardening autonomous** | Policy deployment, manifest fixes, scanner runs happen automatically — replaces manual hardening sprints |
| **jsa-monitor: 65% of runtime events auto-resolved** | Incidents self-heal in seconds — eliminates overnight on-call pages and the $80-200/hr engineer responding to them |
| **jsa-kubester: specialist audit on autopilot** | 13-playbook perfection sequence runs autonomously — what takes a K8s consultant $10-20K per engagement |
| **Shift-left feedback loop** | Runtime findings auto-generate prevention rules for CI + admission — issues caught once never recur, compounding savings over time |
| **Rank-based escalation** | Agents only page humans for B/S rank decisions — engineers spend time on architecture, not grunt work |
| **24/7 coverage without staffing** | Four agents replace the 3 AM on-call rotation — no shift differential, no burnout, no attrition |

### The Math

A mid-market company running Kubernetes typically staffs:
- 1 AppSec engineer ($180K) — jsa-devsec handles 80% of this workload
- 1 Platform/SRE ($200K) — jsa-infrasec + jsa-kubester handle 60% of this workload
- On-call rotation ($50-100K overhead) — jsa-monitor eliminates most of this

**Conservative estimate: $200-300K/year in labor replaced** by four agents running on a few hundred dollars/month of compute.

**Bottom line:** The JSA fleet turns a 5-person security operations team into a 1-2 person team that only handles architecture and B/S rank decisions. The agents do the rest — 24/7, with audit trails, at compute cost.

---

## The Four Agents

```
01-APP-SEC           → jsa-devsec     80% autonomous (E+D+C with JADE)
02-CLUSTER-HARDENING → jsa-infrasec   74% autonomous (E+D+C with JADE)
03-DEPLOY-RUNTIME    → jsa-monitor    80% autonomous (E+D+C with JADE)
04-KUBESTER          → jsa-kubester   Specialist — audit, perfect, verify
```

Each agent reads its playbooks from GP-CONSULTING and executes tools from GP-BEDROCK-AGENTS. **Update the playbook, the agent picks it up.** No code changes needed.

## Agent Summary

| Agent | Brain | Domain | Autonomous | With JADE |
|-------|-------|--------|------------|-----------|
| [jsa-devsec](01-jsa-devsec/) | 01-APP-SEC playbooks | Code, deps, containers, CI | 60% (E+D) | 80% (+C) |
| [jsa-infrasec](02-jsa-infrasec/) | 02-CLUSTER-HARDENING playbooks | Policies, RBAC, admission, PSS | 52% (E+D) | 74% (+C) |
| [jsa-monitor](03-jsa-monitor/) | 03-DEPLOY-RUNTIME playbooks | Falco, events, drift, forensics | 65% (E+D) | 80% (+C) |
| [jsa-kubester](04-jsa-kubester/) | 04-KUBESTER playbooks | 19 CKS/CKA/CKAD domains | Engagement-based | Knowledge engine |

## Rank Boundaries (Hardcoded)

```
E-rank (95-100% auto)  → Pattern execution. No AI, no human.
D-rank (70-90% auto)   → Pattern execution. Logged. No AI.
C-rank (40-70% auto)   → JADE proposes. Confidence scored. May need approval.
B-rank (20-40% auto)   → Human decides. JADE provides intel.
S-rank (0-5% auto)     → Human only. JADE provides dashboards.
```

**JADE max authority: C-rank. Hardcoded. Never change.**

## How It Works

```
1. Agent receives trigger (schedule, webhook, event)
2. Agent reads workflow.yaml → builds task queue
3. For each task:
   a. E/D rank → execute immediately, log result
   b. C rank  → propose to JADE → JADE approves/denies
   c. B rank  → present to human with context + options
   d. S rank  → document and escalate (human only)
4. After each phase, verify before proceeding
5. Log everything: FindingsStore + JSONL audit trail
```

## The Shift-Left Loop

Every runtime finding generates prevention artifacts that flow BACK to earlier packages:

```
Runtime finding (jsa-monitor)
  │
  ├─► jsa-devsec: Conftest rule, pre-commit hook, CI gate
  │   "This should have been caught at code review."
  │
  ├─► jsa-infrasec: Kyverno policy, NetworkPolicy, PSS label
  │   "This should have been blocked at admission."
  │
  └─► FindingsStore cross-agent correlation
      "Same issue in pre-deploy AND runtime = cascade failure (B-rank force)"
```

Issues caught once never recur. The platform gets smarter every cycle.

## Related

| Component | Location |
|-----------|----------|
| Execution engines | `GP-BEDROCK-AGENTS/` (jsa-devsec, jsa-infrasec) |
| AppSec playbooks | `GP-CONSULTING/01-APP-SEC/playbooks/` |
| Cluster playbooks | `GP-CONSULTING/02-CLUSTER-HARDENING/playbooks/` |
| Runtime playbooks | `GP-CONSULTING/03-DEPLOY-RUNTIME/playbooks/` |
| Specialist playbooks | `GP-CONSULTING/04-KUBESTER/playbooks/` |
| Shared infra | `GP-BEDROCK-AGENTS/shared/` (rank_classifier, findings_store) |
| JADE AI | `GP-MODEL-OPS/JADE-AI/` |

---

*Part of the Iron Legion — Making infrastructure cost less and run itself.*
