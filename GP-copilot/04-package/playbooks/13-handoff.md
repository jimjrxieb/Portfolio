# Playbook: Handoff

> Document what was done, what's automated, and what needs ongoing human attention. Hand off to the operations team or to 05-JSA-AUTONOMOUS for 24/7 coverage.
>
> **When:** Last step. Everything is verified and passing.
> **Time:** ~15 min

---

## Step 1: What's Now Automated

After 01-04, these are running autonomously:

| System | What It Does | Deployed By |
|--------|-------------|-------------|
| **Kyverno/Gatekeeper** | Blocks non-compliant workloads at admission | 02-CLUSTER-HARDENING |
| **Falco** | Detects runtime threats (shell access, privesc, exfil) | 03-DEPLOY-RUNTIME |
| **falco-exporter** | Exports Falco alerts to Prometheus | 03-DEPLOY-RUNTIME |
| **Watchers (11)** | Monitor events, RBAC, drift, secrets, PSS, network, supply chain | 03-DEPLOY-RUNTIME |
| **Responders (6)** | Patch security context, generate NetworkPolicy, isolate pods | 03-DEPLOY-RUNTIME |
| **ArgoCD** | GitOps — all changes via git, self-healing | 02-CLUSTER-HARDENING |
| **External Secrets** | Syncs secrets from external store | 02-CLUSTER-HARDENING |

---

## Step 2: What Needs Human Attention

| Task | Frequency | Why |
|------|-----------|-----|
| Review Falco alerts | Daily | False positives need tuning, real threats need response |
| Rotate secrets | Every 90 days | Even with ESO, rotation schedules need verification |
| Update base images | Monthly | New CVEs are discovered constantly |
| Review Kyverno PolicyReports | Weekly | New workloads may need policy exceptions |
| kube-bench re-scan | Monthly | Configuration drift detection |
| etcd backup verification | Monthly | Verify backups are restorable |
| Certificate renewal | Before expiry | kubeadm auto-renews, but verify |
| Kubescape re-scan | Monthly | New controls added, baseline may shift |

---

## Step 3: Escalation to 05-JSA-AUTONOMOUS

If the engagement continues into autonomous agent deployment:

```
05-JSA-AUTONOMOUS deploys:
  jsa-devsec   → Reads 01-APP-SEC playbooks, runs scanners, fixes code
  jsa-infrasec → Reads 02-CLUSTER-HARDENING playbooks, hardens clusters
  jsa-monitor  → Reads 03-DEPLOY-RUNTIME playbooks, responds to runtime threats

These agents handle E/D rank (deterministic fixes).
C-rank decisions go to JADE for AI-assisted approval.
B/S-rank decisions require human (J) approval.
```

The 04-KUBESTER findings feed into the agents' knowledge:
- New policies deployed → jsa-infrasec watches for violations
- New Falco rules tuned → jsa-monitor uses them for detection
- Supply chain policies → jsa-devsec enforces in CI

---

## Step 4: Document the Engagement

The final report from [12-compliance-verification](12-compliance-verification.md) is the primary artifact.

Additional handoff documents:

```bash
# Export cluster state
kubectl cluster-info dump --output-directory=/tmp/kubester-audit/final/cluster-dump/ --namespaces=default,kube-system 2>/dev/null

# Export all policies
kubectl get clusterpolicy -o yaml > /tmp/kubester-audit/final/all-policies.yaml 2>/dev/null
kubectl get constraints -o yaml > /tmp/kubester-audit/final/all-constraints.yaml 2>/dev/null
kubectl get networkpolicy -A -o yaml > /tmp/kubester-audit/final/all-networkpolicies.yaml

# Export RBAC
kubectl get clusterrolebindings -o yaml > /tmp/kubester-audit/final/all-crbs.yaml
kubectl get rolebindings -A -o yaml > /tmp/kubester-audit/final/all-rbs.yaml
```

---

## Step 5: Archive

```bash
# Package everything
tar czf /tmp/kubester-engagement-$(date +%Y%m%d).tar.gz /tmp/kubester-audit/

echo "Engagement archive: /tmp/kubester-engagement-$(date +%Y%m%d).tar.gz"
echo ""
echo "Copy to GP-S3 for permanent storage:"
echo "  cp /tmp/kubester-engagement-*.tar.gz ~/GP-copilot/GP-S3/5-consulting-reports/"
```

---

## Engagement Complete

```
01-APP-SEC          ✓  Application hardened
02-CLUSTER-HARDENING ✓  Cluster hardened, ArgoCD deployed
03-DEPLOY-RUNTIME   ✓  Runtime monitoring, watchers, responders
04-KUBESTER         ✓  Specialist perfected, compliance verified
```

The cluster is production-ready. The Kubernetes specialist has verified and perfected what the platform engineer built.
