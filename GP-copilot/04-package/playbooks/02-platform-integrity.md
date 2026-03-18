# Playbook: Platform Integrity

> Verify Kubernetes binaries haven't been tampered with. Validate the platform is what it claims to be.
>
> **When:** After specialist audit. Especially important on self-hosted clusters (k3s, kubeadm).
> **Time:** ~15 min

---

## Prerequisites

- SSH access to control plane and worker nodes (self-hosted) OR kubectl (managed)
- Gap report from [01-specialist-audit](01-specialist-audit.md)

---

## Step 1: Identify Platform

```bash
# What are we dealing with?
kubectl version -o json | jq '{server: .serverVersion.gitVersion, client: .clientVersion.gitVersion}'

# Platform type
kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}'
# Contains "k3s" → k3s
# Contains "eks" → EKS
# Clean semver → kubeadm or managed
```

| Platform | Binary verification | Node access |
|----------|-------------------|-------------|
| **k3s** | Verify k3s binary | SSH to node |
| **kubeadm** | Verify kubectl, kubeadm, kubelet | SSH to node |
| **EKS/GKE/AKS** | Managed — skip binary checks | No node access |

If managed (EKS/GKE/AKS), skip to Step 4.

---

## Step 2: Verify Binaries (Self-Hosted)

SSH to each control plane node:

```bash
# Get the version running on the node
VERSION=$(kubelet --version | awk '{print $2}')
echo "Verifying version: $VERSION"

# Verify kubectl
curl -sLO "https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubectl.sha256"
INSTALLED=$(sha256sum /usr/local/bin/kubectl 2>/dev/null || sha256sum /usr/bin/kubectl)
EXPECTED=$(cat kubectl.sha256)
INSTALLED_HASH=$(echo "$INSTALLED" | awk '{print $1}')

if [ "$INSTALLED_HASH" = "$EXPECTED" ]; then
    echo "[PASS] kubectl binary verified"
else
    echo "[FAIL] kubectl binary hash mismatch"
    echo "  Installed: $INSTALLED_HASH"
    echo "  Expected:  $EXPECTED"
fi
rm -f kubectl.sha256

# Verify kubelet
curl -sLO "https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubelet.sha256"
INSTALLED_HASH=$(sha256sum /usr/bin/kubelet | awk '{print $1}')
EXPECTED=$(cat kubelet.sha256)

if [ "$INSTALLED_HASH" = "$EXPECTED" ]; then
    echo "[PASS] kubelet binary verified"
else
    echo "[FAIL] kubelet binary hash mismatch"
fi
rm -f kubelet.sha256

# Verify kubeadm (if present)
if command -v kubeadm &>/dev/null; then
    curl -sLO "https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubeadm.sha256"
    INSTALLED_HASH=$(sha256sum /usr/bin/kubeadm | awk '{print $1}')
    EXPECTED=$(cat kubeadm.sha256)
    if [ "$INSTALLED_HASH" = "$EXPECTED" ]; then
        echo "[PASS] kubeadm binary verified"
    else
        echo "[FAIL] kubeadm binary hash mismatch"
    fi
    rm -f kubeadm.sha256
fi
```

> **Reference:** `04-KUBESTER/reference/cks/07-binary-verification.md` for full details including cosign image verification.

---

## Step 3: Verify Static Pod Manifests

On control plane nodes, verify the static pod manifests haven't been modified:

```bash
# Check manifest directory
ls -la /etc/kubernetes/manifests/

# Verify expected files exist
for MANIFEST in kube-apiserver.yaml kube-controller-manager.yaml kube-scheduler.yaml etcd.yaml; do
    if [ -f "/etc/kubernetes/manifests/$MANIFEST" ]; then
        echo "[PASS] $MANIFEST exists"
        # Check file permissions (should be 600 or 644, owned by root)
        PERMS=$(stat -c '%a %U' "/etc/kubernetes/manifests/$MANIFEST")
        echo "       Permissions: $PERMS"
    else
        echo "[WARN] $MANIFEST not found (may be managed differently on this platform)"
    fi
done

# Check for unexpected files
EXTRA=$(ls /etc/kubernetes/manifests/ | grep -v -E 'kube-apiserver|kube-controller-manager|kube-scheduler|etcd')
if [ -n "$EXTRA" ]; then
    echo "[WARN] Unexpected manifests found: $EXTRA"
fi
```

---

## Step 4: Verify Container Images (All Platforms)

```bash
# List all images running in the cluster
kubectl get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u

# Check for images from untrusted registries
kubectl get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u | grep -v -E 'registry.k8s.io|docker.io/library|gcr.io|quay.io|ghcr.io'

# Check for :latest or untagged images
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[]?.image | test(":latest$") or (contains(":") | not)) | "\(.metadata.namespace)/\(.metadata.name): \(.spec.containers[].image)"'
```

If untrusted images or :latest found, log them for [09-supply-chain-perfection](09-supply-chain-perfection.md).

---

## Step 5: Verify Certificate Expiry

```bash
# Check API server cert
kubeadm certs check-expiration 2>/dev/null || echo "kubeadm not available — check manually"

# Manual check (works on any platform)
kubectl get --raw /healthz/poststarthook/start-kube-apiserver-admission-initializer 2>/dev/null

# Check specific certs if accessible
for CERT in /etc/kubernetes/pki/*.crt; do
    EXPIRY=$(openssl x509 -enddate -noout -in "$CERT" 2>/dev/null | cut -d= -f2)
    echo "$CERT — expires: $EXPIRY"
done
```

---

## Outputs

- Binary verification: PASS/FAIL per node
- Unexpected images or registries list
- Certificate expiry dates
- Any findings feed into the specific playbooks that follow

---

## Next

→ [03-apiserver-etcd.md](03-apiserver-etcd.md) — Harden API server flags and secure etcd
