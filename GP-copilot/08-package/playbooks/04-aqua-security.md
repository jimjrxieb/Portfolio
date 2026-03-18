# Playbook 04: Aqua Security Integration
### Container Runtime + Image Scanning + KSPM

---

## WHAT AQUA GIVES US

| Data source | API endpoint | What it contains | Finding type |
|-------------|-------------|-----------------|-------------|
| **Image Vulnerabilities** | `/api/v2/images` | CVEs in container images | VULNERABILITY |
| **Runtime Policies** | `/api/v2/runtime_policies` | Runtime violations (drift, exec, network) | RUNTIME_DETECTION |
| **Assurance Policies** | `/api/v2/assurance_policies` | Image compliance (no root, signed, etc.) | COMPLIANCE_VIOLATION |
| **KSPM** | `/api/v2/risks/kubernetes` | K8s misconfiguration findings | MISCONFIGURATION |

### Why Aqua Matters

- Deep container-native security (image → build → runtime → K8s)
- Runtime detection overlaps with Falco — dedup opportunity
- Image scanning overlaps with Trivy (Aqua owns Trivy!) — high dedup
- KSPM overlaps with Kubescape/kube-bench — more dedup value
- Clients running Aqua Enterprise get significant dedup savings

---

## PREREQUISITES

### Create Aqua API Credentials

1. Go to: **Aqua Console → System → API Keys**
2. Create a key with **Scanner** or **Auditor** role
3. Note: **API URL**, **Username/Token**, **Password/Key**

API base URL depends on deployment:
- Aqua SaaS: `https://<tenant>.cloud.aquasec.com`
- Aqua Self-hosted: `https://<your-aqua-server>:8443`

---

## ADAPTER STRUCTURE

```python
# aqua/ingester.py — Key patterns

class AquaIngester:
    """Pull findings from Aqua Security REST API."""

    def authenticate(self):
        """Aqua uses /api/v1/login returning a JWT."""
        resp = requests.post(
            f"{self.base_url}/api/v1/login",
            json={
                "id": self.username,
                "password": self.password,
            },
            timeout=30,
        )
        resp.raise_for_status()
        self.token = resp.json()["token"]

    def _ingest_image_vulns(self, since):
        """Pull image vulnerability findings."""
        images = self._api_get("/api/v2/images", params={
            "page": 1,
            "pagesize": 100,
            "order_by": "-vulnerability_count",
        })
        findings = []
        for image in images:
            for vuln in image.get("vulnerabilities", []):
                findings.append({
                    "_type": "image_vuln",
                    "image": image["name"],
                    "image_tag": image.get("tag", ""),
                    "registry": image.get("registry", ""),
                    **vuln,
                })
        return findings

    def _ingest_runtime_events(self, since):
        """Pull runtime policy violations."""
        events = self._api_get("/api/v2/events", params={
            "from": int(since.timestamp()),
            "to": int(datetime.now(timezone.utc).timestamp()),
            "type": "runtime",
            "pagesize": 500,
        })
        return [{"_type": "runtime", **e} for e in events]

    def _ingest_kspm(self, since):
        """Pull Kubernetes security posture findings."""
        risks = self._api_get("/api/v2/risks/kubernetes", params={
            "pagesize": 500,
        })
        return [{"_type": "kspm", **r} for r in risks]
```

### Severity mapping

```python
AQUA_SEVERITY_MAP = {
    "critical": Severity.CRITICAL,
    "high": Severity.HIGH,
    "medium": Severity.MEDIUM,
    "low": Severity.LOW,
    "negligible": Severity.INFORMATIONAL,
}
```

---

## AQUA-SPECIFIC DEDUP VALUE

| Aqua finding | Overlaps with | Expected dedup rate |
|-------------|--------------|-------------------|
| Image CVE | Trivy image scan | 90%+ (Aqua owns Trivy — same DB) |
| Runtime exec violation | Falco shell spawn rule | 60-70% (different detection engine) |
| KSPM finding | Kubescape, kube-bench | 70-80% (similar CIS checks) |
| Assurance policy violation | Kyverno admission | 50-60% (different enforcement point) |

**Aqua + Trivy dedup will be the highest overlap** in the entire platform because they share the same vulnerability database. This is a feature, not a bug — the dedup engine proves there are no gaps between the two.

---

## COMPLETION CHECKLIST

```
[ ] Aqua API credentials created
[ ] API URL confirmed (SaaS vs self-hosted)
[ ] Adapter files created (ingester.py, mapper.py, config.yaml)
[ ] Registry entry added
[ ] Connectivity test passes
[ ] Initial backfill completed
[ ] Cross-source dedup report reviewed (expect high Trivy overlap)
[ ] Continuous polling enabled
```
