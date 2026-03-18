# Playbook 02: Wiz Cloud Security Integration
### Cloud Misconfigurations + Vulnerabilities + Attack Paths + DSPM

---

## WHAT WIZ GIVES US

| Data source | API endpoint | What it contains | Finding type |
|-------------|-------------|-----------------|-------------|
| **Issues** | GraphQL `/graphql` | Cloud misconfigurations, compliance violations | MISCONFIGURATION |
| **Vulnerabilities** | GraphQL `/graphql` | OS + library CVEs across cloud workloads | VULNERABILITY |
| **Attack Paths** | GraphQL `/graphql` | Multi-step attack chains (lateral movement risk) | RUNTIME_DETECTION |
| **Data Findings** | GraphQL `/graphql` | Sensitive data exposure (PII, secrets, keys) | SECRET_EXPOSURE |

### Why Wiz Matters

- Wiz sees cloud infrastructure that K8s scanners can't: IAM roles, S3 permissions, cross-account access
- Attack paths show blast radius — not just "this is misconfigured" but "this leads to data exfiltration"
- Vulnerability data overlaps with Trivy (dedup opportunity)
- DSPM (Data Security Posture Management) catches exposed PII that no other scanner finds

---

## PREREQUISITES

### Create Wiz Service Account

1. Go to: **Wiz Console → Settings → Service Accounts**
2. Click **Create Service Account**
3. Set type: **Custom Integration (GraphQL API)**
4. Grant scopes:

| Scope | Why |
|-------|-----|
| `read:issues` | Pull misconfiguration findings |
| `read:vulnerabilities` | Pull CVEs |
| `read:attack_paths` | Pull attack path data |
| `read:data_findings` | Pull sensitive data exposure |
| `update:issues` | Writeback remediation status |

5. Note the **Client ID** and **Client Secret**
6. Note your **API Endpoint URL** (shown in service account details)

---

## STEP 1: BUILD THE ADAPTER

Use the scaffold template:

```bash
# Copy adapter scaffold
cp -r templates/adapter-scaffold/ wiz/

# Rename files
mv wiz/ingester_template.py wiz/ingester.py
mv wiz/mapper_template.py wiz/mapper.py
mv wiz/config_template.yaml wiz/config.example.yaml
```

### wiz/ingester.py — Key implementation points

Wiz uses **GraphQL** (not REST like Falcon):

```python
"""Wiz Cloud Security — Ingester"""

import json
import logging
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests
import yaml

logger = logging.getLogger(__name__)


class WizIngester:
    """Pull findings from Wiz GraphQL API."""

    def __init__(self, config_path="wiz/config.yaml"):
        self.config = self._load_config(config_path)
        self.token = None
        self.token_expiry = None

    def _load_config(self, path):
        with open(path) as f:
            config = yaml.safe_load(f)
        config["api"]["client_id"] = os.environ.get(
            "WIZ_CLIENT_ID", config["api"].get("client_id", "")
        )
        config["api"]["client_secret"] = os.environ.get(
            "WIZ_CLIENT_SECRET", config["api"].get("client_secret", "")
        )
        return config

    def authenticate(self):
        """OAuth2 client_credentials flow."""
        resp = requests.post(
            self.config["api"]["auth_url"],
            data={
                "grant_type": "client_credentials",
                "client_id": self.config["api"]["client_id"],
                "client_secret": self.config["api"]["client_secret"],
                "audience": "wiz-api",
            },
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()
        self.token = data["access_token"]
        self.token_expiry = datetime.now(timezone.utc) + timedelta(
            seconds=data.get("expires_in", 3600)
        )
        logger.info("Wiz authentication successful")

    def _graphql(self, query, variables=None):
        """Execute a GraphQL query against Wiz API."""
        if not self.token or datetime.now(timezone.utc) >= self.token_expiry:
            self.authenticate()

        resp = requests.post(
            self.config["api"]["endpoint"],
            json={"query": query, "variables": variables or {}},
            headers={"Authorization": f"Bearer {self.token}"},
            timeout=60,
        )
        resp.raise_for_status()
        result = resp.json()
        if "errors" in result:
            raise RuntimeError(f"Wiz GraphQL errors: {result['errors']}")
        return result["data"]

    def backfill(self, since_days=30):
        """Pull all findings from the last N days."""
        since = datetime.now(timezone.utc) - timedelta(days=since_days)
        findings = []

        for category in self.config["ingestion"]["categories"]:
            if category == "issues":
                findings.extend(self._ingest_issues(since))
            elif category == "vulnerabilities":
                findings.extend(self._ingest_vulnerabilities(since))
            elif category == "attack_paths":
                findings.extend(self._ingest_attack_paths(since))
            elif category == "data_findings":
                findings.extend(self._ingest_data_findings(since))

        logger.info("Wiz backfill complete: %d findings", len(findings))
        return findings

    def _ingest_issues(self, since):
        """Pull cloud misconfiguration issues."""
        query = """
        query IssuesQuery($after: String, $filterBy: IssueFilters) {
          issues(first: 500, after: $after, filterBy: $filterBy) {
            nodes {
              id
              sourceRule { name }
              severity
              status
              entity {
                id
                name
                type
                ... on CloudResource {
                  region
                  cloudPlatform
                  subscriptionId
                  nativeType
                }
              }
              createdAt
              updatedAt
              remediation
              note
            }
            pageInfo { hasNextPage endCursor }
          }
        }
        """
        variables = {
            "filterBy": {
                "createdAt": {"after": since.isoformat()},
                "status": ["OPEN", "IN_PROGRESS"],
            }
        }

        findings = []
        cursor = None
        while True:
            if cursor:
                variables["after"] = cursor
            data = self._graphql(query, variables)
            issues = data["issues"]
            findings.extend(issues["nodes"])
            if not issues["pageInfo"]["hasNextPage"]:
                break
            cursor = issues["pageInfo"]["endCursor"]

        logger.info("Wiz issues: %d", len(findings))
        return [{"_type": "issue", **f} for f in findings]

    def _ingest_vulnerabilities(self, since):
        """Pull vulnerability findings."""
        query = """
        query VulnQuery($after: String, $filterBy: VulnerabilityFilters) {
          vulnerabilityFindings(first: 500, after: $after, filterBy: $filterBy) {
            nodes {
              id
              name
              CVEDescription
              severity
              score
              exploitabilityScore
              hasCisaKevExploit
              hasExploit
              status
              firstDetectedAt
              lastDetectedAt
              vulnerableAsset {
                id
                name
                type
                ... on VulnerableImage { imageTag registryName }
                ... on VulnerableHost { hostname osName }
              }
              version
              fixedVersion
              remediation
            }
            pageInfo { hasNextPage endCursor }
          }
        }
        """
        variables = {
            "filterBy": {
                "firstDetectedAt": {"after": since.isoformat()},
            }
        }

        findings = []
        cursor = None
        while True:
            if cursor:
                variables["after"] = cursor
            data = self._graphql(query, variables)
            vulns = data["vulnerabilityFindings"]
            findings.extend(vulns["nodes"])
            if not vulns["pageInfo"]["hasNextPage"]:
                break
            cursor = vulns["pageInfo"]["endCursor"]

        logger.info("Wiz vulnerabilities: %d", len(findings))
        return [{"_type": "vulnerability", **f} for f in findings]

    def _ingest_attack_paths(self, since):
        """Pull attack path findings (high-value — shows blast radius)."""
        # Attack paths are queried via the issues API with type filter
        # Implementation similar to _ingest_issues with sourceRule type filter
        logger.info("Wiz attack paths: stub — implement with issue type filter")
        return []

    def _ingest_data_findings(self, since):
        """Pull data security findings (PII exposure, etc.)."""
        logger.info("Wiz data findings: stub — implement with DSPM API")
        return []

    def poll(self):
        """Poll for new findings since last run."""
        # Read last poll timestamp from state file
        state_path = Path(self.config["logging"].get("state_file", "/tmp/gp-vendor/wiz-state.json"))
        since_days = 1  # default: last 24 hours
        if state_path.exists():
            with open(state_path) as f:
                state = json.load(f)
                last_poll = datetime.fromisoformat(state["last_poll"])
                since_days = max(1, (datetime.now(timezone.utc) - last_poll).days + 1)

        findings = self.backfill(since_days=since_days)

        # Save state
        state_path.parent.mkdir(parents=True, exist_ok=True)
        with open(state_path, "w") as f:
            json.dump({"last_poll": datetime.now(timezone.utc).isoformat()}, f)

        return findings

    def test_connection(self):
        """Verify API connectivity."""
        try:
            self.authenticate()
            data = self._graphql("query { issues(first: 1) { totalCount } }")
            return {
                "status": "ok",
                "issues_count": data["issues"]["totalCount"],
            }
        except Exception as e:
            return {"status": "error", "message": str(e)}
```

### wiz/mapper.py — Key implementation points

```python
"""Wiz Cloud Security — Mapper to GPFinding."""

from shared.normalizer import GPFinding, FindingType, Severity, map_severity


WIZ_SEVERITY_MAP = {
    "CRITICAL": Severity.CRITICAL,
    "HIGH": Severity.HIGH,
    "MEDIUM": Severity.MEDIUM,
    "LOW": Severity.LOW,
    "INFORMATIONAL": Severity.INFORMATIONAL,
    "NONE": Severity.INFORMATIONAL,
}


class WizMapper:
    """Map Wiz findings to GPFinding schema."""

    def map(self, raw_finding):
        """Route to the correct mapper based on finding type."""
        ftype = raw_finding.get("_type", "")
        if ftype == "issue":
            return self.issue_to_finding(raw_finding)
        elif ftype == "vulnerability":
            return self.vulnerability_to_finding(raw_finding)
        return None

    def issue_to_finding(self, raw):
        """Wiz Issue (misconfiguration) → GPFinding."""
        entity = raw.get("entity", {})
        return GPFinding(
            source="wiz",
            source_id=raw["id"],
            finding_type=FindingType.MISCONFIGURATION,
            severity=WIZ_SEVERITY_MAP.get(raw.get("severity", ""), Severity.MEDIUM),
            title=raw.get("sourceRule", {}).get("name", "Unknown Wiz Issue"),
            description=raw.get("note", ""),
            asset_type=entity.get("type", "cloud_resource"),
            asset_id=entity.get("name", entity.get("id", "")),
            namespace=entity.get("subscriptionId", ""),
            cluster=entity.get("region", ""),
            remediation=raw.get("remediation", ""),
            first_seen=raw.get("createdAt", ""),
            last_seen=raw.get("updatedAt", ""),
            vendor_severity=raw.get("severity", ""),
            vendor_category="issue",
            raw_payload=raw,
        )

    def vulnerability_to_finding(self, raw):
        """Wiz Vulnerability → GPFinding."""
        asset = raw.get("vulnerableAsset", {})
        cve_id = raw.get("name", "")
        return GPFinding(
            source="wiz",
            source_id=raw["id"],
            finding_type=FindingType.VULNERABILITY,
            severity=WIZ_SEVERITY_MAP.get(raw.get("severity", ""), Severity.MEDIUM),
            title=f"{cve_id}: {raw.get('CVEDescription', '')[:100]}",
            description=raw.get("CVEDescription", ""),
            asset_type=asset.get("type", "package"),
            asset_id=asset.get("name", asset.get("id", "")),
            cve_id=cve_id,
            remediation=raw.get("remediation", f"Update to {raw.get('fixedVersion', 'latest')}"),
            first_seen=raw.get("firstDetectedAt", ""),
            last_seen=raw.get("lastDetectedAt", ""),
            vendor_severity=raw.get("severity", ""),
            vendor_category="vulnerability",
            raw_payload=raw,
        )
```

### Register the adapter

Add to `shared/registry.py`:
```python
_ADAPTER_REGISTRY = {
    "falcon": ("falcon.ingester", "FalconIngester", "falcon.mapper", "FalconMapper"),
    "wiz": ("wiz.ingester", "WizIngester", "wiz.mapper", "WizMapper"),
}
```

---

## STEP 2: CONFIGURE AND TEST

```bash
export WIZ_CLIENT_ID="your-client-id"
export WIZ_CLIENT_SECRET="your-client-secret"

# Test connectivity
bash tools/test-connection.sh --adapter wiz

# Initial backfill
bash tools/ingest.sh --adapter wiz --mode backfill --since 30d

# Check results
bash tools/list-findings.sh --source wiz --format count
```

---

## WIZ-SPECIFIC DEDUP VALUE

| Wiz finding | Overlaps with | Dedup key |
|-------------|--------------|-----------|
| CVE on container image | Trivy image scan | CVE ID + image name |
| S3 bucket public access | Checkov IaC scan | resource ID + rule |
| IAM overprivileged role | Custom OPA policies | IAM role ARN + policy |
| Unencrypted EBS volume | Checkov + AWS Config | volume ID + encryption rule |

Wiz attack paths have **no overlap** — they're net new value. They show multi-step attack chains that no single scanner sees.

---

## COMPLETION CHECKLIST

```
[ ] Wiz service account created with correct scopes
[ ] Credentials stored securely
[ ] Adapter files created (ingester.py, mapper.py, config.yaml)
[ ] Registry entry added
[ ] Connectivity test passes
[ ] Initial backfill completed
[ ] Cross-source dedup report reviewed
[ ] Continuous polling enabled
[ ] Writeback configured (if applicable)
```
