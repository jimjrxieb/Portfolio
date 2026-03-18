# Playbooks — Step-by-Step Guides

> Each playbook walks through one specific workflow for AWS cloud security and EKS deployment.
>
> **Three-tier rule:** Runbook (diagnose) → Script (automate) → Playbook (guide)
>
> **Execution order:** Network first → IAM → Encryption → EKS → CI/CD → Monitoring → Deploy → Validate

---

## Playbook Index

### Phase 1: Foundation (Industry Standard)

| # | Playbook | What | Tool | Type |
|---|----------|------|------|------|
| 01 | [VPC & Network Security](01-vpc-network-security.md) | VPC, subnets, SGs, flow logs, endpoints | `tools/deploy-terraform.sh` | Industry Standard |
| 02 | [IAM Hardening](02-iam-hardening.md) | Root MFA, stale keys, IRSA, policies | `aws iam` | Industry Standard |
| 03 | [Data Protection](03-data-protection.md) | KMS, S3 encryption, Secrets Manager | `aws kms`, `aws s3api` | Industry Standard |

### Phase 2: EKS Platform (Industry Standard + GP-Copilot)

| # | Playbook | What | Tool | Type |
|---|----------|------|------|------|
| 04 | [EKS Cluster Deploy](04-eks-cluster-deploy.md) | Cluster, nodes, addons, OIDC | `aws eks`, `eksctl` | Industry Standard |
| 05 | [EKS Security Hardening](05-eks-security-hardening.md) | Private endpoint, logging, envelope encryption, IRSA | `tools/validate-aws-security.sh` | **GP-Copilot** |
| 06 | [ECR & CI/CD Pipeline](06-ecr-cicd-pipeline.md) | ECR repos, OIDC federation, GHA workflow | `ci-templates/deploy-prod.yml` | **GP-Copilot** |

### Phase 3: Observability (Industry Standard)

| # | Playbook | What | Tool | Type |
|---|----------|------|------|------|
| 07 | [Monitoring & Logging](07-monitoring-logging.md) | CloudTrail, GuardDuty, Security Hub, CloudWatch | `monitoring/README.md` | Industry Standard |

### Phase 4: Deploy (GP-Copilot)

| # | Playbook | What | Tool | Type |
|---|----------|------|------|------|
| 08 | [Deploy Production](08-deploy-prod.md) | Helm deploy to prod EKS (--atomic, HPA, PDB) | `tools/deploy-prod.sh` | **GP-Copilot** |

### Phase 5: Operate (GP-Copilot)

| # | Playbook | What | Tool | Type |
|---|----------|------|------|------|
| 09 | [Incident Response](09-incident-response.md) | IR playbooks: compromised creds, public S3, rogue EC2 | `aws cloudtrail`, `aws ec2` | **GP-Copilot** |
| 10 | [Security Validation](10-security-validation.md) | Full audit: network, IAM, encryption, EKS, monitoring | `tools/validate-aws-security.sh` | **GP-Copilot** |

### What's the difference?

**Industry Standard** = Any cloud security team should be doing this. Creating VPCs, enabling CloudTrail, deploying EKS with logging, configuring IAM. The tools are AWS-native. The playbooks document best practice.

**GP-Copilot Value-Add** = This is what we bring. AWS gives you the building blocks — we harden them. EKS comes with public endpoints, no encryption, minimal logging. We lock it down, wire IRSA, enforce IMDSv2, deploy with `--atomic` rollback, run a 9-step security pipeline, and produce a compliance scorecard. Nobody else gives you `deploy-prod.sh` that audits EKS security, checks ArgoCD ownership, enforces PSS restricted, scans with checkov + kubescape, deploys atomically, and prints a security scorecard — all in one command.

---

## Typical Engagement Flow

```
Phase 1: Foundation
  01-vpc-network-security    ← VPC, subnets, SGs, flow logs, VPC endpoints
  02-iam-hardening           ← Root MFA, policies, stale keys, Access Analyzer
  03-data-protection         ← KMS, S3 encryption, Secrets Manager

Phase 2: EKS Platform
  04-eks-cluster-deploy      ← Cluster, node groups, addons, OIDC
  05-eks-security-hardening  ← Private endpoint, logging, encryption, IRSA, IMDSv2
  06-ecr-cicd-pipeline       ← ECR repos, OIDC federation, GHA workflows

Phase 3: Observability
  07-monitoring-logging      ← CloudTrail, GuardDuty, Security Hub, CloudWatch

Phase 4: Deploy
  08-deploy-prod             ← Helm deploy with full security validation

Phase 5: Operate
  09-incident-response       ← When things go wrong
  10-security-validation     ← Prove everything works (audit deliverable)
```

Phases 1-3 build the infrastructure. Phase 4 deploys the app. Phase 5 operates and validates.

---

## Dev → Staging → Prod Pipeline

The production deploy (Playbook 08) is the final step in a three-environment pipeline:

| Environment | Package | Playbook | PSS | Replicas | HPA |
|------------|---------|----------|-----|----------|-----|
| **Dev** | 01-APP-SEC | [12-deploy-dev](../../01-APP-SEC/playbooks/12-deploy-dev.md) | baseline | 1 | No |
| **Staging** | 02-CLUSTER-HARDENING | [17a-deploy-stage](../../02-CLUSTER-HARDENING/playbooks/17a-deploy-stage.md) | restricted | 2 | No |
| **Prod** | 06-CLOUD-SECURITY | [08-deploy-prod](08-deploy-prod.md) | restricted | 3+ | Yes |

Same image artifact flows through all three. Security context is identical in staging and prod.

---

## Where Things Live

| What | Directory |
|------|-----------|
| **Playbooks** | `playbooks/` (you are here) |
| **IaC Templates** | `terraform/`, `cloudformation/` |
| **Security Patterns** | `templates/` (7 patterns: VPC isolation, zero-trust SG, etc.) |
| **Tools** | `tools/` (8 scripts: deploy, validate, migrate, estimate) |
| **CI Templates** | `ci-templates/` (deploy-prod.yml) |
| **Monitoring** | `monitoring/` (4 dashboards, 24 alerts) |
| **Examples** | `examples/` (manufacturing company case study) |

---

## Source Runbooks

These playbooks were built from battle-tested operational runbooks:

| Runbook | Feeds Into |
|---------|-----------|
| `networking-vpc.md` | Playbook 01 |
| `iam-security.md` | Playbook 02 |
| `data-protection.md` | Playbook 03 |
| `eks-operations.md` | Playbooks 04, 05 |
| `ecr-gha-oidc-setup.md` | Playbook 06 |
| `monitoring-logging.md` | Playbook 07 |
| `incident-response.md` | Playbook 09 |

---

*Ghost Protocol — Cloud Security Package*
