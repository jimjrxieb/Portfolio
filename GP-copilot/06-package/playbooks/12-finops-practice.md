# Playbook 12 — FinOps Practice

> Build a FinOps practice from scratch: tagging strategy, cost allocation, optimization culture, and governance automation. FinOps is not "cut costs" — it's "maximize business value per dollar."
>
> **When:** After cloud infrastructure is deployed and stable. Ideally within the first month of production.
> **Audience:** Platform engineers, engineering managers, finance stakeholders.
> **Time:** ~1 day (initial setup), then ongoing operational cadence

---

## Prerequisites

- AWS account with Cost Explorer enabled
- Tag enforcement capability (SCPs for AWS, Kyverno for K8s)
- At least one production workload running (need real data)
- Budget owner identified (who approves spend?)

---

## The FinOps Model

```
THREE PHASES (cycle continuously):
  1. INFORM   — see what you're spending, who's spending it, on what
  2. OPTIMIZE — right-size, eliminate waste, negotiate rates
  3. OPERATE  — build culture, automate guardrails, continuous improvement

FinOps is NOT just "cut costs." It's "maximize business value per dollar."
```

**Golden Rule:** Every engineer should know what their code costs to run. If they don't, your FinOps practice hasn't started yet.

---

## Phase 1: INFORM — Get Visibility

### Step 1: Tagging Strategy

Enforce these tags on every resource. Without them, you can't attribute cost.

```
MINIMUM TAGS (enforce via policy):
  - team         → who owns the cost
  - environment  → prod / staging / dev / sandbox
  - project      → what business initiative
  - cost-center  → maps to finance GL code
  - managed-by   → terraform / helm / manual (drift detection)

OPTIONAL BUT POWERFUL:
  - ttl           → auto-delete after date (dev/sandbox resources)
  - data-class    → public / internal / confidential / restricted
```

#### AWS: Tag Enforcement via SCP

```bash
cat <<'POLICY' > deny-untagged.json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyUntaggedResources",
    "Effect": "Deny",
    "Action": ["ec2:RunInstances", "rds:CreateDBInstance", "s3:CreateBucket"],
    "Resource": "*",
    "Condition": {
      "Null": {
        "aws:RequestTag/team": "true",
        "aws:RequestTag/environment": "true",
        "aws:RequestTag/project": "true"
      }
    }
  }]
}
POLICY

aws organizations create-policy \
  --name "RequireTags" \
  --type SERVICE_CONTROL_POLICY \
  --content file://deny-untagged.json
```

#### K8s: Label Enforcement via Kyverno

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-cost-labels
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-team-and-project
      match:
        any:
          - resources:
              kinds: ["Deployment", "StatefulSet", "DaemonSet"]
      validate:
        message: "Labels 'team' and 'project' are required for cost attribution."
        pattern:
          metadata:
            labels:
              team: "?*"
              project: "?*"
```

Policy source of truth: `02-CLUSTER-HARDENING/templates/policies/`

### Step 2: Cost Allocation and Showback

```
SHOWBACK vs CHARGEBACK:
  Showback  → "Your team spent $X last month" (visibility, no billing impact)
  Chargeback → "Your team's budget is debited $X" (real financial accountability)

START WITH SHOWBACK. Chargeback without accuracy = politics.
```

#### Export Cost & Usage Reports

```bash
aws cur put-report-definition \
  --report-definition '{
    "ReportName": "daily-cost-report",
    "TimeUnit": "DAILY",
    "Format": "Parquet",
    "Compression": "Parquet",
    "S3Bucket": "your-cur-bucket",
    "S3Prefix": "cur/",
    "S3Region": "us-east-1",
    "AdditionalSchemaElements": ["RESOURCES"],
    "RefreshClosedReports": true,
    "ReportVersioning": "OVERWRITE_REPORT"
  }'
# Query with Athena or pipe into Grafana/Kubecost
```

### Step 3: Track Unit Economics

```
DON'T TRACK: "We spent $50K on AWS this month"
DO TRACK:    "Cost per transaction = $0.003" or "Cost per active user = $1.20/mo"

FORMULA:
  Unit Cost = Total Infrastructure Cost / Business Metric

EXAMPLES:
  SaaS:     cost per active user per month
  E-comm:   cost per order processed
  API:      cost per 1M API calls
  Platform: cost per deployment / cost per developer
```

---

## Phase 2: OPTIMIZE — Cut the Fat

### The Big Five Cost Killers

| # | Problem | Typical Waste | Playbook |
|---|---------|---------------|----------|
| 1 | Idle resources | 20-30% of bill | `06-CLOUD-SECURITY/playbooks/11-aws-cost-optimization.md` Step 6 |
| 2 | Oversized resources | 15-25% waste | `11-aws-cost-optimization.md` Step 2 |
| 3 | Wrong pricing model | 20-40% available | `11-aws-cost-optimization.md` Step 5 |
| 4 | Data transfer | Silent killer | `11-aws-cost-optimization.md` Step 3 |
| 5 | Storage sprawl | Grows forever | `11-aws-cost-optimization.md` Step 4 |

### K8s Right-Sizing

```bash
# Find over-requested pods (need metrics-server or Prometheus)
kubectl top pods -A --sort-by=cpu | head -20

# Compare requests vs actual usage
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[0].resources.requests.cpu}{"\t"}{.spec.containers[0].resources.requests.memory}{"\n"}{end}'
```

Full K8s cost playbook: `02-CLUSTER-HARDENING/playbooks/13c-k8s-cost-optimization.md`

### Commitment Discounts

```
STRATEGY:
  1. Cover steady-state baseline with 1-yr No Upfront Savings Plans
  2. Use Spot for fault-tolerant workloads (60-90% savings)
  3. Keep 20% headroom on On-Demand for spikes

DON'T:
  - Over-commit (3-yr All Upfront for a startup)
  - Forget to check utilization of existing RIs
```

### Scheduled Scaling

```bash
# Stop dev/staging outside business hours (save ~65%)

# K8s CronJob to scale down non-prod
cat <<'EOF' > scale-down-dev.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: scale-down-dev
  namespace: cost-automation
spec:
  schedule: "0 18 * * 1-5"  # 6pm weekdays
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: scaler
          containers:
            - name: scaler
              image: bitnami/kubectl:1.29
              command:
                - /bin/sh
                - -c
                - |
                  for ns in dev staging qa; do
                    kubectl scale deploy --all -n $ns --replicas=0
                  done
          restartPolicy: OnFailure
EOF
```

---

## Phase 3: OPERATE — Build the Culture

### FinOps Team Structure

```
SMALL ORG (< 50 engineers):
  → 1 person (platform/SRE) owns cost visibility
  → Monthly cost review in engineering standup
  → Automated anomaly alerts

MID ORG (50-200 engineers):
  → Dedicated FinOps analyst or embedded in platform team
  → Per-team showback dashboards
  → Quarterly optimization sprints

LARGE ORG (200+ engineers):
  → FinOps team (2-5 people)
  → Chargeback model
  → FinOps guardrails in CI/CD (cost estimation before deploy)
```

### Anomaly Detection

```bash
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget '{
    "BudgetName": "monthly-total",
    "BudgetLimit": {"Amount": "10000", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }' \
  --notifications-with-subscribers '[{
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [{
      "SubscriptionType": "EMAIL",
      "Address": "team@example.com"
    }]
  }]'
```

### Cost Governance Ladder

```
IMPLEMENT IN ORDER — don't jump to hard stops without visibility:
  1. Visibility   → dashboards, reports (passive)
  2. Alerts       → budget thresholds, anomaly detection (reactive)
  3. Guardrails   → tag enforcement, instance type restrictions (preventive)
  4. Hard Stops   → SCP blocking expensive instance types, quota limits (blocking)
```

---

## FinOps Maturity Model

```
CRAWL:
  ✓ Cost allocation tags on 80%+ resources
  ✓ Monthly cost review
  ✓ Basic budgets and alerts
  ✓ Know your top 5 cost drivers

WALK:
  ✓ Per-team showback dashboards
  ✓ Right-sizing recommendations actioned quarterly
  ✓ Savings Plans covering 60%+ of steady-state
  ✓ Dev/staging scheduled scaling
  ✓ Infracost in CI/CD

RUN:
  ✓ Unit economics tracked (cost per user/transaction)
  ✓ Anomaly detection with auto-remediation
  ✓ Spot instances for fault-tolerant workloads
  ✓ Chargeback or mature showback
  ✓ FinOps embedded in engineering culture
```

---

## Tools

### Cloud-Native (Free)

| Tool | What It Does | When to Use |
|------|-------------|-------------|
| AWS Cost Explorer | Spend breakdown by service/tag/account | Daily cost checks |
| AWS Trusted Advisor | Right-sizing, idle resource detection | Monthly optimization review |
| AWS Compute Optimizer | ML-based instance recommendations | Before buying Savings Plans |

### Open Source

| Tool | What It Does | When to Use |
|------|-------------|-------------|
| **Kubecost** | K8s cost allocation per namespace/pod/label | Any K8s cluster |
| **OpenCost** | CNCF K8s cost monitoring (Kubecost core) | Pure open source alternative |
| **Karpenter** | K8s node autoscaling (Spot, right-sizing) | EKS clusters |
| **Infracost** | Cost estimation in Terraform PRs | CI/CD — shift-left cost |
| **Cloud Custodian** | Policy-as-code for cloud resource mgmt | Automated cleanup and tagging |
| **Goldilocks** | VPA recommendations for K8s pods | Right-sizing pod requests |

### Quick Setup: Kubecost + Infracost

```bash
# Kubecost — install in 2 minutes
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm install kubecost kubecost/cost-analyzer \
  --namespace kubecost --create-namespace \
  --set kubecostToken="your-token"

kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090

# Infracost — cost estimates in Terraform PRs
curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh
infracost auth login
infracost breakdown --path .
# Add INFRACOST_API_KEY to repo secrets for CI integration
```

---

## Quick Wins — Do These This Week

```
1. TURN ON COST EXPLORER TAGS       → 5 min, $0
2. CREATE A MONTHLY BUDGET + ALERT  → 10 min, $0
3. FIND UNATTACHED EBS VOLUMES      → see playbook 11 Step 4
4. FIND IDLE LOAD BALANCERS         → check CloudWatch RequestCount = 0 for 7 days
5. CHECK S3 LIFECYCLE POLICIES      → if none exist, you're hoarding data
6. INSTALL KUBECOST                 → 2 min, free tier covers 1 cluster
7. RIGHT-SIZE ONE THING             → pick your most oversized instance, resize it
```

---

## Cross-References

- AWS cost deep-dive: `06-CLOUD-SECURITY/playbooks/11-aws-cost-optimization.md`
- K8s cost optimization: `02-CLUSTER-HARDENING/playbooks/13c-k8s-cost-optimization.md`
- Karpenter: `02-CLUSTER-HARDENING/playbooks/13a-deploy-karpenter.md`
- FinOps + FedRAMP: `07-FEDRAMP-READY/playbooks/11-finops-compliance.md`
