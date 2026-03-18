# Playbook 05: Adding a New Vendor Adapter
### Step-by-Step Guide — Any Security Vendor in ~3 Hours

---

## THE PATTERN

Every vendor adapter follows the exact same structure. Three files. One registry entry.

```
vendors/<vendor-name>/
├── __init__.py           # empty
├── ingester.py           # OAuth2/API client — pulls raw findings
├── mapper.py             # Translates vendor schema → GPFinding
└── config.example.yaml   # Connection config template
```

The shared infrastructure handles everything else:
- `shared/normalizer.py` — GPFinding schema
- `shared/deduplicator.py` — Cross-source dedup
- `shared/store.py` — Write to FindingsStore + JSONL
- `shared/registry.py` — Adapter discovery
- `shared/writeback.py` — Push status back to vendor
- `tools/*` — All CLI tools work with any registered adapter

---

## STEP 1: SCAFFOLD THE ADAPTER (10 minutes)

```bash
cd /path/to/GP-CONSULTING/08-VENDOR-INTEGRATION

# Copy the scaffold template
cp -r templates/adapter-scaffold/ <vendor-name>/

# Rename template files
mv <vendor-name>/ingester_template.py <vendor-name>/ingester.py
mv <vendor-name>/mapper_template.py <vendor-name>/mapper.py
mv <vendor-name>/config_template.yaml <vendor-name>/config.example.yaml

# Create __init__.py
touch <vendor-name>/__init__.py
```

---

## STEP 2: RESEARCH THE VENDOR API (30 minutes)

Before writing code, answer these questions:

```
1. Authentication:
   [ ] OAuth2 client_credentials? (Falcon, Wiz)
   [ ] JWT via /login endpoint? (Prisma, Aqua)
   [ ] API key in header? (Snyk, Qualys)
   [ ] Bearer token? (Tenable)

2. API style:
   [ ] REST (most vendors)
   [ ] GraphQL (Wiz)

3. Pagination:
   [ ] Offset/limit? (most common)
   [ ] Cursor-based? (Wiz, Falcon)
   [ ] Token-based?

4. Rate limits:
   [ ] Requests per minute?
   [ ] Concurrent requests?
   [ ] Backoff strategy?

5. Data categories:
   [ ] What types of findings? (vulns, misconfigs, runtime, compliance)
   [ ] What fields per finding? (severity, asset, CVE, remediation)
   [ ] What's the unique ID field?

6. Writeback:
   [ ] Can you update finding status via API?
   [ ] Can you add tags/labels?
   [ ] What permissions are needed?
```

### Where to find API docs

| Vendor | API docs URL |
|--------|-------------|
| CrowdStrike Falcon | `falcon.crowdstrike.com/documentation` |
| Wiz | `docs.wiz.io/wiz-docs/docs/using-the-wiz-api` |
| Prisma Cloud | `pan.dev/prisma-cloud/api/` |
| Aqua Security | `docs.aquasec.com/reference` |
| Snyk | `docs.snyk.io/snyk-api` |
| Lacework | `docs.lacework.net/api` |
| Qualys | `qualysguard.qg2.apps.qualys.com/api` |
| Tenable | `developer.tenable.com` |

---

## STEP 3: BUILD THE INGESTER (1 hour)

The ingester handles: authentication, API calls, pagination, error handling.

### Template: ingester.py

```python
"""<Vendor Name> — Ingester"""

import json
import logging
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests
import yaml

logger = logging.getLogger(__name__)


class <Vendor>Ingester:
    """Pull findings from <Vendor> API."""

    def __init__(self, config_path="<vendor>/config.yaml"):
        self.config = self._load_config(config_path)
        self.token = None
        self.token_expiry = None
        self.base_url = self.config["api"]["base_url"]

    def _load_config(self, path):
        """Load config, resolve env vars for secrets."""
        with open(path) as f:
            config = yaml.safe_load(f)
        # ALWAYS resolve credentials from environment
        config["api"]["api_key"] = os.environ.get(
            "<VENDOR>_API_KEY", config["api"].get("api_key", "")
        )
        config["api"]["api_secret"] = os.environ.get(
            "<VENDOR>_API_SECRET", config["api"].get("api_secret", "")
        )
        return config

    def authenticate(self):
        """Authenticate to vendor API. Implement per vendor."""
        # Option A: OAuth2 client_credentials
        resp = requests.post(
            f"{self.base_url}/oauth2/token",
            data={
                "grant_type": "client_credentials",
                "client_id": self.config["api"]["api_key"],
                "client_secret": self.config["api"]["api_secret"],
            },
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()
        self.token = data["access_token"]
        self.token_expiry = datetime.now(timezone.utc) + timedelta(
            seconds=data.get("expires_in", 3600)
        )
        logger.info("<Vendor> authentication successful")

    def _api_get(self, path, params=None):
        """Authenticated GET with auto-refresh."""
        if not self.token or datetime.now(timezone.utc) >= self.token_expiry:
            self.authenticate()
        resp = requests.get(
            f"{self.base_url}{path}",
            headers={"Authorization": f"Bearer {self.token}"},
            params=params,
            timeout=60,
        )
        resp.raise_for_status()
        return resp.json()

    def backfill(self, since_days=30):
        """Pull all findings from the last N days."""
        since = datetime.now(timezone.utc) - timedelta(days=since_days)
        findings = []

        for category in self.config["ingestion"]["categories"]:
            method = getattr(self, f"_ingest_{category}", None)
            if method:
                findings.extend(method(since))
            else:
                logger.warning("Unknown category: %s", category)

        logger.info("<Vendor> backfill complete: %d findings", len(findings))
        return findings

    def _ingest_vulnerabilities(self, since):
        """Pull vulnerability findings. Implement pagination."""
        findings = []
        offset = 0
        limit = 100
        while True:
            data = self._api_get("/api/v1/vulnerabilities", params={
                "offset": offset,
                "limit": limit,
                "since": since.isoformat(),
            })
            items = data.get("items", data.get("results", []))
            if not items:
                break
            findings.extend([{"_type": "vulnerability", **item} for item in items])
            offset += limit
            if len(items) < limit:
                break
        logger.info("<Vendor> vulnerabilities: %d", len(findings))
        return findings

    # Add more _ingest_<category> methods as needed

    def poll(self):
        """Poll for new findings since last run."""
        state_path = Path(
            self.config["logging"].get("state_file", "/tmp/gp-vendor/<vendor>-state.json")
        )
        since_days = 1
        if state_path.exists():
            with open(state_path) as f:
                state = json.load(f)
                last_poll = datetime.fromisoformat(state["last_poll"])
                since_days = max(1, (datetime.now(timezone.utc) - last_poll).days + 1)

        findings = self.backfill(since_days=since_days)

        state_path.parent.mkdir(parents=True, exist_ok=True)
        with open(state_path, "w") as f:
            json.dump({"last_poll": datetime.now(timezone.utc).isoformat()}, f)

        return findings

    def test_connection(self):
        """Verify API connectivity. Return dict with status + counts."""
        try:
            self.authenticate()
            # Try to fetch 1 finding to verify
            data = self._api_get("/api/v1/vulnerabilities", params={"limit": 1})
            return {"status": "ok", "sample_count": len(data.get("items", []))}
        except Exception as e:
            return {"status": "error", "message": str(e)}
```

---

## STEP 4: BUILD THE MAPPER (45 minutes)

The mapper translates vendor-specific fields to the GPFinding schema.

### Template: mapper.py

```python
"""<Vendor Name> — Mapper to GPFinding."""

from shared.normalizer import GPFinding, FindingType, Severity


# Map vendor severity strings to GP severity
<VENDOR>_SEVERITY_MAP = {
    "critical": Severity.CRITICAL,
    "high": Severity.HIGH,
    "medium": Severity.MEDIUM,
    "low": Severity.LOW,
    "info": Severity.INFORMATIONAL,
    "informational": Severity.INFORMATIONAL,
    # Add vendor-specific values
}


class <Vendor>Mapper:
    """Map <Vendor> findings to GPFinding schema."""

    def map(self, raw_finding):
        """Route to the correct mapper based on finding type."""
        ftype = raw_finding.get("_type", "")
        method = getattr(self, f"_{ftype}_to_finding", None)
        if method:
            return method(raw_finding)
        return None

    def _vulnerability_to_finding(self, raw):
        """Vendor vulnerability → GPFinding."""
        return GPFinding(
            source="<vendor>",
            source_id=raw.get("id", ""),
            finding_type=FindingType.VULNERABILITY,
            severity=<VENDOR>_SEVERITY_MAP.get(
                raw.get("severity", "").lower(), Severity.MEDIUM
            ),
            title=self._build_title(raw),
            description=raw.get("description", ""),
            asset_type=self._detect_asset_type(raw),
            asset_id=self._extract_asset_id(raw),
            cve_id=raw.get("cve_id", raw.get("cve", "")),
            remediation=raw.get("remediation", raw.get("fix", "")),
            first_seen=raw.get("first_detected", raw.get("created_at", "")),
            last_seen=raw.get("last_detected", raw.get("updated_at", "")),
            vendor_severity=raw.get("severity", ""),
            vendor_category=raw.get("category", "vulnerability"),
            raw_payload=raw,
        )

    def _build_title(self, raw):
        """Build a human-readable title."""
        cve = raw.get("cve_id", raw.get("cve", ""))
        pkg = raw.get("package", raw.get("component", ""))
        if cve and pkg:
            return f"{cve} in {pkg}"
        return raw.get("title", raw.get("name", "Unknown finding"))

    def _detect_asset_type(self, raw):
        """Determine asset type from vendor data."""
        # Customize per vendor's data model
        if raw.get("image"):
            return "container_image"
        if raw.get("host"):
            return "node"
        if raw.get("package"):
            return "package"
        return "resource"

    def _extract_asset_id(self, raw):
        """Extract the most specific asset identifier."""
        return (
            raw.get("image", "")
            or raw.get("hostname", "")
            or raw.get("resource_id", "")
            or raw.get("asset_id", "")
        )
```

### Key mapping decisions

For each vendor, you need to decide:

| Decision | Question | How to answer |
|----------|---------|--------------|
| `source_id` | What's the vendor's unique ID for this finding? | Usually `id` field |
| `finding_type` | VULNERABILITY, MISCONFIGURATION, RUNTIME_DETECTION, etc.? | Based on data category |
| `severity` | How does vendor's severity scale map to ours? | Build `SEVERITY_MAP` |
| `asset_type` | Is this a container, host, package, IAM role, cloud resource? | Inspect vendor data model |
| `asset_id` | What uniquely identifies the affected asset? | Image name, hostname, resource ARN |
| `dedup_key` | How should this finding be deduplicated? | GPFinding computes from type + CVE + asset |

---

## STEP 5: CREATE CONFIG TEMPLATE (10 minutes)

```yaml
# <vendor>/config.example.yaml
api:
  base_url: "https://api.<vendor>.com"
  api_key: "${<VENDOR>_API_KEY}"          # NEVER hardcode
  api_secret: "${<VENDOR>_API_SECRET}"

ingestion:
  poll_interval_seconds: 300
  categories:
    - vulnerabilities
    # - misconfigurations
    # - runtime_events
  severity_floor: "medium"
  deduplicate_by_id: true

writeback:
  enabled: false
  # method: "tags"
  # tag_prefix: "gp"

logging:
  level: "INFO"
  audit_log: "/tmp/gp-vendor/<vendor>-audit.jsonl"
  state_file: "/tmp/gp-vendor/<vendor>-state.json"
```

---

## STEP 6: REGISTER THE ADAPTER (2 minutes)

Edit `shared/registry.py`:

```python
_ADAPTER_REGISTRY = {
    "falcon": ("falcon.ingester", "FalconIngester", "falcon.mapper", "FalconMapper"),
    "wiz": ("wiz.ingester", "WizIngester", "wiz.mapper", "WizMapper"),
    "<vendor>": ("<vendor>.ingester", "<Vendor>Ingester", "<vendor>.mapper", "<Vendor>Mapper"),
}
```

---

## STEP 7: TEST (30 minutes)

```bash
# Set credentials
export <VENDOR>_API_KEY="your-key"
export <VENDOR>_API_SECRET="your-secret"

# Test connectivity
bash tools/test-connection.sh --adapter <vendor>

# Backfill
bash tools/ingest.sh --adapter <vendor> --mode backfill --since 7d

# Check results
bash tools/list-findings.sh --source <vendor> --format count
bash tools/list-findings.sh --source <vendor> --severity critical --format table

# Dedup report
bash tools/dedup-report.sh --source <vendor>
```

---

## STEP 8: DEPLOY (15 minutes)

```bash
# Create K8s CronJob from template
cp templates/cronjob-template.yaml deployment-configs/<vendor>-cronjob.yaml

# Edit: adapter name, secret references, schedule
# Apply
kubectl apply -f deployment-configs/<vendor>-cronjob.yaml
```

---

## CHECKLIST: NEW ADAPTER COMPLETE

```
[ ] ingester.py: authenticate, backfill, poll, test_connection
[ ] mapper.py: map method routing, per-type mapper, severity map
[ ] config.example.yaml: all fields documented, env vars for secrets
[ ] __init__.py: exists (can be empty)
[ ] Registry entry added in shared/registry.py
[ ] test-connection.sh passes
[ ] Backfill runs successfully
[ ] Findings appear in list-findings.sh
[ ] Dedup report shows expected overlap
[ ] CronJob template created for deployment
[ ] Monitoring alerts cover the new adapter (vendor-alerts.yaml)
```

---

## TIME ESTIMATE

| Step | Time |
|------|------|
| Scaffold | 10 min |
| Research vendor API | 30 min |
| Build ingester | 1 hour |
| Build mapper | 45 min |
| Config + registry | 15 min |
| Test | 30 min |
| Deploy | 15 min |
| **Total** | **~3 hours** |

After the first adapter (Falcon took half a day), subsequent adapters take ~3 hours because the pattern is established and shared infra handles everything.
