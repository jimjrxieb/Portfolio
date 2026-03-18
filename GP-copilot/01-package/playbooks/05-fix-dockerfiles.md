# Playbook: Fix Dockerfiles

> Remediate Hadolint, Trivy, and Checkov findings in Dockerfiles.
>
> **When:** After baseline scan shows Dockerfile findings (DL-codes, DS-codes, CKV_DOCKER)
> **Time:** ~10 min per Dockerfile

---

## Step 1: Identify Findings

```bash
# From the remediation plan
grep -A3 "DL[0-9]\|DS[0-9]\|CKV_DOCKER" <scan-output>/REMEDIATION-PLAN.md

# Or from raw Hadolint output
jq -r '.[] | "\(.code) \(.level) \(.file):\(.line) \(.message)"' <scan-output>/hadolint-*.json
```

---

## Step 2: Fix by Error Code

### Add Non-Root User — DL3002, DS002, CKV_DOCKER_2

The #1 Dockerfile finding. Running as root in a container = the container can modify anything on the host if it escapes.

```bash
# Usage: bash add-nonroot-user.sh <Dockerfile-path> [uid]
bash fixers/dockerfile/add-nonroot-user.sh api/Dockerfile
bash fixers/dockerfile/add-nonroot-user.sh services/worker/Dockerfile 10002
```

**What gets added (before CMD/ENTRYPOINT):**
```dockerfile
RUN groupadd -r appgroup && useradd -r -g appgroup -u 10001 appuser
USER 10001
```

### Add HEALTHCHECK — DS026, CKV_DOCKER_3

No HEALTHCHECK means Docker/K8s can't tell if your app is actually working.

```bash
# Usage: bash add-healthcheck.sh <Dockerfile-path>
bash fixers/dockerfile/add-healthcheck.sh api/Dockerfile
```

**What gets added:**
```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
```

The script auto-detects the likely port from EXPOSE directives. Review and adjust the health endpoint.

### Fix CMD Format — DL3025

Shell form CMD is fragile — JSON form is correct.

```bash
# Usage: bash fix-cmd-format.sh <Dockerfile-path>
bash fixers/dockerfile/fix-cmd-format.sh api/Dockerfile
```

**What changes:**
```dockerfile
# Before (shell form — PID 1 is /bin/sh, not your app)
CMD python app.py

# After (exec form — PID 1 is python directly)
CMD ["python", "app.py"]
```

### Fix MAINTAINER — DL4000

`MAINTAINER` is deprecated. Use `LABEL` instead.

```bash
# Usage: bash fix-maintainer.sh <Dockerfile-path>
bash fixers/dockerfile/fix-maintainer.sh api/Dockerfile
```

### Fix WORKDIR — DL3003

Using `cd` instead of `WORKDIR`.

```bash
# Usage: bash fix-workdir.sh <Dockerfile-path>
bash fixers/dockerfile/fix-workdir.sh api/Dockerfile
```

### Fix Shell Quotes — SC2086

Unquoted variables in RUN commands.

```bash
# Usage: bash fix-shell-quotes.sh <Dockerfile-path>
bash fixers/dockerfile/fix-shell-quotes.sh api/Dockerfile
```

---

## Step 3: Manual Findings

| Code | Issue | What to Do |
|------|-------|-----------|
| DL3006 | Always tag image version | Change `FROM python` to `FROM python:3.12-slim` |
| DL3007 | Using `:latest` tag | Pin to a specific version tag |
| DL3008 | Pin apt package versions | Add `=<version>` to `apt-get install` packages |
| DL3013 | Pin pip packages | Use `==<version>` in requirements.txt |

These are manual because the correct version depends on the project's requirements.

---

## Step 4: Verify

```bash
# Re-run Hadolint on fixed Dockerfiles
hadolint api/Dockerfile
hadolint services/worker/Dockerfile

# Re-run Checkov for Dockerfile checks
checkov -f api/Dockerfile --check CKV_DOCKER_2,CKV_DOCKER_3

# Build and test the image
docker build -t test-image api/
docker run --rm test-image whoami
# Expected: appuser (not root)
```

---

## Step 5: Commit

```bash
git add **/Dockerfile
git commit -m "security: harden Dockerfiles (non-root, healthcheck, exec form CMD)"
```

---

## What Good Looks Like

A hardened Dockerfile has all of these:

```dockerfile
FROM python:3.12-slim@sha256:abc123...    # Pinned image with digest
WORKDIR /app                               # WORKDIR not cd
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN groupadd -r app && useradd -r -g app -u 10001 app
USER 10001                                 # Non-root
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s \  # Health check present
  CMD curl -f http://localhost:8080/health || exit 1
CMD ["python", "app.py"]                   # Exec form
```

---

## Next Steps

- Web/DAST findings? → [06-fix-web-security.md](06-fix-web-security.md)
- CI pipeline setup? → [07-deploy-ci-pipeline.md](07-deploy-ci-pipeline.md)
- Ready to rescan? → [09-post-fix-rescan.md](09-post-fix-rescan.md)

---

*Ghost Protocol — Pre-Deployment Security Package*
