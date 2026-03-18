# CKS Domain 5: Supply Chain Security (20%)

Minimize base image footprint. Secure your supply chain. Use static analysis of user workloads. Scan images for known vulnerabilities.

## What You Need to Know

- Image scanning (Trivy, Grype)
- Dockerfile best practices (multi-stage, non-root, pinned versions)
- Image signing and verification (cosign, Notary)
- SBOM generation (Syft, CycloneDX)
- Admission control for image policies
- Static analysis (Kubescape, Checkov, Polaris)

## Pre-Built Tools (Already in GP-CONSULTING)

### Scanners
| Tool | Location | What It Scans |
|------|----------|-------------|
| Trivy | `01-APP-SEC/scanners/trivy_scan_npc.py` | Container images, filesystems, configs |
| Grype | `01-APP-SEC/scanners/grype_scan_npc.py` | Container images, SBOMs |
| Checkov | `01-APP-SEC/scanners/checkov_scan_npc.py` | K8s manifests (CKV_K8S_*) |
| Hadolint | `01-APP-SEC/scanners/hadolint_scan_npc.py` | Dockerfiles (best practices) |
| Kubescape | `01-APP-SEC/scanners/kubescape_scan_npc.py` | Manifests + live cluster |

### Fixers
| Fixer | Location | What It Fixes |
|-------|----------|-------------|
| `add-nonroot-user.sh` | `01-APP-SEC/fixers/dockerfile/` | Add USER directive to Dockerfile |
| `add-healthcheck.sh` | `01-APP-SEC/fixers/dockerfile/` | Add HEALTHCHECK to Dockerfile |
| `fix-maintainer.sh` | `01-APP-SEC/fixers/dockerfile/` | MAINTAINER -> LABEL maintainer |
| `fix-cmd-format.sh` | `01-APP-SEC/fixers/dockerfile/` | CMD string -> exec form |
| `fix-workdir.sh` | `01-APP-SEC/fixers/dockerfile/` | Relative -> absolute WORKDIR |
| `bump-cves.sh` | `01-APP-SEC/fixers/dependencies/` | Update CVE-affected dependencies |

### Admission Policies
| Policy | Location | What It Blocks |
|--------|----------|---------------|
| `disallow-latest-tag.yaml` | `02-CLUSTER-HARDENING/templates/policies/kyverno/` | Blocks :latest images |
| `require-semver-tags.yaml` | `02-CLUSTER-HARDENING/templates/policies/kyverno/` | Requires semantic versions |
| `require-runtime-class-untrusted.yaml` | `02-CLUSTER-HARDENING/templates/policies/kyverno/` | Sandbox for untrusted registries |
| `image-security.rego` | `02-CLUSTER-HARDENING/templates/policies/conftest/` | Image registry/tag checks |

### Watchers
| Watcher | Location | What It Detects |
|---------|----------|----------------|
| `watch-supply-chain.sh` | `03-DEPLOY-RUNTIME/watchers/` | Untrusted registries, unsigned images, missing SBOMs |

### Playbooks
| Playbook | Location | When to Use |
|----------|----------|-------------|
| `10-fix-k8s-manifests.md` | `01-APP-SEC/playbooks/` | Pre-deploy YAML fixes |
| `03-verify-container-hardening.md` | `03-DEPLOY-RUNTIME/playbooks/` | 15-point running pod audit |

## CKS Exam Quick Reference

### Scan an Image with Trivy
```bash
# Scan for CVEs
trivy image nginx:1.25 --severity HIGH,CRITICAL

# Scan K8s manifests
trivy config deployment.yaml

# Scan filesystem
trivy fs --security-checks vuln,config .
```

### Dockerfile Best Practices
```dockerfile
# Multi-stage build (minimize attack surface)
FROM golang:1.22 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /app/server

FROM gcr.io/distroless/static:nonroot
COPY --from=builder /app/server /server
USER 65534:65534
EXPOSE 8080
ENTRYPOINT ["/server"]
```

Key rules:
- Pin base image versions (never `:latest`)
- Use multi-stage builds
- Use distroless or Alpine for runtime
- Run as non-root (USER directive)
- No secrets in image layers
- COPY specific files, not entire directories

### Image Policy Webhook (ImagePolicyWebhook)
```yaml
# /etc/kubernetes/admission/admission-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/admission/webhook-kubeconfig.yaml
      allowTTL: 50
      denyTTL: 50
      retryBackoff: 500
      defaultAllow: false
```

### Kubeconfig for Image Webhook
```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/admission/webhook-ca.crt
    server: https://image-review.example.com:8443/validate
  name: image-review
contexts:
- context:
    cluster: image-review
    user: api-server
  name: image-review
current-context: image-review
users:
- name: api-server
  user:
    client-certificate: /etc/kubernetes/admission/api-server-client.crt
    client-key: /etc/kubernetes/admission/api-server-client.key
```

### Static Analysis with Kubescape
```bash
# Full framework scan
kubescape scan framework nsa -v

# Single control
kubescape scan control C-0013  # Non-root containers

# Specific manifest
kubescape scan deployment.yaml
```

## Practice Scenarios

1. **Image scanning**: Scan a running cluster's images with Trivy, fix CRITICAL CVEs
2. **Dockerfile hardening**: Take a vulnerable Dockerfile, apply all 6 fixers
3. **Image policy**: Deploy Kyverno to block :latest tags, verify enforcement
4. **SBOM**: Generate SBOM with Syft, scan with Grype
5. **Distroless**: Rebuild a Java app using distroless base, verify reduced CVE count
6. **ImagePolicyWebhook**: Configure admission control to validate image signatures
