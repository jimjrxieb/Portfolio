#!/usr/bin/env bash
# =============================================================================
# Ghost Protocol -- setup-karpenter.sh
# Install Karpenter node auto-provisioner on EKS for cost-optimized compute
#
# Usage:
#   bash tools/platform/setup-karpenter.sh --cluster-name my-cluster --aws-region us-east-1
#   bash tools/platform/setup-karpenter.sh --cluster-name my-cluster --dry-run
#   bash tools/platform/setup-karpenter.sh --cluster-name my-cluster --skip-iam
#
# Prerequisites:
#   - EKS cluster running
#   - aws CLI configured with admin access
#   - kubectl, helm installed
#   - Cluster Autoscaler removed (cannot coexist)
#
# What this script does:
#   1. Creates IAM roles (KarpenterControllerRole, KarpenterNodeRole)
#   2. Tags subnets and security groups for Karpenter discovery
#   3. Installs Karpenter via Helm
#   4. Deploys default NodePool + EC2NodeClass
#   5. Verifies controller health
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEMPLATE_DIR="${PACKAGE_DIR}/templates/karpenter"

# Pinned versions
KARPENTER_VERSION="1.1.1"
KARPENTER_NAMESPACE="kube-system"

# Defaults
CLUSTER_NAME=""
AWS_REGION="us-east-1"
DRY_RUN=false
SKIP_IAM=false
DEPLOY_GPU_POOL=false
DEPLOY_CRITICAL_POOL=false

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_section() { echo -e "\n${BLUE}=== $* ===${NC}"; }

die() { log_error "$*"; exit 1; }

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --cluster-name  NAME     EKS cluster name (required)"
    echo "  --aws-region    REGION   AWS region (default: us-east-1)"
    echo "  --skip-iam               Skip IAM role creation (use if roles exist)"
    echo "  --gpu-pool               Also deploy GPU NodePool"
    echo "  --critical-pool          Also deploy on-demand-only critical NodePool"
    echo "  --dry-run                Print what would be done, do not apply"
    echo "  -h, --help               Show this help"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cluster-name)    CLUSTER_NAME="${2:-}"; shift 2 ;;
        --aws-region)      AWS_REGION="${2:-}"; shift 2 ;;
        --skip-iam)        SKIP_IAM=true; shift ;;
        --gpu-pool)        DEPLOY_GPU_POOL=true; shift ;;
        --critical-pool)   DEPLOY_CRITICAL_POOL=true; shift ;;
        --dry-run)         DRY_RUN=true; shift ;;
        -h|--help)         usage ;;
        *)                 die "Unknown option: $1" ;;
    esac
done

[[ -n "$CLUSTER_NAME" ]] || die "--cluster-name is required"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
log_section "Pre-flight checks"

command -v aws     >/dev/null 2>&1 || die "aws CLI not found"
command -v kubectl >/dev/null 2>&1 || die "kubectl not found"
command -v helm    >/dev/null 2>&1 || die "helm not found"

# Verify cluster exists and we can reach it
if ! kubectl cluster-info >/dev/null 2>&1; then
    die "Cannot connect to cluster. Check kubeconfig."
fi
log_ok "kubectl connected"

# Check for Cluster Autoscaler (cannot coexist)
if kubectl get deployment cluster-autoscaler -n kube-system >/dev/null 2>&1; then
    log_warn "Cluster Autoscaler detected. Karpenter replaces it."
    log_warn "Remove it first: helm uninstall cluster-autoscaler -n kube-system"
    if [ "$DRY_RUN" = false ]; then
        die "Remove Cluster Autoscaler before installing Karpenter"
    fi
fi

# Get cluster details
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
CLUSTER_ENDPOINT=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
    --query 'cluster.endpoint' --output text 2>/dev/null) || die "Cluster $CLUSTER_NAME not found in $AWS_REGION"

log_ok "Cluster: $CLUSTER_NAME"
log_ok "Region: $AWS_REGION"
log_ok "Account: $AWS_ACCOUNT_ID"
log_ok "Endpoint: $CLUSTER_ENDPOINT"

if [ "$DRY_RUN" = true ]; then
    log_warn "DRY RUN MODE — showing what would be done"
fi

# ---------------------------------------------------------------------------
# Step 1: IAM Roles
# ---------------------------------------------------------------------------
log_section "Step 1: IAM Roles"

CONTROLLER_ROLE="KarpenterControllerRole-${CLUSTER_NAME}"
NODE_ROLE="KarpenterNodeRole-${CLUSTER_NAME}"
INSTANCE_PROFILE="KarpenterNodeInstanceProfile-${CLUSTER_NAME}"

if [ "$SKIP_IAM" = true ]; then
    log_info "Skipping IAM role creation (--skip-iam)"
else
    # Controller role trust policy (IRSA)
    OIDC_PROVIDER=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
        --query 'cluster.identity.oidc.issuer' --output text | sed 's|https://||')

    CONTROLLER_TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com",
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:${KARPENTER_NAMESPACE}:karpenter"
        }
      }
    }
  ]
}
EOF
)

    # Controller policy (EC2, pricing, SSM, EKS)
    CONTROLLER_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Karpenter",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateFleet",
        "ec2:CreateLaunchTemplate",
        "ec2:CreateTags",
        "ec2:DeleteLaunchTemplate",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceTypeOfferings",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeLaunchTemplates",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "iam:PassRole",
        "pricing:GetProducts",
        "ssm:GetParameter",
        "eks:DescribeCluster"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "${AWS_REGION}"
        }
      }
    },
    {
      "Sid": "ConditionalEC2Termination",
      "Effect": "Allow",
      "Action": "ec2:TerminateInstances",
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/karpenter.sh/nodepool": "*"
        }
      }
    }
  ]
}
EOF
)

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would create IAM role: $CONTROLLER_ROLE"
        log_info "[DRY RUN] Would create IAM role: $NODE_ROLE"
        log_info "[DRY RUN] Would create instance profile: $INSTANCE_PROFILE"
    else
        # Create controller role
        if aws iam get-role --role-name "$CONTROLLER_ROLE" >/dev/null 2>&1; then
            log_info "Controller role $CONTROLLER_ROLE already exists, updating trust policy"
            aws iam update-assume-role-policy --role-name "$CONTROLLER_ROLE" \
                --policy-document "$CONTROLLER_TRUST_POLICY"
        else
            log_info "Creating controller role: $CONTROLLER_ROLE"
            aws iam create-role --role-name "$CONTROLLER_ROLE" \
                --assume-role-policy-document "$CONTROLLER_TRUST_POLICY" \
                --tags Key=Purpose,Value=Karpenter Key=Cluster,Value="$CLUSTER_NAME"
        fi

        # Attach controller policy
        POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerPolicy-${CLUSTER_NAME}"
        if aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
            log_info "Updating controller policy"
            # Create new version
            aws iam create-policy-version --policy-arn "$POLICY_ARN" \
                --policy-document "$CONTROLLER_POLICY" --set-as-default
        else
            log_info "Creating controller policy"
            aws iam create-policy --policy-name "KarpenterControllerPolicy-${CLUSTER_NAME}" \
                --policy-document "$CONTROLLER_POLICY"
        fi
        aws iam attach-role-policy --role-name "$CONTROLLER_ROLE" --policy-arn "$POLICY_ARN"

        # Create node role (EC2 instances need this)
        if aws iam get-role --role-name "$NODE_ROLE" >/dev/null 2>&1; then
            log_info "Node role $NODE_ROLE already exists"
        else
            log_info "Creating node role: $NODE_ROLE"
            aws iam create-role --role-name "$NODE_ROLE" \
                --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
                --tags Key=Purpose,Value=KarpenterNode Key=Cluster,Value="$CLUSTER_NAME"
        fi

        # Attach standard EKS node policies
        for policy in \
            "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" \
            "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" \
            "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" \
            "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"; do
            aws iam attach-role-policy --role-name "$NODE_ROLE" --policy-arn "$policy" 2>/dev/null || true
        done

        # Create instance profile
        if aws iam get-instance-profile --instance-profile-name "$INSTANCE_PROFILE" >/dev/null 2>&1; then
            log_info "Instance profile $INSTANCE_PROFILE already exists"
        else
            log_info "Creating instance profile: $INSTANCE_PROFILE"
            aws iam create-instance-profile --instance-profile-name "$INSTANCE_PROFILE"
            aws iam add-role-to-instance-profile \
                --instance-profile-name "$INSTANCE_PROFILE" --role-name "$NODE_ROLE"
        fi

        log_ok "IAM roles created"
    fi
fi

# ---------------------------------------------------------------------------
# Step 2: Tag subnets and security groups for discovery
# ---------------------------------------------------------------------------
log_section "Step 2: Tag subnets and security groups"

DISCOVERY_TAG="karpenter.sh/discovery"

# Get cluster subnets
SUBNET_IDS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
    --query 'cluster.resourcesVpcConfig.subnetIds' --output text)

# Get cluster security group
CLUSTER_SG=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
    --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)

if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would tag subnets: $SUBNET_IDS"
    log_info "[DRY RUN] Would tag security group: $CLUSTER_SG"
else
    # Tag subnets
    for subnet in $SUBNET_IDS; do
        aws ec2 create-tags --resources "$subnet" \
            --tags "Key=${DISCOVERY_TAG},Value=${CLUSTER_NAME}" \
            --region "$AWS_REGION" 2>/dev/null || true
    done
    log_ok "Subnets tagged for Karpenter discovery"

    # Tag cluster security group
    aws ec2 create-tags --resources "$CLUSTER_SG" \
        --tags "Key=${DISCOVERY_TAG},Value=${CLUSTER_NAME}" \
        --region "$AWS_REGION" 2>/dev/null || true
    log_ok "Security group tagged for Karpenter discovery"
fi

# ---------------------------------------------------------------------------
# Step 3: Install Karpenter via Helm
# ---------------------------------------------------------------------------
log_section "Step 3: Install Karpenter (v${KARPENTER_VERSION})"

HELM_ARGS=(
    karpenter oci://public.ecr.aws/karpenter/karpenter
    --version "$KARPENTER_VERSION"
    --namespace "$KARPENTER_NAMESPACE"
    --create-namespace
    --set "settings.clusterName=${CLUSTER_NAME}"
    --set "settings.clusterEndpoint=${CLUSTER_ENDPOINT}"
    --set "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CONTROLLER_ROLE}"
    --set "replicas=2"
    --wait
    --timeout 5m
)

if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would run: helm upgrade --install ${HELM_ARGS[*]}"
else
    log_info "Installing Karpenter..."
    helm upgrade --install "${HELM_ARGS[@]}"
    log_ok "Karpenter installed"

    # Wait for controller
    log_info "Waiting for Karpenter controller..."
    kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/name=karpenter \
        -n "$KARPENTER_NAMESPACE" \
        --timeout=120s
    log_ok "Karpenter controller ready"
fi

# ---------------------------------------------------------------------------
# Step 4: Deploy NodePool + EC2NodeClass
# ---------------------------------------------------------------------------
log_section "Step 4: Deploy default NodePool + EC2NodeClass"

if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would apply: ${TEMPLATE_DIR}/ec2nodeclass-default.yaml"
    log_info "[DRY RUN] Would apply: ${TEMPLATE_DIR}/nodepool-default.yaml"
else
    # Deploy EC2NodeClass
    sed "s|<CLUSTER_NAME>|${CLUSTER_NAME}|g" \
        "${TEMPLATE_DIR}/ec2nodeclass-default.yaml" | kubectl apply -f -
    log_ok "EC2NodeClass 'default' deployed"

    # Deploy default NodePool
    kubectl apply -f "${TEMPLATE_DIR}/nodepool-default.yaml"
    log_ok "NodePool 'default' deployed"
fi

# Optional pools
if [ "$DEPLOY_GPU_POOL" = true ]; then
    log_info "Deploying GPU NodePool..."
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would apply: ${TEMPLATE_DIR}/nodepool-gpu.yaml"
    else
        sed "s|<CLUSTER_NAME>|${CLUSTER_NAME}|g" \
            "${TEMPLATE_DIR}/nodepool-gpu.yaml" | kubectl apply -f -
        log_ok "GPU NodePool deployed"
    fi
fi

if [ "$DEPLOY_CRITICAL_POOL" = true ]; then
    log_info "Deploying critical (on-demand only) NodePool..."
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would apply: ${TEMPLATE_DIR}/nodepool-critical.yaml"
    else
        sed "s|<CLUSTER_NAME>|${CLUSTER_NAME}|g" \
            "${TEMPLATE_DIR}/nodepool-critical.yaml" | kubectl apply -f -
        log_ok "Critical NodePool deployed"
    fi
fi

# ---------------------------------------------------------------------------
# Step 5: Verify
# ---------------------------------------------------------------------------
log_section "Step 5: Verification"

if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would verify Karpenter pods, CRDs, and NodePool status"
else
    echo ""
    log_info "Karpenter pods:"
    kubectl get pods -n "$KARPENTER_NAMESPACE" -l app.kubernetes.io/name=karpenter

    echo ""
    log_info "CRDs:"
    kubectl get crd | grep karpenter || log_warn "No Karpenter CRDs found"

    echo ""
    log_info "NodePools:"
    kubectl get nodepool

    echo ""
    log_info "EC2NodeClasses:"
    kubectl get ec2nodeclass

    echo ""
    log_info "Existing NodeClaims (should be empty until pods are pending):"
    kubectl get nodeclaim 2>/dev/null || log_info "No NodeClaims yet (expected)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log_section "Summary"
echo ""
log_ok "Karpenter v${KARPENTER_VERSION} installed on ${CLUSTER_NAME}"
echo ""
log_info "Next steps:"
log_info "  1. Deploy a workload with resource requests to trigger node provisioning"
log_info "  2. Watch: kubectl logs -n ${KARPENTER_NAMESPACE} -l app.kubernetes.io/name=karpenter -f"
log_info "  3. Monitor: kubectl get nodeclaim -w"
log_info "  4. Cost tracking: check AWS Cost Explorer, filter by cluster tag"
echo ""
log_info "Cost optimization tips:"
log_info "  - Ensure ALL pods have resource requests (Karpenter needs them for bin-packing)"
log_info "  - Use 'profile-and-set-limits.sh' to right-size existing workloads"
log_info "  - Monitor Spot vs on-demand ratio: kubectl get nodes -L karpenter.sh/capacity-type"
log_info "  - Review consolidation: kubectl logs -n ${KARPENTER_NAMESPACE} -l app.kubernetes.io/name=karpenter | grep -i consolidat"
echo ""
