#!/usr/bin/env bash
# watch-events.sh — K8s event watcher for security-relevant patterns
# Part of GP-CONSULTING/03-DEPLOY-RUNTIME/watchers/
#
# Detects: CrashLoopBackOff, OOMKilled, ImagePullBackOff, FailedScheduling,
#          NodeNotReady, BackOff
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
FOLLOW=false
OUTPUT=""
JSON_OUTPUT=false
ALL_NS_FLAG="--all-namespaces"
SCRIPT_NAME="$(basename "$0")"
DATE_STAMP="$(date +%Y-%m-%d_%H%M%S)"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Watch K8s events for security-relevant patterns.

Options:
  --namespace NS    Scan a single namespace (default: all namespaces)
  --follow          Live stream events (kubectl get events -w)
  --output FILE     Write markdown report to FILE
  --json            Output structured JSON findings (for piping to responders)
  -h, --help        Show this help

Examples:
  bash $SCRIPT_NAME                        # one-shot scan of current events
  bash $SCRIPT_NAME --follow               # live stream
  bash $SCRIPT_NAME --namespace prod       # single namespace
  bash $SCRIPT_NAME --output report.md     # write markdown report
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --namespace)  NAMESPACE="$2"; ALL_NS_FLAG="--namespace $2"; shift 2 ;;
        --follow)     FOLLOW=true; shift ;;
        --output)     OUTPUT="$2"; shift 2 ;;
        --json)       JSON_OUTPUT=true; shift ;;
        -h|--help)    usage ;;
        *)            echo "Unknown option: $1"; usage ;;
    esac
done

if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}ERROR: kubectl not found in PATH${RESET}" >&2; exit 1
fi
if ! kubectl cluster-info &>/dev/null 2>&1; then
    echo -e "${RED}ERROR: Cannot connect to Kubernetes cluster${RESET}" >&2; exit 1
fi

# --- Follow mode: live stream with color highlighting ---
if [[ "$FOLLOW" == "true" ]]; then
    echo -e "${CYAN}${BOLD}[watch-events] Live streaming events...${RESET}"
    echo -e "${CYAN}Watching for: CrashLoopBackOff, OOMKilled, ImagePullBackOff, FailedScheduling, NodeNotReady, BackOff${RESET}"
    echo -e "${CYAN}Press Ctrl+C to stop.${RESET}"
    echo ""
    # shellcheck disable=SC2086
    kubectl get events ${ALL_NS_FLAG} --watch-only \
        -o custom-columns='TIME:.lastTimestamp,TYPE:.type,REASON:.reason,OBJECT:.involvedObject.name,MESSAGE:.message' \
    | while IFS= read -r line; do
        if echo "$line" | grep -qiE 'CrashLoopBackOff|OOMKilled|NodeNotReady'; then
            echo -e "${RED}${line}${RESET}"
        elif echo "$line" | grep -qiE 'ImagePullBackOff|FailedScheduling|BackOff'; then
            echo -e "${YELLOW}${line}${RESET}"
        else
            echo "$line"
        fi
    done
    exit 0
fi

# --- One-shot mode ---
echo -e "${CYAN}${BOLD}[watch-events] Scanning K8s events for security-relevant patterns...${RESET}"
if [[ -n "$NAMESPACE" ]]; then
    echo -e "${CYAN}Namespace: ${NAMESPACE}${RESET}"
else
    echo -e "${CYAN}Scope: all namespaces${RESET}"
fi
echo ""

MD_TMP="$(mktemp)"
trap 'rm -f "$MD_TMP"' EXIT

# shellcheck disable=SC2086
kubectl get events ${ALL_NS_FLAG} -o json 2>/dev/null \
| python3 -c "$(cat <<'PYEOF'
import json, sys
from datetime import datetime

data = json.load(sys.stdin)
items = data.get("items", [])

PATTERNS = [
    ("CrashLoopBackOff", "CRITICAL", "\033[0;31m", "Pod stuck in crash loop (3+ restarts)"),
    ("OOMKilled",        "CRITICAL", "\033[0;31m", "Container killed due to memory limit"),
    ("NodeNotReady",     "CRITICAL", "\033[0;31m", "Node not responding"),
    ("ImagePullBackOff", "WARNING",  "\033[1;33m", "Cannot pull container image"),
    ("FailedScheduling", "WARNING",  "\033[1;33m", "Pod cannot be scheduled"),
    ("BackOff",          "WARNING",  "\033[1;33m", "Container back-off restarting"),
]

GREEN = "\033[0;32m"
BOLD = "\033[1m"
RESET = "\033[0m"

findings = {p[0]: [] for p in PATTERNS}

for item in items:
    reason = item.get("reason", "")
    message = item.get("message", "")
    combined = f"{reason} {message}"
    for name, sev, color, desc in PATTERNS:
        if name.lower() in combined.lower():
            ns = item.get("metadata", {}).get("namespace", "cluster")
            ref = item.get("involvedObject", {})
            kind = ref.get("kind", "?")
            obj_name = ref.get("name", "?")
            findings[name].append({
                "ns": ns,
                "obj": kind + "/" + obj_name,
                "count": item.get("count", 1),
                "last": item.get("lastTimestamp", "unknown"),
                "msg": message[:120],
            })
            break

total = sum(len(v) for v in findings.values())

# Terminal output
if total == 0:
    print(f"{GREEN}{BOLD}PASS: No security-relevant event patterns detected.{RESET}")
    print(f"  Total events scanned: {len(items)}")
else:
    print(f"\033[0;31m{BOLD}FINDINGS: {total} security-relevant events detected{RESET}")
    print(f"  Total events scanned: {len(items)}\n")
    for name, sev, color, desc in PATTERNS:
        evts = findings[name]
        if not evts:
            continue
        print(f"{color}{BOLD}  [{sev}] {name} ({len(evts)} occurrences){RESET}")
        print(f"  {desc}")
        for e in evts[:10]:
            print(f"    {color}{e['ns']}/{e['obj']} (count={e['count']}, last={e['last']}){RESET}")
            print(f"      {e['msg']}")
        if len(evts) > 10:
            print(f"    ... and {len(evts) - 10} more")
        print()

# Markdown report to fd 3
md = []
md.append("# K8s Events Watcher Report\n")
md.append("**Date:** " + datetime.now().strftime("%Y-%m-%d %H:%M:%S") + "  ")
md.append(f"**Total events scanned:** {len(items)}  ")
md.append(f"**Findings:** {total}\n")
if total == 0:
    md.append("## Result: PASS\n")
    md.append("No security-relevant event patterns detected.\n")
else:
    md.append("## Summary\n")
    md.append("| Severity | Pattern | Count | Description |")
    md.append("|----------|---------|-------|-------------|")
    for name, sev, _, desc in PATTERNS:
        if findings[name]:
            md.append(f"| {sev} | {name} | {len(findings[name])} | {desc} |")
    md.append("")
    for name, sev, _, desc in PATTERNS:
        if not findings[name]:
            continue
        md.append(f"### {name}\n")
        md.append("| Namespace | Object | Count | Last Seen | Message |")
        md.append("|-----------|--------|-------|-----------|---------|")
        for e in findings[name]:
            msg = e["msg"].replace("|", "\\|")
            md.append(f"| {e['ns']} | {e['obj']} | {e['count']} | {e['last']} | {msg} |")
        md.append("")
md.append("---\n*Generated by GP-CONSULTING/03-DEPLOY-RUNTIME/watchers/watch-events.sh*")

with open(sys.argv[1], "w") as f:
    f.write("\n".join(md) + "\n")

# JSON output
if sys.argv[2] == "true":
    import json as jmod
    json_findings = []
    CODE_MAP = {
        "CrashLoopBackOff": "EVENT_CRASHLOOP",
        "OOMKilled": "EVENT_OOM",
        "NodeNotReady": "EVENT_NODE_DOWN",
        "ImagePullBackOff": "EVENT_IMAGE_PULL",
        "FailedScheduling": "EVENT_SCHEDULING",
        "BackOff": "EVENT_BACKOFF",
    }
    RESPONDER_MAP = {
        "CrashLoopBackOff": ("capture-forensics.sh", "--namespace {ns} --pod {pod}"),
        "OOMKilled": ("", ""),
        "NodeNotReady": ("", ""),
        "ImagePullBackOff": ("", ""),
        "FailedScheduling": ("", ""),
        "BackOff": ("capture-forensics.sh", "--namespace {ns} --pod {pod}"),
    }
    for pattern_name, evts in findings.items():
        for e in evts:
            code = CODE_MAP.get(pattern_name, "EVENT_UNKNOWN")
            sev = "CRITICAL" if pattern_name in ("CrashLoopBackOff", "OOMKilled", "NodeNotReady") else "WARNING"
            pod = e["obj"].split("/")[-1] if "/" in e["obj"] else e["obj"]
            entry = {"code": code, "severity": sev, "namespace": e["ns"], "resource": e["obj"], "message": e["msg"]}
            resp, args = RESPONDER_MAP.get(pattern_name, ("", ""))
            if resp:
                entry["responder"] = resp
                entry["args"] = args.format(ns=e["ns"], pod=pod)
            json_findings.append(entry)
    jmod.dump({"watcher": "watch-events", "findings": json_findings, "summary": {"total": len(json_findings), "critical": sum(1 for f in json_findings if f["severity"] == "CRITICAL"), "warning": sum(1 for f in json_findings if f["severity"] == "WARNING")}}, sys.stdout, indent=2)
    print()
PYEOF
)" "$MD_TMP" "$JSON_OUTPUT"

# Write report
MD_FILE="${OUTPUT:-./watcher-events-${DATE_STAMP}.md}"
cp "$MD_TMP" "$MD_FILE"
echo ""
echo -e "${CYAN}Markdown report written to: ${MD_FILE}${RESET}"
