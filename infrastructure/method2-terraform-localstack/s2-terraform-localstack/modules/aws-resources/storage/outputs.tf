# Storage Module Outputs

output "s3_buckets" {
  description = "S3 bucket names and ARNs"
  value = {
    raw = {
      id  = aws_s3_bucket.portfolio_raw.id
      arn = aws_s3_bucket.portfolio_raw.arn
    }
    embeddings = {
      id  = aws_s3_bucket.portfolio_embeddings.id
      arn = aws_s3_bucket.portfolio_embeddings.arn
    }
    config = {
      id  = aws_s3_bucket.portfolio_config.id
      arn = aws_s3_bucket.portfolio_config.arn
    }
  }
}

output "dynamodb_tables" {
  description = "DynamoDB table names and ARNs"
  value = {
    document_registry = {
      id   = aws_dynamodb_table.document_registry.id
      arn  = aws_dynamodb_table.document_registry.arn
      name = aws_dynamodb_table.document_registry.name
    }
    embedding_chunks = {
      id   = aws_dynamodb_table.embedding_chunks.id
      arn  = aws_dynamodb_table.embedding_chunks.arn
      name = aws_dynamodb_table.embedding_chunks.name
    }
    ingestion_jobs = {
      id   = aws_dynamodb_table.ingestion_jobs.id
      arn  = aws_dynamodb_table.ingestion_jobs.arn
      name = aws_dynamodb_table.ingestion_jobs.name
    }
  }
}

output "sqs_queues" {
  description = "SQS queue URLs and ARNs"
  value = {
    ingestion = {
      id  = aws_sqs_queue.ingestion_queue.id
      arn = aws_sqs_queue.ingestion_queue.arn
      url = aws_sqs_queue.ingestion_queue.url
    }
    embedding = {
      id  = aws_sqs_queue.embedding_queue.id
      arn = aws_sqs_queue.embedding_queue.arn
      url = aws_sqs_queue.embedding_queue.url
    }
    dlq = {
      id  = aws_sqs_queue.ingestion_dlq.id
      arn = aws_sqs_queue.ingestion_dlq.arn
      url = aws_sqs_queue.ingestion_dlq.url
    }
  }
}

output "cloudwatch_log_groups" {
  description = "CloudWatch log group names"
  value = {
    document_intake       = aws_cloudwatch_log_group.document_intake.name
    document_processor    = aws_cloudwatch_log_group.document_processor.name
    embedding_generator   = aws_cloudwatch_log_group.embedding_generator.name
  }
}
