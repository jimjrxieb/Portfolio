"""
Pod security context evidence collector.
Maps to: CM-6, CM-7, SC-28, SI-3, AC-6(9)
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


def _check_container(container: dict) -> dict:
    sc = container.get("securityContext", {})
    return {
        "name": container["name"],
        "image": container.get("image", "unknown"),
        "run_as_non_root": sc.get("runAsNonRoot"),
        "run_as_user": sc.get("runAsUser"),
        "read_only_root_fs": sc.get("readOnlyRootFilesystem"),
        "allow_privilege_escalation": sc.get("allowPrivilegeEscalation"),
        "capabilities_drop": sc.get("capabilities", {}).get("drop", []),
        "privileged": sc.get("privileged", False),
    }


def collect() -> dict:
    collected_at = datetime.now(timezone.utc).isoformat()
    pods_raw = _run(["kubectl", "get", "pods", "-A", "-o", "json"])

    violations = []
    compliant = []
    summary = {
        "total_pods": 0,
        "privileged_containers": 0,
        "root_containers": 0,
        "no_readonly_fs": 0,
        "privilege_escalation_allowed": 0,
        "missing_drop_all": 0,
    }

    for pod in pods_raw.get("items", []):
        meta = pod["metadata"]
        spec = pod.get("spec", {})
        pod_sc = spec.get("securityContext", {})
        namespace = meta["namespace"]
        pod_name = meta["name"]
        summary["total_pods"] += 1

        pod_issues = []
        containers = spec.get("containers", []) + spec.get("initContainers", [])

        for container in containers:
            c = _check_container(container)

            if c["privileged"]:
                pod_issues.append(f"{c['name']}: privileged=true")
                summary["privileged_containers"] += 1

            if c["run_as_non_root"] is False or c["run_as_user"] == 0:
                pod_issues.append(f"{c['name']}: running as root")
                summary["root_containers"] += 1

            if c["read_only_root_fs"] is not True:
                pod_issues.append(f"{c['name']}: readOnlyRootFilesystem not set")
                summary["no_readonly_fs"] += 1

            if c["allow_privilege_escalation"] is not False:
                pod_issues.append(f"{c['name']}: allowPrivilegeEscalation not false")
                summary["privilege_escalation_allowed"] += 1

            if "ALL" not in c["capabilities_drop"]:
                pod_issues.append(f"{c['name']}: capabilities.drop does not include ALL")
                summary["missing_drop_all"] += 1

        entry = {
            "namespace": namespace,
            "pod": pod_name,
            "issues": pod_issues,
            "pod_security_context": pod_sc,
        }

        if pod_issues:
            violations.append(entry)
        else:
            compliant.append({"namespace": namespace, "pod": pod_name})

    return {
        "collector": "pods",
        "collected_at": collected_at,
        "controls": ["CM-6", "CM-7", "SC-28", "AC-6(9)"],
        "summary": summary,
        "violation_count": len(violations),
        "compliant_count": len(compliant),
        "violations": violations,
        "compliant_pods": compliant,
    }
