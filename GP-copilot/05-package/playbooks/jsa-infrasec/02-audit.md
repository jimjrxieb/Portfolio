# Phase 2: Autonomous Cluster Audit

Source playbooks: `02-CLUSTER-HARDENING/playbooks/03-cluster-audit.md`, `07a-rbac-audit.md`
Automation level: **78% autonomous (E/D-rank)**, 11% human (B-rank), 11% human-only (S-rank)

## What the Agent Does

```
1. Run 3 cluster scanners (Kubescape, kube-bench, Polaris)
2. RBAC audit (cluster-admin, wildcards, automount)
3. Resource baseline (pods without limits, namespaces without quotas)
4. Generate unified audit report
5. Classify all findings by rank
```

## Step-by-Step

### 1. Scanner Runs — E-rank (fully mechanical)

```bash
# Kubescape: NSA/CISA + MITRE ATT&CK frameworks
kubescape scan --format json --output ${OUTPUT_DIR}/audit/kubescape.json
# Extract score: jq '.summaryDetails.complianceScore' ${OUTPUT_DIR}/audit/kubescape.json

# kube-bench: CIS Kubernetes Benchmark
# NOTE: requires node access or privileged pod
kube-bench run --json > ${OUTPUT_DIR}/audit/kube-bench.json 2>/dev/null
# Fallback: run as Job in cluster
# kubectl apply -f 02-CLUSTER-HARDENING/tools/kube-bench-job.yaml

# Polaris: best practices
polaris audit --format json > ${OUTPUT_DIR}/audit/polaris.json
```

### 2. RBAC Audit — D-rank (scan) + B/S-rank (remediation)

```bash
# Cluster-admin bindings
kubectl get clusterrolebindings -o json | jq '
  [.items[] | select(.roleRef.name=="cluster-admin") |
   {name: .metadata.name, subjects: .subjects, created: .metadata.creationTimestamp}]
' > ${OUTPUT_DIR}/audit/cluster-admin-bindings.json

# Classify: system (expected) vs user (investigate)
# System: system:masters, system:node, eks:*, kube-system service accounts
# User: anything else → S-RANK ESCALATION

# Wildcard RBAC permissions
kubectl get clusterroles -o json | jq '
  [.items[] | select(.rules[]? | (.resources[]? == "*") or (.verbs[]? == "*")) |
   {name: .metadata.name, rules: .rules}]
' > ${OUTPUT_DIR}/audit/wildcard-rbac.json

# automountServiceAccountToken scan
kubectl get pods -A -o json | jq '
  [.items[] | select(.spec.automountServiceAccountToken != false) |
   {name: .metadata.name, ns: .metadata.namespace, sa: .spec.serviceAccountName}]
' > ${OUTPUT_DIR}/audit/automount-enabled.json
```

### 3. Resource Baseline — D-rank

```bash
# Pods without resource limits
kubectl get pods -A -o json | jq '
  [.items[] | select(.spec.containers[] | .resources.limits == null) |
   {name: .metadata.name, ns: .metadata.namespace}]
' > ${OUTPUT_DIR}/audit/no-limits.json

# Namespaces without LimitRange
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  lr=$(kubectl get limitrange -n $ns -o json 2>/dev/null | jq '.items | length')
  [ "$lr" = "0" ] && echo "$ns"
done > ${OUTPUT_DIR}/audit/no-limitrange.txt

# Namespaces without NetworkPolicy
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  np=$(kubectl get networkpolicy -n $ns -o json 2>/dev/null | jq '.items | length')
  [ "$np" = "0" ] && echo "$ns"
done > ${OUTPUT_DIR}/audit/no-networkpolicy.txt

# PSS label status
kubectl get ns --show-labels | grep -E 'pod-security|enforce|warn|audit' \
  > ${OUTPUT_DIR}/audit/pss-labels.txt
```

### 4. Unified Audit Report — D-rank

```bash
02-CLUSTER-HARDENING/tools/hardening/run-cluster-audit.sh \
  --output ${OUTPUT_DIR}/audit/CLUSTER-AUDIT-REPORT.md
```

Report includes:
- Kubescape score (0-100)
- kube-bench pass/fail counts by CIS section
- Polaris score (0-100)
- RBAC summary (cluster-admin count, wildcard count)
- Resource cliff (pods without limits count)
- Top 10 failing controls

### 5. RBAC Escalations

**S-rank (user-created cluster-admin)**:
```
STOP. Present to human:
  "User-created cluster-admin bindings found."
  Never modify. Wrong RBAC = locked out of cluster.
  Provide: binding list, subjects, creation dates.
```

**B-rank (Helm cluster-admin)**:
```
Present to human:
  "Helm-related cluster-admin bindings detected."
  Options: accept (k3s dependency), restrict, or remove.
  Provide: binding names, Helm version, k3s status.
```

## Outputs

```
${OUTPUT_DIR}/audit/
├── kubescape.json
├── kube-bench.json
├── polaris.json
├── cluster-admin-bindings.json
├── wildcard-rbac.json
├── automount-enabled.json
├── no-limits.json
├── no-limitrange.txt
├── no-networkpolicy.txt
├── pss-labels.txt
└── CLUSTER-AUDIT-REPORT.md
```

## Phase 2 Gate

```
PASS if: audit report generated AND findings classified
Continue to Phase 3 regardless of finding count.
```
