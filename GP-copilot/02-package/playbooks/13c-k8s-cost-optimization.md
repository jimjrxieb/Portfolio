# Playbook 13c — Kubernetes Cost Optimization

> Right-size pods, right-size nodes, kill waste. Most K8s clusters run at 15-30% actual utilization — this playbook closes that gap.
>
> **When:** After cluster hardening is complete (playbooks 01-13b). Run as part of monthly FinOps cadence.
> **Audience:** Platform engineers, SREs, developers with K8s access.
> **Time:** ~1 hour (initial audit), ~20 min (monthly review)
> **Prerequisite:** `metrics-server` running (`kubectl top` must work)

---

## The Cost Model

```
WASTE = resources requested but never used
  → You're paying for CPU/memory that sits idle
  → Most K8s clusters run at 15-30% actual utilization

THREE LEVERS:
  1. Right-size pods (requests/limits match actual usage)
  2. Right-size nodes (or let Karpenter handle it — see 13a)
  3. Remove waste (abandoned workloads, oversized PVCs, idle LBs)
```

**Golden Rule:** Measure first, cut second. Never optimize what you haven't observed for at least 7 days.

---

## Step 1: Find Where the Money Goes

### Cluster-Wide Utilization

```bash
# Total cluster capacity vs actual usage
kubectl top nodes
# If CPU% and MEMORY% are below 40%, you're overprovisioned

# Total requested vs allocatable (the real waste indicator)
kubectl describe nodes | grep -A5 "Allocated resources"
# Gap between Requests and actual usage = waste
```

### Overprovisioned Namespaces

```bash
# Usage per namespace
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $ns ==="
  kubectl top pods -n "$ns" 2>/dev/null | tail -n +2
done

# Which namespaces request the most?
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | [.metadata.namespace,
    (.spec.containers[].resources.requests.cpu // "0"),
    (.spec.containers[].resources.requests.memory // "0")] | @tsv' | \
  sort | head -30
```

### Pods Requesting Way More Than They Use

```bash
# Top CPU consumers — compare to their requests
kubectl top pods --all-namespaces --no-headers | \
  sort -k3 -rn | head -20

# Get requests for a specific pod
kubectl get pod POD_NAME -n NAMESPACE \
  -o jsonpath='{.spec.containers[*].resources.requests}'
```

---

## Step 2: Right-Size Pod Resources

### Fix Overprovisioned Pods

When a pod requests 500m CPU but uses 50m, you're holding 450m hostage from the scheduler.

```yaml
resources:
  requests:
    cpu: "100m"       # 2x actual p95 (buffer for spikes)
    memory: "128Mi"
  limits:
    cpu: "200m"       # 4x actual (burst headroom)
    memory: "256Mi"
```

**Sizing rules:**
```
requests.cpu    = p95 actual usage (7-day window)
requests.memory = p99 actual usage (OOM is worse than CPU throttle)
limits.cpu      = 2-4x requests (or remove — let it burst)
limits.memory   = 1.5-2x requests (hard ceiling)
```

### Find Pods With No Requests Set

```bash
# BestEffort QoS pods — first to get evicted, can't be scheduled efficiently
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.containers[].resources.requests == null) |
    [.metadata.namespace, .metadata.name] | @tsv'
```

Always set requests. Without them, the scheduler can't bin-pack and you waste nodes.

### Validate After Right-Sizing

```bash
# Watch for 24h after change
kubectl top pod POD_NAME -n NAMESPACE
kubectl get pod POD_NAME -n NAMESPACE
# Confirm: no OOMKills, no restarts, CPU not throttled
```

---

## Step 3: Right-Size Nodes

### Diagnose: Nodes Too Big

```bash
kubectl top nodes
# All nodes <30% CPU and <40% memory = oversized

# Check instance types
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.node\.kubernetes\.io/instance-type}{"\n"}{end}'
```

### Fix Options

| Option | When | How |
|--------|------|-----|
| Smaller instances | Static node groups | e.g., m5.xlarge → m5.large |
| Mixed instances | Spot for stateless | Spot + On-Demand mix |
| Karpenter | EKS clusters | Auto-provisions optimal instance per pod |

For Karpenter setup, see `02-CLUSTER-HARDENING/playbooks/13a-deploy-karpenter.md`.

### Stuck Pods Blocking Scale-Down

```bash
# PodDisruptionBudgets blocking eviction
kubectl get pdb --all-namespaces

# Pods with local storage (prevents node drain)
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.volumes[]?.emptyDir != null) |
    [.metadata.namespace, .metadata.name] | @tsv'
```

---

## Step 4: Find and Kill Waste

### Abandoned Workloads

```bash
# Deployments scaled to 0 (forgotten?)
kubectl get deployments --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.replicas == 0) |
    [.metadata.namespace, .metadata.name] | @tsv'

# Completed jobs consuming etcd space
kubectl get jobs --all-namespaces -o json | \
  jq -r '.items[] | select(.status.completionTime != null) |
    [.metadata.namespace, .metadata.name, .status.completionTime] | @tsv' | \
  sort -k3

# Clean completed jobs
kubectl delete jobs --all-namespaces --field-selector status.successful=1
```

### Oversized PVCs

```bash
# List all PVCs with size
kubectl get pvc --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
SIZE:.spec.resources.requests.storage,\
STATUS:.status.phase

# Check actual usage inside a pod
kubectl exec POD_NAME -n NAMESPACE -- df -h /data
# 100Gi provisioned but 5Gi used = note for next provision cycle
```

Most CSI drivers support volume expansion but NOT shrinking. Note oversized PVCs for next deployment.

### Idle LoadBalancers

```bash
# Each LoadBalancer Service = $18-25/month on AWS
kubectl get svc --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.type == "LoadBalancer") |
    [.metadata.namespace, .metadata.name, .status.loadBalancer.ingress[0].hostname // "pending"] | @tsv'

# Can these be consolidated behind a single Ingress/Gateway?
```

---

## Step 5: Scheduling Optimizations

### Pod Topology Spread (even distribution)

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: my-app
```

### Pod Priority (protect critical workloads)

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: production-critical
value: 1000000
globalDefault: false
description: "Production workloads — never preempted for batch jobs"
```

### Node Affinity for Cost Tiers

```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80
        preference:
          matchExpressions:
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot"]     # Prefer Spot, fall back to On-Demand
```

---

## Step 6: Namespace-Level Cost Controls

### ResourceQuotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: cost-control
  namespace: dev
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "8"
    limits.memory: "16Gi"
    count/pods: "20"
    count/services.loadbalancers: "1"    # One LB max per namespace
    requests.storage: "50Gi"
```

### LimitRanges (per-pod defaults)

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: dev
spec:
  limits:
    - type: Container
      default:
        cpu: "200m"
        memory: "256Mi"
      defaultRequest:
        cpu: "100m"
        memory: "128Mi"
      max:
        cpu: "2"
        memory: "4Gi"
```

---

## Monthly Audit Checklist

```
[ ] kubectl top nodes — if <30% utilization, investigate
[ ] Find pods with requests >3x actual usage — right-size them
[ ] Find LoadBalancer services — consolidate behind Ingress
[ ] Find PVCs >80% unused — note for next provision cycle
[ ] Delete completed Jobs and failed Pods
[ ] Review ResourceQuotas on dev/staging namespaces
[ ] Check Karpenter consolidation logs (if running)
[ ] Review DaemonSets — do all nodes need all DaemonSets?
```

---

## Tools

| Tool | What it does |
|------|-------------|
| `kubectl top` | Real-time CPU/memory usage |
| Kubecost | Per-namespace, per-workload cost breakdown |
| Goldilocks | VPA-based right-sizing recommendations |
| Karpenter | Smart node provisioning (see playbook 13a) |
| `kubectl-resource-capacity` | Node capacity vs allocation summary |

---

## Cross-References

- Karpenter setup: `02-CLUSTER-HARDENING/playbooks/13a-deploy-karpenter.md`
- VPA setup: `02-CLUSTER-HARDENING/playbooks/13b-deploy-vpa.md`
- ResourceQuota enforcement: `02-CLUSTER-HARDENING/playbooks/13-namespace-as-a-service.md`
- AWS cost optimization: `06-CLOUD-SECURITY/playbooks/11-aws-cost-optimization.md`
- FinOps practice: `06-CLOUD-SECURITY/playbooks/12-finops-practice.md`
- Monitoring for usage trending: `03-DEPLOY-RUNTIME/` (Prometheus)
