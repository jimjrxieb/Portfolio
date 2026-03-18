# CKS: Binary Verification

Verify platform binaries before deploying. This is about ensuring the Kubernetes binaries you run haven't been tampered with.

## What You Need to Know

- Download binaries from official sources
- Verify checksums (sha256sum / sha512sum)
- Compare against published hashes
- Applies to: kubectl, kubeadm, kubelet, etcd, any K8s component

## CKS Exam Quick Reference

### Verify kubectl
```bash
# 1. Get current version
VERSION=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion')
# Or specify directly:
VERSION="v1.30.0"

# 2. Download binary
curl -LO "https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubectl"

# 3. Download checksum
curl -LO "https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubectl.sha256"

# 4. Verify
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
# Expected output: kubectl: OK

# 5. If OK, install
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
```

### Verify kubeadm
```bash
VERSION="v1.30.0"

curl -LO "https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubeadm"
curl -LO "https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubeadm.sha256"

echo "$(cat kubeadm.sha256)  kubeadm" | sha256sum --check
# kubeadm: OK
```

### Verify kubelet
```bash
VERSION="v1.30.0"

curl -LO "https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubelet"
curl -LO "https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubelet.sha256"

echo "$(cat kubelet.sha256)  kubelet" | sha256sum --check
# kubelet: OK
```

### Verify etcd
```bash
ETCD_VERSION="v3.5.12"

curl -LO "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz"

# etcd publishes SHA256 in release notes — compare manually
sha256sum "etcd-${ETCD_VERSION}-linux-amd64.tar.gz"
# Compare output against the hash on the GitHub release page
```

### Verify an Already-Installed Binary
```bash
# If you suspect a binary has been tampered with on a running node:

# 1. Get the hash of the installed binary
sha256sum /usr/bin/kubectl

# 2. Download the known-good binary for the same version
VERSION=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion')
curl -LO "https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubectl.sha256"

# 3. Compare
INSTALLED_HASH=$(sha256sum /usr/bin/kubectl | awk '{print $1}')
EXPECTED_HASH=$(cat kubectl.sha256)

if [ "$INSTALLED_HASH" = "$EXPECTED_HASH" ]; then
    echo "VERIFIED: Binary is authentic"
else
    echo "WARNING: Binary hash mismatch — possible tampering"
    echo "  Installed: $INSTALLED_HASH"
    echo "  Expected:  $EXPECTED_HASH"
fi
```

### Verify Container Images (cosign)
```bash
# Kubernetes images are signed with cosign starting v1.24+

# Install cosign
curl -LO https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
chmod +x cosign-linux-amd64
sudo mv cosign-linux-amd64 /usr/local/bin/cosign

# Verify a K8s image
cosign verify registry.k8s.io/kube-apiserver:v1.30.0 \
  --certificate-identity krel-staging@k8s-releng-prod.iam.gserviceaccount.com \
  --certificate-oidc-issuer https://accounts.google.com

# Verify any signed image
cosign verify <image> --key <public-key>
```

### Exam Pattern

The exam will typically:
1. Give you a binary on a node
2. Ask you to verify it against the official release
3. You download the checksum, compare, report if it matches

Key commands to memorize:
```bash
# Download + verify pattern (3 lines)
curl -LO "https://dl.k8s.io/release/VERSION/bin/linux/amd64/BINARY"
curl -LO "https://dl.k8s.io/release/VERSION/bin/linux/amd64/BINARY.sha256"
echo "$(cat BINARY.sha256)  BINARY" | sha256sum --check
```

## Practice Scenarios

1. **Verify kubectl**: Download kubectl for your cluster version, verify the checksum
2. **Detect tampering**: Replace kubectl with a dummy file, run verification, observe failure
3. **Verify on node**: SSH to a node, verify kubelet binary against official release
4. **Image verification**: Use cosign to verify a Kubernetes container image signature
