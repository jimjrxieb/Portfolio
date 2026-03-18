#!/usr/bin/env bash
# watch-drift.sh — K8s configuration drift detector
# Part of GP-CONSULTING/03-DEPLOY-RUNTIME/watchers/
#
# Compares deployment specs vs running pod specs to detect drift in:
#   securityContext, resource limits/requests, image tags, env var count, replicas
#
# Dependencies: kubectl, python3

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

NAMESPACE=""
SKIP_SYSTEM=false
OUTPUT=""
JSON_OUTPUT=false
ALL_NS_FLAG="--all-namespaces"
SCRIPT_NAME="$(basename "$0")"
DATE_STAMP="$(date +%Y-%m-%d_%H%M%S)"

SYSTEM_NAMESPACES="kube-system kube-public kube-node-lease gp-security calico-system tigera-operator"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Compare live K8s state vs deployment specs to detect configuration drift.

Checks:
  - Replicas (desired vs ready)
  - Image tag changes
  - Security context differences
  - Resource limits/requests changes
  - Environment variable count changes

Options:
  --namespace NS    Scan a single namespace (default: all namespaces)
  --skip-system     Skip system namespaces (kube-system, kube-public, etc.)
  --output FILE     Write markdown report to FILE
  --json            Output structured JSON findings (for piping to responders)
  -h, --help        Show this help

Examples:
  bash $SCRIPT_NAME                             # scan all namespaces
  bash $SCRIPT_NAME --namespace production      # single namespace
  bash $SCRIPT_NAME --skip-system               # skip system namespaces
  bash $SCRIPT_NAME --output report.md
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --namespace)   NAMESPACE="$2"; ALL_NS_FLAG="--namespace $2"; shift 2 ;;
        --skip-system) SKIP_SYSTEM=true; shift ;;
        --output)      OUTPUT="$2"; shift 2 ;;
        --json)        JSON_OUTPUT=true; shift ;;
        -h|--help)     usage ;;
        *)             echo "Unknown option: $1"; usage ;;
    esac
done

if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}ERROR: kubectl not found in PATH${RESET}" >&2; exit 1
fi
if ! kubectl cluster-info &>/dev/null 2>&1; then
    echo -e "${RED}ERROR: Cannot connect to Kubernetes cluster${RESET}" >&2; exit 1
fi

echo -e "${CYAN}${BOLD}[watch-drift] Comparing deployment specs vs running pods...${RESET}"
if [[ -n "$NAMESPACE" ]]; then
    echo -e "${CYAN}Namespace: ${NAMESPACE}${RESET}"
elif [[ "$SKIP_SYSTEM" == "true" ]]; then
    echo -e "${CYAN}Scope: all namespaces (skipping system)${RESET}"
else
    echo -e "${CYAN}Scope: all namespaces${RESET}"
fi
echo ""

MD_TMP="$(mktemp)"
DEPLOY_JSON="$(mktemp)"
PODS_JSON="$(mktemp)"
trap 'rm -f "$MD_TMP" "$DEPLOY_JSON" "$PODS_JSON"' EXIT

# shellcheck disable=SC2086
kubectl get deployments ${ALL_NS_FLAG} -o json > "$DEPLOY_JSON" 2>/dev/null &
# shellcheck disable=SC2086
kubectl get pods ${ALL_NS_FLAG} -o json > "$PODS_JSON" 2>/dev/null &
wait

SKIP_NS_LIST=""
if [[ "$SKIP_SYSTEM" == "true" ]]; then
    SKIP_NS_LIST="$SYSTEM_NAMESPACES"
fi

python3 -c '
import json, sys
from datetime import datetime

RED = "\033[0;31m"
YELLOW = "\033[1;33m"
GREEN = "\033[0;32m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
RESET = "\033[0m"

def load(path):
    try:
        with open(path) as f:
            return json.load(f).get("items", [])
    except Exception:
        return []

deployments = load(sys.argv[1])
pods = load(sys.argv[2])
md_path = sys.argv[3]
skip_ns = set(sys.argv[4].split()) if sys.argv[4] else set()

# Index pods by owner (deployment via replicaset)
# Build map: namespace/deployment-name -> list of pods
pod_map = {}  # ns/deploy -> [pod]
for pod in pods:
    ns = pod["metadata"].get("namespace", "default")
    if ns in skip_ns:
        continue
    owners = pod["metadata"].get("ownerReferences", [])
    for owner in owners:
        if owner.get("kind") == "ReplicaSet":
            rs_name = owner.get("name", "")
            # ReplicaSet name = deployment-name + "-" + hash
            # Strip the last hash segment
            parts = rs_name.rsplit("-", 1)
            if len(parts) == 2:
                deploy_name = parts[0]
                key = f"{ns}/{deploy_name}"
                if key not in pod_map:
                    pod_map[key] = []
                pod_map[key].append(pod)

findings = []
deployments_checked = 0

for deploy in deployments:
    ns = deploy["metadata"].get("namespace", "default")
    if ns in skip_ns:
        continue
    name = deploy["metadata"]["name"]
    key = f"{ns}/{name}"
    deployments_checked += 1

    deploy_spec = deploy.get("spec", {})
    pod_template = deploy_spec.get("template", {}).get("spec", {})
    deploy_containers = pod_template.get("containers", [])
    desired_replicas = deploy_spec.get("replicas", 1)

    # Status
    status = deploy.get("status", {})
    ready_replicas = status.get("readyReplicas", 0)
    available_replicas = status.get("availableReplicas", 0)

    deploy_findings = []

    # Check 1: Replica drift
    if ready_replicas != desired_replicas:
        sev = "CRITICAL" if ready_replicas == 0 else "WARNING"
        deploy_findings.append((sev, "replicas", f"desired={desired_replicas}, ready={ready_replicas}"))

    # Get running pods for this deployment
    running_pods = pod_map.get(key, [])

    if not running_pods and desired_replicas > 0:
        deploy_findings.append(("WARNING", "no-pods", "No running pods found for deployment"))
    else:
        for pod in running_pods[:1]:  # Check first pod as representative
            pod_spec = pod.get("spec", {})
            pod_containers = pod_spec.get("containers", [])

            # Build container maps
            deploy_cmap = {c["name"]: c for c in deploy_containers}
            pod_cmap = {c["name"]: c for c in pod_containers}

            for cname, dc in deploy_cmap.items():
                pc = pod_cmap.get(cname)
                if not pc:
                    deploy_findings.append(("WARNING", "missing-container", f"Container {cname} not in running pod"))
                    continue

                # Check 2: Image drift
                d_image = dc.get("image", "")
                p_image = pc.get("image", "")
                if d_image != p_image:
                    deploy_findings.append(("WARNING", "image", f"{cname}: spec={d_image}, running={p_image}"))

                # Check 3: Security context drift
                d_sc = dc.get("securityContext", {})
                p_sc = pc.get("securityContext", {})
                sc_fields = ["runAsNonRoot", "readOnlyRootFilesystem", "allowPrivilegeEscalation",
                             "privileged", "runAsUser", "runAsGroup"]
                for field in sc_fields:
                    dv = d_sc.get(field)
                    pv = p_sc.get(field)
                    if dv is not None and pv is not None and dv != pv:
                        sev = "CRITICAL" if field in ("privileged", "allowPrivilegeEscalation") else "WARNING"
                        deploy_findings.append((sev, f"securityContext.{field}", f"{cname}: spec={dv}, running={pv}"))

                # Check 4: Resource limits/requests drift
                d_res = dc.get("resources", {})
                p_res = pc.get("resources", {})
                for res_type in ["limits", "requests"]:
                    d_vals = d_res.get(res_type, {})
                    p_vals = p_res.get(res_type, {})
                    for metric in ["cpu", "memory"]:
                        dv = d_vals.get(metric)
                        pv = p_vals.get(metric)
                        if dv is not None and pv is not None and str(dv) != str(pv):
                            deploy_findings.append(("WARNING", f"resources.{res_type}.{metric}", f"{cname}: spec={dv}, running={pv}"))

                # Check 5: Env var count (not values — avoid leaking secrets)
                d_env_count = len(dc.get("env", []))
                p_env_count = len(pc.get("env", []))
                d_envfrom_count = len(dc.get("envFrom", []))
                p_envfrom_count = len(pc.get("envFrom", []))
                if d_env_count != p_env_count:
                    deploy_findings.append(("WARNING", "env-count", f"{cname}: spec={d_env_count} vars, running={p_env_count} vars"))
                if d_envfrom_count != p_envfrom_count:
                    deploy_findings.append(("WARNING", "envFrom-count", f"{cname}: spec={d_envfrom_count}, running={p_envfrom_count}"))

    if deploy_findings:
        for sev, check, detail in deploy_findings:
            findings.append((sev, ns, name, check, detail))

# Terminal output
total = len(findings)
critical = sum(1 for f in findings if f[0] == "CRITICAL")
warning = sum(1 for f in findings if f[0] == "WARNING")

if total == 0:
    print(f"{GREEN}{BOLD}PASS: No configuration drift detected across {deployments_checked} deployments.{RESET}")
else:
    color = RED if critical > 0 else YELLOW
    print(f"{color}{BOLD}DRIFT DETECTED: {total} differences found across {deployments_checked} deployments{RESET}")
    print(f"  ({critical} critical, {warning} warning)")
    print()

    current_deploy = ""
    for sev, ns, name, check, detail in findings:
        deploy_key = f"{ns}/{name}"
        if deploy_key != current_deploy:
            current_deploy = deploy_key
            print(f"  {BOLD}{ns}/{name}{RESET}")
        color = RED if sev == "CRITICAL" else YELLOW
        print(f"    {color}[{sev}] {check}: {detail}{RESET}")

print()

# Markdown
md = []
md.append("# K8s Drift Watcher Report\n")
md.append("**Date:** " + datetime.now().strftime("%Y-%m-%d %H:%M:%S") + "  ")
md.append(f"**Deployments checked:** {deployments_checked}  ")
md.append(f"**Drift findings:** {total} ({critical} critical, {warning} warning)\n")

if total == 0:
    md.append("## Result: PASS\n")
    md.append("No configuration drift detected.\n")
else:
    md.append("## Summary\n")
    md.append("| Severity | Namespace | Deployment | Check | Detail |")
    md.append("|----------|-----------|------------|-------|--------|")
    for sev, ns, name, check, detail in findings:
        md.append(f"| {sev} | {ns} | {name} | {check} | {detail.replace(chr(124), chr(92)+chr(124))} |")
    md.append("")

    # Group by deployment
    by_deploy = {}
    for sev, ns, name, check, detail in findings:
        k = f"{ns}/{name}"
        if k not in by_deploy:
            by_deploy[k] = []
        by_deploy[k].append((sev, check, detail))

    for deploy_key, drifts in by_deploy.items():
        md.append(f"### {deploy_key}\n")
        for sev, check, detail in drifts:
            md.append(f"- **[{sev}]** `{check}`: {detail}")
        md.append("")

md.append("---\n*Generated by GP-CONSULTING/03-DEPLOY-RUNTIME/watchers/watch-drift.sh*")

with open(md_path, "w") as f:
    f.write("\n".join(md) + "\n")

# JSON output
if sys.argv[5] == "true":
    import json as jmod
    json_findings = []
    CODE_MAP = {
        "replicas": "DRIFT_REPLICAS",
        "no-pods": "DRIFT_NO_PODS",
        "missing-container": "DRIFT_MISSING_CONTAINER",
        "image": "DRIFT_IMAGE",
        "env-count": "DRIFT_ENV",
        "envFrom-count": "DRIFT_ENVFROM",
    }
    for sev, ns, name, check, detail in findings:
        code = CODE_MAP.get(check, "DRIFT_SECCTX" if "securityContext" in check else "DRIFT_RESOURCES" if "resources" in check else "DRIFT_UNKNOWN")
        entry = {"code": code, "severity": sev, "namespace": ns, "resource": name, "message": f"{check}: {detail}"}
        if "securityContext" in check:
            entry["responder"] = "patch-security-context.sh"
            entry["args"] = f"--namespace {ns} --deployment {name}"
        json_findings.append(entry)
    jmod.dump({"watcher": "watch-drift", "findings": json_findings, "summary": {"total": len(json_findings), "critical": critical, "warning": warning}}, sys.stdout, indent=2)
    print()
' "$DEPLOY_JSON" "$PODS_JSON" "$MD_TMP" "$SKIP_NS_LIST" "$JSON_OUTPUT"

MD_FILE="${OUTPUT:-./watcher-drift-${DATE_STAMP}.md}"
cp "$MD_TMP" "$MD_FILE"
echo -e "${CYAN}Markdown report written to: ${MD_FILE}${RESET}"
