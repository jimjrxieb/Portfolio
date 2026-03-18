# Playbook 03: Configuration Management
### Controls: CM-2, CM-6, CM-7, CM-8

---

## WHAT THIS COVERS

| Control | Name | What the assessor checks |
|---------|------|------------------------|
| CM-2 | Baseline Configuration | Documented, approved baseline exists for the system |
| CM-6 | Configuration Settings | Security settings are configured per approved guidance |
| CM-7 | Least Functionality | System only runs services/ports/protocols that are needed |
| CM-8 | Component Inventory | Complete, accurate, up-to-date inventory of all components |

---

## CM-2: BASELINE CONFIGURATION

### What "compliant" looks like
- Every component has a documented baseline (Dockerfile, K8s manifest, Terraform)
- Baselines are version-controlled in Git
- Deviations from baseline are detected and alerted
- Changes go through a review process before applying

### Step 1: Define the baseline in Git (GitOps)

Your baseline IS your Git repository. Everything declarative, everything versioned.

```
Required baseline artifacts:
├── k8s/
│   ├── base/                    # Kustomize base = the baseline
│   │   ├── deployment.yaml      # Container spec, security context, resources
│   │   ├── service.yaml         # Service definition
│   │   ├── networkpolicy.yaml   # Network segmentation
│   │   └── kustomization.yaml
│   └── overlays/
│       ├── dev/                 # Environment-specific overrides
│       ├── staging/
│       └── prod/
├── Dockerfile                   # Container build baseline
├── terraform/                   # Infrastructure baseline
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── .github/workflows/           # CI/CD baseline
    └── ci.yml
```

### Step 2: Enforce baseline with ArgoCD (drift detection)

```yaml
# ArgoCD Application with self-heal = baseline enforcement
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-prod
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/org/app.git
    targetRevision: main
    path: k8s/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: app-prod
  syncPolicy:
    automated:
      prune: true       # Remove resources not in Git
      selfHeal: true    # Revert manual changes to match Git
    syncOptions:
      - CreateNamespace=true
```

**Self-heal means:** if someone runs `kubectl edit` directly on the cluster, ArgoCD will detect the drift and revert it to match Git. This IS your baseline enforcement.

### Step 3: Document the baseline

Create a baseline document for the assessor:

```markdown
# System Baseline Configuration

## Last Updated: YYYY-MM-DD
## Approved By: [name]
## Git Commit: [sha]

### Container Runtime Baseline
- Base image: python:3.12-slim (pinned)
- Non-root user: appuser (UID 1000)
- Read-only root filesystem
- No capabilities (drop ALL)
- Seccomp: RuntimeDefault
- Resource limits: CPU 500m, Memory 512Mi

### Kubernetes Baseline
- Pod Security Admission: Restricted
- Network: Default-deny with explicit allows
- RBAC: Namespace-scoped, no wildcards
- ServiceAccount: Dedicated per app, no automount

### Infrastructure Baseline
- EKS version: 1.29
- Node AMI: Amazon Linux 2023 (auto-updated)
- Encryption: KMS for EBS, S3, Secrets
- Endpoint: Private only
```

---

## CM-6: CONFIGURATION SETTINGS

### What "compliant" looks like
- Security-relevant config settings follow approved guidance (CIS benchmarks, DISA STIGs)
- Settings are enforced at admission (not just documented)
- Non-compliant configs are blocked before deployment

### Step 1: Deploy admission control policies

```bash
# Apply all FedRAMP Kyverno policies
kubectl apply -f /path/to/GP-CONSULTING/07-FEDRAMP-READY/templates/policies-templates/kyverno/

# Verify they're enforcing
kubectl get clusterpolicies
# NAME                            ADMISSION   BACKGROUND   VALIDATE ACTION   READY
# disallow-privileged             true        true         Enforce           True
# disallow-privilege-escalation   true        true         Enforce           True
# require-run-as-nonroot          true        true         Enforce           True
# require-drop-all                true        true         Enforce           True
# require-resource-limits         true        true         Enforce           True
```

### Step 2: Validate IaC configurations before deploy

```bash
# Run Checkov against Terraform
checkov -d terraform/ --framework terraform --output json > checkov-terraform.json

# Run Checkov against K8s manifests
checkov -d k8s/ --framework kubernetes --output json > checkov-k8s.json

# Run Checkov against Dockerfiles
checkov -f Dockerfile --framework dockerfile --output json > checkov-dockerfile.json

# Run Conftest against K8s manifests with FedRAMP policies
conftest test k8s/base/*.yaml \
  -p /path/to/GP-CONSULTING/07-FEDRAMP-READY/templates/policies-templates/conftest/ \
  --output json > conftest-results.json
```

### Step 3: Add to CI/CD pipeline

```yaml
# .github/workflows/ci.yml — add config validation step
- name: Validate configuration compliance
  run: |
    # Block on critical misconfigurations
    checkov -d k8s/ --framework kubernetes --compact --soft-fail-on LOW
    checkov -f Dockerfile --framework dockerfile --compact --soft-fail-on LOW

    # Run FedRAMP-specific policy checks
    conftest test k8s/base/*.yaml \
      -p fedramp-policies/ \
      --fail-on-warn
```

---

## CM-7: LEAST FUNCTIONALITY

### What "compliant" looks like
- Only required services, ports, and protocols are running
- No unnecessary packages in container images
- No debug tools in production images
- Unused features are disabled

### Step 1: Audit running services

```bash
# List all services and their types
kubectl get svc -A -o custom-columns=\
"NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,PORTS:.spec.ports[*].port"

# Find NodePort services (should be none in prod)
kubectl get svc -A -o json | \
  jq -r '.items[] | select(.spec.type=="NodePort") |
    .metadata.namespace + "/" + .metadata.name'

# Find services with unnecessary ports
# Every port should be documented and justified
```

### Step 2: Minimize container images

```dockerfile
# BAD: Full OS image with hundreds of packages
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y python3 curl wget vim netcat

# GOOD: Multi-stage build with minimal runtime
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/install -r requirements.txt

FROM gcr.io/distroless/python3-debian12
WORKDIR /app
COPY --from=builder /install /usr/local/lib/python3.12/site-packages
COPY src/ ./src/
USER 1000
ENTRYPOINT ["python", "-m", "src.main"]
```

### Step 3: Scan for unnecessary packages

```bash
# Scan the image for CVEs — fewer packages = fewer CVEs
trivy image <image>:<tag> --severity CRITICAL,HIGH --format json

# Compare full vs minimal image
trivy image python:3.12        # ~500 CVEs
trivy image python:3.12-slim   # ~50 CVEs
trivy image distroless/python3 # ~5 CVEs
```

---

## CM-8: COMPONENT INVENTORY

### What "compliant" looks like
- Complete list of all system components (containers, services, libraries, cloud resources)
- Inventory is accurate and current
- Each component has an owner
- Inventory is updated when changes occur

### Step 1: Generate container inventory

```bash
# List all running container images
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u

# Generate SBOM for each image
trivy image <image>:<tag> --format cyclonedx --output sbom-<app>.json

# List all Helm releases
helm list -A -o json | jq '.[] | {namespace: .namespace, name: .name, chart: .chart, version: .app_version}'
```

### Step 2: Generate dependency inventory

```bash
# Python dependencies
pip list --format json > python-deps.json

# Node dependencies
npm ls --json --all > node-deps.json

# Go dependencies
go list -m -json all > go-deps.json

# Scan for known CVEs in dependencies
trivy fs --format json --scanners vuln . > dependency-vulns.json
```

### Step 3: Generate cloud resource inventory

```bash
# AWS resources
aws resourcegroupstaggingapi get-resources \
  --output json > aws-resource-inventory.json

# EKS cluster details
aws eks describe-cluster --name <cluster> --output json > eks-cluster-config.json

# S3 buckets
aws s3api list-buckets --query 'Buckets[*].[Name,CreationDate]' --output table

# RDS instances
aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,Engine,EngineVersion]' --output table

# EC2 instances
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value|[0]]' --output table
```

### Step 4: Maintain the inventory

```bash
# Script to regenerate inventory — run weekly or on every deploy
#!/bin/bash
# generate-inventory.sh

OUTPUT_DIR="compliance-evidence/inventory-$(date +%Y%m%d)"
mkdir -p "$OUTPUT_DIR"

echo "Generating component inventory..."

# K8s components
kubectl get pods -A -o json > "$OUTPUT_DIR/k8s-pods.json"
kubectl get svc -A -o json > "$OUTPUT_DIR/k8s-services.json"
kubectl get deployments -A -o json > "$OUTPUT_DIR/k8s-deployments.json"
kubectl get configmaps -A -o json > "$OUTPUT_DIR/k8s-configmaps.json"

# Container images
kubectl get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | \
  sort -u > "$OUTPUT_DIR/container-images.txt"

# Cloud resources
aws resourcegroupstaggingapi get-resources --output json > "$OUTPUT_DIR/aws-resources.json"

# SBOMs
while read -r image; do
  safe_name=$(echo "$image" | tr '/:' '-')
  trivy image "$image" --format cyclonedx --output "$OUTPUT_DIR/sbom-${safe_name}.json" 2>/dev/null
done < "$OUTPUT_DIR/container-images.txt"

echo "Inventory saved to $OUTPUT_DIR"
```

---

## EVIDENCE FOR THE ASSESSOR

| Evidence | Source | Control |
|----------|--------|---------|
| Git repo with all manifests | GitHub/GitLab | CM-2 |
| ArgoCD sync status (self-heal enabled) | `argocd app list` | CM-2 |
| Kyverno/Gatekeeper policy list | `kubectl get clusterpolicies` | CM-6 |
| Checkov/Conftest scan results | CI pipeline output | CM-6 |
| Minimal container images (distroless) | Dockerfile + `trivy image` output | CM-7 |
| No NodePort services in prod | `kubectl get svc` | CM-7 |
| Component inventory (pods, images, deps) | `generate-inventory.sh` output | CM-8 |
| SBOM per container | CycloneDX JSON files | CM-8 |
| Cloud resource inventory | AWS resource tagging API | CM-8 |

---

## COMPLETION CHECKLIST

```
[ ] CM-2:  All system components defined in Git (declarative baselines)
[ ] CM-2:  ArgoCD managing all environments with self-heal
[ ] CM-2:  Baseline configuration document written and approved
[ ] CM-2:  Drift detection active (ArgoCD OutOfSync alerts)
[ ] CM-6:  Kyverno policies deployed in Enforce mode
[ ] CM-6:  Checkov running in CI pipeline
[ ] CM-6:  Conftest running against K8s manifests in CI
[ ] CM-6:  CIS benchmark checks passing
[ ] CM-7:  All containers use minimal base images (slim/distroless)
[ ] CM-7:  No NodePort services in production
[ ] CM-7:  No debug tools in production images
[ ] CM-7:  Multi-stage Dockerfiles for all services
[ ] CM-8:  Container image inventory generated
[ ] CM-8:  SBOM generated per container image
[ ] CM-8:  Cloud resource inventory generated
[ ] CM-8:  Dependency inventory with CVE status
[ ] CM-8:  Inventory generation automated (weekly or per-deploy)
```
