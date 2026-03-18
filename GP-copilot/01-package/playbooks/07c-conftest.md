# Playbook 07c: Deploy OPA / Conftest Policy Gate

> Deploy Conftest OPA policies into the client repo and wire them into CI.
> This is the pre-deployment policy layer — no cluster required.
> Conftest catches bad manifests **before** they reach Kubernetes.
>
> **When:** After CI pipeline is deployed (07), alongside other scanning configs (07a)
> **Time:** ~10 min
> **Agent:** jsa-devsec (D-rank — deterministic file copy + policy validation)
> **Layer:** CI/CD gate (Layer 1 of 3 — see 02-CLUSTER-HARDENING for Layer 2 admission control)

---

## Policy File Location

Everything lives here. One file, one source of truth:

```
GP-CONSULTING/01-APP-SEC/
└── scanning-configs/
│   └── conftest-policy.rego        ← THE POLICY (constraints live here)
└── scanners/
│   └── conftest_scan_npc.py        ← Scanner wrapper (used in run-all-scanners.sh)
└── playbooks/
    └── 07c-conftest.md             ← This file
```

**Full path to policy:**
```
/home/jimmie/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/scanning-configs/conftest-policy.rego
```

**Full path to scanner NPC:**
```
/home/jimmie/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/scanners/conftest_scan_npc.py
```

---

## What Conftest Checks (All Constraints)

The policy is in `package main` and uses `deny` (blocks) and `warn` (flags) rules.

### Kubernetes — Pod / Deployment / StatefulSet / DaemonSet

| Rule | Type | Triggers On |
|------|------|-------------|
| Privileged container | `deny` | `securityContext.privileged == true` |
| Running as root | `deny` | `securityContext.runAsNonRoot` missing |
| Privilege escalation | `deny` | `securityContext.allowPrivilegeEscalation == true` |
| `:latest` image tag | `deny` | `image` ends with `:latest` |
| Untrusted registry | `deny` | image not in trusted list (docker.io, ghcr.io, gcr.io, registry.k8s.io, quay.io) |
| Dangerous capabilities | `deny` | `capabilities.add` includes `SYS_ADMIN`, `NET_ADMIN`, `SYS_MODULE` |
| Missing resource limits | `warn` | `resources.limits` absent |
| Missing resource requests | `warn` | `resources.requests` absent |
| Missing liveness probe | `warn` | `livenessProbe` absent on Deployment container |
| Missing readiness probe | `warn` | `readinessProbe` absent on Deployment container |

### Kubernetes — Network

| Rule | Type | Triggers On |
|------|------|-------------|
| Namespace missing NetworkPolicy | `warn` | Namespace kind with no NetworkPolicy present |
| LoadBalancer service | `warn` | `Service.spec.type == "LoadBalancer"` |
| NodePort service | `warn` | `Service.spec.type == "NodePort"` |

### Kubernetes — RBAC

| Rule | Type | Triggers On |
|------|------|-------------|
| Wildcard ClusterRole | `deny` | `verbs[*] == "*"` AND `resources[*] == "*"` |
| cluster-admin binding | `deny` | `ClusterRoleBinding.roleRef.name == "cluster-admin"` |

### Terraform — HCL config format (`.tf` files)

| Rule | Type | Triggers On |
|------|------|-------------|
| Unencrypted S3 bucket | `deny` | `aws_s3_bucket` missing `server_side_encryption_configuration` |
| Public S3 bucket | `deny` | `aws_s3_bucket.acl == "public-read"` |
| Open security group | `deny` | `aws_security_group` ingress with `cidr_blocks = 0.0.0.0/0` |

### Terraform — plan JSON format (`terraform show -json`)

| Rule | Type | Triggers On |
|------|------|-------------|
| Unencrypted S3 (plan) | `deny` | `aws_s3_bucket` — `server_side_encryption_configuration` absent or `[]` |
| Public ACL S3 (plan) | `deny` | `aws_s3_bucket.acl == "public-read"` |
| Public access block off (plan) | `deny` | `aws_s3_bucket_public_access_block.block_public_acls == false` |
| Ignore public ACLs off (plan) | `deny` | `aws_s3_bucket_public_access_block.ignore_public_acls == false` |
| Open SG ingress IPv4 (plan) | `deny` | `aws_security_group` ingress `cidr_blocks = 0.0.0.0/0` |
| Open SG ingress IPv6 (plan) | `deny` | `aws_security_group` ingress `ipv6_cidr_blocks = ::/0` |
| RDS unencrypted storage (plan) | `deny` | `aws_db_instance.storage_encrypted == false` |
| RDS publicly accessible (plan) | `deny` | `aws_db_instance.publicly_accessible == true` |
| IAM wildcard action (plan) | `deny` | `aws_iam_policy` with `"Action": "*"` in statement |
| Open SG rule (plan) | `warn` | `aws_security_group_rule` ingress with `cidr_blocks = 0.0.0.0/0` |
| RDS no deletion protection (plan) | `warn` | `aws_db_instance.deletion_protection == false` |

### Dockerfile

| Rule | Type | Triggers On |
|------|------|-------------|
| Root USER | `deny` | `USER root` in Dockerfile |
| `:latest` base image | `warn` | `FROM` uses `:latest` tag |

### GitHub Actions

| Rule | Type | Triggers On |
|------|------|-------------|
| Unpinned action | `deny` | `uses:` without `@` version pin |
| `write-all` permissions | `warn` | `permissions: write-all` at workflow level |

---

## Step 1: Install Conftest (One-Time)

```bash
# macOS
brew install conftest

# Linux
wget https://github.com/open-policy-agent/conftest/releases/download/v0.50.0/conftest_0.50.0_Linux_x86_64.tar.gz
tar xzf conftest_0.50.0_Linux_x86_64.tar.gz
sudo mv conftest /usr/local/bin/

# Verify
conftest --version
```

---

## Step 2: Deploy Policy to Client Repo

```bash
cd <client-repo>

# Create policy directory
mkdir -p policy/

# Copy the base policy from our package
cp /home/jimmie/linkops-industries/GP-copilot/GP-CONSULTING/01-APP-SEC/scanning-configs/conftest-policy.rego \
   policy/conftest-policy.rego

# Confirm it landed
ls -la policy/
```

---

## Step 3: Run the Policy Against Client Manifests

### Kubernetes manifests
```bash
# Test against K8s manifests directory
conftest test k8s/ --policy policy/

# Test against a single file
conftest test k8s/deployment.yaml --policy policy/

# JSON output (for pipeline integration)
conftest test k8s/ --policy policy/ --output json

# Fail only on deny (not warn)
conftest test k8s/ --policy policy/ --fail-on-warn=false
```

### Terraform — raw .tf files (HCL config format)
```bash
# Test Terraform config files directly
conftest test terraform/ --policy policy/
conftest test terraform/main.tf --policy policy/
```

### Terraform — plan JSON format (recommended for CI)

The plan JSON format gives you the exact state Terraform **will create** — not just what's written in .tf files. This catches dynamic values and module outputs that HCL parsing misses.

```bash
# Step 1: Generate a plan
terraform -chdir=terraform/ init
terraform -chdir=terraform/ plan -out=tfplan

# Step 2: Convert to JSON
terraform -chdir=terraform/ show -json tfplan > plan.json

# Step 3: Run conftest against the plan JSON
conftest test plan.json --policy policy/

# Step 4: JSON output for CI artifact
conftest test plan.json --policy policy/ --output json | tee conftest-tf-results.json

# One-liner for CI pipelines
terraform -chdir=terraform/ plan -out=tfplan \
  && terraform -chdir=terraform/ show -json tfplan \
  | conftest test - --policy policy/
```

**Why plan JSON over .tf files:**

| | HCL `.tf` files | Plan JSON |
|-|----------------|-----------|
| What it checks | Written config | Terraform's resolved plan |
| Catches module outputs | No | Yes |
| Catches dynamic values | No | Yes |
| Requires `terraform init` | No | Yes |
| Works on PR (no cloud creds needed) | Yes | Yes (with `-refresh=false`) |

### Dockerfiles
```bash
conftest test Dockerfile --policy policy/
```

### GitHub Actions workflows
```bash
conftest test .github/workflows/ --policy policy/
```

**Reading the output:**
```
FAIL - k8s/deployment.yaml - main - Privileged container not allowed: nginx     ← deny (blocks CI)
FAIL - plan.json - main - S3 bucket missing encryption (plan): aws_s3_bucket.data  ← deny
WARN - k8s/deployment.yaml - main - Container missing resource limits: nginx    ← warn (flags only)
```

---

## Step 4: Verify — Test the Policy Itself

Conftest supports `conftest verify` to run unit tests against the policy rules.

### Write a test fixture (bad manifest that MUST be denied):

```bash
mkdir -p policy/tests/fixtures/

# Bad deployment — should trigger deny rules
cat > policy/tests/fixtures/bad-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-app
spec:
  template:
    spec:
      containers:
      - name: bad-container
        image: nginx:latest
        securityContext:
          privileged: true
          allowPrivilegeEscalation: true
EOF

# Good deployment — should pass all deny rules
cat > policy/tests/fixtures/good-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: good-app
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: good-container
        image: ghcr.io/myorg/myapp:v1.2.3
        securityContext:
          allowPrivilegeEscalation: false
          privileged: false
        resources:
          limits:
            cpu: "500m"
            memory: "256Mi"
          requests:
            cpu: "100m"
            memory: "128Mi"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
EOF
```

### Write the Rego test file:

```bash
cat > policy/conftest-policy_test.rego << 'EOF'
package main

import future.keywords.if

# --- DENY tests ---

test_deny_privileged_container if {
    deny["Privileged container not allowed: bad-container"] with input as {
        "kind": "Deployment",
        "spec": {"template": {"spec": {"containers": [
            {"name": "bad-container", "securityContext": {"privileged": true}}
        ]}}}
    }
}

test_deny_latest_tag if {
    deny[_] with input as {
        "kind": "Deployment",
        "spec": {"template": {"spec": {"containers": [
            {"name": "app", "image": "nginx:latest"}
        ]}}}
    }
}

test_deny_cluster_admin_binding if {
    deny["Binding to cluster-admin not allowed"] with input as {
        "kind": "ClusterRoleBinding",
        "roleRef": {"name": "cluster-admin"}
    }
}

test_deny_wildcard_clusterrole if {
    deny["ClusterRole grants wildcard permissions"] with input as {
        "kind": "ClusterRole",
        "rules": [{"verbs": ["*"], "resources": ["*"]}]
    }
}

# --- PASS tests (good manifests should NOT trigger deny) ---

test_allow_good_deployment if {
    count(deny) == 0 with input as {
        "kind": "Deployment",
        "spec": {"template": {"spec": {
            "securityContext": {"runAsNonRoot": true},
            "containers": [{
                "name": "app",
                "image": "ghcr.io/myorg/myapp:v1.2.3",
                "securityContext": {
                    "privileged": false,
                    "allowPrivilegeEscalation": false
                },
                "resources": {
                    "limits": {"cpu": "500m", "memory": "256Mi"},
                    "requests": {"cpu": "100m", "memory": "128Mi"}
                }
            }]
        }}}
    }
}
EOF
```

### Run the tests:

```bash
# Run Rego unit tests
conftest verify --policy policy/

# Expected output:
# PASS - 5/5 - conftest-policy_test.rego

# Test against fixture files
conftest test policy/tests/fixtures/bad-deployment.yaml --policy policy/
# Expected: FAIL (deny rules fire)

conftest test policy/tests/fixtures/good-deployment.yaml --policy policy/
# Expected: PASS (no deny rules fire, some warns OK)
```

---

## Step 5: Add Exceptions for Client-Specific Cases

Some clients have legitimate exceptions (logging DaemonSets needing hostPath, etc.). Document every exception:

```rego
# In policy/conftest-policy.rego — add exception for known-good cases

# Exception: logging agent DaemonSet needs SYS_ADMIN
# Approved by: client-team, 2026-03-16
# Ticket: SEC-142
deny contains msg if {
    input.kind == "DaemonSet"
    container := input.spec.template.spec.containers[_]
    container.securityContext.privileged == true
    # Exception: allow for known logging DaemonSets only
    not container.name in ["fluentbit", "datadog-agent", "falco"]
    msg := sprintf("Privileged container not allowed: %s", [container.name])
}
```

---

## Step 6: Wire Into CI

```yaml
# .github/workflows/security.yml — add conftest step

    - name: OPA Policy Check (Conftest)
      run: |
        conftest test k8s/ --policy policy/ --output json | tee conftest-results.json
        # Exit code 1 = deny violations (fails the pipeline)
        # Exit code 0 = pass (warn-only violations don't block)

    - name: Upload Conftest Results
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: conftest-results
        path: conftest-results.json
```

Our `full-security-pipeline.yml` template (from playbook 07) already includes this step.

---

## Step 7: Commit to Client Repo

```bash
git add \
  policy/conftest-policy.rego \
  policy/conftest-policy_test.rego \
  policy/tests/fixtures/bad-deployment.yaml \
  policy/tests/fixtures/good-deployment.yaml

git commit -m "security: add OPA/Conftest policy gate with tests

- policy/conftest-policy.rego: 20 rules (K8s, Terraform, Dockerfile, GHA)
- policy/conftest-policy_test.rego: unit tests for all deny rules
- fixtures: bad/good deployment manifests for manual verification
- CI: conftest step in security pipeline

Deny rules block: privileged containers, root USER, :latest tags,
  untrusted registries, dangerous capabilities, wildcard RBAC,
  cluster-admin bindings, open S3 buckets, open security groups
Warn rules flag: missing limits/probes, NodePort/LoadBalancer services"
```

---

## Quick Reference — All File Paths

```
POLICY SOURCE (our package — edit here, deploy to client):
  GP-CONSULTING/01-APP-SEC/scanning-configs/conftest-policy.rego
  GP-CONSULTING/01-APP-SEC/scanning-configs/conftest-policy_test.rego

DEPLOYED TO CLIENT REPO:
  policy/conftest-policy.rego               ← constraints (all rules)
  policy/conftest-policy_test.rego          ← rego unit tests (38 tests)
  policy/tests/fixtures/bad-deployment.yaml  ← fixture: must fail K8s
  policy/tests/fixtures/good-deployment.yaml ← fixture: must pass K8s
  policy/tests/fixtures/bad-plan.json        ← fixture: must fail Terraform plan
  policy/tests/fixtures/good-plan.json       ← fixture: must pass Terraform plan

SCANNER NPC (used in run-all-scanners.sh):
  GP-CONSULTING/01-APP-SEC/scanners/conftest_scan_npc.py

CI TEMPLATE (wired in playbook 07):
  GP-CONSULTING/01-APP-SEC/ci-templates/full-security-pipeline.yml

RUN TESTS:
  conftest verify --policy policy/                                # unit tests (38/38)
  conftest test k8s/ --policy policy/                            # K8s manifests
  conftest test Dockerfile --policy policy/                      # Dockerfile
  terraform show -json tfplan | conftest test - --policy policy/ # Terraform plan JSON
```

---

## Relationship to Other Policy Layers

```
LAYER 1 — This playbook (01-APP-SEC/07c)
  Conftest in CI/CD
  Blocks bad manifests BEFORE they reach the cluster
  No cluster needed

LAYER 2 — 02-CLUSTER-HARDENING/playbooks/06-deploy-admission-control.md
  Kyverno OR OPA Gatekeeper in the cluster
  Blocks bad deployments AT the API server (kubectl apply)
  Requires cluster access

LAYER 3 — 03-DEPLOY-RUNTIME
  Falco + jsa-infrasec watchers
  Detects policy DRIFT after deployment
  Runtime only
```

If you need admission control (Layer 2), go to:
```
GP-CONSULTING/02-CLUSTER-HARDENING/playbooks/06-deploy-admission-control.md
GP-CONSULTING/02-CLUSTER-HARDENING/templates/policies/kyverno/
GP-CONSULTING/02-CLUSTER-HARDENING/templates/policies/gatekeeper/
```

---

## Next Steps

- Wire scanning configs (non-OPA)? → [07a-deploy-security-configs.md](07a-deploy-security-configs.md)
- Deploy pre-commit hooks? → [08-deploy-pre-commit.md](08-deploy-pre-commit.md)
- Deploy cluster admission control? → [02-CLUSTER-HARDENING/playbooks/06-deploy-admission-control.md](../../02-CLUSTER-HARDENING/playbooks/06-deploy-admission-control.md)

---

*Ghost Protocol — Pre-Deployment Security Package*
