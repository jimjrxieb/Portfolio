#!/bin/bash
# Kubernetes CIS Benchmark Remediation Script
# Fixes for High Severity Issues (4.1.1, 4.1.5, 4.1.9, 4.1.10)

set -e

echo "🔒 Applying CIS Kubernetes Benchmark Security Fixes..."

# Fix 4.1.1: Set kubelet service file permissions to 644
echo "Fixing 4.1.1: Setting kubelet service file permissions..."
if [ -f /etc/systemd/system/kubelet.service.d/10-kubeadm.conf ]; then
    chmod 644 /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    echo "✅ Kubelet service file permissions set to 644"
else
    echo "⚠️ Kubelet service file not found at expected location"
fi

# Fix 4.1.5: Set kubelet.conf file permissions to 644
echo "Fixing 4.1.5: Setting kubelet.conf permissions..."
if [ -f /etc/kubernetes/kubelet.conf ]; then
    chmod 644 /etc/kubernetes/kubelet.conf
    echo "✅ kubelet.conf permissions set to 644"
else
    echo "⚠️ kubelet.conf not found at /etc/kubernetes/"
fi

# Fix 4.1.6: Set kubelet.conf ownership to root:root
echo "Fixing 4.1.6: Setting kubelet.conf ownership..."
if [ -f /etc/kubernetes/kubelet.conf ]; then
    chown root:root /etc/kubernetes/kubelet.conf
    echo "✅ kubelet.conf ownership set to root:root"
fi

# Fix 4.1.7: Set client CA file permissions
echo "Fixing 4.1.7: Setting client CA file permissions..."
if [ -f /etc/kubernetes/pki/ca.crt ]; then
    chmod 644 /etc/kubernetes/pki/ca.crt
    echo "✅ Client CA file permissions set to 644"
fi

# Fix 4.1.8: Set client CA file ownership
echo "Fixing 4.1.8: Setting client CA file ownership..."
if [ -f /etc/kubernetes/pki/ca.crt ]; then
    chown root:root /etc/kubernetes/pki/ca.crt
    echo "✅ Client CA file ownership set to root:root"
fi

# Fix 4.1.9: Set kubelet config file permissions to 644
echo "Fixing 4.1.9: Setting kubelet config permissions..."
if [ -f /var/lib/kubelet/config.yaml ]; then
    chmod 644 /var/lib/kubelet/config.yaml
    echo "✅ Kubelet config permissions set to 644"
else
    echo "⚠️ Kubelet config not found at /var/lib/kubelet/config.yaml"
fi

# Fix 4.1.10: Set kubelet config ownership to root:root
echo "Fixing 4.1.10: Setting kubelet config ownership..."
if [ -f /var/lib/kubelet/config.yaml ]; then
    chown root:root /var/lib/kubelet/config.yaml
    echo "✅ Kubelet config ownership set to root:root"
fi

# Create secure kubelet configuration directory if it doesn't exist
mkdir -p /var/lib/kubelet/pki
chmod 755 /var/lib/kubelet/pki
chown root:root /var/lib/kubelet/pki

echo "🔒 CIS Kubernetes security hardening complete!"
echo "📄 Next steps:"
echo "1. Copy the kubelet-config.yaml to /var/lib/kubelet/config.yaml"
echo "2. Update kubelet service to use --config=/var/lib/kubelet/config.yaml"
echo "3. Restart kubelet service: systemctl daemon-reload && systemctl restart kubelet"