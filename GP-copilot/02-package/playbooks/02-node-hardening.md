# Playbook: Node Hardening (Ansible)

> Harden the OS underneath the cluster — sysctl, auditd, kubelet config.
>
> **When:** Layer 0. Run BEFORE any K8s policies. Kubernetes can't harden what's underneath it.
> **Time:** ~30 min (configure inventory + run + verify)

---

## What Is This

Ansible is SSH + a script that knows how to be idempotent. That's it.

```
What you already do manually          What Ansible does
─────────────────────────────────     ─────────────────────────────
ssh jimmie@server                     Same SSH, but to ALL nodes at once
sudo sysctl -w net.ipv4...=0         Same sysctl, but checks first — skips if already set
sudo vim /etc/audit/rules.d/...      Same file edits, but templated
sudo systemctl restart kubelet       Same restart, but only if config changed
```

You install Ansible on YOUR rig (not the servers). You tell it which servers to SSH into (the inventory file). You run the wrapper script. Ansible SSHes into every node, applies the hardening, and reports back what changed.

The actual hardening logic lives in 3 YAML playbooks under `playbooks/ansible/`:

| Playbook | What It Hardens | CIS Sections |
|----------|----------------|-------------|
| `cis-node-hardening.yml` | Kernel, network, filesystem | 1.x, 3.x, 4.1.x |
| `auditd-config.yml` | Audit logging for K8s | 4.1.x |
| `kubelet-hardening.yml` | Kubelet auth, ports, TLS | 4.2.x |

---

## Prerequisites

- Ansible installed on your rig: `pip install ansible`
- SSH key-based authentication to all target nodes (no passwords)
- sudo/root on target nodes

---

## Step 1: Configure Inventory

Tell Ansible which servers to hit.

```bash
cd ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/node-hardening

# Edit the inventory with your node IPs
vim inventory/eks-nodes.ini
```

**Single node (k3s, portfolioserver-style):**
```ini
[control_plane]
100.116.11.56 ansible_user=jimmie

[workers]
# k3s single-node — control plane IS the worker

[k8s_nodes:children]
control_plane
workers
```

**Multi-node (EKS, kubeadm):**
```ini
[control_plane]
10.0.1.10 ansible_user=ubuntu

[workers]
10.0.1.20 ansible_user=ubuntu
10.0.1.21 ansible_user=ubuntu
10.0.1.22 ansible_user=ubuntu

[k8s_nodes:children]
control_plane
workers
```

---

## Step 2: Dry Run First

```bash
# Preview what WOULD change — changes nothing
bash harden-nodes.sh --check
```

Review the diff output. Ansible shows green (already compliant), yellow (would change), red (error). Look for anything unexpected.

---

## Step 3: Apply Hardening

```bash
# Apply all three playbooks in order
bash harden-nodes.sh

# Or apply specific layers
bash harden-nodes.sh --tags cis       # Sysctl + kernel modules only
bash harden-nodes.sh --tags auditd    # Audit rules only
bash harden-nodes.sh --tags kubelet   # Kubelet config only

# Target specific node groups
bash harden-nodes.sh --limit workers
```

`harden-nodes.sh` is just a wrapper. It calls `ansible-playbook` three times — once for each YAML playbook. You never copy files manually. Ansible pushes everything over SSH.

---

## What Each Playbook Does

### `cis-node-hardening.yml` — Kernel + Network + Filesystem

| Category | What It Does |
|----------|-------------|
| Filesystems | Disable cramfs, squashfs, udf |
| Core dumps | Restrict core dump generation |
| ASLR | Enable `kernel.randomize_va_space=2` |
| Network | Disable ICMP redirects, enable SYN cookies, log martians |
| Protocols | Disable dccp, sctp, rds, tipc |
| Permissions | Lock down K8s config and PKI file permissions |

### `auditd-config.yml` — Audit Logging

| Audit Category | What Gets Logged |
|---------------|-----------------|
| K8s binaries | kubelet, kubectl, kubeadm execution |
| Container runtime | containerd, runc, ctr, crictl |
| K8s config | /etc/kubernetes/, /var/lib/kubelet/ changes |
| Auth events | PAM, shadow, sudoers, su/sudo |
| Privilege use | setuid, setgid, setreuid |
| Network changes | hostname, /etc/hosts, interface config |

### `kubelet-hardening.yml` — Kubelet CIS 4.2.x

| CIS Control | Setting | Value |
|-------------|---------|-------|
| 4.2.1 | anonymous-auth | false |
| 4.2.2 | authorization-mode | Webhook |
| 4.2.4 | read-only-port | 0 (disabled) |
| 4.2.6 | protect-kernel-defaults | true |
| 4.2.9 | TLS cipher suites | FIPS-approved only |
| 4.2.13 | seccomp default | enabled |

---

## Step 4: Verify

```bash
# Re-run in check mode — should show zero changes (all green)
bash harden-nodes.sh --check

# Then run cluster audit to see the impact on kube-bench scores
bash ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/hardening/run-cluster-audit.sh
```

kube-bench sections 1.x and 4.2.x should now pass. Those are the sections that fail on a fresh cluster because nobody hardened the OS.

---

## File Layout

```
node-hardening/
├── harden-nodes.sh              # Wrapper — runs all 3 playbooks via ansible-playbook
└── inventory/
    └── eks-nodes.ini            # YOUR node IPs go here

playbooks/ansible/               # The actual Ansible playbooks (harden-nodes.sh calls these)
├── cis-node-hardening.yml       # Sysctl, kernel modules, file permissions
├── auditd-config.yml            # Audit logging rules for K8s
├── kubelet-hardening.yml        # Kubelet auth, ports, TLS
└── templates/
    └── kubelet-config.yaml.j2   # Kubelet config template (pushed to nodes by Ansible)
```

---

## EKS-Specific Notes

- EKS managed node groups use Amazon Linux 2 or Bottlerocket
- SSH requires SSM Session Manager or bastion host
- Some CIS controls already enforced by EKS AMI — Ansible is idempotent, safe to re-run
- Bottlerocket nodes are immutable — use Bottlerocket API instead of Ansible
- EKS kubelet config lives at `/etc/kubernetes/kubelet/kubelet-config.json`

---

## Next Steps

- Run the cluster audit post-hardening? → [01-cluster-audit.md](01-cluster-audit.md)
- Automated cluster-level fixes? → [03-automated-fixes.md](03-automated-fixes.md)

---

*Ghost Protocol — K8s Hardening Package (CKA + CKS)*
