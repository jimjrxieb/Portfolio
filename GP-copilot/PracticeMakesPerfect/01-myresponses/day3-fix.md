# Day [N] Responses
**Date:** YYYY-MM-DD
**Started:** [HH:MM]
**Completed:** [HH:MM]

---

<!---------- COPY THIS BLOCK FOR EACH TICKET ---------------------------->

## TICKET-014 | [KUBERENTES]
**Time spent:** __ mins

### Ticket Deliverables:
1. prode is pointed towards 8080 and app is running on port 3000
2. edit deployment and change probe port to 3000
3. kubectl get pods get pods -n payments
4. of course create a conftest policy 
# policy/kubernetes/probe-port-match.rego
package kubernetes.probes

deny[msg] {
    container := input.spec.template.spec.containers[_]
    probe_port := container.readinessProbe.httpGet.port
    container_port := container.ports[_].containerPort
    probe_port != container_port
    msg := sprintf("Readiness probe port %d doesn't match container port %d", [probe_port, container_port])
}

# .github/workflows/security.yaml
- name: Validate K8s manifests
  run: |
    conftest test k8s/*.yaml --policy policy/kubernetes/

### My use of JSA to fix(if allowed):
jade would create the parallel conftest policy while i change port to match application location 

### Why I did it this way:
simple and common error. learning opa has help with the "how do we prevent error in the future?"

### How I would validate:
kubectl get pods and see if the pod is ready

### Confidence level: _10_/10


## TICKET-015 | [OPA/GATEKEEPR]
**Time spent:** __ mins

### The Ask (in my words):
<!-- Can you explain what this ticket is asking WITHOUT jargon? -->
the ticket is asking to create a opa policy to block privilege escalation in containers. 
### What I Tried First:
<!-- Before asking AI, what did YOU think the answer was? -->
i had high confidence in what it was asking . 
### JSA/AI Solution:
<!-- What did the AI produce? -->
# constraint-template-block-privileged.yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sblockprivileged
  annotations:
    description: "Blocks containers with privileged=true or allowPrivilegeEscalation=true"
spec:
  crd:
    spec:
      names:
        kind: K8sBlockPrivileged
      validation:
        openAPIV3Schema:
          type: object
          properties:
            # No parameters needed for this simple policy
            # But you COULD add exemptImages, etc. here
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sblockprivileged

        # Deny if privileged: true
        violation[{"msg": msg}] {
          container := input_containers[_]
          container.securityContext.privileged == true
          msg := sprintf("Container '%v' has privileged=true. This is blocked by security policy.", [container.name])
        }

        # Deny if allowPrivilegeEscalation: true
        violation[{"msg": msg}] {
          container := input_containers[_]
          container.securityContext.allowPrivilegeEscalation == true
          msg := sprintf("Container '%v' has allowPrivilegeEscalation=true. This is blocked by security policy.", [container.name])
        }

        # Helper: Get all containers (regular + init + ephemeral)
        input_containers[c] {
          c := input.review.object.spec.containers[_]
        }
        input_containers[c] {
          c := input.review.object.spec.initContainers[_]
        }
        input_containers[c] {
          c := input.review.object.spec.template.spec.containers[_]
        }
        input_containers[c] {
          c := input.review.object.spec.template.spec.initContainers[_]
        }
### My Evaluation:
<!-- Is this RIGHT? How do you know? What would break? -->
i like it. clear messages and clear sections to check the pods
### What I Learned:
<!-- One concept I understand better now -->
the helper get all containers. 
### Could I Explain This in an Interview? 
<!-- Yes/No - if No, what's the gap? -->
yes. 
### Confidence level: __/10

---

## TICKET-016 | [CICD]
**Time spent:** __ mins

### The Ask (in my words):
<!-- Can you explain what this ticket is asking WITHOUT jargon? -->
yes explain why gitleaks is flagging their build
### What I Tried First:
<!-- Before asking AI, what did YOU think the answer was? -->
I dont know. To me it looks like their secret was still being added even though we are trying to call it from another location
### JSA/AI Solution:
<!-- What did the AI produce? -->
1. Root Cause: The `||` operator creates a hardcoded fallback value in source code.
2. // ❌ INSECURE - fallback exposes secret
const STRIPE_KEY = process.env.STRIPE_KEY || "sk_live_defaultkey123456789";

// ✅ SECURE - fail fast, no fallback
const STRIPE_KEY = process.env.STRIPE_KEY;

if (!STRIPE_KEY) {
  throw new Error("STRIPE_KEY environment variable is required");
}

export { STRIPE_KEY };
3. **Answer: NO** - not for this case.

**.gitleaksignore is appropriate for:**
| Use Case | Appropriate? |
|----------|--------------|
| Real secret hardcoded | ❌ NO - fix the code |
| Documentation examples | ✅ YES |
| Test fixtures with fake data | ✅ YES |
| False positives (hash looks like key) | ✅ YES |
| Already-rotated key in old commits | ⚠️ MAYBE - after rotation confirmed |

**Why not ignore this:**
- Ignoring doesn't remove the secret - it just hides the warning
- The secret is still in Git, still exposed
- That's security theater, not security
4. # .gitleaks.toml
title = "SecureBank Gitleaks Config"

[allowlist]
  description = "Safe patterns to ignore"
  
  # Stripe TEST keys are designed to be safe
  regexes = [
    '''sk_test_[a-zA-Z0-9]+''',
    '''pk_test_[a-zA-Z0-9]+''',
  ]
  
  # Test fixture files
  paths = [
    '''test/fixtures/.*''',
    '''__mocks__/.*''',
  ]

# NEVER allow live keys - explicit block
[[rules]]
  id = "stripe-live-key-block"
  description = "Stripe Live Key - NEVER allow"
  regex = '''sk_live_[a-zA-Z0-9]{24,}'''
  tags = ["critical", "stripe"]

### My Evaluation:
<!-- Is this RIGHT? How do you know? What would break? -->

### What I Learned:
<!-- One concept I understand better now -->
`env_var || "fallback"` pattern is dangerous for secrets
- The fallback is STILL in Git, regardless of runtime behavior
- Gitleaks scans the CODE, not runtime values
- Secure pattern: fail fast, no fallbacks for secrets
### Could I Explain This in an Interview? 
<!-- Yes/No - if No, what's the gap? -->
After studying the answer i believe i could. Secret was getting pushed to github due to bad syntax. 
### Confidence level: _5_/10

---

## TICKET-017 | [SCRIPTING/AUTOMATION]
**Time spent:** __ mins

### The Ask (in my words):
<!-- Can you explain what this ticket is asking WITHOUT jargon? -->
Platform team rotates K8s tokens every month and its a pain - they have to manually update 12 repos, trigger deployments, then check everything works. They want a script to do steps 2-4 automatically.

### What I Tried First:
<!-- Before asking AI, what did YOU think the answer was? -->
I knew it would need to use the GitHub API somehow and loop through repos, but I didnt know the actual API calls or how to handle the encryption GitHub requires for secrets.

### Ticket Deliverables:

**1. Python script with proper error handling**
The script does 3 things per repo: update secret → trigger workflow → wait and check if deployment worked. It uses try/except blocks so if one repo fails it keeps going to the next one instead of crashing. At the end it prints a report showing what passed/failed.

**2. Example config file for repo list**
```yaml
# repos.yaml
secret_name: K8S_SERVICE_ACCOUNT_TOKEN

repos:
  - owner: securebank
    repo: payment-api
    branch: main
  - owner: securebank
    repo: user-service
    branch: main
  # ... add more repos as needed
```

**3. How would you securely pass the token to this script?**
Best option: read it from a file with restricted permissions (chmod 600), then shred the file after. Never pass the token directly on the command line because it shows up in bash history and process lists. Even better - pull it from AWS Secrets Manager so it never touches disk at all.

```bash
# Good
python rotate_token.py --token-file /secure/token.txt --config repos.yaml

# Bad - token visible in history
python rotate_token.py --token "actual-secret-here"
```

**4. What logging would you add for audit trail?**
- Timestamp for each action
- Which repo was updated
- Success/failure status
- Who ran the script (could grab from env or require a --operator flag)
- Write to a log file, not just stdout

Something like:
```
2026-01-12 14:30:22 | operator=jimmie | repo=securebank/payment-api | action=secret_update | status=success
2026-01-12 14:30:25 | operator=jimmie | repo=securebank/payment-api | action=workflow_trigger | status=success
```

### JSA/AI Solution (full script for reference):
<!-- What did the AI produce? -->
#!/usr/bin/env python3
"""
Token Rotation Automation Script
Updates GitHub secrets, triggers deployments, verifies health.

Usage:
    python rotate_token.py --token-file /secure/path/token.txt --config repos.yaml
"""

import requests  # Library to make HTTP calls (API requests)
import yaml      # Library to read YAML config files
import time      # Library for sleep/wait
import argparse  # Library to handle command line arguments
import sys       # Library for exit codes
from base64 import b64encode  # GitHub needs secrets encoded
from nacl import encoding, public  # GitHub uses encryption for secrets

# ============================================================
# CONFIGURATION
# ============================================================

GITHUB_API = "https://api.github.com"
WORKFLOW_FILENAME = "deploy.yml"  # The workflow file to trigger
MAX_WAIT_MINUTES = 10             # How long to wait for deployment
POLL_INTERVAL_SECONDS = 30        # How often to check status


# ============================================================
# GITHUB API FUNCTIONS
# ============================================================

def get_headers(github_token: str) -> dict:
    """
    Create headers for GitHub API authentication.
    Every API call needs these headers to prove who we are.
    """
    return {
        "Authorization": f"Bearer {github_token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28"
    }


def encrypt_secret(public_key: str, secret_value: str) -> str:
    """
    GitHub requires secrets to be encrypted with the repo's public key.
    This is a security feature - secrets are encrypted in transit.
    
    Don't worry about understanding the crypto - just know it's required.
    """
    public_key_bytes = public.PublicKey(
        public_key.encode("utf-8"), 
        encoding.Base64Encoder()
    )
    sealed_box = public.SealedBox(public_key_bytes)
    encrypted = sealed_box.encrypt(secret_value.encode("utf-8"))
    return b64encode(encrypted).decode("utf-8")


def get_repo_public_key(owner: str, repo: str, headers: dict) -> tuple:
    """
    Get the public key for a repo (needed to encrypt secrets).
    Returns: (key_id, public_key)
    """
    url = f"{GITHUB_API}/repos/{owner}/{repo}/actions/secrets/public-key"
    response = requests.get(url, headers=headers)
    
    if response.status_code != 200:
        raise Exception(f"Failed to get public key for {owner}/{repo}: {response.text}")
    
    data = response.json()
    return data["key_id"], data["key"]


def update_secret(owner: str, repo: str, secret_name: str, 
                  secret_value: str, headers: dict) -> bool:
    """
    Update a secret in a GitHub repo.
    
    Steps:
    1. Get repo's public key (for encryption)
    2. Encrypt the secret value
    3. PUT the encrypted secret to GitHub
    """
    try:
        # Step 1: Get public key
        key_id, public_key = get_repo_public_key(owner, repo, headers)
        
        # Step 2: Encrypt the secret
        encrypted_value = encrypt_secret(public_key, secret_value)
        
        # Step 3: Update the secret
        url = f"{GITHUB_API}/repos/{owner}/{repo}/actions/secrets/{secret_name}"
        payload = {
            "encrypted_value": encrypted_value,
            "key_id": key_id
        }
        response = requests.put(url, headers=headers, json=payload)
        
        # 201 = created, 204 = updated (both are success)
        if response.status_code in [201, 204]:
            print(f"  ✅ Secret updated: {owner}/{repo}")
            return True
        else:
            print(f"  ❌ Failed to update secret: {owner}/{repo} - {response.text}")
            return False
            
    except Exception as e:
        print(f"  ❌ Error updating {owner}/{repo}: {str(e)}")
        return False


def trigger_workflow(owner: str, repo: str, branch: str, headers: dict) -> bool:
    """
    Trigger a GitHub Actions workflow via workflow_dispatch.
    
    This is like clicking "Run workflow" in the GitHub UI.
    """
    url = f"{GITHUB_API}/repos/{owner}/{repo}/actions/workflows/{WORKFLOW_FILENAME}/dispatches"
    payload = {
        "ref": branch  # Which branch to run on
    }
    
    response = requests.post(url, headers=headers, json=payload)
    
    if response.status_code == 204:
        print(f"  ✅ Workflow triggered: {owner}/{repo}")
        return True
    else:
        print(f"  ❌ Failed to trigger workflow: {owner}/{repo} - {response.text}")
        return False


def get_latest_workflow_run(owner: str, repo: str, headers: dict) -> dict:
    """
    Get the most recent workflow run for a repo.
    """
    url = f"{GITHUB_API}/repos/{owner}/{repo}/actions/workflows/{WORKFLOW_FILENAME}/runs"
    params = {"per_page": 1}  # Only get the latest
    
    response = requests.get(url, headers=headers, params=params)
    
    if response.status_code == 200:
        runs = response.json().get("workflow_runs", [])
        if runs:
            return runs[0]
    return None


def wait_for_workflow(owner: str, repo: str, headers: dict) -> str:
    """
    Wait for a workflow to complete and return final status.
    
    Polls GitHub every POLL_INTERVAL_SECONDS until:
    - Workflow completes (success/failure)
    - We hit MAX_WAIT_MINUTES timeout
    """
    max_attempts = (MAX_WAIT_MINUTES * 60) // POLL_INTERVAL_SECONDS
    
    for attempt in range(max_attempts):
        run = get_latest_workflow_run(owner, repo, headers)
        
        if run:
            status = run.get("status")        # queued, in_progress, completed
            conclusion = run.get("conclusion") # success, failure, cancelled, etc.
            
            if status == "completed":
                return conclusion
        
        # Not done yet - wait and try again
        print(f"  ⏳ Waiting for {owner}/{repo}... ({attempt + 1}/{max_attempts})")
        time.sleep(POLL_INTERVAL_SECONDS)
    
    return "timeout"


# ============================================================
# MAIN ORCHESTRATION
# ============================================================

def rotate_tokens(config: dict, new_token: str, github_token: str) -> dict:
    """
    Main function: Rotate tokens across all repos in config.
    
    Returns a report of what happened.
    """
    headers = get_headers(github_token)
    secret_name = config.get("secret_name", "K8S_SERVICE_ACCOUNT_TOKEN")
    
    report = {
        "success": [],
        "failed_secret_update": [],
        "failed_workflow_trigger": [],
        "failed_deployment": [],
        "timeout": []
    }
    
    for repo_config in config["repos"]:
        owner = repo_config["owner"]
        repo = repo_config["repo"]
        branch = repo_config.get("branch", "main")
        
        print(f"\n📦 Processing {owner}/{repo}...")
        
        # Step 1: Update the secret
        if not update_secret(owner, repo, secret_name, new_token, headers):
            report["failed_secret_update"].append(f"{owner}/{repo}")
            continue  # Skip to next repo
        
        # Step 2: Trigger deployment workflow
        if not trigger_workflow(owner, repo, branch, headers):
            report["failed_workflow_trigger"].append(f"{owner}/{repo}")
            continue
        
        # Step 3: Wait for deployment and verify
        print(f"  ⏳ Waiting for deployment to complete...")
        result = wait_for_workflow(owner, repo, headers)
        
        if result == "success":
            print(f"  ✅ Deployment successful: {owner}/{repo}")
            report["success"].append(f"{owner}/{repo}")
        elif result == "timeout":
            print(f"  ⚠️ Deployment timed out: {owner}/{repo}")
            report["timeout"].append(f"{owner}/{repo}")
        else:
            print(f"  ❌ Deployment failed: {owner}/{repo} ({result})")
            report["failed_deployment"].append(f"{owner}/{repo}")
    
    return report


def print_report(report: dict):
    """
    Print a summary report of the rotation.
    """
    print("\n" + "=" * 60)
    print("📊 TOKEN ROTATION REPORT")
    print("=" * 60)
    
    total = sum(len(v) for v in report.values())
    
    print(f"\n✅ Successful: {len(report['success'])}/{total}")
    for repo in report['success']:
        print(f"   - {repo}")
    
    if report['failed_secret_update']:
        print(f"\n❌ Failed (secret update): {len(report['failed_secret_update'])}")
        for repo in report['failed_secret_update']:
            print(f"   - {repo}")
    
    if report['failed_workflow_trigger']:
        print(f"\n❌ Failed (workflow trigger): {len(report['failed_workflow_trigger'])}")
        for repo in report['failed_workflow_trigger']:
            print(f"   - {repo}")
    
    if report['failed_deployment']:
        print(f"\n❌ Failed (deployment): {len(report['failed_deployment'])}")
        for repo in report['failed_deployment']:
            print(f"   - {repo}")
    
    if report['timeout']:
        print(f"\n⚠️ Timed out: {len(report['timeout'])}")
        for repo in report['timeout']:
            print(f"   - {repo}")
    
    print("\n" + "=" * 60)
    
    # Return exit code based on success
    if len(report['success']) == total:
        return 0  # All good
    else:
        return 1  # Some failures


# ============================================================
# ENTRY POINT
# ============================================================

def main():
    """
    Parse arguments and run the rotation.
    """
    parser = argparse.ArgumentParser(description="Rotate K8s tokens across GitHub repos")
    parser.add_argument("--token-file", required=True, 
                        help="Path to file containing the new token")
    parser.add_argument("--config", required=True,
                        help="Path to YAML config file with repo list")
    parser.add_argument("--github-token", 
                        help="GitHub PAT (or set GITHUB_TOKEN env var)")
    
    args = parser.parse_args()
    
    # Load the new token from file (more secure than command line arg)
    try:
        with open(args.token_file, 'r') as f:
            new_token = f.read().strip()
    except Exception as e:
        print(f"❌ Failed to read token file: {e}")
        sys.exit(1)
    
    # Load repo config
    try:
        with open(args.config, 'r') as f:
            config = yaml.safe_load(f)
    except Exception as e:
        print(f"❌ Failed to read config file: {e}")
        sys.exit(1)
    
    # Get GitHub token (from arg or environment)
    import os
    github_token = args.github_token or os.environ.get("GITHUB_TOKEN")
    if not github_token:
        print("❌ GitHub token required. Use --github-token or set GITHUB_TOKEN env var")
        sys.exit(1)
    
    # Run the rotation
    report = rotate_tokens(config, new_token, github_token)
    
    # Print report and exit with appropriate code
    exit_code = print_report(report)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()

2. # repos.yaml
# List of repos to update during token rotation

secret_name: K8S_SERVICE_ACCOUNT_TOKEN  # Name of the GitHub secret to update

repos:
  - owner: securebank
    repo: payment-api
    branch: main
    
  - owner: securebank
    repo: user-service
    branch: main
    
  - owner: securebank
    repo: notification-service
    branch: main
    
  - owner: securebank
    repo: fraud-detection
    branch: main
    
  - owner: securebank
    repo: reporting-api
    branch: main
    
  - owner: securebank
    repo: admin-portal
    branch: main
    
  - owner: securebank
    repo: mobile-backend
    branch: main
    
  - owner: securebank
    repo: transaction-processor
    branch: main
    
  - owner: securebank
    repo: audit-logger
    branch: main
    
  - owner: securebank
    repo: rate-limiter
    branch: main
    
  - owner: securebank
    repo: cache-service
    branch: main
    
  - owner: securebank
    repo: api-gateway
    branch: main

3. ## Token Security Options (Best → Worst)

### Option A: Secrets Manager (BEST)
```bash
# Token never touches disk or command line
aws secretsmanager get-secret-value --secret-id k8s-token | \
  jq -r '.SecretString' > /tmp/token.txt

python rotate_token.py --token-file /tmp/token.txt --config repos.yaml

rm /tmp/token.txt  # Clean up immediately
```

### Option B: File with Restricted Permissions
```bash
# Create token file with restricted permissions
touch /secure/token.txt
chmod 600 /secure/token.txt  # Only owner can read
echo "your-token-here" > /secure/token.txt

# Run script
python rotate_token.py --token-file /secure/token.txt --config repos.yaml

# Shred (secure delete) when done
shred -u /secure/token.txt
```

### Option C: Environment Variable
```bash
# Set in environment (visible in process list briefly)
export K8S_TOKEN="your-token-here"

# Modify script to read from env
python rotate_token.py --token-env K8S_TOKEN --config repos.yaml

# Unset immediately
unset K8S_TOKEN
```

### ❌ NEVER DO THIS
```bash
# Token visible in command history, process list, logs
python rotate_token.py --token "sk_live_actualtoken123"  # BAD
```

## GitHub Token (for API auth)

Same rules apply. Best practice:
```bash
# Store GitHub PAT in environment
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"

# Script reads from environment automatically
python rotate_token.py --token-file /secure/k8s-token.txt --config repos.yaml
```

### My Evaluation:
The script structure makes sense - it loops through repos, does the 3 steps for each, and tracks failures separately so you know exactly where things went wrong. The error handling with try/except and continue means one bad repo doesnt kill the whole rotation.

### What I Learned:
**Best practice for automation scripts:** the script needs to be *resilient* - meaning if step 2 fails, dont just crash. Log the failure, skip to the next item, and give a summary at the end. This way the operator knows exactly what needs manual attention.

Pattern I'll remember:
```python
results = {"success": [], "failed": []}
for item in items:
    try:
        do_thing(item)
        results["success"].append(item)
    except Exception as e:
        results["failed"].append(item)
        continue  # dont crash, keep going
print_report(results)
```

### How I Would Validate:
1. Test with a single repo first (make a test-repos.yaml with just one entry)
2. Check GitHub UI - did the secret actually update?
3. Check Actions tab - did the workflow run?
4. Check the pod - is it healthy with the new token?

### Could I Explain This in an Interview?
Not yet - I understand the concept but would need to practice explaining the API flow and encryption part.

### Confidence level: _3_/10

---
## TICKET-018 | [API]
**Time spent:** __ mins

### The Ask (in my words):
<!-- Can you explain what this ticket is asking WITHOUT jargon? -->
I believe the ticket is asking for the the possible reasons for their Trivy scanner to stop recieving findings. Reviewing logs and lack of human interactions its more so configuration or authorization issue due to the "invaild API Key" error message. 
### What I Tried First:
<!-- Before asking AI, what did YOU think the answer was? -->
First I would check if we have access to the vault and if the API key itself is still valid and not expired. 
### JSA/AI Solution:
<!-- What did the AI produce? -->
# Force restart to pick up current secret
kubectl rollout restart deployment/trivy-scanner
# OR for ECS
Immediate:


# Force restart to pick up current secret
kubectl rollout restart deployment/trivy-scanner
# OR for ECS
aws ecs update-service --service trivy-scanner --force-new-deployment

import boto3
import json

def get_api_key():
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId='dashboard-api-key')
    return json.loads(response['SecretString'])['api_key']

def send_findings(findings):
    response = requests.post(
        "https://security-dashboard.healthvault.io/api/v1/findings",
        json=findings,
        headers={"X-API-Key": get_api_key()}  # Fresh fetch each time
    )
    return response.status_code

### My Evaluation:
<!-- Is this RIGHT? How do you know? What would break? -->
Still relying on Claude to be correct. Makes sense that if the keys were rotated the old container would still pick up old cache. I had that problem when building my website of the website and container still using old image cache and not updating properly. Also makes sense to fetch curretn work API key to make sure this isnt an issue. A few seconds to check vs the Mean time to respond to tickets and resolve is worht the trade off. 
### What I Learned:
<!-- One concept I understand better now -->
Adding a get_key function instead of a hardcoded path to key will help in the long run if this issue ever occurs again. 
### Could I Explain This in an Interview? 
<!-- Yes/No - if No, what's the gap? -->
Yes. i understood from experience that is something has access one day and not the next its because the api key is expired. In this case guessing the have and automatic key rotation in place (security best practice) its smart to start the container each time with the fresh correct key. 
### Confidence level: _9_/10

## TICKET-019 | [HELM]
**Time spent:** __ mins

### What I Tried First:
<!-- Before asking AI, what did YOU think the answer was? -->
I would use AI to complete this task due to writing yaml faster and better than i could
### AI Solution:
<!-- What did the AI produce? -->
infrasec:
  resources:
    requests:
      cpu: "100m"      # Baseline when idle
      memory: "256Mi"  # Minimum for agent + cached results
    limits:
      cpu: "1000m"     # Allow burst to 1 CPU during scans
      memory: "1Gi"    # Headroom for large scan results in memory

### Deliverables: 
<!-- Answer to the questions-->
1. updated with requests: setting these mean the pod wont be evicted until node is under sever pressure. For Guaranteed space we use QoS class implications. trade off is having more eviction protection but wastes resources when idle. 
2. request = the minimum need for pod to run smoothly. limits = the most that single pod can use without being shut down. 
3. Profile > Start conservative > observe > tune 
Get as much info from developers and rule of thumb to create baseline values. provide conservative requests and limits . monitor how the pod is performing and adjust accordingly. like CPU throttling, OOMkilled restarts, low utilizaion and pod pending. 
### My Evaluation:
<!-- Is this RIGHT? How do you know? What would break? -->
Relying on AI to be correct. But i know about request and limits and this fix looks good to me. clear "rule of thumb" allocation. Now after being updated it will have to be monitored and tune correctly. 
### What I Learned:
<!-- One concept I understand better now -->
Profile > Start conservative > observe > tune. Using this method to guage how resources are allocated properly in the real world. 
### Could I Explain This in an Interview? 
<!-- Yes/No - if No, what's the gap? -->

### Confidence level: __/10

## TICKET-020 | [IAMROLES]
**Time spent:** __ mins


### What I Tried First:
<!-- Before asking AI, what did YOU think the answer was? -->
I never had to deal with IAM roles directly in this manner so im relying on AI.
### AI Solution:
<!-- What did the AI produce? -->
Absolutely. Below is **auditor-ready, FedRAMP-aligned guidance** you can drop directly into your SSP / IAM control narrative. This is written from a **security-first, reverse-engineering mindset** and matches what assessors actually look for.

---

# IAM Role Hygiene & Governance Strategy

**Purpose:** Reduce attack surface, enforce least privilege, and establish traceability for compliance (FedRAMP Moderate/High).

---

## 1. Identify Unused IAM Roles

### Auditor Concern

> “Are unused or dormant identities removed in a timely manner?”

Unused roles are a **privilege persistence risk** and a common FedRAMP finding.

---

### Method A — Last Used Analysis (Primary)

AWS tracks role usage automatically.

#### Console

* IAM → Roles → **Last activity**
* Look for:

  * `Last used: Never`
  * `Last used > 90 days ago`

#### CLI (Preferred for evidence)

```bash
aws iam list-roles \
  --query 'Roles[].{RoleName:RoleName,LastUsed:RoleLastUsed.LastUsedDate}'
```

**Interpretation**

* `null` → Role has **never been assumed**
* `>90 days` → Candidate for review or decommission

📌 **FedRAMP-friendly threshold:** 90 days (matches NIST AC-2 / IA-4 review cadence)

---

### Method B — CloudTrail Correlation (Authoritative)

Check if roles were actually assumed.

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRole
```

Then correlate:

* `userIdentity.arn`
* `requestParameters.roleArn`

**Result**

* No AssumeRole events → role is **effectively unused**

---

### Method C — Access Advisor (Service-Level)

For each role:

* IAM → Role → **Access Advisor**
* Shows which AWS services were accessed and **when**

Roles with **zero service access** are strong removal candidates.

---

### Required Documentation (FedRAMP Evidence)

| Field       | Example               |
| ----------- | --------------------- |
| Role Name   | `legacy-ci-role`      |
| Last Used   | Never                 |
| Decision    | Scheduled for removal |
| Owner       | Platform Engineering  |
| Review Date | YYYY-MM-DD            |

---

## 2. Identify Overly Permissive Roles (Wildcards)

### Auditor Concern

> “How do you prevent excessive permissions and privilege escalation?”

Wildcards are **explicitly scrutinized** in FedRAMP assessments.

---

### High-Risk Patterns (Immediate Findings)

Flag **any** policy containing:

#### Action Wildcards

```json
"Action": "*"
"Action": "iam:*"
```

#### Resource Wildcards

```json
"Resource": "*"
```

#### Combined (Critical)

```json
"Action": "*",
"Resource": "*"
```

---

### Automated Detection (CLI)

```bash
aws iam list-roles --query 'Roles[].RoleName' --output text | tr '\t' '\n' | while read role; do
  aws iam list-attached-role-policies --role-name $role
done
```

Then:

```bash
aws iam get-policy-version \
  --policy-arn <ARN> \
  --version-id v1
```

Scan for:

* `*`
* `iam:PassRole`
* `sts:AssumeRole` without conditions
* `ec2:*`, `s3:*`, `kms:*`

---

### High-Risk Permissions (FedRAMP Red Flags)

| Permission                  | Why It’s Dangerous      |
| --------------------------- | ----------------------- |
| `iam:PassRole`              | Privilege escalation    |
| `iam:CreatePolicy`          | Policy injection        |
| `sts:AssumeRole` (unscoped) | Lateral movement        |
| `kms:*`                     | Data exfiltration       |
| `ec2:*`                     | Infrastructure takeover |

---

### Required Mitigations

* Replace `*` with **explicit actions**
* Scope resources to:

  * Specific ARNs
  * Environment tags
* Add **conditions**:

```json
"Condition": {
  "StringEquals": {
    "aws:RequestedRegion": "us-east-1"
  }
}
```

---

### Required Documentation

| Role         | Finding    | Risk | Mitigation              |
| ------------ | ---------- | ---- | ----------------------- |
| `admin-role` | `Action:*` | High | Split into scoped roles |

---

## 3. IAM Role Naming Convention (FedRAMP-Ready)

### Auditor Concern

> “Can you quickly determine the purpose and scope of a role?”

If the name doesn’t explain **who / what / where / why**, it will be flagged.

---

### Recommended Naming Pattern

```
<env>-<account>-<service>-<function>-role
```

#### Examples

| Role Name                      | Meaning                   |
| ------------------------------ | ------------------------- |
| `prod-sec-ci-deploy-role`      | Production CI deployment  |
| `dev-app-s3-read-role`         | Dev app read-only S3      |
| `shared-audit-cloudtrail-role` | Centralized audit logging |

---

### Mandatory Tags (FedRAMP Evidence)

Every role **must** include:

```json
{
  "Owner": "team-name",
  "Purpose": "human-readable explanation",
  "Environment": "dev|stage|prod",
  "ReviewDate": "YYYY-MM-DD",
  "FedRAMP": "Moderate"
}
```

Auditors **love tags**. They map directly to accountability controls.

---

## 4. Ongoing Governance (What Auditors Really Want)

### Quarterly IAM Role Review (Control AC-2)

Checklist:

* [ ] Role still needed?
* [ ] Permissions still required?
* [ ] Last used < 90 days?
* [ ] Owner confirmed?

Automate with:

* AWS Config
* IAM Access Analyzer
* Security Hub custom controls

---

### Decommissioning Workflow

1. Disable trust policy
2. Observe for breakage (7–14 days)
3. Delete role
4. Log decision

---

## Executive Summary (Drop This in the SSP)

> The organization maintains a centralized IAM role governance program that identifies unused and overly permissive roles through automated analysis of IAM metadata, CloudTrail logs, and Access Advisor. Roles are reviewed quarterly, deprecated roles are removed within 90 days of inactivity, and all roles follow a standardized naming and tagging convention aligned with least privilege and FedRAMP requirements.




### Deliverables: 
<!-- Answer to the questions-->
1. aws iam list-roles \
  --query 'Roles[].{RoleName:RoleName,LastUsed:RoleLastUsed.LastUsedDate}' \
  --output table
2. aws iam list-roles --query 'Roles[].RoleName' --output text | tr '\t' '\n'
"Action": "*"
"Action": "iam:*"
"Resource": "*"
3. <env>-<service>-<purpose>-role
4. The minimum process auditors expect
Quarterly IAM Role Review, 
-Roles not used in 90 days → flagged
-Wildcard permissions → removed or justified
-Owner must approve role continued existence
-Automated controls (best practice)

IAM Access Analyzer → permission risk
AWS Config rules:
-No Action:*
-No Resource:*
-Security Hub → continuous findings
-Decommissioning workflow
-Disable trust policy
-Wait 7–14 days
-Delete role
-Record decision


### My Evaluation:
<!-- Is this RIGHT? How do you know? What would break? -->
Still using AI to answer non data sensative questions like this one. Command are correct 
### What I Learned:
<!-- One concept I understand better now -->
How to indentify unused IAM roles. Having a IAM Role review checklist is good because it reduces attack surface and confirms if permissions are still being used properly. 
### Could I Explain This in an Interview? 
<!-- Yes/No - if No, what's the gap? -->
no
### Confidence level: _5_/10

# 🎤 INTERVIEW QUESTIONS (3)

*Answer these as if you're in an interview. Speak out loud or write as you would explain verbally. Structure matters.*

---

### INTERVIEW-01 | Explain a Concept
**Interviewer:** "Can you explain what Pod Security Standards are in Kubernetes and why they matter?"

**Your Task:**
- Explain PSS to someone who knows Kubernetes but not security
- Cover the three levels (Privileged, Baseline, Restricted)
- Give a real-world example of when you'd use each
- Mention how it relates to Pod Security Admission

**Format:** 2-3 minute verbal explanation (write it out as you'd say it)

### ANSWER:
PSS is a best practice set of standards that grant minimum permissions and privileges to pods that require them. These standards are enforced using Pod Security Admission, which applies them via namespace labels in warn, audit, or enforce mode. That lets teams roll security out safely without breaking workloads.
---

### INTERVIEW-02 | Troubleshooting Scenario
**Interviewer:** "Walk me through how you would troubleshoot a Kubernetes pod that keeps getting OOMKilled."

**Your Task:**
- Describe your systematic approach
- What commands would you run first?
- How do you determine if it's a memory leak vs undersized limits?
- What's your fix strategy?

**Format:** Step-by-step walkthrough as you'd explain to an interviewer

### ANSWER:
 I confirm it’s an OOMKill, verify memory limits, check actual usage, identify whether the pattern is a leak or load-related, apply a safe short-term mitigation, and then drive a permanent fix through code or tuning
---

### INTERVIEW-03 | Architecture Design
**Interviewer:** "If you were designing a secrets management strategy for a Kubernetes cluster, what would you consider?"

**Your Task:**
- Cover at least 3 different approaches (native secrets, external secrets, vault, etc.)
- Discuss trade-offs of each
- What would influence your recommendation?
- How would compliance requirements (HIPAA, PCI) affect your choice?

**Format:** Structured answer with clear reasoning

### ANSWER: 

Secrets management isn’t just a tool choice — it’s a balance of threat model, compliance, and operational maturity. In regulated environments, I prefer external or dynamic secrets with strong auditability, and I treat native Kubernetes Secrets as a convenience layer, not a security boundary.
<!------------------- END TICKET BLOCK ----------------------------------->

## Self-Assessment

**Tickets completed:** __/N
**Total time:** __ mins
**Hardest ticket:** TICKET-___
**Most confident:** TICKET-___
**Need to study more:** API , AUtomation , best practices 
