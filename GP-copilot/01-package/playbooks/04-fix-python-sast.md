# Playbook: Fix Python SAST Findings

> Remediate Bandit and Semgrep findings in Python code.
>
> **When:** After baseline scan shows Python SAST findings (Bandit B-codes, Semgrep rules)
> **Time:** ~20 min per repo (most have fixer scripts, some need manual review)

---

## Step 1: Identify Findings

```bash
# From the remediation plan
grep -A3 "B[0-9]\{3\}\|python\.lang\.security" <scan-output>/REMEDIATION-PLAN.md

# Or from raw Bandit output — HIGH and MEDIUM severity
jq -r '.results[] | select(.issue_severity=="HIGH" or .issue_severity=="MEDIUM") | "\(.test_id) \(.issue_severity) \(.filename):\(.line_number) \(.issue_text)"' \
  <scan-output>/bandit.json
```

---

## Step 2: Fix by Error Code

Work through findings top to bottom. Each error code has a dedicated fixer.

### Weak Hashing — B303, B324

MD5/SHA1 used for security purposes.

```bash
# Usage: python3 fix-md5.py <python-file>
python3 fixers/python/fix-md5.py src/auth.py
python3 fixers/python/fix-md5.py src/utils.py
```

**What changes:**
```python
# Before
import hashlib
token = hashlib.md5(data.encode()).hexdigest()

# After
import hashlib
token = hashlib.sha256(data.encode()).hexdigest()
```

### Shell Injection — B602, B603

`subprocess` with `shell=True` or unsanitized input.

```bash
# Usage: bash fix-shell-injection.sh <python-file>
bash fixers/python/fix-shell-injection.sh src/runner.py
bash fixers/python/fix-shell-injection.sh src/deploy.py
```

**What changes:**
```python
# Before (B602 — shell=True with variable)
subprocess.call(f"git clone {repo_url}", shell=True)

# After (safe — list form, no shell)
subprocess.call(["git", "clone", repo_url])
```

### Weak Random — B311

`random.random()` used where `secrets` should be.

```bash
# Usage: bash fix-weak-random.sh <python-file>
bash fixers/python/fix-weak-random.sh src/tokens.py
```

**What changes:**
```python
# Before
import random
token = ''.join(random.choice(chars) for _ in range(32))

# After
import secrets
token = secrets.token_hex(16)
```

### Unsafe exec — B102

Dynamic `exec()` call.

```bash
# Usage: bash fix-exec.sh <python-file>
bash fixers/python/fix-exec.sh src/plugins.py
```

### Pickle — B301

`pickle.loads()` on untrusted data.

```bash
# Usage: bash fix-pickle.sh <python-file>
bash fixers/python/fix-pickle.sh src/cache.py
```

**What changes:** Replaces `pickle` with `json` where possible, flags cases that need manual review.

### Unsafe YAML — B506

`yaml.load()` without safe Loader.

```bash
# Usage: bash fix-yaml-load.sh <python-file>
bash fixers/python/fix-yaml-load.sh src/config.py
```

**What changes:**
```python
# Before
data = yaml.load(f.read())

# After
data = yaml.safe_load(f.read())
```

### Unsafe XML — B314

`xml.etree.ElementTree` (vulnerable to XXE).

```bash
# Usage: bash fix-defusedxml.sh <python-file>
bash fixers/python/fix-defusedxml.sh src/parser.py
```

**What changes:**
```python
# Before
import xml.etree.ElementTree as ET

# After
import defusedxml.ElementTree as ET
```

Note: Requires `defusedxml` package. Add to requirements: `defusedxml==0.7.1`

---

## Step 3: Manual Findings

These don't have automated fixers — they need human judgment:

| Code | Issue | What to Do |
|------|-------|-----------|
| B501 | SSL with bad version | Enforce TLS 1.2+ in all SSL contexts |
| B608 | SQL injection | Rewrite to use parameterized queries (`cursor.execute("SELECT * FROM t WHERE id = %s", (id,))`) |

---

## Step 4: Verify

```bash
# Re-run Bandit on fixed files
bandit -r src/ -f json 2>/dev/null | jq '[.results[] | select(.issue_severity=="HIGH")] | length'
# Expected: 0

# Re-run Semgrep
semgrep --config p/security-audit --config p/python src/ --json 2>/dev/null | jq '.results | length'
# Expected: significantly reduced
```

---

## Step 5: Run Tests

```bash
pytest tests/
```

SAST fixes change code behavior (e.g., sha256 produces different hashes than md5). If tests compare hash values, they'll need updating.

---

## Step 6: Commit

```bash
git add src/
git commit -m "security: fix Python SAST findings (Bandit/Semgrep)"
```

---

## Next Steps

- Dockerfile issues? → [05-fix-dockerfiles.md](05-fix-dockerfiles.md)
- Web/DAST findings? → [06-fix-web-security.md](06-fix-web-security.md)
- Ready to rescan? → [09-post-fix-rescan.md](09-post-fix-rescan.md)

---

*Ghost Protocol — Pre-Deployment Security Package*
