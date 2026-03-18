# CKA Domain 2: Workloads & Scheduling (15%)

Understand deployments and how to perform rolling updates and rollbacks. Use ConfigMaps and Secrets to configure applications. Know how to scale applications. Understand primitives to create robust, self-healing application deployments. Understand how resource limits can affect Pod scheduling. Awareness of manifest management and common templating tools.

## CKA Exam Quick Reference

### Deployments
```bash
# Create deployment (imperative — exam speed)
kubectl create deployment nginx --image=nginx:1.25 --replicas=3

# Rolling update
kubectl set image deployment/nginx nginx=nginx:1.26

# Check rollout status
kubectl rollout status deployment/nginx

# Rollback
kubectl rollout undo deployment/nginx
kubectl rollout undo deployment/nginx --to-revision=2

# Scale
kubectl scale deployment/nginx --replicas=5

# Autoscale (HPA)
kubectl autoscale deployment/nginx --min=3 --max=10 --cpu-percent=80
```

### ConfigMaps & Secrets
```bash
# Create ConfigMap
kubectl create configmap app-config \
  --from-literal=DB_HOST=postgres \
  --from-literal=DB_PORT=5432

# Create Secret
kubectl create secret generic db-creds \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASS=secret123

# Use in pod (env vars)
# envFrom:
# - configMapRef:
#     name: app-config
# - secretRef:
#     name: db-creds

# Use as volume
# volumes:
# - name: config
#   configMap:
#     name: app-config
```

### Pod Spec with Everything
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values: [myapp]
            topologyKey: kubernetes.io/hostname
      containers:
      - name: app
        image: myapp:1.0.0
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 15
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        envFrom:
        - configMapRef:
            name: app-config
```

### Jobs & CronJobs
```bash
# Create Job
kubectl create job backup --image=busybox -- sh -c 'echo backup complete'

# Create CronJob (every day at 2am)
kubectl create cronjob nightly-backup --image=busybox \
  --schedule="0 2 * * *" -- sh -c 'echo backup'
```

### DaemonSets
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
spec:
  selector:
    matchLabels:
      app: log-collector
  template:
    metadata:
      labels:
        app: log-collector
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      containers:
      - name: collector
        image: fluentd:v1.16
```

### Scheduling — Taints, Tolerations, Affinity
```bash
# Taint a node
kubectl taint nodes node1 env=prod:NoSchedule

# Toleration in pod spec
# tolerations:
# - key: "env"
#   operator: "Equal"
#   value: "prod"
#   effect: "NoSchedule"

# Node selector (simple)
# nodeSelector:
#   disktype: ssd

# Node affinity (flexible)
# affinity:
#   nodeAffinity:
#     requiredDuringSchedulingIgnoredDuringExecution:
#       nodeSelectorTerms:
#       - matchExpressions:
#         - key: disktype
#           operator: In
#           values: [ssd]
```

### Resource Limits & LimitRange
```yaml
# LimitRange — defaults for namespace
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: app-ns
spec:
  limits:
  - default:
      cpu: 500m
      memory: 256Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
```

## Cross-Reference to GP-CONSULTING

| Need | Location |
|------|----------|
| Resource limits template | `02-CLUSTER-HARDENING/templates/remediation/resource-management.yaml` |
| LimitRange generation | `02-CLUSTER-HARDENING/tools/hardening/profile-and-set-limits.sh` |
| Add probes | `02-CLUSTER-HARDENING/tools/hardening/add-probes.sh` |
| Add resource limits | `02-CLUSTER-HARDENING/tools/hardening/add-resource-limits.sh` |
| PDB template | `02-CLUSTER-HARDENING/templates/golden-path/base/pdb.yaml` |
| Availability template | `02-CLUSTER-HARDENING/templates/remediation/availability.yaml` |
| Kyverno cleanup jobs | `02-CLUSTER-HARDENING/playbooks/16-kyverno-cleanup-jobs.md` |

## Practice Scenarios

1. **Rolling update**: Deploy v1, update to v2, verify zero-downtime, rollback to v1
2. **ConfigMap hot reload**: Mount ConfigMap as volume, update it, verify pod sees new data
3. **Resource scheduling**: Create pods with specific requests, observe scheduler decisions
4. **DaemonSet**: Deploy a logging agent to all nodes including control plane
5. **CronJob**: Create nightly backup job with history limits and failure handling
6. **Anti-affinity**: Ensure 3 replicas never land on the same node
