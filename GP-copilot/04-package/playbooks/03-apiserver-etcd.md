# Playbook: API Server & etcd Security

> Verify and harden API server configuration. Ensure etcd is encrypted at rest with a working backup procedure.
>
> **When:** After platform integrity verified. Critical on self-hosted clusters.
> **Time:** ~20 min

---

## Prerequisites

- SSH to control plane node (self-hosted) OR managed console access (EKS/GKE/AKS)
- kube-bench results from [01-specialist-audit](01-specialist-audit.md)
- **ArgoCD rule:** If API server is ArgoCD-managed, make changes in git. Check first: `kubectl get pod -n kube-system kube-apiserver-* -o jsonpath='{.metadata.labels.app\.kubernetes\.io/instance}'`

---

## Step 1: Audit API Server Flags

```bash
# Get current API server flags
kubectl -n kube-system get pod -l component=kube-apiserver \
  -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | sort
```

Verify these critical flags:

| Flag | Expected | Why |
|------|----------|-----|
| `--anonymous-auth` | `false` | Block unauthenticated requests |
| `--authorization-mode` | `Node,RBAC` | Never `AlwaysAllow` |
| `--enable-admission-plugins` | `NodeRestriction,...` | Required admission controllers |
| `--audit-log-path` | Set | Audit trail |
| `--audit-log-maxage` | `30` | Retain 30 days |
| `--encryption-provider-config` | Set | Secrets encrypted at rest |
| `--profiling` | `false` | Disable profiling endpoint |
| `--insecure-port` | `0` | No unencrypted API access |
| `--kubelet-certificate-authority` | Set | Verify kubelet certs |

```bash
# Quick check against kube-bench section 1 (API server)
kube-bench run --targets master --check 1.2
```

### Fix (Self-Hosted Only)

Edit `/etc/kubernetes/manifests/kube-apiserver.yaml`:

```bash
# Backup first
cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml.bak

# Add/fix flags
# The kubelet watches this file — it will restart the API server automatically
```

For managed clusters (EKS/GKE/AKS), these flags are set by the provider. Document any that can't be changed and note as accepted risk.

---

## Step 2: Verify Encryption at Rest

```bash
# Check if encryption config exists
kubectl -n kube-system get pod -l component=kube-apiserver \
  -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep encryption
```

If `--encryption-provider-config` is NOT set:

```bash
# Generate encryption key
KEY=$(head -c 32 /dev/urandom | base64)

# Create encryption config
cat > /etc/kubernetes/enc/encryption-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: ${KEY}
  - identity: {}
EOF

chmod 600 /etc/kubernetes/enc/encryption-config.yaml
```

Add to API server manifest:
```yaml
- --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml
```

And mount the directory:
```yaml
volumeMounts:
- name: enc-config
  mountPath: /etc/kubernetes/enc
  readOnly: true
volumes:
- name: enc-config
  hostPath:
    path: /etc/kubernetes/enc
    type: DirectoryOrCreate
```

Re-encrypt existing secrets:
```bash
# Wait for API server to restart
kubectl get pods -n kube-system -l component=kube-apiserver -w

# Re-encrypt all secrets
kubectl get secrets -A -o json | kubectl replace -f -
```

> **Reference:** `04-KUBESTER/reference/cks/04-microservice-vulnerabilities.md` for full encryption details.

---

## Step 3: Verify etcd Security

```bash
# Check etcd health
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Check etcd flags
kubectl -n kube-system get pod -l component=etcd \
  -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | sort
```

Verify:
- `--client-cert-auth=true`
- `--peer-client-cert-auth=true`
- `--trusted-ca-file` set
- `--cert-file` and `--key-file` set

---

## Step 4: Establish etcd Backup Procedure

```bash
# Run a backup now
bash ~/GP-copilot/GP-CONSULTING/04-KUBESTER/templates/quick-ref/etcd-backup-restore.sh backup /tmp/kubester-audit/etcd-backup.db

# Verify the backup
bash ~/GP-copilot/GP-CONSULTING/04-KUBESTER/templates/quick-ref/etcd-backup-restore.sh health
```

If no CronJob exists for automated backups, create one:
```bash
# Document the backup command and schedule
echo "etcd backup procedure verified. Recommend CronJob at 0 2 * * * (daily 2am)" >> /tmp/kubester-audit/gap-report.md
```

---

## Step 5: Audit Logging

If `--audit-log-path` is not set:

```bash
# Deploy the audit policy
cp ~/GP-copilot/GP-CONSULTING/04-KUBESTER/templates/quick-ref/audit-policy.yaml \
  /etc/kubernetes/audit/audit-policy.yaml
```

Add to API server manifest:
```yaml
- --audit-policy-file=/etc/kubernetes/audit/audit-policy.yaml
- --audit-log-path=/var/log/kubernetes/audit.log
- --audit-log-maxage=30
- --audit-log-maxbackup=10
- --audit-log-maxsize=100
```

Mount:
```yaml
volumeMounts:
- name: audit-config
  mountPath: /etc/kubernetes/audit
  readOnly: true
- name: audit-logs
  mountPath: /var/log/kubernetes
volumes:
- name: audit-config
  hostPath:
    path: /etc/kubernetes/audit
- name: audit-logs
  hostPath:
    path: /var/log/kubernetes
    type: DirectoryOrCreate
```

> **Reference:** `04-KUBESTER/reference/cks/06-monitoring-logging-runtime.md` for audit policy format.

---

## Outputs

- API server flags audit: compliant / non-compliant
- Encryption at rest: enabled / configured
- etcd backup: tested and documented
- Audit logging: enabled / configured

---

## Next

→ [04-rbac-perfection.md](04-rbac-perfection.md) — Tighten RBAC beyond what 02 implemented
