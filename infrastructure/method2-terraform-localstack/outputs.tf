# LocalStack Environment Outputs

output "s3_buckets" {
  description = "S3 bucket information"
  value       = module.storage.s3_buckets
}

output "dynamodb_tables" {
  description = "DynamoDB table information"
  value       = module.storage.dynamodb_tables
}

output "sqs_queues" {
  description = "SQS queue information"
  value       = module.storage.sqs_queues
}

output "cloudwatch_log_groups" {
  description = "CloudWatch log group names"
  value       = module.storage.cloudwatch_log_groups
}

output "localstack_endpoint" {
  description = "LocalStack endpoint URL"
  value       = "http://localhost:4566"
}

output "connection_info" {
  description = "Connection information for services"
  value = {
    s3_raw_bucket             = "s3://portfolio-raw"
    s3_embeddings_bucket      = "s3://portfolio-embeddings"
    dynamodb_document_table   = module.storage.dynamodb_tables.document_registry.name
    dynamodb_chunks_table     = module.storage.dynamodb_tables.embedding_chunks.name
    dynamodb_jobs_table       = module.storage.dynamodb_tables.ingestion_jobs.name
    sqs_ingestion_queue_url   = module.storage.sqs_queues.ingestion.url
    sqs_embedding_queue_url   = module.storage.sqs_queues.embedding.url
  }
}
