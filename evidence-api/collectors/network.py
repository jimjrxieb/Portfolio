"""
Network policy evidence collector.
Maps to: SC-7, SC-7(5), AC-4
"""

import json
import subprocess
from datetime import datetime, timezone


def _run(args: list[str]) -> dict:
    result = subprocess.run(args, capture_output=True, text=True, timeout=30)
    try:
        return json.loads(result.stdout) if result.stdout else {}
    except json.JSONDecodeError:
        return {"raw": result.stdout, "error": result.stderr}


def collect() -> dict:
    collected_at = datetime.now(timezone.utc).isoformat()

    netpols = _run(["kubectl", "get", "networkpolicies", "-A", "-o", "json"])
    namespaces_raw = _run(["kubectl", "get", "namespaces", "-o", "json"])

    all_namespaces = [
        ns["metadata"]["name"]
        for ns in namespaces_raw.get("items", [])
    ]

    # Which namespaces have at least one NetworkPolicy?
    namespaces_with_policy = set()
    for pol in netpols.get("items", []):
        namespaces_with_policy.add(pol["metadata"]["namespace"])

    unprotected = [ns for ns in all_namespaces if ns not in namespaces_with_policy]

    # Flag policies that allow all ingress or all egress (overly permissive)
    permissive_policies = []
    for pol in netpols.get("items", []):
        spec = pol.get("spec", {})
        name = pol["metadata"]["name"]
        ns = pol["metadata"]["namespace"]

        ingress_rules = spec.get("ingress", [])
        egress_rules = spec.get("egress", [])

        # An empty dict {} in ingress/egress means allow all
        for rule in ingress_rules:
            if rule == {}:
                permissive_policies.append({
                    "namespace": ns,
                    "policy": name,
                    "issue": "allows all ingress (empty ingress rule)"
                })

        for rule in egress_rules:
            if rule == {}:
                permissive_policies.append({
                    "namespace": ns,
                    "policy": name,
                    "issue": "allows all egress (empty egress rule)"
                })

    return {
        "collector": "network",
        "collected_at": collected_at,
        "controls": ["SC-7", "SC-7(5)", "AC-4"],
        "total_namespaces": len(all_namespaces),
        "namespaces_with_policy": list(namespaces_with_policy),
        "unprotected_namespaces": unprotected,
        "unprotected_count": len(unprotected),
        "permissive_policies": permissive_policies,
        "network_policies": netpols.get("items", []),
    }
