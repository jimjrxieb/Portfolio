# KMS Key for encrypting DynamoDB tables and CloudWatch logs
# This provides customer-managed encryption instead of AWS-managed

variable "use_customer_managed_encryption" {
  description = "Enable customer-managed KMS encryption (false for LocalStack/dev, true for production)"
  type        = bool
  default     = false
}

# KMS Key for storage encryption
resource "aws_kms_key" "storage" {
  count = var.use_customer_managed_encryption ? 1 : 0

  description             = "KMS key for DynamoDB tables and CloudWatch log groups"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-storage-kms-key"
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "storage-encryption"
  }
}

# KMS Key Alias (easier to reference)
resource "aws_kms_alias" "storage" {
  count = var.use_customer_managed_encryption ? 1 : 0

  name          = "alias/${var.project_name}-storage"
  target_key_id = aws_kms_key.storage[0].key_id
}

# Output the KMS key ARN for use in other resources
output "kms_key_arn" {
  description = "ARN of the KMS key for storage encryption"
  value       = var.use_customer_managed_encryption ? aws_kms_key.storage[0].arn : null
}

output "kms_key_id" {
  description = "ID of the KMS key for storage encryption"
  value       = var.use_customer_managed_encryption ? aws_kms_key.storage[0].id : null
}
