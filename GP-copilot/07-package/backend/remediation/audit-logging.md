# Audit Logging — FedRAMP AU-2, AU-3, AU-9, AU-12

## The Problem

FedRAMP requires comprehensive audit logging with tamper protection.
No audit logs = no evidence of who did what = automatic finding across AU family.

## What Must Be Logged (AU-2)

| Event | Example | Control |
|-------|---------|---------|
| Authentication attempts | Login success/failure | AU-2, IA-2 |
| Authorization decisions | RBAC allow/deny | AU-2, AC-3 |
| Resource modifications | Pod create/delete/update | AU-2, CM-6 |
| Secret access | Secret read/list | AU-2, IA-5 |
| Privileged operations | kubectl exec, port-forward | AU-2, AC-6 |
| Configuration changes | ConfigMap/RBAC changes | AU-2, CM-6 |

## Fix: Enable K8s Audit Policy

Create audit policy file:

```yaml
# /etc/kubernetes/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Log authentication at RequestResponse level
  - level: RequestResponse
    users: ["*"]
    verbs: ["create"]
    resources:
      - group: "authentication.k8s.io"
        resources: ["tokenreviews"]

  # Log all secret access
  - level: Metadata
    resources:
      - group: ""
        resources: ["secrets"]

  # Log RBAC changes
  - level: RequestResponse
    resources:
      - group: "rbac.authorization.k8s.io"
        resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]

  # Log pod exec (privilege escalation vector)
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["pods/exec", "pods/attach", "pods/portforward"]

  # Log namespace/deployment changes
  - level: RequestResponse
    verbs: ["create", "update", "patch", "delete"]
    resources:
      - group: ""
        resources: ["namespaces", "configmaps", "services"]
      - group: "apps"
        resources: ["deployments", "statefulsets", "daemonsets"]

  # Log everything else at Metadata level
  - level: Metadata
    omitStages:
      - RequestReceived
```

Apply to API server:
```
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
--audit-log-path=/var/log/kubernetes/audit.log
--audit-log-maxage=365
--audit-log-maxbackup=10
--audit-log-maxsize=100
```

For managed K8s (EKS/GKE/AKS), enable audit logging through the cloud console.

## Fix: Deploy Falco for Runtime Audit

See `03-DEPLOY-RUNTIME/` for full Falco deployment. Key rules for FedRAMP:

```yaml
# Falco rules that map to AU controls
- rule: Terminal shell in container
  condition: >
    spawned_process and container and shell_procs
  output: >
    Shell spawned in container (user=%user.name container=%container.name image=%container.image.repository)
  priority: WARNING

- rule: Read sensitive file
  condition: >
    open_read and container and sensitive_files
  output: >
    Sensitive file opened (file=%fd.name user=%user.name container=%container.name)
  priority: WARNING
```

## Fix: Application-Level Audit Logging

Your app should log security events in structured JSON:

```python
import json
import logging
from datetime import datetime, timezone

audit_logger = logging.getLogger("audit")

def log_security_event(event_type, user, resource, action, outcome, details=None):
    record = {
        "timestamp": datetime.now(tz=timezone.utc).isoformat(),
        "event_type": event_type,
        "user": user,
        "resource": resource,
        "action": action,
        "outcome": outcome,  # "success" or "failure"
        "source_ip": request.remote_addr if request else None,
        "details": details,
    }
    audit_logger.info(json.dumps(record))

# Usage
log_security_event("authentication", "user@example.com", "/login", "login", "failure",
                   {"reason": "invalid_password", "attempt": 3})
```

## Fix: Protect Audit Logs (AU-9)

- RBAC: only security team can read logs
- Ship to immutable storage (S3 with Object Lock, CloudWatch Logs)
- Separate log storage from application namespace

```yaml
# RBAC: restrict log access
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: audit-log-reader
  namespace: logging
rules:
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get"]
# Only bind to security team ServiceAccount
```

## Fix: Log Retention

| Requirement | FedRAMP | Implementation |
|-------------|---------|----------------|
| Online retention | 90 days minimum | ELK/Loki with retention policy |
| Archive retention | 1 year (Low) / 3 years (Moderate) | S3 Glacier with lifecycle |
| Immutability | Required | S3 Object Lock or WORM storage |

## Evidence for 3PAO

- [ ] K8s audit policy file showing events captured
- [ ] Falco deployment showing runtime monitoring
- [ ] Sample audit log entries (structured JSON)
- [ ] RBAC showing restricted log access
- [ ] Log retention configuration (90 day online + archive)
- [ ] Immutable storage configuration

## Remediation Priority: C — Security Review

Audit logging setup requires architectural decisions about log destinations,
retention, and access controls. Security review required for the configuration.
