# Playbook 05 — EKS Security Hardening

> Harden an existing EKS cluster beyond AWS defaults. This is what we bring — every item here is required for production.
>
> **When:** Immediately after Playbook 04 (cluster is running, nodes are ready).
> **Audience:** Platform engineers and security consultants.
> **Time:** ~45 min (some changes trigger rolling updates)

> **Golden Rule:** EKS out of the box is not secure. Every item on the checklist at the end of this playbook is required for production.

---

## Prerequisites

| Prerequisite | How to Verify |
|---|---|
| EKS cluster running (Playbook 04) | `aws eks describe-cluster --name ${CLUSTER_NAME} --query 'cluster.status'` |
| kubectl configured | `kubectl get nodes` |
| KMS key available | `aws kms describe-key --key-id alias/${PROJECT}-eks` |
| VPN/bastion/SSM access to private VPC | Can reach private subnets (needed after Step 1) |

```bash
export PROJECT="anthra"
export REGION="us-east-1"
export CLUSTER_NAME="${PROJECT}-eks"
```

---

## Step 1: Private API Endpoint

Lock the Kubernetes API to private access only. No public internet exposure.

```bash
# BEFORE you do this — confirm you have private VPC access
# via VPN, bastion host, or SSM Session Manager.
# If you lock the endpoint and can't reach the VPC, you lose kubectl access.

# Verify current endpoint config
aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} \
  --query 'cluster.resourcesVpcConfig.{Public:endpointPublicAccess,Private:endpointPrivateAccess}' \
  --output table

# Disable public, enable private
aws eks update-cluster-config \
  --name ${CLUSTER_NAME} \
  --region ${REGION} \
  --resources-vpc-config endpointPublicAccess=false,endpointPrivateAccess=true

# Wait for update to complete
aws eks wait cluster-active --name ${CLUSTER_NAME} --region ${REGION}

# Verify (must be connected to private VPC to run this)
kubectl cluster-info
```

> **Rollback:** If you lose access, use the AWS Console or a Lambda in the VPC to re-enable public access temporarily.

---

## Step 2: Control Plane Logging

Enable all five EKS log types. These go to CloudWatch and are critical for audit trails.

```bash
# Check current logging
aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} \
  --query 'cluster.logging.clusterLogging[*].{Types:types,Enabled:enabled}' \
  --output table

# Enable all 5 log types
aws eks update-cluster-config \
  --name ${CLUSTER_NAME} \
  --region ${REGION} \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'

aws eks wait cluster-active --name ${CLUSTER_NAME} --region ${REGION}
```

Verify logs are flowing:

```bash
# Check CloudWatch log group exists
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/eks/${CLUSTER_NAME}/cluster" \
  --query 'logGroups[*].{Name:logGroupName,Retention:retentionInDays,StoredBytes:storedBytes}' \
  --output table

# Check log streams are active (give it 2-3 minutes after enabling)
aws logs describe-log-streams \
  --log-group-name "/aws/eks/${CLUSTER_NAME}/cluster" \
  --order-by LastEventTime \
  --descending \
  --limit 5 \
  --query 'logStreams[*].{Stream:logStreamName,LastEvent:lastEventTimestamp}' \
  --output table
```

| Log Type | What It Captures | Why It Matters |
|---|---|---|
| `api` | API server requests | Who did what to the cluster |
| `audit` | Detailed audit trail | FedRAMP AU-2 compliance |
| `authenticator` | IAM authentication events | Failed auth attempts, privilege escalation |
| `controllerManager` | Controller operations | Deployment failures, scaling events |
| `scheduler` | Pod scheduling decisions | Resource contention, affinity issues |

---

## Step 3: Secrets Encryption (Envelope Encryption)

EKS encrypts etcd at rest by default, but secrets are only base64-encoded. Envelope encryption adds a second layer using your KMS key.

```bash
export KMS_KEY_ARN=$(aws kms describe-key --key-id alias/${PROJECT}-eks \
  --query 'KeyMetadata.Arn' --output text)

# Associate encryption config
aws eks associate-encryption-config \
  --cluster-name ${CLUSTER_NAME} \
  --region ${REGION} \
  --encryption-config '[{"resources":["secrets"],"provider":{"keyArn":"'"${KMS_KEY_ARN}"'"}}]'

# Wait — this can take 10-15 minutes
echo "Waiting for encryption association (up to 15 min)..."
aws eks wait cluster-active --name ${CLUSTER_NAME} --region ${REGION}

# Verify encryption is enabled
aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} \
  --query 'cluster.encryptionConfig[*].{Resources:resources,KeyArn:provider.keyArn}' \
  --output table
```

> **Warning:** This is a one-way operation. Once envelope encryption is enabled, it cannot be removed. Existing secrets are re-encrypted on next write; force re-encryption of all secrets:

```bash
# Re-encrypt all existing secrets
kubectl get secrets --all-namespaces -o json | \
  kubectl replace -f -
```

---

## Step 4: IRSA (IAM Roles for Service Accounts)

IRSA eliminates the need for node-level IAM permissions. Each pod gets exactly the AWS access it needs — nothing more.

### 4a: Verify OIDC Provider

```bash
# Confirm OIDC provider exists (created in Playbook 04, Step 7)
export OIDC_ID=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} \
  --query 'cluster.identity.oidc.issuer' --output text | cut -d'/' -f5)

aws iam list-open-id-connect-providers | grep ${OIDC_ID}
# Must return an ARN. If empty, go back to Playbook 04 Step 7.
```

### 4b: Create an IRSA Role (Example: S3 Read-Only for Log Ingest)

```bash
export ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
export NAMESPACE="log-ingest"
export SERVICE_ACCOUNT="log-ingest-sa"

# Create trust policy scoped to specific namespace:serviceaccount
cat > /tmp/irsa-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT}",
          "oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name ${PROJECT}-irsa-log-ingest \
  --assume-role-policy-document file:///tmp/irsa-trust-policy.json \
  --tags Key=Project,Value=${PROJECT}

# Attach S3 read-only (scope to specific bucket in production)
aws iam attach-role-policy \
  --role-name ${PROJECT}-irsa-log-ingest \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

export IRSA_ROLE_ARN=$(aws iam get-role --role-name ${PROJECT}-irsa-log-ingest \
  --query 'Role.Arn' --output text)
```

### 4c: Annotate the ServiceAccount

```bash
# Create namespace if needed
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Create annotated ServiceAccount
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${SERVICE_ACCOUNT}
  namespace: ${NAMESPACE}
  annotations:
    eks.amazonaws.com/role-arn: "${IRSA_ROLE_ARN}"
EOF
```

### 4d: Test IRSA

```bash
# Deploy a test pod using the service account
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: irsa-test
  namespace: ${NAMESPACE}
spec:
  serviceAccountName: ${SERVICE_ACCOUNT}
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
  restartPolicy: Never
EOF

kubectl wait --for=condition=Ready pod/irsa-test -n ${NAMESPACE} --timeout=60s

# Verify the pod can access S3
kubectl exec -n ${NAMESPACE} irsa-test -- aws s3 ls
# Should succeed

# Verify a pod WITHOUT the annotation cannot
kubectl run irsa-negative-test --image=amazon/aws-cli:2.15.0 -n ${NAMESPACE} \
  --command -- sleep 3600
kubectl wait --for=condition=Ready pod/irsa-negative-test -n ${NAMESPACE} --timeout=60s
kubectl exec -n ${NAMESPACE} irsa-negative-test -- aws s3 ls
# Should fail with "Unable to locate credentials"

# Cleanup
kubectl delete pod irsa-test irsa-negative-test -n ${NAMESPACE}
```

---

## Step 5: Node Security — IMDSv2 Enforcement

Instance Metadata Service v1 is vulnerable to SSRF attacks. A compromised pod can steal node IAM credentials by hitting `169.254.169.254`. IMDSv2 requires a token, blocking this attack vector.

```bash
# Get the launch template used by the node group
LAUNCH_TEMPLATE=$(aws eks describe-nodegroup \
  --cluster-name ${CLUSTER_NAME} \
  --nodegroup-name ${PROJECT}-workers \
  --region ${REGION} \
  --query 'nodegroup.launchTemplate.{Id:id,Version:version}' \
  --output json)

LT_ID=$(echo ${LAUNCH_TEMPLATE} | python3 -c "import sys,json; print(json.load(sys.stdin)['Id'])")
LT_VERSION=$(echo ${LAUNCH_TEMPLATE} | python3 -c "import sys,json; print(json.load(sys.stdin)['Version'])")

# Create new launch template version with IMDSv2 required
aws ec2 create-launch-template-version \
  --launch-template-id ${LT_ID} \
  --source-version ${LT_VERSION} \
  --launch-template-data '{"MetadataOptions":{"HttpTokens":"required","HttpPutResponseHopLimit":2,"HttpEndpoint":"enabled"}}'

NEW_VERSION=$(aws ec2 describe-launch-template-versions \
  --launch-template-id ${LT_ID} \
  --query 'LaunchTemplateVersions[-1].VersionNumber' --output text)

# Update node group to use new version
aws eks update-nodegroup-config \
  --cluster-name ${CLUSTER_NAME} \
  --nodegroup-name ${PROJECT}-workers \
  --region ${REGION} \
  --launch-template id=${LT_ID},version=${NEW_VERSION}

echo "Node group will rolling-update to IMDSv2. Monitor with:"
echo "  aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${PROJECT}-workers --query 'nodegroup.health'"
```

> **Note:** `HttpPutResponseHopLimit=2` is required for pods using IRSA. A hop limit of 1 blocks the pod from reaching IMDS entirely, which breaks IRSA token retrieval.

---

## Step 6: Network Policies

By default, every pod can talk to every other pod. Deploy default-deny and allow only what's needed.

### 6a: Enable VPC CNI Network Policy Support

```bash
# Check if network policy is already enabled
aws eks describe-addon --cluster-name ${CLUSTER_NAME} --addon-name vpc-cni --region ${REGION} \
  --query 'addon.configurationValues'

# Enable network policy on the VPC CNI addon
aws eks update-addon \
  --cluster-name ${CLUSTER_NAME} \
  --addon-name vpc-cni \
  --region ${REGION} \
  --configuration-values '{"enableNetworkPolicy": "true"}' \
  --resolve-conflicts OVERWRITE

aws eks wait cluster-active --name ${CLUSTER_NAME} --region ${REGION}
```

### 6b: Deploy Default-Deny per Namespace

```bash
# Apply default-deny to all app namespaces
for NS in default log-ingest api-gateway monitoring; do
  cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: ${NS}
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
  echo "Applied default-deny to ${NS}"
done
```

> **Cross-reference:** For Kyverno-enforced NetworkPolicy patterns and generate policies, see `02-CLUSTER-HARDENING/playbooks/06-deploy-admission-control.md`.

---

## Step 7: ECR Image Scanning

Enable scan-on-push so every image is checked for CVEs before it runs in the cluster.

```bash
# List all ECR repos
aws ecr describe-repositories --region ${REGION} \
  --query 'repositories[*].{Name:repositoryName,ScanOnPush:imageScanningConfiguration.scanOnPush}' \
  --output table

# Enable scan-on-push on all repos that have it disabled
for REPO in $(aws ecr describe-repositories --region ${REGION} \
  --query 'repositories[?imageScanningConfiguration.scanOnPush==`false`].repositoryName' --output text); do
  aws ecr put-image-scanning-configuration \
    --repository-name ${REPO} \
    --image-scanning-configuration scanOnPush=true \
    --region ${REGION}
  echo "Enabled scan-on-push: ${REPO}"
done

# Check findings for a specific image
aws ecr describe-image-scan-findings \
  --repository-name ${PROJECT}-api \
  --image-id imageTag=latest \
  --region ${REGION} \
  --query 'imageScanFindings.findingSeverityCounts' \
  --output table
```

---

## Step 8: Pod Security Standards (PSS) Labels

Apply PSS labels to namespaces. Restricted for app workloads, baseline for infrastructure.

```bash
# Restricted PSS for application namespaces
for NS in default log-ingest api-gateway; do
  kubectl label namespace ${NS} \
    pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/warn=restricted \
    pod-security.kubernetes.io/audit=restricted \
    --overwrite
  echo "Applied restricted PSS to ${NS}"
done

# Baseline PSS for infrastructure namespaces
for NS in kube-system monitoring ingress-nginx; do
  kubectl label namespace ${NS} \
    pod-security.kubernetes.io/enforce=baseline \
    pod-security.kubernetes.io/warn=restricted \
    pod-security.kubernetes.io/audit=restricted \
    --overwrite
  echo "Applied baseline PSS to ${NS}"
done

# Verify labels
kubectl get namespaces -L pod-security.kubernetes.io/enforce
```

---

## EKS Security Checklist

Run through this after completing all steps:

| # | Control | Check Command | Pass Criteria |
|---|---|---|---|
| 1 | Private API endpoint | `aws eks describe-cluster --name ${CLUSTER_NAME} --query 'cluster.resourcesVpcConfig.endpointPublicAccess'` | `false` |
| 2 | All 5 log types enabled | `aws eks describe-cluster --name ${CLUSTER_NAME} --query 'cluster.logging'` | All 5 types, enabled=true |
| 3 | Envelope encryption | `aws eks describe-cluster --name ${CLUSTER_NAME} --query 'cluster.encryptionConfig'` | KMS key ARN present |
| 4 | OIDC provider + IRSA | `aws iam list-open-id-connect-providers \| grep ${OIDC_ID}` | Provider ARN returned |
| 5 | Managed node groups | `aws eks list-nodegroups --cluster-name ${CLUSTER_NAME}` | At least 1 node group |
| 6 | ECR scan-on-push | `aws ecr describe-repositories --query 'repositories[*].imageScanningConfiguration'` | All `scanOnPush=true` |
| 7 | Restrictive security groups | `aws ec2 describe-security-groups --group-ids ${SG_ID}` | No `0.0.0.0/0` ingress rules |
| 8 | PSS labels applied | `kubectl get ns -L pod-security.kubernetes.io/enforce` | All app ns = restricted |
| 9 | Network policies deployed | `kubectl get networkpolicy -A` | Default-deny in each app ns |
| 10 | IMDSv2 enforced | Check launch template metadata options | `HttpTokens=required` |

---

## Compliance Mapping

| EKS Hardening Item | FedRAMP Control | Description |
|---|---|---|
| Control plane logging (all 5 types) | AU-2 (Audit Events) | Captures API, auth, and system events |
| Envelope encryption (KMS) | SC-28 (Protection of Information at Rest) | Secrets encrypted with customer-managed key |
| Private API endpoint | SC-7 (Boundary Protection) | API not exposed to public internet |
| IRSA (least privilege) | AC-6 (Least Privilege) | Pods get only the AWS permissions they need |
| IMDSv2 enforcement | AC-3 (Access Enforcement) | Blocks SSRF-based credential theft |
| TLS for API + etcd | SC-8 (Transmission Confidentiality) | All control plane communication encrypted |
| Network policies | SC-7 (Boundary Protection) | Microsegmentation between workloads |
| PSS labels | CM-6 (Configuration Settings) | Enforced security baselines per namespace |

---

## Validation

Run the GP-Copilot security validation script:

```bash
PKG=~/linkops-industries/GP-copilot/GP-CONSULTING/06-CLOUD-SECURITY

# Automated checks
bash ${PKG}/tools/validate-security.sh --cluster ${CLUSTER_NAME} --region ${REGION}

# Manual spot-checks
aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} \
  --query 'cluster.{Endpoint:resourcesVpcConfig.endpointPublicAccess,Encryption:encryptionConfig,Logging:logging.clusterLogging}' \
  --output json
```

---

## Expected Outcomes

| Item | Expected State |
|---|---|
| API endpoint | Private only (`endpointPublicAccess=false`) |
| Control plane logging | All 5 types enabled, logs in CloudWatch |
| Secrets encryption | KMS envelope encryption active |
| IRSA | OIDC provider created, test pod assumes role |
| IMDSv2 | `HttpTokens=required` on all node launch templates |
| Network policies | Default-deny in every app namespace |
| ECR scanning | `scanOnPush=true` on all repositories |
| PSS labels | Restricted on app namespaces, baseline on infra |

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Lost kubectl access after private endpoint | No VPN/bastion to private VPC | Re-enable public access via AWS Console, set up SSM or bastion first |
| IRSA pod gets "Unable to locate credentials" | ServiceAccount annotation missing or trust policy wrong | Check annotation: `kubectl get sa -o yaml`, verify OIDC ID in trust policy |
| IMDSv2 update causes node churn | Rolling update replaces nodes one by one | Expected behavior — wait for all nodes to cycle (10-20 min) |
| `associate-encryption-config` stuck | Large cluster, many secrets to re-encrypt | Wait up to 30 min, check: `aws eks describe-update --name ${CLUSTER_NAME} --update-id <id>` |
| Network policy blocks legitimate traffic | Default-deny applied without allow rules | Add explicit allow rules for required traffic before applying default-deny |
| ECR scan shows CRITICAL findings | Known CVEs in base images | Update base images, then re-push. Block deploy if CRITICAL findings exist |
| PSS rejects existing workloads | Pods don't meet restricted standard | Fix workloads first (runAsNonRoot, drop ALL, readOnlyRootFilesystem), then apply label |

---

*Ghost Protocol — Cloud Security Package*
