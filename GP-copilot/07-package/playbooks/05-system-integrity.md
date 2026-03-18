# Playbook 05: System & Information Integrity + Risk Assessment
### Controls: SI-2, SI-4, SI-10, RA-5, RA-7

---

## WHAT THIS COVERS

| Control | Name | What the assessor checks |
|---------|------|------------------------|
| SI-2 | Flaw Remediation | Known vulnerabilities are identified and patched |
| SI-4 | Information System Monitoring | System is monitored for attacks and anomalies |
| SI-10 | Information Input Validation | Application validates input at system boundaries |
| RA-5 | Vulnerability Scanning | Regular vulnerability scans are performed |
| RA-7 | Risk Response | Identified risks are addressed based on severity |

---

## RA-5 + SI-2: VULNERABILITY SCANNING AND PATCHING

### What "compliant" looks like
- Automated vulnerability scanning runs on every build
- Container images are scanned before deployment
- Dependencies are scanned for known CVEs
- Critical vulnerabilities are patched within 30 days
- High vulnerabilities within 90 days

### Step 1: Scan everything

```bash
# 1. Code dependencies (SAST + SCA)
trivy fs --format json --scanners vuln,secret . > trivy-fs.json
semgrep --config auto --json -o semgrep.json .
gitleaks detect --source . --report-format json --report-path gitleaks.json

# 2. Container images
# Extract all images from K8s manifests
grep -rh "image:" k8s/ | awk '{print $2}' | sort -u | while read img; do
  safe=$(echo "$img" | tr '/:' '-')
  trivy image "$img" --format json --output "trivy-image-${safe}.json"
done

# 3. IaC misconfigurations
checkov -d . --framework terraform,kubernetes,dockerfile --output json > checkov.json

# 4. Running cluster (if live)
# Uses 02-CLUSTER-HARDENING scanners
kubescape scan --format json --output kubescape.json
kube-bench run --json > kube-bench.json
```

### Step 2: Map to NIST controls and prioritize

```bash
# Use the scan-and-map tool to auto-map findings to NIST controls
python3 /path/to/GP-CONSULTING/07-FEDRAMP-READY/tools/scan-and-map.py \
  --target . \
  --output ./evidence/scan-$(date +%Y%m%d) \
  --project "client-app"

# Output: nist-mapping-report.json with findings ranked E→S
```

### Step 3: Triage by severity and rank

| Severity | FedRAMP SLA | Iron Legion Rank | Action |
|----------|-------------|------------------|--------|
| Critical | 30 days | B-rank | Fix immediately, human review |
| High | 90 days | C-rank | Fix this sprint, JADE-assisted |
| Medium | 180 days | D-rank | Schedule for next release |
| Low | Track only | E-rank | Auto-suppress or backlog |

```bash
# Quick triage: how many findings by severity?
cat trivy-fs.json | jq '[.Results[]?.Vulnerabilities[]? | .Severity] | group_by(.) | map({(.[0]): length}) | add'

# Critical findings — these are your immediate priority
cat trivy-fs.json | jq '.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL") | {id: .VulnerabilityID, pkg: .PkgName, installed: .InstalledVersion, fixed: .FixedVersion}'
```

### Step 4: Fix critical and high vulnerabilities

**Dependency CVEs**
```bash
# Python: update vulnerable packages
pip install --upgrade <package>==<fixed-version>
pip-audit --fix    # auto-fix where possible

# Node: update vulnerable packages
npm audit fix
npm audit fix --force    # for breaking changes (test after)

# Go: update vulnerable modules
go get <module>@<fixed-version>
govulncheck ./...    # verify fixes

# Regenerate lock files
pip freeze > requirements.txt
npm install    # regenerates package-lock.json
```

**Container image CVEs**
```bash
# Update base image to latest patched version
# In Dockerfile, change:
FROM python:3.12.2-slim
# To:
FROM python:3.12.6-slim    # latest patch

# Or switch to distroless (dramatically reduces CVE count)
FROM gcr.io/distroless/python3-debian12

# Rebuild and re-scan
docker build -t app:patched .
trivy image app:patched --severity CRITICAL,HIGH
```

### Step 5: Add scanning to CI/CD pipeline

```yaml
# .github/workflows/ci.yml
- name: Vulnerability scan
  run: |
    # Scan dependencies
    trivy fs --format json --output trivy-fs.json --exit-code 1 --severity CRITICAL .

    # Scan container image
    docker build -t $IMAGE .
    trivy image --format json --output trivy-image.json --exit-code 1 --severity CRITICAL $IMAGE

    # Secret scan
    gitleaks detect --source . --exit-code 1

    # SAST
    semgrep --config auto --error --severity ERROR .

- name: Upload scan evidence
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: security-scan-evidence
    path: |
      trivy-fs.json
      trivy-image.json
      semgrep.json
```

---

## RA-7: RISK RESPONSE

### What "compliant" looks like
- Every identified risk has a documented response (fix, accept, transfer, mitigate)
- Risk responses are tracked in the POA&M
- Risk acceptance requires authorization from the appropriate level

### Risk response tracking

```bash
# Generate the POA&M from scan results
python3 /path/to/GP-CONSULTING/07-FEDRAMP-READY/tools/gap-analysis.py \
  --evidence-dir ./evidence/scan-20260311 \
  --output ./evidence/gap-analysis

# The POA&M (poam.md) contains:
# - Finding ID
# - Description
# - Severity / Rank
# - Affected control(s)
# - Remediation plan
# - Target date
# - Status
```

### Risk acceptance template (for findings you can't fix)

```markdown
## Risk Acceptance Record

**Finding:** CVE-2025-XXXXX in libfoo 1.2.3
**Severity:** Medium
**Affected Control:** SI-2 (Flaw Remediation)

**Why we can't fix it:**
No upstream patch available. Vendor tracking issue #12345.

**Why the risk is acceptable:**
The vulnerable code path is not reachable in our application.
The function `foo_parse()` is never called — verified by:
- Code search confirming no imports of the affected module
- Semgrep rule confirming no usage patterns

**Mitigating controls:**
- NetworkPolicy restricts pod communication (SC-7)
- Pod runs as non-root with read-only filesystem (AC-6)
- Runtime monitoring via Falco would detect exploitation (SI-4)

**Accepted by:** [Name, Title]
**Date:** YYYY-MM-DD
**Review date:** YYYY-MM-DD (90 days)
```

---

## SI-4: INFORMATION SYSTEM MONITORING

### What "compliant" looks like
- Runtime monitoring detects anomalous behavior
- Alerts are generated for security-relevant events
- Monitoring covers: processes, network, file access, syscalls
- Alerts are reviewed and investigated

### Step 1: Deploy Falco for runtime detection

```bash
# Install Falco via Helm
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco \
  -n falco-system --create-namespace \
  --set falcosidekick.enabled=true \
  --set falcosidekick.config.slack.webhookurl=<slack-webhook>

# Verify
kubectl get pods -n falco-system
kubectl logs -n falco-system -l app.kubernetes.io/name=falco --tail=20
```

### Step 2: FedRAMP-relevant Falco rules

```yaml
# fedramp-rules.yaml — supplement default rules
- rule: Unauthorized Process in Container
  desc: Detect processes not in the allowed list
  condition: >
    spawned_process and container and
    not proc.name in (allowed_processes)
  output: "Unexpected process in container (user=%user.name command=%proc.cmdline container=%container.name image=%container.image.repository)"
  priority: WARNING
  tags: [SI-4, fedramp]

- rule: Write to Sensitive Directory
  desc: Detect writes to /etc, /usr, /bin in containers
  condition: >
    write and container and
    (fd.directory in (/etc, /usr, /bin, /sbin)) and
    not proc.name in (apt, dpkg, yum, rpm)
  output: "Write to sensitive directory (user=%user.name file=%fd.name container=%container.name)"
  priority: WARNING
  tags: [SI-4, fedramp]

- rule: Outbound Connection to Unusual Port
  desc: Detect outbound connections to non-standard ports
  condition: >
    outbound and container and
    not fd.sport in (80, 443, 53, 5432, 6379, 8080, 8443, 9090)
  output: "Outbound connection to unusual port (container=%container.name port=%fd.sport ip=%fd.sip)"
  priority: NOTICE
  tags: [SI-4, SC-7, fedramp]

- rule: Secret Access from Non-App Container
  desc: Detect access to mounted secrets from unexpected processes
  condition: >
    open_read and container and
    fd.name startswith /var/run/secrets and
    not proc.name in (app, python, node, java, go)
  output: "Secret file access from unexpected process (process=%proc.name file=%fd.name container=%container.name)"
  priority: WARNING
  tags: [SI-4, IA-5, fedramp]
```

### Step 3: Prometheus + Grafana monitoring

```yaml
# Prometheus alerts for FedRAMP SI-4
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: fedramp-si4-alerts
  namespace: monitoring
spec:
  groups:
    - name: fedramp-monitoring
      rules:
        - alert: PodCrashLooping
          expr: rate(kube_pod_container_status_restarts_total[15m]) > 0.1
          for: 5m
          labels:
            severity: warning
            compliance: SI-4
          annotations:
            summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"

        - alert: HighCPUUsage
          expr: (rate(container_cpu_usage_seconds_total[5m]) / on(namespace,pod) kube_pod_container_resource_limits{resource="cpu"}) > 0.9
          for: 10m
          labels:
            severity: warning
            compliance: SI-4
          annotations:
            summary: "Container CPU usage above 90% of limit"

        - alert: UnusualNetworkTraffic
          expr: sum(rate(container_network_transmit_bytes_total[5m])) by (namespace, pod) > 100000000
          for: 5m
          labels:
            severity: warning
            compliance: SI-4
          annotations:
            summary: "Unusual outbound network traffic from {{ $labels.namespace }}/{{ $labels.pod }}"

        - alert: FalcoAlertFired
          expr: sum(rate(falco_events_total{priority=~"Warning|Error|Critical"}[5m])) > 0
          for: 1m
          labels:
            severity: critical
            compliance: SI-4
          annotations:
            summary: "Falco detected security-relevant event"
```

---

## SI-10: INFORMATION INPUT VALIDATION

### What "compliant" looks like
- Application validates all input at system boundaries
- SQL injection, XSS, command injection are prevented
- Input validation is tested (SAST scan confirms)

### Step 1: Scan for input validation issues

```bash
# Run Semgrep with security rules
semgrep --config "p/owasp-top-ten" --json -o owasp-findings.json .

# Specific checks
semgrep --config "p/sql-injection" --json -o sqli.json .
semgrep --config "p/xss" --json -o xss.json .
semgrep --config "p/command-injection" --json -o cmdi.json .
```

### Step 2: Fix common patterns

**SQL Injection** — use parameterized queries
```python
# BAD
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")

# GOOD
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
```

**Command Injection** — never use shell=True with user input
```python
# BAD
subprocess.run(f"ls {user_path}", shell=True)

# GOOD
subprocess.run(["ls", user_path], shell=False)
```

**XSS** — escape output
```python
# BAD (Jinja2)
{{ user_input }}

# GOOD (Jinja2 auto-escapes by default, but verify)
{{ user_input | e }}
```

### Step 3: Add Semgrep to CI as a gate

```yaml
- name: SAST - Input Validation
  run: |
    semgrep --config "p/owasp-top-ten" --error --severity ERROR .
    # Blocks the build if SQL injection, XSS, or command injection found
```

---

## EVIDENCE FOR THE ASSESSOR

| Evidence | Source | Control |
|----------|--------|---------|
| Trivy scan results (code + images) | CI artifact | RA-5, SI-2 |
| Semgrep SAST results | CI artifact | RA-5, SI-10 |
| Gitleaks secret scan | CI artifact | RA-5 |
| POA&M with remediation timelines | gap-analysis.py output | RA-7 |
| Risk acceptance records | Documented decisions | RA-7 |
| Falco deployment proof | `kubectl get pods -n falco-system` | SI-4 |
| Prometheus alert rules | `kubectl get prometheusrules` | SI-4 |
| CI pipeline showing scan gates | GitHub Actions run logs | SI-2, RA-5 |
| Patch history (before/after scans) | Comparison of scan results | SI-2 |

---

## COMPLETION CHECKLIST

```
[ ] RA-5:  Trivy scanning code dependencies in CI
[ ] RA-5:  Trivy scanning container images in CI
[ ] RA-5:  Semgrep SAST running in CI
[ ] RA-5:  Gitleaks secret scanning in CI
[ ] RA-5:  Scans run on every commit (not just releases)
[ ] RA-7:  POA&M generated with all open findings
[ ] RA-7:  Each finding has a response (fix/accept/mitigate)
[ ] RA-7:  Risk acceptances documented with justification
[ ] SI-2:  Critical CVEs patched within 30 days
[ ] SI-2:  High CVEs patched within 90 days
[ ] SI-2:  Base images updated to latest patch versions
[ ] SI-2:  Dependency lock files regenerated after patches
[ ] SI-4:  Falco deployed and generating events
[ ] SI-4:  Prometheus alerts for anomalous behavior
[ ] SI-4:  Monitoring covers: process, network, file, crash events
[ ] SI-4:  Alert review process documented
[ ] SI-10: Semgrep OWASP rules running in CI
[ ] SI-10: No SQL injection patterns in codebase
[ ] SI-10: No command injection patterns in codebase
[ ] SI-10: Input validation at all API endpoints
```
