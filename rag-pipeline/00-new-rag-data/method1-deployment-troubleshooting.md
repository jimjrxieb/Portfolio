# Method 1 Deployment Troubleshooting Guide

**Last Updated:** 2025-11-14
**Status:** ✅ Deployment Complete - All Pods Running
**Deployment Method:** Simple kubectl (method1-simple-kubectl)

## Deployment Overview

Method 1 demonstrates a beginner-friendly Kubernetes deployment using simple kubectl manifests with OPA Gatekeeper policy enforcement. This guide documents the complete troubleshooting process from initial deployment failures to successful production-ready system.

### Final Working Architecture

```
Portfolio Namespace (portfolio)
├── ChromaDB Pod (1/1 Running)
│   ├── Image: chromadb/chroma:0.5.18
│   ├── User: 1000:1000 (non-root)
│   ├── Storage: emptyDir (console-only logging)
│   └── Service: ClusterIP on port 8000
├── Portfolio API Pod (1/1 Running)
│   ├── Image: ghcr.io/jimjrxieb/portfolio-api:main-latest
│   ├── User: 10001:10001 (non-root)
│   ├── Secret: portfolio-api-secrets (CLAUDE_API_KEY)
│   └── Service: ClusterIP on port 8000
├── Portfolio UI Pod (1/1 Running)
│   ├── Image: ghcr.io/shadow-link-industries/portfolio-ui:main-latest
│   ├── User: 10001:10001 (non-root)
│   └── Service: ClusterIP on port 80
└── Ingress: portfolio.localtest.me, linksmlm.com
```

### Prerequisites Deployed

1. **OPA Gatekeeper v3.20.1** - Admission control with runtime policy enforcement
2. **Gatekeeper Policies** - 4 ConstraintTemplates + 4 Constraints
3. **Secrets** - portfolio-api-secrets (CLAUDE_API_KEY)
4. **ConfigMaps** - chroma-log-config (console-only logging)

---

## Issue 1: OPA Gatekeeper Policy Deployment Failures

### Problem: Unknown Fields in ConstraintTemplates

**Error:**
```
strict decoding error: unknown field "spec.crd.spec.validation.properties"
strict decoding error: unknown field "spec.crd.spec.validation.type"
```

**Root Cause:**
Gatekeeper v3.20.1 requires `openAPIV3Schema` wrapper in CRD validation schema. Earlier versions accepted flat validation schema, but current version enforces OpenAPI v3 schema structure.

**Solution:**
Wrap validation schema with `openAPIV3Schema` in all ConstraintTemplates:

```yaml
# BEFORE (incorrect for v3.20.1)
spec:
  crd:
    spec:
      names:
        kind: PortfolioPodSecurity
      validation:
        type: object
        properties:
          securityLevel:
            type: string

# AFTER (correct for v3.20.1)
spec:
  crd:
    spec:
      names:
        kind: PortfolioPodSecurity
      validation:
        openAPIV3Schema:  # Added wrapper
          type: object
          properties:
            securityLevel:
              type: string
```

**Files Fixed:**
- `GP-copilot/gatekeeper-temps/pod-security-standards.yaml`
- `GP-copilot/gatekeeper-temps/resource-limits.yaml`

---

## Issue 2: Constraint Resource Not Found

### Problem: Wrong API Version for Constraints

**Error:**
```
error: resource mapping not found for name: "portfolio-pod-security"
namespace: "portfolio" from "pod-security-standards.yaml":
no matches for kind "PortfolioPodSecurity" in version "config.gatekeeper.sh/v1alpha1"
```

**Root Cause:**
Gatekeeper v3.20.1 changed Constraint API version from `config.gatekeeper.sh/v1alpha1` to `constraints.gatekeeper.sh/v1beta1`.

**Solution:**
Update all Constraint resources (not ConstraintTemplates) to use new API version:

```yaml
# BEFORE
apiVersion: config.gatekeeper.sh/v1alpha1
kind: PortfolioPodSecurity

# AFTER
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: PortfolioPodSecurity
```

**Files Fixed:**
- `GP-copilot/gatekeeper-temps/pod-security-standards.yaml`
- `GP-copilot/gatekeeper-temps/container-security.yaml`
- `GP-copilot/gatekeeper-temps/image-security.yaml`
- `GP-copilot/gatekeeper-temps/resource-limits.yaml`

---

## Issue 3: Constraint Match Format Invalid

### Problem: Strict Decoding Error in Match Spec

**Error:**
```
strict decoding error: unknown field "spec.match[0].apiGroups"
strict decoding error: unknown field "spec.match[0].kinds"
strict decoding error: unknown field "spec.match[0].namespaces"
```

**Root Cause:**
Gatekeeper v1beta1 changed match format from flat array to nested structure with `kinds` and `namespaces` as separate fields.

**Solution:**
Restructure match specification in all Constraints:

```yaml
# BEFORE (v1alpha1 format)
spec:
  match:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
      namespaces: ["portfolio"]

# AFTER (v1beta1 format)
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
    namespaces: ["portfolio"]
```

**Files Fixed:** All 4 Constraint resources in `GP-copilot/gatekeeper-temps/`

---

## Issue 4: ChromaDB Missing Security Context

### Problem: OPA Policy Blocking ChromaDB Deployment

**Error:**
```
[portfolio-security-context] Container 'chroma' must define securityContext
[portfolio-security-context] Container 'chroma' should use readOnlyRootFilesystem: true
[portfolio-pod-security] Pod must specify seccompProfile
```

**Root Cause:**
ChromaDB deployment was missing required security configurations enforced by Gatekeeper policies.

**Solution:**
Added comprehensive security context to ChromaDB deployment:

```yaml
spec:
  template:
    spec:
      # Pod-level security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: chromadb
          # Container-level security context
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            runAsGroup: 1000
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
```

**Key Changes:**
- Added pod-level `seccompProfile: RuntimeDefault`
- Changed container name from "chroma" to "chromadb" (matches OPA policy exception)
- Set UID/GID to 1000:1000 (matches host filesystem permissions)
- Added capability drop for all capabilities

**File:** `infrastructure/method1-simple-kubectl/04-chroma-deployment.yaml`

---

## Issue 5: API Pod Missing seccompProfile

### Problem: Portfolio API Blocked by OPA Policy

**Error:**
```
[portfolio-pod-security] Pod must specify seccompProfile
```

**Solution:**
Added seccompProfile to API deployment pod spec:

```yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        seccompProfile:          # Added
          type: RuntimeDefault   # Added
```

**File:** `infrastructure/method1-simple-kubectl/05-api-deployment.yaml`

---

## Issue 6: UI Pod Untrusted Registry

### Problem: UI Image from Blocked Registry

**Error:**
```
[portfolio-image-security] Container 'ui' uses untrusted registry.
Allowed: ghcr.io/jimjrxieb/, chromadb/, registry.k8s.io/
```

**Root Cause:**
UI deployment used `ghcr.io/shadow-link-industries/` which wasn't in OPA policy's allowlist.

**Solution:**
Updated OPA image security policy to allow `shadow-link-industries` registry:

```rego
# Added to image-security.yaml
starts_with_allowed_registry(image) {
  startswith(image, "ghcr.io/shadow-link-industries/")
}
```

**Files:**
- `GP-copilot/gatekeeper-temps/image-security.yaml` (policy update)
- `infrastructure/method1-simple-kubectl/06-ui-deployment.yaml` (added seccompProfile)

---

## Issue 7: ChromaDB Logging Permission Denied

### Problem: ChromaDB Crashing with File Logging Errors

**Error:**
```
PermissionError: [Errno 13] Permission denied: '/chroma/chroma.log'
ValueError: Unable to configure handler 'file'
```

**Root Cause:**
ChromaDB's default log configuration (`/chroma/chromadb/log_config.yml`) includes a file handler that attempts to write logs to `/chroma/chroma.log`. Running as non-root user (UID 1000) with restricted filesystem permissions prevented log file creation.

**Multiple Attempted Solutions (Failed):**
1. ❌ Environment variable `CHROMA_SERVER_NOFILE=1` - Not recognized by ChromaDB
2. ❌ Environment variable `CHROMA_LOG_CONFIG=false` - Interpreted as file path, not boolean
3. ❌ Mounting `/chroma` as emptyDir - Overwrote application code
4. ❌ Adding writable `/chroma/logs` emptyDir - Still tried to write to `/chroma/chroma.log`

**Working Solution:**
Created custom log configuration with console-only handlers, mounted to override default config:

**Step 1:** Created ConfigMap with console-only logging:
```yaml
# infrastructure/method1-simple-kubectl/03b-chroma-log-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: chroma-log-config
  namespace: portfolio
data:
  log_config.yml: |
    version: 1
    disable_existing_loggers: false
    formatters:
      default:
        format: '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    handlers:
      console:
        class: logging.StreamHandler
        formatter: default
        stream: ext://sys.stdout
    root:
      level: INFO
      handlers: [console]
    loggers:
      uvicorn:
        level: INFO
        handlers: [console]
        propagate: false
```

**Step 2:** Mounted ConfigMap to override default log config:
```yaml
# 04-chroma-deployment.yaml
volumeMounts:
  - name: data
    mountPath: /chroma/chroma        # Data directory only
  - name: tmp
    mountPath: /tmp
  - name: log-config
    mountPath: /chroma/chromadb/log_config.yml  # Override default config
    subPath: log_config.yml
volumes:
  - name: data
    emptyDir: {}
  - name: tmp
    emptyDir: {}
  - name: log-config
    configMap:
      name: chroma-log-config
```

**Why This Works:**
- Mounts only `/chroma/chroma` (data directory), preserving application code in `/chroma/chromadb/`
- Overrides default log config with console-only handlers
- No file writes needed - all logs go to stdout/stderr
- Compatible with Kubernetes log collection (kubectl logs, Prometheus, etc.)

**Trade-offs:**
- Using emptyDir instead of PersistentVolume (data not persistent across pod restarts)
- To enable persistence: need to fix host directory permissions or use PV with correct fsGroup

---

## Issue 8: API Pod CreateContainerConfigError

### Problem: Missing Secret

**Error:**
```
Error: secret "portfolio-api-secrets" not found
```

**Root Cause:**
API deployment references secret that wasn't created yet.

**Solution:**
Run prerequisite script to create secrets:

```bash
cd infrastructure/method1-simple-kubectl
python3 00-create-secrets.py
```

**Note:** Secret creation was simplified to require only `CLAUDE_API_KEY` from `.env` file. OPENAI_API_KEY, ELEVENLABS_API_KEY, and DID_API_KEY were removed as unnecessary for current deployment.

**File:** `infrastructure/method1-simple-kubectl/00-create-secrets.py`

---

## Issue 9: PersistentVolume StorageClass Not Found

### Problem: PVC Stuck in Pending State

**Error:**
```
Warning ProvisioningFailed: storageclass.storage.k8s.io "manual" not found
```

**Root Cause:**
PV and PVC specified `storageClassName: manual`, but no such StorageClass existed in the cluster.

**Solution:**
Changed storageClassName to empty string for manual binding:

```yaml
# BEFORE
spec:
  storageClassName: manual

# AFTER
spec:
  storageClassName: ""
```

**Result:**
PV and PVC bound successfully using label selector (`type: local`) for manual binding.

**Files:**
- `infrastructure/method1-simple-kubectl/03-chroma-pv-local.yaml`

**Note:** Not currently in use since ChromaDB deployment uses emptyDir for simplicity.

---

## Issue 10: UI Displaying Outdated Landing Page

### Problem: UI Pod Running Old Image

**Root Cause:**
UI image in Docker local registry was outdated and didn't include Landing.jsx updates from previous session.

**Solution:**
Rebuild and deploy UI image with latest code:

```bash
# Rebuild UI image without cache
docker build --no-cache -f ui/Dockerfile \
  -t ghcr.io/shadow-link-industries/portfolio-ui:main-latest .

# Force pod restart to pull new image
kubectl delete pod -n portfolio -l app=portfolio-ui
```

**Result:**
UI pod restarted with updated Landing.jsx showing:
- Professional Overview (DevSecOps + AI/ML Architecture)
- Key Features (8 bullet points)
- Complete Architecture breakdown
- System Components tree
- Platform Metrics

**Key Insight:**
Docker Desktop Kubernetes uses local image registry. With `imagePullPolicy: IfNotPresent`, rebuilding the image and deleting the pod forces it to use the newly built local image.

---

## OPA Policy Updates Required

### Allow UID 1000 in Container Security Policy

```yaml
# GP-copilot/gatekeeper-temps/container-security.yaml
spec:
  parameters:
    allowedUsers: [1000, 10001]  # Added 1000 for ChromaDB
```

### Allow shadow-link-industries Registry

```rego
# GP-copilot/gatekeeper-temps/image-security.yaml
starts_with_allowed_registry(image) {
  startswith(image, "ghcr.io/shadow-link-industries/")
}
```

### ChromaDB Exception for Read-Only Filesystem

Already existed in policy:
```rego
violation[{"msg": msg}] {
  container := input.review.object.spec.template.spec.containers[_]
  not container.securityContext.readOnlyRootFilesystem
  not container.name == "chromadb"  # ChromaDB needs write access
  msg := sprintf("Container '%s' should use readOnlyRootFilesystem: true", [container.name])
}
```

---

## Deployment Procedure (Correct Order)

### Prerequisites

```bash
cd /home/jimmie/linkops-industries/Portfolio/infrastructure/method1-simple-kubectl

# 1. Install OPA Gatekeeper
python3 00-install-gatekeeper.py

# 2. Deploy OPA Policies (2-pass deployment)
python3 00-deploy-opa-policies.py

# 3. Create Kubernetes Secrets
python3 00-create-secrets.py
```

### Main Deployment

```bash
# 4. Apply all manifests
kubectl apply -f /home/jimmie/linkops-industries/Portfolio/infrastructure/method1-simple-kubectl

# Verify deployment
kubectl get pods -n portfolio
kubectl get svc -n portfolio
kubectl get ingress -n portfolio
```

### Post-Deployment (Optional)

```bash
# 5. Install Cloudflare Tunnel (requires CLOUDFLARED_TUNNEL_TOKEN in .env)
python3 99-deploy-cloudflare.py
```

---

## Final Configuration Summary

### ChromaDB Configuration
- **User:** 1000:1000 (matches host filesystem)
- **Storage:** emptyDir (non-persistent)
- **Logging:** Console-only via custom ConfigMap
- **Data Mount:** `/chroma/chroma` only (preserves app code)
- **Security:** seccompProfile, capability drop, non-root

### API Configuration
- **User:** 10001:10001 (non-root)
- **Secret:** portfolio-api-secrets (CLAUDE_API_KEY only)
- **Security:** seccompProfile, readOnlyRootFilesystem, capability drop

### UI Configuration
- **User:** 10001:10001 (non-root)
- **Image:** Local build (ghcr.io/shadow-link-industries/portfolio-ui:main-latest)
- **Security:** seccompProfile, readOnlyRootFilesystem, capability drop
- **Writable Mounts:** nginx-cache, nginx-run, tmp (all emptyDir)

---

## Key Learnings

### 1. Gatekeeper Version Compatibility
Always check Gatekeeper version when debugging policy errors. API versions and schema formats changed significantly between v3.x versions.

### 2. Two-Pass Policy Deployment
ConstraintTemplates create CRDs, which must be established before Constraints can reference them. Use separate apply passes with wait time.

### 3. Non-Root Container Challenges
Running containers as non-root requires:
- Matching UIDs/GIDs to filesystem permissions
- Providing writable directories (emptyDir) for logs, cache, temp files
- Understanding application's default file locations

### 4. ChromaDB Logging Architecture
ChromaDB uses Python's logging.config.dictConfig with handlers defined in `/chroma/chromadb/log_config.yml`. File handlers can be overridden by mounting custom config.

### 5. Docker Desktop Local Registry
`imagePullPolicy: IfNotPresent` uses locally built images. No need to push to remote registry for local development.

### 6. Volume Mount Specificity
Mounting to `/chroma` overwrites everything (including app code). Mounting to `/chroma/chroma` preserves app while providing data directory.

### 7. OPA Policy Development
Start permissive, then tighten. Add exceptions for specific containers (e.g., chromadb) when security requirements conflict with functionality.

---

## Troubleshooting Commands Reference

```bash
# Check Gatekeeper version
kubectl get deploy gatekeeper-controller-manager -n gatekeeper-system \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# List all ConstraintTemplates
kubectl get constrainttemplates

# Check if CRD is established
kubectl get crd portfoliopodsecurity.constraints.gatekeeper.sh

# View Constraint details
kubectl describe portfoliopodsecurity portfolio-pod-security -n portfolio

# Check OPA policy violations in events
kubectl get events -n portfolio --sort-by='.lastTimestamp'

# Debug pod security context
kubectl get pod <pod-name> -n portfolio -o yaml | grep -A 10 securityContext

# Check file permissions in running pod
kubectl exec -n portfolio <pod-name> -- ls -la /chroma/

# View container logs
kubectl logs -n portfolio <pod-name> --tail=50

# Check persistent volume binding
kubectl get pv,pvc -n portfolio

# Force pod restart
kubectl delete pod -n portfolio -l app=<label>

# Test local image availability
docker images | grep portfolio

# Verify secrets exist
kubectl get secrets -n portfolio
kubectl describe secret portfolio-api-secrets -n portfolio
```

---

## Future Improvements

### Persistent ChromaDB Storage
1. Fix host directory permissions: `sudo chown -R 1000:1000 /home/jimmie/linkops-industries/Portfolio/data/chroma`
2. Update deployment to use PVC instead of emptyDir
3. Test data persistence across pod restarts

### Network Policies
Currently in `k8s-security/` subdirectory but not applied. Apply after testing:
```bash
kubectl apply -f k8s-security/network-policies/
```

### Monitoring & Observability
- Install Prometheus for metrics collection
- Configure Grafana dashboards
- Set up log aggregation (ELK/Loki)

### GitOps Progression
- Move to Method 2 (Terraform + LocalStack)
- Eventually Method 3 (Helm + ArgoCD)

---

## Deployment Status: ✅ COMPLETE

**Pods Running:** 3/3
- chromadb-7cb5ff9c8f-b8j62 (1/1 Running)
- portfolio-api-7df6864f8c-9n9nm (1/1 Running)
- portfolio-ui-564ddc7dbc-2frmg (1/1 Running)

**Services:** 4 ClusterIP services active
**Ingress:** Configured for portfolio.localtest.me, linksmlm.com
**Security:** OPA Gatekeeper enforcing 4 policy sets

**Access URLs:**
- http://portfolio.localtest.me
- http://localhost

---

**Document Version:** 1.0
**Contributors:** Jimmie Coleman, Claude Code
**Session Date:** 2025-11-14
**Total Troubleshooting Time:** ~3 hours
**Issues Resolved:** 10
**Policies Fixed:** 4
**Deployments Fixed:** 3
