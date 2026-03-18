# Playbook: Cluster Audit

> Deploy tools and run the initial cluster security audit.
>
> **When:** First day of any cluster hardening engagement.
> **Time:** ~15 min (install tools + run audit + review report)

---

## Prerequisites

- `kubectl` configured with cluster-admin access to the target cluster
- Know your scenario: Managed K8s (EKS/GKE/AKS) vs self-hosted (k3s/kubeadm) vs container toolkit

---

## Step 1: Choose Your Scenario

| Scenario | When to Use | Tools Run From |
|----------|------------|---------------|
| **A: Managed K8s** | EKS, GKE, AKS — public API endpoint | Your rig |
| **B: Self-hosted** | k3s, kubeadm, EC2, bare metal — localhost API | On the server |
| **C: Container Toolkit** | Self-hosted, want nothing installed on server | Pod on the cluster |

---

## Step 2: Install Tools

### Scenario A: Your Rig (EKS/GKE/AKS)

```bash
# Configure kubectl
aws eks update-kubeconfig --name my-cluster --region us-east-1   # EKS
# gcloud container clusters get-credentials my-cluster            # GKE
# az aks get-credentials --resource-group rg --name my-cluster    # AKS

# Verify access
kubectl cluster-info

# Install tools locally
bash ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/hardening/install-scanners.sh --cluster
```

### Scenario B: On the Server (k3s/kubeadm)

```bash
# FROM YOUR RIG — SCP scripts to the server
scp ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/hardening/install-scanners.sh user@server:~/
scp ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/hardening/run-cluster-audit.sh user@server:~/

# SSH in and install
ssh user@server
bash ~/install-scanners.sh --cluster
kubectl cluster-info
```

### Scenario C: Container Toolkit (Recommended for Self-Hosted)

Nothing installed on the server. Deploy a pod with all tools baked in.

```bash
# SCP the manifest to the server
scp ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/toolbox-pod.yaml user@server:/tmp/

# ON THE SERVER — deploy the pod
kubectl apply -f /tmp/toolbox-pod.yaml
kubectl wait --for=condition=Ready pod/cluster-toolkit -n gp-security --timeout=60s

# Exec in — all tools are on PATH
kubectl exec -it cluster-toolkit -n gp-security -- bash
```

The toolkit pod creates: Namespace, ServiceAccount, ClusterRole + Binding, NetworkPolicy, PVC, and the Pod itself.

---

## Step 3: Run the Audit

### Scenario A: From Your Rig

```bash
PKG=~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING
REPORTS=~/GP-copilot/GP-S3/5-consulting-reports

bash $PKG/tools/hardening/run-cluster-audit.sh \
  --output $REPORTS/01-instance/slot-1/cluster-audit-$(date +%Y%m%d)/k8s-audit.md
```

### Scenario B: On the Server

```bash
mkdir -p ~/cluster-audits
bash ~/run-cluster-audit.sh --output ~/cluster-audits/k8s-audit-$(date +%Y%m%d).md

# FROM YOUR RIG — pull results to GP-S3
REPORTS=~/GP-copilot/GP-S3/5-consulting-reports/01-instance/slot-1
mkdir -p $REPORTS/cluster-audit-$(date +%Y%m%d)
scp user@server:~/cluster-audits/*.md $REPORTS/cluster-audit-$(date +%Y%m%d)/
```

### Scenario C: From the Toolkit Pod

```bash
kubectl exec cluster-toolkit -n gp-security -- run-cluster-audit.sh

# Pull reports back
kubectl cp gp-security/cluster-toolkit:/opt/cluster-toolkit/reports/ ./reports/
```

---

## Step 4: Read the Report

The audit runs 5 checks:

| Check | What It Finds | Client Impact |
|-------|--------------|---------------|
| kubescape | Risk score 0-100, MITRE ATT&CK gaps | "Your cluster scores 34. Industry avg is 67." |
| kube-bench | CIS benchmark pass/fail | Numbered findings auditors recognize |
| polaris | Best practices score | Readable for non-security clients |
| RBAC audit | cluster-admin bindings, wildcard roles | "You have 11 cluster-admins. Should be 2." |
| Resource cliff | Pods without limits, root pods, no NetworkPolicy | "One bad deploy can OOM the whole node" |

**Read the report. The top 3-5 findings = your engagement scope.**

---

## Step 5: What Good vs Bad Looks Like

**Real example — portfolioserver (k3s v1.34.3, 1 node, 37 pods):**
```
Polaris: 82/100
kube-bench: 1 PASS, 11 FAIL, 47 WARN
Pods without resource limits: 27/37
Pods potentially running as root: 6
Namespaces without NetworkPolicy: 9/12
cluster-admin bindings: 3
ClusterRoles with wildcard permissions: 8
```

---

## Next Steps

With the audit done, pick your path:
- Nodes need OS-level hardening? → [02-node-hardening.md](02-node-hardening.md)
- Ready for automated cluster fixes? → [03-automated-fixes.md](03-automated-fixes.md)
- Want to fix manifests individually? → [04-fix-manifests.md](04-fix-manifests.md)
- Deploy admission control? → [05-deploy-admission-control.md](05-deploy-admission-control.md)

---

*Ghost Protocol — K8s Hardening Package (CKA + CKS)*
