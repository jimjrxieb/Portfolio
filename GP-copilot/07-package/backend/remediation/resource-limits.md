# Resource Limits — FedRAMP SC-5, CM-6

## The Problem

Containers without resource limits can consume unlimited CPU/memory,
enabling denial-of-service within the cluster. SC-5 requires DoS protection.

## Quick Diagnosis

```bash
# Containers without resource limits
kubectl get pods -A -o json | jq -r '
  .items[] | .metadata as $meta |
  .spec.containers[] |
  select(.resources.limits == null or .resources.requests == null) |
  "\($meta.namespace)/\($meta.name) container=\(.name)"
'

# Namespaces without ResourceQuota
for ns in $(kubectl get ns -o name | cut -d/ -f2); do
  count=$(kubectl get resourcequota -n "$ns" --no-headers 2>/dev/null | wc -l)
  [ "$count" -eq 0 ] && echo "NO QUOTA: $ns"
done
```

## Fix: Add Resource Limits to Deployments

```yaml
containers:
  - name: app
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
```

**Sizing guidelines:**
| Workload | CPU request | CPU limit | Memory request | Memory limit |
|----------|------------|-----------|----------------|--------------|
| Web frontend | 100m | 500m | 128Mi | 512Mi |
| API backend | 250m | 1000m | 256Mi | 1Gi |
| Database | 500m | 2000m | 512Mi | 2Gi |
| Worker/batch | 100m | 1000m | 256Mi | 1Gi |

## Fix: Namespace ResourceQuota

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: {{NAMESPACE}}-quota
  namespace: {{NAMESPACE}}
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "8"
    limits.memory: "16Gi"
    pods: "20"
    count/deployments.apps: "10"
    count/services: "10"
```

## Fix: LimitRange (Default Limits)

Catches pods deployed without explicit limits:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: {{NAMESPACE}}
spec:
  limits:
    - default:
        cpu: "500m"
        memory: "512Mi"
      defaultRequest:
        cpu: "100m"
        memory: "128Mi"
      max:
        cpu: "2"
        memory: "2Gi"
      min:
        cpu: "50m"
        memory: "64Mi"
      type: Container
```

## Enforce with Kyverno

```bash
kubectl apply -f ../policies/kyverno/require-resource-limits.yaml
```

## Evidence for 3PAO

- [ ] All pods have resource requests and limits set
- [ ] ResourceQuota in every application namespace
- [ ] LimitRange providing defaults
- [ ] Kyverno policy enforcing limits on new deployments

## Remediation Priority: E — Auto-Remediate

Resource limits are fully pattern-based. Auto-apply default values.
