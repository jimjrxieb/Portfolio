# Playbook 07: Writeback & Vendor Sync
### Pushing Remediation Status Back to Vendor Consoles

---

## WHY WRITEBACK

Without writeback:
- GP-Copilot remediates a finding → our system shows "fixed"
- Vendor console still shows "open" → SOC team re-triages the same issue
- Double work. Confusion. Alert fatigue.

With writeback:
- GP-Copilot remediates a finding → tags it in the vendor console
- SOC team sees "gp:remediated" in Falcon/Wiz/Prisma → no re-triage needed
- One source of truth for finding status

---

## WRITEBACK STATUSES

| GP Status | Vendor Tag | What it means |
|-----------|-----------|---------------|
| `REMEDIATED` | `gp:remediated` | Finding is fixed. Verified by re-scan. |
| `IN_PROGRESS` | `gp:in-progress` | Fix is underway. Tracked in POA&M. |
| `ACCEPTED_RISK` | `gp:accepted-risk` | Risk accepted with documented justification. |
| `FALSE_POSITIVE` | `gp:false-positive` | Confirmed false positive. Suppressed. |
| `DEFERRED` | `gp:deferred` | Scheduled for future remediation. |

---

## HOW WRITEBACK WORKS

### Architecture

```
FindingsStore (finding has rank + status)
  → writeback.sh triggers WritebackClient
    → Client reads findings with remediation status
    → Client calls vendor API to update:
       - Falcon: add tags to detections
       - Wiz: update issue status
       - Prisma: update alert status
       - Aqua: update vulnerability status
    → Log result to JSONL audit trail
    → Return success/failure report
```

### The WritebackClient interface (shared/writeback.py)

Every vendor adapter implements this:

```python
class WritebackClient(ABC):
    @abstractmethod
    def write_status(self, source_id, status, note=""):
        """Update a single finding's status in the vendor platform."""
        pass

    @abstractmethod
    def write_batch(self, updates):
        """Batch update multiple findings."""
        pass

    @abstractmethod
    def test_write_access(self):
        """Verify the API credentials have write permissions."""
        pass

    @abstractmethod
    def dry_run(self, updates):
        """Preview what would be written without making API calls."""
        pass
```

---

## FALCON WRITEBACK IMPLEMENTATION

Falcon supports tagging detections:

```python
# falcon/writeback_client.py

class FalconWritebackClient(WritebackClient):
    """Push remediation tags to CrowdStrike Falcon."""

    def write_status(self, source_id, status, note=""):
        """Tag a detection in Falcon."""
        tag = self.config["writeback"]["status_tags"].get(status.value)
        if not tag:
            return WritebackResult(source_id, False, status, "No tag mapping")

        resp = self._api_patch(
            "/detects/entities/detects/v2",
            json={
                "ids": [source_id],
                "assigned_to_uuid": "",
                "comment": f"GP-Copilot: {status.value} — {note}",
                "show_in_ui": True,
                "status": self._map_status(status),
            },
        )
        return WritebackResult(
            source_id=source_id,
            success=resp.status_code == 200,
            status=status,
            message=f"Tagged: {tag}",
            vendor_response=resp.json(),
        )

    def _map_status(self, status):
        """Map GP status to Falcon detection status."""
        return {
            RemediationStatus.REMEDIATED: "closed",
            RemediationStatus.FALSE_POSITIVE: "false_positive",
            RemediationStatus.IN_PROGRESS: "in_progress",
            RemediationStatus.ACCEPTED_RISK: "ignored",
            RemediationStatus.DEFERRED: "new",  # keep open but tagged
        }.get(status, "new")
```

---

## RUNNING WRITEBACK

### Dry run first (always)

```bash
# See what would be written without making API calls
bash tools/writeback.sh --adapter falcon --dry-run

# Output:
# === Writeback Dry Run: falcon ===
# Would update 847 findings:
#   REMEDIATED:     612
#   IN_PROGRESS:    180
#   ACCEPTED_RISK:  42
#   FALSE_POSITIVE: 13
#
# No API calls made.
```

### Execute writeback

```bash
# Write all statuses
bash tools/writeback.sh --adapter falcon

# Write only verified remediations (re-scan confirmed fix)
bash tools/writeback.sh --adapter falcon --verified-only

# Output:
# === Writeback: falcon ===
# Updated: 612 REMEDIATED
# Updated: 180 IN_PROGRESS
# Updated: 42 ACCEPTED_RISK
# Updated: 13 FALSE_POSITIVE
# Failed: 0
# Audit log: /tmp/gp-vendor/falcon-writeback-audit.jsonl
```

### Scheduled writeback (K8s CronJob)

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: vendor-writeback-falcon
  namespace: vendor-integration
spec:
  schedule: "0 */6 * * *"    # Every 6 hours
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: writeback
              image: ghcr.io/org/vendor-integration:latest
              command: ["bash", "tools/writeback.sh", "--adapter", "falcon"]
              envFrom:
                - secretRef:
                    name: vendor-credentials
          restartPolicy: OnFailure
```

---

## WRITEBACK FOR OTHER VENDORS

### Wiz

```python
# Wiz uses GraphQL mutations to update issue status
mutation = """
mutation UpdateIssueStatus($issueId: ID!, $status: IssueStatus!, $note: String) {
  updateIssueStatus(input: {id: $issueId, status: $status, note: $note}) {
    issue { id status }
  }
}
"""
# Status values: OPEN, IN_PROGRESS, RESOLVED, REJECTED
```

### Prisma Cloud

```python
# Prisma uses REST PATCH to update alert status
resp = requests.patch(
    f"{base_url}/alert/dismiss",
    headers={"x-redlock-auth": token},
    json={
        "alerts": [alert_id],
        "dismissalNote": "GP-Copilot: remediated",
        "dismissalTimeRange": {"type": "absolute", "value": {"endTime": 0}},
    },
)
```

### Aqua

```python
# Aqua uses REST to acknowledge vulnerabilities
resp = requests.post(
    f"{base_url}/api/v2/vulnerabilities/acknowledge",
    headers={"Authorization": f"Bearer {token}"},
    json={
        "vulnerabilities": [vuln_id],
        "comment": "GP-Copilot: remediated",
    },
)
```

---

## AUDIT TRAIL

Every writeback is logged to JSONL:

```json
{
  "timestamp": "2026-03-11T14:30:00Z",
  "adapter": "falcon",
  "source_id": "ldt:abc123:def456",
  "status": "REMEDIATED",
  "success": true,
  "note": "CVE-2025-1234 patched in image update",
  "vendor_response": {"status_code": 200}
}
```

This is your compliance evidence that remediation was communicated to the vendor platform.

---

## CONFLICT RESOLUTION

What happens when the vendor and GP-Copilot disagree?

| Scenario | Resolution |
|----------|-----------|
| GP says remediated, vendor re-opens | Re-scan. If still fixed → re-writeback. If regression → re-open in GP too. |
| GP says false positive, vendor escalates | Human review. If confirmed FP → document justification. If real → remove FP tag. |
| Vendor closes finding, GP still shows open | Ingest picks up vendor status change → update FindingsStore. |
| New vendor finding on a remediated asset | New finding. Dedup won't merge (different dedup_key). Triage as new. |

---

## COMPLETION CHECKLIST

```
[ ] WritebackClient implemented for each active vendor
[ ] Dry-run tested (verify correct mapping before actual writes)
[ ] Writeback executed successfully
[ ] Vendor console shows GP tags on updated findings
[ ] Audit trail logging confirmed (JSONL)
[ ] Scheduled writeback CronJob deployed (if applicable)
[ ] Conflict resolution process documented
[ ] SOC team briefed on GP tags and what they mean
```
