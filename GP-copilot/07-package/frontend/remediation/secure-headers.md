# Secure HTTP Headers — FedRAMP SC-7, SC-8

## The Problem

Missing security headers expose the frontend to clickjacking, XSS, MIME-sniffing,
and data leakage attacks. FedRAMP auditors check for these on every web endpoint.

## Required Headers

| Header | Value | Why |
|--------|-------|-----|
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | Force HTTPS |
| `Content-Security-Policy` | App-specific (see below) | Prevent XSS |
| `X-Content-Type-Options` | `nosniff` | Prevent MIME confusion |
| `X-Frame-Options` | `DENY` | Prevent clickjacking |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Limit referrer leakage |
| `Permissions-Policy` | `camera=(), geolocation=(), microphone=()` | Disable unused APIs |

## Fix: Python (Flask)

```python
from flask import Flask

app = Flask(__name__)

@app.after_request
def set_security_headers(response):
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; "
        "script-src 'self'; "
        "style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data:; "
        "font-src 'self'; "
        "connect-src 'self'; "
        "frame-ancestors 'none'; "
        "base-uri 'self'; "
        "form-action 'self'"
    )
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), geolocation=(), microphone=()"
    return response
```

## Fix: Python (FastAPI)

```python
from fastapi import FastAPI
from starlette.middleware.base import BaseHTTPMiddleware

class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "camera=(), geolocation=(), microphone=()"
        # CSP should be tuned per app — start restrictive
        response.headers["Content-Security-Policy"] = "default-src 'self'; frame-ancestors 'none'"
        return response

app = FastAPI()
app.add_middleware(SecurityHeadersMiddleware)
```

## Fix: Node.js (Express)

```javascript
const helmet = require("helmet"); // helmet@7.1.0

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:"],
      frameAncestors: ["'none'"],
    },
  },
  strictTransportSecurity: { maxAge: 31536000, includeSubDomains: true },
  referrerPolicy: { policy: "strict-origin-when-cross-origin" },
}));
```

## Fix: Nginx (Reverse Proxy / Ingress)

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), geolocation=(), microphone=()" always;
add_header Content-Security-Policy "default-src 'self'; frame-ancestors 'none'" always;
```

## Fix: Secure Cookie Flags

```python
# Flask
app.config["SESSION_COOKIE_SECURE"] = True      # HTTPS only
app.config["SESSION_COOKIE_HTTPONLY"] = True      # No JS access
app.config["SESSION_COOKIE_SAMESITE"] = "Strict"  # CSRF protection
```

```javascript
// Express
app.use(session({
  cookie: {
    secure: true,      // HTTPS only
    httpOnly: true,     // No JS access
    sameSite: "strict", // CSRF protection
    maxAge: 900000,     // 15 min
  },
}));
```

## Fix: CORS Configuration

```python
# NEVER do this in production:
# CORS(app, origins="*")

# Do this:
ALLOWED_ORIGINS = [
    "https://app.client.com",
    "https://admin.client.com",
]

from flask_cors import CORS
CORS(app, origins=ALLOWED_ORIGINS, supports_credentials=True)
```

## Verification

```bash
# Check headers on a live endpoint
curl -sI https://app.client.com | grep -iE '(strict-transport|content-security|x-content|x-frame|referrer|permissions)'
```

## Remediation Priority: D — Auto-Remediate

Header configuration is pattern-based — auto-fixable by automated tooling.
