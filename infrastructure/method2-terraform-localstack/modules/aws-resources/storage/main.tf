# S3 Buckets and DynamoDB Tables Module
# Supports both LocalStack and AWS

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# S3 Buckets for RAG Pipeline
resource "aws_s3_bucket" "portfolio_raw" {
  bucket = "${var.project_name}-raw"

  tags = merge(var.tags, {
    Name        = "${var.project_name}-raw"
    Purpose     = "Raw document storage"
    Environment = var.environment
  })
}

resource "aws_s3_bucket" "portfolio_embeddings" {
  bucket = "${var.project_name}-embeddings"

  tags = merge(var.tags, {
    Name        = "${var.project_name}-embeddings"
    Purpose     = "Processed embeddings storage"
    Environment = var.environment
  })
}

resource "aws_s3_bucket" "portfolio_config" {
  bucket = "${var.project_name}-config"

  tags = merge(var.tags, {
    Name        = "${var.project_name}-config"
    Purpose     = "Configuration and secrets"
    Environment = var.environment
  })
}

# Enable versioning on raw bucket
resource "aws_s3_bucket_versioning" "portfolio_raw" {
  bucket = aws_s3_bucket.portfolio_raw.id

  versioning_configuration {
    status = "Enabled"
  }
}

# DynamoDB Table: Document Registry
resource "aws_dynamodb_table" "document_registry" {
  name           = "${var.project_name}-document-registry"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "document_id"
  range_key      = "version"

  attribute {
    name = "document_id"
    type = "S"
  }

  attribute {
    name = "version"
    type = "N"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "upload_timestamp"
    type = "S"
  }

  global_secondary_index {
    name            = "status-upload_timestamp-index"
    hash_key        = "status"
    range_key       = "upload_timestamp"
    projection_type = "ALL"
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-document-registry"
    Purpose     = "Document metadata tracking"
    Environment = var.environment
  })
}

# DynamoDB Table: Embedding Chunks
resource "aws_dynamodb_table" "embedding_chunks" {
  name           = "${var.project_name}-embedding-chunks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "chunk_id"
  range_key      = "document_id"

  attribute {
    name = "chunk_id"
    type = "S"
  }

  attribute {
    name = "document_id"
    type = "S"
  }

  attribute {
    name = "chunk_index"
    type = "N"
  }

  global_secondary_index {
    name            = "document_id-chunk_index-index"
    hash_key        = "document_id"
    range_key       = "chunk_index"
    projection_type = "ALL"
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-embedding-chunks"
    Purpose     = "Chunk-level embedding metadata"
    Environment = var.environment
  })
}

# DynamoDB Table: Ingestion Jobs
resource "aws_dynamodb_table" "ingestion_jobs" {
  name           = "${var.project_name}-ingestion-jobs"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "job_id"

  attribute {
    name = "job_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "started_at"
    type = "S"
  }

  global_secondary_index {
    name            = "status-started_at-index"
    hash_key        = "status"
    range_key       = "started_at"
    projection_type = "ALL"
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-ingestion-jobs"
    Purpose     = "Job tracking and status"
    Environment = var.environment
  })
}

# SQS Queue: Ingestion Queue
resource "aws_sqs_queue" "ingestion_queue" {
  name                       = "${var.project_name}-ingestion-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400

  tags = merge(var.tags, {
    Name        = "${var.project_name}-ingestion-queue"
    Purpose     = "Document ingestion queue"
    Environment = var.environment
  })
}

# SQS Queue: Embedding Queue
resource "aws_sqs_queue" "embedding_queue" {
  name                       = "${var.project_name}-embedding-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400

  tags = merge(var.tags, {
    Name        = "${var.project_name}-embedding-queue"
    Purpose     = "Embedding generation queue"
    Environment = var.environment
  })
}

# SQS Queue: Dead Letter Queue
resource "aws_sqs_queue" "ingestion_dlq" {
  name                      = "${var.project_name}-ingestion-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = merge(var.tags, {
    Name        = "${var.project_name}-ingestion-dlq"
    Purpose     = "Dead letter queue for failed messages"
    Environment = var.environment
  })
}

# Configure DLQ for main ingestion queue
resource "aws_sqs_queue_redrive_policy" "ingestion_queue" {
  queue_url = aws_sqs_queue.ingestion_queue.id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ingestion_dlq.arn
    maxReceiveCount     = 3
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "document_intake" {
  name              = "/aws/lambda/${var.project_name}-document-intake"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name        = "${var.project_name}-document-intake-logs"
    Environment = var.environment
  })
}

resource "aws_cloudwatch_log_group" "document_processor" {
  name              = "/aws/lambda/${var.project_name}-document-processor"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name        = "${var.project_name}-document-processor-logs"
    Environment = var.environment
  })
}

resource "aws_cloudwatch_log_group" "embedding_generator" {
  name              = "/aws/lambda/${var.project_name}-embedding-generator"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name        = "${var.project_name}-embedding-generator-logs"
    Environment = var.environment
  })
}
