#!/usr/bin/env bash
# fix-dast-findings.sh — Remediate DAST findings at the K8s infrastructure layer
# Part of GP-CONSULTING/03-DEPLOY-RUNTIME/responders/
#
# Fixes D-rank and C-rank DAST findings by patching gateway/ingress config,
# applying NetworkPolicies, and updating deployment specs.
#
# Usage:
#   # Fix specific category
#   bash fix-dast-findings.sh --namespace anthra --fix headers --dry-run
#   bash fix-dast-findings.sh --namespace anthra --fix headers --apply
#
#   # Fix all categories
#   bash fix-dast-findings.sh --namespace anthra --fix all --dry-run
#   bash fix-dast-findings.sh --namespace anthra --fix all --apply
#
#   # Pipe from run-dast.sh JSON
#   bash tools/run-dast.sh --target http://localhost:8080 --namespace anthra --json | \
#     bash responders/fix-dast-findings.sh --namespace anthra --fix auto --apply
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
FIX_CATEGORY=""
DRY_RUN=true
GATEWAY_NAME=""
GATEWAY_TYPE=""
SCRIPT_NAME="$(basename "$0")"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME --namespace NS --fix CATEGORY [OPTIONS]

Remediate DAST findings at the Kubernetes infrastructure layer.

Required:
  --namespace NS      Target namespace
  --fix CATEGORY      What to fix: headers, cookies, cors, paths, metadata, sa-tokens, all, auto

Options:
  --apply             Apply changes (default: dry-run)
  --dry-run           Show what would be applied (default)
  --gateway NAME      Gateway/Ingress name (auto-detected if not set)
  --gateway-type TYPE envoy|nginx|istio|httproute (auto-detected if not set)
  -h, --help          Show this help

Categories:
  headers     — Add security headers via gateway/ingress config
  cookies     — Document cookie fix (app-level — generates patch guidance)
  cors        — Document CORS fix (app-level — generates patch guidance)
  paths       — Block exposed paths (/metrics, /debug, /actuator) via NetworkPolicy
  metadata    — Block cloud metadata API (169.254.169.254) via NetworkPolicy
  sa-tokens   — Patch deployments to disable automountServiceAccountToken
  all         — Run all of the above
  auto        — Read JSON from stdin, fix only what was found

Examples:
  bash $SCRIPT_NAME --namespace anthra --fix all --dry-run
  bash $SCRIPT_NAME --namespace anthra --fix headers --apply
  bash $SCRIPT_NAME --namespace anthra --fix metadata --apply
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --namespace)    NAMESPACE="$2"; shift 2 ;;
        --fix)          FIX_CATEGORY="$2"; shift 2 ;;
        --apply)        DRY_RUN=false; shift ;;
        --dry-run)      DRY_RUN=true; shift ;;
        --gateway)      GATEWAY_NAME="$2"; shift 2 ;;
        --gateway-type) GATEWAY_TYPE="$2"; shift 2 ;;
        -h|--help)      usage; exit 0 ;;
        *)              echo -e "${RED}Unknown option: $1${RESET}" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$NAMESPACE" || -z "$FIX_CATEGORY" ]]; then
    echo -e "${RED}ERROR: --namespace and --fix are required.${RESET}" >&2
    usage
    exit 1
fi

MODE_LABEL="DRY RUN"
[[ "$DRY_RUN" == "false" ]] && MODE_LABEL="APPLY"

echo ""
echo -e "${BOLD}=== DAST Remediation ===${RESET}"
echo -e "  Namespace: $NAMESPACE"
echo -e "  Fix:       $FIX_CATEGORY"
echo -e "  Mode:      $MODE_LABEL"
echo ""

FIXED_COUNT=0
SKIPPED_COUNT=0

# ─── Auto-detect gateway type ────────────────────────────────────────────

detect_gateway() {
    if [[ -n "$GATEWAY_TYPE" ]]; then
        return
    fi

    # Check for Gateway API HTTPRoutes
    if kubectl get httproutes -n "$NAMESPACE" &>/dev/null 2>&1; then
        HR_COUNT=$(kubectl get httproutes -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l || echo "0")
        if [[ "$HR_COUNT" -gt 0 ]]; then
            GATEWAY_TYPE="httproute"
            [[ -z "$GATEWAY_NAME" ]] && GATEWAY_NAME=$(kubectl get httproutes -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
            return
        fi
    fi

    # Check for Ingress
    ING_COUNT=$(kubectl get ingress -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l || echo "0")
    if [[ "$ING_COUNT" -gt 0 ]]; then
        ING_CLASS=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].spec.ingressClassName}' 2>/dev/null || true)
        case "$ING_CLASS" in
            nginx)  GATEWAY_TYPE="nginx" ;;
            istio)  GATEWAY_TYPE="istio" ;;
            *)      GATEWAY_TYPE="nginx" ;;  # default assumption
        esac
        [[ -z "$GATEWAY_NAME" ]] && GATEWAY_NAME=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
        return
    fi

    # Check for Envoy Gateway
    if kubectl get gateways -n "$NAMESPACE" &>/dev/null 2>&1; then
        GW_COUNT=$(kubectl get gateways -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l || echo "0")
        if [[ "$GW_COUNT" -gt 0 ]]; then
            GATEWAY_TYPE="envoy"
            [[ -z "$GATEWAY_NAME" ]] && GATEWAY_NAME=$(kubectl get gateways -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
            return
        fi
    fi

    GATEWAY_TYPE="none"
}

# ─── Fix: Security Headers ───────────────────────────────────────────────

fix_headers() {
    echo -e "${BOLD}--- Fix: Security Headers ---${RESET}"
    echo ""

    detect_gateway

    case "$GATEWAY_TYPE" in
        httproute)
            echo -e "  ${CYAN}Gateway API HTTPRoute detected: $GATEWAY_NAME${RESET}"
            echo ""

            # Get current HTTPRoute and patch with ResponseHeaderModifier
            PATCH=$(cat <<'PATCH_EOF'
{
  "spec": {
    "rules": [{
      "filters": [{
        "type": "ResponseHeaderModifier",
        "responseHeaderModifier": {
          "set": [
            {"name": "X-Frame-Options", "value": "DENY"},
            {"name": "X-Content-Type-Options", "value": "nosniff"},
            {"name": "Strict-Transport-Security", "value": "max-age=31536000; includeSubDomains"},
            {"name": "Content-Security-Policy", "value": "default-src 'self'"},
            {"name": "Referrer-Policy", "value": "strict-origin-when-cross-origin"}
          ],
          "remove": ["Server", "X-Powered-By"]
        }
      }]
    }]
  }
}
PATCH_EOF
)
            echo "  Patch for HTTPRoute/$GATEWAY_NAME:"
            echo "$PATCH" | python3 -m json.tool 2>/dev/null | sed 's/^/    /'
            echo ""

            if [[ "$DRY_RUN" == "false" ]]; then
                kubectl patch httproute "$GATEWAY_NAME" -n "$NAMESPACE" --type merge -p "$PATCH" 2>&1
                echo -e "  ${GREEN}APPLIED${RESET}  Security headers added to HTTPRoute/$GATEWAY_NAME"
                FIXED_COUNT=$((FIXED_COUNT + 1))
            else
                echo -e "  ${YELLOW}DRY RUN${RESET}  Would patch HTTPRoute/$GATEWAY_NAME"
                FIXED_COUNT=$((FIXED_COUNT + 1))
            fi
            ;;

        nginx)
            echo -e "  ${CYAN}Nginx Ingress detected: $GATEWAY_NAME${RESET}"
            echo ""

            ANNOTATIONS='{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/configuration-snippet":"more_set_headers \"X-Frame-Options: DENY\";\nmore_set_headers \"X-Content-Type-Options: nosniff\";\nmore_set_headers \"Strict-Transport-Security: max-age=31536000; includeSubDomains\";\nmore_set_headers \"Content-Security-Policy: default-src '"'"'self'"'"'\";\nmore_set_headers \"Referrer-Policy: strict-origin-when-cross-origin\";\nmore_clear_headers \"Server\";\nmore_clear_headers \"X-Powered-By\";\n","nginx.ingress.kubernetes.io/server-snippet":"server_tokens off;"}}}'

            if [[ "$DRY_RUN" == "false" ]]; then
                kubectl patch ingress "$GATEWAY_NAME" -n "$NAMESPACE" --type merge -p "$ANNOTATIONS" 2>&1
                echo -e "  ${GREEN}APPLIED${RESET}  Security headers added to Ingress/$GATEWAY_NAME"
                FIXED_COUNT=$((FIXED_COUNT + 1))
            else
                echo "  Would add annotations to Ingress/$GATEWAY_NAME:"
                echo "    nginx.ingress.kubernetes.io/configuration-snippet: (security headers)"
                echo "    nginx.ingress.kubernetes.io/server-snippet: server_tokens off"
                echo -e "  ${YELLOW}DRY RUN${RESET}"
                FIXED_COUNT=$((FIXED_COUNT + 1))
            fi
            ;;

        none|*)
            echo -e "  ${YELLOW}SKIP${RESET}      No gateway/ingress found in namespace $NAMESPACE"
            echo ""
            echo "  Manual fix options:"
            echo "    1. Add headers in your app framework (Flask, Express, FastAPI)"
            echo "    2. Deploy an ingress controller and create an Ingress resource"
            echo "    3. Use Gateway API with an HTTPRoute ResponseHeaderModifier"
            echo ""
            echo "  Required headers:"
            echo "    X-Frame-Options: DENY"
            echo "    X-Content-Type-Options: nosniff"
            echo "    Strict-Transport-Security: max-age=31536000; includeSubDomains"
            echo "    Content-Security-Policy: default-src 'self'"
            echo "    Referrer-Policy: strict-origin-when-cross-origin"
            echo "    (remove Server and X-Powered-By)"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            ;;
    esac
    echo ""
}

# ─── Fix: Block Exposed Paths ────────────────────────────────────────────

fix_paths() {
    echo -e "${BOLD}--- Fix: Block Exposed Paths ---${RESET}"
    echo ""

    # Create a NetworkPolicy that restricts metrics/debug ports to monitoring namespace only
    NETPOL_YAML=$(cat <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dast-block-internal-endpoints
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    # Allow all traffic on app ports (80, 443, 8080, 3000, etc.)
    - ports:
        - port: 80
          protocol: TCP
        - port: 443
          protocol: TCP
        - port: 8080
          protocol: TCP
        - port: 3000
          protocol: TCP
    # Restrict metrics/debug ports to monitoring namespace only
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - port: 9090
          protocol: TCP
        - port: 9091
          protocol: TCP
        - port: 8081
          protocol: TCP
EOF
)

    echo "  NetworkPolicy to restrict /metrics access:"
    echo "$NETPOL_YAML" | sed 's/^/    /'
    echo ""

    if [[ "$DRY_RUN" == "false" ]]; then
        echo "$NETPOL_YAML" | kubectl apply -n "$NAMESPACE" -f - 2>&1
        echo -e "  ${GREEN}APPLIED${RESET}  NetworkPolicy dast-block-internal-endpoints"
        FIXED_COUNT=$((FIXED_COUNT + 1))
    else
        echo -e "  ${YELLOW}DRY RUN${RESET}  Would apply NetworkPolicy to $NAMESPACE"
        FIXED_COUNT=$((FIXED_COUNT + 1))
    fi

    echo ""
    echo "  Note: For path-level blocking, configure at the gateway/ingress level:"
    echo "    - Only route public paths (e.g., /api, /app) through the gateway"
    echo "    - Don't route /metrics, /debug, /actuator, /swagger externally"
    echo ""
}

# ─── Fix: Block Cloud Metadata API ───────────────────────────────────────

fix_metadata() {
    echo -e "${BOLD}--- Fix: Block Cloud Metadata API ---${RESET}"
    echo ""

    NETPOL_YAML=$(cat <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dast-block-metadata-api
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    # Allow all egress EXCEPT cloud metadata
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 169.254.169.254/32
EOF
)

    echo "  NetworkPolicy to block 169.254.169.254:"
    echo "$NETPOL_YAML" | sed 's/^/    /'
    echo ""

    if [[ "$DRY_RUN" == "false" ]]; then
        echo "$NETPOL_YAML" | kubectl apply -n "$NAMESPACE" -f - 2>&1
        echo -e "  ${GREEN}APPLIED${RESET}  NetworkPolicy dast-block-metadata-api"
        FIXED_COUNT=$((FIXED_COUNT + 1))
    else
        echo -e "  ${YELLOW}DRY RUN${RESET}  Would apply metadata-blocking NetworkPolicy to $NAMESPACE"
        FIXED_COUNT=$((FIXED_COUNT + 1))
    fi
    echo ""
}

# ─── Fix: Disable SA Token Mounts ────────────────────────────────────────

fix_sa_tokens() {
    echo -e "${BOLD}--- Fix: Disable ServiceAccount Token Mounts ---${RESET}"
    echo ""

    # Get deployments that don't have automountServiceAccountToken: false
    DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" -o json 2>/dev/null | python3 -c "
import sys, json
deps = json.load(sys.stdin)
for dep in deps.get('items', []):
    name = dep['metadata']['name']
    spec = dep.get('spec', {}).get('template', {}).get('spec', {})
    automount = spec.get('automountServiceAccountToken')
    if automount is not False:
        print(name)
" 2>/dev/null || true)

    if [[ -z "$DEPLOYMENTS" ]]; then
        echo -e "  ${GREEN}PASS${RESET}      All deployments already have automountServiceAccountToken: false"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        while IFS= read -r dep_name; do
            [[ -z "$dep_name" ]] && continue
            PATCH='{"spec":{"template":{"spec":{"automountServiceAccountToken":false}}}}'

            if [[ "$DRY_RUN" == "false" ]]; then
                kubectl patch deployment "$dep_name" -n "$NAMESPACE" -p "$PATCH" 2>&1
                echo -e "  ${GREEN}APPLIED${RESET}  $dep_name — automountServiceAccountToken: false"
                FIXED_COUNT=$((FIXED_COUNT + 1))
            else
                echo -e "  ${YELLOW}DRY RUN${RESET}  Would patch deployment/$dep_name — automountServiceAccountToken: false"
                FIXED_COUNT=$((FIXED_COUNT + 1))
            fi
        done <<< "$DEPLOYMENTS"
    fi
    echo ""
}

# ─── Fix: Cookie Guidance ────────────────────────────────────────────────

fix_cookies() {
    echo -e "${BOLD}--- Fix: Cookie Security ---${RESET}"
    echo ""
    echo "  Cookie flags must be set in the application code or framework config."
    echo "  This cannot be patched at the K8s infrastructure layer."
    echo ""
    echo "  Required flags for all cookies:"
    echo "    Secure=true    (only sent over HTTPS)"
    echo "    HttpOnly=true  (not accessible via JavaScript)"
    echo "    SameSite=Lax   (prevents CSRF)"
    echo ""
    echo "  Framework examples:"
    echo ""
    echo "    Flask:   response.set_cookie('session', token, secure=True, httponly=True, samesite='Lax')"
    echo "    Express: res.cookie('session', token, { secure: true, httpOnly: true, sameSite: 'lax' })"
    echo "    FastAPI: response.set_cookie('session', token, secure=True, httponly=True, samesite='lax')"
    echo "    Django:  SESSION_COOKIE_SECURE=True, SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE='Lax'"
    echo ""
    echo "  Or set via environment variables on the deployment:"
    echo "    kubectl set env deployment/<app> -n $NAMESPACE \\"
    echo "      SESSION_COOKIE_SECURE=true \\"
    echo "      SESSION_COOKIE_HTTPONLY=true \\"
    echo "      SESSION_COOKIE_SAMESITE=Lax"
    echo ""
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
}

# ─── Fix: CORS Guidance ──────────────────────────────────────────────────

fix_cors() {
    echo -e "${BOLD}--- Fix: CORS Configuration ---${RESET}"
    echo ""
    echo "  CORS must be configured in the application code or at the gateway level."
    echo ""
    echo "  Rule: Never use Access-Control-Allow-Origin: *"
    echo "  Rule: Never reflect the Origin header back as the allowed origin"
    echo ""

    detect_gateway

    case "$GATEWAY_TYPE" in
        nginx)
            echo "  For Nginx Ingress, add annotation:"
            echo "    nginx.ingress.kubernetes.io/cors-allow-origin: \"https://app.example.com\""
            echo "    nginx.ingress.kubernetes.io/enable-cors: \"true\""
            ;;
        *)
            echo "  Set allowed origins in application code:"
            echo ""
            echo "    Flask:   CORS(app, origins=['https://app.example.com'])"
            echo "    Express: cors({ origin: ['https://app.example.com'] })"
            echo "    FastAPI: CORSMiddleware(allow_origins=['https://app.example.com'])"
            ;;
    esac
    echo ""
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
}

# ─── Fix: Auto mode (read JSON from stdin) ───────────────────────────────

fix_auto() {
    echo -e "${BOLD}--- Auto-Fix from JSON ---${RESET}"
    echo ""

    if ! read -t 1 -r FIRST_LINE; then
        echo -e "  ${RED}ERROR${RESET}  No JSON input on stdin. Pipe from run-dast.sh --json"
        exit 1
    fi

    # Read the rest of stdin
    JSON_INPUT="$FIRST_LINE$(cat)"

    # Parse finding codes and determine which fixes to run
    FIXES_NEEDED=$(echo "$JSON_INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
fixes = set()
for f in data.get('findings', []):
    code = f.get('code', '')
    if 'MISSING_' in code or 'VERSION_DISCLOSURE' in code or 'POWERED_BY' in code:
        fixes.add('headers')
    elif 'COOKIE' in code:
        fixes.add('cookies')
    elif 'CORS' in code:
        fixes.add('cors')
    elif 'METRICS' in code or 'DEBUG' in code or 'SENSITIVE_PATH' in code or 'API_DOCS' in code:
        fixes.add('paths')
    elif 'METADATA' in code:
        fixes.add('metadata')
    elif 'SA_TOKEN' in code:
        fixes.add('sa-tokens')
for fix in sorted(fixes):
    print(fix)
" 2>/dev/null || true)

    if [[ -z "$FIXES_NEEDED" ]]; then
        echo -e "  ${GREEN}No auto-fixable findings in JSON input.${RESET}"
        return
    fi

    echo "  Findings mapped to fixes:"
    echo "$FIXES_NEEDED" | sed 's/^/    - /'
    echo ""

    while IFS= read -r fix; do
        [[ -z "$fix" ]] && continue
        case "$fix" in
            headers)    fix_headers ;;
            cookies)    fix_cookies ;;
            cors)       fix_cors ;;
            paths)      fix_paths ;;
            metadata)   fix_metadata ;;
            sa-tokens)  fix_sa_tokens ;;
        esac
    done <<< "$FIXES_NEEDED"
}

# ─── Run the requested fixes ─────────────────────────────────────────────

case "$FIX_CATEGORY" in
    headers)    fix_headers ;;
    cookies)    fix_cookies ;;
    cors)       fix_cors ;;
    paths)      fix_paths ;;
    metadata)   fix_metadata ;;
    sa-tokens)  fix_sa_tokens ;;
    all)
        fix_headers
        fix_paths
        fix_metadata
        fix_sa_tokens
        fix_cookies
        fix_cors
        ;;
    auto)       fix_auto ;;
    *)
        echo -e "${RED}Unknown fix category: $FIX_CATEGORY${RESET}" >&2
        echo "Valid: headers, cookies, cors, paths, metadata, sa-tokens, all, auto" >&2
        exit 1
        ;;
esac

# ─── Summary ─────────────────────────────────────────────────────────────

echo -e "${BOLD}=== Remediation Summary ===${RESET}"
echo -e "  ${GREEN}Fixed${RESET}:   $FIXED_COUNT"
echo -e "  ${YELLOW}Skipped${RESET}: $SKIPPED_COUNT (require app-level changes)"
echo ""

if [[ "$DRY_RUN" == "true" && "$FIXED_COUNT" -gt 0 ]]; then
    echo "Re-run with --apply to apply changes:"
    echo "  bash $SCRIPT_NAME --namespace $NAMESPACE --fix $FIX_CATEGORY --apply"
    echo ""
fi
