# Playbook: Deploy Admission Control

> Deploy Kyverno or Gatekeeper in audit mode to watch every kubectl apply.
>
> **When:** After the initial audit. Runs for 1 week gathering violations before you fix anything.
> **Time:** ~15 min to deploy, then 1 week of observation

---

## The Principle

Audit first, enforce later. Deploy admission control in audit mode so it logs every violation without blocking anything. After 1 week of data, you know exactly what to fix before flipping to enforce.

---

## Step 1: Choose Your Engine

| Engine | Best For | Requires |
|--------|----------|----------|
| **Kyverno** | Most engagements. Simpler, YAML-native policies. | Nothing extra — self-contained |
| **Gatekeeper** | Client already uses OPA/Rego. | OPA knowledge |

**Default recommendation: Kyverno.** It's simpler, doesn't require learning Rego, and supports mutations (auto-fix at admission time).

---

## Step 2: Deploy in Audit Mode

```bash
PKG=~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING

# Kyverno (recommended)
bash $PKG/tools/admission/deploy-policies.sh --engine kyverno --mode audit

# Gatekeeper (if client already uses OPA)
bash $PKG/tools/admission/deploy-policies.sh --engine gatekeeper --mode audit

# With namespace exclusions
bash $PKG/tools/admission/deploy-policies.sh \
  --engine kyverno \
  --mode audit \
  --namespace-exclusions kube-system,kube-public,monitoring

# Dry run first
bash $PKG/tools/admission/deploy-policies.sh --engine kyverno --mode audit --dry-run
```

**What the script does:**
1. Checks if engine is already installed
2. Installs Kyverno or Gatekeeper if needed
3. Deploys all policies in audit mode
4. Verifies policies are active
5. Runs smoke tests

---

## Step 3: Verify Deployment

```bash
# Kyverno — check policies
kubectl get clusterpolicies
kubectl get policyreports -A

# Gatekeeper — check constraints
kubectl get constraints
kubectl get constrainttemplates
```

---

## Step 4: Let It Observe (1 Week)

The admission controller logs every violation without blocking. Let it run for a week during normal development.

---

## Step 5: Generate Violation Report

After 1 week of observation:

```bash
bash $PKG/tools/hardening/generate-fix-report.sh \
  --namespace all \
  --top 20 \
  --output ~/GP-copilot/GP-S3/5-consulting-reports/<client>/violation-report-$(date +%Y%m%d).md
```

The report shows:
- Every violated policy ranked by count
- Affected deployments
- Exact YAML to fix each violation
- Which remediation template to use

---

## What Gets Deployed (Kyverno — 13 Policies)

| Policy | What It Catches |
|--------|---------------|
| `disallow-privileged` | Privileged containers |
| `disallow-privilege-escalation` | allowPrivilegeEscalation: true |
| `require-run-as-nonroot` | Containers running as root |
| `disallow-host-namespaces` | hostPID, hostIPC, hostNetwork |
| `require-seccomp-strict` | Missing seccomp profile |
| `require-apparmor-profile` | Missing AppArmor annotation |
| `require-drop-all-capabilities` | Capabilities not dropped |
| `disallow-latest-tag` | Using :latest image tag |
| `require-resource-limits` | Missing CPU/memory limits |
| `require-readonly-rootfs` | Writable root filesystem |
| `require-pss-labels` | Missing PSS namespace labels |
| `require-semver-tags` | Non-semver image tags |
| `require-runtime-class-untrusted` | Missing RuntimeClass for untrusted |

---

## Next Steps

- Fix the violations the report found? → [03-automated-fixes.md](03-automated-fixes.md) + [04-fix-manifests.md](04-fix-manifests.md)
- Wire CI/CD to catch violations pre-merge? → [06-wire-cicd.md](06-wire-cicd.md)
- Ready to enforce? → [07-audit-to-enforce.md](07-audit-to-enforce.md)

---

*Ghost Protocol — K8s Hardening Package (CKA + CKS)*
