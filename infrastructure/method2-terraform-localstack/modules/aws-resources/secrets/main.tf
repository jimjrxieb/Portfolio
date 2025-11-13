# AWS Secrets Manager - Portfolio API Keys
# Production-grade secret management with rotation support

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================================================
# SECRET: Claude API Key
# ============================================================================

resource "aws_secretsmanager_secret" "claude_api_key" {
  name        = "${var.project_name}/claude-api-key"
  description = "Anthropic Claude API key for LLM chat completions"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "llm"
  }
}

resource "aws_secretsmanager_secret_version" "claude_api_key" {
  secret_id     = aws_secretsmanager_secret.claude_api_key.id
  secret_string = var.claude_api_key
}

# ============================================================================
# SECRET: OpenAI API Key (Fallback)
# ============================================================================

resource "aws_secretsmanager_secret" "openai_api_key" {
  name        = "${var.project_name}/openai-api-key"
  description = "OpenAI API key for fallback LLM and embeddings"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "llm"
  }
}

resource "aws_secretsmanager_secret_version" "openai_api_key" {
  secret_id     = aws_secretsmanager_secret.openai_api_key.id
  secret_string = var.openai_api_key != "" ? var.openai_api_key : "not-configured"
}

# ============================================================================
# SECRET: ElevenLabs API Key (Voice)
# ============================================================================

resource "aws_secretsmanager_secret" "elevenlabs_api_key" {
  name        = "${var.project_name}/elevenlabs-api-key"
  description = "ElevenLabs API key for voice synthesis"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "voice"
  }
}

resource "aws_secretsmanager_secret_version" "elevenlabs_api_key" {
  secret_id     = aws_secretsmanager_secret.elevenlabs_api_key.id
  secret_string = var.elevenlabs_api_key != "" ? var.elevenlabs_api_key : "not-configured"
}

# ============================================================================
# SECRET: D-ID API Key (Avatar)
# ============================================================================

resource "aws_secretsmanager_secret" "did_api_key" {
  name        = "${var.project_name}/did-api-key"
  description = "D-ID API key for avatar generation"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "avatar"
  }
}

resource "aws_secretsmanager_secret_version" "did_api_key" {
  secret_id     = aws_secretsmanager_secret.did_api_key.id
  secret_string = var.did_api_key != "" ? var.did_api_key : "not-configured"
}

# ============================================================================
# SECRET: Database Connection String (For Future Use)
# ============================================================================

resource "aws_secretsmanager_secret" "database_credentials" {
  name        = "${var.project_name}/database-credentials"
  description = "ChromaDB connection credentials"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "database"
  }
}

resource "aws_secretsmanager_secret_version" "database_credentials" {
  secret_id = aws_secretsmanager_secret.database_credentials.id
  secret_string = jsonencode({
    host     = "chroma.portfolio.svc.cluster.local"
    port     = "8000"
    protocol = "http"
  })
}

# ============================================================================
# IAM Policy: Allow Lambda to Read Secrets
# ============================================================================

data "aws_iam_policy_document" "lambda_secrets_access" {
  statement {
    sid    = "AllowSecretsManagerRead"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]

    resources = [
      aws_secretsmanager_secret.claude_api_key.arn,
      aws_secretsmanager_secret.openai_api_key.arn,
      aws_secretsmanager_secret.elevenlabs_api_key.arn,
      aws_secretsmanager_secret.did_api_key.arn,
      aws_secretsmanager_secret.database_credentials.arn,
    ]
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "lambda_secrets_access" {
  name        = "${var.project_name}-lambda-secrets-access"
  description = "Allow Lambda functions to read secrets from Secrets Manager"
  policy      = data.aws_iam_policy_document.lambda_secrets_access.json
}

# ============================================================================
# CloudWatch Log Group for Secret Access Auditing
# ============================================================================

# resource "aws_cloudwatch_log_group" "secrets_audit" {
#   name              = "/aws/secretsmanager/${var.project_name}"
#   retention_in_days = 7
#
#   tags = {
#     Project     = var.project_name
#     Environment = var.environment
#     Purpose     = "audit"
#   }
# }
