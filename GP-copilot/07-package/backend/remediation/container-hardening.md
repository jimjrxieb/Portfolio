# Container Hardening — FedRAMP CM-2, CM-7, CM-8, SI-3

## The Problem

Bloated images with `:latest` tags, running package managers in prod, and unscanned
containers violate multiple FedRAMP controls around configuration management.

## Quick Diagnosis

```bash
# Images using :latest tag
kubectl get pods -A -o json | jq -r '
  .items[].spec.containers[].image' | grep -E ':latest$|^[^:]+$'

# Scan all running images
for img in $(kubectl get pods -A -o json | jq -r '.items[].spec.containers[].image' | sort -u); do
  echo "=== $img ==="
  trivy image --severity CRITICAL,HIGH "$img" 2>/dev/null | tail -5
done
```

## Fix: Pin Images to Digest

```dockerfile
# BAD
FROM python:latest
FROM python:3.12

# GOOD — pinned to specific version
FROM python:3.12.8-slim

# BEST — pinned to digest (immutable)
FROM python:3.12.8-slim@sha256:abc123...
```

Get the digest:
```bash
docker inspect --format='{{index .RepoDigests 0}}' python:3.12.8-slim
```

## Fix: Use Minimal Base Images

| Instead of | Use | Size reduction |
|-----------|-----|---------------|
| `python:3.12` | `python:3.12-slim` | ~800MB → ~150MB |
| `node:20` | `node:20-alpine` | ~1GB → ~180MB |
| `ubuntu:22.04` | `gcr.io/distroless/base` | ~80MB → ~20MB |
| Any Go binary | `scratch` or `distroless` | → ~10MB |

## Fix: Multi-Stage Build (Remove Build Tools from Production)

```dockerfile
# Build stage
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Production stage — no pip, no build tools
FROM python:3.12-slim
COPY --from=builder /install /usr/local
COPY --chown=1000:1000 . /app
WORKDIR /app
USER 1000
EXPOSE 8080
CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:8080"]
```

## Fix: Approved Registry Policy

Only allow images from your organization's approved registries:

```yaml
# Kyverno policy
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-image-registries
spec:
  validationFailureAction: Enforce
  rules:
    - name: validate-registries
      match:
        any:
          - resources:
              kinds: ["Pod"]
      validate:
        message: "Images must come from approved registries"
        pattern:
          spec:
            containers:
              - image: "{{ECR_ACCOUNT}}.dkr.ecr.*.amazonaws.com/*"
```

## Fix: Image Pull Policy

```yaml
# Force fresh pulls (prevent stale cached images)
containers:
  - name: app
    image: {{ECR_ACCOUNT}}.dkr.ecr.us-east-1.amazonaws.com/app:v1.2.3
    imagePullPolicy: Always
```

## Fix: Generate SBOM for Every Image

```bash
# In CI pipeline after build
trivy image --format cyclonedx --output sbom-${IMAGE_TAG}.json ${IMAGE}

# Or with Syft
syft ${IMAGE} -o cyclonedx-json > sbom-${IMAGE_TAG}.json
```

## CI Pipeline Integration

```yaml
# In your build pipeline
- name: Build and scan
  run: |
    docker build -t $IMAGE .
    trivy image --exit-code 1 --severity CRITICAL $IMAGE
    trivy image --format cyclonedx --output sbom.json $IMAGE
```

## Evidence for 3PAO

- [ ] Dockerfiles showing pinned versions + non-root USER
- [ ] Trivy scan results (zero CRITICAL)
- [ ] SBOM artifacts for all production images
- [ ] Registry policy (Kyverno/Gatekeeper) showing enforcement
- [ ] CI logs showing image scanning on every build

## Remediation Priority: D — Auto-Remediate

Image hardening is pattern-based — automated tooling can auto-fix Dockerfiles and
flag unscanned images.
