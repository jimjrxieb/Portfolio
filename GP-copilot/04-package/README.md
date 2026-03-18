# 04-KUBESTER — Kubernetes Specialist Engineer

The Kubernetes specialist that comes in after 01-03 and **perfects** what was implemented. 13 sequenced playbooks that audit, tighten, and verify every layer of Kubernetes security — from binary integrity to compliance certification.

---

## How 04-KUBESTER Saves Money

Kubernetes clusters bleed money in three ways: **over-provisioned workloads**, **security debt that compounds into incidents**, and **audit failures that delay revenue**. A single misconfigured RBAC binding can lead to a breach costing millions. A cluster that fails CIS benchmarks delays SOC 2 or FedRAMP authorization by months — months where contracts sit unsigned.

04-KUBESTER is the specialist pass that catches what packages 01-03 missed:

| What 04-KUBESTER Does | Cost Impact |
|------------------------|-------------|
| **Resource limits + probes on every workload (playbook 11)** | Eliminates over-provisioned pods — right-sized compute = lower cloud bill |
| **RBAC least-privilege audit (playbook 04)** | Removes over-provisioned bindings — shrinks blast radius, avoids breach costs |
| **Admission audit→enforce transition (playbook 05)** | Misconfigurations blocked at deploy — zero post-deploy remediation spend |
| **Default-deny NetworkPolicy everywhere (playbook 07)** | Lateral movement blocked — contains incidents before they spread across namespaces |
| **Secrets encryption + ESO migration (playbook 08)** | Secrets stored properly — avoids the $4.35M average cost of a credential breach |
| **Supply chain audit + SBOM (playbook 09)** | Vulnerable images caught before deploy — no emergency CVE fire drills |
| **Final CIS compliance pass (playbook 12)** | Before/after scores documented — audit prep in days, not weeks. Unblocks SOC 2/FedRAMP revenue |
| **Falco tuning + incident response test (playbook 10)** | False positives eliminated — on-call engineers only paged for real threats |
| **Structured handoff (playbook 13)** | Ops team inherits a documented, verified cluster — no knowledge-transfer tax |

**Bottom line:** 04-KUBESTER turns a "mostly hardened" cluster into a **provably hardened** one. The difference between 71% and 95%+ on a Kubescape audit is the difference between "we're working on compliance" and "here's the signed report." That gap is where contracts stall, audits drag, and cloud spend goes unchecked. Thirteen playbooks close it.

---

## The Flow

```
01-APP-SEC           → Harden the application code
02-CLUSTER-HARDENING → Harden the cluster, deploy ArgoCD, pull app in
03-DEPLOY-RUNTIME    → Deploy Falco, watchers, monitoring, DAST
04-KUBESTER          → Specialist perfects what 01-03 built ← YOU ARE HERE
```

## Playbooks (Execution Order)

| # | Playbook | What It Does | Perfects |
|---|----------|-------------|----------|
| 01 | [Specialist Audit](playbooks/01-specialist-audit.md) | Baseline what 01-03 implemented, identify gaps | — |
| 02 | [Platform Integrity](playbooks/02-platform-integrity.md) | Verify binaries, static pod manifests, certificates | Trust |
| 03 | [API Server & etcd](playbooks/03-apiserver-etcd.md) | Harden API flags, encryption at rest, etcd backup | 02 |
| 04 | [RBAC Perfection](playbooks/04-rbac-perfection.md) | Remove over-provisioned bindings, lock down SAs | 02 |
| 05 | [Admission Perfection](playbooks/05-admission-perfection.md) | Audit→enforce, deploy missing policies, ImagePolicyWebhook | 02 |
| 06 | [Pod Security Perfection](playbooks/06-pod-security-perfection.md) | Seccomp, AppArmor, RuntimeClass on every pod | 02 |
| 07 | [Network Perfection](playbooks/07-network-perfection.md) | Default-deny everywhere, mTLS STRICT, no NodePort | 02/03 |
| 08 | [Secrets Perfection](playbooks/08-secrets-perfection.md) | Encryption verified, ESO migration, rotation audit | 02 |
| 09 | [Supply Chain Perfection](playbooks/09-supply-chain-perfection.md) | Image audit, CVE scan, registry policies, SBOM | 01 |
| 10 | [Runtime Perfection](playbooks/10-runtime-perfection.md) | Tune Falco, test incident response, verify watchers | 03 |
| 11 | [Storage & Workloads](playbooks/11-storage-workloads.md) | Resource limits, probes, PDB, storage security | 02 |
| 12 | [Compliance Verification](playbooks/12-compliance-verification.md) | Final CIS pass, before/after scores, compliance report | All |
| 13 | [Handoff](playbooks/13-handoff.md) | Document, archive, hand off to ops or 05-JSA-AUTONOMOUS | — |

## Tools

```
tools/domain-audit.sh           # Audit cluster against CKS/CKA domains (used in playbook 01)
tools/cks-practice.sh           # CKS practice scenarios with validation
tools/cka-practice.sh           # CKA practice scenarios with validation
tools/ckad-practice.sh          # CKAD practice scenarios with validation
tools/exam-speedrun.sh          # Imperative command cheat sheet
```

## Templates

```
templates/quick-ref/
  security-context.yaml           # Complete hardened deployment
  networkpolicy-default-deny.yaml # Default deny + DNS + allow pattern
  rbac-least-privilege.yaml       # SA + Role + RoleBinding
  audit-policy.yaml               # Kubernetes audit policy
  pss-namespace.yaml              # Pod Security Standards labels
  etcd-backup-restore.sh          # etcd backup/restore commands
```

## Reference (CKS/CKA/CKAD Exam Guides)

Detailed reference material organized by certification exam domain. The playbooks above reference these when deeper knowledge is needed.

### CKS (8 guides)

| Domain | Reference |
|--------|-----------|
| Cluster Setup & Hardening | `reference/cks/01-cluster-setup.md` |
| Cluster Hardening (RBAC, Admission) | `reference/cks/02-cluster-hardening.md` |
| System Hardening (Seccomp, AppArmor) | `reference/cks/03-system-hardening.md` |
| Microservice Vulnerabilities (PSS, NetworkPolicy) | `reference/cks/04-microservice-vulnerabilities.md` |
| Supply Chain Security | `reference/cks/05-supply-chain-security.md` |
| Monitoring, Logging & Runtime (Falco) | `reference/cks/06-monitoring-logging-runtime.md` |
| Binary Verification | `reference/cks/07-binary-verification.md` |
| ImagePolicyWebhook | `reference/cks/08-image-policy-webhook.md` |

### CKA (5 guides)

| Domain | Reference |
|--------|-----------|
| Cluster Architecture (kubeadm, etcd, HA) | `reference/cka/01-cluster-architecture.md` |
| Workloads & Scheduling | `reference/cka/02-workloads-scheduling.md` |
| Services & Networking | `reference/cka/03-services-networking.md` |
| Storage (PV, PVC, StorageClass) | `reference/cka/04-storage.md` |
| Troubleshooting | `reference/cka/05-troubleshooting.md` |

### CKAD (6 guides)

| Domain | Reference |
|--------|-----------|
| Application Design and Build | `reference/ckad/01-application-design-build.md` |
| Application Deployment (Helm, Kustomize) | `reference/ckad/02-application-deployment.md` |
| App Environment & Security | `reference/ckad/03-application-environment.md` |
| Services and Networking | `reference/ckad/04-services-networking.md` |
| Observability & Maintenance | `reference/ckad/05-application-observability.md` |
| Helm Package Manager | `reference/ckad/06-helm-package-manager.md` |

## Cross-Reference to Other Packages

| Need | Go To |
|------|-------|
| Run SAST scanners on K8s manifests | `01-APP-SEC/scanners/` |
| Fix K8s manifest security issues | `01-APP-SEC/playbooks/10-fix-k8s-manifests.md` |
| Deploy admission control | `02-CLUSTER-HARDENING/playbooks/06-deploy-admission-control.md` |
| All 13 Kyverno policies | `02-CLUSTER-HARDENING/templates/policies/kyverno/` |
| RBAC templates & audit | `02-CLUSTER-HARDENING/templates/remediation/rbac-templates.yaml` |
| Golden path (Kustomize) | `02-CLUSTER-HARDENING/templates/golden-path/` |
| External Secrets Operator | `02-CLUSTER-HARDENING/templates/external-secrets/` |
| Node hardening (Ansible) | `02-CLUSTER-HARDENING/playbooks/ansible/` |
| Deploy Falco | `03-DEPLOY-RUNTIME/playbooks/02-deploy-falco.md` |
| Service mesh (Istio/Cilium) | `03-DEPLOY-RUNTIME/templates/service-mesh/` |
| Falco rules | `03-DEPLOY-RUNTIME/templates/falco-rules/` |
| Runtime watchers | `03-DEPLOY-RUNTIME/watchers/` |
| Runtime responders | `03-DEPLOY-RUNTIME/responders/` |
| FedRAMP compliance | `07-FEDRAMP-READY/` |
