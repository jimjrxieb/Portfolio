# Outputs for Secrets Manager Module

output "secret_arns" {
  description = "ARNs of all secrets for Lambda environment variables"
  value = {
    claude_api_key      = aws_secretsmanager_secret.claude_api_key.arn
    openai_api_key      = aws_secretsmanager_secret.openai_api_key.arn
    elevenlabs_api_key  = aws_secretsmanager_secret.elevenlabs_api_key.arn
    did_api_key         = aws_secretsmanager_secret.did_api_key.arn
    database_credentials = aws_secretsmanager_secret.database_credentials.arn
  }
}

output "secret_names" {
  description = "Names of all secrets for easy reference"
  value = {
    claude_api_key      = aws_secretsmanager_secret.claude_api_key.name
    openai_api_key      = aws_secretsmanager_secret.openai_api_key.name
    elevenlabs_api_key  = aws_secretsmanager_secret.elevenlabs_api_key.name
    did_api_key         = aws_secretsmanager_secret.did_api_key.name
    database_credentials = aws_secretsmanager_secret.database_credentials.name
  }
}

output "lambda_secrets_policy_arn" {
  description = "IAM policy ARN for Lambda to access secrets"
  value       = aws_iam_policy.lambda_secrets_access.arn
}

# output "secrets_audit_log_group" {
#   description = "CloudWatch log group for secret access auditing"
#   value       = aws_cloudwatch_log_group.secrets_audit.name
# }
