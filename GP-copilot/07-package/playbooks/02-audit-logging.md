# Playbook 02: Audit & Accountability
### Controls: AU-2, AU-3, AU-6, AU-12

---

## WHAT THIS COVERS

| Control | Name | What the assessor checks |
|---------|------|------------------------|
| AU-2 | Audit Events | System is configured to audit the right events |
| AU-3 | Content of Audit Records | Audit records contain sufficient detail (who, what, when, where, outcome) |
| AU-6 | Audit Review, Analysis, Reporting | Audit records are regularly reviewed and analyzed |
| AU-12 | Audit Generation | System generates audit records for defined events |

**This is one of the most heavily scrutinized families.** If the assessor can't see evidence that you log and review, you fail.

---

## AU-2 + AU-12: WHAT TO LOG AND HOW TO GENERATE IT

### Layer 1: Kubernetes API Audit Logging

Every API call to the cluster must be logged. This is your primary evidence source.

**Enable K8s audit logging (EKS)**
```bash
# EKS: Enable control plane logging
aws eks update-cluster-config \
  --name <cluster-name> \
  --logging '{"clusterLogging":[
    {"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}
  ]}'

# Verify
aws eks describe-cluster --name <cluster-name> \
  --query 'cluster.logging.clusterLogging[?enabled==`true`].types[]'
```

**Enable K8s audit logging (self-managed clusters)**

Create an audit policy:
```yaml
# audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Log all requests at Metadata level (who did what, when)
  - level: Metadata
    resources:
      - group: ""
        resources: ["pods", "services", "configmaps", "secrets", "namespaces"]
      - group: "apps"
        resources: ["deployments", "statefulsets", "daemonsets"]
      - group: "rbac.authorization.k8s.io"
        resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
      - group: "networking.k8s.io"
        resources: ["networkpolicies"]

  # Log request bodies for sensitive operations
  - level: Request
    resources:
      - group: ""
        resources: ["secrets"]
    verbs: ["create", "update", "patch", "delete"]

  # Log auth failures in detail
  - level: Request
    nonResourceURLs:
      - "/api*"
    omitStages:
      - "RequestReceived"

  # Don't log read-only system requests (too noisy)
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]

  # Don't log health checks
  - level: None
    nonResourceURLs:
      - "/healthz*"
      - "/readyz*"
      - "/livez*"

  # Default: log metadata for everything else
  - level: Metadata
```

Add to API server:
```bash
# kube-apiserver flags
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
--audit-log-path=/var/log/kubernetes/audit.log
--audit-log-maxage=30
--audit-log-maxbackup=10
--audit-log-maxsize=100
```

### Layer 2: Application-Level Logging

Every application must log these events:

```
MUST LOG:
  ✓ Authentication attempts (success and failure)
  ✓ Authorization decisions (access granted/denied)
  ✓ Data access (reads to sensitive data)
  ✓ Data modifications (creates, updates, deletes)
  ✓ Configuration changes
  ✓ System startup/shutdown
  ✓ Errors and exceptions

EACH LOG ENTRY MUST CONTAIN (AU-3):
  ✓ Timestamp (ISO 8601, UTC)
  ✓ Event type (auth, access, modify, error)
  ✓ User/service identity
  ✓ Source IP / pod name
  ✓ Resource accessed
  ✓ Action taken
  ✓ Outcome (success/failure)
```

**Structured logging format (JSON)**
```json
{
  "timestamp": "2026-03-11T14:30:00Z",
  "level": "INFO",
  "event": "data_access",
  "user": "jane.doe@company.com",
  "source_ip": "10.0.1.42",
  "pod": "payments-api-7f8d9c-abc12",
  "namespace": "payments-prod",
  "resource": "customer_records",
  "action": "read",
  "outcome": "success",
  "details": {
    "record_count": 50,
    "query_type": "list"
  }
}
```

### Layer 3: AWS CloudTrail

```bash
# Verify CloudTrail is enabled for all regions
aws cloudtrail describe-trails --query 'trailList[*].[Name,IsMultiRegionTrail,LogFileValidationEnabled]' --output table

# If not enabled:
aws cloudtrail create-trail \
  --name fedramp-audit-trail \
  --s3-bucket-name <audit-bucket> \
  --is-multi-region-trail \
  --enable-log-file-validation \
  --kms-key-id <kms-key-arn>

aws cloudtrail start-logging --name fedramp-audit-trail

# Enable CloudTrail data events for S3 (if storing sensitive data)
aws cloudtrail put-event-selectors \
  --trail-name fedramp-audit-trail \
  --event-selectors '[{
    "ReadWriteType": "All",
    "IncludeManagementEvents": true,
    "DataResources": [{"Type": "AWS::S3::Object", "Values": ["arn:aws:s3:::<sensitive-bucket>/"]}]
  }]'
```

### Layer 4: VPC Flow Logs

```bash
# Enable VPC flow logs
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids <vpc-id> \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /aws/vpc/flow-logs \
  --deliver-logs-permission-arn <flow-logs-role-arn>
```

---

## LOG AGGREGATION STACK

All logs must flow to a central, tamper-resistant location.

### Option A: AWS-native (simpler, FedRAMP-authorized)

```
K8s audit logs → CloudWatch Logs (via EKS integration)
App logs → Fluent Bit DaemonSet → CloudWatch Logs
CloudTrail → S3 + CloudWatch
VPC Flow Logs → CloudWatch

CloudWatch → OpenSearch (for analysis)
CloudWatch → S3 (for long-term retention)
```

**Deploy Fluent Bit for application logs**
```yaml
# fluent-bit-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: logging
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         5
        Log_Level     info
        Parsers_File  parsers.conf

    [INPUT]
        Name              tail
        Tag               kube.*
        Path              /var/log/containers/*.log
        Parser            cri
        Mem_Buf_Limit     50MB
        Skip_Long_Lines   On
        Refresh_Interval  10

    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Merge_Log           On
        K8S-Logging.Parser  On

    [OUTPUT]
        Name                cloudwatch_logs
        Match               kube.*
        region              us-east-1
        log_group_name      /k8s/application-logs
        log_stream_prefix   pod-
        auto_create_group   true
```

### Option B: Open-source stack (Loki + Grafana)

```bash
# Install Loki stack via Helm
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack \
  -n logging --create-namespace \
  --set fluent-bit.enabled=true \
  --set grafana.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=50Gi
```

---

## AU-6: AUDIT REVIEW AND ANALYSIS

### What "compliant" looks like
- Audit records are reviewed regularly (weekly minimum, daily recommended)
- Anomalies are investigated
- Review process is documented

### Set up automated alerting (catches the obvious stuff)

```yaml
# CloudWatch metric filter for failed authentication
aws logs put-metric-filter \
  --log-group-name /k8s/audit \
  --filter-name AuthFailures \
  --filter-pattern '{ $.responseStatus.code = 403 }' \
  --metric-transformations \
    metricName=K8sAuthFailures,metricNamespace=FedRAMP,metricValue=1

# Alert on spike
aws cloudwatch put-metric-alarm \
  --alarm-name K8sAuthFailureSpike \
  --metric-name K8sAuthFailures \
  --namespace FedRAMP \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions <sns-topic-arn>
```

**Prometheus alerting rules for K8s**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: fedramp-audit-alerts
  namespace: monitoring
spec:
  groups:
    - name: fedramp-audit
      rules:
        - alert: UnauthorizedAPIAccess
          expr: sum(rate(apiserver_request_total{code=~"401|403"}[5m])) > 0.5
          for: 5m
          labels:
            severity: warning
            compliance: AU-6
          annotations:
            summary: "Elevated rate of unauthorized API requests"

        - alert: SecretAccessAnomaly
          expr: sum(rate(apiserver_request_total{resource="secrets",verb=~"get|list"}[5m])) > 10
          for: 5m
          labels:
            severity: warning
            compliance: AU-6
          annotations:
            summary: "Unusual rate of secret access"
```

### Weekly review process (document this)

```markdown
# Weekly Audit Review Checklist

**Reviewer:** _______________
**Date:** _______________
**Period:** _______________ to _______________

## Automated Alerts Reviewed
- [ ] Authentication failure alerts: _____ triggered, _____ investigated
- [ ] Authorization failure alerts: _____ triggered, _____ investigated
- [ ] Secret access anomaly alerts: _____ triggered, _____ investigated

## Manual Review
- [ ] Reviewed K8s audit log for privilege escalation attempts
- [ ] Reviewed CloudTrail for IAM changes
- [ ] Reviewed VPC flow logs for unexpected traffic patterns
- [ ] Checked for new ClusterRoleBindings with elevated privileges

## Findings
| Finding | Severity | Action Taken | Status |
|---------|----------|-------------|--------|
| | | | |

## Sign-off
Reviewed by: _______________
Date: _______________
```

---

## LOG RETENTION REQUIREMENTS

| Log type | FedRAMP Moderate minimum | Recommended |
|----------|------------------------|-------------|
| K8s audit logs | 1 year | 3 years |
| Application logs | 1 year | 3 years |
| CloudTrail | 1 year | 3 years |
| VPC flow logs | 1 year | 3 years |
| Access logs | 1 year | 3 years |

```bash
# Set CloudWatch retention
aws logs put-retention-policy \
  --log-group-name /k8s/audit \
  --retention-in-days 1095   # 3 years

aws logs put-retention-policy \
  --log-group-name /k8s/application-logs \
  --retention-in-days 1095

# Archive to S3 for cost savings (after 90 days)
# Use CloudWatch subscription filter → Kinesis Firehose → S3
```

---

## EVIDENCE FOR THE ASSESSOR

| Evidence | How to generate | Template |
|----------|----------------|----------|
| Audit policy document | K8s audit-policy.yaml + CloudTrail config | `templates/remediation-templates/audit-logging.yaml` |
| Sample audit records | `kubectl logs` or CloudWatch query | Show 5 examples with all AU-3 fields |
| Review process documentation | Weekly checklist above | Fill in for last 4 weeks |
| Alert configuration | Prometheus rules + CloudWatch alarms | Export configs |
| Retention policy proof | CloudWatch retention settings | `aws logs describe-log-groups` |
| Log integrity proof | CloudTrail log file validation | `aws cloudtrail validate-logs` |

---

## COMPLETION CHECKLIST

```
[ ] AU-2:  K8s API audit logging enabled (all event types)
[ ] AU-2:  CloudTrail enabled (multi-region, log validation)
[ ] AU-2:  VPC flow logs enabled
[ ] AU-2:  Applications logging auth, access, modify, error events
[ ] AU-3:  All log entries contain: timestamp, user, source, resource, action, outcome
[ ] AU-3:  Structured JSON logging format in all applications
[ ] AU-6:  Automated alerts for auth failures, anomalies
[ ] AU-6:  Weekly review process documented and executed
[ ] AU-6:  4+ weeks of review logs available for assessor
[ ] AU-12: Fluent Bit / log aggregation deployed and collecting
[ ] AU-12: Central log store (CloudWatch, Loki, or OpenSearch) operational
[ ] AU-12: Log retention set to 1+ year (3 recommended)
[ ] AU-12: Log integrity verified (CloudTrail validation)
```
