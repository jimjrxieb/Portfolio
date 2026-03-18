# CKS Domain 3: System Hardening (15%)

Minimize host OS footprint. Minimize IAM roles. Minimize external access to the network. Use kernel hardening tools (AppArmor, seccomp).

## What You Need to Know

- AppArmor profiles (enforce, complain, unconfined)
- Seccomp profiles (RuntimeDefault, Localhost, Unconfined)
- Node hardening (CIS benchmark, sysctl, kernel modules)
- Kubelet security configuration
- Minimize OS attack surface

## Pre-Built Tools (Already in GP-CONSULTING)

### Policies
| Resource | Location | What It Provides |
|----------|----------|-----------------|
| `require-seccomp-strict.yaml` | `02-CLUSTER-HARDENING/templates/policies/kyverno/` | Enforce RuntimeDefault seccomp |
| `require-apparmor-profile.yaml` | `02-CLUSTER-HARDENING/templates/policies/kyverno/` | Enforce AppArmor profiles |
| Seccomp profile templates | `02-CLUSTER-HARDENING/templates/remediation/seccomp-profiles.yaml` | Profile definitions |
| AppArmor profile templates | `02-CLUSTER-HARDENING/templates/remediation/apparmor-profiles.yaml` | Profile definitions |
| RuntimeClass template | `02-CLUSTER-HARDENING/templates/remediation/runtime-class.yaml` | gVisor/kata config |

### Watchers
| Watcher | Location | What It Detects |
|---------|----------|----------------|
| `watch-seccomp.sh` | `03-DEPLOY-RUNTIME/watchers/` | Pods with seccomp Unconfined or missing |
| `watch-apparmor.sh` | `03-DEPLOY-RUNTIME/watchers/` | Pods with apparmor Unconfined or missing |

### Node Hardening (Ansible)
| Playbook | Location | What It Hardens |
|----------|----------|----------------|
| `cis-node-hardening.yml` | `02-CLUSTER-HARDENING/playbooks/ansible/` | Sysctl, kernel modules, file permissions |
| `kubelet-hardening.yml` | `02-CLUSTER-HARDENING/playbooks/ansible/` | Kubelet auth, ports, TLS config |
| `auditd-config.yml` | `02-CLUSTER-HARDENING/playbooks/ansible/` | K8s-specific auditd rules |

### Playbooks
| Playbook | Location | When to Use |
|----------|----------|-------------|
| `02-node-hardening.md` | `02-CLUSTER-HARDENING/playbooks/` | CIS node hardening with Ansible |

## CKS Exam Quick Reference

### AppArmor

```bash
# Check AppArmor status on node
aa-status

# Load a profile
apparmor_parser -q /etc/apparmor.d/custom-profile

# Profile for blocking writes
cat <<'EOF' > /etc/apparmor.d/k8s-deny-write
#include <tunables/global>
profile k8s-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>
  file,
  deny /tmp/** w,
  deny /var/log/** w,
}
EOF
apparmor_parser -q /etc/apparmor.d/k8s-deny-write
```

Apply to a pod:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secured-pod
  annotations:
    container.apparmor.security.beta.kubernetes.io/app: localhost/k8s-deny-write
spec:
  containers:
  - name: app
    image: nginx:1.25
```

### Seccomp

```yaml
# Pod with RuntimeDefault seccomp (exam default)
apiVersion: v1
kind: Pod
metadata:
  name: secured-pod
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.25
```

```yaml
# Pod with custom seccomp profile
# Profile must exist at /var/lib/kubelet/seccomp/profiles/custom.json
apiVersion: v1
kind: Pod
metadata:
  name: custom-seccomp-pod
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/custom.json
  containers:
  - name: app
    image: nginx:1.25
```

### Minimize Host OS Footprint
```bash
# Disable unnecessary services
systemctl disable --now snapd
systemctl disable --now avahi-daemon

# Remove unnecessary packages
apt purge -y telnet ftp rsh-client

# Disable kernel modules
cat <<EOF >> /etc/modprobe.d/k8s-hardening.conf
install cramfs /bin/true
install freevxfs /bin/true
install hfs /bin/true
install hfsplus /bin/true
install udf /bin/true
EOF

# Sysctl hardening
cat <<EOF >> /etc/sysctl.d/90-k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
kernel.panic = 10
kernel.panic_on_oops = 1
vm.overcommit_memory = 1
EOF
sysctl --system
```

### Kubelet Security
```bash
# Key kubelet flags to verify
# --anonymous-auth=false
# --authorization-mode=Webhook
# --read-only-port=0
# --protect-kernel-defaults=true
# --streaming-connection-idle-timeout=5m

# Check current kubelet config
kubectl get --raw /api/v1/nodes/<node>/proxy/configz | jq
```

## Practice Scenarios

1. **AppArmor**: Create a profile that blocks writing to /tmp, apply to a pod, verify writes fail
2. **Seccomp**: Apply RuntimeDefault to all pods in a namespace via Kyverno policy
3. **Node hardening**: Run Ansible CIS playbook, verify kube-bench score improves
4. **Kubelet**: Disable anonymous auth, set Webhook authorization, verify with kube-bench section 4.2
5. **Minimize surface**: Remove telnet/ftp, disable unused kernel modules, verify
