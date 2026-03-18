"""
CrowdStrike Falcon → GPFinding mapper.

Translates Falcon's detection and vulnerability schemas into GP-Copilot's
universal GPFinding format. This is where vendor-specific logic lives.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Optional

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from shared.normalizer import GPFinding, FindingType, Severity, map_severity

logger = logging.getLogger("gp.vendor.falcon.mapper")


# Falcon detection behavior → GP finding type mapping
_BEHAVIOR_TO_TYPE = {
    "malware": FindingType.RUNTIME_DETECTION,
    "exploit": FindingType.RUNTIME_DETECTION,
    "command_and_control": FindingType.RUNTIME_DETECTION,
    "lateral_movement": FindingType.RUNTIME_DETECTION,
    "credential_theft": FindingType.SECRET_EXPOSURE,
    "persistence": FindingType.RUNTIME_DETECTION,
    "privilege_escalation": FindingType.RUNTIME_DETECTION,
    "defense_evasion": FindingType.RUNTIME_DETECTION,
    "collection": FindingType.RUNTIME_DETECTION,
    "exfiltration": FindingType.RUNTIME_DETECTION,
    "reconnaissance": FindingType.RUNTIME_DETECTION,
    "execution": FindingType.RUNTIME_DETECTION,
}

# Falcon MITRE tactic mapping
_FALCON_TACTIC_MAP = {
    "CredentialAccess": "Credential Access",
    "LateralMovement": "Lateral Movement",
    "PrivilegeEscalation": "Privilege Escalation",
    "DefenseEvasion": "Defense Evasion",
    "CommandAndControl": "Command and Control",
    "InitialAccess": "Initial Access",
    "Execution": "Execution",
    "Persistence": "Persistence",
    "Collection": "Collection",
    "Exfiltration": "Exfiltration",
    "Discovery": "Discovery",
    "Impact": "Impact",
}


class FalconMapper:
    """Maps CrowdStrike Falcon API responses to GPFinding instances."""

    def detection_to_finding(self, detection: dict) -> Optional[GPFinding]:
        """
        Map a Falcon detection (from /detects/entities/summaries) to GPFinding.

        Falcon detection schema (relevant fields):
        {
            "detection_id": "ldt:abc123",
            "max_severity_displayname": "High",
            "max_severity": 4,
            "first_behavior": "2024-01-15T10:30:00Z",
            "last_behavior": "2024-01-15T10:35:00Z",
            "device": {"hostname": "worker-node-1", ...},
            "behaviors": [
                {
                    "tactic": "PrivilegeEscalation",
                    "technique": "T1068",
                    "display_name": "Suspicious process...",
                    "description": "...",
                    "severity": 4,
                    "scenario": "exploit",
                    "cmdline": "...",
                    "filename": "...",
                }
            ]
        }
        """
        try:
            detection_id = detection.get("detection_id", "")
            behaviors = detection.get("behaviors", [])
            device = detection.get("device", {})

            if not behaviors:
                logger.debug("Skipping detection %s: no behaviors", detection_id)
                return None

            primary = behaviors[0]
            tactic = primary.get("tactic", "")
            technique = primary.get("technique", "")
            scenario = primary.get("scenario", "").lower()

            severity_val = str(detection.get("max_severity", "3"))
            severity = map_severity(severity_val, vendor="falcon")

            finding_type = _BEHAVIOR_TO_TYPE.get(scenario, FindingType.RUNTIME_DETECTION)

            hostname = device.get("hostname", "unknown")
            asset_id = f"node/{hostname}"

            return GPFinding(
                source="falcon",
                source_id=detection_id,
                finding_type=finding_type,
                severity=severity,
                title=primary.get("display_name", f"Falcon detection: {scenario}"),
                description=primary.get("description", ""),
                asset_type="node",
                asset_id=asset_id,
                cluster=device.get("cluster_name"),
                mitre_tactic=_FALCON_TACTIC_MAP.get(tactic, tactic),
                mitre_technique=technique if technique else None,
                first_seen=_parse_ts(detection.get("first_behavior")),
                last_seen=_parse_ts(detection.get("last_behavior")),
                vendor_severity=detection.get("max_severity_displayname"),
                vendor_category=scenario,
                raw_payload=detection,
            )
        except Exception as e:
            logger.error("Failed to map detection %s: %s", detection.get("detection_id"), e)
            return None

    def vulnerability_to_finding(self, vuln: dict) -> Optional[GPFinding]:
        """
        Map a Falcon Spotlight vulnerability to GPFinding.

        Falcon vulnerability schema (relevant fields):
        {
            "id": "vuln_123",
            "cve": {"id": "CVE-2024-1234", "severity": "HIGH"},
            "host_info": {"hostname": "worker-1"},
            "app": {"product_name_version": "openssl-3.0.1"},
            "remediation": {"action": "Update to openssl-3.0.14"},
            "created_timestamp": "2024-01-15T10:30:00Z",
            "updated_timestamp": "2024-01-20T08:00:00Z",
        }
        """
        try:
            vuln_id = vuln.get("id", "")
            cve_info = vuln.get("cve", {})
            host_info = vuln.get("host_info", {})
            app_info = vuln.get("app", {})
            remediation_info = vuln.get("remediation", {})

            cve_id = cve_info.get("id", "")
            severity_str = cve_info.get("severity", "medium")
            severity = map_severity(severity_str, vendor="falcon")

            hostname = host_info.get("hostname", "unknown")
            product = app_info.get("product_name_version", "unknown")

            return GPFinding(
                source="falcon",
                source_id=vuln_id,
                finding_type=FindingType.VULNERABILITY,
                severity=severity,
                title=f"{cve_id}: {product}" if cve_id else f"Vulnerability in {product}",
                description=cve_info.get("description", ""),
                asset_type="package",
                asset_id=product,
                cve_id=cve_id if cve_id else None,
                remediation=remediation_info.get("action"),
                first_seen=_parse_ts(vuln.get("created_timestamp")),
                last_seen=_parse_ts(vuln.get("updated_timestamp")),
                vendor_severity=severity_str,
                vendor_category="spotlight_vulnerability",
                raw_payload=vuln,
            )
        except Exception as e:
            logger.error("Failed to map vulnerability %s: %s", vuln.get("id"), e)
            return None

    def iom_to_finding(self, iom: dict) -> Optional[GPFinding]:
        """
        Map a Falcon Indicator of Misconfiguration (IoM) to GPFinding.

        IoMs are K8s/cloud misconfigurations detected by Falcon Cloud Security.
        """
        try:
            iom_id = iom.get("id", "")
            severity_str = iom.get("severity", "medium")
            severity = map_severity(severity_str, vendor="falcon")

            resource_type = iom.get("resource_type", "unknown")
            resource_id = iom.get("resource_id", "unknown")

            return GPFinding(
                source="falcon",
                source_id=iom_id,
                finding_type=FindingType.MISCONFIGURATION,
                severity=severity,
                title=iom.get("title", f"Misconfiguration: {resource_type}"),
                description=iom.get("description", ""),
                asset_type=resource_type,
                asset_id=resource_id,
                namespace=iom.get("namespace"),
                cluster=iom.get("cluster_name"),
                remediation=iom.get("remediation"),
                first_seen=_parse_ts(iom.get("created_timestamp")),
                last_seen=_parse_ts(iom.get("updated_timestamp")),
                vendor_severity=severity_str,
                vendor_category="iom",
                raw_payload=iom,
            )
        except Exception as e:
            logger.error("Failed to map IoM %s: %s", iom.get("id"), e)
            return None


def _parse_ts(ts_str: Optional[str]) -> Optional[datetime]:
    """Parse Falcon timestamp string to datetime."""
    if not ts_str:
        return None
    try:
        return datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return None
