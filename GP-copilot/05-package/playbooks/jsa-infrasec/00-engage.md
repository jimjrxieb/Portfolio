# Playbook 00: Full Autonomous Cluster Hardening Engagement

Master playbook. The agent reads this to execute a complete 02-CLUSTER-HARDENING
engagement from discovery to platform services with zero human intervention on
E/D-rank work.

## Inputs

| Variable | Source | Example |
|----------|--------|---------|
| `KUBECONFIG` | Environment or in-cluster | `~/.kube/config` |
| `TARGET_REPO` | CLI arg (for git-based fixes) | Client infrastructure repo |
| `OUTPUT_DIR` | `GP-S3/5-consulting-reports/${INSTANCE}/${SLOT}` | Standard report path |
| `APP_NAMESPACES` | Auto-discovered (non-system) | `default,app,staging` |

## Execution Flow

```
START
  │
  ├─ Prerequisites (cluster access, scanner tools, ArgoCD detection)
  │   └─ FAIL → abort with missing prerequisites
  │
  ├─► PHASE 1: DISCOVER (playbooks/01-discover.md)
  │   ├─ List ArgoCD-managed applications
  │   ├─ Build resource ownership map
  │   ├─ Detect cluster platform (k3s, EKS, etc.)
  │   ├─ Document platform quirks
  │   └─ GATE: ownership map built? → Phase 2.
  │
  ├─► PHASE 2: AUDIT (playbooks/02-audit.md)
  │   ├─ Run Kubescape (NSA/CISA + MITRE)
  │   ├─ Run kube-bench (CIS Benchmark)
  │   ├─ Run Polaris (best practices)
  │   ├─ RBAC audit (cluster-admin, wildcards, automount)
  │   ├─ Resource baseline (pods without limits)
  │   └─ GATE: audit report generated? → Phase 3.
  │
  ├─► PHASE 3: FIX (playbooks/03-fix.md)
  │   ├─ Node hardening (Ansible dry-run → B-rank apply)
  │   ├─ Manifest fixes (securityContext, limits, probes)
  │   ├─ Cluster-wide: NetworkPolicy, LimitRange, ResourceQuota, PSS
  │   ├─ automountServiceAccountToken disable
  │   ├─ Verify no service breakage
  │   └─ GATE: no CrashLoopBackOff AND score improved? → Phase 4.
  │
  ├─► PHASE 4: ENFORCE (playbooks/04-enforce.md)
  │   ├─ Select admission engine (JADE C-rank)
  │   ├─ Deploy policies in AUDIT mode
  │   ├─ Observation period (1 week minimum)
  │   ├─ Classify violations (JADE C-rank)
  │   ├─ Progressive: audit → warn → enforce (B-rank for enforce)
  │   └─ GATE: admission control active? → Phase 5.
  │
  ├─► PHASE 5: VALIDATE (playbooks/05-validate.md)
  │   ├─ Wire conftest into CI/CD pipeline
  │   ├─ Generate compliance matrix (CIS/NIST/CKS)
  │   ├─ Post-hardening rescan
  │   ├─ Before/after score comparison
  │   └─ GATE: compliance report generated? → Phase 6.
  │
  ├─► PHASE 6: OPERATE (playbooks/06-operate.md) [optional]
  │   ├─ Gateway API (C-rank controller choice)
  │   ├─ External Secrets Operator (C-rank backend choice)
  │   ├─ Backstage developer portal
  │   ├─ Namespace-as-a-Service
  │   ├─ Golden Path deployment template
  │   ├─ Secrets hygiene
  │   ├─ Kyverno cleanup fixes
  │   ├─ GitOps promotion workflow
  │   └─ Staging deployment
  │
  └─ COMPLETION
      ├─ Generate ENGAGEMENT-SUMMARY.md
      ├─ Kubescape score delta (before → after)
      ├─ Policies deployed (audit vs enforce)
      ├─ Log to JSONL audit trail
      └─ Notify human of pending B/S-rank decisions
```

## Rank Distribution Across Phases

| Phase | E | D | C | B | S |
|-------|---|---|---|---|---|
| 1 Discover | 2 | 2 | — | 1 | — |
| 2 Audit | 3 | 4 | — | 1 | 1 |
| 3 Fix | 2 | 6 | 1 | 2 | 1 |
| 4 Enforce | — | 4 | 2 | 1 | — |
| 5 Validate | 2 | 3 | — | — | — |
| 6 Operate | — | 10 | 10 | 4 | 1 |
| **Total** | **9** | **29** | **13** | **9** | **3** |

**Autonomous (E+D): 38/63 = 60%**
**With JADE (E+D+C): 51/63 = 81%**
**Human required (B): 9/63 = 14%**
**Human only (S): 3/63 = 5%**

## Error Handling

1. **ArgoCD-managed resource**: NEVER kubectl patch. Flag for git-based fix. Always.
2. **Service breakage after fix**: Capture state, present rollback commands, S-rank escalate.
3. **Scanner fails**: Skip scanner, log warning, continue with others.
4. **Ansible fails**: Rollback node, escalate to human with error details.
5. **Policy blocks deployment**: Do NOT auto-create PolicyException. B-rank escalate.
6. **Any step modifies kube-system**: Extra verification — check all system pods healthy.

## Guardrails

- **ArgoCD rule is LAW.** Check ownership before EVERY kubectl patch. No exceptions.
- **Never auto-enforce.** Admission policies start in audit. Enforce requires human.
- **Never modify cluster-admin.** S-rank. Human only.
- **Never skip service discovery.** NetworkPolicy without discovery = service outage.
- **Never batch unrelated Helm commits.** One chart, one sync. ArgoCD rule #6.
- **Always capture before-state.** Every kubectl change gets a `kubectl get -o yaml` first.
- **k3s quirk: local-path-provisioner needs enforce=privileged.** Never override this.
- **k3s quirk: config.yaml is NOT KubeletConfiguration.** Use k3s-native format.
