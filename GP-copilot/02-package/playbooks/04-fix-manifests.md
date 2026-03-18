# Playbook: Fix K8s Manifests

> Fix individual manifest findings: security context, resource limits, probes, NodePort, pull policy.
>
> **When:** After automated fixes (03). For per-deployment issues the cluster-wide fixes don't cover.
> **Time:** ~20 min (depends on number of manifests)

---

## The Rule

Each fixer creates a `.bak` backup, uses `yq` for auto-patching when available, and tells you the rescan command. These are D-rank fixes — high auto-fix rate, deterministic.

---

## Step 1: Identify What Needs Fixing

```bash
# Generate the violation report from PolicyReports
bash ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/hardening/generate-fix-report.sh \
  --namespace all --top 20
```

Or check the cluster audit report from [01-cluster-audit](01-cluster-audit.md).

---

## Step 2: Fix by Error Code

### Security Context — CKV_K8S_20/22/25/28/30, C-0013/16/17/34/46/55, KSV001/003/020/021

The #1 K8s finding. Missing `securityContext` means containers can escalate privileges, run as root, and mount the host filesystem.

```bash
# Usage: bash add-security-context.sh <manifest.yaml> [uid]
bash tools/hardening/add-security-context.sh k8s/deployment.yaml
bash tools/hardening/add-security-context.sh k8s/api-deployment.yaml 10002
```

**What gets added:**
```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    fsGroup: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
```

### Resource Limits — CKV_K8S_11/12/13, KSV011/016

Missing CPU/memory limits means one pod can starve the whole node.

```bash
# Usage: bash add-resource-limits.sh <manifest.yaml>
bash tools/hardening/add-resource-limits.sh k8s/deployment.yaml
```

**What gets added:**
```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

Review and adjust values based on the application's actual needs.

### Health Probes — CKV_K8S_8/9, C-0018

Missing liveness/readiness probes means K8s can't tell if your app is healthy.

```bash
# Usage: bash add-probes.sh <manifest.yaml>
bash tools/hardening/add-probes.sh k8s/deployment.yaml
```

**What gets added:** Auto-detects ports. Uses httpGet for web ports (80, 8080, 3000, etc.), tcpSocket for database ports.

**Important:** The app MUST have `/healthz` and `/ready` endpoints for httpGet probes. If unknown, the script falls back to tcpSocket. Check `initialDelaySeconds` — slow-starting apps need higher values.

### NodePort → ClusterIP — C-0074

NodePort exposes services on every node. Use ClusterIP + Ingress instead.

```bash
# Usage: bash fix-nodeport.sh <service.yaml>
bash tools/hardening/fix-nodeport.sh k8s/service.yaml
```

Converts `type: NodePort` to `type: ClusterIP` and prints an Ingress template to add.

### Image Pull Policy — CKV_K8S_15

Missing or incorrect `imagePullPolicy`.

```bash
# Usage: bash fix-pull-policy.sh <manifest.yaml>
bash tools/hardening/fix-pull-policy.sh k8s/deployment.yaml
```

---

## Step 3: Apply Remediation Templates

For findings not covered by fixers, use the remediation templates directly:

```bash
TEMPLATES=~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/templates/remediation

# Network policies (default-deny + allow rules)
kubectl apply -f $TEMPLATES/network-policies.yaml -n <namespace>

# RBAC (least privilege roles)
cat $TEMPLATES/rbac-templates.yaml   # Review first, then apply

# Seccomp profiles
kubectl apply -f $TEMPLATES/seccomp-profiles.yaml

# AppArmor profiles
kubectl apply -f $TEMPLATES/apparmor-profiles.yaml

# PSS namespace labels
kubectl apply -f $TEMPLATES/pss-namespace-labels.yaml

# PDB + HPA (availability)
kubectl apply -f $TEMPLATES/availability.yaml -n <namespace>

# RuntimeClass (gVisor/Kata for untrusted workloads)
kubectl apply -f $TEMPLATES/runtime-class.yaml
```

---

## Step 4: Verify

```bash
# Re-scan specific manifest
checkov -f k8s/deployment.yaml --check CKV_K8S_20,CKV_K8S_28,CKV_K8S_30
kubescape scan framework nsa k8s/deployment.yaml

# Full cluster audit
bash ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/hardening/run-cluster-audit.sh

# Check violation count from PolicyReports
kubectl get policyreports -A -o json | \
  python3 -c "import json,sys; d=json.load(sys.stdin); print('Failures:', sum(r.get('summary',{}).get('fail',0) for r in d['items']))"
```

**Target:** violations = 0 before moving to enforcement.

---

## Step 5: Handle Exceptions

For system pods, monitoring agents, and legacy apps that legitimately can't comply:

```yaml
apiVersion: kyverno.io/v2beta1
kind: PolicyException
metadata:
  name: prometheus-exception
  namespace: monitoring
spec:
  exceptions:
  - policyName: disallow-privileged
    ruleNames: [privileged-containers]
  match:
    any:
    - resources:
        kinds: [Pod]
        namespaces: [monitoring]
        names: [prometheus-*]
```

Document every exception in the client's POA&M.

---

## Step 6: Commit

```bash
git add k8s/
git commit -m "security: harden K8s manifests (securityContext, limits, probes)"
```

---

## Next Steps

- Deploy admission control? → [05-deploy-admission-control.md](05-deploy-admission-control.md)
- Wire CI/CD? → [06-wire-cicd.md](06-wire-cicd.md)
- Ready for enforcement? → [07-audit-to-enforce.md](07-audit-to-enforce.md)

---

*Ghost Protocol — K8s Hardening Package (CKA + CKS)*
