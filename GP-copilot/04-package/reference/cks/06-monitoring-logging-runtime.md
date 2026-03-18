# CKS Domain 6: Monitoring, Logging & Runtime Security (15%)

Perform behavioral analytics of syscall process and file activities at host and container level. Detect threats within physical infrastructure, apps, networks, data, users, and workloads. Detect all phases of attack regardless of where it occurs. Perform deep analytical investigation and identification of bad actors. Ensure immutability of containers at runtime. Use Audit Logs to monitor access.

## What You Need to Know

- Falco (syscall monitoring, threat detection)
- Kubernetes audit logging
- Container immutability (readOnlyRootFilesystem)
- Incident response (isolate, forensics, remediate)
- Behavioral analytics and attack detection

## Pre-Built Tools (Already in GP-CONSULTING)

### Falco
| Resource | Location | What It Provides |
|----------|----------|-----------------|
| `deploy.sh` | `03-DEPLOY-RUNTIME/tools/` | One-command Falco install |
| `tune-falco.sh` | `03-DEPLOY-RUNTIME/tools/` | Noise reduction, rule tuning |
| `health-check.sh` | `03-DEPLOY-RUNTIME/tools/` | Verify Falco + exporter running |
| Falco rules (7 sets) | `03-DEPLOY-RUNTIME/templates/falco-rules/` | K8s audit, privesc, persistence, exfil, mining, mesh, allowlist |
| `falco-alerts.yaml` | `03-DEPLOY-RUNTIME/templates/monitoring/` | Prometheus alert rules |

### Runtime Watchers
| Watcher | Location | What It Detects |
|---------|----------|----------------|
| `watch-events.sh` | `03-DEPLOY-RUNTIME/watchers/` | CrashLoops, OOMKilled, ImagePullBackOff |
| `watch-drift.sh` | `03-DEPLOY-RUNTIME/watchers/` | Running vs declared state divergence |
| `watch-audit.sh` | `03-DEPLOY-RUNTIME/watchers/` | Suspicious API server calls |

### Incident Response
| Responder | Location | What It Does |
|-----------|----------|-------------|
| `isolate-pod.sh` | `03-DEPLOY-RUNTIME/responders/` | Quarantine pod with deny-all NetworkPolicy |
| `kill-pod.sh` | `03-DEPLOY-RUNTIME/responders/` | Terminate pod after forensic capture |
| `capture-forensics.sh` | `03-DEPLOY-RUNTIME/responders/` | Non-destructive evidence collection |
| `debug-finding.sh` | `03-DEPLOY-RUNTIME/tools/` | Forensic investigation workflow |

### Playbooks
| Playbook | Location | When to Use |
|----------|----------|-------------|
| `02-deploy-falco.md` | `03-DEPLOY-RUNTIME/playbooks/` | Deploy Falco DaemonSet |
| `04-tune-falco.md` | `03-DEPLOY-RUNTIME/playbooks/` | Reduce noise, tune rules |
| `07-operations.md` | `03-DEPLOY-RUNTIME/playbooks/` | Daily health check, incident workflow |
| `10-deploy-logging.md` | `03-DEPLOY-RUNTIME/playbooks/` | Centralized log aggregation |
| `03-verify-container-hardening.md` | `03-DEPLOY-RUNTIME/playbooks/` | 15-point running pod audit |

## CKS Exam Quick Reference

### Falco — Detect Suspicious Activity
```bash
# Install Falco
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco -n falco --create-namespace \
  --set driver.kind=modern_ebpf \
  --set falcosidekick.enabled=true

# View alerts
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=50

# Key Falco rules to know:
# - Terminal shell in container
# - Write below /etc
# - Read sensitive file (e.g., /etc/shadow)
# - Unexpected outbound connection
# - Privilege escalation (setuid)
```

### Falco Rule Format
```yaml
- rule: Terminal shell in container
  desc: A shell was spawned in a container
  condition: >
    spawned_process and container and
    proc.name in (bash, sh, zsh, dash) and
    container.id != host
  output: >
    Shell spawned in container
    (user=%user.name container=%container.name
    shell=%proc.name parent=%proc.pname
    cmdline=%proc.cmdline image=%container.image.repository)
  priority: WARNING
  tags: [container, shell, mitre_execution]
```

### Kubernetes Audit Logging
```yaml
# /etc/kubernetes/audit/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Log secrets access at Metadata level
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]

# Log all changes at RequestResponse level
- level: RequestResponse
  verbs: ["create", "update", "patch", "delete"]

# Log everything else at Request level
- level: Request

# Don't log read-only endpoints
- level: None
  resources:
  - group: ""
    resources: ["events"]
```

```bash
# Enable audit logging on API server
# --audit-policy-file=/etc/kubernetes/audit/audit-policy.yaml
# --audit-log-path=/var/log/kubernetes/audit.log
# --audit-log-maxage=30
# --audit-log-maxbackup=10
# --audit-log-maxsize=100

# Query audit logs
cat /var/log/kubernetes/audit.log | jq 'select(.verb=="delete" and .objectRef.resource=="secrets")'
```

### Container Immutability
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: immutable-pod
spec:
  containers:
  - name: app
    image: nginx:1.25
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
```

### Incident Response Workflow
```bash
# 1. Identify the compromised pod
kubectl get events -A --sort-by='.lastTimestamp' | grep -i warning

# 2. Capture forensics FIRST
kubectl exec -n target compromised-pod -- cat /proc/1/cmdline
kubectl exec -n target compromised-pod -- ls -la /tmp
kubectl logs -n target compromised-pod > /tmp/evidence/pod-logs.txt

# 3. Isolate with NetworkPolicy
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-compromised
  namespace: target
spec:
  podSelector:
    matchLabels:
      app: compromised-app
  policyTypes:
  - Ingress
  - Egress
EOF

# 4. Kill if needed (after forensics captured)
kubectl delete pod -n target compromised-pod --grace-period=0 --force
```

## Practice Scenarios

1. **Falco**: Deploy Falco, exec into a pod, find the alert in Falco logs
2. **Audit logging**: Enable K8s audit logs, create/delete a secret, find it in the audit log
3. **Immutability**: Create pod with readOnlyRootFilesystem, verify writes fail to /etc
4. **Incident response**: Detect shell in container -> capture forensics -> isolate -> kill
5. **Behavioral analysis**: Write Falco rule that detects outbound connections to crypto mining pools
6. **Log analysis**: Parse audit logs to find who deleted a secret in the last hour
