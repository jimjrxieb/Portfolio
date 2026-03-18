#!/usr/bin/env bash
# deploy-cloudformation.sh — Deploy CloudFormation with change sets and validation
# Usage: bash tools/deploy-cloudformation.sh --template ./cfn/vpc.yaml --stack my-vpc [OPTIONS]

set -euo pipefail

TEMPLATE=""
STACK_NAME=""
REGION="us-east-1"
PARAMS=""
DRY_RUN=false
DELETE=false

usage() {
  cat <<EOF
Usage: $(basename "$0") --template FILE --stack NAME [OPTIONS]

Options:
  --template FILE    CloudFormation template file (required)
  --stack NAME       Stack name (required)
  --region REGION    AWS region (default: us-east-1)
  --params KEY=VAL   Parameter overrides (repeatable)
  --dry-run          Validate + create change set only
  --delete           Delete the stack
  -h, --help         Show this help

Examples:
  $(basename "$0") --template cfn/01-vpc.yaml --stack anthra-vpc
  $(basename "$0") --template cfn/03-eks.yaml --stack anthra-eks --params EKSVersion=1.29
  $(basename "$0") --stack anthra-vpc --delete
EOF
  exit 0
}

PARAM_OVERRIDES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --template) TEMPLATE="$2"; shift 2 ;;
    --stack) STACK_NAME="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --params) PARAM_OVERRIDES+=("$2"); shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --delete) DELETE=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

[[ -z "$STACK_NAME" ]] && echo "ERROR: --stack is required" && exit 1

if [[ "$DELETE" == "true" ]]; then
  echo "=== Deleting stack: $STACK_NAME ==="
  aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
  echo "Waiting for deletion..."
  aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"
  echo "Stack deleted."
  exit 0
fi

[[ -z "$TEMPLATE" ]] && echo "ERROR: --template is required" && exit 1
[[ ! -f "$TEMPLATE" ]] && echo "ERROR: Template not found: $TEMPLATE" && exit 1

echo "=== GP-Consulting: CloudFormation Deployment ==="
echo "Template: $TEMPLATE"
echo "Stack:    $STACK_NAME"
echo "Region:   $REGION"
echo ""

# Step 1: Validate template
echo "[1/4] Validating template..."
aws cloudformation validate-template --template-body "file://$TEMPLATE" --region "$REGION" > /dev/null
echo "  Template valid."
echo ""

# Step 2: Lint (if cfn-lint available)
if command -v cfn-lint &>/dev/null; then
  echo "[2/4] Running cfn-lint..."
  cfn-lint "$TEMPLATE" || true
  echo ""
else
  echo "[2/4] cfn-lint not installed — skipping"
  echo ""
fi

# Step 3: Security scan (if checkov available)
if command -v checkov &>/dev/null; then
  echo "[3/4] Running Checkov IaC scan..."
  checkov -f "$TEMPLATE" --framework cloudformation --compact --quiet || true
  echo ""
else
  echo "[3/4] Checkov not installed — skipping"
  echo ""
fi

# Step 4: Deploy
echo "[4/4] Deploying stack..."
DEPLOY_ARGS=(
  --template-file "$TEMPLATE"
  --stack-name "$STACK_NAME"
  --region "$REGION"
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_IAM
  --no-fail-on-empty-changeset
)

if [[ ${#PARAM_OVERRIDES[@]} -gt 0 ]]; then
  DEPLOY_ARGS+=(--parameter-overrides "${PARAM_OVERRIDES[@]}")
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "  Dry run — creating change set only..."
  CS_NAME="cs-$(date +%Y%m%d%H%M%S)"
  aws cloudformation create-change-set \
    --template-body "file://$TEMPLATE" \
    --stack-name "$STACK_NAME" \
    --change-set-name "$CS_NAME" \
    --region "$REGION" \
    --capabilities CAPABILITY_NAMED_IAM 2>/dev/null || \
  aws cloudformation create-change-set \
    --template-body "file://$TEMPLATE" \
    --stack-name "$STACK_NAME" \
    --change-set-name "$CS_NAME" \
    --change-set-type CREATE \
    --region "$REGION" \
    --capabilities CAPABILITY_NAMED_IAM

  sleep 5
  aws cloudformation describe-change-set \
    --stack-name "$STACK_NAME" \
    --change-set-name "$CS_NAME" \
    --region "$REGION" \
    --query 'Changes[].{Action:ResourceChange.Action,Resource:ResourceChange.LogicalResourceId,Type:ResourceChange.ResourceType}' \
    --output table
  echo ""
  echo "Change set created: $CS_NAME"
  echo "Execute with: aws cloudformation execute-change-set --stack-name $STACK_NAME --change-set-name $CS_NAME --region $REGION"
  exit 0
fi

aws cloudformation deploy "${DEPLOY_ARGS[@]}"
echo ""
echo "=== Stack deployed ==="
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs' \
  --output table 2>/dev/null || true
