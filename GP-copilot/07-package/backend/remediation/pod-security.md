# Pod Security — FedRAMP AC-6 (Least Privilege)

## The Problem

Pods running as root, with privileged mode, or with excessive capabilities violate AC-6.
This is one of the most common FedRAMP findings in Kubernetes environments.

## Quick Diagnosis

```bash
# Pods running as root (missing runAsNonRoot or runAsUser=0)
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(
    .spec.securityContext.runAsNonRoot != true or
    .spec.securityContext.runAsUser == 0
  ) |
  "\(.metadata.namespace)/\(.metadata.name)"
'

# Privileged containers
kubectl get pods -A -o json | jq -r '
  .items[].spec.containers[] |
  select(.securityContext.privileged == true) |
  .name
'

# Containers not dropping capabilities
kubectl get pods -A -o json | jq -r '
  .items[].spec.containers[] |
  select(.securityContext.capabilities.drop == null) |
  .name
'
```

## Fix: Add Security Context to Deployment

Patch an existing deployment:

```yaml
# pod-security-patch.yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: {{APP_NAME}}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
```

Apply:
```bash
kubectl patch deployment {{APP_NAME}} -n {{NAMESPACE}} --patch-file pod-security-patch.yaml
```

## Fix: Dockerfile Changes for Non-Root

Many containers fail `runAsNonRoot` because the image defaults to root.

```dockerfile
FROM python:3.12-slim

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser -d /home/appuser -s /sbin/nologin appuser

# Install dependencies as root, then switch
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app and set ownership
COPY --chown=appuser:appuser . /app
WORKDIR /app

# Switch to non-root
USER appuser

EXPOSE 8080
CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:8080"]
```

## Fix: Read-Only Root Filesystem

When `readOnlyRootFilesystem: true`, the app can't write to `/tmp` or log dirs.
Use `emptyDir` volumes:

```yaml
containers:
  - name: app
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
      - name: tmp
        mountPath: /tmp
      - name: logs
        mountPath: /var/log/app
volumes:
  - name: tmp
    emptyDir: {}
  - name: logs
    emptyDir:
      sizeLimit: 100Mi
```

## Fix: When an App Truly Needs a Capability

Some apps legitimately need `NET_BIND_SERVICE` (ports < 1024).
Only add what's needed:

```yaml
securityContext:
  capabilities:
    drop: ["ALL"]
    add: ["NET_BIND_SERVICE"]  # Only if binding to port < 1024
```

Never add `SYS_ADMIN`, `SYS_PTRACE`, or `NET_RAW` unless there's a documented reason.

## Enforce with Kyverno

Apply the policy to block non-compliant deployments:

```bash
kubectl apply -f ../policies/kyverno/require-run-as-nonroot.yaml
kubectl apply -f ../policies/kyverno/disallow-privileged.yaml
kubectl apply -f ../policies/kyverno/disallow-privilege-escalation.yaml
kubectl apply -f ../policies/kyverno/require-drop-all.yaml
```

## Full Compliant Template

See `remediation-templates/pod-security-context.yaml` for a complete PSS Restricted example.

## Evidence for 3PAO

- [ ] `kubectl get pods -A -o yaml` showing all pods with security contexts
- [ ] Kyverno policy reports showing enforcement
- [ ] Dockerfile showing `USER` directive
- [ ] No findings from `kubescape scan` on NSA/CISA framework

## Remediation Priority: D — Auto-Remediate

Pod security context is pattern-based — automated tooling auto-fixes by patching deployments.
