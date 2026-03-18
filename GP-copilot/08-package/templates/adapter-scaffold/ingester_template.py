"""<VENDOR_NAME> — Ingester

Pull findings from <VENDOR_NAME> API into GPFinding pipeline.

Usage:
    1. Copy this directory to vendors/<vendor>/
    2. Rename this file to ingester.py
    3. Replace all <VENDOR>, <VENDOR_NAME>, <vendor> placeholders
    4. Implement authenticate() for your vendor's auth method
    5. Implement _ingest_<category>() for each data category
    6. Register in shared/registry.py
"""

import json
import logging
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests
import yaml

logger = logging.getLogger(__name__)


class VendorIngester:
    """Pull findings from <VENDOR_NAME> API.

    Replace 'VendorIngester' with '<Vendor>Ingester' (e.g., WizIngester).
    """

    def __init__(self, config_path="<vendor>/config.yaml"):
        self.config = self._load_config(config_path)
        self.token = None
        self.token_expiry = None
        self.base_url = self.config["api"]["base_url"]

    # ── Config ────────────────────────────────────────────────────────

    def _load_config(self, path):
        """Load config, resolve env vars for secrets."""
        with open(path) as f:
            config = yaml.safe_load(f)
        # ALWAYS resolve credentials from environment — never hardcode
        config["api"]["api_key"] = os.environ.get(
            "<VENDOR>_API_KEY", config["api"].get("api_key", "")
        )
        config["api"]["api_secret"] = os.environ.get(
            "<VENDOR>_API_SECRET", config["api"].get("api_secret", "")
        )
        return config

    # ── Authentication ────────────────────────────────────────────────
    # Pick ONE of these patterns and delete the others.

    def authenticate(self):
        """Authenticate to vendor API.

        Common patterns (pick one):

        A) OAuth2 client_credentials (Falcon, Wiz):
            POST /oauth2/token with client_id + client_secret
            Returns: access_token + expires_in

        B) JWT via login endpoint (Prisma, Aqua):
            POST /api/v1/login with username + password
            Returns: token (JWT)

        C) API key in header (Snyk, Qualys):
            No auth call needed — pass key in every request header
            self.token = self.config["api"]["api_key"]

        D) Bearer token (Tenable):
            Static token — no auth call needed
            self.token = self.config["api"]["api_key"]
        """
        # === OPTION A: OAuth2 (most common) ===
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
        logger.info("<VENDOR_NAME> authentication successful")

    # ── HTTP helpers ──────────────────────────────────────────────────

    def _ensure_auth(self):
        """Refresh token if expired."""
        if not self.token or (
            self.token_expiry and datetime.now(timezone.utc) >= self.token_expiry
        ):
            self.authenticate()

    def _api_get(self, path, params=None):
        """Authenticated GET with auto-refresh."""
        self._ensure_auth()
        resp = requests.get(
            f"{self.base_url}{path}",
            headers={"Authorization": f"Bearer {self.token}"},
            params=params,
            timeout=60,
        )
        resp.raise_for_status()
        return resp.json()

    def _api_post(self, path, json_data=None):
        """Authenticated POST with auto-refresh."""
        self._ensure_auth()
        resp = requests.post(
            f"{self.base_url}{path}",
            headers={"Authorization": f"Bearer {self.token}"},
            json=json_data,
            timeout=60,
        )
        resp.raise_for_status()
        return resp.json()

    def _api_patch(self, path, json_data=None):
        """Authenticated PATCH with auto-refresh."""
        self._ensure_auth()
        resp = requests.patch(
            f"{self.base_url}{path}",
            headers={"Authorization": f"Bearer {self.token}"},
            json=json_data,
            timeout=60,
        )
        resp.raise_for_status()
        return resp.json()

    # ── Ingestion ─────────────────────────────────────────────────────

    def backfill(self, since_days=30):
        """Pull all findings from the last N days."""
        since = datetime.now(timezone.utc) - timedelta(days=since_days)
        findings = []

        for category in self.config["ingestion"]["categories"]:
            method = getattr(self, f"_ingest_{category}", None)
            if method:
                findings.extend(method(since))
            else:
                logger.warning("Unknown ingestion category: %s", category)

        logger.info("<VENDOR_NAME> backfill complete: %d findings", len(findings))
        return findings

    def _ingest_vulnerabilities(self, since):
        """Pull vulnerability findings with pagination.

        Pagination patterns (pick one):

        A) Offset/limit (most common):
            params: offset=0, limit=100
            Stop when: len(items) < limit

        B) Cursor-based (Falcon, Wiz):
            params: after=<cursor>
            Stop when: no next cursor in response

        C) Token-based:
            params: next_token=<token>
            Stop when: no next_token in response
        """
        findings = []
        offset = 0
        limit = self.config["ingestion"].get("page_size", 100)

        while True:
            data = self._api_get(
                "/api/v1/vulnerabilities",
                params={
                    "offset": offset,
                    "limit": limit,
                    "since": since.isoformat(),
                },
            )
            items = data.get("items", data.get("results", data.get("resources", [])))
            if not items:
                break
            findings.extend([{"_type": "vulnerability", **item} for item in items])
            offset += limit
            if len(items) < limit:
                break

        logger.info("<VENDOR_NAME> vulnerabilities: %d", len(findings))
        return findings

    # Add more _ingest_<category> methods for each data type:
    # def _ingest_misconfigurations(self, since): ...
    # def _ingest_runtime_events(self, since): ...
    # def _ingest_compliance(self, since): ...

    # ── Polling ───────────────────────────────────────────────────────

    def poll(self):
        """Poll for new findings since last run.

        State is persisted to a JSON file so the ingester knows
        where it left off between runs.
        """
        state_path = Path(
            self.config["logging"].get(
                "state_file", "/tmp/gp-vendor/<vendor>-state.json"
            )
        )
        since_days = 1

        if state_path.exists():
            with open(state_path) as f:
                state = json.load(f)
                last_poll = datetime.fromisoformat(state["last_poll"])
                since_days = max(
                    1, (datetime.now(timezone.utc) - last_poll).days + 1
                )

        findings = self.backfill(since_days=since_days)

        # Save state
        state_path.parent.mkdir(parents=True, exist_ok=True)
        with open(state_path, "w") as f:
            json.dump({"last_poll": datetime.now(timezone.utc).isoformat()}, f)

        return findings

    # ── Connectivity test ─────────────────────────────────────────────

    def test_connection(self):
        """Verify API connectivity and credentials.

        Returns dict with status and diagnostic info.
        Used by: tools/test-connection.sh --adapter <vendor>
        """
        try:
            self.authenticate()
            # Try to fetch 1 finding to verify data access
            data = self._api_get(
                "/api/v1/vulnerabilities", params={"limit": 1}
            )
            count = len(data.get("items", data.get("results", [])))
            return {
                "status": "ok",
                "authenticated": True,
                "sample_count": count,
                "base_url": self.base_url,
            }
        except requests.exceptions.HTTPError as e:
            return {
                "status": "error",
                "authenticated": False,
                "http_status": e.response.status_code if e.response else None,
                "message": str(e),
            }
        except Exception as e:
            return {
                "status": "error",
                "authenticated": False,
                "message": str(e),
            }
