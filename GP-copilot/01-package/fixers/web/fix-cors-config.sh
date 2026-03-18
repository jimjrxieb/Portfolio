#!/usr/bin/env bash
# fix-cors-config.sh
# Replace wildcard CORS with explicit origin allowlist.
#
# Usage:
#   bash fix-cors-config.sh <file> [framework]
#
# Error codes:
#   ZAP 90033 (Loosely scoped CORS policy / Access-Control-Allow-Origin: *)
#   Semgrep javascript.browser.security.wildcard-cors
#   Semgrep python.flask.security.wildcard-cors
#
# What it does:
#   - Auto-detects the framework from file content
#   - Identifies wildcard CORS patterns (Allow-Origin: *)
#   - Prints framework-specific CORS config with explicit origins
#   - Creates .bak backup

set -euo pipefail

FILE="${1:-}"
FRAMEWORK="${2:-auto}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: bash fix-cors-config.sh <file> [framework]"
  echo ""
  echo "Frameworks: flask, express, django, fastapi, spring, nginx, apache, auto"
  echo ""
  echo "Examples:"
  echo "  bash fix-cors-config.sh app.py flask"
  echo "  bash fix-cors-config.sh server.js express"
  echo "  bash fix-cors-config.sh nginx.conf nginx"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Ghost Protocol — CORS Configuration ===${NC}"
echo "  File      : $FILE"
echo "  Framework : $FRAMEWORK"
echo ""

# Auto-detect framework
if [[ "$FRAMEWORK" == "auto" ]]; then
  CONTENT=$(cat "$FILE")
  if echo "$CONTENT" | grep -qE "from flask|import Flask|flask_cors|CORS"; then
    FRAMEWORK="flask"
  elif echo "$CONTENT" | grep -qE "from fastapi|import FastAPI|CORSMiddleware"; then
    FRAMEWORK="fastapi"
  elif echo "$CONTENT" | grep -qE "from django|CORS_ALLOW|django-cors"; then
    FRAMEWORK="django"
  elif echo "$CONTENT" | grep -qE "require\(['\"]express['\"]|require\(['\"]cors['\"]|from ['\"]express['\"]"; then
    FRAMEWORK="express"
  elif echo "$CONTENT" | grep -qE "@SpringBoot|@CrossOrigin|import org.springframework"; then
    FRAMEWORK="spring"
  elif echo "$CONTENT" | grep -qE "server\s*\{|location\s*/|add_header.*Access-Control"; then
    FRAMEWORK="nginx"
  elif echo "$CONTENT" | grep -qE "<VirtualHost|Header set.*Access-Control"; then
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

# Check for wildcard CORS
echo "Checking current CORS configuration..."
WILDCARD_LINES=$(grep -n "Allow-Origin.*\*\|origins.*\*\|allow_all_origins\|CORS_ORIGIN_ALLOW_ALL" "$FILE" 2>/dev/null || true)
if [[ -n "$WILDCARD_LINES" ]]; then
  echo -e "  ${RED}✗ Wildcard CORS detected:${NC}"
  echo "$WILDCARD_LINES" | while IFS= read -r line; do
    echo -e "    ${RED}$line${NC}"
  done
else
  echo -e "  ${YELLOW}⚠ No obvious wildcard pattern found — review CORS config manually${NC}"
fi
echo ""

echo -e "${GREEN}Replace wildcard CORS with explicit origins:${NC}"
echo ""
echo -e "${YELLOW}NOTE: Replace https://app.example.com with your actual frontend origin(s).${NC}"
echo ""

case "$FRAMEWORK" in
  flask)
    cat <<'SNIPPET'
# --- CORS Configuration (Flask-CORS) ---
# pip install flask-cors

from flask_cors import CORS

# BEFORE (insecure):
# CORS(app)  # allows all origins
# CORS(app, origins="*")

# AFTER (secure):
CORS(app, origins=[
    "https://app.example.com",
    "https://staging.example.com",
])

# Or per-route:
# @cross_origin(origins=["https://app.example.com"])
SNIPPET
    ;;

  fastapi)
    cat <<'SNIPPET'
# --- CORS Configuration (FastAPI) ---

from fastapi.middleware.cors import CORSMiddleware

# BEFORE (insecure):
# app.add_middleware(CORSMiddleware, allow_origins=["*"])

# AFTER (secure):
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://app.example.com",
        "https://staging.example.com",
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)
SNIPPET
    ;;

  django)
    cat <<'SNIPPET'
# --- CORS Configuration (django-cors-headers) ---
# pip install django-cors-headers
# Add 'corsheaders' to INSTALLED_APPS
# Add 'corsheaders.middleware.CorsMiddleware' to MIDDLEWARE (before CommonMiddleware)

# BEFORE (insecure):
# CORS_ORIGIN_ALLOW_ALL = True
# CORS_ALLOW_ALL_ORIGINS = True

# AFTER (secure):
CORS_ORIGIN_ALLOW_ALL = False
CORS_ALLOWED_ORIGINS = [
    "https://app.example.com",
    "https://staging.example.com",
]

# Optional: regex for subdomains
# CORS_ALLOWED_ORIGIN_REGEXES = [
#     r"^https://\w+\.example\.com$",
# ]

CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_METHODS = ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
CORS_ALLOW_HEADERS = ['Authorization', 'Content-Type']
SNIPPET
    ;;

  express)
    cat <<'SNIPPET'
// --- CORS Configuration (Express) ---
// npm install cors

const cors = require('cors');

// BEFORE (insecure):
// app.use(cors());  // allows all origins
// app.use(cors({ origin: '*' }));

// AFTER (secure):
app.use(cors({
  origin: [
    'https://app.example.com',
    'https://staging.example.com',
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Authorization', 'Content-Type'],
}));
SNIPPET
    ;;

  spring)
    cat <<'SNIPPET'
// --- CORS Configuration (Spring Boot) ---

import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class CorsConfig implements WebMvcConfigurer {
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        // BEFORE (insecure):
        // registry.addMapping("/**").allowedOrigins("*");

        // AFTER (secure):
        registry.addMapping("/api/**")
            .allowedOrigins(
                "https://app.example.com",
                "https://staging.example.com"
            )
            .allowedMethods("GET", "POST", "PUT", "DELETE")
            .allowedHeaders("Authorization", "Content-Type")
            .allowCredentials(true);
    }
}
SNIPPET
    ;;

  nginx)
    cat <<'SNIPPET'
# --- CORS Configuration (Nginx) ---

# BEFORE (insecure):
# add_header Access-Control-Allow-Origin "*" always;

# AFTER (secure — origin validation):
map $http_origin $cors_origin {
    default "";
    "https://app.example.com"     $http_origin;
    "https://staging.example.com" $http_origin;
}

server {
    location /api/ {
        if ($cors_origin) {
            add_header Access-Control-Allow-Origin $cors_origin always;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Authorization, Content-Type" always;
            add_header Access-Control-Allow-Credentials "true" always;
        }

        # Handle preflight
        if ($request_method = OPTIONS) {
            add_header Access-Control-Allow-Origin $cors_origin always;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Authorization, Content-Type" always;
            add_header Content-Length 0;
            return 204;
        }
    }
}
SNIPPET
    ;;

  apache)
    cat <<'SNIPPET'
# --- CORS Configuration (Apache) ---
# Requires: a2enmod headers a2enmod rewrite

# BEFORE (insecure):
# Header set Access-Control-Allow-Origin "*"

# AFTER (secure — origin validation):
SetEnvIf Origin "^https://(app|staging)\.example\.com$" CORS_ORIGIN=$0
Header always set Access-Control-Allow-Origin %{CORS_ORIGIN}e env=CORS_ORIGIN
Header always set Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" env=CORS_ORIGIN
Header always set Access-Control-Allow-Headers "Authorization, Content-Type" env=CORS_ORIGIN
Header always set Access-Control-Allow-Credentials "true" env=CORS_ORIGIN
SNIPPET
    ;;

  *)
    cat <<'SNIPPET'
# --- CORS Configuration (generic guidance) ---
#
# NEVER use Access-Control-Allow-Origin: *
#
# Instead, validate the Origin header against an allowlist:
#   1. Read the Origin header from the request
#   2. Check if it's in your allowed origins list
#   3. If yes, echo it back as Access-Control-Allow-Origin
#   4. If no, omit the header (browser will block the request)
#
# Allowed origins should be:
#   - Your frontend domain(s) only
#   - Full URLs including scheme (https://app.example.com)
#   - Never regex patterns that are too broad
SNIPPET
    ;;
esac

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Replace the wildcard CORS config with the explicit allowlist above"
echo "  2. Update origin URLs to match your actual frontend domain(s)"
echo "  3. Test cross-origin requests from your frontend"
echo "  4. Re-scan: zap-baseline.py -t http://localhost:PORT -J zap-results.json"
echo "  5. Commit: git commit -m 'security: restrict CORS to explicit origins (ZAP 90033)'"
echo ""
