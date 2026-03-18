#!/usr/bin/env bash
# add-security-headers.sh
# Add security headers to a web application or server config.
#
# Usage:
#   bash add-security-headers.sh <file> [framework]
#
# Error codes:
#   ZAP 10038 (Content-Security-Policy missing)
#   ZAP 10020 (X-Frame-Options missing)
#   ZAP 10021 (X-Content-Type-Options missing)
#   ZAP 10035 (Strict-Transport-Security missing)
#   ZAP 10036 (Server header leaks version info)
#
# What it does:
#   - Auto-detects the framework from file content
#   - Prints framework-specific middleware/config to add
#   - Creates .bak backup
#   - Guidance-first: prints what to add, auto-patches where safe

set -euo pipefail

FILE="${1:-}"
FRAMEWORK="${2:-auto}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: bash add-security-headers.sh <file> [framework]"
  echo ""
  echo "Frameworks: flask, express, django, fastapi, spring, nginx, apache, auto"
  echo ""
  echo "Examples:"
  echo "  bash add-security-headers.sh app.py flask"
  echo "  bash add-security-headers.sh server.js express"
  echo "  bash add-security-headers.sh nginx.conf nginx"
  echo "  bash add-security-headers.sh app.py          # auto-detect"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — Security Headers ===${NC}"
echo "  File      : $FILE"
echo "  Framework : $FRAMEWORK"
echo ""

# Auto-detect framework from file content
if [[ "$FRAMEWORK" == "auto" ]]; then
  CONTENT=$(cat "$FILE")
  if echo "$CONTENT" | grep -qE "from flask|import Flask"; then
    FRAMEWORK="flask"
  elif echo "$CONTENT" | grep -qE "from fastapi|import FastAPI|from starlette"; then
    FRAMEWORK="fastapi"
  elif echo "$CONTENT" | grep -qE "from django|INSTALLED_APPS|MIDDLEWARE"; then
    FRAMEWORK="django"
  elif echo "$CONTENT" | grep -qE "require\(['\"]express['\"]|from ['\"]express['\"]|import express"; then
    FRAMEWORK="express"
  elif echo "$CONTENT" | grep -qE "@SpringBoot|@RestController|import org.springframework"; then
    FRAMEWORK="spring"
  elif echo "$CONTENT" | grep -qE "server\s*\{|location\s*/|proxy_pass|nginx"; then
    FRAMEWORK="nginx"
  elif echo "$CONTENT" | grep -qE "<VirtualHost|ServerName|<Directory|Header set"; then
    FRAMEWORK="apache"
  else
    echo -e "${YELLOW}Could not auto-detect framework. Showing generic guidance.${NC}"
    FRAMEWORK="generic"
  fi
  echo -e "  Detected  : ${GREEN}$FRAMEWORK${NC}"
  echo ""
fi

# Create backup
cp "$FILE" "$FILE.bak"
echo -e "${YELLOW}Backup created: $FILE.bak${NC}"
echo ""

# Check what's already present
echo "Checking existing headers..."
HAS_CSP=$(grep -ci "Content-Security-Policy" "$FILE" || true)
HAS_XFO=$(grep -ci "X-Frame-Options" "$FILE" || true)
HAS_XCTO=$(grep -ci "X-Content-Type-Options" "$FILE" || true)
HAS_HSTS=$(grep -ci "Strict-Transport-Security" "$FILE" || true)

[[ $HAS_CSP -gt 0 ]]  && echo -e "  ${GREEN}✓ Content-Security-Policy — present${NC}"  || echo -e "  ${RED}✗ Content-Security-Policy — MISSING${NC}"
[[ $HAS_XFO -gt 0 ]]  && echo -e "  ${GREEN}✓ X-Frame-Options — present${NC}"          || echo -e "  ${RED}✗ X-Frame-Options — MISSING${NC}"
[[ $HAS_XCTO -gt 0 ]] && echo -e "  ${GREEN}✓ X-Content-Type-Options — present${NC}"   || echo -e "  ${RED}✗ X-Content-Type-Options — MISSING${NC}"
[[ $HAS_HSTS -gt 0 ]] && echo -e "  ${GREEN}✓ Strict-Transport-Security — present${NC}" || echo -e "  ${RED}✗ Strict-Transport-Security — MISSING${NC}"
echo ""

echo -e "${GREEN}Add the following to $FILE:${NC}"
echo ""

case "$FRAMEWORK" in
  flask)
    cat <<'SNIPPET'
# --- Security Headers (add after app = Flask(__name__)) ---

@app.after_request
def add_security_headers(response):
    response.headers['Content-Security-Policy'] = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'"
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    response.headers['Permissions-Policy'] = 'geolocation=(), camera=(), microphone=()'
    return response

# Alternative: use Flask-Talisman for production
# pip install flask-talisman
# from flask_talisman import Talisman
# Talisman(app, content_security_policy={...})
SNIPPET
    ;;

  fastapi)
    cat <<'SNIPPET'
# --- Security Headers Middleware ---

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response: Response = await call_next(request)
        response.headers['Content-Security-Policy'] = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'"
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
        response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
        response.headers['Permissions-Policy'] = 'geolocation=(), camera=(), microphone=()'
        return response

# Add to app: app.add_middleware(SecurityHeadersMiddleware)
SNIPPET
    ;;

  django)
    cat <<'SNIPPET'
# --- Security Headers (add to settings.py) ---

# Django 4+ built-in security middleware handles most headers.
# Ensure 'django.middleware.security.SecurityMiddleware' is in MIDDLEWARE.

SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True
X_FRAME_OPTIONS = 'DENY'
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_REFERRER_POLICY = 'strict-origin-when-cross-origin'

# CSP requires django-csp:
# pip install django-csp
# MIDDLEWARE += ['csp.middleware.CSPMiddleware']
# CSP_DEFAULT_SRC = ("'self'",)
# CSP_SCRIPT_SRC = ("'self'",)
# CSP_STYLE_SRC = ("'self'", "'unsafe-inline'")
SNIPPET
    ;;

  express)
    cat <<'SNIPPET'
// --- Security Headers (add near top of server setup) ---

// Option 1: helmet (recommended)
// npm install helmet
const helmet = require('helmet');
app.use(helmet());

// Option 2: manual headers
app.use((req, res, next) => {
  res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'");
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('Permissions-Policy', 'geolocation=(), camera=(), microphone=()');
  next();
});
SNIPPET
    ;;

  spring)
    cat <<'SNIPPET'
// --- Security Headers (Spring Security config) ---

import org.springframework.security.config.annotation.web.builders.HttpSecurity;

@Override
protected void configure(HttpSecurity http) throws Exception {
    http.headers(headers -> headers
        .contentSecurityPolicy(csp -> csp.policyDirectives("default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'"))
        .frameOptions(frame -> frame.deny())
        .httpStrictTransportSecurity(hsts -> hsts.maxAgeInSeconds(31536000).includeSubDomains(true))
        .contentTypeOptions(contentType -> {})
        .referrerPolicy(referrer -> referrer.policy(ReferrerPolicy.STRICT_ORIGIN_WHEN_CROSS_ORIGIN))
    );
}
SNIPPET
    ;;

  nginx)
    cat <<'SNIPPET'
# --- Security Headers (add inside server {} block) ---

add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'" always;
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), camera=(), microphone=()" always;

# Hide server version
server_tokens off;
SNIPPET
    ;;

  apache)
    cat <<'SNIPPET'
# --- Security Headers (add to VirtualHost or .htaccess) ---
# Requires: a2enmod headers

Header always set Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'"
Header always set X-Frame-Options "DENY"
Header always set X-Content-Type-Options "nosniff"
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
Header always set Permissions-Policy "geolocation=(), camera=(), microphone=()"

# Hide server version
ServerTokens Prod
ServerSignature Off
SNIPPET
    ;;

  *)
    cat <<'SNIPPET'
# --- Security Headers (generic — add to your response middleware) ---
#
# Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'
# X-Frame-Options: DENY
# X-Content-Type-Options: nosniff
# Strict-Transport-Security: max-age=31536000; includeSubDomains
# Referrer-Policy: strict-origin-when-cross-origin
# Permissions-Policy: geolocation=(), camera=(), microphone=()
#
# Consult your framework docs for the correct middleware pattern.
SNIPPET
    ;;
esac

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Add the middleware/config above to $FILE"
echo "  2. Adjust CSP directives for your app (may need 'unsafe-inline' for styles)"
echo "  3. Test locally — ensure no resources are blocked by CSP"
echo "  4. Re-scan: zap-baseline.py -t http://localhost:PORT -J zap-results.json"
echo "  5. Commit: git commit -m 'security: add security headers (ZAP 10038/10020/10021/10035)'"
echo ""
