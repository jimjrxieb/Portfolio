# CKAD Domain 1: Application Design and Build (20%)

Define, build, and modify container images. Choose and use the right workload resource (Deployment, DaemonSet, CronJob, etc.). Understand multi-container Pod design patterns (sidecar, init, ambassador). Utilize persistent and ephemeral volumes.

## CKAD Exam Quick Reference

### Build Container Images

```dockerfile
# Multi-stage build (exam-efficient pattern)
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY . .
USER 1000
EXPOSE 8080
CMD ["python", "app.py"]
```

```bash
# Build and tag
docker build -t myapp:1.0 .

# Save/load (air-gapped transfer)
docker save myapp:1.0 > myapp.tar
docker load < myapp.tar
```

### Workload Resources — When to Use What

| Resource | Use When |
|----------|----------|
| **Deployment** | Stateless apps, rolling updates, scale up/down |
| **StatefulSet** | Databases, ordered startup, stable network IDs, per-replica storage |
| **DaemonSet** | One pod per node (logging, monitoring, CNI) |
| **Job** | Run-to-completion tasks (migrations, batch processing) |
| **CronJob** | Scheduled recurring tasks |
| **ReplicaSet** | Never create directly — Deployment manages these |

### Deployment
```bash
# Imperative (exam speed)
kubectl create deployment web --image=nginx:1.25 --replicas=3
kubectl set image deployment/web nginx=nginx:1.26
kubectl scale deployment/web --replicas=5
kubectl rollout undo deployment/web
kubectl rollout status deployment/web
kubectl rollout history deployment/web
```

### Jobs
```bash
# Single-run job
kubectl create job import --image=busybox -- sh -c 'echo importing data'

# Parallel job
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-job
spec:
  completions: 5
  parallelism: 3
  backoffLimit: 4
  activeDeadlineSeconds: 300
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox
        command: ["sh", "-c", "echo processing item"]
EOF
```

### CronJobs
```bash
kubectl create cronjob cleanup --image=busybox --schedule="*/15 * * * *" -- sh -c 'echo cleanup'
```

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: report
spec:
  schedule: "0 6 * * *"          # Daily at 6am
  concurrencyPolicy: Forbid       # Don't overlap
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: report
            image: myapp:1.0
            command: ["python", "generate_report.py"]
```

### Multi-Container Patterns

```yaml
# Init container — runs before main container
apiVersion: v1
kind: Pod
metadata:
  name: app-with-init
spec:
  initContainers:
  - name: init-db
    image: busybox
    command: ["sh", "-c", "until nslookup db-svc; do echo waiting; sleep 2; done"]
  containers:
  - name: app
    image: myapp:1.0

---
# Sidecar — runs alongside main container
apiVersion: v1
kind: Pod
metadata:
  name: app-with-sidecar
spec:
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  - name: log-shipper
    image: fluentd:v1.16
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  volumes:
  - name: logs
    emptyDir: {}

---
# Ambassador — proxy for external services
apiVersion: v1
kind: Pod
metadata:
  name: app-with-ambassador
spec:
  containers:
  - name: app
    image: myapp:1.0
    env:
    - name: DB_HOST
      value: "localhost"      # Talks to ambassador on localhost
    - name: DB_PORT
      value: "5432"
  - name: db-proxy
    image: envoyproxy/envoy:v1.30
    ports:
    - containerPort: 5432
```

### Volumes
```yaml
# emptyDir — shared temp storage between containers
volumes:
- name: shared
  emptyDir: {}

# hostPath — node filesystem (testing only)
volumes:
- name: data
  hostPath:
    path: /data
    type: DirectoryOrCreate

# PVC — persistent storage
volumes:
- name: data
  persistentVolumeClaim:
    claimName: my-pvc

# ConfigMap as volume
volumes:
- name: config
  configMap:
    name: app-config
    items:
    - key: config.yaml
      path: config.yaml

# Secret as volume
volumes:
- name: creds
  secret:
    secretName: db-creds
    defaultMode: 0400
```

## Cross-Reference to GP-CONSULTING

| Need | Location |
|------|----------|
| Dockerfile fixers | `01-APP-SEC/fixers/dockerfile/` (6 fixers) |
| Dockerfile scanner | `01-APP-SEC/scanners/hadolint_scan_npc.py` |
| Golden path deployment | `02-CLUSTER-HARDENING/templates/golden-path/base/deployment.yaml` |
| Resource limits | `02-CLUSTER-HARDENING/tools/hardening/add-resource-limits.sh` |
| Probes | `02-CLUSTER-HARDENING/tools/hardening/add-probes.sh` |

## Practice Scenarios

1. **Multi-stage build**: Write a Dockerfile for a Go app that compiles in stage 1, runs in distroless stage 2
2. **Init container**: Pod that waits for a service to be available before starting
3. **Sidecar**: Main app writes logs to file, sidecar tails and ships to stdout
4. **Job**: Process 10 items in parallel (completions=10, parallelism=3)
5. **CronJob**: Run every 5 minutes, don't allow overlapping runs
6. **StatefulSet**: Deploy a 3-replica database with per-replica PVCs
