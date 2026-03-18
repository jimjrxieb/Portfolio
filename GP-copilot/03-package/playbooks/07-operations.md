# Playbook: Operations

> Ongoing operations: weekly reports, investigating findings, managing snapshots, troubleshooting.
>
> **When:** Week 5+, after full deployment.
> **Time:** Ongoing

---

## Weekly Reports

```bash
PKG=~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME
REPORTS=~/GP-copilot/GP-S3/5-consulting-reports/<client>

# Auto-generate from live Prometheus data
python3 $PKG/tools/generate-report.py \
  --start 2026-03-01 \
  --end 2026-03-07 \
  --format markdown \
  --output $REPORTS/weekly-report-$(date +%Y%m%d).md

# Generate a demo report with sample data (for sales/onboarding)
python3 $PKG/tools/generate-report.py --demo --output demo-report.md
```

---

## Investigate Findings (Requires --with-jsa)

```bash
# Debug the most recent finding
bash $PKG/tools/debug-finding.sh --latest

# Debug a specific finding
bash $PKG/tools/debug-finding.sh --finding-id FIND-12345

# Filter by severity
bash $PKG/tools/debug-finding.sh --latest --severity critical
```

---

## Manage Snapshots (Requires --with-jsa)

```bash
# List all snapshots
bash $PKG/tools/snapshot-browser.sh --list

# Filter by deployment
bash $PKG/tools/snapshot-browser.sh --list --deployment payment-api

# Restore from snapshot
bash $PKG/tools/snapshot-browser.sh --restore snap-001

# Preview restore (dry-run)
bash $PKG/tools/snapshot-browser.sh --restore snap-001 --dry-run

# Clean up old snapshots
bash $PKG/tools/snapshot-browser.sh --cleanup --older-than 30
```

---

## SLOs (Track These)

| Metric | Target | Action if Breached |
|--------|--------|--------------------|
| Falco pods running | 100% of nodes | `kubectl rollout restart -n falco daemonset/falco` |
| falco-exporter running | 1 pod | Check gRPC connection to Falco |
| Alerts/day | <50 | Run `tune-falco.sh --show-top`, add exceptions |
| Detection latency (p95) | <10s | Verify Falco daemonset health |

**Additional SLOs (with --with-jsa):**

| Metric | Target | Action if Breached |
|--------|--------|--------------------|
| Auto-fix rollback rate | <5% | Drop max rank to E, investigate |
| jsa-infrasec uptime | 99.9% | Check OOM limits, scale memory |
| JADE decision latency (p95) | <5s | Check JADE health, scale resources |

---

## Data-Plane Health Check

Run this when customers report timeouts but pods show Running — or proactively on a schedule.

```bash
# Full data-plane audit
bash $PKG/watchers/watch-dataplane.sh

# Single namespace (e.g., the app namespace)
bash $PKG/watchers/watch-dataplane.sh --namespace production

# JSON output for automation
bash $PKG/watchers/watch-dataplane.sh --json
```

**What it catches that the other watchers don't:**

| Symptom | Root Cause | Finding Code |
|---------|-----------|-------------|
| Intermittent 5xx | Service endpoints empty or degraded | DATAPLANE_ENDPOINT_EMPTY |
| Random DNS failures | CoreDNS upstream errors or pod restarts | DATAPLANE_DNS_ERRORS |
| New deploys hang | Service selector doesn't match pod labels | DATAPLANE_SELECTOR_MISMATCH |
| Traffic drops on some nodes | kube-proxy not ready on all nodes | DATAPLANE_PROXY_DEGRADED |
| Pod-to-pod networking broken | CNI plugin degraded | DATAPLANE_CNI_DEGRADED |
| Everything looks fine but isn't | Node under memory/disk/PID pressure | DATAPLANE_NODE_PRESSURE |

**Recommended cadence:** Daily (cron), or immediately when customers report latency/timeout issues.

---

## Troubleshooting

### High alert volume (>100/hr)

```bash
bash $PKG/tools/tune-falco.sh --show-top
# Add exceptions to templates/falco-rules/allowlist.yaml
```

### Falco DaemonSet pods not running

```bash
kubectl get pods -n falco -o wide
kubectl describe pod -n falco <pod-name> | grep -A10 Events
# Common cause: eBPF driver not supported
# Fix: switch to kmod driver
helm upgrade falco falcosecurity/falco -n falco \
  --reuse-values --set driver.kind=kmod
```

### falco-exporter not scraping

```bash
kubectl logs -n falco -l app.kubernetes.io/name=falco-exporter --tail=50
# Common cause: Falco gRPC not enabled
helm upgrade falco falcosecurity/falco -n falco \
  --reuse-values \
  --set falco.grpc.enabled=true \
  --set falco.grpcOutput.enabled=true
```

### jsa-infrasec pod crashed (if --with-jsa)

```bash
kubectl describe pod -n jsa-infrasec -l app=jsa-infrasec | tail -20
kubectl logs -n jsa-infrasec -l app=jsa-infrasec --previous --tail=100
kubectl rollout restart -n jsa-infrasec deploy/jsa-infrasec
```

---

## Next Steps

- Back to engagement overview → [../ENGAGEMENT-GUIDE.md](../ENGAGEMENT-GUIDE.md)
- Move to package 04? → [../../04-JSA-AUTONOMOUS/ENGAGEMENT-GUIDE.md](../../04-JSA-AUTONOMOUS/ENGAGEMENT-GUIDE.md)

---

*Ghost Protocol — Runtime Security Package (CKS)*
