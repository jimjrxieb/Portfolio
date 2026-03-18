# Playbook: Fix Web Security (DAST Findings)

> Remediate ZAP and Nuclei findings — missing headers, insecure cookies, CORS misconfig.
>
> **When:** After DAST scan shows web infrastructure findings (ZAP alert codes, Nuclei templates)
> **Time:** ~15 min for infrastructure fixes (headers/cookies). Application-level findings (XSS, SQLi) are B-rank manual.

---

## DAST vs SAST — Know the Difference

SAST (Semgrep, Bandit) reads code. DAST (ZAP, Nuclei) hits the running app from outside. DAST finds what's actually exposed to attackers — missing headers, insecure cookies, open endpoints.

**D-rank (automatable):** Missing security headers, insecure cookie flags, CORS wildcard — these are infrastructure-level and have fixer scripts.

**B-rank (manual):** XSS, SQL injection, SSRF — these require understanding the application logic. No fixer script. Human reviews and fixes.

---

## Step 1: Identify Findings

```bash
# From the remediation plan
grep -A3 "ZAP\|nuclei\|10038\|10020\|10021\|10035\|10010\|90033" <scan-output>/REMEDIATION-PLAN.md

# Or from raw ZAP output
jq -r '.site[].alerts[] | "\(.alertRef) \(.risk) \(.name) (\(.count) instances)"' <scan-output>/zap-results.json

# From Nuclei
cat <scan-output>/nuclei.jsonl | jq -r '"\(.info.severity) \(.templateID) \(.matched-at)"'
```

---

## Step 2: Fix Missing Security Headers

Most web frameworks need 5 security headers. One script handles all of them.

```bash
# Usage: bash add-security-headers.sh <file> [framework]
# Frameworks: flask, express, django, fastapi, spring, nginx, apache, auto

# Flask
bash fixers/web/add-security-headers.sh app.py flask

# Express
bash fixers/web/add-security-headers.sh server.js express

# FastAPI
bash fixers/web/add-security-headers.sh main.py fastapi

# Nginx config
bash fixers/web/add-security-headers.sh nginx.conf nginx

# Auto-detect from file content
bash fixers/web/add-security-headers.sh app.py
```

**What gets added:**

| Header | What It Prevents | ZAP Code |
|--------|-----------------|----------|
| `Content-Security-Policy` | XSS, injection | 10038 |
| `X-Frame-Options: DENY` | Clickjacking | 10020 |
| `X-Content-Type-Options: nosniff` | MIME sniffing | 10021 |
| `Strict-Transport-Security` | HTTP downgrade | 10035 |
| `Server` (removed/hidden) | Version disclosure | 10036 |

---

## Step 3: Fix Insecure Cookies

```bash
# Usage: bash fix-cookie-flags.sh <file> [framework]
bash fixers/web/fix-cookie-flags.sh app.py flask
bash fixers/web/fix-cookie-flags.sh server.js express
```

**What changes:**

| Flag | What It Prevents | ZAP Code |
|------|-----------------|----------|
| `Secure` | Cookie sent over HTTP | 10010 |
| `HttpOnly` | JavaScript access to cookie | 10054 |
| `SameSite=Lax` | CSRF attacks | 10029 |

**Example (Flask):**
```python
# Before
response.set_cookie("session", token)

# After
response.set_cookie("session", token, secure=True, httponly=True, samesite="Lax")
```

---

## Step 4: Fix CORS Wildcard

```bash
# Usage: bash fix-cors-config.sh <file> [framework]
bash fixers/web/fix-cors-config.sh app.py flask
bash fixers/web/fix-cors-config.sh server.js express
```

**What changes:**
```python
# Before (ZAP 90033 — allows any origin)
CORS(app, origins="*")

# After (allowlist specific origins)
CORS(app, origins=["https://app.example.com", "https://staging.example.com"])
```

---

## Step 5: Manual Findings (B-Rank)

These require understanding the application code. No fixer script — document them for the development team.

| ZAP Code | Finding | What to Do |
|----------|---------|-----------|
| 40012 | Cross-Site Scripting (Reflected XSS) | Escape output, use templating engine auto-escaping |
| 40014 | Cross-Site Scripting (Persistent XSS) | Sanitize input on write, escape on read |
| 40018 | SQL Injection | Use parameterized queries, never string concatenation |
| 40043 | Server-Side Request Forgery (SSRF) | Validate/allowlist URLs, block internal ranges |

---

## Step 6: Verify

```bash
# Re-run ZAP baseline against staging
docker run --rm -v $(pwd)/outputs:/zap/wrk:rw \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t https://staging.example.com -J zap-post-fix.json

# Compare alert counts
jq '.site[].alerts | length' outputs/zap-results.json       # before
jq '.site[].alerts | length' outputs/zap-post-fix.json      # after

# Re-run Nuclei
nuclei -u https://staging.example.com -tags misconfig,exposure -silent -jsonl \
  | jq -s 'length'
```

---

## Step 7: Commit

```bash
git add app.py server.js nginx.conf
git commit -m "security: add security headers, fix cookie flags, restrict CORS"
```

---

## Next Steps

- Set up CI pipeline? → [07-deploy-ci-pipeline.md](07-deploy-ci-pipeline.md)
- Pre-commit hooks? → [08-deploy-pre-commit.md](08-deploy-pre-commit.md)
- Ready to rescan? → [09-post-fix-rescan.md](09-post-fix-rescan.md)

---

*Ghost Protocol — Pre-Deployment Security Package*
