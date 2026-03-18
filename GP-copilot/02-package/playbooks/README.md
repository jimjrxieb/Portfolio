# Playbooks — Step-by-Step Guides

> Each playbook walks through one specific workflow for K8s cluster hardening and platform setup.
>
> **Three-tier rule:** Runbook (diagnose) → Script (automate) → Playbook (guide)
>
> **Execution order:** Ansible first → hardening components → audit → fix → enforce → validate → operate

---

## Playbook Index

### Pre-Flight (run before anything else)

```bash
bash tools/hardening/pre-flight-check.sh
```

Detects platform, GitOps controllers, storage + PSA conflicts, Ansible readiness, existing hardening. Catches every gotcha we've ever hit BEFORE you start breaking things.

### Phase 1: Discover

| # | Playbook | What | Tool | Type |
|---|----------|------|------|------|
| 01 | [Identify Management](01-identify-management.md) | Who owns resources (ArgoCD vs kubectl) | `kubectl get applications` | Industry Standard |
| 01a | [Platform Quirks](01a-platform-quirks.md) | k3s vs EKS vs kubeadm vs Docker Desktop | detection commands | **GP-Copilot** |

### Phase 2: Harden

| # | Playbook | What | Tool | Type |
|---|----------|------|------|------|
| 02 | [Node Hardening](02-node-hardening.md) | Ansible: sysctl, auditd, kubelet CIS | `node-hardening/harden-nodes.sh` → `ansible/` | Industry Standard |
| 03 | [Cluster Audit](03-cluster-audit.md) | Kubescape, kube-bench, polaris baseline | `tools/hardening/run-cluster-audit.sh` | Industry Standard |
| 04 | [Fix Manifests](04-fix-manifests.md) | SecurityContext, limits, probes | `tools/hardening/add-security-context.sh` etc. | **GP-Copilot** |
| 05 | [Automated Fixes](05-automated-fixes.md) | NetworkPolicy, LimitRange, PSS labels | `tools/hardening/fix-cluster-security.sh` | **GP-Copilot** |

### Phase 3: Enforce

| # | Playbook | What | Tool | Type |
|---|----------|------|------|------|
| 06 | [Deploy Admission Control](06-deploy-admission-control.md) | Kyverno or Gatekeeper (audit mode) | `tools/admission/deploy-policies.sh` | Industry Standard |
| 07 | [Audit to Enforce](07-audit-to-enforce.md) | Progressive enforcement rollout | `tools/admission/audit-to-enforce.sh` | **GP-Copilot** |
| 07a | [RBAC Audit](07a-rbac-audit.md) | ClusterRoleBindings, ServiceAccount review | kubectl | Industry Standard |

### Phase 4: Validate

| # | Playbook | What | Tool | Type |
|---|----------|------|------|------|
| 08 | [Wire CI/CD](08-wire-cicd.md) | Conftest in CI pipelines | `tools/platform/setup-cicd.sh` | Industry Standard |
| 09 | [Compliance Report](09-compliance-report.md) | CIS, NIST, SOC2, CKS coverage | `tools/admission/policy-coverage-report.py` | **GP-Copilot** |

### Phase 5: Operate (Platform Services)

| # | Playbook | What | Tool | Type |
|---|----------|------|------|------|
| 10 | [Deploy Gateway API](10-deploy-gateway-api.md) | Envoy Gateway, HTTPRoutes, canary | `tools/platform/setup-gateway-api.sh` | Industry Standard |
| 11 | [Setup External Secrets](11-setup-external-secrets.md) | ESO, ClusterSecretStore | `tools/platform/setup-external-secrets.sh` | Industry Standard |
| 12 | [Deploy Backstage](12-deploy-backstage.md) | Developer portal, catalog, templates | `tools/platform/setup-backstage.sh` | Industry Standard |
| 13 | [Namespace-as-a-Service](13-namespace-as-a-service.md) | TeamNamespace CRD + operator | `tools/platform/deploy-namespace-operator.sh` | **GP-Copilot** |
| 13a | [Deploy Karpenter](13a-deploy-karpenter.md) | Node auto-provisioning, right-sizing, Spot | `tools/platform/setup-karpenter.sh` | Industry Standard |
| 13b | [Deploy VPA](13b-deploy-vpa.md) | Pod right-sizing recommendations + auto-scaling | `tools/platform/setup-vpa.sh` | Industry Standard |
| 14 | [Golden Path Deployment](14-golden-path-deployment.md) | Kustomize app scaffold (base/overlays/argocd) | `tools/platform/create-app-deployment.sh` | **GP-Copilot** |

### Phase 6: Maintain (added during engagements)

| # | Playbook | What | Tool | Type |
|---|----------|------|------|------|
| 15 | [Secrets Hygiene](15-secrets-hygiene.md) | Orphaned secrets, automount audit | `tools/hardening/cleanup-orphaned-secrets.sh` | **GP-Copilot** |
| 16 | [Kyverno Cleanup Jobs](16-kyverno-cleanup-jobs.md) | Diagnose/fix CronJob failures | `tools/hardening/fix-kyverno-cleanup-jobs.sh` | **GP-Copilot** |
| 17 | [GitOps Promotion Workflow](17-gitops-promotion-workflow.md) | ArgoCD + dev→staging→prod pipeline | `tools/platform/promote-image.sh` | **GP-Copilot** |
| 17a | [Deploy Staging](17a-deploy-stage.md) | Helm deploy to staging (prod-class security) | `tools/platform/deploy-stage.sh` | **GP-Copilot** |

### What's the difference?

**Industry Standard** = Any platform team should be doing this. Running CIS benchmarks, deploying admission control, setting up Gateway API, External Secrets, Backstage. The tools are open source. The playbooks document best practice.

**GP-Copilot Value-Add** = This is what we bring. The auditors find problems — we auto-fix them. The cluster needs policies — we progressively roll out warn → audit → enforce without breaking workloads. Developers need to deploy — we stamp out hardened golden paths in 30 seconds. The platform needs GitOps — we wire ArgoCD with promotion workflows, PolicyExceptions, and audit trails. Nobody else gives you `fix-cluster-security.sh` that auto-discovers services, generates NetworkPolicies, applies PSS labels, and produces a compliance report in one run.

---

## Typical Engagement Flow

```
Phase 1: Discover
  01-identify-management      ← ArgoCD vs kubectl ownership map
  01a-platform-quirks         ← k3s vs EKS vs kubeadm (config paths, gotchas)

Phase 2: Harden
  02-node-hardening            ← Ansible: sysctl, auditd, kubelet (Layer 0)
  03-cluster-audit             ← kubescape, kube-bench, polaris (baseline)
  04-fix-manifests             ← securityContext, limits, probes
  05-automated-fixes           ← NetworkPolicy, LimitRange, PSS

Phase 3: Enforce
  06-deploy-admission-control  ← Kyverno or Gatekeeper (audit mode first)
  07-audit-to-enforce          ← Progressive: warn → deny
  07a-rbac-audit               ← ClusterRoleBindings, SA token review

Phase 4: Validate
  08-wire-cicd                 ← Conftest gates in CI pipelines
  09-compliance-report         ← CIS, NIST, SOC2, CKS coverage

Phase 5: Operate
  10 → 14                     ← Platform services for developers
```

Phases 1-4 harden the cluster. Phase 5 builds the platform developers use.

---

## Ansible Playbooks

The `ansible/` subdirectory contains Ansible YAML playbooks for node-level hardening (Phase 2, step 02). These are automation scripts, not step-by-step guides — they're called by `node-hardening/harden-nodes.sh`.

| Ansible Playbook | What It Hardens |
|-----------------|----------------|
| `ansible/cis-node-hardening.yml` | Sysctl, kernel modules, file permissions |
| `ansible/auditd-config.yml` | K8s-specific audit rules |
| `ansible/kubelet-hardening.yml` | Authentication, authorization, TLS |

See [02-node-hardening.md](02-node-hardening.md) for the step-by-step guide.

---

## Numbering Convention

- Sequential integers: `01`, `02`, `03` ...
- Sub-playbooks use letter suffix: `07a`, `07b`, `07c`
- No `00` numbers
- Never renumber existing playbooks — add `a/b/c` suffixes instead

---

## Where Things Live

| What | Directory |
|------|-----------|
| **Playbooks** | `playbooks/` (you are here) |
| **Ansible** | `playbooks/ansible/` |
| **Layer 1 scripts** | `tools/hardening/` — audit, fix, collect, install, per-finding fixers |
| **Layer 2 scripts** | `tools/admission/` — deploy/test policies, audit-to-enforce |
| **Layer 3 scripts** | `tools/platform/` — ArgoCD, Gateway API, ESO, Backstage, NaaS, golden path |
| **Policies** | `templates/policies/` — Kyverno, Gatekeeper, Conftest, Terraform |
| **Remediation** | `templates/remediation/` — 12 YAML fix templates |
| **Golden path** | `templates/golden-path/` — Kustomize base/overlays/argocd |
| **Backstage** | `backstage/` — developer portal config, catalog, software templates |
| **Monitoring** | `monitoring/` — Grafana dashboards + Prometheus alerts |

---

*Ghost Protocol — K8s Hardening Package (CKA + CKS + CNPA)*
