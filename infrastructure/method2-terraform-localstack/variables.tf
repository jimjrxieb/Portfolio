# LocalStack Environment Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "portfolio"
}

variable "aws_region" {
  description = "AWS region (LocalStack ignores this but required for provider)"
  type        = string
  default     = "us-east-1"
}
