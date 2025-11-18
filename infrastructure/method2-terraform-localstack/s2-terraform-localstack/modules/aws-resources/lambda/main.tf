# AWS Lambda Functions for Portfolio Chat
# Production-grade Lambda with Secrets Manager integration

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================================================
# IAM ROLE: Lambda Execution Role
# ============================================================================

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.project_name}-lambda-exec-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Attach Secrets Manager policy (from secrets module)
resource "aws_iam_role_policy_attachment" "lambda_secrets" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = var.secrets_policy_arn
}

# Attach basic Lambda execution policy for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ============================================================================
# LAMBDA FUNCTION: Chat Handler
# ============================================================================

resource "aws_lambda_function" "chat_handler" {
  filename      = "${path.module}/../../../lambda-functions/chat-handler.zip"
  function_name = "${var.project_name}-chat-handler"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = filebase64sha256("${path.module}/../../../lambda-functions/chat-handler.zip")

  runtime = "python3.11"
  timeout = 30

  environment {
    variables = {
      AWS_ENDPOINT_URL = var.aws_endpoint_url
      PROJECT_NAME     = var.project_name
      ENVIRONMENT      = var.environment
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Function    = "chat-handler"
  }
}

# ============================================================================
# CLOUDWATCH LOG GROUP
# ============================================================================

resource "aws_cloudwatch_log_group" "lambda_chat" {
  name              = "/aws/lambda/${aws_lambda_function.chat_handler.function_name}"
  retention_in_days = 7

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Function    = "chat-handler"
  }
}
