# Playbook 13a — Deploy Karpenter

> Right-size compute automatically. Karpenter provisions the exact nodes your pods need —
> right instance type, right size, right purchase option. No over-provisioning, no wasted spend.

---

## How Karpenter Saves Money

Cluster Autoscaler scales node groups. Karpenter provisions individual nodes matched to pending pod requirements. The difference is 20-40% of your compute bill.

| Without Karpenter | With Karpenter |
|-------------------|----------------|
| Fixed node groups — pods fit or don't | Nodes provisioned per-pod requirements |
| Over-provisioned to handle spikes | Right-sized in real-time (2 min provision) |
| Manual instance type selection | Automatic: best price/performance from 50+ types |
| On-demand only (or static Spot mix) | Intelligent Spot + On-demand mix per workload |
| Idle nodes run 24/7 | Empty nodes terminated in 30s |
| Scale-up takes 5-10 min | Scale-up in <2 min |
| One node size fits all | GPU nodes only when GPU pods are pending |

**Real-world impact:**
- **20-40% compute cost reduction** from right-sizing alone
- **60-80% savings on interruptible workloads** via automatic Spot provisioning
- **Zero idle node cost** — Karpenter consolidates and terminates empty nodes
- **No capacity planning meetings** — the cluster sizes itself

---

## Prerequisites

- EKS cluster running (02 hardening complete)
- `kubectl`, `helm` installed
- IRSA or Pod Identity configured (Karpenter needs EC2/pricing API access)
- Cluster Autoscaler removed (cannot coexist — Karpenter replaces it)

**If Kyverno is enforcing:** Karpenter's pods need privileged access for node management. Pre-create a PolicyException for the `kube-system` namespace or use the `--policy-exceptions` flag in the setup script.

---

## Step 1: Install Karpenter

```bash
PKG=~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING

# Automated install (creates IAM roles, installs Karpenter, deploys default NodePool)
bash $PKG/tools/platform/setup-karpenter.sh \
  --cluster-name my-cluster \
  --aws-region us-east-1

# Dry-run first
bash $PKG/tools/platform/setup-karpenter.sh \
  --cluster-name my-cluster \
  --aws-region us-east-1 \
  --dry-run
```

### What the script does

1. Creates IAM roles (KarpenterControllerRole, KarpenterNodeRole)
2. Tags subnets and security groups for Karpenter discovery
3. Installs Karpenter via Helm into `kube-system`
4. Deploys a default NodePool + EC2NodeClass
5. Verifies the controller is healthy

### Verify

```bash
# Karpenter controller running
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter
# All Running

# CRDs installed
kubectl get crd | grep karpenter
# nodepools.karpenter.sh
# ec2nodeclasses.karpenter.k8s.aws
# nodeclaims.karpenter.sh

# Default NodePool exists
kubectl get nodepool
# NAME      NODECLASS   NODES   READY   AGE
# default   default     0       True    1m
```

---

## Step 2: Configure NodePool (Cost-Optimized)

The default NodePool balances cost and availability. Customize for your workloads:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        managed-by: karpenter
    spec:
      requirements:
        # Instance families — general purpose + compute optimized
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ["m5", "m6i", "m7i", "c5", "c6i", "c7i"]

        # Sizes — avoid micro/small (poor bin-packing)
        - key: karpenter.k8s.aws/instance-size
          operator: In
          values: ["medium", "large", "xlarge", "2xlarge"]

        # Purchase type — prefer Spot for 60-80% savings
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]

        # Architecture
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]

      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default

  # Cost optimization: consolidate under-utilized nodes
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 30s

  # Budget: never disrupt more than 20% of nodes at once
  budgets:
    - nodes: "20%"

  # Limits: cap total cluster compute
  limits:
    cpu: "100"
    memory: 400Gi

  # Node expiry: rotate nodes every 7 days (security + AMI freshness)
  template:
    spec:
      expireAfter: 168h
EOF
```

### Key decisions

| Setting | Recommendation | Why |
|---------|---------------|-----|
| `capacity-type` | `["spot", "on-demand"]` | Karpenter uses Spot first, falls back to on-demand |
| `consolidationPolicy` | `WhenEmptyOrUnderutilized` | Aggressively removes waste — empty nodes gone in 30s |
| `instance-family` | 3+ families | More options = better Spot availability + pricing |
| `instance-size` | Skip `nano`/`micro`/`small` | Poor bin-packing, high per-node overhead |
| `expireAfter` | `168h` (7 days) | Forces AMI rotation for security patching |
| `limits.cpu` | Set to max expected | Prevents runaway scaling from misconfigured HPA |

---

## Step 3: Configure EC2NodeClass

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # AMI — use latest EKS-optimized
  amiSelectorTerms:
    - alias: al2023@latest

  # Subnets — Karpenter discovers via tags
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: my-cluster

  # Security groups — same discovery
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: my-cluster

  # Instance profile (IAM role for nodes)
  role: KarpenterNodeRole-my-cluster

  # Block device — encrypted, gp3 for cost
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 50Gi
        volumeType: gp3
        encrypted: true
        deleteOnTermination: true

  # Metadata options — IMDSv2 required (security)
  metadataOptions:
    httpEndpoint: enabled
    httpProtocolIPv6: disabled
    httpPutResponseHopLimit: 2
    httpTokens: required
EOF
```

### Security notes

- **IMDSv2 required** (`httpTokens: required`) — blocks SSRF credential theft
- **Encrypted EBS** — satisfies FedRAMP SC-28 at rest
- **gp3 volumes** — 20% cheaper than gp2, better baseline performance
- **`deleteOnTermination: true`** — no orphaned EBS volumes accumulating cost

---

## Step 4: Workload-Specific NodePools (Optional)

For workloads with different requirements (GPU, high-memory, guaranteed on-demand):

### GPU workload pool

```bash
cp $PKG/templates/karpenter/nodepool-gpu.yaml /tmp/gpu-pool.yaml

sed -i 's|<CLUSTER_NAME>|my-cluster|g' /tmp/gpu-pool.yaml

kubectl apply -f /tmp/gpu-pool.yaml
```

Pods requesting `nvidia.com/gpu` automatically land on GPU nodes. No GPU pods pending = no GPU nodes running = zero GPU cost when idle.

### Critical workload pool (on-demand only)

```bash
cp $PKG/templates/karpenter/nodepool-critical.yaml /tmp/critical-pool.yaml

sed -i 's|<CLUSTER_NAME>|my-cluster|g' /tmp/critical-pool.yaml

kubectl apply -f /tmp/critical-pool.yaml
```

Use node affinity to pin critical services:

```yaml
# In your Deployment spec:
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: karpenter.sh/nodepool
              operator: In
              values: ["critical"]
```

---

## Step 5: Verify Cost Optimization

```bash
# See what Karpenter provisioned
kubectl get nodeclaim
# NAME              TYPE        CAPACITY    ZONE         NODEPOOL   AGE
# default-abc123    m6i.large   spot        us-east-1a   default    5m

# Check node utilization
kubectl top nodes
# NAME              CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
# ip-10-0-1-50      450m         45%    1200Mi          60%

# Watch consolidation in action (Karpenter logs)
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -f | grep -i consolidat

# Check Spot vs on-demand mix
kubectl get nodes -L karpenter.sh/capacity-type
# NAME              CAPACITY-TYPE
# ip-10-0-1-50      spot
# ip-10-0-2-80      spot
# ip-10-0-3-12      on-demand    ← only critical pool
```

### Cost metrics to track

| Metric | How to measure | Target |
|--------|---------------|--------|
| **Spot adoption rate** | `kubectl get nodes -L karpenter.sh/capacity-type` | >60% of nodes on Spot |
| **Node utilization** | `kubectl top nodes` — CPU/memory % | >50% average |
| **Empty node dwell time** | Karpenter logs — time between last pod eviction and node termination | <60s |
| **Instance type diversity** | `kubectl get nodes -L node.kubernetes.io/instance-type` | 3+ types (Spot resilience) |
| **Monthly compute bill** | AWS Cost Explorer — EC2 filter by cluster tag | 20-40% reduction vs before |

---

## Step 6: Remove Cluster Autoscaler

If Cluster Autoscaler is still running, remove it — they cannot coexist:

```bash
# Check if CA exists
kubectl get deployment cluster-autoscaler -n kube-system 2>/dev/null

# If it does, remove it (Karpenter replaces it entirely)
helm uninstall cluster-autoscaler -n kube-system 2>/dev/null || \
  kubectl delete deployment cluster-autoscaler -n kube-system 2>/dev/null

# Verify only Karpenter is managing nodes
kubectl get nodes -L karpenter.sh/nodepool
```

---

## Troubleshooting

### Pods stuck in Pending (Karpenter not provisioning)

```bash
# Check Karpenter logs
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --tail=50

# Common causes:
# - NodePool requirements too restrictive (no matching instance types)
# - Subnet tags missing (karpenter.sh/discovery)
# - IAM role missing EC2 permissions
# - limits.cpu reached (increase or check for resource waste)
```

### Nodes being terminated too aggressively

```bash
# Check disruption budget
kubectl get nodepool default -o yaml | grep -A5 disruption

# Increase consolidateAfter or use budgets:
#   budgets:
#     - nodes: "10%"    ← slower consolidation
```

### Spot interruption handling

```bash
# Karpenter handles Spot interruptions natively:
# 1. AWS sends 2-min warning
# 2. Karpenter cordons + drains the node
# 3. Karpenter provisions a replacement (may be different instance type)
# 4. Pods reschedule on new node

# Verify with:
kubectl get events --field-selector reason=Disrupted -A
```

### Kyverno blocking Karpenter nodes

```bash
# Karpenter-provisioned nodes may fail if Kyverno requires labels/annotations
# at the namespace level. Create a PolicyException:
kubectl apply -f $PKG/templates/policies/kyverno/exception-karpenter.yaml
```

---

## Templates Reference

| File | What | Who owns it |
|------|------|-------------|
| `nodepool-default.yaml` | Cost-optimized default pool (Spot + on-demand) | Platform team |
| `nodepool-gpu.yaml` | GPU workload pool (p3/g4 instances) | Platform team |
| `nodepool-critical.yaml` | On-demand only for critical services | Platform team |
| `ec2nodeclass-default.yaml` | AMI, subnet, SG, EBS config | Platform team |
| `exception-karpenter.yaml` | Kyverno PolicyException for Karpenter | Platform team |

---

## Integration with Other Playbooks

| Playbook | How Karpenter connects |
|----------|----------------------|
| 02 Node Hardening | Karpenter nodes use EKS-optimized AMI — hardening baked into AMI, not Ansible |
| 05 Automated Fixes | Resource limits in manifests drive Karpenter's bin-packing decisions |
| 11 ESO | Karpenter node IAM role needs access if pods use IRSA |
| 13 NaaS | Namespace resource quotas cap what Karpenter will provision per tenant |
| 14 Golden Path | Golden path templates should include resource requests (Karpenter needs them) |

---

*Ghost Protocol — Karpenter (EKS + Cost Optimization)*
