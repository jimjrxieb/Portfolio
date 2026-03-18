# Playbook: Specialist Audit

> Baseline what 01-APP-SEC, 02-CLUSTER-HARDENING, and 03-DEPLOY-RUNTIME implemented. Identify gaps before perfecting.
>
> **When:** First step. Packages 01-03 are deployed and running.
> **Time:** ~30 min

---

## Prerequisites

- Packages 01-03 completed (app hardened, cluster hardened, runtime deployed)
- `kubectl` configured with cluster-admin access
- Scanners installed (`02-CLUSTER-HARDENING/tools/hardening/install-scanners.sh`)

---

## Step 1: Run the Domain Audit

```bash
PKG=~/GP-copilot/GP-CONSULTING/04-KUBESTER

# Full CKS + CKA audit against all domains
bash $PKG/tools/domain-audit.sh --all
```

This checks:
- CKS: API server flags, NetworkPolicy coverage, admission control, PSS labels, seccomp/apparmor, privileged containers, :latest tags, Falco, audit logging, immutability
- CKA: Node health, resource limits, probes, CoreDNS, CNI, storage, pod status, warnings

Review the output. Every `[FAIL]` and `[WARN]` is something 01-03 didn't catch or didn't fully address.

---

## Step 2: Run CIS Benchmark (Full Pass)

02-CLUSTER-HARDENING ran Kubescape and kube-bench during the initial audit. Run them again — 02 may have fixed things that changed the score, or missed items that only show up post-deployment.

```bash
# kube-bench — all sections
kube-bench run --targets master,node,etcd,policies

# Kubescape — NSA + CIS frameworks
kubescape scan framework nsa,cis-v1.23-t1.0.1 -v

# Polaris — best practices
polaris audit --format=pretty
```

Save the output:
```bash
mkdir -p /tmp/kubester-audit
kube-bench run --targets master,node,etcd,policies > /tmp/kubester-audit/kube-bench.txt
kubescape scan framework nsa -o /tmp/kubester-audit/kubescape.json --format json
polaris audit --format=json > /tmp/kubester-audit/polaris.json
```

---

## Step 3: Inventory What 01-03 Deployed

Check what's actually running:

```bash
# Admission control (from 02)
kubectl get deploy -n kyverno 2>/dev/null && echo "Kyverno: YES" || echo "Kyverno: NO"
kubectl get deploy -n gatekeeper-system 2>/dev/null && echo "Gatekeeper: YES" || echo "Gatekeeper: NO"

# Active policies
kubectl get clusterpolicy 2>/dev/null | wc -l
kubectl get constraints 2>/dev/null | wc -l

# PolicyReport violations (current)
kubectl get policyreport -A --no-headers 2>/dev/null | wc -l

# Runtime (from 03)
kubectl get pods -n falco --no-headers 2>/dev/null
kubectl get pods -n monitoring --no-headers 2>/dev/null

# ArgoCD (from 02)
kubectl get pods -n argocd --no-headers 2>/dev/null

# Service mesh (from 03)
kubectl get pods -n istio-system --no-headers 2>/dev/null
kubectl get pods -n cilium --no-headers 2>/dev/null
```

---

## Step 4: Generate the Gap Report

```bash
echo "=== KUBESTER SPECIALIST AUDIT ===" > /tmp/kubester-audit/gap-report.md
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> /tmp/kubester-audit/gap-report.md
echo "Cluster: $(kubectl config current-context)" >> /tmp/kubester-audit/gap-report.md
echo "" >> /tmp/kubester-audit/gap-report.md

# kube-bench failures
echo "## kube-bench FAIL items" >> /tmp/kubester-audit/gap-report.md
grep '\[FAIL\]' /tmp/kubester-audit/kube-bench.txt >> /tmp/kubester-audit/gap-report.md

# Polaris warnings/dangers
echo "" >> /tmp/kubester-audit/gap-report.md
echo "## Polaris warnings" >> /tmp/kubester-audit/gap-report.md
cat /tmp/kubester-audit/polaris.json | jq -r '.Results[] | select(.Score < 70) | "\(.Name) — score: \(.Score)"' >> /tmp/kubester-audit/gap-report.md 2>/dev/null

echo "" >> /tmp/kubester-audit/gap-report.md
echo "Report: /tmp/kubester-audit/gap-report.md"
```

---

## Step 5: Decide the Sequence

Based on the gap report, pick which playbooks to run next. The recommended order:

| Playbook | Run If |
|----------|--------|
| 02 — Platform Integrity | kube-bench section 1.x/4.x failures, binary concerns |
| 03 — API Server & etcd | Encryption at rest missing, API server flags wrong |
| 04 — RBAC Perfection | cluster-admin over-provisioned, wildcard roles |
| 05 — Admission Perfection | Policies in audit mode, missing ImagePolicyWebhook |
| 06 — Pod Security Perfection | Seccomp/AppArmor gaps, RuntimeClass missing |
| 07 — Network Perfection | NetworkPolicy gaps, service mesh not STRICT |
| 08 — Secrets Perfection | Native secrets still used, no encryption at rest |
| 09 — Supply Chain Perfection | :latest tags, unsigned images, no SBOM |
| 10 — Runtime Perfection | Falco noisy, audit logs not configured, watchers missing |
| 11 — Storage & Workloads | PV security, probes missing, resource limits wrong |
| 12 — Compliance Verification | Final CIS pass, generate compliance report |
| 13 — Handoff | Document what was done, ongoing maintenance plan |

Skip playbooks where the gap report shows no issues.

---

## Next

→ [02-platform-integrity.md](02-platform-integrity.md) — Verify binaries and platform configuration
