# Playbook 09: 3PAO Assessment Prep
### Getting Ready for the Assessor

---

## WHAT THIS IS

The 3PAO (Third Party Assessment Organization) is the independent assessor who verifies your FedRAMP compliance. They review your documentation, test your controls, and write the final assessment report that goes to the FedRAMP PMO.

This playbook gets you ready for that assessment.

---

## 4 WEEKS BEFORE ASSESSMENT

### Week -4: Documentation review

```
[ ] SSP is complete and current (no placeholder text)
[ ] POA&M has realistic dates (nothing overdue without justification)
[ ] SAR reflects the latest scan results (< 30 days old)
[ ] Control matrix shows 80%+ MET/PARTIAL
[ ] Control family narratives are written for all 10 families
[ ] Architecture diagrams match actual deployment
[ ] Data flow diagrams are accurate
[ ] Interconnection table is complete
```

### Week -3: Evidence freshness

Evidence must be recent. Stale evidence = failed control.

```bash
# Re-run the full scan to generate fresh evidence
/path/to/GP-CONSULTING/07-FEDRAMP-READY/tools/run-fedramp-scan.sh \
  --target /path/to/app \
  --output ./evidence/pre-assessment-$(date +%Y%m%d) \
  --project "pre-3pao-$(date +%Y%m%d)"

# Generate fresh inventory
./scripts/generate-inventory.sh

# Generate fresh account review
./scripts/quarterly-account-review.sh > evidence/account-review-$(date +%Y%m%d).txt

# Collect all evidence into one folder
mkdir -p evidence/3pao-package
cp -r evidence/pre-assessment-*/* evidence/3pao-package/
```

### Week -2: Control validation

Walk through every control yourself. Pretend you're the assessor.

```bash
# AC-2: Can you show me the account inventory?
kubectl get clusterrolebindings -o wide
aws iam generate-credential-report

# AC-6: Are all containers non-root?
kubectl get pods -A -o json | jq '[.items[] | select(.spec.securityContext.runAsNonRoot != true)] | length'
# Must be 0 (excluding system namespaces)

# AU-2: Is audit logging enabled?
aws eks describe-cluster --name <cluster> --query 'cluster.logging'

# CM-6: Are admission policies enforcing?
kubectl get clusterpolicies -o custom-columns="NAME:.metadata.name,ACTION:.spec.validationFailureAction"
# All should show "Enforce"

# SC-7: Does every namespace have NetworkPolicies?
for ns in $(kubectl get ns -l platform.gp.io/team -o jsonpath='{.items[*].metadata.name}'); do
  count=$(kubectl get networkpolicies -n "$ns" --no-headers 2>/dev/null | wc -l)
  echo "$ns: $count NetworkPolicies"
done
# Every namespace should have at least default-deny + DNS allow

# SC-8: Is all traffic encrypted?
# Check TLS on ingress
kubectl get gateway -A -o yaml | grep -A5 "tls:"
# Check mTLS (if Istio)
istioctl authn tls-check | grep -v "OK"

# SC-28: Is storage encrypted?
aws ec2 describe-volumes --query 'Volumes[?Encrypted==`false`].[VolumeId]' --output text
# Must return nothing

# SI-4: Is Falco running?
kubectl get pods -n falco-system
kubectl logs -n falco-system -l app.kubernetes.io/name=falco --tail=5

# IA-5: Are there any hardcoded secrets?
gitleaks detect --source . --no-banner
# Must return 0 findings
```

### Week -1: Dry run

Run through the assessor's likely questions:

```markdown
## Common 3PAO Questions and Where to Find Answers

### Access Control
Q: "How do you manage user accounts?"
A: [SSP Section 2 → AC-2, evidence: account-review-YYYYMMDD.txt]

Q: "Show me your RBAC configuration."
A: [kubectl get clusterrolebindings, kubectl get rolebindings -A]

Q: "How do you enforce least privilege?"
A: [Kyverno policies + RBAC audit, evidence: kyverno-policies.txt]

### Audit
Q: "What events do you audit?"
A: [K8s audit policy + CloudTrail config, evidence: audit-policy.yaml]

Q: "Show me an audit log entry."
A: [CloudWatch query for K8s audit events]

Q: "How often do you review audit logs?"
A: [Weekly review checklist, evidence: weekly-review-*.pdf]

### Configuration
Q: "What's your baseline configuration?"
A: [Git repo + ArgoCD self-heal, evidence: argocd-app-list.txt]

Q: "How do you detect configuration drift?"
A: [ArgoCD OutOfSync alerts, evidence: argocd-sync-status.txt]

### Encryption
Q: "Show me encryption at rest."
A: [S3 bucket encryption, EBS encryption, RDS encryption audit outputs]

Q: "Show me encryption in transit."
A: [TLS config on Gateway, mTLS config (Istio)]

### Vulnerability Management
Q: "How often do you scan?"
A: [Every commit in CI + weekly scheduled scan, evidence: CI pipeline config]

Q: "Show me your latest scan results."
A: [trivy-fs.json, semgrep.json, evidence < 30 days old]

Q: "How do you handle findings that can't be fixed?"
A: [Risk acceptance records in POA&M]

### Incident Response
Q: "What's your incident response plan?"
A: [IR plan document, version-controlled]

Q: "When was the last time you tested it?"
A: [Tabletop exercise results]

Q: "Show me your incident history."
A: [Incident tracker with all incidents]

### Continuous Monitoring
Q: "What monitoring do you have in place?"
A: [Falco (runtime) + Prometheus (metrics) + CloudTrail (API)]

Q: "How do you know if something is wrong?"
A: [Alert routing: Falco → Slack, Prometheus → PagerDuty]
```

---

## EVIDENCE PACKAGE STRUCTURE

Organize evidence so the assessor can find everything:

```
evidence/3pao-package/
├── 01-documentation/
│   ├── ssp.md                          # System Security Plan
│   ├── poam.md                         # Plan of Action & Milestones
│   ├── sar.md                          # Security Assessment Report
│   ├── control-matrix.md               # Control status overview
│   ├── ir-plan.md                      # Incident Response Plan
│   ├── sdlc.md                         # Secure Development Lifecycle
│   └── control-families/               # Per-family narratives
│       ├── AC-access-control.md
│       ├── AU-audit.md
│       ├── CA-assessment.md
│       ├── CM-config-mgmt.md
│       ├── IA-identification.md
│       ├── IR-incident-response.md
│       ├── RA-risk-assessment.md
│       ├── SA-system-acquisition.md
│       ├── SC-system-comms.md
│       └── SI-system-integrity.md
│
├── 02-scan-results/
│   ├── trivy-fs.json                   # Code dependency scan
│   ├── trivy-images.json               # Container image scan
│   ├── semgrep-results.json            # SAST scan
│   ├── gitleaks-report.json            # Secret scan
│   ├── checkov-results.json            # IaC scan
│   ├── conftest-results.json           # Policy validation
│   ├── kubescape.json                  # Cluster security
│   ├── kube-bench.json                 # CIS benchmark
│   └── nist-mapping-report.json        # NIST control mapping
│
├── 03-configuration-evidence/
│   ├── k8s-audit-policy.yaml           # Audit policy
│   ├── kyverno-policies.txt            # Admission policies
│   ├── argocd-app-list.txt             # GitOps config
│   ├── network-policies.txt            # NetworkPolicy list
│   ├── rbac-audit.json                 # RBAC configuration
│   ├── eks-cluster-config.json         # Cluster settings
│   └── cloudtrail-config.json          # AWS audit config
│
├── 04-encryption-evidence/
│   ├── s3-encryption-audit.txt         # S3 bucket encryption
│   ├── ebs-encryption-audit.txt        # EBS volume encryption
│   ├── rds-encryption-audit.txt        # RDS encryption
│   ├── tls-certificates.txt            # TLS cert details
│   └── kms-key-rotation.txt            # KMS key config
│
├── 05-access-evidence/
│   ├── iam-credential-report.csv       # IAM users + MFA status
│   ├── account-review-YYYYMMDD.txt     # Quarterly review
│   └── oidc-config.txt                 # SSO/OIDC setup
│
├── 06-monitoring-evidence/
│   ├── falco-deployment.txt            # Falco pods status
│   ├── prometheus-rules.txt            # Alert rules
│   ├── cloudwatch-alarms.txt           # AWS alarms
│   └── weekly-reviews/                 # Audit review logs
│       ├── review-2026-03-03.pdf
│       └── review-2026-03-10.pdf
│
├── 07-incident-evidence/
│   ├── incident-tracker.csv            # All incidents
│   ├── tabletop-exercise-2026.pdf      # Annual exercise
│   └── post-incident-reports/          # Individual reports
│
├── 08-inventory/
│   ├── container-images.txt            # All images in cluster
│   ├── aws-resources.json              # Cloud resource inventory
│   ├── k8s-deployments.json            # K8s workloads
│   └── sboms/                          # Per-image SBOMs
│
└── 09-ci-cd-evidence/
    ├── github-workflow.yml             # Pipeline config
    ├── pipeline-run-logs/              # Recent run logs
    └── pre-commit-config.yaml          # Pre-commit hooks
```

---

## ASSESSMENT DAY

### What to have ready

```
[ ] Laptop with kubectl access to the cluster
[ ] AWS console access (read-only for assessor walkthrough)
[ ] ArgoCD UI access
[ ] Grafana/Prometheus access
[ ] Evidence package (organized per structure above)
[ ] SSP printed or on shared screen
[ ] Incident tracker open
[ ] Team available: Platform Lead, Security Lead, App Dev Lead
```

### What the assessor will do

1. **Document review** (Day 1-2): Read SSP, POA&M, control narratives
2. **Evidence validation** (Day 2-3): Verify scan results, check configs match documentation
3. **Technical testing** (Day 3-5): Run their own scans, test controls, try to break things
4. **Interviews** (Throughout): Ask team members about processes, incident handling, etc.
5. **Report writing** (Week 2): Write the SAR with their findings

### What NOT to do

- Don't fake evidence or manufacture scan results
- Don't deploy security controls the day before and claim they've been running
- Don't answer questions you don't know — say "I'll get that information"
- Don't argue with findings — document disagreements for the response phase

---

## POST-ASSESSMENT

After the 3PAO delivers their report:

1. **Review findings** — understand each one
2. **Update POA&M** — add any new findings from the 3PAO
3. **Fix what you can** — address findings before final submission
4. **Submit to FedRAMP PMO** — SSP + SAR + POA&M
5. **Begin continuous monitoring** — monthly scans, quarterly reviews

---

## COMPLETION CHECKLIST

```
[ ] Documentation complete (SSP, POA&M, SAR, control narratives)
[ ] Evidence < 30 days old
[ ] Control matrix shows 80%+ MET/PARTIAL
[ ] Zero open critical/high findings (or documented in POA&M with dates)
[ ] All pods run non-root with security contexts
[ ] NetworkPolicies in every namespace
[ ] RBAC follows least privilege
[ ] Audit logging covers all control plane operations
[ ] Encryption at rest verified (S3, EBS, RDS)
[ ] Encryption in transit verified (TLS/mTLS)
[ ] CI/CD generates fresh evidence on every deploy
[ ] Incident response plan tested (tabletop exercise)
[ ] Account review completed (quarterly)
[ ] Falco deployed and generating events
[ ] Evidence package organized and accessible
[ ] Team briefed on common assessor questions
```
