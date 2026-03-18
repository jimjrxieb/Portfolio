# Playbook 03: Prisma Cloud Integration
### CSPM + CWPP + Code Security + IAM Security

---

## WHAT PRISMA GIVES US

| Data source | API endpoint | What it contains | Finding type |
|-------------|-------------|-----------------|-------------|
| **Alerts** | `/alert` | CSPM misconfigurations, policy violations | MISCONFIGURATION |
| **Vulnerabilities** | `/v2/vulnerability` | Image + host + function CVEs | VULNERABILITY |
| **Compliance** | `/compliance` | CIS/NIST/PCI compliance posture | COMPLIANCE_VIOLATION |
| **IAM** | `/api/v1/permission` | Overprivileged identities, unused permissions | IAM_RISK |
| **Code Security** | `/code/api/v1/issues` | IaC misconfigs, secrets in code, license violations | MISCONFIGURATION |

### Why Prisma Matters

- Palo Alto customers already pay for it — they want to extract value
- CSPM + CWPP in one platform means both cloud and container findings
- IAM security catches overprivileged roles that no other scanner checks
- Code Security overlaps with Checkov (Prisma owns Bridgecrew/Checkov) — nearly 1:1 dedup

---

## PREREQUISITES

### Create Prisma Cloud Access Key

1. Go to: **Prisma Cloud → Settings → Access Control → Access Keys**
2. Click **Add → Access Key**
3. Set role: **Account Group Read Only** (or custom with API access)
4. Note the **Access Key ID** and **Secret Key**
5. Note your **API URL**:

| Stack | API URL |
|-------|---------|
| app | `api.prismacloud.io` |
| app2 | `api2.prismacloud.io` |
| app3 | `api3.prismacloud.io` |
| app.eu | `api.eu.prismacloud.io` |
| app.anz | `api.anz.prismacloud.io` |
| app.gov | `api.gov.prismacloud.io` |
| app.ca | `api.ca.prismacloud.io` |

---

## ADAPTER STRUCTURE

```python
# prisma/ingester.py — Key patterns

class PrismaIngester:
    """Pull findings from Prisma Cloud REST API."""

    def authenticate(self):
        """Prisma uses /login endpoint returning a JWT."""
        resp = requests.post(
            f"{self.base_url}/login",
            json={
                "username": self.access_key,
                "password": self.secret_key,
            },
            timeout=30,
        )
        resp.raise_for_status()
        self.token = resp.json()["token"]

    def _api_get(self, path, params=None):
        """Authenticated GET request."""
        headers = {"x-redlock-auth": self.token}
        resp = requests.get(
            f"{self.base_url}{path}",
            headers=headers,
            params=params,
            timeout=60,
        )
        if resp.status_code == 401:
            self.authenticate()
            resp = requests.get(
                f"{self.base_url}{path}",
                headers={"x-redlock-auth": self.token},
                params=params,
                timeout=60,
            )
        resp.raise_for_status()
        return resp.json()

    def _ingest_alerts(self, since):
        """Pull CSPM alerts."""
        alerts = self._api_get("/alert", params={
            "timeType": "absolute",
            "startTime": int(since.timestamp() * 1000),
            "endTime": int(datetime.now(timezone.utc).timestamp() * 1000),
            "detailed": "true",
        })
        return [{"_type": "alert", **a} for a in alerts]

    def _ingest_vulnerabilities(self, since):
        """Pull CWPP vulnerability data."""
        vulns = self._api_get("/v2/vulnerability", params={
            "offset": 0,
            "limit": 50,
            "sort": "severity",
        })
        return [{"_type": "vulnerability", **v} for v in vulns]
```

### Severity mapping

```python
PRISMA_SEVERITY_MAP = {
    "critical": Severity.CRITICAL,
    "high": Severity.HIGH,
    "medium": Severity.MEDIUM,
    "low": Severity.LOW,
    "informational": Severity.INFORMATIONAL,
}
```

---

## PRISMA-SPECIFIC DEDUP VALUE

| Prisma finding | Overlaps with | Dedup key |
|---------------|--------------|-----------|
| CSPM alert (S3 public) | Checkov, Wiz | resource ID + policy |
| CWPP CVE (container) | Trivy, Falcon Spotlight | CVE ID + image |
| Code Security (IaC) | Checkov (same engine!) | file path + rule ID |
| IAM overprivileged | Wiz IAM | IAM ARN + permission set |
| Compliance violation | Kubescape, kube-bench | control ID + resource |

**Code Security findings will have near-100% overlap with Checkov** because Prisma Cloud acquired Bridgecrew (Checkov's parent). The dedup engine handles this — you get merged findings with evidence from both sources.

---

## COMPLETION CHECKLIST

```
[ ] Prisma Cloud access key created
[ ] API URL confirmed (check your stack)
[ ] Adapter files created (ingester.py, mapper.py, config.yaml)
[ ] Registry entry added
[ ] Connectivity test passes
[ ] Initial backfill completed
[ ] Cross-source dedup report reviewed
[ ] High overlap with Checkov confirmed (expected)
[ ] Continuous polling enabled
```
