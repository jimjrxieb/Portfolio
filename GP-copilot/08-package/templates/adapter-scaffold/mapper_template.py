"""<VENDOR_NAME> — Mapper to GPFinding

Translates vendor-specific finding schema to the universal GPFinding format.

Usage:
    1. Copy this directory to vendors/<vendor>/
    2. Rename this file to mapper.py
    3. Replace all <VENDOR>, <VENDOR_NAME>, <vendor> placeholders
    4. Update SEVERITY_MAP for your vendor's severity values
    5. Implement per-type mapper methods (_vulnerability_to_finding, etc.)
    6. Update _detect_asset_type and _extract_asset_id for vendor's data model
"""

from shared.normalizer import FindingType, GPFinding, Severity

# ── Severity Mapping ──────────────────────────────────────────────────
# Map vendor's severity strings to GP severity enum.
# Check your vendor's API docs for exact string values.

VENDOR_SEVERITY_MAP = {
    # Most vendors use these standard strings:
    "critical": Severity.CRITICAL,
    "high": Severity.HIGH,
    "medium": Severity.MEDIUM,
    "low": Severity.LOW,
    "info": Severity.INFORMATIONAL,
    "informational": Severity.INFORMATIONAL,
    # Add vendor-specific values here:
    # "urgent": Severity.CRITICAL,
    # "negligible": Severity.INFORMATIONAL,
    # Numeric scores (some vendors use 1-10):
    # If your vendor uses numeric severity, convert in the mapper method
}

# ── Finding Type Routing ──────────────────────────────────────────────
# Map vendor's category strings to GP finding types.

VENDOR_TYPE_MAP = {
    "vulnerability": FindingType.VULNERABILITY,
    "misconfiguration": FindingType.MISCONFIGURATION,
    "runtime": FindingType.RUNTIME_DETECTION,
    "compliance": FindingType.COMPLIANCE_VIOLATION,
    "secret": FindingType.SECRET_EXPOSURE,
    "iam": FindingType.IAM_RISK,
    # Add vendor-specific category names:
    # "image_vuln": FindingType.VULNERABILITY,
    # "cloud_config": FindingType.MISCONFIGURATION,
    # "detection": FindingType.RUNTIME_DETECTION,
}


class VendorMapper:
    """Map <VENDOR_NAME> findings to GPFinding schema.

    Replace 'VendorMapper' with '<Vendor>Mapper' (e.g., WizMapper).
    """

    def map(self, raw_finding):
        """Route to the correct mapper based on finding type.

        The ingester adds a '_type' field to each raw finding
        to indicate which mapper method to use.
        """
        ftype = raw_finding.get("_type", "")
        method = getattr(self, f"_{ftype}_to_finding", None)
        if method:
            return method(raw_finding)
        return None

    # ── Per-Type Mappers ──────────────────────────────────────────────
    # Add one method per finding type your vendor produces.
    # The method name must match: _{_type}_to_finding

    def _vulnerability_to_finding(self, raw):
        """Map a vendor vulnerability to GPFinding."""
        return GPFinding(
            source="<vendor>",
            source_id=raw.get("id", ""),
            finding_type=FindingType.VULNERABILITY,
            severity=VENDOR_SEVERITY_MAP.get(
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

    # def _misconfiguration_to_finding(self, raw):
    #     """Map a vendor misconfiguration to GPFinding."""
    #     return GPFinding(
    #         source="<vendor>",
    #         source_id=raw.get("id", ""),
    #         finding_type=FindingType.MISCONFIGURATION,
    #         severity=VENDOR_SEVERITY_MAP.get(
    #             raw.get("severity", "").lower(), Severity.MEDIUM
    #         ),
    #         title=raw.get("title", ""),
    #         description=raw.get("description", ""),
    #         asset_type=self._detect_asset_type(raw),
    #         asset_id=self._extract_asset_id(raw),
    #         remediation=raw.get("remediation", ""),
    #         raw_payload=raw,
    #     )

    # def _runtime_to_finding(self, raw):
    #     """Map a vendor runtime detection to GPFinding."""
    #     ...

    # ── Helper Methods ────────────────────────────────────────────────

    def _build_title(self, raw):
        """Build a human-readable title from vendor fields.

        Priority: CVE + package > vendor title > fallback
        """
        cve = raw.get("cve_id", raw.get("cve", ""))
        pkg = raw.get("package", raw.get("component", ""))
        if cve and pkg:
            return f"{cve} in {pkg}"
        return raw.get("title", raw.get("name", "Unknown finding"))

    def _detect_asset_type(self, raw):
        """Determine asset type from vendor data.

        Update the field checks for your vendor's data model.
        Common vendor field names for each asset type:

        container_image: image, imageId, container_image, artifact
        node/host:       host, hostname, hostId, machine, endpoint
        package:         package, component, library, dependency
        cloud_resource:  resourceId, arn, resource, cloudResource
        k8s_resource:    namespace, pod, deployment, workload
        iam:             principal, role, user, identity
        """
        if raw.get("image") or raw.get("imageId"):
            return "container_image"
        if raw.get("host") or raw.get("hostname"):
            return "node"
        if raw.get("namespace") or raw.get("pod"):
            return "k8s_resource"
        if raw.get("arn") or raw.get("resourceId"):
            return "cloud_resource"
        if raw.get("package") or raw.get("component"):
            return "package"
        if raw.get("principal") or raw.get("role"):
            return "iam"
        return "resource"

    def _extract_asset_id(self, raw):
        """Extract the most specific asset identifier.

        The asset_id is used for dedup — two findings on the same
        asset_id with the same CVE will be merged.

        Update field priority for your vendor's data model.
        """
        return (
            raw.get("image", "")
            or raw.get("hostname", "")
            or raw.get("arn", "")
            or raw.get("resource_id", "")
            or raw.get("asset_id", "")
            or raw.get("id", "unknown")
        )

    def _extract_mitre(self, raw):
        """Extract MITRE ATT&CK technique IDs if available.

        Some vendors (Falcon, Wiz) provide MITRE mappings.
        Returns list of technique IDs like ["T1059", "T1053.005"]
        """
        tactics = raw.get("mitre_tactics", raw.get("attack_tactics", []))
        techniques = raw.get(
            "mitre_techniques", raw.get("attack_techniques", [])
        )
        if isinstance(techniques, str):
            techniques = [techniques]
        return techniques or []
