"""
CrowdStrike Falcon finding ingester.

Polls Falcon APIs for detections, vulnerabilities, and misconfigurations.
Supports backfill (historical) and poll (continuous) modes.

API docs: https://falcon.crowdstrike.com/documentation/
Auth: OAuth2 client credentials flow.
"""

from __future__ import annotations

import json
import logging
import os
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Generator, Optional

import yaml

try:
    import requests
except ImportError:
    requests = None  # Handled at runtime with clear error

from .mapper import FalconMapper

logger = logging.getLogger("gp.vendor.falcon")

# Falcon API base URLs by cloud region
_CLOUD_URLS = {
    "us-1": "https://api.crowdstrike.com",
    "us-2": "https://api.us-2.crowdstrike.com",
    "eu-1": "https://api.eu-1.crowdstrike.com",
    "us-gov-1": "https://api.laggar.gcw.crowdstrike.com",
}

# Falcon API endpoints
_ENDPOINTS = {
    "oauth2": "/oauth2/token",
    "detections_query": "/detects/queries/detects/v1",
    "detections_detail": "/detects/entities/summaries/GET/v1",
    "vulnerabilities": "/spotlight/queries/vulnerabilities/v1",
    "vulnerabilities_detail": "/spotlight/entities/vulnerabilities/v2",
    "iom_query": "/detects/queries/iom/v2",
    "iom_detail": "/detects/entities/iom/v2",
}


class FalconIngester:
    """
    Ingests findings from CrowdStrike Falcon.

    Usage:
        ingester = FalconIngester()
        ingester.load_config("falcon/config.yaml")
        ingester.authenticate()

        # Backfill last 30 days
        for finding in ingester.backfill(since_days=30):
            process(finding)

        # Continuous polling
        for finding in ingester.poll():
            process(finding)
    """

    def __init__(self):
        self.config: dict = {}
        self.base_url: str = ""
        self.access_token: Optional[str] = None
        self.token_expiry: Optional[datetime] = None
        self.mapper = FalconMapper()

    def load_config(self, config_path: str | Path) -> None:
        """Load adapter configuration from YAML file."""
        config_path = Path(config_path)
        if not config_path.exists():
            raise FileNotFoundError(
                f"Config not found: {config_path}. "
                f"Copy config.example.yaml to config.yaml and fill in credentials."
            )

        with open(config_path) as f:
            self.config = yaml.safe_load(f)

        api_cfg = self.config.get("api", {})
        cloud = api_cfg.get("cloud", "us-1")
        self.base_url = api_cfg.get("base_url", _CLOUD_URLS.get(cloud, _CLOUD_URLS["us-1"]))

    def authenticate(self) -> None:
        """Obtain OAuth2 access token from Falcon API."""
        self._require_requests()

        api_cfg = self.config.get("api", {})
        client_id = os.environ.get("FALCON_CLIENT_ID", api_cfg.get("client_id", ""))
        client_secret = os.environ.get("FALCON_CLIENT_SECRET", api_cfg.get("client_secret", ""))

        if not client_id or not client_secret:
            raise ValueError(
                "Falcon credentials not found. Set FALCON_CLIENT_ID and "
                "FALCON_CLIENT_SECRET env vars, or fill in config.yaml."
            )

        resp = requests.post(
            f"{self.base_url}{_ENDPOINTS['oauth2']}",
            data={
                "client_id": client_id,
                "client_secret": client_secret,
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=30,
        )
        resp.raise_for_status()

        token_data = resp.json()
        self.access_token = token_data["access_token"]
        expires_in = token_data.get("expires_in", 1800)
        self.token_expiry = datetime.now(timezone.utc) + timedelta(seconds=expires_in - 60)

        logger.info("Falcon OAuth2 authentication successful")

    def test_connection(self) -> dict:
        """
        Test API connectivity and return capability summary.

        Returns dict with endpoint availability and sample counts.
        Used by tools/test-connection.sh.
        """
        self._ensure_auth()
        results = {}

        # Test detections endpoint
        try:
            resp = self._get(_ENDPOINTS["detections_query"], params={"limit": 1})
            results["detections"] = {
                "accessible": True,
                "total": resp.get("meta", {}).get("pagination", {}).get("total", 0),
            }
        except Exception as e:
            results["detections"] = {"accessible": False, "error": str(e)}

        # Test vulnerabilities endpoint
        try:
            resp = self._get(_ENDPOINTS["vulnerabilities"], params={"limit": 1})
            results["vulnerabilities"] = {
                "accessible": True,
                "total": resp.get("meta", {}).get("pagination", {}).get("total", 0),
            }
        except Exception as e:
            results["vulnerabilities"] = {"accessible": False, "error": str(e)}

        return results

    def backfill(self, since_days: int = 30) -> Generator:
        """
        Pull historical findings from the last N days.

        Yields GPFinding instances.
        """
        self._ensure_auth()
        since = datetime.now(timezone.utc) - timedelta(days=since_days)
        since_str = since.strftime("%Y-%m-%dT%H:%M:%SZ")

        # Ingest detections
        yield from self._ingest_detections(since_filter=since_str)

        # Ingest vulnerabilities
        yield from self._ingest_vulnerabilities(since_filter=since_str)

    def poll(self, interval: Optional[int] = None) -> Generator:
        """
        Continuously poll for new findings.

        Yields GPFinding instances as they arrive.
        Polls at the interval specified in config (default 300s).
        """
        if interval is None:
            interval = self.config.get("ingestion", {}).get("poll_interval_seconds", 300)

        last_poll = datetime.now(timezone.utc)

        while True:
            self._ensure_auth()
            since_str = last_poll.strftime("%Y-%m-%dT%H:%M:%SZ")
            last_poll = datetime.now(timezone.utc)

            yield from self._ingest_detections(since_filter=since_str)
            yield from self._ingest_vulnerabilities(since_filter=since_str)

            logger.info("Poll complete, sleeping %ds", interval)
            time.sleep(interval)

    def _ingest_detections(self, since_filter: str) -> Generator:
        """Query and yield detections as GPFindings."""
        severity_floor = self.config.get("ingestion", {}).get("severity_floor", "low")
        offset = 0
        limit = 100

        while True:
            resp = self._get(
                _ENDPOINTS["detections_query"],
                params={
                    "filter": f"created_timestamp:>'{since_filter}'",
                    "limit": limit,
                    "offset": offset,
                },
            )

            detection_ids = resp.get("resources", [])
            if not detection_ids:
                break

            # Get full detection details
            detail_resp = self._post(
                _ENDPOINTS["detections_detail"],
                json_body={"ids": detection_ids},
            )

            for detection in detail_resp.get("resources", []):
                finding = self.mapper.detection_to_finding(detection)
                if finding and self._passes_severity_floor(finding, severity_floor):
                    yield finding

            if len(detection_ids) < limit:
                break
            offset += limit

    def _ingest_vulnerabilities(self, since_filter: str) -> Generator:
        """Query and yield vulnerabilities as GPFindings."""
        severity_floor = self.config.get("ingestion", {}).get("severity_floor", "low")
        after = None

        while True:
            params = {
                "filter": f"created_timestamp:>'{since_filter}'",
                "limit": 100,
            }
            if after:
                params["after"] = after

            resp = self._get(_ENDPOINTS["vulnerabilities"], params=params)
            vuln_ids = resp.get("resources", [])
            if not vuln_ids:
                break

            detail_resp = self._get(
                _ENDPOINTS["vulnerabilities_detail"],
                params={"ids": vuln_ids},
            )

            for vuln in detail_resp.get("resources", []):
                finding = self.mapper.vulnerability_to_finding(vuln)
                if finding and self._passes_severity_floor(finding, severity_floor):
                    yield finding

            after = resp.get("meta", {}).get("pagination", {}).get("after")
            if not after:
                break

    def _passes_severity_floor(self, finding, floor: str) -> bool:
        """Check if a finding meets the configured severity floor."""
        from shared.normalizer import Severity
        order = {
            Severity.CRITICAL: 5, Severity.HIGH: 4, Severity.MEDIUM: 3,
            Severity.LOW: 2, Severity.INFORMATIONAL: 1,
        }
        floor_map = {
            "critical": 5, "high": 4, "medium": 3, "low": 2, "informational": 1,
        }
        floor_val = floor_map.get(floor.lower(), 2)
        return order.get(finding.severity, 3) >= floor_val

    # --- HTTP helpers ---

    def _ensure_auth(self) -> None:
        """Re-authenticate if token is expired or missing."""
        if not self.access_token or (
            self.token_expiry and datetime.now(timezone.utc) >= self.token_expiry
        ):
            self.authenticate()

    def _get(self, endpoint: str, params: Optional[dict] = None) -> dict:
        """Authenticated GET request to Falcon API."""
        self._require_requests()
        resp = requests.get(
            f"{self.base_url}{endpoint}",
            params=params,
            headers={"Authorization": f"Bearer {self.access_token}"},
            timeout=30,
        )
        resp.raise_for_status()
        return resp.json()

    def _post(self, endpoint: str, json_body: Optional[dict] = None) -> dict:
        """Authenticated POST request to Falcon API."""
        self._require_requests()
        resp = requests.post(
            f"{self.base_url}{endpoint}",
            json=json_body,
            headers={
                "Authorization": f"Bearer {self.access_token}",
                "Content-Type": "application/json",
            },
            timeout=30,
        )
        resp.raise_for_status()
        return resp.json()

    @staticmethod
    def _require_requests():
        if requests is None:
            raise ImportError(
                "The 'requests' library is required for Falcon integration. "
                "Install it: pip install requests"
            )
