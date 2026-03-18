# Playbook: Pod Security Perfection

> Go beyond PSS labels. Verify every pod has seccomp, AppArmor, and RuntimeClass where needed. Fix what 02 missed at the individual container level.
>
> **When:** After admission control is enforcing. Now perfect the workloads themselves.
> **Time:** ~20 min

---

## Prerequisites

- Admission policies enforcing (from [05-admission-perfection](05-admission-perfection.md))
- 03-DEPLOY-RUNTIME playbook 03 (verify container hardening) completed

---

## Step 1: PSS Label Coverage

02-CLUSTER-HARDENING applied PSS labels. Verify every application namespace has them:

```bash
# Namespaces WITHOUT PSS enforce labels
kubectl get ns -o json | jq -r '
  .items[] |
  select(.metadata.labels["pod-security.kubernetes.io/enforce"] == null) |
  .metadata.name' | grep -v -E 'kube-system|kube-public|kube-node-lease|kyverno|gatekeeper|falco|argocd'
```

Fix any gaps:

```bash
# Apply restricted PSS (production namespaces)
for NS in $(kubectl get ns -o json | jq -r '.items[] | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == null) | .metadata.name' | grep -v -E 'kube-system|kube-public|kube-node-lease|kyverno|gatekeeper|falco|argocd|monitoring'); do
    kubectl label ns "$NS" \
      pod-security.kubernetes.io/enforce=restricted \
      pod-security.kubernetes.io/audit=restricted \
      pod-security.kubernetes.io/warn=restricted \
      --overwrite
    echo "Labeled $NS with restricted PSS"
done
```

> **Reference:** `04-KUBESTER/templates/quick-ref/pss-namespace.yaml`

---

## Step 2: Seccomp Audit

```bash
# Pods WITHOUT seccomp profiles (excluding system namespaces)
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.metadata.namespace | test("kube-system|kyverno|gatekeeper|falco") | not) |
  select(
    (.spec.securityContext.seccompProfile == null) and
    ([.spec.containers[].securityContext.seccompProfile // null] | all(. == null))
  ) |
  "\(.metadata.namespace)/\(.metadata.name)"'
```

For each pod without seccomp, the fix depends on how it's managed:

- **ArgoCD-managed:** Fix in git (deployment YAML in the app repo)
- **Helm-managed:** Update Helm values
- **kubectl-managed:** Patch directly

```bash
# If kubectl-managed, patch the deployment
kubectl patch deployment <name> -n <ns> --type merge -p '{
  "spec": {"template": {"spec": {"securityContext": {"seccompProfile": {"type": "RuntimeDefault"}}}}}
}'
```

> **Tool:** `03-DEPLOY-RUNTIME/watchers/watch-seccomp.sh` monitors this continuously.

---

## Step 3: AppArmor Audit

```bash
# Pods WITHOUT AppArmor annotations (on nodes that support it)
# First check if AppArmor is available
kubectl get nodes -o json | jq -r '.items[0].status.nodeInfo.osImage'

kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.metadata.namespace | test("kube-system|kyverno|gatekeeper|falco") | not) |
  select((.metadata.annotations // {}) | keys | map(startswith("container.apparmor")) | any | not) |
  "\(.metadata.namespace)/\(.metadata.name)"'
```

If AppArmor is available on the nodes, apply runtime-default:

```bash
# Patch deployment with AppArmor annotation
kubectl patch deployment <name> -n <ns> --type merge -p '{
  "spec": {"template": {"metadata": {"annotations": {"container.apparmor.security.beta.kubernetes.io/<container-name>": "runtime/default"}}}}
}'
```

> **Template:** `02-CLUSTER-HARDENING/templates/remediation/apparmor-profiles.yaml`
> **Tool:** `03-DEPLOY-RUNTIME/watchers/watch-apparmor.sh`

---

## Step 4: RuntimeClass for Untrusted Workloads

If the cluster runs third-party or untrusted workloads, verify RuntimeClass is configured:

```bash
# Check available RuntimeClasses
kubectl get runtimeclass

# If gVisor/kata is installed, verify untrusted workloads use it
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.runtimeClassName != null) |
  "\(.metadata.namespace)/\(.metadata.name) — runtimeClass: \(.spec.runtimeClassName)"'
```

If RuntimeClass is needed but not deployed:

> **Template:** `02-CLUSTER-HARDENING/templates/remediation/runtime-class.yaml` (gVisor, kata)
> **Policy:** `02-CLUSTER-HARDENING/templates/policies/kyverno/require-runtime-class-untrusted.yaml`

---

## Step 5: Full 15-Point Container Audit

Run the comprehensive audit from 03-DEPLOY-RUNTIME:

```bash
bash ~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME/tools/verify-container-hardening.sh
```

This checks: runAsNonRoot, readOnlyRootFilesystem, capabilities drop ALL, seccomp, resource limits, probes, imagePullPolicy, :latest tags, hostNetwork, hostPID, hostIPC, privileged, automountServiceAccountToken, and more.

Any remaining failures are findings for this playbook to fix.

---

## Outputs

- PSS labels: all application namespaces labeled restricted
- Seccomp: RuntimeDefault on all application pods
- AppArmor: runtime/default where supported
- RuntimeClass: configured for untrusted workloads (if applicable)
- 15-point audit: all checks passing

---

## Next

→ [07-network-perfection.md](07-network-perfection.md) — Perfect NetworkPolicies and service mesh
