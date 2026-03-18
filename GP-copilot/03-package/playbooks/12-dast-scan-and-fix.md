# Playbook: DAST Scan and Remediation

> Run dynamic application security testing against the live app in-cluster.
> The app is deployed — now hit it from outside and see what's actually exposed.
>
> **When:** After ArgoCD deploys the app (post playbook 03). Before going live.
> **Time:** ~20 min scan + ~30 min for infrastructure fixes
> **Requires:** App running in-cluster with a reachable Service or Ingress/Gateway

---

## Why This Is in 03, Not 01

| Package | App State | What You Can Test |
|---------|-----------|-------------------|
| 01-APP-SEC | Code in CI/CD, not deployed | Source code patterns (SAST), dependencies (SCA), secrets, Dockerfiles |
| 03-DEPLOY-RUNTIME | App running in-cluster | Actual HTTP responses, headers, cookies, TLS, exposed endpoints (DAST) |

DAST needs a live target. You can't test HTTP headers on code that isn't serving HTTP yet.

---

## DAST Tools

| Tool | What It Does | Speed | Depth |
|------|-------------|-------|-------|
| **ZAP Baseline** | Passive scan — checks headers, cookies, info disclosure | Fast (~2 min) | Surface |
| **ZAP Full** | Active scan — tests for XSS, SQLi, SSRF, path traversal | Slow (~30 min+) | Deep |
| **Nuclei** | Template-based — misconfigs, exposures, known CVEs, tech detection | Fast (~5 min) | Targeted |
| **curl + manual** | Spot-check specific endpoints, TLS config, response headers | Instant | Precise |

**Recommended order:** curl spot-check → ZAP baseline → Nuclei → ZAP full (if time allows)

---

## Step 1: Get the Target URL

The app is running in-cluster. Figure out how to reach it.

```bash
PKG=~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME

# Option A: Service with port-forward (no Ingress/Gateway)
kubectl port-forward -n anthra svc/novasec-api 8080:8080 &
TARGET="http://localhost:8080"

# Option B: Gateway API / Envoy
TARGET=$(kubectl get gateway -n anthra -o jsonpath='{.items[0].status.addresses[0].value}' 2>/dev/null)
TARGET="http://${TARGET}"

# Option C: Ingress
TARGET=$(kubectl get ingress -n anthra -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null)
TARGET="https://${TARGET}"

# Option D: LoadBalancer
TARGET=$(kubectl get svc -n anthra -l app=novasec-api -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null)
TARGET="http://${TARGET}:8080"

# Verify it's reachable
curl -sI "$TARGET" | head -10
```

---

## Step 2: Spot-Check with curl

Before running a full scanner, check the basics manually. This takes 30 seconds and catches the most common issues.

```bash
# Check response headers
curl -sI "$TARGET" | grep -iE "x-frame|x-content|strict-transport|content-security|server|x-powered"

# Check cookie flags
curl -sI "$TARGET/login" 2>/dev/null | grep -i set-cookie

# Check CORS
curl -sI -H "Origin: https://evil.com" "$TARGET" | grep -i access-control

# Check TLS (if HTTPS)
curl -svI "$TARGET" 2>&1 | grep -E "SSL connection|subject:|expire"

# Check for common exposed paths
for path in /healthz /metrics /debug /swagger /api-docs /.env /admin /actuator; do
    CODE=$(curl -so /dev/null -w "%{http_code}" "$TARGET$path" 2>/dev/null)
    [[ "$CODE" != "404" && "$CODE" != "000" ]] && echo "$CODE $path"
done
```

### Quick Audit Checklist

```
[ ] Security headers present (CSP, X-Frame, HSTS, X-Content-Type)
[ ] Server version NOT disclosed (no "Server: nginx/1.25.3")
[ ] Cookies have Secure, HttpOnly, SameSite flags
[ ] CORS not set to * (or absent if not needed)
[ ] /metrics, /debug, /actuator return 404 or 403 from outside
[ ] /swagger, /api-docs gated behind auth (or 404)
[ ] .env, .git, backup files return 404
[ ] TLS 1.2+ only, no expired certs
[ ] Error pages don't leak stack traces
```

---

## Step 3: ZAP Baseline Scan (Passive)

Passive scan only — checks what the server sends back, doesn't try to exploit anything. Safe to run against production.

```bash
REPORT_DIR=~/GP-copilot/GP-S3/5-consulting-reports/01-instance/slot-3/dast-$(date +%Y%m%d)
mkdir -p "$REPORT_DIR"

# ZAP baseline — passive scan
docker run --rm --network host \
    -v "$REPORT_DIR":/zap/wrk:rw \
    ghcr.io/zaproxy/zaproxy:stable \
    zap-baseline.py \
        -t "$TARGET" \
        -J zap-baseline.json \
        -r zap-baseline.html \
        -w zap-baseline.md \
        -l WARN

# View summary
echo "=== ZAP Baseline Findings ==="
python3 -c "
import json
with open('$REPORT_DIR/zap-baseline.json') as f:
    data = json.load(f)
for site in data.get('site', []):
    for alert in site.get('alerts', []):
        risk = alert.get('riskdesc', '').split(' ')[0]
        code = alert.get('alertRef', 'N/A')
        name = alert.get('name', '')
        count = alert.get('count', 0)
        print(f'  {risk:8s}  [{code}] {name} ({count} instances)')
"
```

---

## Step 4: Nuclei Scan (Template-Based)

Targeted checks for misconfigs, exposures, and known CVEs. Faster and more precise than ZAP for infrastructure issues.

```bash
# Nuclei — misconfigs, exposures, tech detection
nuclei -u "$TARGET" \
    -tags misconfig,exposure,tech \
    -severity medium,high,critical \
    -silent \
    -jsonl -o "$REPORT_DIR/nuclei.jsonl"

# Summary
echo "=== Nuclei Findings ==="
cat "$REPORT_DIR/nuclei.jsonl" | python3 -c "
import sys, json
findings = [json.loads(l) for l in sys.stdin if l.strip()]
for f in sorted(findings, key=lambda x: {'critical':0,'high':1,'medium':2,'low':3}.get(x.get('info',{}).get('severity','low'), 4)):
    sev = f.get('info', {}).get('severity', 'unknown').upper()
    tid = f.get('template-id', 'N/A')
    name = f.get('info', {}).get('name', '')
    matched = f.get('matched-at', '')
    print(f'  {sev:8s}  [{tid}] {name}')
    print(f'           {matched}')
"

# Kubernetes-specific templates (if available)
nuclei -u "$TARGET" \
    -tags kubernetes,k8s,cloud \
    -severity low,medium,high,critical \
    -silent \
    -jsonl >> "$REPORT_DIR/nuclei.jsonl"
```

---

## Step 5: ZAP Full Scan (Active — Optional)

Active scanning — ZAP attempts XSS, SQLi, path traversal, etc. **Do NOT run against production.** Staging/dev only.

```bash
# ZAP full scan — ACTIVE (staging only)
docker run --rm --network host \
    -v "$REPORT_DIR":/zap/wrk:rw \
    ghcr.io/zaproxy/zaproxy:stable \
    zap-full-scan.py \
        -t "$TARGET" \
        -J zap-full.json \
        -r zap-full.html \
        -m 30 \
        -l WARN
```

---

## Step 6: Kubernetes-Specific DAST Checks

Things that DAST tools don't check but matter when the app runs in K8s.

### 6a. Exposed Kubernetes Metadata

```bash
# Can the app reach the metadata API? (should be blocked by NetworkPolicy)
kubectl run dast-probe --rm -it --restart=Never \
    --image=curlimages/curl:latest \
    --namespace anthra \
    -- curl -s --connect-timeout 3 http://169.254.169.254/latest/meta-data/
# Expected: timeout or connection refused (blocked by netpol/IMDS hop limit)

# Check if ServiceAccount token is mounted and accessible
kubectl run dast-probe --rm -it --restart=Never \
    --image=curlimages/curl:latest \
    --namespace anthra \
    --overrides='{"spec":{"automountServiceAccountToken":true}}' \
    -- sh -c 'cat /var/run/secrets/kubernetes.io/serviceaccount/token | head -c 50 && echo'
# If this works, automountServiceAccountToken should be false
```

### 6b. Service-to-Service Access (Lateral Movement)

```bash
# Can the API pod reach the DB directly? (should be allowed)
kubectl exec -n anthra deploy/novasec-api -- \
    curl -s --connect-timeout 3 novasec-db:5432 2>&1 | head -1

# Can the UI pod reach the DB? (should be BLOCKED by NetworkPolicy)
kubectl exec -n anthra deploy/novasec-ui -- \
    curl -s --connect-timeout 3 novasec-db:5432 2>&1 | head -1
# Expected: timeout (blocked)

# Can the app reach external internet? (depends on egress policy)
kubectl exec -n anthra deploy/novasec-api -- \
    curl -s --connect-timeout 3 https://httpbin.org/ip 2>&1 | head -1
```

### 6c. mTLS Verification (If Service Mesh Deployed)

```bash
# Is traffic between services encrypted?
# With Istio:
istioctl authn tls-check novasec-api.anthra novasec-db.anthra

# With Cilium:
kubectl get ciliumnetworkpolicy -n anthra -o yaml | grep -A5 "encryption"

# Manual: capture traffic and verify it's not plaintext
kubectl exec -n anthra deploy/novasec-api -- \
    curl -v http://novasec-db:5432 2>&1 | grep -i "SSL\|TLS"
```

### 6d. Gateway/Ingress Misconfiguration

```bash
# Check for path traversal via gateway
curl -s "$TARGET/../../../etc/passwd"
curl -s "$TARGET/..%2f..%2f..%2fetc/passwd"

# Check for host header injection
curl -sI -H "Host: evil.com" "$TARGET"

# Check for HTTP smuggling (basic)
curl -s -H "Transfer-Encoding: chunked" -H "Content-Length: 0" "$TARGET"

# Check for open redirects
curl -sI "$TARGET/redirect?url=https://evil.com" 2>/dev/null | grep -i location
```

---

## Step 7: Remediation

### Severity Tiers

| Tier | Findings | Fix Method | Time |
|------|----------|-----------|------|
| **D-rank (auto)** | Missing headers, insecure cookies, version disclosure, CORS wildcard | Fixer scripts or K8s annotations | 5 min each |
| **C-rank (guided)** | Exposed /metrics or /debug, metadata API reachable, missing mTLS | Config change + redeploy | 15 min each |
| **B-rank (manual)** | XSS, SQLi, SSRF, path traversal, host header injection | Code fix by dev team | Hours-days |

### D-Rank Fixes (Infrastructure — Automatable)

**Missing security headers** — Fix at the gateway/ingress level, not in the app:

```yaml
# Gateway API — HTTPRoute filter (preferred for K8s-native)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: novasec-api
  namespace: anthra
spec:
  parentRefs:
    - name: anthra-gateway
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      filters:
        - type: ResponseHeaderModifier
          responseHeaderModifier:
            set:
              - name: X-Frame-Options
                value: DENY
              - name: X-Content-Type-Options
                value: nosniff
              - name: Strict-Transport-Security
                value: max-age=31536000; includeSubDomains
              - name: Content-Security-Policy
                value: "default-src 'self'"
              - name: Referrer-Policy
                value: strict-origin-when-cross-origin
            remove:
              - Server
              - X-Powered-By
      backendRefs:
        - name: novasec-api
          port: 8080
```

```yaml
# Nginx Ingress — annotations
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: novasec-api
  namespace: anthra
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Frame-Options: DENY";
      more_set_headers "X-Content-Type-Options: nosniff";
      more_set_headers "Strict-Transport-Security: max-age=31536000; includeSubDomains";
      more_set_headers "Content-Security-Policy: default-src 'self'";
      more_set_headers "Referrer-Policy: strict-origin-when-cross-origin";
      more_clear_headers "Server";
      more_clear_headers "X-Powered-By";
```

```yaml
# Envoy Gateway — SecurityPolicy (for Envoy-based setups like ours)
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: security-headers
  namespace: anthra
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      name: novasec-api
```

**Insecure cookies** — Set at the app or gateway level:

```yaml
# If app sets cookies, add to deployment env vars:
env:
  - name: SESSION_COOKIE_SECURE
    value: "true"
  - name: SESSION_COOKIE_HTTPONLY
    value: "true"
  - name: SESSION_COOKIE_SAMESITE
    value: "Lax"
```

**Version disclosure** — Remove `Server` header (see header examples above) or:

```bash
# Envoy: already strips by default
# Nginx: add to ingress annotation
nginx.ingress.kubernetes.io/server-snippet: |
  server_tokens off;
```

### C-Rank Fixes (Config Changes)

**Exposed /metrics or /debug endpoints:**

```yaml
# NetworkPolicy — block external access to metrics port
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: metrics-internal-only
  namespace: anthra
spec:
  podSelector:
    matchLabels:
      app: novasec-api
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - port: 9090    # metrics port
          protocol: TCP
```

Or at the gateway level — don't route /metrics externally:

```yaml
# HTTPRoute — only expose /api, not /metrics
rules:
  - matches:
      - path:
          type: PathPrefix
          value: /api
    backendRefs:
      - name: novasec-api
        port: 8080
  # /metrics, /debug, /healthz NOT routed through gateway
```

**Metadata API reachable:**

```yaml
# NetworkPolicy — block egress to cloud metadata (169.254.169.254)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: block-metadata
  namespace: anthra
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 169.254.169.254/32
```

**ServiceAccount token mounted:**

```yaml
# Deployment — disable token mount
spec:
  template:
    spec:
      automountServiceAccountToken: false
```

### B-Rank Findings (Manual — Document for Dev Team)

Create a findings report for the development team:

```markdown
## B-Rank DAST Findings (Requires Code Changes)

| # | Finding | Severity | URL | Evidence | Recommendation |
|---|---------|----------|-----|----------|---------------|
| 1 | Reflected XSS | HIGH | /api/search?q=<script> | Parameter reflected in response without encoding | Use output encoding, enable CSP |
| 2 | SQL Injection | CRITICAL | /api/users?id=1' | Error message reveals SQL syntax | Use parameterized queries |
| 3 | Open Redirect | MEDIUM | /redirect?url=evil.com | 302 redirect to arbitrary domain | Validate redirect URLs against allowlist |
```

---

## Step 8: Rescan and Verify

```bash
# Re-run ZAP baseline after fixes
docker run --rm --network host \
    -v "$REPORT_DIR":/zap/wrk:rw \
    ghcr.io/zaproxy/zaproxy:stable \
    zap-baseline.py \
        -t "$TARGET" \
        -J zap-post-fix.json \
        -r zap-post-fix.html \
        -l WARN

# Compare before/after
echo "=== Before ==="
python3 -c "
import json
with open('$REPORT_DIR/zap-baseline.json') as f:
    alerts = sum(len(s.get('alerts',[])) for s in json.load(f).get('site',[]))
print(f'  Alert types: {alerts}')
"

echo "=== After ==="
python3 -c "
import json
with open('$REPORT_DIR/zap-post-fix.json') as f:
    alerts = sum(len(s.get('alerts',[])) for s in json.load(f).get('site',[]))
print(f'  Alert types: {alerts}')
"

# Re-run curl spot check
curl -sI "$TARGET" | grep -iE "x-frame|x-content|strict-transport|content-security|server"
```

---

## Audit Report Format

Save to `GP-S3/5-consulting-reports/<client>/dast-<date>/`:

```
dast-20260313/
├── zap-baseline.json          # Raw ZAP output
├── zap-baseline.html          # ZAP HTML report (for client)
├── nuclei.jsonl               # Raw Nuclei output
├── k8s-dast-checks.md         # K8s-specific checks (metadata, lateral, mTLS)
├── findings-summary.md        # Triage table (D/C/B rank)
└── remediation-applied.md     # What was fixed, what's pending
```

### findings-summary.md Template

```markdown
# DAST Findings Summary — <app> — <date>

**Target:** <URL>
**Namespace:** <namespace>
**Cluster:** <cluster>
**Scanners:** ZAP baseline, Nuclei (misconfig+exposure), K8s-specific checks

## Summary

| Severity | Count | Auto-fixable | Manual |
|----------|-------|-------------|--------|
| CRITICAL | 0     | 0           | 0      |
| HIGH     | 2     | 1           | 1      |
| MEDIUM   | 5     | 4           | 1      |
| LOW      | 3     | 3           | 0      |

## D-Rank (Fixed)

| Finding | Tool | Fix Applied |
|---------|------|-------------|
| Missing X-Frame-Options | ZAP 10020 | Added via HTTPRoute ResponseHeaderModifier |
| Missing HSTS | ZAP 10035 | Added via HTTPRoute ResponseHeaderModifier |
| Server version disclosed | ZAP 10036 | Removed Server header via gateway config |
| Insecure cookie flags | ZAP 10010 | Set Secure, HttpOnly, SameSite via app env vars |

## C-Rank (Fixed)

| Finding | Tool | Fix Applied |
|---------|------|-------------|
| /metrics exposed externally | Nuclei | Removed from HTTPRoute, added NetworkPolicy |

## B-Rank (Pending — Assigned to Dev Team)

| Finding | Tool | Assigned To | Deadline |
|---------|------|------------|----------|
| Reflected XSS on /search | ZAP 40012 | Dev team | <date> |
```

---

## When to Run

| Trigger | Scan Type | Against |
|---------|----------|---------|
| After first deploy (this playbook) | Full (baseline + nuclei + K8s checks) | Staging |
| After each release | ZAP baseline + nuclei | Staging |
| Weekly (cron or CI) | ZAP baseline | Staging |
| Before go-live | Full + ZAP active | Staging |
| Never | ZAP active scan | Production |

---

## Next Steps

- Operations and ongoing monitoring → [07-operations.md](07-operations.md)
- Need to harden the gateway? → [08-deploy-service-mesh.md](08-deploy-service-mesh.md)
- Back to engagement overview → [../ENGAGEMENT-GUIDE.md](../ENGAGEMENT-GUIDE.md)

---

*Ghost Protocol — Runtime Security Package (CKS/CNPE)*
