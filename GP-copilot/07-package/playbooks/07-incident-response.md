# Playbook 07: Incident Response
### Controls: IR-4, IR-5

---

## WHAT THIS COVERS

| Control | Name | What the assessor checks |
|---------|------|------------------------|
| IR-4 | Incident Handling | Organization has a process to detect, analyze, contain, eradicate, and recover from incidents |
| IR-5 | Incident Monitoring | Incidents are tracked from detection to resolution |

---

## IR-4: INCIDENT HANDLING

### What "compliant" looks like
- Documented incident response plan
- Defined roles and responsibilities
- Detection → Triage → Contain → Eradicate → Recover → Lessons Learned process
- Incident response is tested at least annually

### Step 1: Incident Response Plan

Create this document and keep it in version control:

```markdown
# Incident Response Plan

## 1. Scope
This plan covers security incidents for [application name] running in [AWS/EKS environment].

## 2. Roles and Responsibilities

| Role | Name | Contact | Responsibility |
|------|------|---------|---------------|
| Incident Commander | [Name] | [phone/slack] | Overall coordination, decisions |
| Security Lead | [Name] | [phone/slack] | Technical investigation, containment |
| Platform Engineer | [Name] | [phone/slack] | Cluster/infra actions |
| Communications | [Name] | [phone/slack] | Internal/external comms, FedRAMP PMO notification |

## 3. Severity Classification

| Severity | Definition | Response Time | Example |
|----------|-----------|---------------|---------|
| **P1 - Critical** | Active data breach, system compromise | 15 min | Unauthorized access to PII, active exploit |
| **P2 - High** | Potential compromise, service degradation | 1 hour | Suspicious login patterns, critical CVE exploited |
| **P3 - Medium** | Policy violation, anomalous behavior | 4 hours | Failed auth spike, unusual process in container |
| **P4 - Low** | Informational, minor policy deviation | 24 hours | New CVE published for a dependency |

## 4. Detection Sources

| Source | What it detects | Alert channel |
|--------|----------------|---------------|
| Falco | Runtime anomalies (syscalls, file access, network) | Slack #security-alerts |
| Prometheus | Metric anomalies (CPU spike, error rate, restarts) | PagerDuty |
| CloudTrail | AWS API anomalies (IAM changes, unusual access) | CloudWatch Alarm → SNS |
| GuardDuty | AWS threat detection (recon, credential theft) | SecurityHub → SNS |
| Gitleaks (CI) | Secrets committed to code | Slack #security-alerts |

## 5. Incident Response Phases

### Phase 1: Detection & Triage (0-15 min)
1. Alert received via [Slack/PagerDuty/email]
2. On-call acknowledges within 15 minutes
3. Classify severity (P1-P4)
4. If P1/P2: page Incident Commander
5. Create incident channel: #incident-YYYY-MM-DD-brief-description

### Phase 2: Containment (15 min - 2 hours)
Depending on incident type:

**Compromised container:**
```bash
# Isolate the pod (block all network traffic)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-compromised-pod
  namespace: <namespace>
spec:
  podSelector:
    matchLabels:
      app: <compromised-app>
  policyTypes:
    - Ingress
    - Egress
EOF

# Scale down to stop the compromised workload
kubectl scale deployment <name> --replicas=0 -n <namespace>

# Capture pod state for forensics BEFORE deleting
kubectl get pod <pod> -n <namespace> -o yaml > forensics/pod-state.yaml
kubectl logs <pod> -n <namespace> --all-containers > forensics/pod-logs.txt
kubectl describe pod <pod> -n <namespace> > forensics/pod-describe.txt
```

**Compromised credentials:**
```bash
# Immediately rotate the credential
aws secretsmanager put-secret-value --secret-id <secret> --secret-string '<new-value>'

# Deactivate IAM access keys
aws iam update-access-key --user-name <user> --access-key-id <key> --status Inactive

# Force ESO re-sync
kubectl annotate externalsecret <name> -n <namespace> force-sync=$(date +%s) --overwrite

# Restart affected pods to pick up new credentials
kubectl rollout restart deployment -n <namespace>
```

**Unauthorized access:**
```bash
# Check recent K8s API calls from the suspect identity
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | head -30

# Check CloudTrail for IAM activity
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=<suspect-user> \
  --max-results 50 --output json

# Revoke access
kubectl delete rolebinding <binding> -n <namespace>
aws iam put-user-policy --user-name <user> --policy-name DenyAll \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Deny","Action":"*","Resource":"*"}]}'
```

### Phase 3: Eradication (2-24 hours)
1. Identify root cause
2. Remove the vulnerability/misconfiguration
3. Scan for lateral movement or persistence
4. Verify no other systems are affected

### Phase 4: Recovery (24-72 hours)
1. Restore from known-good state (Git is source of truth)
2. Re-deploy from clean images
3. Verify all controls are functioning
4. Re-enable traffic/access gradually
5. Monitor closely for recurrence

### Phase 5: Post-Incident (within 5 business days)
1. Write incident report (see template below)
2. Conduct lessons-learned meeting
3. Update monitoring/alerting to detect this type of incident earlier
4. Update runbooks if response was unclear
5. File POA&M entry if a control gap was exploited

## 6. FedRAMP Reporting Requirements

| Severity | Report to FedRAMP PMO | Timeline |
|----------|----------------------|----------|
| P1 | Required — US-CERT reporting | Within 1 hour of detection |
| P2 | Required — FedRAMP PMO notification | Within 24 hours |
| P3 | Log internally, include in monthly report | Monthly |
| P4 | Log internally | N/A |
```

### Step 2: Post-Incident Report Template

```markdown
# Incident Report: [Brief Title]

**Incident ID:** INC-YYYY-NNN
**Date Detected:** YYYY-MM-DD HH:MM UTC
**Date Resolved:** YYYY-MM-DD HH:MM UTC
**Severity:** P1/P2/P3/P4
**Incident Commander:** [Name]

## Summary
[2-3 sentence description of what happened]

## Timeline
| Time (UTC) | Event |
|------------|-------|
| HH:MM | Alert received via [source] |
| HH:MM | Incident commander paged |
| HH:MM | Containment action taken: [describe] |
| HH:MM | Root cause identified: [describe] |
| HH:MM | Eradication complete |
| HH:MM | Recovery complete, service restored |

## Root Cause
[What specifically caused this incident]

## Impact
- **Data affected:** [None / X records / specific data types]
- **Services affected:** [Which services, duration]
- **Users affected:** [Number, scope]

## Containment Actions
1. [Action taken]
2. [Action taken]

## Eradication Actions
1. [Action taken]
2. [Action taken]

## Recovery Actions
1. [Action taken]
2. [Action taken]

## Lessons Learned
| What went well | What to improve |
|---------------|----------------|
| | |

## Action Items
| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
| | | | |

## Controls Affected
| Control | Impact | POA&M Entry? |
|---------|--------|-------------|
| | | |
```

---

## IR-5: INCIDENT MONITORING

### What "compliant" looks like
- All incidents are logged in a tracking system
- Incident status is tracked from detection to closure
- Metrics are collected (MTTR, incident count, severity distribution)
- Incident patterns are analyzed for systemic issues

### Step 1: Incident tracking

At minimum, maintain a spreadsheet or ticketing system:

```markdown
# Incident Tracker

| ID | Date | Severity | Title | Status | MTTR | Root Cause | Controls |
|----|------|----------|-------|--------|------|------------|----------|
| INC-2026-001 | 2026-01-15 | P3 | Unusual process in payments pod | Closed | 2h | False positive — migration job | SI-4 |
| INC-2026-002 | 2026-02-03 | P2 | Exposed API key in commit | Closed | 4h | Developer committed .env file | IA-5 |
```

### Step 2: Alerting pipeline

```
Detection layer:
  Falco → Falcosidekick → Slack + PagerDuty
  Prometheus → AlertManager → Slack + PagerDuty
  CloudTrail → CloudWatch Alarms → SNS → Slack
  GuardDuty → SecurityHub → SNS → Slack

Triage layer:
  On-call reviews alert
  → Classify severity (P1-P4)
  → Create incident record
  → Begin response

Tracking layer:
  Incident created in tracker
  → Status updates throughout response
  → Closed with post-incident report
  → Metrics updated
```

### Step 3: Falcosidekick for alert routing

```bash
# Install Falcosidekick (routes Falco alerts to multiple destinations)
helm upgrade falco falcosecurity/falco \
  -n falco-system \
  --set falcosidekick.enabled=true \
  --set falcosidekick.config.slack.webhookurl=<slack-webhook> \
  --set falcosidekick.config.slack.channel=security-alerts \
  --set falcosidekick.config.pagerduty.routingkey=<pd-key>
```

### Step 4: Incident metrics (for assessor)

```bash
# Generate quarterly incident metrics
echo "=== INCIDENT METRICS Q1 2026 ==="
echo "Total incidents: $(grep -c 'INC-2026' incident-tracker.csv)"
echo "P1 incidents: $(grep -c 'P1' incident-tracker.csv)"
echo "P2 incidents: $(grep -c 'P2' incident-tracker.csv)"
echo "Average MTTR: $(awk -F',' '{sum+=$6; n++} END {print sum/n " hours"}' incident-tracker.csv)"
echo "Incidents per control family:"
awk -F',' '{print $8}' incident-tracker.csv | sort | uniq -c | sort -rn
```

---

## ANNUAL TABLETOP EXERCISE

FedRAMP requires testing the IR plan at least annually.

### Tabletop exercise template

```markdown
# Tabletop Exercise: [Scenario Name]

**Date:** YYYY-MM-DD
**Facilitator:** [Name]
**Participants:** [Names and roles]

## Scenario
At 2:15 PM, Falco alerts fire indicating an unexpected shell was spawned
inside the payments-api container. CloudTrail shows an IAM role assumption
from an unrecognized IP address 30 minutes prior.

## Discussion Questions
1. Who gets paged first? What's the classification?
2. What's the first containment action?
3. How do you determine if data was exfiltrated?
4. What evidence do you need to preserve?
5. When do you notify the FedRAMP PMO?
6. How do you communicate to internal stakeholders?
7. What's the recovery plan?

## Observed Gaps
| Gap | Action Item | Owner |
|-----|-------------|-------|
| | | |

## Next Exercise Date: YYYY-MM-DD
```

---

## EVIDENCE FOR THE ASSESSOR

| Evidence | Source | Control |
|----------|--------|---------|
| Incident Response Plan document | Version-controlled .md | IR-4 |
| Post-incident reports | Completed templates | IR-4 |
| Incident tracker (all incidents) | Spreadsheet/ticketing system | IR-5 |
| Quarterly incident metrics | Generated report | IR-5 |
| Tabletop exercise results | Exercise template with findings | IR-4 |
| Alert routing configuration | Falcosidekick + AlertManager config | IR-5 |
| On-call schedule | PagerDuty or documented rotation | IR-4 |

---

## COMPLETION CHECKLIST

```
[ ] IR-4:  Incident Response Plan documented and approved
[ ] IR-4:  Roles and responsibilities defined (IC, Security Lead, Platform, Comms)
[ ] IR-4:  Severity classification defined (P1-P4)
[ ] IR-4:  Containment playbooks for: compromised pod, leaked credential, unauthorized access
[ ] IR-4:  Recovery procedures documented (rollback via GitOps)
[ ] IR-4:  FedRAMP PMO reporting requirements documented
[ ] IR-4:  Annual tabletop exercise completed
[ ] IR-4:  Post-incident report template ready
[ ] IR-5:  Incident tracking system in place
[ ] IR-5:  All detection sources feeding alerts (Falco, Prometheus, CloudTrail, GuardDuty)
[ ] IR-5:  Alert routing to Slack + PagerDuty configured
[ ] IR-5:  Quarterly incident metrics generated
[ ] IR-5:  Incident history available for assessor review
```
