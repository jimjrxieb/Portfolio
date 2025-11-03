# AWS RAG Architecture for AI Practitioner Certification

**Purpose**: Demonstrate enterprise-grade RAG data ingestion using AWS services (LocalStack)
**Focus**: Data landing zone, metadata tracking, and scalable ingestion pipeline

---

## Architecture Overview

```
Data Sources → S3 Landing Zone → Processing Pipeline → Vector DB → Query API
                      ↓
                  DynamoDB Metadata
                      ↓
                  SQS Processing Queue
                      ↓
                  Lambda Functions
```

---

## AWS Services (LocalStack)

### 1. **S3 Buckets** (Object Storage)

**Purpose**: Multi-stage data landing zone

```
s3://portfolio-raw/              # Raw ingested documents
├── incoming/                    # New uploads (unprocessed)
├── processed/                   # Successfully processed
├── failed/                      # Processing failures
└── archived/                    # Historical data

s3://portfolio-embeddings/       # Generated embeddings (backup)
├── vectors/                     # Embedding vectors
└── metadata/                    # Embedding metadata

s3://portfolio-config/           # Configuration files
├── ingestion-rules/             # Processing rules
└── model-configs/               # Model configurations
```

**Benefits**:
- Versioning enabled (track changes)
- Lifecycle policies (auto-archive old data)
- Event notifications (trigger processing)
- Server-side encryption

### 2. **DynamoDB Tables** (Metadata & State)

#### Table: `document_registry`
**Purpose**: Track all documents in the system

```python
Partition Key: document_id (String)
Sort Key: version (Number)

Attributes:
- document_id: UUID
- s3_key: S3 object path
- filename: Original filename
- upload_timestamp: ISO8601
- file_size: Bytes
- file_type: Extension (md, txt, pdf)
- status: PENDING | PROCESSING | COMPLETED | FAILED
- processing_started_at: ISO8601
- processing_completed_at: ISO8601
- chunk_count: Number of chunks created
- embedding_model: sentence-transformers/all-MiniLM-L6-v2
- error_message: If status=FAILED
- metadata: JSON (custom fields)

GSI: status-upload_timestamp-index
- Partition: status
- Sort: upload_timestamp
- Purpose: Query by status efficiently
```

#### Table: `embedding_chunks`
**Purpose**: Track individual chunks and their embeddings

```python
Partition Key: chunk_id (String)
Sort Key: document_id (String)

Attributes:
- chunk_id: UUID
- document_id: Reference to parent document
- chunk_index: Position in document (0, 1, 2...)
- content: Text content
- content_hash: SHA256 of content
- embedding_vector_s3: S3 path to vector file
- chromadb_id: ID in ChromaDB
- token_count: Approximate tokens
- created_at: ISO8601

GSI: document_id-chunk_index-index
- Partition: document_id
- Sort: chunk_index
- Purpose: Get all chunks for a document
```

#### Table: `ingestion_jobs`
**Purpose**: Track batch ingestion operations

```python
Partition Key: job_id (String)

Attributes:
- job_id: UUID
- job_type: BATCH | INCREMENTAL | REINDEX
- status: PENDING | RUNNING | COMPLETED | FAILED
- source_s3_prefix: S3 path
- documents_total: Count
- documents_processed: Count
- documents_failed: Count
- started_at: ISO8601
- completed_at: ISO8601
- error_details: JSON
- triggered_by: USER | SCHEDULED | EVENT

GSI: status-started_at-index
```

### 3. **SQS Queues** (Async Processing)

**Queue: `portfolio-ingestion-queue`**
- Purpose: Decouple S3 events from processing
- Message: Document metadata + S3 path
- Visibility timeout: 5 minutes
- Dead-letter queue: `portfolio-ingestion-dlq`
- Max receive count: 3

**Queue: `portfolio-embedding-queue`**
- Purpose: Chunking → Embedding pipeline
- Message: Chunk data
- Batch processing enabled

### 4. **Lambda Functions** (Processing Logic)

**Function: `document-intake`**
- Trigger: S3 ObjectCreated (raw bucket)
- Purpose: Validate and register new documents
- Flow:
  1. Read S3 event
  2. Validate file type and size
  3. Create entry in `document_registry`
  4. Send to `portfolio-ingestion-queue`

**Function: `document-processor`**
- Trigger: SQS `portfolio-ingestion-queue`
- Purpose: Process documents into chunks
- Flow:
  1. Download document from S3
  2. Sanitize content
  3. Chunk into 1000-token segments
  4. Create entries in `embedding_chunks`
  5. Send chunks to `portfolio-embedding-queue`
  6. Update document status

**Function: `embedding-generator`**
- Trigger: SQS `portfolio-embedding-queue`
- Purpose: Generate embeddings and store in ChromaDB
- Flow:
  1. Receive chunk data
  2. Generate embedding (sentence-transformers)
  3. Store in ChromaDB
  4. Backup vector to S3
  5. Update chunk metadata

### 5. **EventBridge** (Orchestration)

**Rule: `daily-reindex`**
- Schedule: cron(0 2 * * ? *)  # 2 AM daily
- Target: Lambda `batch-reindex`
- Purpose: Rebuild indexes if needed

**Rule: `process-monitoring`**
- Schedule: rate(5 minutes)
- Target: Lambda `check-health`
- Purpose: Monitor pipeline health

### 6. **CloudWatch** (Monitoring)

**Logs**:
- `/aws/lambda/document-intake`
- `/aws/lambda/document-processor`
- `/aws/lambda/embedding-generator`

**Metrics**:
- Custom: `IngestedDocuments`
- Custom: `ProcessingDuration`
- Custom: `FailedChunks`
- Custom: `ChromaDBErrors`

**Alarms**:
- High error rate (>5% failures)
- Slow processing (>5 min average)
- Queue depth (>100 messages)

---

## Data Flow

### Ingestion Pipeline

```
1. Upload Document
   ↓
   S3: s3://portfolio-raw/incoming/doc.md
   ↓
   [S3 Event Trigger]
   ↓
   Lambda: document-intake
   ↓
   DynamoDB: document_registry (status=PENDING)
   ↓
   SQS: portfolio-ingestion-queue
   ↓
   Lambda: document-processor
   ↓
   - Chunk document
   - Store chunks in DynamoDB
   - Update status=PROCESSING
   ↓
   SQS: portfolio-embedding-queue (per chunk)
   ↓
   Lambda: embedding-generator
   ↓
   - Generate embedding
   - Store in ChromaDB
   - Backup to S3
   - Update DynamoDB
   ↓
   DynamoDB: document_registry (status=COMPLETED)
   ↓
   S3: Move to s3://portfolio-raw/processed/
```

### Query Pipeline

```
User Query
   ↓
   FastAPI: POST /api/chat
   ↓
   Generate query embedding
   ↓
   ChromaDB: Semantic search (top 5 chunks)
   ↓
   DynamoDB: Fetch chunk metadata (source, timestamp)
   ↓
   Format context with citations
   ↓
   OpenAI API: GPT-4o mini
   ↓
   Validate response (anti-hallucination)
   ↓
   Return answer + citations
```

---

## Benefits for AWS AI Practitioner Certification

### Demonstrates Knowledge of:

1. **Data Engineering**
   - Multi-stage data pipeline (raw → processed → archived)
   - Event-driven architecture (S3 → SQS → Lambda)
   - Batch vs real-time processing

2. **AWS Services**
   - S3: Object storage, versioning, lifecycle policies
   - DynamoDB: NoSQL, GSI design, query patterns
   - Lambda: Serverless compute, event triggers
   - SQS: Async processing, DLQ, visibility timeout
   - EventBridge: Scheduled tasks, event routing
   - CloudWatch: Logging, metrics, alarms

3. **AI/ML Best Practices**
   - Embedding generation (sentence-transformers)
   - Vector search (ChromaDB)
   - RAG (Retrieval-Augmented Generation)
   - LLM integration (OpenAI GPT-4o mini)
   - Response validation

4. **Operational Excellence**
   - Monitoring and alerting
   - Error handling (DLQ, retries)
   - Idempotency (SHA256 content hashing)
   - Audit trail (DynamoDB metadata)

---

## Implementation Plan

### Phase 1: LocalStack Setup (Week 1)

- [ ] Install LocalStack
- [ ] Configure S3 buckets
- [ ] Create DynamoDB tables
- [ ] Set up SQS queues
- [ ] Test basic AWS CLI operations

### Phase 2: Lambda Functions (Week 2)

- [ ] Build `document-intake` Lambda
- [ ] Build `document-processor` Lambda
- [ ] Build `embedding-generator` Lambda
- [ ] Test end-to-end pipeline
- [ ] Add error handling

### Phase 3: Integration (Week 3)

- [ ] Connect S3 events to Lambda
- [ ] Configure SQS triggers
- [ ] Set up EventBridge rules
- [ ] Add CloudWatch monitoring
- [ ] Test failure scenarios

### Phase 4: API Updates (Week 4)

- [ ] Update FastAPI to query DynamoDB
- [ ] Add document upload endpoint
- [ ] Add ingestion status endpoint
- [ ] Add re-indexing endpoint
- [ ] Document API with OpenAPI

### Phase 5: Demo & Documentation (Week 5)

- [ ] Create demo dataset
- [ ] Record ingestion pipeline demo
- [ ] Document architecture diagrams
- [ ] Write troubleshooting guide
- [ ] Prepare certification presentation

---

## Cost Comparison (Prod vs LocalStack)

### Production AWS (Monthly Estimate)

```
S3: 10GB storage = $0.23
DynamoDB: 10GB + 1M reads + 100K writes = $3.00
Lambda: 1M requests @ 512MB/1s = $2.00
SQS: 1M requests = $0.40
EventBridge: 1M events = $1.00
CloudWatch: Logs 5GB = $2.50
Total: ~$10/month (low volume)
```

### LocalStack (Development)

```
LocalStack Community: Free
LocalStack Pro: $35/month (advanced features)
Local compute: $0 (your laptop/server)
```

---

## Directory Structure

```
Portfolio/
├── aws/
│   ├── lambda/
│   │   ├── document-intake/
│   │   │   ├── handler.py
│   │   │   └── requirements.txt
│   │   ├── document-processor/
│   │   │   ├── handler.py
│   │   │   └── requirements.txt
│   │   └── embedding-generator/
│   │       ├── handler.py
│   │       └── requirements.txt
│   ├── dynamodb/
│   │   ├── schemas/
│   │   │   ├── document_registry.json
│   │   │   ├── embedding_chunks.json
│   │   │   └── ingestion_jobs.json
│   │   └── seed_data/
│   ├── s3/
│   │   └── lifecycle-policies.json
│   ├── eventbridge/
│   │   └── rules.json
│   └── cloudwatch/
│       ├── alarms.json
│       └── dashboards.json
├── localstack/
│   ├── init-aws.sh           # Bootstrap AWS resources
│   └── docker-compose.localstack.yml
└── scripts/
    ├── upload-to-s3.py       # Upload documents
    ├── trigger-ingestion.py  # Manual trigger
    └── check-status.py       # Monitor progress
```

---

## LocalStack Configuration

### docker-compose.localstack.yml

```yaml
version: '3.8'

services:
  localstack:
    image: localstack/localstack:latest
    ports:
      - "4566:4566"            # LocalStack gateway
      - "4510-4559:4510-4559"  # External services port range
    environment:
      - SERVICES=s3,dynamodb,sqs,lambda,events,logs,cloudwatch
      - DEBUG=1
      - DATA_DIR=/tmp/localstack/data
      - LAMBDA_EXECUTOR=docker
      - DOCKER_HOST=unix:///var/run/docker.sock
    volumes:
      - "./localstack/init-aws.sh:/etc/localstack/init/ready.d/init-aws.sh"
      - "/var/run/docker.sock:/var/run/docker.sock"
      - "./localstack/data:/tmp/localstack/data"
    networks:
      - portfolio-network

  chromadb:
    image: chromadb/chroma:latest
    ports:
      - "8001:8000"
    volumes:
      - ./data/chroma:/chroma/data
    environment:
      - CHROMA_DB_IMPL=duckdb+parquet
      - CHROMA_PERSIST_DIRECTORY=/chroma/data
    networks:
      - portfolio-network

  api:
    build:
      context: .
      dockerfile: ./api/Dockerfile
    ports:
      - "8000:8000"
    environment:
      - CHROMA_URL=http://chromadb:8000
      - AWS_ENDPOINT_URL=http://localstack:4566
      - AWS_ACCESS_KEY_ID=test
      - AWS_SECRET_ACCESS_KEY=test
      - AWS_DEFAULT_REGION=us-east-1
      - OPENAI_API_KEY=${OPENAI_API_KEY:-}
    volumes:
      - ./data:/data
    depends_on:
      - chromadb
      - localstack
    networks:
      - portfolio-network

networks:
  portfolio-network:
    name: portfolio-network
```

---

## Environment Variables

```bash
# AWS (LocalStack)
AWS_ENDPOINT_URL=http://localhost:4566
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1

# S3 Buckets
S3_RAW_BUCKET=portfolio-raw
S3_EMBEDDINGS_BUCKET=portfolio-embeddings
S3_CONFIG_BUCKET=portfolio-config

# DynamoDB Tables
DYNAMODB_DOCUMENT_TABLE=document_registry
DYNAMODB_CHUNKS_TABLE=embedding_chunks
DYNAMODB_JOBS_TABLE=ingestion_jobs

# SQS Queues
SQS_INGESTION_QUEUE=portfolio-ingestion-queue
SQS_EMBEDDING_QUEUE=portfolio-embedding-queue
SQS_DLQ=portfolio-ingestion-dlq

# Processing
CHUNK_SIZE=1000
CHUNK_OVERLAP=200
EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2

# ChromaDB
CHROMA_URL=http://chromadb:8000
CHROMA_COLLECTION=portfolio_knowledge

# API
OPENAI_API_KEY=sk-...
GPT_MODEL=gpt-4o-mini
```

---

## Next Steps

1. Review this architecture
2. Confirm AWS services to use
3. Set up LocalStack environment
4. Build Lambda functions
5. Test end-to-end pipeline
6. Document for certification

Ready to start implementation? Let me know which phase you want to begin with!
