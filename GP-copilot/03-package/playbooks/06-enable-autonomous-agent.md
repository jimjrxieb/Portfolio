# Playbook: Enable Autonomous Agent

> Progressive enablement of jsa-infrasec auto-fix: E → D → C rank.
> Requires `--with-jsa` deployment and package 04-JSA-AUTONOMOUS.
>
> **When:** Week 3-4, after Falco is tuned and false positive rate is <50/day.
> **Time:** ~15 min per rank level

---

## Safety Pre-Checks (Do Not Skip)

```bash
PKG=~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME

# 1. JADE is healthy
curl http://100.114.41.76:8000/api/jade/health

# 2. Health-check is clean
bash $PKG/tools/health-check.sh

# 3. False positive rate is <50/day
bash $PKG/tools/tune-falco.sh --show-top

# 4. Test rollback safety net
bash $PKG/tools/test-rollback.sh
```

The rollback test creates a temp deployment, snapshots it, applies a bad change (privileged: true), restores from snapshot, and verifies. Must PASS before enabling auto-fix.

---

## Step 1: Enable E-Rank Only (Day 1-2)

```bash
kubectl patch configmap -n jsa-infrasec jsa-infrasec-config \
  --type merge \
  -p '{"data":{"AUTO_FIX_ENABLED":"true","AUTO_FIX_MAX_RANK":"E","DRY_RUN":"false"}}'

kubectl rollout restart -n jsa-infrasec deploy/jsa-infrasec
```

E-rank actions: capture logs, create state snapshots, tag resources. **No workload changes.**

Monitor:
```bash
kubectl logs -n jsa-infrasec deploy/jsa-infrasec -f | grep -E "FIX|RANK|AUTO"
```

---

## Step 2: Enable D-Rank (Day 3+)

```bash
kubectl patch configmap -n jsa-infrasec jsa-infrasec-config \
  --type merge \
  -p '{"data":{"AUTO_FIX_MAX_RANK":"D"}}'

kubectl rollout restart -n jsa-infrasec deploy/jsa-infrasec
```

D-rank auto-fixes: patch deployments with security contexts, rotate exposed secrets, apply NetworkPolicies.

Watch fix rate vs rollback rate:
```bash
kubectl logs -n jsa-infrasec deploy/jsa-infrasec --tail=200 | grep -E "FIX_APPLIED|ROLLBACK"
```

**Target:** rollback rate <5%. If higher, tune Falco rules more.

---

## Step 3: Enable C-Rank with JADE (Week 4)

C-rank requires JADE approval: isolate compromised pods, kill suspicious containers, update RBAC.

```bash
kubectl patch configmap -n jsa-infrasec jsa-infrasec-config \
  --type merge \
  -p '{"data":{"AUTO_FIX_MAX_RANK":"C","JADE_APPROVAL_REQUIRED":"true"}}'

kubectl rollout restart -n jsa-infrasec deploy/jsa-infrasec
```

**JADE max authority is C-rank hardcoded.** It cannot approve B or S rank fixes.

---

## Step 4: Test the Alert Pipeline

```bash
# Replay a test alert through jsa-infrasec
bash $PKG/tools/replay-alert.sh --type shell-spawn

# Preview only (see the JSON without sending)
bash $PKG/tools/replay-alert.sh --type shell-spawn --dry-run
```

Available built-in types: `shell-spawn`, `crypto-mining`, `privilege-escalation`, `data-exfiltration`, `secret-access`

---

## Rollback Safety

If rollback rate exceeds 10%:

```bash
# Reduce auto-fix ceiling while investigating
kubectl patch configmap -n jsa-infrasec jsa-infrasec-config \
  --type merge \
  -p '{"data":{"AUTO_FIX_MAX_RANK":"E"}}'

kubectl rollout restart -n jsa-infrasec deploy/jsa-infrasec

# Review recent rollbacks
kubectl logs -n jsa-infrasec deploy/jsa-infrasec --tail=500 | grep ROLLBACK
```

---

## Next Steps

- Set up operations → [07-operations.md](07-operations.md)

---

*Ghost Protocol — Runtime Security Package (CKS)*
