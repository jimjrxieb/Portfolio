variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "secrets_policy_arn" {
  description = "ARN of the IAM policy for Secrets Manager access"
  type        = string
}

variable "aws_endpoint_url" {
  description = "AWS endpoint URL for LocalStack"
  type        = string
  default     = "http://localhost:4566"
}
