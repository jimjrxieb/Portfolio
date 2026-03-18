#!/usr/bin/env bash
# fix-cookie-flags.sh
# Add Secure, HttpOnly, and SameSite flags to cookie configuration.
#
# Usage:
#   bash fix-cookie-flags.sh <file> [framework]
#
# Error codes:
#   ZAP 10010 (Cookie without Secure flag)
#   ZAP 10054 (Cookie without HttpOnly flag)
#   ZAP 10029 (Cookie without SameSite attribute)
#
# What it does:
#   - Auto-detects the framework from file content
#   - Prints framework-specific cookie configuration
#   - Creates .bak backup

set -euo pipefail

FILE="${1:-}"
FRAMEWORK="${2:-auto}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: bash fix-cookie-flags.sh <file> [framework]"
  echo ""
  echo "Frameworks: flask, express, django, fastapi, spring, nginx, apache, auto"
  echo ""
  echo "Examples:"
  echo "  bash fix-cookie-flags.sh app.py flask"
  echo "  bash fix-cookie-flags.sh server.js express"
  echo "  bash fix-cookie-flags.sh settings.py django"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — Cookie Security Flags ===${NC}"
echo "  File      : $FILE"
echo "  Framework : $FRAMEWORK"
echo ""

# Auto-detect framework
if [[ "$FRAMEWORK" == "auto" ]]; then
  CONTENT=$(cat "$FILE")
  if echo "$CONTENT" | grep -qE "from flask|import Flask"; then
    FRAMEWORK="flask"
  elif echo "$CONTENT" | grep -qE "from fastapi|import FastAPI|from starlette"; then
    FRAMEWORK="fastapi"
  elif echo "$CONTENT" | grep -qE "from django|INSTALLED_APPS|MIDDLEWARE|SESSION_COOKIE"; then
    FRAMEWORK="django"
  elif echo "$CONTENT" | grep -qE "require\(['\"]express['\"]|from ['\"]express['\"]|import express"; then
    FRAMEWORK="express"
  elif echo "$CONTENT" | grep -qE "@SpringBoot|@RestController|import org.springframework"; then
    FRAMEWORK="spring"
  elif echo "$CONTENT" | grep -qE "server\s*\{|location\s*/|proxy_pass|nginx"; then
    FRAMEWORK="nginx"
  elif echo "$CONTENT" | grep -qE "<VirtualHost|ServerName|Header set"; then
    FRAMEWORK="apache"
  else
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
echo "Checking existing cookie settings..."
HAS_SECURE=$(grep -ci "\\bsecure\\b" "$FILE" || true)
HAS_HTTPONLY=$(grep -ci "httponly\|HttpOnly\|http_only" "$FILE" || true)
HAS_SAMESITE=$(grep -ci "samesite\|SameSite\|same_site" "$FILE" || true)

[[ "$HAS_SECURE" -gt 0 ]]   && echo -e "  ${GREEN}✓ Secure flag — likely present${NC}"   || echo -e "  ${RED}✗ Secure flag — MISSING${NC}"
[[ "$HAS_HTTPONLY" -gt 0 ]]  && echo -e "  ${GREEN}✓ HttpOnly flag — likely present${NC}"  || echo -e "  ${RED}✗ HttpOnly flag — MISSING${NC}"
[[ "$HAS_SAMESITE" -gt 0 ]] && echo -e "  ${GREEN}✓ SameSite attr — likely present${NC}"  || echo -e "  ${RED}✗ SameSite attribute — MISSING${NC}"
echo ""

echo -e "${GREEN}Add the following to $FILE:${NC}"
echo ""

case "$FRAMEWORK" in
  flask)
    cat <<'SNIPPET'
# --- Cookie Security (add to Flask app config) ---

app.config['SESSION_COOKIE_SECURE'] = True        # Only send over HTTPS
app.config['SESSION_COOKIE_HTTPONLY'] = True        # No JavaScript access
app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'      # CSRF protection
app.config['REMEMBER_COOKIE_SECURE'] = True
app.config['REMEMBER_COOKIE_HTTPONLY'] = True
app.config['REMEMBER_COOKIE_SAMESITE'] = 'Lax'

# For custom cookies using response.set_cookie():
# response.set_cookie('key', 'value', secure=True, httponly=True, samesite='Lax')
SNIPPET
    ;;

  fastapi)
    cat <<'SNIPPET'
# --- Cookie Security (FastAPI/Starlette) ---
# When setting cookies on a response:

from starlette.responses import JSONResponse

response = JSONResponse(content={"status": "ok"})
response.set_cookie(
    key="session_id",
    value="...",
    secure=True,          # Only send over HTTPS
    httponly=True,         # No JavaScript access
    samesite="lax",       # CSRF protection
    max_age=3600,
)

# If using SessionMiddleware:
# from starlette.middleware.sessions import SessionMiddleware
# app.add_middleware(SessionMiddleware, secret_key="...", https_only=True, same_site="lax")
SNIPPET
    ;;

  django)
    cat <<'SNIPPET'
# --- Cookie Security (add to settings.py) ---

SESSION_COOKIE_SECURE = True           # Only send over HTTPS
SESSION_COOKIE_HTTPONLY = True          # No JavaScript access
SESSION_COOKIE_SAMESITE = 'Lax'        # CSRF protection

CSRF_COOKIE_SECURE = True              # CSRF cookie also HTTPS-only
CSRF_COOKIE_HTTPONLY = True             # CSRF cookie no JS access
CSRF_COOKIE_SAMESITE = 'Lax'

LANGUAGE_COOKIE_SECURE = True
LANGUAGE_COOKIE_HTTPONLY = True
LANGUAGE_COOKIE_SAMESITE = 'Lax'
SNIPPET
    ;;

  express)
    cat <<'SNIPPET'
// --- Cookie Security (Express session config) ---

// If using express-session:
const session = require('express-session');
app.use(session({
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: true,          // Only send over HTTPS
    httpOnly: true,        // No JavaScript access
    sameSite: 'lax',       // CSRF protection
    maxAge: 3600000,       // 1 hour
  }
}));

// For individual cookies:
// res.cookie('name', 'value', { secure: true, httpOnly: true, sameSite: 'lax' });
SNIPPET
    ;;

  spring)
    cat <<'SNIPPET'
// --- Cookie Security (Spring Boot application.properties) ---
// server.servlet.session.cookie.secure=true
// server.servlet.session.cookie.http-only=true
// server.servlet.session.cookie.same-site=Lax

// Or programmatically in a @Configuration class:
import org.springframework.session.web.http.DefaultCookieSerializer;

@Bean
public DefaultCookieSerializer cookieSerializer() {
    DefaultCookieSerializer serializer = new DefaultCookieSerializer();
    serializer.setUseSecureCookie(true);
    serializer.setUseHttpOnlyCookie(true);
    serializer.setSameSite("Lax");
    return serializer;
}
SNIPPET
    ;;

  nginx)
    cat <<'SNIPPET'
# --- Cookie Security (Nginx proxy_cookie_flags) ---
# Requires nginx 1.19.3+ with ngx_http_proxy_module

# Add inside location {} block:
proxy_cookie_flags ~ secure httponly samesite=lax;

# Or rewrite Set-Cookie headers:
proxy_cookie_path / "/; Secure; HttpOnly; SameSite=Lax";
SNIPPET
    ;;

  apache)
    cat <<'SNIPPET'
# --- Cookie Security (Apache mod_headers) ---
# Requires: a2enmod headers

# Add Secure, HttpOnly, SameSite to all Set-Cookie headers:
Header always edit Set-Cookie ^(.*)$ "$1; Secure; HttpOnly; SameSite=Lax"
SNIPPET
    ;;

  *)
    cat <<'SNIPPET'
# --- Cookie Security (generic guidance) ---
#
# Every cookie your application sets should include:
#   Secure    — only transmitted over HTTPS
#   HttpOnly  — not accessible to JavaScript (prevents XSS cookie theft)
#   SameSite  — Lax (default) or Strict (prevents CSRF)
#
# Set-Cookie: session_id=abc123; Secure; HttpOnly; SameSite=Lax; Path=/
#
# Consult your framework docs for the correct API.
SNIPPET
    ;;
esac

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Add the cookie configuration above to $FILE"
echo "  2. Verify HTTPS is enabled (Secure flag requires it)"
echo "  3. Test login/session flow — ensure cookies still work"
echo "  4. Re-scan: zap-baseline.py -t http://localhost:PORT -J zap-results.json"
echo "  5. Commit: git commit -m 'security: add Secure/HttpOnly/SameSite cookie flags (ZAP 10010/10054/10029)'"
echo ""
