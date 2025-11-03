# LocalStack Environment Configuration
# Deploys Portfolio infrastructure to LocalStack for local testing

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# LocalStack Provider Configuration
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3             = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    logs           = "http://localhost:4566"
    events         = "http://localhost:4566"
    iam            = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
}

# Storage Module (S3, DynamoDB, SQS)
module "storage" {
  source = "../../modules/storage"

  project_name = var.project_name
  environment  = "localstack"

  tags = {
    Environment = "localstack"
    ManagedBy   = "terraform"
    Purpose     = "local-development"
  }
}

# EventBridge Rule: Daily Reindex (2 AM)
resource "aws_cloudwatch_event_rule" "daily_reindex" {
  name                = "${var.project_name}-daily-reindex"
  description         = "Trigger daily reindex at 2 AM"
  schedule_expression = "cron(0 2 * * ? *)"

  tags = {
    Environment = "localstack"
    ManagedBy   = "terraform"
  }
}

# EventBridge Rule: Process Monitoring (every 5 minutes)
resource "aws_cloudwatch_event_rule" "process_monitoring" {
  name                = "${var.project_name}-process-monitoring"
  description         = "Monitor processes every 5 minutes"
  schedule_expression = "rate(5 minutes)"

  tags = {
    Environment = "localstack"
    ManagedBy   = "terraform"
  }
}
