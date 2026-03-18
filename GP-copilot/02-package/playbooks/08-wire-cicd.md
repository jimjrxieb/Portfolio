# Playbook: Wire CI/CD

> Set up conftest in the client's CI pipeline so non-compliant K8s manifests are rejected before merge.
>
> **When:** After policies are deployed. Prevents new violations from entering the codebase.
> **Time:** ~10 min

---

## The Principle

Admission control catches violations at `kubectl apply`. CI catches them at `git push` — before they even reach the cluster. Same policies, earlier in the pipeline.

---

## Step 1: Copy Policies to Client Repo

```bash
bash ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/platform/setup-cicd.sh \
  --client-repo ~/GP-copilot/GP-PROJECTS/01-instance/slot-1/<client-repo> \
  --manifests-dir k8s

# Preview first
bash ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/platform/setup-cicd.sh \
  --client-repo ~/GP-copilot/GP-PROJECTS/01-instance/slot-1/<client-repo> \
  --manifests-dir k8s \
  --dry-run
```

**What it creates in the client repo:**
```
<client-repo>/
  policies/conftest/           ← 6 Rego policies
    cicd-security.rego
    compliance-controls.rego
    image-security.rego
    secrets-management.rego
    ...
  .github/workflows/
    policy-check.yml           ← Blocks PR if manifests fail
  scripts/
    test-policies.sh           ← Run locally before pushing
```

---

## Step 2: Test Locally

```bash
cd <client-repo>
bash scripts/test-policies.sh
```

**Expected output:**
```
Testing 15 manifests against 6 policies...

FAIL: k8s/payment-api.yaml
  - require-run-as-nonroot: Containers must run as non-root
  - require-resource-limits: Containers must have resource limits

PASS: k8s/user-api.yaml
PASS: k8s/billing-api.yaml

Results: 13 passed, 2 failed
```

---

## Step 3: Test Terraform IaC (If Applicable)

Terraform policies run from the source of truth — no copy needed:

```bash
conftest test <client-repo>/terraform/*.tf \
  --policy ~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/templates/policies/terraform/
```

**Terraform policies cover:** S3 encryption + public access, IAM wildcards + admin roles, VPC flow logs + open security groups, general Terraform hardening.

---

## Step 4: Commit and Push

```bash
cd <client-repo>
git add policies/ .github/workflows/policy-check.yml scripts/test-policies.sh
git commit -m "ci: add K8s policy-as-code checks (conftest + Rego)"
git push
```

---

## Step 5: Set Up Branch Protection

```
GitHub repo → Settings → Branches → Branch protection rules → Add rule

Branch name pattern: main

  [x] Require status checks to pass before merging
      Required checks: policy-check
  [x] Require branches to be up to date before merging
```

---

## Next Steps

- Fix the violations CI is catching? → [04-fix-manifests.md](04-fix-manifests.md)
- Ready to move admission control to enforce? → [07-audit-to-enforce.md](07-audit-to-enforce.md)

---

*Ghost Protocol — K8s Hardening Package (CKA + CKS)*
