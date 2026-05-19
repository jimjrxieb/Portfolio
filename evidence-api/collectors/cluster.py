"""
Cluster hardening evidence collector.
Runs kube-bench and kubescape.
Maps to: CM-6, CM-7, SC-7, SI-2, AC-2, AU-2
"""

import json
import subprocess
from datetime import datetime, timezone


def _run_json(args: list[str]) -> dict:
    result = subprocess.run(args, capture_output=True, text=True, timeout=120)
    try:
        return json.loads(result.stdout) if result.stdout else {}
    except json.JSONDecodeError:
        return {"raw": result.stdout[:5000], "error": result.stderr[:500]}


def collect_kube_bench() -> dict:
    result = subprocess.run(
        ["kube-bench", "run", "--json"],
        capture_output=True, text=True, timeout=120,
    )
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return {"error": result.stderr[:500], "raw": result.stdout[:2000]}

    # Summarize — don't return the full blob to keep payloads manageable
    totals = data.get("Totals", {})
    controls = []
    for test in data.get("Controls", []):
        for group in test.get("tests", []):
            for result_item in group.get("results", []):
                if result_item.get("status") in ("FAIL", "WARN"):
                    controls.append({
                        "id": result_item.get("test_number"),
                        "desc": result_item.get("test_desc"),
                        "status": result_item.get("status"),
                        "remediation": result_item.get("remediation", ""),
                    })

    return {
        "tool": "kube-bench",
        "totals": totals,
        "fail_warn_count": len(controls),
        "findings": controls,
    }


def collect_kubescape() -> dict:
    result = subprocess.run(
        ["kubescape", "scan", "--format", "json", "--output", "/tmp/kubescape-evidence.json"],
        capture_output=True, text=True, timeout=180,
    )
    try:
        with open("/tmp/kubescape-evidence.json") as f:
            data = json.load(f)
    except Exception:
        try:
            data = json.loads(result.stdout)
        except Exception:
            return {"error": result.stderr[:500]}

    # Extract summary
    summary = data.get("summaryDetails", {})
    failed_controls = []
    for resource in data.get("results", []):
        for control in resource.get("controls", []):
            if control.get("status", {}).get("status") == "failed":
                failed_controls.append({
                    "control_id": control.get("controlID"),
                    "name": control.get("name"),
                    "resource": resource.get("name"),
                    "namespace": resource.get("namespace"),
                })

    return {
        "tool": "kubescape",
        "summary": summary,
        "failed_control_count": len(failed_controls),
        "failed_controls": failed_controls[:50],  # cap for payload size
    }


def collect() -> dict:
    collected_at = datetime.now(timezone.utc).isoformat()

    bench = collect_kube_bench()
    scape = collect_kubescape()

    return {
        "collector": "cluster",
        "collected_at": collected_at,
        "controls": ["CM-6", "CM-7", "SC-7", "SI-2", "AC-2", "AU-2"],
        "kube_bench": bench,
        "kubescape": scape,
    }
