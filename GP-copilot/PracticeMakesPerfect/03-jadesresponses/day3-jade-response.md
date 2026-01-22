# Day 3 - JADE Responses

---

## TICKET-014 | Kubernetes Readiness Probe Issue

### 1. Root Cause
**Port mismatch**: The readiness probe checks port `8080`, but the app logs show `Server started on port 3000`. The probe is hitting the wrong port, so it always fails.

### 2. Two Fixes

**Quick Fix (immediate):**
```bash
kubectl patch deployment payment-api-v2 -n payments --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/port", "value": 3000}]'
```

**Proper Fix (in code/Helm):**
```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 3000  # Match the actual app port
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 3
```

### 3. Verify Command
```bash
kubectl get pods -n payments -w
# Wait for READY 1/1

kubectl rollout status deployment/payment-api-v2 -n payments
# Should show "successfully rolled out"
```

### 4. CI/CD Prevention
- **Conftest policy**: Validate that probe ports match container ports
- **Helm lint**: Check port consistency in values
- **Pre-deploy test**: Hit `/health` endpoint in staging before prod

---

## TICKET-015 | OPA/Gatekeeper Privilege Escalation Block

### 1. ConstraintTemplate
```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sblockprivilegeescalation
spec:
  crd:
    spec:
      names:
        kind: K8sBlockPrivilegeEscalation
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sblockprivilegeescalation

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          container.securityContext.privileged == true
          msg := sprintf("Container '%v' cannot run as privileged", [container.name])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          container.securityContext.allowPrivilegeEscalation == true
          msg := sprintf("Container '%v' cannot have allowPrivilegeEscalation=true", [container.name])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.initContainers[_]
          container.securityContext.privileged == true
          msg := sprintf("Init container '%v' cannot run as privileged", [container.name])
        }
```

### 2. Constraint with Namespace Exclusion
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockPrivilegeEscalation
metadata:
  name: block-privilege-escalation
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet", "DaemonSet"]
    excludedNamespaces:
      - kube-system
```

### 3. Example Pod that PASSES
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  containers:
    - name: app
      image: nginx:alpine
      securityContext:
        allowPrivilegeEscalation: false
        privileged: false
        runAsNonRoot: true
        runAsUser: 1000
```

### 4. Example Pod that FAILS
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
spec:
  containers:
    - name: app
      image: nginx
      securityContext:
        privileged: true  # BLOCKED
```

### 5. Safe Rollout Strategy
1. Deploy in `dryrun` mode first (audit only)
2. Review violations in `kubectl get k8sblockprivilegeescalation -o yaml`
3. Fix offending workloads
4. Switch to `deny` mode
5. Monitor for new violations

---

## TICKET-016 | Gitleaks False Positive

### 1. Why Gitleaks Flagged It
Not a false positive. The **fallback value** `"sk_live_defaultkey123456789"` is a hardcoded secret in the source code. Even though it's a "default", it:
- Matches the `sk_live_*` pattern (real Stripe key format)
- Is committed to git history
- Could be a real leaked key

### 2. Secure Fix
```typescript
// src/config/payment.ts
const STRIPE_KEY = process.env.STRIPE_KEY;

if (!STRIPE_KEY) {
  throw new Error("STRIPE_KEY environment variable is required");
}
```

Never use fallback secrets. Fail fast if env var is missing.

### 3. Should They Use .gitleaksignore?
**No** for this case. The secret pattern is real. Only use `.gitleaksignore` for:
- Test files with fake example secrets
- Documentation with redacted examples
- Known false positives (after review)

### 4. Example .gitleaks.toml for Test Keys
```toml
[extend]
# Allow test keys only in test directories
[[rules]]
id = "stripe-test-key"
description = "Stripe test key in test files"
regex = '''sk_test_[a-zA-Z0-9]{24}'''
allowlist = { paths = ["**/test/**", "**/tests/**", "**/*_test.go"] }
```

---

## TICKET-017 | Token Rotation Script

### 1. Python Script
```python
#!/usr/bin/env python3
"""Rotate K8s SA token across GitHub repos."""

import os
import sys
import time
import yaml
import base64
import logging
import requests
from typing import List, Dict
from nacl import encoding, public

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

GITHUB_API = "https://api.github.com"

def get_public_key(repo: str, token: str) -> tuple:
    """Get repo's public key for secret encryption."""
    resp = requests.get(
        f"{GITHUB_API}/repos/{repo}/actions/secrets/public-key",
        headers={"Authorization": f"token {token}"}
    )
    resp.raise_for_status()
    data = resp.json()
    return data["key_id"], data["key"]

def encrypt_secret(public_key: str, secret_value: str) -> str:
    """Encrypt secret using repo's public key."""
    pk = public.PublicKey(public_key.encode(), encoding.Base64Encoder())
    sealed = public.SealedBox(pk).encrypt(secret_value.encode())
    return base64.b64encode(sealed).decode()

def update_secret(repo: str, secret_name: str, secret_value: str, token: str) -> bool:
    """Update a GitHub Actions secret."""
    try:
        key_id, pub_key = get_public_key(repo, token)
        encrypted = encrypt_secret(pub_key, secret_value)

        resp = requests.put(
            f"{GITHUB_API}/repos/{repo}/actions/secrets/{secret_name}",
            headers={"Authorization": f"token {token}"},
            json={"encrypted_value": encrypted, "key_id": key_id}
        )
        resp.raise_for_status()
        logger.info(f"Updated secret {secret_name} in {repo}")
        return True
    except Exception as e:
        logger.error(f"Failed to update {repo}: {e}")
        return False

def trigger_workflow(repo: str, workflow: str, token: str) -> bool:
    """Trigger workflow dispatch."""
    try:
        resp = requests.post(
            f"{GITHUB_API}/repos/{repo}/actions/workflows/{workflow}/dispatches",
            headers={"Authorization": f"token {token}"},
            json={"ref": "main"}
        )
        resp.raise_for_status()
        logger.info(f"Triggered {workflow} in {repo}")
        return True
    except Exception as e:
        logger.error(f"Failed to trigger workflow in {repo}: {e}")
        return False

def check_deployment_status(repo: str, token: str, timeout: int = 300) -> bool:
    """Wait for deployment to succeed."""
    start = time.time()
    while time.time() - start < timeout:
        resp = requests.get(
            f"{GITHUB_API}/repos/{repo}/actions/runs?status=in_progress",
            headers={"Authorization": f"token {token}"}
        )
        runs = resp.json().get("workflow_runs", [])
        if not runs:
            logger.info(f"{repo}: Deployment complete")
            return True
        time.sleep(10)
    logger.error(f"{repo}: Deployment timed out")
    return False

def main():
    config_file = sys.argv[1] if len(sys.argv) > 1 else "repos.yaml"

    # Load config
    with open(config_file) as f:
        config = yaml.safe_load(f)

    gh_token = os.environ.get("GITHUB_TOKEN")
    k8s_token = os.environ.get("K8S_SA_TOKEN")

    if not gh_token or not k8s_token:
        logger.error("GITHUB_TOKEN and K8S_SA_TOKEN required")
        sys.exit(1)

    results = {"success": [], "failed": []}

    for repo in config["repos"]:
        # Update secret
        if not update_secret(repo, "K8S_SA_TOKEN", k8s_token, gh_token):
            results["failed"].append(repo)
            continue

        # Trigger deployment
        if not trigger_workflow(repo, "deploy.yml", gh_token):
            results["failed"].append(repo)
            continue

        # Verify
        if check_deployment_status(repo, gh_token):
            results["success"].append(repo)
        else:
            results["failed"].append(repo)

    # Report
    logger.info(f"Success: {len(results['success'])}, Failed: {len(results['failed'])}")
    for repo in results["failed"]:
        logger.error(f"FAILED: {repo}")

    sys.exit(0 if not results["failed"] else 1)

if __name__ == "__main__":
    main()
```

### 2. Config File (repos.yaml)
```yaml
repos:
  - org/service-api
  - org/service-web
  - org/service-worker
  - org/service-scheduler
```

### 3. Secure Token Passing
```bash
# From environment (CI)
export K8S_SA_TOKEN=$(vault kv get -field=token secret/k8s/sa)
export GITHUB_TOKEN=$(vault kv get -field=token secret/github/automation)
python rotate_token.py

# Or use stdin
echo "$K8S_SA_TOKEN" | python rotate_token.py --token-stdin
```

### 4. Audit Logging
- Timestamp of each action
- Repo name and secret name
- Success/failure status
- User/service that ran the script
- Store logs in centralized logging (CloudWatch, Splunk)

---

## TICKET-018 | API Integration Debug

### 1. Five Things to Check
1. **Verify API key value**: `echo $DASHBOARD_API_KEY | wc -c` (check length)
2. **Check for whitespace**: `echo "$DASHBOARD_API_KEY" | xxd | head` (look for trailing newlines)
3. **Test key manually**: `curl -H "X-API-Key: $DASHBOARD_API_KEY" https://...`
4. **Check AWS Secrets Manager**: Did the secret get rotated?
5. **Check API server logs**: Is the key being received? What key is expected?

### 2. Verify Key Loading
```python
import os
API_KEY = os.getenv("DASHBOARD_API_KEY")
print(f"Key length: {len(API_KEY) if API_KEY else 0}")
print(f"Key starts with: {API_KEY[:8] if API_KEY else 'NONE'}...")
print(f"Has newline: {repr(API_KEY[-5:]) if API_KEY else 'N/A'}")
```

### 3. Hypothesis: Why It Broke
Most likely: **Secret was rotated** in AWS Secrets Manager but the pod wasn't restarted. The env var is set at pod startup, not dynamically refreshed.

Other possibilities:
- Trailing newline in secret value
- Key expired (time-based)
- API endpoint changed

### 4. More Resilient Integration
```python
import os
import requests
from functools import lru_cache
import boto3

@lru_cache(maxsize=1)
def get_api_key():
    """Fetch key from Secrets Manager with caching."""
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId='dashboard-api-key')
    return response['SecretString'].strip()

def send_findings(findings, retry=3):
    for attempt in range(retry):
        try:
            response = requests.post(
                "https://security-dashboard.healthvault.io/api/v1/findings",
                json=findings,
                headers={"X-API-Key": get_api_key()},
                timeout=30
            )
            response.raise_for_status()
            return response.status_code
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 401:
                get_api_key.cache_clear()  # Refresh key
            if attempt == retry - 1:
                raise
```

---

## TICKET-019 | Helm Resource Limits

### 1. Updated values.yaml
```yaml
infrasec:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 1000m      # Allow burst during scans
      memory: 512Mi
  # Prevent eviction during scans
  priorityClassName: system-cluster-critical
```

### 2. Requests vs Limits
- **Requests**: Guaranteed minimum. Scheduler uses this to place pods.
- **Limits**: Maximum allowed. Container is throttled (CPU) or killed (memory) if exceeded.

### 3. Determining Values
1. **Run the workload** with no limits, monitor actual usage
2. **Set requests** to p50 (normal usage)
3. **Set limits** to p99 (peak usage + buffer)
4. Use `kubectl top pods` or Prometheus metrics
5. Iterate based on OOMKills or throttling

---

## TICKET-020 | IAM Role Audit

### 1. Find Unused Roles
```bash
# Get roles with no recent activity (last 90 days)
aws iam generate-credential-report
aws iam get-credential-report --output text --query Content | base64 -d > report.csv

# Or use Access Analyzer
aws accessanalyzer list-findings \
  --analyzer-arn arn:aws:access-analyzer:us-east-1:ACCOUNT:analyzer/NAME \
  --filter '{"findingType": {"eq": ["UnusedIAMRole"]}}'

# Manual: Check last used date
for role in $(aws iam list-roles --query 'Roles[].RoleName' --output text); do
  last_used=$(aws iam get-role --role-name $role --query 'Role.RoleLastUsed.LastUsedDate' --output text)
  echo "$role: $last_used"
done
```

### 2. Find Overly Permissive Roles
```bash
# Find policies with wildcards
for role in $(aws iam list-roles --query 'Roles[].RoleName' --output text); do
  aws iam list-attached-role-policies --role-name $role --query 'AttachedPolicies[].PolicyArn' --output text | while read arn; do
    version=$(aws iam get-policy --policy-arn $arn --query 'Policy.DefaultVersionId' --output text)
    aws iam get-policy-version --policy-arn $arn --version-id $version --query 'PolicyVersion.Document' | grep -l '"*"' && echo "WILDCARD: $role - $arn"
  done
done

# Use IAM Access Analyzer policy validation
aws accessanalyzer validate-policy --policy-document file://policy.json --policy-type IDENTITY_POLICY
```

### 3. Naming Convention
```
{env}-{service}-{purpose}-role

Examples:
- prod-payments-api-role
- dev-analytics-etl-role
- staging-frontend-deploy-role
- shared-monitoring-readonly-role
```

### 4. Prevent Sprawl
- **IaC only**: No manual role creation. All in Terraform/CDK
- **Tagging required**: Environment, team, expiry date
- **Quarterly review**: Automated report of unused roles
- **Expiry dates**: Temporary roles auto-delete after N days

---

## INTERVIEW-01 | Pod Security Standards

"Pod Security Standards, or PSS, is Kubernetes' built-in way to enforce security policies on pods. Think of it as guardrails that prevent developers from deploying insecure containers.

There are three levels:

**Privileged** is basically no restrictions - anything goes. You'd use this for system-level components like CNI plugins or storage drivers that legitimately need host access.

**Baseline** blocks the most dangerous stuff - privileged containers, host networking, host paths. This is what most production workloads should use. It stops the obvious bad things while still being flexible.

**Restricted** is the strictest - requires running as non-root, drops all capabilities, requires read-only root filesystem. This is for high-security environments or compliance requirements like PCI-DSS.

The way you enforce it is through Pod Security Admission, which is built into Kubernetes since 1.25. You label namespaces with the level you want:

```yaml
labels:
  pod-security.kubernetes.io/enforce: restricted
```

In practice, we usually set `restricted` on application namespaces and `privileged` on `kube-system`. The key is to start with `warn` mode to see what would break, then switch to `enforce` once you've fixed the violations."

---

## INTERVIEW-02 | OOMKilled Troubleshooting

"When I see a pod getting OOMKilled, here's my systematic approach:

**First, I check the events:**
```bash
kubectl describe pod <name> | grep -A5 OOMKilled
kubectl get events --field-selector involvedObject.name=<pod>
```

This tells me how often it's happening and the memory at time of kill.

**Second, I look at current resource config:**
```bash
kubectl get pod <name> -o yaml | grep -A10 resources
```

Is the limit set too low? Is there even a limit?

**Third, I check actual memory usage over time:**
```bash
kubectl top pod <name>
# Or in Prometheus: container_memory_usage_bytes
```

I'm looking for: Does it slowly climb (leak) or spike suddenly (burst)?

**To determine leak vs undersized:**
- If memory grows linearly over hours/days → likely a leak
- If it spikes during specific operations → undersized for workload
- If it immediately hits limit on startup → definitely undersized

**Fix strategy:**
1. If undersized: Increase limit based on observed max + 20% buffer
2. If leak: That's a code fix. As a workaround, add liveness probe that restarts before OOM
3. Profile the app with memory tools to find the leak source

The key insight is: don't just bump the limit blindly. Understand *why* it's using that memory."

---

## INTERVIEW-03 | Secrets Management Architecture

"For Kubernetes secrets management, I'd consider three main approaches:

**1. Native Kubernetes Secrets**
- Pros: Simple, built-in, no extra dependencies
- Cons: Base64 encoded (not encrypted at rest by default), anyone with RBAC can read them
- Use when: Small clusters, non-sensitive data, development environments

**2. External Secrets Operator + Cloud Provider**
- Pros: Secrets stored in AWS Secrets Manager/GCP Secret Manager, automatic rotation, audit logs
- Cons: Cloud dependency, extra operator to manage
- Use when: You're already in a cloud provider, need rotation, need audit trail

**3. HashiCorp Vault**
- Pros: Dynamic secrets, fine-grained policies, works anywhere, PKI capabilities
- Cons: Operational complexity, another system to maintain
- Use when: Multi-cloud, need dynamic database credentials, need PKI

**Factors influencing my recommendation:**
- Team size and expertise
- Existing infrastructure
- Compliance requirements
- Multi-cloud needs

**For compliance:**
- **HIPAA**: Needs encryption at rest, audit logging, access controls → Vault or External Secrets
- **PCI-DSS**: Needs rotation, strong access controls → Vault with dynamic secrets
- **FedRAMP**: Needs FIPS-compliant encryption → Vault with HSM backend

My default recommendation for most production clusters is External Secrets Operator with the cloud provider's secret manager. It's the best balance of security, simplicity, and auditability. Vault is great but often overkill unless you need its advanced features."

---

## Summary

| Ticket | Status | Time |
|--------|--------|------|
| TICKET-014 (K8s) | Complete | 8 min |
| TICKET-015 (OPA) | Complete | 15 min |
| TICKET-016 (Gitleaks) | Complete | 6 min |
| TICKET-017 (Script) | Complete | 20 min |
| TICKET-018 (API) | Complete | 8 min |
| TICKET-019 (Helm) | Complete | 5 min |
| TICKET-020 (IAM) | Complete | 10 min |
| INTERVIEW-01 | Complete | 5 min |
| INTERVIEW-02 | Complete | 5 min |
| INTERVIEW-03 | Complete | 8 min |
| **Total** | **10/10** | **~90 min** |
