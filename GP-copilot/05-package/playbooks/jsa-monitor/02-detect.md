# Phase 2: Configure Detection

Source playbooks: `03-DEPLOY-RUNTIME/playbooks/04-tune-falco.md`, `10-deploy-logging.md`
Automation level: **73% autonomous (D-rank)**, 18% JADE (C-rank), 9% human (B-rank)

## What the Agent Does

```
1. Collect Falco baseline (24h alert patterns)
2. Generate allowlist for known-good patterns (JADE approves)
3. Deploy log pipeline (Fluent Bit → backend)
4. Start 8 signal watchers
5. Verify end-to-end detection pipeline
```

## Falco Tuning

### Baseline Collection — D-rank

```bash
03-DEPLOY-RUNTIME/tools/tune-falco.sh --baseline --duration 24h

# Collects:
# - Rule trigger frequency
# - Top triggered rules
# - Pods/containers triggering alerts
# - Time-of-day patterns (CI runners, cron jobs)
```

### Allowlist Generation — D-rank (generate) + C-rank (apply)

```bash
# Generate candidates (D-rank, mechanical)
03-DEPLOY-RUNTIME/tools/tune-falco.sh --generate-allowlist

# Categories of known-good suppressions:
# - Monitoring agents: prometheus, grafana, datadog, newrelic
# - CI/CD runners: github-actions, gitlab-runner, jenkins-agent
# - Log collectors: fluent-bit, fluentd, vector
# - Dev/staging shells: developer debug sessions
# - Config management: ansible, puppet, chef
```

JADE reviews each candidate (C-rank):
```
ESCALATE to JADE:
  "Review allowlist candidates. For each suppression:
   1. Is this process legitimately doing what Falco flagged?
   2. Would suppressing it hide a real attack?
   Approve safe suppressions. Deny anything risky."
```

## Log Pipeline

### Fluent Bit — D-rank

```bash
03-DEPLOY-RUNTIME/tools/deploy.sh --component fluent-bit

# Fluent Bit DaemonSet collects:
# - Container stdout/stderr (all pods)
# - Kubernetes metadata enrichment (pod, namespace, labels)
# - Falco JSON output
# - Kubernetes audit logs (if configured)
```

### Log Backend — C-rank (JADE selects)

```
ESCALATE to JADE:
  "Select log backend for this cluster."

  Loki:
  - Lighter footprint (256Mi-1Gi)
  - LogQL queries (grep-style)
  - Grafana-native
  - Cheaper storage (label-indexed, not full-text)
  - Best for: small-medium clusters, Grafana shops

  Elasticsearch:
  - Heavier (2-8Gi per node)
  - KQL/Lucene queries (full-text search)
  - Kibana UI
  - More powerful analytics
  - Best for: large clusters, compliance-heavy, existing ELK

  Default: Loki (lighter, Grafana-native)
```

### Verify Pipeline — D-rank

```bash
# Generate test log
kubectl run log-test --image=busybox --restart=Never --rm -i \
  -- echo "jsa-monitor-test-$(date +%s)"

# Query backend to verify it arrived
# Loki: logcli query '{namespace="default"} |= "jsa-monitor-test"'
# ES: curl -s 'localhost:9200/_search?q=jsa-monitor-test'
```

## Start Watchers — D-rank

8 watchers, each monitoring a different signal source:

```bash
# K8s events (CrashLoopBackOff, OOMKilled, ImagePullBackOff)
03-DEPLOY-RUNTIME/watchers/watch-events.sh --daemon &

# Configuration drift (live state vs git)
03-DEPLOY-RUNTIME/watchers/watch-drift.sh --daemon &

# Secrets hygiene (orphaned secrets, automount audit)
03-DEPLOY-RUNTIME/watchers/watch-secrets.sh --daemon &

# Network coverage (namespaces without NetworkPolicy)
03-DEPLOY-RUNTIME/watchers/watch-network-coverage.sh --daemon &

# PSS compliance (pods violating namespace PSS labels)
03-DEPLOY-RUNTIME/watchers/watch-pss.sh --daemon &

# Policy violations (Kyverno/Gatekeeper audit events)
03-DEPLOY-RUNTIME/watchers/watch-policy-violations.sh --daemon &

# Supply chain (unsigned images, missing SBOMs)
03-DEPLOY-RUNTIME/watchers/watch-supply-chain.sh --daemon &

# Data plane health (pod readiness, service endpoints)
03-DEPLOY-RUNTIME/watchers/watch-dataplane.sh --daemon &
```

Each watcher:
- Runs continuously (watch API or periodic poll)
- Normalizes findings to standard format
- Writes to FindingsStore + JSONL
- Routes to response-playbook.yaml for action

## Phase 2 Gate

```
PASS if: Falco tuned + log pipeline verified + all 8 watchers running
FAIL: Deploy what works, log failures, continue
```
