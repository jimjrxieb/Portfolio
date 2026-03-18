# Playbook 01a — Platform Quirks Reference

## Purpose

Every K8s distribution does things differently. Before running Ansible, deploying policies, or troubleshooting, identify the platform and check this reference. Most hardening failures happen because a tool assumes kubeadm paths, service names, or behaviors that don't exist on k3s, EKS, or Docker Desktop.

## Quick Detection

```bash
# What are we running on?
kubectl version --short 2>/dev/null | grep Server
kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}'

# k3s?
which k3s 2>/dev/null && k3s --version
# EKS?
kubectl get nodes -o jsonpath='{.items[0].metadata.labels.eks\.amazonaws\.com/nodegroup}'
# kubeadm?
which kubeadm 2>/dev/null && kubeadm version
# Docker Desktop / Rancher Desktop?
kubectl get nodes -o jsonpath='{.items[0].metadata.labels.node\.kubernetes\.io/instance-type}'
# minikube?
minikube version 2>/dev/null
```

## Platform Matrix

### Config Files

| What | kubeadm | k3s | EKS | Docker Desktop |
|------|---------|-----|-----|----------------|
| Cluster config | `/etc/kubernetes/admin.conf` | `/etc/rancher/k3s/config.yaml` | N/A (managed) | `~/.kube/config` |
| Kubelet config | `/var/lib/kubelet/config.yaml` | embedded in k3s binary | `/etc/kubernetes/kubelet/kubelet-config.json` | embedded |
| Kubelet args | systemd drop-in `/etc/systemd/system/kubelet.service.d/` | `kubelet-arg:` list in k3s config.yaml | launch template userdata | Docker Desktop settings |
| API server args | `/etc/kubernetes/manifests/kube-apiserver.yaml` | `kube-apiserver-arg:` in k3s config.yaml | EKS control plane (no access) | embedded |
| PKI / certs | `/etc/kubernetes/pki/` | `/var/lib/rancher/k3s/server/tls/` | managed by AWS | embedded |
| kubeconfig | `/etc/kubernetes/admin.conf` | `/etc/rancher/k3s/k3s.yaml` | `aws eks update-kubeconfig` | `~/.kube/config` |

### Service Names

| What | kubeadm | k3s | EKS | Docker Desktop |
|------|---------|-----|-----|----------------|
| Kubelet service | `kubelet` | `k3s` (bundled) | `kubelet` | Docker.app |
| Container runtime | `containerd` / `crio` | `k3s` (bundled containerd) | `containerd` | Docker.app |
| Restart command | `systemctl restart kubelet` | `systemctl restart k3s` | N/A (managed) | Restart Docker Desktop |

### Storage

| What | kubeadm | k3s | EKS | Docker Desktop |
|------|---------|-----|-----|----------------|
| Default StorageClass | none (manual setup) | `local-path` | `gp2` / `gp3` (EBS CSI) | `hostpath` |
| PV provisioner | depends on setup | `local-path-provisioner` | EBS CSI driver | hostpath-provisioner |
| Helper pod namespace | N/A | **PVC's namespace** (gotcha!) | N/A (CSI driver) | N/A |

### Pod Security

| What | kubeadm | k3s | EKS | Docker Desktop |
|------|---------|-----|-----|----------------|
| Default PSA | none | `baseline` (v1.25+) | none | none |
| PSA config location | admission-control-config-file | built-in default | EKS add-on | none |
| Override method | namespace labels | namespace labels (but see gotcha below) | namespace labels | namespace labels |

## Gotchas By Platform

### k3s

1. **Config format**: `/etc/rancher/k3s/config.yaml` is NOT a KubeletConfiguration. It uses k3s-specific keys.
   ```yaml
   # WRONG — this is KubeletConfiguration format, k3s ignores it
   apiVersion: kubelet.config.k8s.io/v1beta1
   kind: KubeletConfiguration
   authentication:
     anonymous:
       enabled: false

   # RIGHT — k3s native format
   kubelet-arg:
     - "anonymous-auth=false"
     - "read-only-port=0"
   ```

2. **local-path-provisioner + PSA**: Helper pods are created in the PVC's namespace using hostPath volumes. If PSA enforce is `baseline` or higher, provisioning fails silently.
   - **Fix**: Set namespace PSA `enforce=privileged`, use Gatekeeper/Kyverno for real enforcement.
   - **Or**: Move to a CSI driver that doesn't use helper pods.

3. **Traefik RBAC**: k3s installs Traefik via Helm with `cluster-admin` bindings (`helm-kube-system-traefik`). These are recreated on k3s upgrade — don't delete them.

4. **No separate kubelet process**: k3s bundles kubelet, containerd, and API server in one binary. `systemctl restart k3s` restarts everything. There is no `kubelet` service.

5. **Embedded etcd**: k3s uses embedded etcd (or SQLite for single-node). CIS etcd benchmark sections (2.x) require different paths than external etcd.

6. **protect-kernel-defaults**: Set to `false` on k3s. k3s manages its own sysctl settings, and `true` can prevent k3s from starting if any Ansible sysctl changes conflict.

### EKS (AWS)

1. **No control plane access**: You cannot modify API server flags, etcd config, or scheduler settings. CIS sections 1.x are AWS's responsibility.

2. **Managed node groups**: Kubelet config is baked into the AMI and launch template. To change kubelet args, update the launch template userdata or use a custom AMI.

3. **Storage**: EBS CSI driver handles provisioning — no helper pod issues. But ensure the CSI driver add-on is installed.

4. **Auth**: `aws-iam-authenticator` or IRSA for pod-level auth. No static tokens or basic auth.

5. **PSA**: Not enabled by default. You set it via namespace labels like any other cluster.

6. **Audit logging**: Must be enabled via EKS control plane logging (CloudWatch), not `--audit-log-path`.

### kubeadm (self-hosted)

1. **Static pods**: API server, controller-manager, scheduler run as static pods in `/etc/kubernetes/manifests/`. Changes require editing the manifest — kubelet auto-restarts the pod.

2. **kubelet systemd**: Has its own service unit. Drop-in files go in `/etc/systemd/system/kubelet.service.d/`.

3. **Certificate rotation**: Enabled by default in modern kubeadm, but verify `--rotate-certificates` and `--rotate-server-certificates`.

4. **Storage**: No default provisioner. Must install one (local-path, NFS, Ceph, etc.).

### Docker Desktop / Rancher Desktop

1. **Single node only**: Not production. Good for local testing of policies.

2. **No SSH**: Can't run Ansible against it. Node hardening doesn't apply.

3. **Reset risk**: Docker Desktop can reset the K8s cluster entirely when updated. Don't store state you can't recreate.

4. **Resource limits**: Default memory/CPU limits are low. Adjust in Docker Desktop settings.

5. **hostPath**: Works but paths are inside the VM, not on your host filesystem.

### minikube

1. **Driver matters**: `docker` driver has different networking than `hyperkit` or `kvm2`.

2. **Multi-node**: Supported but each node is a container/VM. Ansible works but over `minikube ssh`.

3. **Addons**: Many things installed via `minikube addons enable X` rather than Helm/kubectl.

## Ansible Detection Pattern

Use this in all Ansible playbooks to branch by platform:

```yaml
tasks:
  - name: Check if k3s is installed
    stat:
      path: /usr/local/bin/k3s
    register: k3s_binary

  - name: Check if kubeadm is installed
    stat:
      path: /usr/bin/kubeadm
    register: kubeadm_binary

  - name: Set platform fact
    set_fact:
      k8s_platform: >-
        {{ 'k3s' if k3s_binary.stat.exists | default(false) else
           'kubeadm' if kubeadm_binary.stat.exists | default(false) else
           'unknown' }}

  # Then use: when: k8s_platform == 'k3s'
```

## Agent Integration

`jsa-infrasec` reads this playbook during cluster discovery (playbook 01):
1. Detect platform (k3s, kubeadm, EKS)
2. Set platform-specific paths for config, certs, services
3. Skip inapplicable CIS sections (e.g., etcd on EKS)
4. Apply correct kubelet arg format
5. Choose appropriate storage class workarounds
