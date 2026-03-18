# Playbook 04 — EKS Cluster Deploy

> Stand up a production-ready EKS cluster with proper networking, logging, and encryption from day one.
>
> **When:** After VPC (Playbook 01), IAM roles (Playbook 02), and KMS key (Playbook 03) are complete.
> **Audience:** Platform engineers deploying EKS for a client engagement.
> **Time:** ~30 min (cluster creation takes 10-15 min, node group another 5-10 min)

---

## Prerequisites

| Prerequisite | How to Verify | Playbook |
|---|---|---|
| VPC with private subnets | `aws ec2 describe-subnets --filters "Name=tag:Project,Values=$PROJECT"` | 01 |
| IAM roles created | `aws iam get-role --role-name ${PROJECT}-eks-cluster-role` | 02 |
| KMS key for envelope encryption | `aws kms describe-key --key-id alias/${PROJECT}-eks` | 03 |
| AWS CLI v2 + kubectl + eksctl | `aws --version && kubectl version --client && eksctl version` | — |

Set your variables:

```bash
export PROJECT="anthra"
export REGION="us-east-1"
export CLUSTER_NAME="${PROJECT}-eks"
export K8S_VERSION="1.29"
export KMS_KEY_ARN=$(aws kms describe-key --key-id alias/${PROJECT}-eks --query 'KeyMetadata.Arn' --output text)
export VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=${PROJECT}" --query 'Vpcs[0].VpcId' --output text)
export PRIVATE_SUBNETS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Tier,Values=private" \
  --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')
export SECURITY_GROUP=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${PROJECT}-eks-cluster-sg" \
  --query 'SecurityGroups[0].GroupId' --output text)
```

---

## Step 1: Create EKS IAM Roles

### Cluster Service Role

The EKS control plane needs a role to manage AWS resources on your behalf.

```bash
# Create trust policy
cat > /tmp/eks-cluster-trust.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name ${PROJECT}-eks-cluster-role \
  --assume-role-policy-document file:///tmp/eks-cluster-trust.json \
  --tags Key=Project,Value=${PROJECT}

# Attach the required policy
aws iam attach-role-policy \
  --role-name ${PROJECT}-eks-cluster-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

# Store the ARN
export CLUSTER_ROLE_ARN=$(aws iam get-role --role-name ${PROJECT}-eks-cluster-role --query 'Role.Arn' --output text)
echo "Cluster role: ${CLUSTER_ROLE_ARN}"
```

### Node Group Role

Worker nodes need permissions for ECR pulls, CNI networking, and EC2 operations.

```bash
# Create trust policy
cat > /tmp/eks-node-trust.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name ${PROJECT}-eks-node-role \
  --assume-role-policy-document file:///tmp/eks-node-trust.json \
  --tags Key=Project,Value=${PROJECT}

# Attach all three required policies
aws iam attach-role-policy \
  --role-name ${PROJECT}-eks-node-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

aws iam attach-role-policy \
  --role-name ${PROJECT}-eks-node-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

aws iam attach-role-policy \
  --role-name ${PROJECT}-eks-node-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

export NODE_ROLE_ARN=$(aws iam get-role --role-name ${PROJECT}-eks-node-role --query 'Role.Arn' --output text)
echo "Node role: ${NODE_ROLE_ARN}"
```

---

## Step 2: Create EKS Cluster

Private subnets only. All logging enabled. KMS encryption for secrets from the start.

```bash
aws eks create-cluster \
  --name ${CLUSTER_NAME} \
  --region ${REGION} \
  --kubernetes-version ${K8S_VERSION} \
  --role-arn ${CLUSTER_ROLE_ARN} \
  --resources-vpc-config \
    subnetIds=${PRIVATE_SUBNETS},\
securityGroupIds=${SECURITY_GROUP},\
endpointPublicAccess=true,\
endpointPrivateAccess=true \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}' \
  --encryption-config '[{"resources":["secrets"],"provider":{"keyArn":"'"${KMS_KEY_ARN}"'"}}]' \
  --tags Project=${PROJECT},ManagedBy=gp-copilot
```

> **Note:** We start with `endpointPublicAccess=true` so we can configure the cluster remotely. Playbook 05 locks this down to private-only after bastion/VPN is confirmed.

---

## Step 3: Wait for Cluster and Update Kubeconfig

Cluster creation takes 10-15 minutes.

```bash
# Wait for cluster to become ACTIVE
echo "Waiting for cluster to become active..."
aws eks wait cluster-active --name ${CLUSTER_NAME} --region ${REGION}
echo "Cluster is ACTIVE"

# Verify status
aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} \
  --query 'cluster.{Status:status,Endpoint:endpoint,Version:version,Encryption:encryptionConfig[0].provider.keyArn}' \
  --output table

# Update kubeconfig
aws eks update-kubeconfig \
  --name ${CLUSTER_NAME} \
  --region ${REGION} \
  --alias ${CLUSTER_NAME}

# Verify connectivity
kubectl cluster-info
kubectl get ns
```

Expected output: cluster endpoint reachable, default namespaces listed (default, kube-system, kube-public, kube-node-lease).

---

## Step 4: Create Managed Node Group

```bash
aws eks create-nodegroup \
  --cluster-name ${CLUSTER_NAME} \
  --nodegroup-name ${PROJECT}-workers \
  --node-role ${NODE_ROLE_ARN} \
  --subnets $(echo ${PRIVATE_SUBNETS} | tr ',' ' ') \
  --instance-types t3.large \
  --ami-type AL2_x86_64 \
  --disk-size 50 \
  --scaling-config minSize=2,maxSize=6,desiredSize=3 \
  --labels role=worker,project=${PROJECT} \
  --tags Project=${PROJECT},ManagedBy=gp-copilot \
  --region ${REGION}
```

Wait for the node group:

```bash
echo "Waiting for node group (5-10 min)..."
aws eks wait nodegroup-active \
  --cluster-name ${CLUSTER_NAME} \
  --nodegroup-name ${PROJECT}-workers \
  --region ${REGION}
echo "Node group is ACTIVE"

# Verify nodes joined
kubectl get nodes -o wide
```

| Parameter | Default | Production Recommendation |
|---|---|---|
| Instance type | `t3.large` | `m5.xlarge` or `m6i.xlarge` for workloads |
| AMI type | `AL2_x86_64` | `AL2_ARM_64` for Graviton (cost savings) |
| Disk size | 50 GB | 100 GB for image-heavy workloads |
| Min nodes | 2 | 2 (HA minimum) |
| Max nodes | 6 | Based on workload projections |
| Desired nodes | 3 | Start at min+1, let autoscaler adjust |

---

## Step 5: Install EKS Add-ons

EKS managed add-ons get automatic security patches from AWS.

```bash
# VPC CNI — pod networking
aws eks create-addon \
  --cluster-name ${CLUSTER_NAME} \
  --addon-name vpc-cni \
  --addon-version $(aws eks describe-addon-versions --addon-name vpc-cni --kubernetes-version ${K8S_VERSION} \
    --query 'addons[0].addonVersions[0].addonVersion' --output text) \
  --resolve-conflicts OVERWRITE \
  --region ${REGION}

# CoreDNS — cluster DNS
aws eks create-addon \
  --cluster-name ${CLUSTER_NAME} \
  --addon-name coredns \
  --addon-version $(aws eks describe-addon-versions --addon-name coredns --kubernetes-version ${K8S_VERSION} \
    --query 'addons[0].addonVersions[0].addonVersion' --output text) \
  --resolve-conflicts OVERWRITE \
  --region ${REGION}

# kube-proxy — network rules
aws eks create-addon \
  --cluster-name ${CLUSTER_NAME} \
  --addon-name kube-proxy \
  --addon-version $(aws eks describe-addon-versions --addon-name kube-proxy --kubernetes-version ${K8S_VERSION} \
    --query 'addons[0].addonVersions[0].addonVersion' --output text) \
  --resolve-conflicts OVERWRITE \
  --region ${REGION}

# EBS CSI Driver — persistent volumes
aws eks create-addon \
  --cluster-name ${CLUSTER_NAME} \
  --addon-name aws-ebs-csi-driver \
  --addon-version $(aws eks describe-addon-versions --addon-name aws-ebs-csi-driver --kubernetes-version ${K8S_VERSION} \
    --query 'addons[0].addonVersions[0].addonVersion' --output text) \
  --resolve-conflicts OVERWRITE \
  --region ${REGION}
```

Verify all add-ons are active:

```bash
aws eks list-addons --cluster-name ${CLUSTER_NAME} --region ${REGION} --output table

# Check each addon status
for addon in vpc-cni coredns kube-proxy aws-ebs-csi-driver; do
  STATUS=$(aws eks describe-addon --cluster-name ${CLUSTER_NAME} --addon-name ${addon} \
    --region ${REGION} --query 'addon.status' --output text)
  echo "${addon}: ${STATUS}"
done
```

All four should report `ACTIVE`.

---

## Step 6: Verify Cluster

```bash
# Nodes ready
kubectl get nodes
# Expected: all nodes in Ready state

# System pods running
kubectl get pods -n kube-system
# Expected: coredns, aws-node (VPC CNI), kube-proxy on each node

# Addons healthy
kubectl get daemonsets -n kube-system
# Expected: aws-node and kube-proxy DaemonSets with DESIRED=READY

# Test pod scheduling
kubectl run test-nginx --image=nginx:1.25-alpine --restart=Never
kubectl wait --for=condition=Ready pod/test-nginx --timeout=60s
kubectl delete pod test-nginx
```

---

## Step 7: Create OIDC Provider

Required for IRSA (IAM Roles for Service Accounts). Without this, pods cannot assume IAM roles.

```bash
# Get the OIDC issuer URL
export OIDC_ISSUER=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} \
  --query 'cluster.identity.oidc.issuer' --output text)
echo "OIDC Issuer: ${OIDC_ISSUER}"

# Associate the OIDC provider (eksctl method — simplest)
eksctl utils associate-iam-oidc-provider \
  --cluster ${CLUSTER_NAME} \
  --region ${REGION} \
  --approve

# Verify the provider was created
aws iam list-open-id-connect-providers | grep $(echo ${OIDC_ISSUER} | cut -d'/' -f5)
```

If `eksctl` is not available, create manually:

```bash
# Get thumbprint
THUMBPRINT=$(echo | openssl s_client -servername oidc.eks.${REGION}.amazonaws.com \
  -connect oidc.eks.${REGION}.amazonaws.com:443 2>/dev/null | \
  openssl x509 -fingerprint -noout | cut -d'=' -f2 | tr -d ':' | tr '[:upper:]' '[:lower:]')

# Create the provider
aws iam create-open-id-connect-provider \
  --url ${OIDC_ISSUER} \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list ${THUMBPRINT}
```

---

## Terraform Alternative

For repeatable deployments, use the Terraform module:

```bash
PKG=~/linkops-industries/GP-copilot/GP-CONSULTING/06-CLOUD-SECURITY

# Review the Terraform config
cat ${PKG}/terraform/eks-cluster.tf

# Deploy via the wrapper script
bash ${PKG}/tools/deploy-terraform.sh --module eks --env production --region ${REGION}
```

The Terraform module creates everything in Steps 1-7 as a single `terraform apply`.

---

## Expected Outcomes

| Item | Expected State |
|---|---|
| EKS cluster | Status: ACTIVE |
| Kubernetes version | ${K8S_VERSION} |
| Control plane logging | All 5 log types enabled |
| Secrets encryption | KMS envelope encryption active |
| Managed node group | All nodes in Ready state |
| EKS add-ons | vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver all ACTIVE |
| OIDC provider | Created and verified |
| kubeconfig | Working — `kubectl get nodes` returns node list |

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `aws eks update-kubeconfig` fails with "cluster not found" | Wrong region or cluster name | Verify: `aws eks list-clusters --region ${REGION}` |
| `kubectl` returns "Unauthorized" | IAM user/role not in aws-auth ConfigMap | Check: `kubectl get configmap aws-auth -n kube-system -o yaml` — add your IAM ARN |
| Nodes stuck in `NotReady` | Node role missing policies or subnet has no NAT gateway | Verify NAT: `aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=${VPC_ID}"` and check node role policies |
| Add-on stuck in `CREATING` or `DEGRADED` | Version conflict or missing IRSA for EBS CSI | Check: `aws eks describe-addon --cluster-name ${CLUSTER_NAME} --addon-name <name>` for health issues |
| CoreDNS pods in `Pending` | No nodes available or taints blocking scheduling | Check: `kubectl describe pod -n kube-system -l k8s-app=kube-dns` for scheduling errors |
| "error: You must be logged in to the server" | kubeconfig context wrong or token expired | Re-run: `aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}` |
| Node group creation fails | Subnets in different AZs than expected or insufficient capacity | Use at least 2 subnets in different AZs, try different instance types |

---

*Ghost Protocol — Cloud Security Package*
