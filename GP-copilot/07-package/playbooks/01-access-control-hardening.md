# Playbook 01: Access Control Hardening
### Controls: AC-2, AC-3, AC-6, AC-17

---

## WHAT THIS COVERS

| Control | Name | What the assessor checks |
|---------|------|------------------------|
| AC-2 | Account Management | User accounts are managed, reviewed, disabled when not needed |
| AC-3 | Access Enforcement | System enforces approved authorizations |
| AC-6 | Least Privilege | Users/processes have minimum necessary permissions |
| AC-17 | Remote Access | Remote access is controlled and encrypted |

---

## AC-2: ACCOUNT MANAGEMENT

### What "compliant" looks like
- Every user/service account is documented and has a business justification
- Accounts are reviewed periodically (quarterly minimum)
- Inactive accounts are disabled or removed
- No shared accounts

### Step 1: Audit existing accounts

**Kubernetes RBAC**
```bash
# List all ClusterRoleBindings — who has cluster-wide access?
kubectl get clusterrolebindings -o custom-columns=\
"NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name"

# Find cluster-admin bindings (these are B-rank — must justify each one)
kubectl get clusterrolebindings -o json | \
  jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name + " → " + (.subjects[]?.name // "unknown")'

# List all RoleBindings per namespace
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $ns ==="
  kubectl get rolebindings -n "$ns" -o custom-columns=\
"NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name" 2>/dev/null
done

# List all ServiceAccounts
kubectl get serviceaccounts -A -o custom-columns=\
"NAMESPACE:.metadata.namespace,NAME:.metadata.name"
```

**AWS IAM**
```bash
# List all IAM users
aws iam list-users --query 'Users[*].[UserName,CreateDate,PasswordLastUsed]' --output table

# Find users without MFA
aws iam generate-credential-report
aws iam get-credential-report --query 'Content' --output text | base64 -d | \
  awk -F',' '$4=="true" && $8=="false" {print "NO MFA:", $1}'

# Find inactive users (no login in 90+ days)
aws iam generate-credential-report
aws iam get-credential-report --query 'Content' --output text | base64 -d | \
  awk -F',' 'NR>1 && $5!="N/A" {print $1, $5}' | while read user last_used; do
    days_ago=$(( ($(date +%s) - $(date -d "$last_used" +%s)) / 86400 ))
    if [ "$days_ago" -gt 90 ]; then
      echo "INACTIVE ($days_ago days): $user"
    fi
  done

# List access keys older than 90 days
aws iam generate-credential-report
aws iam get-credential-report --query 'Content' --output text | base64 -d | \
  awk -F',' 'NR>1 && $9=="true" {print $1, "Key1:", $10}' | while read user label date; do
    days_ago=$(( ($(date +%s) - $(date -d "$date" +%s)) / 86400 ))
    if [ "$days_ago" -gt 90 ]; then
      echo "STALE KEY ($days_ago days): $user"
    fi
  done
```

### Step 2: Fix what you found

**Remove unnecessary cluster-admin bindings**
```bash
# For each cluster-admin binding that isn't system-critical:
kubectl delete clusterrolebinding <name>

# Replace with scoped role
kubectl create rolebinding <user>-edit \
  --clusterrole=edit \
  --user=<user> \
  --namespace=<namespace>
```

**Disable inactive IAM users**
```bash
# Deactivate console access
aws iam delete-login-profile --user-name <username>

# Deactivate access keys
aws iam update-access-key --user-name <username> --access-key-id <key-id> --status Inactive
```

**Remove default ServiceAccount token automounting**
```yaml
# Every namespace should have this
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
  namespace: <namespace>
automountServiceAccountToken: false
```

### Step 3: Establish ongoing review process

```bash
# Create a quarterly account review script
# Save as: scripts/quarterly-account-review.sh

#!/bin/bash
echo "=== QUARTERLY ACCOUNT REVIEW: $(date +%Y-%m-%d) ==="
echo ""

echo "--- K8s cluster-admin bindings ---"
kubectl get clusterrolebindings -o json | \
  jq -r '.items[] | select(.roleRef.name=="cluster-admin") |
    "  " + .metadata.name + " → " + (.subjects[]?.name // "unknown")'

echo ""
echo "--- IAM users without MFA ---"
aws iam generate-credential-report > /dev/null 2>&1
sleep 5
aws iam get-credential-report --query 'Content' --output text | base64 -d | \
  awk -F',' '$4=="true" && $8=="false" {print "  NO MFA:", $1}'

echo ""
echo "--- Inactive IAM users (90+ days) ---"
aws iam get-credential-report --query 'Content' --output text | base64 -d | \
  awk -F',' 'NR>1 && $5!="N/A" {
    cmd = "echo $(( ($(date +%s) - $(date -d \"" $5 "\" +%s)) / 86400 ))"
    cmd | getline days; close(cmd)
    if (days > 90) print "  INACTIVE (" days " days):", $1
  }'

echo ""
echo "--- K8s ServiceAccounts with token automount ---"
kubectl get serviceaccounts -A -o json | \
  jq -r '.items[] | select(.automountServiceAccountToken != false) |
    "  " + .metadata.namespace + "/" + .metadata.name'
```

### Evidence for the assessor
- Account inventory spreadsheet (who, what role, business justification)
- Quarterly review logs (script output + sign-off)
- Screenshots/logs of disabled accounts
- RBAC policy documentation

---

## AC-3: ACCESS ENFORCEMENT

### What "compliant" looks like
- System enforces authorization decisions (not just documented — enforced)
- RBAC is active on the cluster
- API access requires authentication
- No anonymous access

### Step 1: Verify RBAC is enforced

```bash
# Confirm RBAC is enabled (should be by default on modern clusters)
kubectl api-versions | grep rbac

# Check for anonymous access
kubectl auth can-i list pods --as=system:anonymous
# Should return: no

# Check for unauthenticated API access
kubectl auth can-i list pods --as=system:unauthenticated
# Should return: no
```

### Step 2: Apply least-privilege RBAC templates

```yaml
# Application ServiceAccount — only what it needs
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: app-namespace
automountServiceAccountToken: false
---
# Read-only role for the app
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: app-namespace
rules:
  - apiGroups: [""]
    resources: ["configmaps", "secrets"]
    resourceNames: ["app-config", "app-secrets"]  # specific resources only
    verbs: ["get"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]    # read-only, no create/delete
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-role-binding
  namespace: app-namespace
subjects:
  - kind: ServiceAccount
    name: app-sa
    namespace: app-namespace
roleRef:
  kind: Role
  name: app-role
  apiGroup: rbac.authorization.k8s.io
```

### Step 3: Enforce with admission control

Use the RBAC templates from:
`templates/remediation-templates/rbac-templates.yaml`

---

## AC-6: LEAST PRIVILEGE

### What "compliant" looks like
- No process runs with more permissions than needed
- No containers run as root
- No wildcard RBAC verbs or resources
- Capabilities are dropped

### Step 1: Find violations

```bash
# Find pods running as root
kubectl get pods -A -o json | \
  jq -r '.items[] | select(
    .spec.containers[]?.securityContext?.runAsNonRoot != true and
    .spec.securityContext?.runAsNonRoot != true
  ) | .metadata.namespace + "/" + .metadata.name'

# Find privileged containers
kubectl get pods -A -o json | \
  jq -r '.items[] | select(
    .spec.containers[]?.securityContext?.privileged == true
  ) | .metadata.namespace + "/" + .metadata.name'

# Find RBAC with wildcard verbs
kubectl get clusterroles -o json | \
  jq -r '.items[] | select(.rules[]?.verbs[]? == "*") | .metadata.name'

# Find RBAC with wildcard resources
kubectl get clusterroles -o json | \
  jq -r '.items[] | select(.rules[]?.resources[]? == "*") | .metadata.name'
```

### Step 2: Fix pods — apply security contexts

```yaml
# Minimum security context for every container
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
```

Use the fixer from GP-CONSULTING:
```bash
# Auto-add security contexts to manifests
/path/to/GP-CONSULTING/02-CLUSTER-HARDENING/tools/hardening/add-security-context.sh <manifest.yaml>
```

### Step 3: Enforce with Kyverno

Deploy the policies from `templates/policies-templates/kyverno/`:
```bash
kubectl apply -f templates/policies-templates/kyverno/disallow-privileged.yaml
kubectl apply -f templates/policies-templates/kyverno/disallow-privilege-escalation.yaml
kubectl apply -f templates/policies-templates/kyverno/require-run-as-nonroot.yaml
kubectl apply -f templates/policies-templates/kyverno/require-drop-all.yaml
kubectl apply -f templates/policies-templates/kyverno/require-resource-limits.yaml
```

### Evidence for the assessor
- `kubectl get pods -A -o yaml` showing all security contexts
- Kyverno policy list showing enforcement
- RBAC audit showing no wildcards
- Container scan showing non-root user in Dockerfiles

---

## AC-17: REMOTE ACCESS

### What "compliant" looks like
- All remote access to the system is encrypted (TLS/SSH)
- VPN or private network for cluster access
- No direct internet-facing API server
- kubectl access via SSO/OIDC, not static tokens

### Step 1: Verify encryption

```bash
# Check API server is TLS
kubectl cluster-info
# Should show https:// URLs

# Check for public API server endpoint
aws eks describe-cluster --name <cluster> --query 'cluster.resourcesVpcConfig.endpointPublicAccess'
# Should be: false (or restricted to specific CIDRs)

# Check for public services
kubectl get svc -A -o json | \
  jq -r '.items[] | select(.spec.type=="LoadBalancer" or .spec.type=="NodePort") |
    .metadata.namespace + "/" + .metadata.name + " (" + .spec.type + ")"'
```

### Step 2: Lock down access

```bash
# Restrict EKS public endpoint to your CIDRs only
aws eks update-cluster-config \
  --name <cluster> \
  --resources-vpc-config endpointPublicAccess=true,publicAccessCidrs="10.0.0.0/8","192.168.1.0/24"

# Or disable public endpoint entirely (require VPN)
aws eks update-cluster-config \
  --name <cluster> \
  --resources-vpc-config endpointPublicAccess=false,endpointPrivateAccess=true
```

### Evidence for the assessor
- Network diagram showing encrypted paths
- EKS cluster config showing private endpoint
- VPN configuration documentation
- OIDC/SSO configuration for kubectl access

---

## COMPLETION CHECKLIST

```
[ ] AC-2: Account inventory documented with business justifications
[ ] AC-2: Quarterly review process established and first review completed
[ ] AC-2: Inactive accounts disabled
[ ] AC-2: No shared accounts
[ ] AC-3: RBAC verified active, no anonymous access
[ ] AC-3: Application-specific roles created (no cluster-admin for apps)
[ ] AC-6: All pods run as non-root
[ ] AC-6: All containers drop ALL capabilities
[ ] AC-6: No wildcard RBAC verbs or resources
[ ] AC-6: Kyverno policies enforcing least privilege
[ ] AC-17: All remote access encrypted (TLS)
[ ] AC-17: API server not publicly accessible (or CIDR-restricted)
[ ] AC-17: kubectl access via SSO/OIDC
```
