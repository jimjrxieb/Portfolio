# Input Validation & Injection Prevention — FedRAMP RA-5, SI-2

## The Problem

Unvalidated user input leads to SQL injection, XSS, command injection, and path traversal.
FedRAMP Moderate requires all these to be addressed (RA-5 vulnerability scanning, SI-2 flaw remediation).

## Fix: SQL Injection (CWE-89)

**NEVER** concatenate user input into SQL:

```python
# BAD — SQL injection
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")
cursor.execute("SELECT * FROM users WHERE id = " + user_id)

# GOOD — parameterized query
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
```

**SQLAlchemy:**
```python
# BAD
db.execute(text(f"SELECT * FROM users WHERE name = '{name}'"))

# GOOD
db.execute(text("SELECT * FROM users WHERE name = :name"), {"name": name})
```

**Node.js (pg):**
```javascript
// BAD
client.query(`SELECT * FROM users WHERE id = ${userId}`);

// GOOD
client.query("SELECT * FROM users WHERE id = $1", [userId]);
```

## Fix: Cross-Site Scripting / XSS (CWE-79)

**Python (Jinja2 — Flask/Django):**
```python
# Jinja2 auto-escapes by default in Flask. Verify it's not disabled:
app.jinja_env.autoescape = True  # Should be True

# NEVER use |safe or Markup() with user input
# BAD
return render_template("page.html", content=Markup(user_input))

# GOOD — let Jinja2 auto-escape
return render_template("page.html", content=user_input)
```

**React (JSX auto-escapes by default):**
```jsx
// BAD — dangerouslySetInnerHTML with user data
<div dangerouslySetInnerHTML={{__html: userData}} />

// GOOD — React auto-escapes
<div>{userData}</div>
```

**Manual escaping (when needed):**
```python
from markupsafe import escape
safe_output = escape(user_input)
```

## Fix: Command Injection (CWE-78)

```python
import subprocess

# BAD — shell=True with user input
subprocess.run(f"grep {user_input} /var/log/app.log", shell=True)

# GOOD — argument list, no shell
subprocess.run(["grep", user_input, "/var/log/app.log"], check=True)

# GOOD — if you need shell features, validate input first
import re
if not re.match(r'^[a-zA-Z0-9_-]+$', user_input):
    raise ValueError("Invalid input")
```

## Fix: Path Traversal (CWE-22)

```python
import os

# BAD — user controls file path
path = os.path.join("/uploads", user_filename)

# GOOD — resolve and validate
UPLOAD_DIR = os.path.realpath("/uploads")
requested = os.path.realpath(os.path.join(UPLOAD_DIR, user_filename))
if not requested.startswith(UPLOAD_DIR):
    raise ValueError("Path traversal attempt")
```

## Fix: CSRF Protection (CWE-352)

**Flask:**
```python
from flask_wtf.csrf import CSRFProtect

csrf = CSRFProtect(app)
# All POST/PUT/DELETE forms require {{ csrf_token() }}
```

**Django (built-in):**
```python
# Ensure middleware is active (default)
MIDDLEWARE = [
    "django.middleware.csrf.CsrfViewMiddleware",
]
# Templates: {% csrf_token %} in every form
```

**SPA / API pattern:**
```python
# Send CSRF token in response header, client sends back in X-CSRF-Token
# Verify on server side for all state-changing requests
```

## Fix: File Upload Validation

```python
ALLOWED_EXTENSIONS = {".pdf", ".png", ".jpg", ".csv"}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB

def validate_upload(file):
    # Check extension
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise ValueError(f"File type {ext} not allowed")

    # Check size
    file.seek(0, 2)
    size = file.tell()
    file.seek(0)
    if size > MAX_FILE_SIZE:
        raise ValueError("File too large")

    # Check magic bytes (don't trust extension alone)
    header = file.read(8)
    file.seek(0)
    if ext == ".pdf" and not header.startswith(b"%PDF"):
        raise ValueError("File content doesn't match extension")
```

## Fix: Open Redirect (CWE-601)

```python
from urllib.parse import urlparse

ALLOWED_HOSTS = {"app.client.com", "admin.client.com"}

def safe_redirect(url):
    parsed = urlparse(url)
    if parsed.netloc and parsed.netloc not in ALLOWED_HOSTS:
        raise ValueError("Redirect to untrusted host")
    if parsed.scheme and parsed.scheme not in ("https",):
        raise ValueError("Non-HTTPS redirect")
    return url
```

## Detection

```bash
# Semgrep scan for injection patterns
semgrep scan --config ../scanning-configs/semgrep-fedramp.yaml /path/to/app

# Additional rules for Python
semgrep scan --config "p/python" --severity ERROR /path/to/app

# Additional rules for JavaScript
semgrep scan --config "p/javascript" --severity ERROR /path/to/app
```

## Remediation Priority: C — Security Review

Injection fixes require context understanding — security review required, may need human approval
for complex cases (e.g., stored XSS in rich text editors).
