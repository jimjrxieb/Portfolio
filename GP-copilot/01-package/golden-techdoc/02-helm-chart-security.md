# 02 — Helm Chart Security Defaults

Every container you deploy must meet these security baselines.
Kyverno policies on the cluster will **block** deployments that don't comply.

## Pod Security Context

Set at the pod level — applies to all containers:

```yaml
spec:
  template:
    spec:
      serviceAccountName: {{ include "myapp.serviceAccountName" . }}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 999
        fsGroup: 999
        seccompProfile:
          type: RuntimeDefault
```

## Container Security Context

Set per container — locks down individual containers:

```yaml
containers:
  - name: app
    image: ghcr.io/yourorg/yourapp:v1.2.3    # Pinned tag, never :latest
    imagePullPolicy: IfNotPresent
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      runAsGroup: 999
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL
      seccompProfile:
        type: RuntimeDefault
```

### What Each Field Does

| Field | Why It's Required | Kyverno Enforced? |
|-------|------------------|-------------------|
| `runAsNonRoot: true` | Prevents running as root (UID 0) | Yes |
| `readOnlyRootFilesystem: true` | Prevents filesystem tampering | Yes |
| `allowPrivilegeEscalation: false` | Blocks `setuid` / `setgid` exploits | Yes |
| `capabilities.drop: [ALL]` | Removes all Linux capabilities | Yes |
| `seccompProfile.type: RuntimeDefault` | Enables syscall filtering | Yes |
| Pinned image tag (no `:latest`) | Reproducible builds | Yes |

### When You Need Exceptions

Some containers (nginx, ChromaDB) need specific capabilities:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false      # ChromaDB writes to /data
  capabilities:
    drop:
      - ALL
    add:
      - CHOWN        # File ownership
      - SETUID       # nginx worker process
      - SETGID       # nginx worker process
```

Set your namespace PSS labels accordingly:
```yaml
pod-security.kubernetes.io/enforce: baseline     # allows CHOWN/SETUID/SETGID
pod-security.kubernetes.io/audit: restricted      # still audits violations
pod-security.kubernetes.io/warn: restricted       # warns on non-compliant
```

---

## Resource Limits (Required)

Every container must have both requests and limits:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

### Sizing Guide

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|------------|-----------|---------------|-------------|
| Frontend (nginx/static) | 50m | 200m | 128Mi | 256Mi |
| API (FastAPI/Express) | 200m | 1000m | 512Mi | 2Gi |
| Database (Postgres/Chroma) | 100m | 500m | 256Mi | 1Gi |
| Worker/Queue | 100m | 500m | 256Mi | 512Mi |

---

## Health Probes (Required)

Both readiness and liveness probes are required:

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 6

livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 3
```

**Rules:**
- Readiness `initialDelaySeconds` < Liveness `initialDelaySeconds` (readiness first)
- Liveness should be more forgiving (higher `failureThreshold`)
- Use a dedicated `/health` endpoint, not your homepage

---

## Service Accounts

Always create a dedicated service account with token automount disabled:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "myapp.fullname" . }}
automountServiceAccountToken: false
```

Never use the `default` service account. Never mount tokens unless your
app explicitly calls the Kubernetes API.

---

## Services

Always `ClusterIP`. Never `NodePort` or `LoadBalancer`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "myapp.fullname" . }}
spec:
  type: ClusterIP
  ports:
    - port: 8000
      targetPort: 8000
      protocol: TCP
      name: http
  selector:
    {{- include "myapp.selectorLabels" . | nindent 4 }}
```

External access goes through Gateway API, not direct service exposure.

---

## Writable Directories

With `readOnlyRootFilesystem: true`, your app needs `emptyDir` volumes
for any directories it writes to:

```yaml
volumeMounts:
  - name: tmp
    mountPath: /tmp
  - name: cache
    mountPath: /var/cache/nginx
  - name: run
    mountPath: /var/run

volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
```

---

## Image Requirements

- **Pin versions**: `image: ghcr.io/org/app:v1.2.3` (never `:latest`)
- **Use semver tags**: `main-<sha>` or `v1.2.3` — Kyverno blocks `:latest`
- **Multi-stage builds**: Keep final image minimal
- **Non-root user**: Dockerfile must have `USER <non-root>` (UID >= 1000)
- **Registry**: Use `ghcr.io`, ECR, or your org's private registry

### Dockerfile Pattern

```dockerfile
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM gcr.io/distroless/nodejs22-debian12
COPY --from=builder /app /app
USER 1000
EXPOSE 8080
CMD ["app/server.js"]
```

---

## Values Template

Copy this into your `values.yaml` as a starting point:

```yaml
gateway:
  enabled: true
  className: gp-gateway
  host: myapp.example.com
  listenerPort: 8000
  annotations: {}

securityContext:
  pod:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 999
    fsGroup: 999
    seccompProfile:
      type: RuntimeDefault
  container:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 999
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL

serviceAccount:
  create: true
  automountServiceAccountToken: false

networkPolicy:
  enabled: true
  ingressNamespace: kube-system
```
