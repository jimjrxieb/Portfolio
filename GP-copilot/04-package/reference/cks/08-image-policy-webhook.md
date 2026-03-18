# CKS: ImagePolicyWebhook Admission Controller

The built-in Kubernetes admission controller that validates images against an external webhook before allowing pods to run. This is different from Kyverno/Gatekeeper — it's a native API server plugin.

## When to Use What

| Tool | Type | Best For |
|------|------|----------|
| **ImagePolicyWebhook** | Native admission plugin | Image validation against external signing service |
| **Kyverno** | External admission controller | Policy-as-code, wide coverage, easy to use |
| **Gatekeeper** | External admission controller | OPA/Rego policies, complex logic |

GP-CONSULTING uses Kyverno/Gatekeeper for day-to-day admission control. ImagePolicyWebhook is specifically for CKS exam and for organizations with dedicated image signing infrastructure.

## Architecture

```
Pod create request
  → API Server
    → ImagePolicyWebhook admission plugin
      → HTTPS POST to external webhook server
        → Webhook checks image signature/policy
          → Returns allow/deny
            → API Server accepts/rejects pod
```

## CKS Exam Quick Reference

### Step 1: Webhook Server (Already Running)

The exam gives you a webhook server. You need to know:
- It listens on HTTPS (e.g., `https://image-review.example.com:8443/validate`)
- It expects `ImageReview` objects
- It returns `allowed: true/false`

### Step 2: Create Kubeconfig for Webhook

```yaml
# /etc/kubernetes/admission/webhook-kubeconfig.yaml
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

### Step 3: Create Admission Configuration

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

**Critical setting**: `defaultAllow: false` means if the webhook is unreachable, ALL image pulls are denied. This is the secure default for CKS.

### Step 4: Enable in API Server

Edit `/etc/kubernetes/manifests/kube-apiserver.yaml`:

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    # Add ImagePolicyWebhook to admission plugins
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
    # Point to admission config
    - --admission-control-config-file=/etc/kubernetes/admission/admission-config.yaml
    volumeMounts:
    # Mount the admission config directory
    - name: admission-config
      mountPath: /etc/kubernetes/admission
      readOnly: true
  volumes:
  - name: admission-config
    hostPath:
      path: /etc/kubernetes/admission
      type: DirectoryOrCreate
```

### Step 5: Verify

```bash
# Wait for API server to restart (kubelet watches manifests)
# Check API server is running
kubectl get pods -n kube-system -l component=kube-apiserver

# Test with a disallowed image
kubectl run test --image=untrusted-registry.com/malicious:latest
# Expected: admission webhook denied the request

# Test with an allowed image
kubectl run test --image=registry.k8s.io/nginx:1.25
# Expected: pod created (if webhook approves)

# Check API server logs for webhook calls
kubectl logs -n kube-system kube-apiserver-<node> | grep -i imagepolicy
```

### File Layout on the Node

```
/etc/kubernetes/
├── manifests/
│   └── kube-apiserver.yaml          # API server static pod (EDIT THIS)
├── admission/
│   ├── admission-config.yaml        # AdmissionConfiguration (CREATE THIS)
│   ├── webhook-kubeconfig.yaml      # Kubeconfig for webhook (CREATE THIS)
│   ├── webhook-ca.crt               # CA cert for webhook server (GIVEN)
│   ├── api-server-client.crt        # Client cert for API server (GIVEN)
│   └── api-server-client.key        # Client key for API server (GIVEN)
└── pki/
    └── ...                          # Existing K8s PKI (don't touch)
```

### Troubleshooting

```bash
# API server won't start after edit
# Check manifest syntax
cat /etc/kubernetes/manifests/kube-apiserver.yaml | python3 -c "import sys,yaml; yaml.safe_load(sys.stdin)"

# Check container logs directly
crictl ps -a | grep kube-apiserver
crictl logs <container-id>

# Common mistakes:
# 1. Wrong path in --admission-control-config-file
# 2. Missing volume mount for /etc/kubernetes/admission
# 3. Typo in admission plugin name (case-sensitive: ImagePolicyWebhook)
# 4. Wrong kubeConfigFile path in admission-config.yaml
# 5. Certificate files not readable

# Verify files exist
ls -la /etc/kubernetes/admission/
```

### ImageReview API (What the Webhook Receives)

```json
{
  "apiVersion": "imagepolicy.k8s.io/v1alpha1",
  "kind": "ImageReview",
  "spec": {
    "containers": [
      {
        "image": "nginx:1.25"
      }
    ],
    "namespace": "default"
  }
}
```

### ImageReview Response (What the Webhook Returns)

```json
{
  "apiVersion": "imagepolicy.k8s.io/v1alpha1",
  "kind": "ImageReview",
  "status": {
    "allowed": true,
    "reason": "Image signature verified"
  }
}
```

## Comparison with Kyverno Image Verification

For production use, GP-CONSULTING uses Kyverno policies:
- `02-CLUSTER-HARDENING/templates/policies/kyverno/disallow-latest-tag.yaml`
- `02-CLUSTER-HARDENING/templates/policies/kyverno/require-semver-tags.yaml`
- `02-CLUSTER-HARDENING/templates/policies/kyverno/require-runtime-class-untrusted.yaml`

These are easier to manage, don't require modifying API server manifests, and support policy-as-code in git.

ImagePolicyWebhook is a lower-level mechanism for organizations that need native API server integration with an image signing service (like Notary or sigstore).

## Practice Scenarios

1. **Full setup**: Given a webhook server URL and certs, configure ImagePolicyWebhook end-to-end
2. **defaultAllow**: Test with `defaultAllow: true` vs `false` — stop the webhook, observe behavior
3. **Troubleshoot**: API server won't start after enabling ImagePolicyWebhook — find and fix the error
4. **Compare**: Block `:latest` tag using both ImagePolicyWebhook and Kyverno, note the differences
