# CKAD Domain 3: Application Environment, Configuration and Security (25%)

Discover and use resources that extend Kubernetes (CRD, Operators). Understand authentication, authorization, and admission control. Understand requests, limits, and quotas. Understand ConfigMaps. Create and consume Secrets. Understand ServiceAccounts. Understand Application Security (SecurityContexts, Capabilities, etc.).

## CKAD Exam Quick Reference

### ConfigMaps
```bash
# Create from literals
kubectl create configmap app-config \
  --from-literal=DB_HOST=postgres \
  --from-literal=DB_PORT=5432 \
  --from-literal=LOG_LEVEL=info

# Create from file
kubectl create configmap nginx-conf --from-file=nginx.conf

# Create from env file
kubectl create configmap app-env --from-env-file=.env
```

```yaml
# Use as environment variables
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: myapp:1.0
    envFrom:
    - configMapRef:
        name: app-config
    # OR individual keys:
    env:
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: DB_HOST

---
# Use as volume
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: config
      mountPath: /etc/config
      readOnly: true
  volumes:
  - name: config
    configMap:
      name: app-config
```

### Secrets
```bash
# Create generic secret
kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password=s3cret

# Create TLS secret
kubectl create secret tls tls-secret --cert=tls.crt --key=tls.key

# Create docker registry secret
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=pass
```

```yaml
# Use as environment variables
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-creds
      key: password

# Use as volume
volumeMounts:
- name: creds
  mountPath: /etc/secrets
  readOnly: true
volumes:
- name: creds
  secret:
    secretName: db-creds
    defaultMode: 0400
```

### Resource Requests and Limits
```yaml
containers:
- name: app
  image: myapp:1.0
  resources:
    requests:          # Scheduler guarantee
      cpu: 100m        # 0.1 CPU core
      memory: 128Mi    # 128 MiB
    limits:            # Hard ceiling
      cpu: 500m        # 0.5 CPU core
      memory: 256Mi    # 256 MiB — OOMKilled if exceeded
```

### ResourceQuota
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: team-ns
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
    services: "10"
    persistentvolumeclaims: "10"
    count/deployments.apps: "10"
```

### LimitRange
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: defaults
  namespace: team-ns
spec:
  limits:
  - default:           # Default limits if not specified
      cpu: 500m
      memory: 256Mi
    defaultRequest:    # Default requests if not specified
      cpu: 100m
      memory: 128Mi
    max:               # Maximum allowed
      cpu: "2"
      memory: 1Gi
    min:               # Minimum allowed
      cpu: 50m
      memory: 64Mi
    type: Container
```

### ServiceAccounts
```bash
# Create
kubectl create sa app-sa -n app-ns

# Use in pod
# spec.serviceAccountName: app-sa

# Disable token automount
# spec.automountServiceAccountToken: false
```

### SecurityContext (CKAD level)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
  containers:
  - name: app
    image: myapp:1.0
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]   # Only if needed
```

### CRDs and Operators
```bash
# List CRDs
kubectl get crd

# Describe a CRD
kubectl describe crd certificates.cert-manager.io

# List custom resources
kubectl get certificates -A

# CRDs are just API extensions — use like any other resource
kubectl get <custom-resource> -n <ns> -o yaml
```

```yaml
# Example: Create a custom resource
apiVersion: stable.example.com/v1
kind: CronTab
metadata:
  name: my-cron
spec:
  cronSpec: "*/5 * * * *"
  image: busybox
  replicas: 1
```

### Admission Control (CKAD awareness)
```bash
# Check enabled admission controllers
kubectl -n kube-system get pod kube-apiserver-* -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | grep admission

# Common admission controllers:
# NamespaceLifecycle, LimitRanger, ServiceAccount, ResourceQuota,
# PodSecurity, MutatingAdmissionWebhook, ValidatingAdmissionWebhook
```

## Cross-Reference to GP-CONSULTING

| Need | Location |
|------|----------|
| Security context template | `04-KUBESTER/templates/quick-ref/security-context.yaml` |
| ResourceQuota template | `02-CLUSTER-HARDENING/templates/golden-path/base/resourcequota.yaml` |
| LimitRange template | `02-CLUSTER-HARDENING/templates/golden-path/base/limitrange.yaml` |
| Secrets hygiene | `02-CLUSTER-HARDENING/playbooks/15-secrets-hygiene.md` |
| External Secrets Operator | `02-CLUSTER-HARDENING/templates/external-secrets/` |
| RBAC templates | `04-KUBESTER/templates/quick-ref/rbac-least-privilege.yaml` |
| Kyverno CRDs | `02-CLUSTER-HARDENING/templates/policies/kyverno/` |

## Practice Scenarios

1. **ConfigMap**: Create ConfigMap, mount as volume AND env vars in same pod
2. **Secrets**: Create Secret, mount as read-only volume with 0400 permissions
3. **Resource limits**: Create pod with requests/limits, observe scheduling behavior when node is full
4. **ResourceQuota**: Set quota on namespace, verify pods are rejected when quota exceeded
5. **LimitRange**: Set defaults, create pod without limits, verify defaults applied
6. **SecurityContext**: Create pod that runs as non-root with read-only filesystem
7. **ServiceAccount**: Create SA with specific role, verify pod can only do permitted actions
8. **CRD**: List CRDs in cluster, create an instance of a custom resource
