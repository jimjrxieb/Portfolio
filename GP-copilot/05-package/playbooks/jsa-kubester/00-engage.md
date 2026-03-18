# Playbook 00: Full Specialist Engagement

Master playbook. Kubester runs AFTER packages 01-03 are deployed.
It's the QA layer that takes hardened clusters to exam-perfect level.

## Three Operating Modes

### 1. Perfection Mode (this playbook)
Run 13-playbook sequence: audit → perfect each domain → verify → handoff.

### 2. Diagnostic Mode (on-demand)
Any symptom → `diagnostic-engine.yaml` → root cause → fix → explain → prevent.
Used when something breaks or someone asks "why is this pod crashing?"

### 3. Teaching Mode (on-demand)
Any K8s concept → `domain-knowledge.yaml` → exam context → commands → templates.
Used for learning, exam prep, or explaining a finding.

## Perfection Flow

```
START (01-03 deployed, cluster operational)
  │
  ├─► PHASE 1: SPECIALIST AUDIT (playbooks/01-audit.md)
  │   ├─ domain-audit.sh --all (CKS + CKA coverage)
  │   ├─ Kubescape + kube-bench + Polaris
  │   ├─ Inventory: what's deployed vs what's missing
  │   └─ GAP-REPORT.md → which playbooks 02-11 to run
  │
  ├─► PHASE 2: DOMAIN PERFECTION (playbooks/02-perfect.md)
  │   ├─ 02: Platform integrity (binary checksums, certs)
  │   ├─ 03: API server + etcd (flags, encryption, backup)
  │   ├─ 04: RBAC (cluster-admin, wildcards, automount)
  │   ├─ 05: Admission (audit→enforce, missing policies)
  │   ├─ 06: Pod security (PSS, seccomp, AppArmor, RuntimeClass)
  │   ├─ 07: Network (default-deny, NodePort, mTLS)
  │   ├─ 08: Secrets (encryption, ESO, rotation, orphans)
  │   ├─ 09: Supply chain (registries, CVEs, :latest, signing)
  │   ├─ 10: Runtime (Falco, watchers, IR drill, audit logs)
  │   └─ 11: Storage + workloads (limits, probes, PVs, PDB)
  │
  ├─► PHASE 3: COMPLIANCE VERIFICATION (playbooks/03-verify.md)
  │   ├─ Rescan all (Kubescape, kube-bench, Polaris, domain-audit)
  │   ├─ Before vs after comparison
  │   ├─ Accepted risk documentation (B-rank: human)
  │   ├─ Optional: FedRAMP gap analysis
  │   └─ SPECIALIST-REPORT.md
  │
  └─► PHASE 4: HANDOFF (playbooks/04-handoff.md)
      ├─ Document automated vs manual
      ├─ Configure jsa-monitor with tuned params
      ├─ Archive all audit artifacts
      └─ HANDOFF-SUMMARY.md
```

## Rank Distribution

| Phase | E | D | C | B | S |
|-------|---|---|---|---|---|
| 1 Audit | 4 | 2 | — | — | — |
| 2 Perfect | 3 | 33 | 7 | 5 | 1 |
| 3 Verify | 1 | 3 | — | 1 | — |
| 4 Handoff | 1 | 3 | — | — | — |
| **Total** | **9** | **41** | **7** | **6** | **1** |

**Autonomous (E+D): 50/64 = 78%**
**With JADE (E+D+C): 57/64 = 89%**
**Human required (B): 6/64 = 9%**
**Human only (S): 1/64 = 2%**

## Cross-Agent Routing

When kubester finds an issue, it routes the fix to the right agent:

```
Manifest needs securityContext     → jsa-devsec (01-APP-SEC/fixers/k8s-manifests/)
Namespace needs NetworkPolicy      → jsa-infrasec (02-CLUSTER-HARDENING/tools/hardening/)
Falco needs tuning                 → jsa-monitor (03-DEPLOY-RUNTIME/tools/tune-falco.sh)
API server needs flag changes      → HUMAN (control plane access required)
cluster-admin RBAC                 → HUMAN (S-rank, never auto-modify)
```

## Guardrails

- **Never modify control plane without human approval.** API server flags = B-rank minimum.
- **Never touch cluster-admin RBAC.** S-rank. Human only.
- **ArgoCD rule still applies.** Fix in git, not kubectl.
- **Always explain WHY.** Every fix includes CKS/CKA/CKAD domain context.
- **Route to the right agent.** Kubester diagnoses — the specialized agent fixes.
