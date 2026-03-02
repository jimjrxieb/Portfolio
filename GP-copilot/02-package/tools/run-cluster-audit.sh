#!/usr/bin/env bash
# run-cluster-audit.sh
# Live cluster audit — CKS + CKA best practices.
# Runs kubescape, kube-bench, polaris, RBAC audit, and resource cliff check.
# Outputs one markdown report per run.
#
# Usage:
#   bash run-cluster-audit.sh
#   bash run-cluster-audit.sh --output ~/reports/client-audit-$(date +%Y%m%d).md
#   bash run-cluster-audit.sh --skip kubescape --skip kube-bench

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

OUTPUT=""
SKIP_TOOLS=()
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --output FILE      Write report to file (default: ./k8s-audit-DATE.md)"
  echo "  --skip TOOL        Skip a tool: kubescape|kube-bench|polaris|rbac|resources (repeatable)"
  echo "  --help|-h          Show this help"
  echo ""
  echo "Examples:"
  echo "  bash run-cluster-audit.sh"
  echo "  bash run-cluster-audit.sh --output ~/reports/acme-audit-$(date +%Y%m%d).md"
  echo "  bash run-cluster-audit.sh --skip kube-bench"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) OUTPUT="$2"; shift 2 ;;
    --skip)   SKIP_TOOLS+=("$2"); shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo -e "${RED}Unknown option: $1${NC}"; usage; exit 1 ;;
  esac
done

OUTPUT="${OUTPUT:-./k8s-audit-${DATE}.md}"

should_skip() { local t="$1"; for s in "${SKIP_TOOLS[@]:-}"; do [[ "$s" == "$t" ]] && return 0; done; return 1; }

echo ""
echo -e "${BLUE}=== K8s Cluster Audit ===${NC}"
echo "  Output    : $OUTPUT"
echo "  Skipping  : ${SKIP_TOOLS[*]:-none}"
echo ""

# Verify cluster access
if ! kubectl cluster-info &>/dev/null; then
  echo -e "${RED}ERROR: Cannot reach cluster. Check kubectl context.${NC}"
  exit 1
fi

CLUSTER_CTX=$(kubectl config current-context 2>/dev/null || echo "unknown")
CLUSTER_VER=$(kubectl version --short 2>/dev/null | grep "Server" | awk '{print $3}' || echo "unknown")
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
NS_COUNT=$(kubectl get namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')
POD_COUNT=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l | tr -d ' ')

echo -e "${GREEN}Connected:${NC} $CLUSTER_CTX  |  $CLUSTER_VER  |  ${NODE_COUNT} nodes  |  ${NS_COUNT} namespaces  |  ${POD_COUNT} pods"
echo ""

# ── Report header ──────────────────────────────────────────────────────────
REPORT_LINES=()
REPORT_LINES+=("# K8s Cluster Audit Report")
REPORT_LINES+=("Date: $DATE  |  Context: \`$CLUSTER_CTX\`  |  Server: \`$CLUSTER_VER\`")
REPORT_LINES+=("")
REPORT_LINES+=("| | |")
REPORT_LINES+=("|---|---|")
REPORT_LINES+=("| Nodes | $NODE_COUNT |")
REPORT_LINES+=("| Namespaces | $NS_COUNT |")
REPORT_LINES+=("| Pods | $POD_COUNT |")
REPORT_LINES+=("")
REPORT_LINES+=("---")
REPORT_LINES+=("")

# ── 1. Kubescape ───────────────────────────────────────────────────────────
if should_skip "kubescape"; then
  echo -e "${YELLOW}[SKIP]${NC} kubescape"
else
  echo -e "${BLUE}[1/5]${NC} kubescape — NSA/CISA + MITRE ATT&CK risk score"
  REPORT_LINES+=("## 1. Kubescape — Risk Score (NSA/CISA + MITRE ATT&CK)")
  REPORT_LINES+=("")
  if command -v kubescape &>/dev/null; then
    KS_OUT=$(kubescape scan cluster --format pretty-printer 2>/dev/null || true)
    # Extract risk score line
    KS_SCORE=$(echo "$KS_OUT" | grep -E "Risk score|risk score" | head -1 || echo "")
    KS_FAILED=$(echo "$KS_OUT" | grep -E "Failed resources|failed resources" | head -1 || echo "")
    KS_PASSED=$(echo "$KS_OUT" | grep -E "Passed resources|passed resources" | head -1 || echo "")
    if [[ -n "$KS_SCORE" ]]; then
      echo -e "  ${GREEN}✓${NC} $KS_SCORE"
      REPORT_LINES+=("\`\`\`")
      REPORT_LINES+=("$KS_SCORE")
      [[ -n "$KS_FAILED" ]] && REPORT_LINES+=("$KS_FAILED")
      [[ -n "$KS_PASSED" ]] && REPORT_LINES+=("$KS_PASSED")
      REPORT_LINES+=("\`\`\`")
    else
      echo -e "  ${YELLOW}⚠${NC} kubescape ran but could not parse score"
      REPORT_LINES+=("kubescape ran — check raw output for risk score")
    fi
    # Top failing controls
    KS_TOP=$(echo "$KS_OUT" | grep -A2 "FAILED" | head -30 || true)
    if [[ -n "$KS_TOP" ]]; then
      REPORT_LINES+=("")
      REPORT_LINES+=("**Top failing controls:**")
      REPORT_LINES+=("\`\`\`")
      REPORT_LINES+=("$KS_TOP")
      REPORT_LINES+=("\`\`\`")
    fi
  else
    echo -e "  ${YELLOW}⚠${NC} kubescape not installed — install: https://kubescape.io/docs/install/"
    REPORT_LINES+=("**kubescape not installed.** Install: \`curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash\`")
  fi
  REPORT_LINES+=("")
fi

# ── 2. Kube-bench ──────────────────────────────────────────────────────────
if should_skip "kube-bench"; then
  echo -e "${YELLOW}[SKIP]${NC} kube-bench"
else
  echo -e "${BLUE}[2/5]${NC} kube-bench — CIS Kubernetes Benchmark"
  REPORT_LINES+=("## 2. Kube-bench — CIS Benchmark")
  REPORT_LINES+=("")
  # kube-bench must run ON a cluster node — try local first, fall back to K8s Job
  KB_OUT=""
  KB_METHOD=""
  if command -v kube-bench &>/dev/null; then
    KB_OUT=$(kube-bench run 2>/dev/null || true)
    # If local run failed (no config / not on a node), KB_OUT will be empty or error
    if echo "$KB_OUT" | grep -q "^\[PASS\]\|^\[FAIL\]\|^\[WARN\]"; then
      KB_METHOD="local"
    else
      KB_OUT=""
    fi
  fi

  # Fallback: run as a Job inside the cluster
  if [[ -z "$KB_OUT" ]]; then
    echo -e "  ${YELLOW}⚠${NC} kube-bench can't run locally (must run on a cluster node)"
    echo -e "  ${BLUE}→${NC} Running as Kubernetes Job..."
    # Clean up any previous run
    kubectl delete job kube-bench -n default --ignore-not-found &>/dev/null || true
    if kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml &>/dev/null; then
      # Wait for job to complete (up to 90s)
      if kubectl wait --for=condition=complete job/kube-bench -n default --timeout=90s &>/dev/null 2>&1; then
        KB_OUT=$(kubectl logs job.batch/kube-bench -n default 2>/dev/null || true)
        KB_METHOD="job"
      else
        echo -e "  ${RED}✗${NC} kube-bench Job did not complete in 90s"
      fi
      # Clean up
      kubectl delete job kube-bench -n default --ignore-not-found &>/dev/null || true
    else
      echo -e "  ${RED}✗${NC} Could not create kube-bench Job"
    fi
  fi

  if [[ -n "$KB_OUT" ]] && echo "$KB_OUT" | grep -q "^\[PASS\]\|^\[FAIL\]\|^\[WARN\]"; then
    [[ "$KB_METHOD" == "job" ]] && echo -e "  ${GREEN}✓${NC} Results from cluster Job"
    KB_SUMMARY=$(echo "$KB_OUT" | grep -E "^== Summary" -A10 | head -15 || true)
    KB_FAIL_COUNT=$(echo "$KB_OUT" | grep -c "^\[FAIL\]" || echo "0")
    KB_WARN_COUNT=$(echo "$KB_OUT" | grep -c "^\[WARN\]" || echo "0")
    KB_PASS_COUNT=$(echo "$KB_OUT" | grep -c "^\[PASS\]" || echo "0")
    echo -e "  PASS: ${GREEN}$KB_PASS_COUNT${NC}  FAIL: ${RED}$KB_FAIL_COUNT${NC}  WARN: ${YELLOW}$KB_WARN_COUNT${NC}"
    REPORT_LINES+=("| PASS | FAIL | WARN | Method |")
    REPORT_LINES+=("|------|------|------|--------|")
    REPORT_LINES+=("| $KB_PASS_COUNT | $KB_FAIL_COUNT | $KB_WARN_COUNT | $KB_METHOD |")
    REPORT_LINES+=("")
    if [[ -n "$KB_SUMMARY" ]]; then
      REPORT_LINES+=("\`\`\`")
      REPORT_LINES+=("$KB_SUMMARY")
      REPORT_LINES+=("\`\`\`")
    fi
    # Top 10 FAILs
    KB_FAILS=$(echo "$KB_OUT" | grep "^\[FAIL\]" | head -10 || true)
    if [[ -n "$KB_FAILS" ]]; then
      REPORT_LINES+=("")
      REPORT_LINES+=("**Top failures:**")
      REPORT_LINES+=("\`\`\`")
      REPORT_LINES+=("$KB_FAILS")
      REPORT_LINES+=("\`\`\`")
    fi
  else
    echo -e "  ${RED}✗${NC} kube-bench could not produce results (local or Job)"
    REPORT_LINES+=("**kube-bench could not run.** It must execute on a cluster node.")
    REPORT_LINES+=("")
    REPORT_LINES+=("Manual run:")
    REPORT_LINES+=("\`\`\`bash")
    REPORT_LINES+=("# SSH to a node and run directly:")
    REPORT_LINES+=("ssh <node> 'kube-bench run'")
    REPORT_LINES+=("")
    REPORT_LINES+=("# Or run as a Kubernetes Job:")
    REPORT_LINES+=("kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml")
    REPORT_LINES+=("kubectl wait --for=condition=complete job/kube-bench -n default --timeout=90s")
    REPORT_LINES+=("kubectl logs job.batch/kube-bench -n default")
    REPORT_LINES+=("\`\`\`")
  fi
  REPORT_LINES+=("")
fi

# ── 3. Polaris ─────────────────────────────────────────────────────────────
if should_skip "polaris"; then
  echo -e "${YELLOW}[SKIP]${NC} polaris"
else
  echo -e "${BLUE}[3/5]${NC} polaris — best practices score"
  REPORT_LINES+=("## 3. Polaris — Best Practices Score")
  REPORT_LINES+=("")
  if command -v polaris &>/dev/null; then
    # polaris v8+ auto-connects via kubeconfig — no --cluster flag needed
    # stderr has log lines, stdout has JSON — must separate them
    POL_SCORE=$(polaris audit --format json 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    score = d.get('Score', 'N/A')
    print(f'Score: {score}/100')
except:
    print('')
" 2>/dev/null || echo "")

    if [[ -n "$POL_SCORE" && "$POL_SCORE" != "Score: N/A/100" ]]; then
      echo -e "  ${GREEN}✓${NC} $POL_SCORE"
      REPORT_LINES+=("\`\`\`")
      REPORT_LINES+=("$POL_SCORE")
      REPORT_LINES+=("\`\`\`")
    else
      echo -e "  ${YELLOW}⚠${NC} polaris JSON parse failed — trying pretty format"
    fi

    # Always grab the pretty-format failures for the report
    POL_FAILURES=$(polaris audit --format pretty --only-show-failed-tests 2>/dev/null || true)
    # Strip ANSI color codes for clean markdown
    POL_FAILURES_CLEAN=$(echo "$POL_FAILURES" | sed 's/\x1b\[[0-9;]*m//g' | head -60 || true)
    if [[ -n "$POL_FAILURES_CLEAN" ]]; then
      REPORT_LINES+=("")
      REPORT_LINES+=("**Failed checks:**")
      REPORT_LINES+=("\`\`\`")
      REPORT_LINES+=("$POL_FAILURES_CLEAN")
      REPORT_LINES+=("\`\`\`")
    fi
  else
    echo -e "  ${YELLOW}⚠${NC} polaris not installed — install: brew install fairwindsops/tap/polaris"
    REPORT_LINES+=("**polaris not installed.** Install: \`brew install fairwindsops/tap/polaris\`")
  fi
  REPORT_LINES+=("")
fi

# ── 4. RBAC audit ──────────────────────────────────────────────────────────
if should_skip "rbac"; then
  echo -e "${YELLOW}[SKIP]${NC} rbac"
else
  echo -e "${BLUE}[4/5]${NC} RBAC — cluster-admin bindings + wildcard roles"
  REPORT_LINES+=("## 4. RBAC Audit")
  REPORT_LINES+=("")

  # Who has cluster-admin
  CA_BINDINGS=$(kubectl get clusterrolebindings -A -o json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
admins = []
for b in d.get('items', []):
    if b.get('roleRef', {}).get('name') == 'cluster-admin':
        subjects = b.get('subjects', [])
        for s in subjects:
            admins.append(f\"  {b['metadata']['name']}: {s.get('kind','?')}/{s.get('name','?')} (ns:{s.get('namespace','-')})\")
for a in admins:
    print(a)
" 2>/dev/null || echo "  (could not query)")

  CA_COUNT=$(echo "$CA_BINDINGS" | grep -c "^  " || echo "0")
  echo -e "  cluster-admin bindings: ${YELLOW}$CA_COUNT${NC}"
  REPORT_LINES+=("### cluster-admin bindings ($CA_COUNT found)")
  REPORT_LINES+=("")
  REPORT_LINES+=("\`\`\`")
  REPORT_LINES+=("$CA_BINDINGS")
  REPORT_LINES+=("\`\`\`")
  REPORT_LINES+=("")
  [[ "$CA_COUNT" -gt 3 ]] && REPORT_LINES+=("**⚠ >3 cluster-admin bindings is excessive. Review and remove unused ones.**") && REPORT_LINES+=("")

  # Wildcard rules in ClusterRoles
  WILDCARD_ROLES=$(kubectl get clusterroles -o json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
hits = []
skip = {'system:', 'kubeadm:', 'flannel', 'calico', 'aws-', 'eks:', 'kube-', 'helm-', 'tiller'}
for r in d.get('items', []):
    name = r['metadata']['name']
    if any(name.startswith(s) for s in skip):
        continue
    for rule in r.get('rules', []):
        if '*' in rule.get('verbs', []) or '*' in rule.get('resources', []):
            hits.append(f'  {name}: verbs={rule.get(\"verbs\")} resources={rule.get(\"resources\")}')
            break
for h in hits[:15]:
    print(h)
" 2>/dev/null || echo "  (could not query)")

  WC_COUNT=$(echo "$WILDCARD_ROLES" | grep -c "^  " 2>/dev/null || echo "0")
  echo -e "  wildcard roles: ${YELLOW}$WC_COUNT${NC}"
  if [[ "$WC_COUNT" -gt 0 ]]; then
    REPORT_LINES+=("### Wildcard rules in ClusterRoles ($WC_COUNT found — non-system)")
    REPORT_LINES+=("")
    REPORT_LINES+=("\`\`\`")
    REPORT_LINES+=("$WILDCARD_ROLES")
    REPORT_LINES+=("\`\`\`")
    REPORT_LINES+=("**Fix:** Replace wildcard verbs/resources with explicit permissions.")
    REPORT_LINES+=("")
  fi
fi

# ── 5. Resource cliff + pod security ──────────────────────────────────────
if should_skip "resources"; then
  echo -e "${YELLOW}[SKIP]${NC} resources"
else
  echo -e "${BLUE}[5/5]${NC} Resource cliff + pod security quick check"
  REPORT_LINES+=("## 5. Resource Cliff + Pod Security")
  REPORT_LINES+=("")

  # Pods with no resource limits
  NO_LIMITS=$(kubectl get pods -A -o json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
hits = []
for pod in d.get('items', []):
    ns = pod['metadata']['namespace']
    name = pod['metadata']['name']
    for c in pod['spec'].get('containers', []):
        res = c.get('resources', {})
        if not res.get('limits'):
            hits.append(f'  {ns}/{name} — container: {c[\"name\"]}')
            break
for h in hits[:20]:
    print(h)
extra = len(hits) - 20
if extra > 0:
    print(f'  ... and {extra} more')
print(f'TOTAL_NO_LIMITS:{len(hits)}')
" 2>/dev/null || echo "  (could not query)")

  NL_COUNT=$(echo "$NO_LIMITS" | grep "^TOTAL_NO_LIMITS:" | cut -d: -f2 || echo "?")
  NL_LIST=$(echo "$NO_LIMITS" | grep -v "^TOTAL_NO_LIMITS:" || true)
  echo -e "  pods without resource limits: ${RED}$NL_COUNT${NC}"
  REPORT_LINES+=("### Pods without resource limits ($NL_COUNT)")
  REPORT_LINES+=("")
  if [[ -n "$NL_LIST" && "$NL_COUNT" != "0" ]]; then
    REPORT_LINES+=("\`\`\`")
    REPORT_LINES+=("$NL_LIST")
    REPORT_LINES+=("\`\`\`")
    REPORT_LINES+=("**Fix:** Add \`resources.limits.cpu/memory\` to every container. See \`GP-copilot/02-package/remediation-templates/pod-security-context.yaml\`.")
    REPORT_LINES+=("**Also:** Apply \`GP-copilot/02-package/remediation-templates/resource-management.yaml\` — LimitRange sets namespace-wide defaults.")
  else
    REPORT_LINES+=("All pods have resource limits defined.")
  fi
  REPORT_LINES+=("")

  # Pods running as root
  ROOT_PODS=$(kubectl get pods -A -o json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
hits = []
for pod in d.get('items', []):
    ns = pod['metadata']['namespace']
    name = pod['metadata']['name']
    spec = pod['spec']
    pod_sc = spec.get('securityContext', {})
    for c in spec.get('containers', []):
        c_sc = c.get('securityContext', {})
        run_as_non_root = c_sc.get('runAsNonRoot', pod_sc.get('runAsNonRoot', False))
        run_as_user = c_sc.get('runAsUser', pod_sc.get('runAsUser', None))
        if not run_as_non_root and (run_as_user is None or run_as_user == 0):
            hits.append(f'  {ns}/{name} — {c[\"name\"]}')
            break
for h in hits[:15]:
    print(h)
extra = len(hits) - 15
if extra > 0:
    print(f'  ... and {extra} more')
print(f'TOTAL_ROOT:{len(hits)}')
" 2>/dev/null || echo "  TOTAL_ROOT:?")

  ROOT_COUNT=$(echo "$ROOT_PODS" | grep "^TOTAL_ROOT:" | cut -d: -f2 || echo "?")
  ROOT_LIST=$(echo "$ROOT_PODS" | grep -v "^TOTAL_ROOT:" || true)
  echo -e "  pods potentially running as root: ${YELLOW}$ROOT_COUNT${NC}"
  REPORT_LINES+=("### Pods potentially running as root ($ROOT_COUNT)")
  REPORT_LINES+=("")
  if [[ -n "$ROOT_LIST" && "$ROOT_COUNT" != "0" ]]; then
    REPORT_LINES+=("\`\`\`")
    REPORT_LINES+=("$ROOT_LIST")
    REPORT_LINES+=("\`\`\`")
    REPORT_LINES+=("**Fix:** Add \`runAsNonRoot: true\` + \`runAsUser: 1000\` to securityContext. See \`GP-copilot/02-package/remediation-templates/pod-security-context.yaml\`.")
  else
    REPORT_LINES+=("All pods have runAsNonRoot set.")
  fi
  REPORT_LINES+=("")

  # Namespaces without network policies
  NS_NO_NP=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | while read ns; do
    count=$(kubectl get networkpolicy -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    [[ "$count" -eq 0 ]] && echo "  $ns"
  done || true)
  NNP_COUNT=$(echo "$NS_NO_NP" | grep -c "^  " 2>/dev/null || echo "0")
  echo -e "  namespaces without NetworkPolicy: ${YELLOW}$NNP_COUNT${NC}"
  REPORT_LINES+=("### Namespaces without NetworkPolicy ($NNP_COUNT)")
  REPORT_LINES+=("")
  if [[ -n "$NS_NO_NP" && "$NNP_COUNT" -gt 0 ]]; then
    REPORT_LINES+=("\`\`\`")
    REPORT_LINES+=("$NS_NO_NP")
    REPORT_LINES+=("\`\`\`")
    REPORT_LINES+=("**Fix:** Apply default-deny + ingress/egress rules. See \`GP-copilot/02-package/remediation-templates/network-policies.yaml\`.")
  else
    REPORT_LINES+=("All namespaces have at least one NetworkPolicy.")
  fi
  REPORT_LINES+=("")
fi

# ── Summary ────────────────────────────────────────────────────────────────
REPORT_LINES+=("---")
REPORT_LINES+=("")
REPORT_LINES+=("## Next Steps")
REPORT_LINES+=("")
REPORT_LINES+=("1. **Fix violations** — use \`GP-copilot/02-package/remediation-templates/\` for copy-paste patches")
REPORT_LINES+=("2. **Run policy checks** — \`bash GP-copilot/02-package/tools/test-policies.sh\` validates manifests against OPA policies")
REPORT_LINES+=("3. **Review Gatekeeper constraints** — \`GP-copilot/02-package/gatekeeper-constraints/\` has admission control templates")
REPORT_LINES+=("4. **CI/CD enforcement** — \`.github/workflows/policy-check.yml\` runs conftest on PRs")
REPORT_LINES+=("5. **Re-audit** — run this script again after applying fixes to verify progress")
REPORT_LINES+=("")
REPORT_LINES+=("*Portfolio Cluster Hardening Package*")

# ── Write report ───────────────────────────────────────────────────────────
printf '%s\n' "${REPORT_LINES[@]}" > "$OUTPUT"

echo ""
echo -e "${GREEN}=== Done ===${NC}"
echo "  Report: $OUTPUT"
echo ""
