# Terraform Templates

> **Production-ready Terraform modules for secure AWS infrastructure**

---

## Available Modules

| Module | Description | Security Features |
|--------|-------------|-------------------|
| `vpc/` | Multi-AZ VPC with public/private subnets | VPC Flow Logs, NAT Gateway per AZ, deny-by-default NACLs |
| `s3/` | Encrypted S3 buckets | Versioning, KMS encryption, public access blocked |
| `iam/` | Least-privilege IAM roles | No wildcards, condition keys, MFA enforcement |
| `rds/` | Managed PostgreSQL/MySQL | Multi-AZ, encrypted, automated backups |
| `eks/` | Kubernetes cluster | Private API, managed nodes, IRSA |
| `security/` | CloudTrail, GuardDuty, Config | Compliance monitoring, threat detection |

---

## Quick Start

### 1. Install Terraform

```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
unzip terraform_1.7.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### 2. Create Project Structure

```bash
mkdir -p infrastructure/{modules,environments}
cd infrastructure

# Copy modules
cp -r ../terraform/vpc modules/
cp -r ../terraform/s3 modules/
cp -r ../terraform/iam modules/
```

### 3. Create Main Configuration

```hcl
# main.tf
terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "infrastructure/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  enable_flow_logs   = true
}

# S3 Module
module "s3_data" {
  source = "./modules/s3"

  bucket_name          = "${var.project_name}-data"
  versioning_enabled   = true
  encryption_enabled   = true
}

# IAM Module
module "iam_app" {
  source = "./modules/iam"

  role_name = "${var.project_name}-app"

  assume_role_principals = {
    Service = "ecs-tasks.amazonaws.com"
  }

  policy_statements = [
    {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      resources = [
        "${module.s3_data.bucket_arn}/*"
      ]
    }
  ]
}
```

### 4. Create Variables

```hcl
# variables.tf
variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project name for resource tagging"
}

variable "environment" {
  type        = string
  description = "Environment (dev, staging, prod)"
}
```

### 5. Create Environment Files

```hcl
# environments/dev.tfvars
project_name = "acme-corp"
environment  = "dev"
aws_region   = "us-east-1"
```

```hcl
# environments/prod.tfvars
project_name = "acme-corp"
environment  = "prod"
aws_region   = "us-east-1"
```

### 6. Deploy

```bash
# Initialize
terraform init

# Create workspace
terraform workspace new dev

# Plan
terraform plan -var-file="environments/dev.tfvars"

# Apply
terraform apply -var-file="environments/dev.tfvars"
```

---

## LocalStack Testing

Test your Terraform locally before deploying to AWS:

### 1. Start LocalStack

```bash
docker run --rm -d \
  -p 4566:4566 \
  -e SERVICES=s3,ec2,iam,rds,sts \
  --name localstack \
  localstack/localstack:latest
```

### 2. Configure Terraform for LocalStack

```hcl
# providers.tf
variable "use_localstack" {
  type    = bool
  default = false
}

provider "aws" {
  region = var.aws_region

  # LocalStack configuration
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      s3             = "http://localhost:4566"
      ec2            = "http://localhost:4566"
      iam            = "http://localhost:4566"
      rds            = "http://localhost:4566"
      sts            = "http://localhost:4566"
      dynamodb       = "http://localhost:4566"
      cloudwatch     = "http://localhost:4566"
    }
  }

  access_key = var.use_localstack ? "test" : null
  secret_key = var.use_localstack ? "test" : null
}
```

### 3. Deploy to LocalStack

```bash
# Apply with LocalStack
terraform apply \
  -var="use_localstack=true" \
  -var-file="environments/dev.tfvars"

# Verify resources
awslocal s3 ls
awslocal ec2 describe-vpcs
```

---

## Security Scanning

Scan your Terraform before deploying:

### Checkov

```bash
# Install
pip install checkov

# Scan all modules
checkov -d modules/

# Scan specific module
checkov -d modules/vpc/

# Generate report
checkov -d modules/ -o json > security-scan.json
```

### TFsec

```bash
# Install
brew install tfsec

# Scan
tfsec modules/

# Scan with custom rules
tfsec modules/ --config-file tfsec-rules.yaml
```

### Terraform Validate

```bash
# Validate syntax
terraform validate

# Format code
terraform fmt -recursive

# Check for issues
terraform plan
```

---

## Module Structure

Each module follows this pattern:

```
modules/vpc/
├── main.tf          # Main resources
├── variables.tf     # Input variables
├── outputs.tf       # Outputs
├── versions.tf      # Terraform/provider versions
├── data.tf          # Data sources (if needed)
└── README.md        # Module documentation
```

---

## Best Practices

### 1. State Management

```hcl
# Always use remote state
terraform {
  backend "s3" {
    bucket         = "your-tfstate-bucket"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"  # For state locking
  }
}
```

### 2. Variable Validation

```hcl
variable "environment" {
  type        = string
  description = "Environment name"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

### 3. Sensitive Variables

```hcl
variable "db_password" {
  type        = string
  description = "Database password"
  sensitive   = true
}

# Never commit sensitive values
# Use environment variables or secret management
export TF_VAR_db_password="secret123"
```

### 4. Module Versioning

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.0"  # Pin to specific version

  # Module configuration
}
```

### 5. Tagging

```hcl
provider "aws" {
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      CostCenter  = var.cost_center
    }
  }
}
```

---

## Common Tasks

### Import Existing Resources

```bash
# Import existing VPC
terraform import module.vpc.aws_vpc.main vpc-12345678

# Import existing S3 bucket
terraform import module.s3.aws_s3_bucket.main my-bucket
```

### Update Specific Resource

```bash
# Target specific resource
terraform apply -target=module.vpc.aws_vpc.main

# Taint resource (force recreation)
terraform taint module.rds.aws_db_instance.main
```

### Destroy Resources

```bash
# Destroy all
terraform destroy -var-file="environments/dev.tfvars"

# Destroy specific module
terraform destroy -target=module.vpc
```

---

## Troubleshooting

### State Lock Error

```bash
# Error: Error acquiring the state lock
# Solution:
terraform force-unlock <LOCK_ID>
```

### Provider Cache Issues

```bash
# Clear provider cache
rm -rf .terraform/

# Re-initialize
terraform init
```

### Drift Detection

```bash
# Check for drift
terraform plan -refresh-only

# Show current state
terraform show

# Refresh state
terraform refresh
```

---

*Part of the Terraform collection - Infrastructure as Code*
