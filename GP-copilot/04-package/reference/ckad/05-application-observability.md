# CKAD Domain 5: Application Observability and Maintenance (15%)

Understand API deprecations. Implement probes and health checks. Use built-in CLI tools to monitor Kubernetes applications. Utilize container logs. Debugging in Kubernetes.

## CKAD Exam Quick Reference

### Probes
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: myapp:1.0
    ports:
    - containerPort: 8080

    # Liveness — is the container alive? Restart if fails.
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 10
      periodSeconds: 15
      failureThreshold: 3

    # Readiness — is the container ready for traffic? Remove from service if fails.
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 10
      failureThreshold: 3

    # Startup — is the container started? Block liveness/readiness until passes.
    startupProbe:
      httpGet:
        path: /healthz
        port: 8080
      failureThreshold: 30
      periodSeconds: 10
      # Gives container 300s to start (30 * 10s)
```

### Probe Types
```yaml
# HTTP GET
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
    httpHeaders:
    - name: Accept
      value: application/json

# TCP Socket
livenessProbe:
  tcpSocket:
    port: 3306

# Exec command (exit 0 = healthy)
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy

# gRPC (K8s 1.27+)
livenessProbe:
  grpc:
    port: 50051
```

### Monitoring
```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -A
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory

# Pod resource usage in specific namespace
kubectl top pods -n app-ns

# Container-level usage
kubectl top pods --containers
```

### Logs
```bash
# Current logs
kubectl logs <pod>
kubectl logs <pod> -n <ns>

# Previous container logs (after crash)
kubectl logs <pod> --previous

# Specific container in multi-container pod
kubectl logs <pod> -c <container>

# Follow logs
kubectl logs <pod> -f

# Last N lines
kubectl logs <pod> --tail=50

# Since duration
kubectl logs <pod> --since=1h

# All pods with label
kubectl logs -l app=web --all-containers

# Timestamps
kubectl logs <pod> --timestamps
```

### Debugging
```bash
# Describe (events, conditions, state)
kubectl describe pod <pod>

# Events (sorted by time)
kubectl get events --sort-by='.lastTimestamp'
kubectl get events -n <ns> --field-selector type=Warning

# Exec into running container
kubectl exec -it <pod> -- /bin/sh
kubectl exec -it <pod> -c <container> -- /bin/bash

# Ephemeral debug container (pod doesn't have shell)
kubectl debug -it <pod> --image=busybox --target=<container>

# Debug node
kubectl debug node/<node> -it --image=busybox

# Copy files from pod
kubectl cp <ns>/<pod>:/path/to/file ./local-file

# Port forward for testing
kubectl port-forward <pod> 8080:80
kubectl port-forward svc/<service> 8080:80
```

### Common Issues

| Symptom | Diagnostic | Fix |
|---------|-----------|-----|
| **CrashLoopBackOff** | `kubectl logs --previous` | Fix app config, command, or increase memory |
| **ImagePullBackOff** | `kubectl describe pod` | Fix image name, create imagePullSecret |
| **Pending** | `kubectl describe pod` | Fix resource requests, taints, or node capacity |
| **OOMKilled** | `kubectl describe pod` (last state) | Increase memory limits |
| **CreateContainerError** | `kubectl describe pod` | Fix volume mount, ConfigMap/Secret references |
| **Readiness failing** | `kubectl describe pod` (events) | Fix readiness probe path/port/delay |
| **Liveness restart loop** | `kubectl describe pod` (restart count) | Increase initialDelaySeconds or failureThreshold |

### API Deprecations
```bash
# Check current API versions
kubectl api-versions

# Check if resource uses deprecated API
kubectl explain deployment --api-version=apps/v1

# Convert deprecated manifests
kubectl convert -f old-manifest.yaml --output-version apps/v1

# Key deprecation to know:
# extensions/v1beta1 → networking.k8s.io/v1 (Ingress)
# policy/v1beta1 → policy/v1 (PodDisruptionBudget)
# batch/v1beta1 → batch/v1 (CronJob)
```

## Cross-Reference to GP-CONSULTING

| Need | Location |
|------|----------|
| Add probes to manifests | `02-CLUSTER-HARDENING/tools/hardening/add-probes.sh` |
| Event watcher | `03-DEPLOY-RUNTIME/watchers/watch-events.sh` |
| Debug finding | `03-DEPLOY-RUNTIME/tools/debug-finding.sh` |
| Health check | `03-DEPLOY-RUNTIME/tools/health-check.sh` |
| Container hardening audit | `03-DEPLOY-RUNTIME/playbooks/03-verify-container-hardening.md` |
| Drift detection | `03-DEPLOY-RUNTIME/watchers/watch-drift.sh` |

## Practice Scenarios

1. **Probes**: Add liveness, readiness, and startup probes to a slow-starting app
2. **Debug crash**: Pod is CrashLoopBackOff — use logs and describe to find the issue
3. **Resource monitoring**: Identify the pod using the most CPU in the cluster
4. **Ephemeral debug**: Pod has no shell — use debug container to inspect filesystem
5. **Log analysis**: Find all ERROR lines in the last hour across all pods in a namespace
6. **Port forward**: Forward local port to a pod, test the app, then clean up
7. **Readiness gate**: Create pod where readiness probe fails initially, verify traffic only routes after it passes
