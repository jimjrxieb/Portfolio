# Quick Start: AWS RAG Data Landing Zone

**Purpose**: Set up LocalStack AWS environment for RAG data ingestion demo
**Target**: AWS AI Practitioner Certification

---

## Prerequisites

```bash
# Required
- Docker & Docker Compose
- Python 3.11+
- AWS CLI v2

# Install AWS CLI (if not installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

---

## Step 1: Start LocalStack

```bash
# From Portfolio directory
cd /home/jimmie/linkops-industries/Portfolio

# Start LocalStack + ChromaDB + API
docker-compose -f docker-compose.localstack.yml up -d

# Check status
docker-compose -f docker-compose.localstack.yml ps

# Expected output:
# NAME                    STATUS
# portfolio-localstack    Up (healthy)
# portfolio-chromadb      Up (healthy)
# portfolio-api           Up (healthy)
# portfolio-ui            Up
```

---

## Step 2: Verify AWS Resources

The init script (`localstack/init-aws.sh`) automatically creates:

### Check S3 Buckets

```bash
aws s3 ls --endpoint-url=http://localhost:4566

# Expected output:
# portfolio-raw
# portfolio-embeddings
# portfolio-config
```

### Check DynamoDB Tables

```bash
aws dynamodb list-tables \
    --endpoint-url=http://localhost:4566 \
    --region us-east-1

# Expected output:
# {
#     "TableNames": [
#         "document_registry",
#         "embedding_chunks",
#         "ingestion_jobs"
#     ]
# }
```

### Check SQS Queues

```bash
aws sqs list-queues --endpoint-url=http://localhost:4566

# Expected output:
# {
#     "QueueUrls": [
#         "http://localhost:4566/000000000000/portfolio-ingestion-queue",
#         "http://localhost:4566/000000000000/portfolio-embedding-queue",
#         "http://localhost:4566/000000000000/portfolio-ingestion-dlq"
#     ]
# }
```

---

## Step 3: Upload Test Document to S3

```bash
# Upload a knowledge document
aws s3 cp data/knowledge/01-bio.md \
    s3://portfolio-raw/incoming/01-bio.md \
    --endpoint-url=http://localhost:4566

# Verify upload
aws s3 ls s3://portfolio-raw/incoming/ \
    --endpoint-url=http://localhost:4566

# Expected output:
# 2025-11-03 12:00:00       2234 01-bio.md
```

---

## Step 4: Check DynamoDB for Metadata

```bash
# Scan document_registry table
aws dynamodb scan \
    --table-name document_registry \
    --endpoint-url=http://localhost:4566 \
    --region us-east-1

# Expected: Empty initially (Lambda will populate)
# {
#     "Items": [],
#     "Count": 0,
#     "ScannedCount": 0
# }
```

---

## Step 5: Test ChromaDB

```bash
# Check ChromaDB health
curl http://localhost:8001/api/v1/heartbeat

# Expected: {"nanosecond heartbeat": 1730000000000000000}

# List collections
curl http://localhost:8001/api/v1/collections

# Expected: {"collections": ["portfolio_knowledge"]}
```

---

## Step 6: Test FastAPI

```bash
# Health check
curl http://localhost:8000/health

# Expected: {"status": "healthy", "service": "portfolio-api"}

# Debug AWS configuration
curl http://localhost:8000/api/debug/aws-config

# Chat with RAG system
curl -X POST http://localhost:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is your DevOps experience?"}'
```

---

## Directory Structure Created

```
Portfolio/
├── AWS_RAG_ARCHITECTURE.md        # Architecture documentation
├── QUICK_START_AWS_RAG.md         # This file
├── docker-compose.localstack.yml  # LocalStack docker-compose
├── localstack/
│   ├── init-aws.sh                # AWS resource initialization
│   └── data/                      # LocalStack persistence
├── aws/
│   └── lambda/                    # Lambda functions (next step)
└── data/
    ├── chroma/                    # ChromaDB storage
    └── knowledge/                 # 22 markdown docs
```

---

## AWS CLI Configuration

Create `~/.aws/config`:

```ini
[profile localstack]
region = us-east-1
output = json
endpoint_url = http://localhost:4566
```

Create `~/.aws/credentials`:

```ini
[localstack]
aws_access_key_id = test
aws_secret_access_key = test
```

### Usage

```bash
# Use LocalStack profile
aws s3 ls --profile localstack

# Or set environment variables
export AWS_PROFILE=localstack
export AWS_ENDPOINT_URL=http://localhost:4566
aws s3 ls
```

---

## Useful Commands

### View Logs

```bash
# LocalStack logs
docker logs portfolio-localstack -f

# API logs
docker logs portfolio-api -f

# ChromaDB logs
docker logs portfolio-chromadb -f
```

### Reset Environment

```bash
# Stop all services
docker-compose -f docker-compose.localstack.yml down

# Remove volumes (complete reset)
docker-compose -f docker-compose.localstack.yml down -v

# Remove LocalStack data
rm -rf localstack/data/*

# Start fresh
docker-compose -f docker-compose.localstack.yml up -d
```

### Access LocalStack UI (if using Pro)

```
http://localhost:4566/_localstack/dashboard
```

---

## Data Flow Demo Script

### 1. Upload Document

```bash
# Upload to S3 landing zone
aws s3 cp data/knowledge/06-jade.md \
    s3://portfolio-raw/incoming/06-jade.md \
    --endpoint-url=http://localhost:4566
```

### 2. Trigger Processing (Manual - Lambda not yet built)

```bash
# Read document
CONTENT=$(cat data/knowledge/06-jade.md)

# Send to processing queue
aws sqs send-message \
    --queue-url http://localhost:4566/000000000000/portfolio-ingestion-queue \
    --message-body "$CONTENT" \
    --endpoint-url=http://localhost:4566
```

### 3. Check Queue

```bash
# Get queue attributes
aws sqs get-queue-attributes \
    --queue-url http://localhost:4566/000000000000/portfolio-ingestion-queue \
    --attribute-names All \
    --endpoint-url=http://localhost:4566
```

### 4. Register in DynamoDB (Manual)

```bash
# Create document entry
aws dynamodb put-item \
    --table-name document_registry \
    --item '{
        "document_id": {"S": "doc-001"},
        "version": {"N": "1"},
        "filename": {"S": "06-jade.md"},
        "s3_key": {"S": "incoming/06-jade.md"},
        "status": {"S": "PENDING"},
        "upload_timestamp": {"S": "2025-11-03T12:00:00Z"},
        "file_size": {"N": "3600"},
        "file_type": {"S": "md"}
    }' \
    --endpoint-url=http://localhost:4566

# Query document
aws dynamodb get-item \
    --table-name document_registry \
    --key '{"document_id": {"S": "doc-001"}, "version": {"N": "1"}}' \
    --endpoint-url=http://localhost:4566
```

---

## Troubleshooting

### LocalStack Not Starting

```bash
# Check Docker
docker ps

# Check LocalStack logs
docker logs portfolio-localstack

# Restart LocalStack
docker restart portfolio-localstack
```

### AWS CLI Errors

```bash
# Verify endpoint
echo $AWS_ENDPOINT_URL
# Should be: http://localhost:4566

# Test connectivity
curl http://localhost:4566/_localstack/health

# Check credentials
aws configure list
```

### S3 Permission Errors

```bash
# LocalStack uses fake credentials
# Ensure you're using:
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
```

### DynamoDB Not Created

```bash
# Check init script ran
docker logs portfolio-localstack | grep "DynamoDB"

# Manually run init script
docker exec portfolio-localstack /etc/localstack/init/ready.d/init-aws.sh
```

---

## Next Steps

1. ✅ LocalStack running with S3, DynamoDB, SQS
2. ✅ ChromaDB ready for embeddings
3. ✅ FastAPI connected to AWS services
4. ⏭️ Build Lambda functions for processing
5. ⏭️ Connect S3 events to Lambda triggers
6. ⏭️ Test end-to-end ingestion pipeline
7. ⏭️ Add CloudWatch monitoring
8. ⏭️ Create certification demo

---

## Certification Demo Talking Points

When demonstrating for AWS AI Practitioner certification:

1. **Data Landing Zone**
   - "I've created a multi-stage S3 landing zone with incoming/processed/failed folders"
   - "This allows tracking document lifecycle from upload to processing"

2. **Metadata Tracking**
   - "DynamoDB tables track document registry, embedding chunks, and job status"
   - "GSI indexes enable efficient queries by status and timestamp"

3. **Async Processing**
   - "SQS queues decouple S3 events from processing for scalability"
   - "Dead-letter queues capture failures for debugging"

4. **RAG Pipeline**
   - "Documents are chunked into 1000-token segments with 200-token overlap"
   - "sentence-transformers generate 384-dimensional embeddings"
   - "ChromaDB provides fast vector similarity search"

5. **LLM Integration**
   - "OpenAI GPT-4o mini generates responses from retrieved context"
   - "Response validation prevents hallucinations"
   - "Citations link answers back to source documents"

6. **Observability**
   - "CloudWatch logs capture processing metrics"
   - "EventBridge schedules daily reindexing"
   - "Health checks monitor service availability"

---

Ready to build the Lambda functions? 🚀
