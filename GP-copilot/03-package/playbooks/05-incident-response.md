# Playbook 05: Incident Response

> Derived from [GP-CONSULTING/03-DEPLOY-RUNTIME/responders/CAPABILITIES.md + playbooks/07-operations.md](https://github.com/jimjrxieb/GP-copilot)
> Tailored for the Portfolio k3s cluster (portfolioserver)

## What This Does

Defines how to respond when Falco fires a critical alert. The response follows a forensics-first approach: capture evidence, isolate the threat, investigate, then remediate.

## Response Playbook

```
1. capture-forensics.sh  → Preserve evidence (logs, describe, YAML, events, ps, ss)
2. isolate-pod.sh        → Cut network with deny-all NetworkPolicy
3. Review forensics       → Determine: false positive or real threat
4. Decision:
   ├── False positive → Tune Falco (add exception)
   ├── Real threat    → kill-pod.sh + rotate credentials
   └── Needs fixing   → patch-security-context.sh
```

## Responder Scripts (6 Tools)

| Script | Rank | What It Does | When to Use |
|--------|------|-------------|-------------|
| `capture-forensics.sh` | E | Captures pod state: logs, describe, YAML, events, running processes, network connections | Always first — before isolating or killing |
| `isolate-pod.sh` | C | Applies deny-all NetworkPolicy to quarantine a pod | Falco fires critical alert on specific pod |
| `kill-pod.sh` | C | Terminates pod (captures forensics first automatically) | Confirmed malicious activity, time-sensitive |
| `patch-security-context.sh` | D | Patches deployment security context (runAsNonRoot, drop ALL) | Hardening violation detected |
| `generate-networkpolicy.sh` | D | Generates least-privilege NetworkPolicy for a workload | After network coverage audit |
| `scope-rbac.sh` | C | Audits RBAC permissions, generates scoped replacements | Overly permissive roles found |

## Severity Levels for Portfolio

| Severity | Example | Response Time | Who |
|----------|---------|--------------|-----|
| **P1 — Active compromise** | Shell spawn in API pod, credential theft | Immediate | Platform engineer |
| **P2 — Policy violation** | Container running as root, missing NetworkPolicy | Same day | Platform engineer |
| **P3 — Suspicious activity** | Unusual network connection, file access | Next business day | Review in Grafana |
| **P4 — Informational** | New process spawned (legitimate), config change | Weekly review | Dashboard check |

## SLOs to Track

| Metric | Target | Breach Action |
|--------|--------|--------------|
| Falco pods running | 100% of nodes | Rollout restart |
| Alerts/day | <50 | Tune Falco, add exceptions |
| Detection latency (p95) | <10 seconds | Check DaemonSet health |
| False positive rate | <10% | Refine allowlist |

## What This Means for Portfolio

Without incident response:
- Alert fires → nobody knows what to do → panic
- Evidence lost because pod was restarted before capturing state

With this playbook:
- Alert fires → capture forensics → isolate → investigate → remediate
- Every step is scripted and auditable
- Evidence preserved for post-incident review
- NIST IR-4 (Incident Handling) compliant
