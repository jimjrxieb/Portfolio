# Playbook 16 — Kyverno Cleanup Job Troubleshooting

> Diagnose and fix Kyverno cleanup CronJob failures (ImagePullBackOff, CrashLoopBackOff, stale jobs).

## When to Run

- Kyverno cleanup pods in ImagePullBackOff or CrashLoopBackOff
- Report accumulation (admission reports, ephemeral reports growing unbounded)
- After Kyverno upgrade

## Prerequisites

- `kubectl` access to cluster
- `jq` installed

## Steps

### Step 1: Diagnose

```bash
PKG=~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING
bash $PKG/tools/hardening/fix-kyverno-cleanup-jobs.sh --diagnose \
  --output /tmp/kyverno-cleanup-diagnosis.md
```

This checks:
- CronJob schedules and last-run times
- Failed/stuck pods and their error reasons
- Image mismatch between cleanup jobs and main controllers
- Registry pull errors in events

### Step 2: Common issues and fixes

#### ImagePullBackOff

**Root cause:** Cleanup CronJobs reference an image tag that doesn't exist or the registry is unreachable.

**Fix:** The tool auto-patches CronJob images to match the running admission controller image:

```bash
bash $PKG/tools/hardening/fix-kyverno-cleanup-jobs.sh \
  --output /tmp/kyverno-cleanup-fix.md
```

**Manual fix** (if tool can't resolve):

```bash
# Get the working image from admission controller
KYVERNO_IMAGE=$(kubectl get deploy kyverno-admission-controller -n kyverno \
  -o jsonpath='{.spec.template.spec.containers[0].image}')

# Patch each CronJob
for cj in $(kubectl get cronjob -n kyverno -o name); do
  kubectl patch $cj -n kyverno --type='json' \
    -p="[{\"op\": \"replace\", \"path\": \"/spec/jobTemplate/spec/template/spec/containers/0/image\", \"value\": \"$KYVERNO_IMAGE\"}]"
done
```

#### CrashLoopBackOff

**Root cause:** Usually RBAC — cleanup controller SA missing permissions.

```bash
# Check RBAC
kubectl auth can-i --as=system:serviceaccount:kyverno:kyverno-cleanup-jobs \
  delete admissionreports -n kyverno
```

#### Stale reports accumulating

```bash
# Count reports
kubectl get admissionreports -A --no-headers | wc -l
kubectl get clusteradmissionreports --no-headers | wc -l

# Manual cleanup if CronJobs are broken
kubectl delete admissionreports -A --all
kubectl delete clusteradmissionreports --all
```

### Step 3: Verify fix

```bash
# Wait for next CronJob trigger, or trigger manually
kubectl create job --from=cronjob/kyverno-cleanup-admission-reports test-cleanup -n kyverno

# Watch for completion
kubectl get pods -n kyverno -l job-name=test-cleanup -w

# Clean up test job
kubectl delete job test-cleanup -n kyverno
```

### Step 4: Prevent recurrence

After Kyverno Helm upgrades, verify cleanup CronJob images match:

```bash
kubectl get cronjob -n kyverno -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.jobTemplate.spec.template.spec.containers[0].image}{"\n"}{end}'
```

Add to CI/CD post-deploy checks.

## Agent Rank

| Finding | Rank | Action |
|---------|------|--------|
| Cleanup CronJob ImagePullBackOff | D-rank | Auto-patch image to match controller |
| Cleanup CronJob CrashLoopBackOff | C-rank | Diagnose RBAC, escalate if unclear |
| Report accumulation (>1000) | D-rank | Manual cleanup + fix CronJob |
