# Phase 1: Deploy Runtime Stack

Source playbooks: `03-DEPLOY-RUNTIME/playbooks/01-install-prerequisites.md`, `02-deploy-falco.md`, `03-verify-container-hardening.md`
Automation level: **100% autonomous (E/D-rank)**

## What the Agent Does

```
1. Install prerequisites (kubectl, helm, jq, yq)
2. Deploy Falco DaemonSet + exporter
3. Load 65 custom detection rules (8 rule files, MITRE-tagged)
4. Verify Falco producing events
5. Run 15-point container hardening audit
```

## Step-by-Step

### 1. Prerequisites — E-rank

```bash
03-DEPLOY-RUNTIME/tools/install-prerequisites.sh
# Installs: kubectl, helm, jq, yq (if not present)
# Verifies: cluster access, namespace creation ability
```

### 2. Deploy Falco — D-rank

```bash
# Add Helm repo
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# Deploy Falco
03-DEPLOY-RUNTIME/tools/deploy.sh --component falco
# Equivalent to:
# helm upgrade --install falco falcosecurity/falco \
#   --namespace falco --create-namespace \
#   --set falco.grpc.enabled=true \
#   --set falco.grpc_output.enabled=true \
#   --set driver.kind=ebpf  # or kernel_module depending on platform

# Deploy exporter (Prometheus metrics)
03-DEPLOY-RUNTIME/tools/deploy.sh --component falco-exporter
```

### 3. Load Custom Rules — D-rank

```bash
# 8 rule files, 65 rules total:
kubectl create configmap falco-custom-rules -n falco \
  --from-file=03-DEPLOY-RUNTIME/templates/falco-rules/mitre-mappings.yaml \
  --from-file=03-DEPLOY-RUNTIME/templates/falco-rules/crypto-mining.yaml \
  --from-file=03-DEPLOY-RUNTIME/templates/falco-rules/data-exfiltration.yaml \
  --from-file=03-DEPLOY-RUNTIME/templates/falco-rules/privilege-escalation.yaml \
  --from-file=03-DEPLOY-RUNTIME/templates/falco-rules/persistence.yaml \
  --from-file=03-DEPLOY-RUNTIME/templates/falco-rules/k8s-audit.yaml \
  --from-file=03-DEPLOY-RUNTIME/templates/falco-rules/service-mesh.yaml \
  --from-file=03-DEPLOY-RUNTIME/templates/falco-rules/allowlist.yaml \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart Falco to pick up rules
kubectl rollout restart daemonset/falco -n falco
kubectl rollout status daemonset/falco -n falco --timeout=120s
```

### 4. Verify — D-rank

```bash
03-DEPLOY-RUNTIME/tools/health-check.sh --component falco

# Check Falco pods running on all nodes:
kubectl get pods -n falco -o wide

# Check Falco is producing events:
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=10
# Should see JSON events within 1 minute

# Test detection with a deliberate trigger:
kubectl run falco-test --image=busybox --restart=Never --rm -i -- sh -c "cat /etc/shadow"
# Falco should alert: "Sensitive file opened for reading"
kubectl delete pod falco-test --ignore-not-found
```

### 5. Container Hardening Audit — D-rank

```bash
03-DEPLOY-RUNTIME/tools/verify-container-hardening.sh
```

15-point audit checks:
1. readOnlyRootFilesystem set
2. runAsNonRoot set
3. allowPrivilegeEscalation=false
4. capabilities drop ALL
5. seccompProfile set
6. Resource limits set
7. Liveness probe set
8. Readiness probe set
9. No :latest tags
10. imagePullPolicy=Always
11. automountServiceAccountToken=false
12. No hostNetwork/hostPID/hostIPC
13. No privileged containers
14. No hostPath volumes
15. Pod Disruption Budget exists

Output: `${OUTPUT_DIR}/container-hardening-audit.md`

## Phase 1 Gate

```
PASS if: Falco running AND producing events AND rules loaded
FAIL: Troubleshoot:
  - eBPF vs kernel module (platform-dependent)
  - Node access for DaemonSet
  - Namespace permissions
```
