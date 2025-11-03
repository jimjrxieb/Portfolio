#!/bin/bash

echo "🚀 Initializing AWS resources in LocalStack..."

# Wait for LocalStack to be ready
sleep 5

# Set AWS CLI endpoint
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Function to check if resource exists
resource_exists() {
    aws "$@" --endpoint-url=$AWS_ENDPOINT_URL 2>&1 | grep -qv "does not exist"
}

echo "📦 Creating S3 Buckets..."

# Create S3 buckets
aws s3 mb s3://portfolio-raw --endpoint-url=$AWS_ENDPOINT_URL
aws s3 mb s3://portfolio-embeddings --endpoint-url=$AWS_ENDPOINT_URL
aws s3 mb s3://portfolio-config --endpoint-url=$AWS_ENDPOINT_URL

# Create bucket folders (by uploading empty objects)
echo "Creating S3 folder structure..."
for bucket in portfolio-raw; do
    for folder in incoming processed failed archived; do
        aws s3api put-object \
            --bucket $bucket \
            --key ${folder}/ \
            --endpoint-url=$AWS_ENDPOINT_URL
    done
done

# Enable versioning on raw bucket
aws s3api put-bucket-versioning \
    --bucket portfolio-raw \
    --versioning-configuration Status=Enabled \
    --endpoint-url=$AWS_ENDPOINT_URL

echo "✅ S3 buckets created"

echo "🗄️  Creating DynamoDB Tables..."

# Create document_registry table
aws dynamodb create-table \
    --table-name document_registry \
    --attribute-definitions \
        AttributeName=document_id,AttributeType=S \
        AttributeName=version,AttributeType=N \
        AttributeName=status,AttributeType=S \
        AttributeName=upload_timestamp,AttributeType=S \
    --key-schema \
        AttributeName=document_id,KeyType=HASH \
        AttributeName=version,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --global-secondary-indexes \
        "[{
            \"IndexName\": \"status-upload_timestamp-index\",
            \"KeySchema\": [
                {\"AttributeName\": \"status\", \"KeyType\": \"HASH\"},
                {\"AttributeName\": \"upload_timestamp\", \"KeyType\": \"RANGE\"}
            ],
            \"Projection\": {\"ProjectionType\": \"ALL\"}
        }]" \
    --endpoint-url=$AWS_ENDPOINT_URL

# Create embedding_chunks table
aws dynamodb create-table \
    --table-name embedding_chunks \
    --attribute-definitions \
        AttributeName=chunk_id,AttributeType=S \
        AttributeName=document_id,AttributeType=S \
        AttributeName=chunk_index,AttributeType=N \
    --key-schema \
        AttributeName=chunk_id,KeyType=HASH \
        AttributeName=document_id,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --global-secondary-indexes \
        "[{
            \"IndexName\": \"document_id-chunk_index-index\",
            \"KeySchema\": [
                {\"AttributeName\": \"document_id\", \"KeyType\": \"HASH\"},
                {\"AttributeName\": \"chunk_index\", \"KeyType\": \"RANGE\"}
            ],
            \"Projection\": {\"ProjectionType\": \"ALL\"}
        }]" \
    --endpoint-url=$AWS_ENDPOINT_URL

# Create ingestion_jobs table
aws dynamodb create-table \
    --table-name ingestion_jobs \
    --attribute-definitions \
        AttributeName=job_id,AttributeType=S \
        AttributeName=status,AttributeType=S \
        AttributeName=started_at,AttributeType=S \
    --key-schema \
        AttributeName=job_id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --global-secondary-indexes \
        "[{
            \"IndexName\": \"status-started_at-index\",
            \"KeySchema\": [
                {\"AttributeName\": \"status\", \"KeyType\": \"HASH\"},
                {\"AttributeName\": \"started_at\", \"KeyType\": \"RANGE\"}
            ],
            \"Projection\": {\"ProjectionType\": \"ALL\"}
        }]" \
    --endpoint-url=$AWS_ENDPOINT_URL

echo "✅ DynamoDB tables created"

echo "📬 Creating SQS Queues..."

# Create main ingestion queue
aws sqs create-queue \
    --queue-name portfolio-ingestion-queue \
    --attributes VisibilityTimeout=300,MessageRetentionPeriod=86400 \
    --endpoint-url=$AWS_ENDPOINT_URL

# Create embedding queue
aws sqs create-queue \
    --queue-name portfolio-embedding-queue \
    --attributes VisibilityTimeout=300,MessageRetentionPeriod=86400 \
    --endpoint-url=$AWS_ENDPOINT_URL

# Create dead-letter queue
aws sqs create-queue \
    --queue-name portfolio-ingestion-dlq \
    --attributes MessageRetentionPeriod=1209600 \
    --endpoint-url=$AWS_ENDPOINT_URL

# Get DLQ ARN
DLQ_ARN=$(aws sqs get-queue-attributes \
    --queue-url http://localhost:4566/000000000000/portfolio-ingestion-dlq \
    --attribute-names QueueArn \
    --endpoint-url=$AWS_ENDPOINT_URL \
    --query 'Attributes.QueueArn' \
    --output text)

# Configure DLQ for main queue
aws sqs set-queue-attributes \
    --queue-url http://localhost:4566/000000000000/portfolio-ingestion-queue \
    --attributes "RedrivePolicy={\"deadLetterTargetArn\":\"${DLQ_ARN}\",\"maxReceiveCount\":\"3\"}" \
    --endpoint-url=$AWS_ENDPOINT_URL

echo "✅ SQS queues created"

echo "📊 Creating CloudWatch Log Groups..."

# Create log groups for Lambda functions
aws logs create-log-group \
    --log-group-name /aws/lambda/document-intake \
    --endpoint-url=$AWS_ENDPOINT_URL

aws logs create-log-group \
    --log-group-name /aws/lambda/document-processor \
    --endpoint-url=$AWS_ENDPOINT_URL

aws logs create-log-group \
    --log-group-name /aws/lambda/embedding-generator \
    --endpoint-url=$AWS_ENDPOINT_URL

echo "✅ CloudWatch log groups created"

echo "🎯 Creating EventBridge Rules..."

# Create scheduled rule for daily reindex (2 AM)
aws events put-rule \
    --name daily-reindex \
    --schedule-expression "cron(0 2 * * ? *)" \
    --state ENABLED \
    --endpoint-url=$AWS_ENDPOINT_URL

# Create monitoring rule (every 5 minutes)
aws events put-rule \
    --name process-monitoring \
    --schedule-expression "rate(5 minutes)" \
    --state ENABLED \
    --endpoint-url=$AWS_ENDPOINT_URL

echo "✅ EventBridge rules created"

echo "📋 Listing created resources..."

echo ""
echo "S3 Buckets:"
aws s3 ls --endpoint-url=$AWS_ENDPOINT_URL

echo ""
echo "DynamoDB Tables:"
aws dynamodb list-tables --endpoint-url=$AWS_ENDPOINT_URL --query 'TableNames'

echo ""
echo "SQS Queues:"
aws sqs list-queues --endpoint-url=$AWS_ENDPOINT_URL --query 'QueueUrls'

echo ""
echo "✅ LocalStack AWS resources initialized successfully!"
echo ""
echo "📝 Access URLs:"
echo "  - LocalStack Gateway: http://localhost:4566"
echo "  - S3 Raw Bucket: http://localhost:4566/portfolio-raw"
echo "  - DynamoDB Console: http://localhost:4566/dynamodb"
echo "  - SQS Console: http://localhost:4566/sqs"
echo ""
echo "🔧 Test with AWS CLI:"
echo "  aws s3 ls s3://portfolio-raw --endpoint-url=http://localhost:4566"
echo "  aws dynamodb scan --table-name document_registry --endpoint-url=http://localhost:4566"
echo "  aws sqs list-queues --endpoint-url=http://localhost:4566"
echo ""
