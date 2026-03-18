# CloudFormation Templates

> **Production-ready CloudFormation stacks for secure AWS infrastructure**

---

## Available Templates

| Template | Description | Security Features |
|----------|-------------|-------------------|
| `vpc/` | Multi-AZ VPC with public/private subnets | VPC Flow Logs, NAT Gateway per AZ, deny-by-default NACLs |
| `s3/` | Encrypted S3 buckets | Versioning, KMS encryption, public access blocked |
| `iam/` | Least-privilege IAM roles | No wildcards, condition keys, MFA enforcement |
| `rds/` | Managed PostgreSQL/MySQL | Multi-AZ, encrypted, automated backups |
| `eks/` | Kubernetes cluster | Private API, managed nodes, IRSA |
| `security/` | CloudTrail, GuardDuty, Config | Compliance monitoring, threat detection |

---

## Quick Start

### 1. Install AWS CLI

```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### 2. Configure AWS Credentials

```bash
aws configure
# AWS Access Key ID: YOUR_KEY
# AWS Secret Access Key: YOUR_SECRET
# Default region: us-east-1
# Default output format: json
```

### 3. Create Project Structure

```bash
mkdir -p infrastructure/{stacks,parameters}
cd infrastructure

# Copy templates
cp -r ../cloudformation/vpc stacks/
cp -r ../cloudformation/s3 stacks/
cp -r ../cloudformation/iam stacks/
```

### 4. Create Parameters File

```json
// parameters/dev-vpc.json
[
  {
    "ParameterKey": "ProjectName",
    "ParameterValue": "acme-corp"
  },
  {
    "ParameterKey": "Environment",
    "ParameterValue": "dev"
  },
  {
    "ParameterKey": "VpcCidr",
    "ParameterValue": "10.0.0.0/16"
  },
  {
    "ParameterKey": "EnableFlowLogs",
    "ParameterValue": "true"
  }
]
```

### 5. Validate Template

```bash
aws cloudformation validate-template \
  --template-body file://stacks/vpc/template.yaml
```

### 6. Deploy Stack

```bash
# Create stack
aws cloudformation create-stack \
  --stack-name acme-corp-dev-vpc \
  --template-body file://stacks/vpc/template.yaml \
  --parameters file://parameters/dev-vpc.json \
  --capabilities CAPABILITY_IAM

# Monitor deployment
aws cloudformation wait stack-create-complete \
  --stack-name acme-corp-dev-vpc

# Check status
aws cloudformation describe-stacks \
  --stack-name acme-corp-dev-vpc
```

---

## LocalStack Testing

Test your CloudFormation locally before deploying to AWS:

### 1. Start LocalStack

```bash
docker run --rm -d \
  -p 4566:4566 \
  -e SERVICES=cloudformation,s3,ec2,iam,rds,sts \
  --name localstack \
  localstack/localstack:latest
```

### 2. Deploy to LocalStack

```bash
# Install awslocal
pip install awscli-local

# Create stack in LocalStack
awslocal cloudformation create-stack \
  --stack-name acme-corp-dev-vpc \
  --template-body file://stacks/vpc/template.yaml \
  --parameters file://parameters/dev-vpc.json

# Check status
awslocal cloudformation describe-stacks \
  --stack-name acme-corp-dev-vpc

# Verify resources
awslocal ec2 describe-vpcs
```

---

## Security Scanning

Scan your CloudFormation before deploying:

### cfn-lint

```bash
# Install
pip install cfn-lint

# Scan template
cfn-lint stacks/vpc/template.yaml

# Scan all templates
cfn-lint stacks/**/*.yaml

# Custom rules
cfn-lint stacks/vpc/template.yaml --config-file .cfnlintrc
```

### Checkov

```bash
# Install
pip install checkov

# Scan CloudFormation template
checkov -f stacks/vpc/template.yaml

# Scan all templates
checkov -d stacks/

# Generate report
checkov -d stacks/ -o json > security-scan.json
```

### TaskCat (AWS Testing Tool)

```bash
# Install
pip install taskcat

# Create config
cat > .taskcat.yml <<EOF
project:
  name: acme-corp-infrastructure
  regions:
    - us-east-1
tests:
  default:
    template: stacks/vpc/template.yaml
    parameters: parameters/dev-vpc.json
EOF

# Run tests
taskcat test run
```

---

## Stack Structure

Each stack follows this pattern:

```
stacks/vpc/
├── template.yaml       # CloudFormation template
├── parameters.json     # Parameter values (dev)
├── parameters-prod.json # Parameter values (prod)
├── outputs.txt         # Expected outputs documentation
└── README.md           # Stack documentation
```

---

## Best Practices

### 1. Use Parameters

```yaml
Parameters:
  ProjectName:
    Type: String
    Description: Project name prefix
    AllowedPattern: ^[a-z0-9-]+$
    ConstraintDescription: Only lowercase letters, numbers, and hyphens

  Environment:
    Type: String
    Description: Environment name
    AllowedValues:
      - dev
      - staging
      - prod
    Default: dev
```

### 2. Use Conditions

```yaml
Conditions:
  IsProduction: !Equals [!Ref Environment, 'prod']
  EnableHighAvailability: !Or
    - !Equals [!Ref Environment, 'prod']
    - !Equals [!Ref Environment, 'staging']

Resources:
  Database:
    Type: AWS::RDS::DBInstance
    Properties:
      MultiAZ: !If [EnableHighAvailability, true, false]
```

### 3. Use Mappings

```yaml
Mappings:
  RegionMap:
    us-east-1:
      AMI: ami-0c55b159cbfafe1f0
    us-west-2:
      AMI: ami-0d1cd67c26f5fca19

Resources:
  Instance:
    Type: AWS::EC2::Instance
    Properties:
      ImageId: !FindInMap [RegionMap, !Ref 'AWS::Region', AMI]
```

### 4. Use Outputs

```yaml
Outputs:
  VpcId:
    Description: VPC ID
    Value: !Ref VPC
    Export:
      Name: !Sub '${ProjectName}-VpcId'

  PrivateSubnetIds:
    Description: Private subnet IDs
    Value: !Join [',', [!Ref PrivateSubnet1, !Ref PrivateSubnet2]]
    Export:
      Name: !Sub '${ProjectName}-PrivateSubnetIds'
```

### 5. Use Cross-Stack References

```yaml
# In dependent stack
Resources:
  SecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      VpcId: !ImportValue acme-corp-VpcId
```

### 6. Enable Termination Protection

```bash
aws cloudformation update-termination-protection \
  --stack-name acme-corp-prod-vpc \
  --enable-termination-protection
```

---

## Common Tasks

### Update Stack

```bash
# Update stack
aws cloudformation update-stack \
  --stack-name acme-corp-dev-vpc \
  --template-body file://stacks/vpc/template.yaml \
  --parameters file://parameters/dev-vpc.json

# Monitor update
aws cloudformation wait stack-update-complete \
  --stack-name acme-corp-dev-vpc
```

### Create Change Set

```bash
# Create change set
aws cloudformation create-change-set \
  --stack-name acme-corp-dev-vpc \
  --change-set-name update-20260212 \
  --template-body file://stacks/vpc/template.yaml \
  --parameters file://parameters/dev-vpc.json

# Describe change set
aws cloudformation describe-change-set \
  --stack-name acme-corp-dev-vpc \
  --change-set-name update-20260212

# Execute change set
aws cloudformation execute-change-set \
  --stack-name acme-corp-dev-vpc \
  --change-set-name update-20260212
```

### Delete Stack

```bash
# Delete stack
aws cloudformation delete-stack \
  --stack-name acme-corp-dev-vpc

# Monitor deletion
aws cloudformation wait stack-delete-complete \
  --stack-name acme-corp-dev-vpc
```

### Export Stack

```bash
# Get template from existing stack
aws cloudformation get-template \
  --stack-name acme-corp-dev-vpc \
  --query TemplateBody \
  --output text > exported-template.yaml
```

---

## Stack Sets (Multi-Account/Multi-Region)

Deploy the same stack across multiple accounts/regions:

### 1. Create Stack Set

```bash
aws cloudformation create-stack-set \
  --stack-set-name acme-corp-security-baseline \
  --template-body file://stacks/security/cloudtrail.yaml \
  --parameters file://parameters/security-baseline.json \
  --capabilities CAPABILITY_IAM
```

### 2. Deploy to Accounts/Regions

```bash
aws cloudformation create-stack-instances \
  --stack-set-name acme-corp-security-baseline \
  --accounts 123456789012 234567890123 \
  --regions us-east-1 us-west-2 \
  --operation-preferences FailureToleranceCount=1,MaxConcurrentCount=2
```

### 3. Monitor Deployment

```bash
aws cloudformation list-stack-instances \
  --stack-set-name acme-corp-security-baseline
```

---

## Drift Detection

Detect configuration drift:

```bash
# Detect drift
aws cloudformation detect-stack-drift \
  --stack-name acme-corp-dev-vpc

# Get drift status
aws cloudformation describe-stack-drift-detection-status \
  --stack-drift-detection-id <DRIFT_DETECTION_ID>

# View drift details
aws cloudformation describe-stack-resource-drifts \
  --stack-name acme-corp-dev-vpc
```

---

## Nested Stacks

Organize large deployments with nested stacks:

```yaml
# parent-stack.yaml
Resources:
  VPCStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: https://s3.amazonaws.com/my-bucket/vpc-template.yaml
      Parameters:
        ProjectName: !Ref ProjectName

  RDSStack:
    Type: AWS::CloudFormation::Stack
    DependsOn: VPCStack
    Properties:
      TemplateURL: https://s3.amazonaws.com/my-bucket/rds-template.yaml
      Parameters:
        VpcId: !GetAtt VPCStack.Outputs.VpcId
```

---

## Troubleshooting

### Stack in UPDATE_ROLLBACK_FAILED

```bash
# Continue rollback
aws cloudformation continue-update-rollback \
  --stack-name acme-corp-dev-vpc

# OR: Skip problematic resources
aws cloudformation continue-update-rollback \
  --stack-name acme-corp-dev-vpc \
  --resources-to-skip LogicalResourceId1,LogicalResourceId2
```

### Stack Events

```bash
# View stack events
aws cloudformation describe-stack-events \
  --stack-name acme-corp-dev-vpc \
  --max-items 20

# Filter failed events
aws cloudformation describe-stack-events \
  --stack-name acme-corp-dev-vpc \
  | jq '.StackEvents[] | select(.ResourceStatus | contains("FAILED"))'
```

### Resource Information

```bash
# List stack resources
aws cloudformation list-stack-resources \
  --stack-name acme-corp-dev-vpc

# Describe specific resource
aws cloudformation describe-stack-resource \
  --stack-name acme-corp-dev-vpc \
  --logical-resource-id VPC
```

---

## CloudFormation vs Terraform

| Feature | CloudFormation | Terraform |
|---------|---------------|-----------|
| **Provider** | AWS native | HashiCorp |
| **Multi-cloud** | AWS only | Yes (AWS, Azure, GCP, etc.) |
| **State** | AWS-managed | External (S3, Terraform Cloud) |
| **Syntax** | YAML/JSON | HCL |
| **Drift detection** | Built-in | Manual (`plan -refresh-only`) |
| **Rollback** | Automatic | Manual |
| **Nested stacks** | Yes | Modules |
| **LocalStack** | Supported | Supported |
| **Learning curve** | Easier for AWS-only | Steeper, more flexible |

**Choose CloudFormation if:**
- You're AWS-only
- You want AWS-native tooling
- You prefer automatic rollback
- You want AWS-managed state

**Choose Terraform if:**
- You need multi-cloud
- You want more flexibility
- You prefer HCL syntax
- You need advanced features (workspaces, modules)

---

*Part of the CloudFormation collection - Infrastructure as Code*
