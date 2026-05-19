"""
RBAC evidence collector.
Maps to: AC-2, AC-3, AC-6, AC-6(1), AC-6(5)
"""

import json
import subprocess
from datetime import datetime, timezone


def _run(args: list[str]) -> dict:
    result = subprocess.run(
        args,
        capture_output=True,
        text=True,
        timeout=30,
    )
    try:
        return json.loads(result.stdout) if result.stdout else {}
    except json.JSONDecodeError:
        return {"raw": result.stdout, "error": result.stderr}


def collect() -> dict:
    collected_at = datetime.now(timezone.utc).isoformat()

    cluster_role_bindings = _run([
        "kubectl", "get", "clusterrolebindings", "-o", "json"
    ])
    role_bindings = _run([
        "kubectl", "get", "rolebindings", "-A", "-o", "json"
    ])
    service_accounts = _run([
        "kubectl", "get", "serviceaccounts", "-A", "-o", "json"
    ])
    cluster_roles = _run([
        "kubectl", "get", "clusterroles", "-o", "json"
    ])

    # Check default SA permissions in each namespace
    namespaces_raw = _run(["kubectl", "get", "namespaces", "-o", "json"])
    namespaces = [
        ns["metadata"]["name"]
        for ns in namespaces_raw.get("items", [])
    ]

    default_sa_perms = {}
    for ns in namespaces:
        result = subprocess.run(
            ["kubectl", "auth", "can-i", "--list",
             f"--as=system:serviceaccount:{ns}:default", f"-n={ns}"],
            capture_output=True, text=True, timeout=15,
        )
        default_sa_perms[ns] = result.stdout.strip()

    # Flag cluster-admin bindings — always a finding to review
    cluster_admin_bindings = []
    for item in cluster_role_bindings.get("items", []):
        role_ref = item.get("roleRef", {})
        if role_ref.get("name") == "cluster-admin":
            cluster_admin_bindings.append({
                "binding_name": item["metadata"]["name"],
                "subjects": item.get("subjects", []),
            })

    return {
        "collector": "rbac",
        "collected_at": collected_at,
        "controls": ["AC-2", "AC-3", "AC-6", "AC-6(1)", "AC-6(5)"],
        "cluster_admin_bindings": cluster_admin_bindings,
        "cluster_admin_count": len(cluster_admin_bindings),
        "service_account_count": len(service_accounts.get("items", [])),
        "namespaces_checked": namespaces,
        "default_sa_permissions_by_namespace": default_sa_perms,
        "cluster_role_bindings": cluster_role_bindings.get("items", []),
        "role_bindings": role_bindings.get("items", []),
        "cluster_roles": cluster_roles.get("items", []),
    }
