# Playbook 13b — Deploy VPA (Vertical Pod Autoscaler)

> Right-size pods automatically. VPA analyzes actual CPU/memory usage and recommends (or applies)
> optimal resource requests. No more guessing at resource values — data-driven sizing that cuts
> waste and prevents OOM kills.

---

## How VPA Saves Money

Developers guess at resource requests. They guess high (waste) or low (OOM kills, throttling). VPA replaces guessing with measured usage data.

| What VPA Does | Cost Impact |
|---------------|-------------|
| Measures actual CPU/memory over time | Replaces day-one guesses with real data |
| Recommends optimal resource requests | Exposes 2-10x over-provisioned pods |
| Auto-applies right-sized requests (Auto mode) | Continuous savings without manual intervention |
| Sets lower bound (min) to prevent under-provisioning | No more OOM kills from aggressive downsizing |
| Sets upper bound (max) to cap runaway growth | Prevents single pod from eating the node |
| Feeds accurate requests to Karpenter/HPA | Right-sized pods = right-sized nodes = right-sized bill |

**Bottom line:**
- **20-50% pod-level resource savings** from eliminating over-provisioned requests
- **Fewer OOM kills** — VPA catches under-provisioned pods before they crash
- **Compound savings with Karpenter** — accurate pod requests = better bin-packing = fewer nodes
- **Zero manual tuning** — VPA continuously adjusts as workload patterns change

---

## Prerequisites

- Kubernetes cluster running (1.24+)
- `kubectl` installed and cluster-reachable
- Metrics Server deployed (`kubectl top pods` must work)
- 02-CLUSTER-HARDENING baseline complete (playbooks 01-05)

**If using HPA:** VPA and HPA can conflict on the same metric. Never use VPA Auto mode on CPU if HPA is scaling on CPU for the same deployment. Use VPA in recommend-only mode alongside HPA, or have VPA manage memory while HPA manages CPU.

---

## Step 1: Install VPA

```bash
PKG=~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING

# Automated install (CRDs + controller + recommender + admission controller)
bash $PKG/tools/platform/setup-vpa.sh

# Recommend-only mode (default — safe, no pod restarts)
bash $PKG/tools/platform/setup-vpa.sh --mode recommend

# Auto mode (VPA applies recommendations by evicting and resizing pods)
bash $PKG/tools/platform/setup-vpa.sh --mode auto

# Dry-run first
bash $PKG/tools/platform/setup-vpa.sh --dry-run
```

### What the script does

1. Clones the VPA repo and installs CRDs
2. Deploys the VPA controller (recommender + updater + admission controller)
3. Creates a sample VPA resource in recommend mode
4. Verifies CRDs, controller health, and recommendation status

### Verify

```bash
# VPA controller running
kubectl get pods -n kube-system -l app=vpa-recommender
# NAME                               READY   STATUS    RESTARTS   AGE
# vpa-recommender-xxxxxxxxxx-xxxxx   1/1     Running   0          2m

# CRDs installed
kubectl get crd | grep verticalpodautoscaler
# verticalpodautoscalers.autoscaling.k8s.io
# verticalpodautoscalercheckpoints.autoscaling.k8s.io

# VPA objects queryable
kubectl get vpa -A
```

---

## Step 2: Deploy VPA for Existing Workloads

### Phase 1: Recommend mode (observe, don't change)

Start every workload in recommend-only mode. VPA watches resource usage and generates recommendations without touching pods.

```bash
# Deploy VPA in recommend mode for a deployment
cp $PKG/templates/vpa/vpa-recommend.yaml /tmp/vpa-myapp.yaml

sed -i 's|<APP_NAME>|my-deployment|g' /tmp/vpa-myapp.yaml
sed -i 's|<NAMESPACE>|default|g' /tmp/vpa-myapp.yaml

kubectl apply -f /tmp/vpa-myapp.yaml
```

Wait 24-48 hours for meaningful recommendations (VPA needs to observe real traffic patterns).

```bash
# Check recommendations
kubectl get vpa my-deployment-vpa -n default -o yaml

# Look for the recommendation section:
#   recommendation:
#     containerRecommendations:
#       - containerName: my-container
#         lowerBound:
#           cpu: 25m
#           memory: 128Mi
#         target:
#           cpu: 100m         ← VPA recommends this
#           memory: 256Mi     ← VPA recommends this
#         upperBound:
#           cpu: 500m
#           memory: 1Gi
```

### Phase 2: Compare recommendations vs current requests

```bash
# What the deployment currently requests
kubectl get deploy my-deployment -n default -o jsonpath='{.spec.template.spec.containers[0].resources}' | python3 -m json.tool

# What VPA recommends
kubectl get vpa my-deployment-vpa -n default -o jsonpath='{.status.recommendation.containerRecommendations[0].target}' | python3 -m json.tool

# Common finding: deployment requests 1 CPU / 2Gi memory
#                 VPA recommends 100m CPU / 256Mi memory
#                 = 10x over-provisioned
```

### Phase 3: Switch to Auto mode (optional — when you trust the recommendations)

```bash
# Deploy VPA in auto mode with safety bounds
cp $PKG/templates/vpa/vpa-auto.yaml /tmp/vpa-myapp-auto.yaml

sed -i 's|<APP_NAME>|my-deployment|g' /tmp/vpa-myapp-auto.yaml
sed -i 's|<NAMESPACE>|default|g' /tmp/vpa-myapp-auto.yaml

kubectl apply -f /tmp/vpa-myapp-auto.yaml
```

**Warning:** Auto mode evicts pods to apply new resource requests. Ensure your workload tolerates restarts (has multiple replicas, PodDisruptionBudgets, graceful shutdown).

---

## Step 3: VPA + Karpenter Integration

VPA right-sizes pods. Karpenter right-sizes nodes. Together they eliminate waste at both layers.

```
Without VPA+Karpenter:
  Pod requests 4 CPU → Karpenter provisions xlarge node → pod uses 200m → 95% waste

With VPA+Karpenter:
  VPA sets pod to 250m → Karpenter provisions medium node → pod uses 200m → 20% headroom
```

### How they work together

1. **VPA** analyzes actual usage, sets accurate resource requests
2. **Karpenter** reads those requests, provisions the smallest node that fits
3. **Result:** Pods get what they need. Nodes aren't oversized. Bill drops.

### Deployment order matters

```bash
# 1. Deploy VPA in recommend mode first
# 2. Wait 24-48h for recommendations
# 3. Switch to Auto mode (or manually apply recommendations)
# 4. Karpenter automatically provisions right-sized nodes on next scale event

# Verify the chain is working:
kubectl top pods -A --sort-by=cpu    # Actual usage
kubectl get vpa -A                    # VPA recommendations
kubectl get nodeclaim                 # Karpenter node sizing
kubectl top nodes                     # Node utilization (target: >50%)
```

### Anti-pattern: VPA without resource requests

VPA cannot help pods that have no resource requests set. Fix this first:

```bash
# Find pods with no resource requests
kubectl get pods -A -o json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for pod in data['items']:
    for c in pod['spec'].get('containers', []):
        if not c.get('resources', {}).get('requests'):
            print(f\"  {pod['metadata']['namespace']}/{pod['metadata']['name']} -> {c['name']}: NO REQUESTS\")
"
```

---

## Step 4: Verify Savings

```bash
# Current resource usage vs requests
kubectl top pods -n default
# NAME                            CPU(cores)   MEMORY(bytes)
# my-deployment-xxxxxxxxxx-xxxxx  45m          120Mi

# VPA recommendation
kubectl get vpa my-deployment-vpa -n default \
  -o jsonpath='{.status.recommendation.containerRecommendations[0].target}'
# {"cpu":"50m","memory":"150Mi"}

# Original request (before VPA)
# cpu: 500m, memory: 1Gi
# VPA recommendation: cpu: 50m, memory: 150Mi
# Savings: 90% CPU, 85% memory — per pod
```

### Metrics to track

| Metric | How to measure | Target |
|--------|---------------|--------|
| **Request vs actual ratio** | `kubectl top pods` vs pod spec requests | <2x (requests within 2x of actual) |
| **VPA recommendation age** | `kubectl get vpa -o yaml` — check last update time | <24h (fresh data) |
| **OOM kills (before/after)** | `kubectl get events --field-selector reason=OOMKilled -A` | Zero after VPA tuning |
| **Node utilization** | `kubectl top nodes` — CPU/memory % | >50% average |
| **Pod restart count** | `kubectl get pods -A` — RESTARTS column | Stable or decreasing |

### Cluster-wide savings estimate

```bash
# Sum all VPA recommendations vs current requests
kubectl get vpa -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: target={.status.recommendation.containerRecommendations[0].target}{"\n"}{end}'
```

---

## Troubleshooting

### VPA not generating recommendations

```bash
# Check the recommender is running
kubectl get pods -n kube-system -l app=vpa-recommender
kubectl logs -n kube-system -l app=vpa-recommender --tail=50

# Common causes:
# - Metrics Server not installed (VPA needs it)
# - VPA targetRef doesn't match the deployment name
# - Pod has been running <15 minutes (VPA needs time to collect data)

# Verify Metrics Server works
kubectl top pods -n default
# If this fails, install Metrics Server first
```

### VPA recommendations seem too low

```bash
# VPA uses percentile-based algorithms. If recommendations seem low:
# 1. Wait longer — 24-48h of real traffic gives better data
# 2. Check if the load during observation was representative
# 3. Use minAllowed in resource policy to set a floor

# Example: never go below 100m CPU regardless of VPA recommendation
# See vpa-auto.yaml template for minAllowed/maxAllowed settings
```

### VPA + HPA conflict

```bash
# Symptoms: pods constantly restarting, HPA and VPA fighting over replicas

# Rule: never use VPA Auto mode on the same metric HPA uses
# Safe combinations:
#   - HPA on CPU + VPA on memory (Auto mode)
#   - HPA on custom metrics + VPA on CPU and memory (Auto mode)
#   - HPA on CPU + VPA in recommend-only mode (observe, apply manually)

# To check if HPA exists for the same deployment:
kubectl get hpa -A | grep my-deployment
```

### Pods not being evicted in Auto mode

```bash
# Check VPA updater logs
kubectl get pods -n kube-system -l app=vpa-updater
kubectl logs -n kube-system -l app=vpa-updater --tail=50

# Common causes:
# - Only 1 replica (VPA won't evict if it would cause downtime)
# - PodDisruptionBudget prevents eviction
# - VPA admission controller not running
kubectl get pods -n kube-system -l app=vpa-admission-controller
```

---

## Templates Reference

| File | What | Who owns it |
|------|------|-------------|
| `vpa/vpa-recommend.yaml` | VPA in Off/recommend mode — observe, don't change | Platform team |
| `vpa/vpa-auto.yaml` | VPA in Auto mode with min/max safety bounds | Platform team |

---

## Integration with Other Playbooks

| Playbook | How VPA connects |
|----------|-----------------|
| 05 Automated Fixes | VPA data validates whether resource limits in manifests are reasonable |
| 13 NaaS | Namespace ResourceQuotas still cap total, VPA optimizes within that cap |
| 13a Karpenter | VPA right-sizes pods → Karpenter right-sizes nodes → compound savings |
| 14 Golden Path | Golden path templates should include VPA objects alongside deployments |
| 03 DEPLOY-RUNTIME | Falco rules unaffected — VPA changes requests, not security contexts |

---

*Ghost Protocol — VPA (Resource Optimization + Cost Reduction)*
