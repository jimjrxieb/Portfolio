# Portfolio Infrastructure Deployment - Comprehensive Technical Documentation

**Last Updated:** November 2025  
**Purpose:** Complete reference documentation for the Portfolio platform's three deployment methods with detailed Kubernetes manifests, Terraform configurations, and security implementations.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Deployment Methods Overview](#deployment-methods-overview)
3. [Method 1: Simple Kubernetes (kubectl)](#method-1-simple-kubernetes-kubectl)
4. [Method 2: Terraform + LocalStack](#method-2-terraform--localstack)
5. [Method 3: Helm + ArgoCD (Production)](#method-3-helm--argocd-production)
6. [Kubernetes Resources Architecture](#kubernetes-resources-architecture)
7. [Terraform Module Structure](#terraform-module-structure)
8. [Security Policies and Enforcement](#security-policies-and-enforcement)
9. [Infrastructure Patterns & Best Practices](#infrastructure-patterns--best-practices)
10. [Configuration Details](#configuration-details)

---

## Executive Summary

The Portfolio platform implements a **three-tier deployment strategy** providing flexibility from local development to production-grade infrastructure:

- **Method 1:** Simple kubectl - Quick local development (5 minutes)
- **Method 2:** Terraform + LocalStack - Production-like testing locally (15 minutes)
- **Method 3:** Helm + ArgoCD - Real AWS production deployment (30+ minutes)

Each method builds upon the previous, sharing common security policies and Kubernetes patterns while increasing complexity and production-readiness.

### Core Stack Components

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Frontend** | React + Vite | Web UI with TypeScript |
| **Backend** | FastAPI + Python | REST API with RAG capabilities |
| **Vector DB** | ChromaDB | Embedding storage for RAG |
| **Orchestration** | Kubernetes | Container orchestration |
| **Infrastructure as Code** | Terraform | AWS resource management |
| **Package Management** | Helm | Kubernetes application packaging |
| **GitOps** | ArgoCD | Automated deployment from Git |
| **Cloud Provider** | AWS (or LocalStack) | Infrastructure hosting |

---

## Deployment Methods Overview

### Comparison Matrix

| Feature | Method 1 | Method 2 | Method 3 |
|---------|----------|----------|----------|
| **Deployment Tool** | kubectl | Terraform | Helm + ArgoCD |
| **AWS Services** | None | LocalStack | Real AWS |
| **Infrastructure as Code** | No | Yes | Yes |
| **GitOps Support** | No | No | Yes |
| **Production Ready** | No | No | Yes |
| **Time to Deploy** | 5 min | 15 min | 30+ min |
| **Learning Curve** | Easy | Medium | Hard |
| **Suitable For** | Learning | Testing AWS | Production |
| **Cost** | Free | Free | $$$$ |
| **Rollback Capability** | Manual | Terraform | Automatic |
| **Blue-Green Deployment** | No | No | Yes |
| **Monitoring Integration** | Manual | Manual | Built-in |

---

## Method 1: Simple Kubernetes (kubectl)

### Purpose and Use Cases

**When to use:**
- Learning Kubernetes basics
- Rapid local development iteration
- Quick prototyping
- No AWS service requirements
- Single developer or small teams

### Prerequisites

- Docker Desktop with Kubernetes enabled
- kubectl configured and connected to Docker Desktop Kubernetes
- Ollama running locally (for embeddings: `ollama serve`)
- NGINX Ingress Controller installed
- 8GB+ RAM available

### Installation Steps

#### 1. Enable NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

This creates:
- `ingress-nginx` namespace
- NGINX controller deployment
- Service with LoadBalancer type
- ConfigMap for NGINX settings

#### 2. Start Ollama

```bash
# Terminal 1: Start Ollama server
ollama serve

# Terminal 2: Pull embedding model
ollama pull nomic-embed-text
```

#### 3. Create Kubernetes Resources

```bash
cd infrastructure/method1-simple-kubectl

# Create namespace first
kubectl apply -f 01-namespace.yaml

# Create secrets (with your real API keys)
kubectl create secret generic portfolio-api-secrets \
  --from-literal=CLAUDE_API_KEY="your-key" \
  --from-literal=OPENAI_API_KEY="your-key" \
  --from-literal=ELEVENLABS_API_KEY="your-key" \
  --from-literal=DID_API_KEY="your-key" \
  -n portfolio

# Or apply all at once (order preserved by numbering)
kubectl apply -f .
```

### Kubernetes Manifest Architecture

#### 01-namespace.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: portfolio
  labels:
    name: portfolio
    environment: development
```

**Purpose:** Isolates all Portfolio resources in dedicated namespace for resource management and RBAC.

#### 02-secrets-example.yaml

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: portfolio-api-secrets
  namespace: portfolio
type: Opaque
stringData:
  CLAUDE_API_KEY: "REPLACE_WITH_YOUR_CLAUDE_API_KEY"
  OPENAI_API_KEY: "REPLACE_WITH_YOUR_OPENAI_API_KEY"
  ELEVENLABS_API_KEY: "REPLACE_WITH_YOUR_ELEVENLABS_API_KEY"
  DID_API_KEY: "REPLACE_WITH_YOUR_DID_API_KEY"
```

**Purpose:** Stores sensitive API keys as Kubernetes Secret. Referenced by API deployment.

**Security:** 
- Encrypted at rest in etcd (when configured)
- Only mounted in API container
- Type: Opaque (base64 encoded, not encrypted by default)

#### 03-chroma-pv-local.yaml

Defines persistent storage for ChromaDB vector database:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: chroma-pv-local
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /home/jimmie/linkops-industries/Portfolio/data/chroma
    type: DirectoryOrCreate
  persistentVolumeReclaimPolicy: Retain
```

**Configuration Details:**
- **Storage Size:** 5Gi (adjustable based on embedding volume)
- **Storage Class:** manual (local development only)
- **Access Mode:** ReadWriteOnce (single node access)
- **Host Path:** Local directory on host machine
- **Reclaim Policy:** Retain (data persists after PVC deletion)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: chroma-data
  namespace: portfolio
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  selector:
    matchLabels:
      type: local
```

**How it works:**
1. PV defines physical storage location
2. PVC requests storage from available PVs
3. Selector matches labels between PV and PVC
4. Pod mounts PVC, getting access to underlying storage

#### 04-chroma-deployment.yaml

ChromaDB Deployment (Vector Database):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chroma
  namespace: portfolio
  labels:
    app: chroma
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chroma
  template:
    metadata:
      labels:
        app: chroma
    spec:
      containers:
        - name: chroma
          image: chromadb/chroma:0.5.18
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8000
              name: http
          env:
            - name: IS_PERSISTENT
              value: "TRUE"
            - name: ANONYMIZED_TELEMETRY
              value: "FALSE"
          resources:
            requests:
              cpu: "100m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          volumeMounts:
            - name: data
              mountPath: /chroma/chroma
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: chroma-data
```

**Configuration:**
- **Image:** chromadb/chroma:0.5.18
- **Port:** 8000 (HTTP)
- **Persistence:** Mounted to `/chroma/chroma`
- **Resources:**
  - Requests: 100m CPU, 256Mi RAM (minimum guaranteed)
  - Limits: 500m CPU, 512Mi RAM (maximum allowed)

**Environment Variables:**
- `IS_PERSISTENT=TRUE`: Enables persistent storage mode
- `ANONYMIZED_TELEMETRY=FALSE`: Disables telemetry collection

Includes Service for internal DNS resolution:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: chroma
  namespace: portfolio
spec:
  selector:
    app: chroma
  ports:
    - port: 8000
      targetPort: 8000
      protocol: TCP
  type: ClusterIP
```

**Purpose:** Exposes ChromaDB internally as `http://chroma:8000` for API to connect.

#### 05-api-deployment.yaml

FastAPI Backend Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portfolio-api
  namespace: portfolio
  labels:
    app: portfolio-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: portfolio-api
  template:
    metadata:
      labels:
        app: portfolio-api
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
      containers:
        - name: api
          image: ghcr.io/shadow-link-industries/portfolio-api:main-latest
          imagePullPolicy: IfNotPresent
          securityContext:
            runAsNonRoot: true
            runAsUser: 10001
            runAsGroup: 10001
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
          ports:
            - containerPort: 8000
              name: http
          env:
            - name: LLM_PROVIDER
              value: "claude"
            - name: LLM_MODEL
              value: "claude-3-haiku-20240307"
            - name: OLLAMA_URL
              value: "http://host.docker.internal:11434"
            - name: EMBED_MODEL
              value: "nomic-embed-text"
            - name: CHROMA_HOST
              value: "chroma"
            - name: CHROMA_PORT
              value: "8000"
            - name: CHROMA_URL
              value: "file:///chroma-data"
            - name: CLAUDE_API_KEY
              valueFrom:
                secretKeyRef:
                  name: portfolio-api-secrets
                  key: CLAUDE_API_KEY
            # ... other API keys from secrets
          resources:
            requests:
              cpu: "200m"
              memory: "512Mi"
            limits:
              cpu: "1"
              memory: "2Gi"
          volumeMounts:
            - name: data
              mountPath: /data
            - name: tmp
              mountPath: /tmp
            - name: chroma-data
              mountPath: /chroma-data
      volumes:
        - name: data
          emptyDir: {}
        - name: tmp
          emptyDir: {}
        - name: chroma-data
          persistentVolumeClaim:
            claimName: chroma-data
```

**Security Context Details:**
- **runAsNonRoot: true** - Container must run as non-root user
- **runAsUser: 10001** - Run as UID 10001 (non-system user)
- **allowPrivilegeEscalation: false** - Prevent privilege escalation
- **readOnlyRootFilesystem: true** - Read-only root FS (with /tmp, /var/tmp writable)
- **capabilities.drop: ALL** - Remove all Linux capabilities

**Environment Variables:**
- LLM configuration (Claude, OpenAI fallback)
- Ollama connection for embeddings
- ChromaDB connection details
- Secret references for API keys

**Resources:**
- **Requests:** 200m CPU, 512Mi RAM
- **Limits:** 1 CPU, 2Gi RAM

**Volumes:**
- `data`: emptyDir for runtime data
- `tmp`: emptyDir for temporary files
- `chroma-data`: PVC mount to ChromaDB storage

#### 06-ui-deployment.yaml

React Frontend Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portfolio-ui
  namespace: portfolio
  labels:
    app: portfolio-ui
spec:
  replicas: 1
  selector:
    matchLabels:
      app: portfolio-ui
  template:
    metadata:
      labels:
        app: portfolio-ui
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
      containers:
        - name: ui
          image: ghcr.io/shadow-link-industries/portfolio-ui:main-latest
          imagePullPolicy: IfNotPresent
          securityContext:
            runAsNonRoot: true
            runAsUser: 10001
            runAsGroup: 10001
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
          ports:
            - containerPort: 80
              name: http
          env:
            - name: VITE_API_BASE_URL
              value: ""
          resources:
            requests:
              cpu: "50m"
              memory: "128Mi"
            limits:
              cpu: "200m"
              memory: "256Mi"
          volumeMounts:
            - name: nginx-cache
              mountPath: /var/cache/nginx
            - name: nginx-run
              mountPath: /var/run
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: nginx-cache
          emptyDir: {}
        - name: nginx-run
          emptyDir: {}
        - name: tmp
          emptyDir: {}
```

**Configuration:**
- **Port:** 80 (HTTP)
- **Security:** Same hardened context as API
- **Resources:**
  - Requests: 50m CPU, 128Mi RAM (minimal for static content)
  - Limits: 200m CPU, 256Mi RAM

**Environment:**
- `VITE_API_BASE_URL`: Base URL for API calls (empty = relative)

#### 07-ingress.yaml

NGINX Ingress Controller Configuration:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: portfolio
  namespace: portfolio
  annotations:
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-headers: "Content-Type, Authorization"
spec:
  ingressClassName: nginx
  rules:
    - host: portfolio.localtest.me
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: portfolio-api
                port:
                  number: 8000
          - path: /
            pathType: Prefix
            backend:
              service:
                name: portfolio-ui
                port:
                  number: 80
    - host: linksmlm.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: portfolio-api
                port:
                  number: 8000
          - path: /
            pathType: Prefix
            backend:
              service:
                name: portfolio-ui
                port:
                  number: 80
```

**Routing Rules:**
- `/api` routes to `portfolio-api:8000`
- `/` routes to `portfolio-ui:80`
- Supports both `portfolio.localtest.me` and `linksmlm.com` domains

**CORS Configuration:**
- Allows all origins: `*`
- Methods: GET, POST, OPTIONS
- Headers: Content-Type, Authorization

### Deployment Order and Dependencies

The numbered files enforce correct deployment order:

1. **01-namespace.yaml** - Create namespace (prerequisite)
2. **02-secrets-example.yaml** - Create secrets (required by API)
3. **03-chroma-pv-local.yaml** - Create persistent volume (required by ChromaDB)
4. **04-chroma-deployment.yaml** - Deploy ChromaDB (required by API)
5. **05-api-deployment.yaml** - Deploy API
6. **06-ui-deployment.yaml** - Deploy UI
7. **07-ingress.yaml** - Create ingress (routes to services)

This order ensures all dependencies are satisfied.

### Verification and Access

```bash
# Check deployment status
kubectl get pods -n portfolio

# Check services
kubectl get svc -n portfolio

# Check ingress
kubectl get ingress -n portfolio

# View logs
kubectl logs -n portfolio deployment/portfolio-api
kubectl logs -n portfolio deployment/chroma
```

### Access URLs

- **UI:** http://portfolio.localtest.me
- **API:** http://portfolio.localtest.me/api
- **API Health:** http://portfolio.localtest.me/api/health

---

## Method 2: Terraform + LocalStack

### Purpose and Architecture

**When to use:**
- Testing AWS services locally without costs
- Learning Terraform Infrastructure as Code
- Production-like environment on laptop
- Team development with consistent setup
- Integration testing with AWS services

### What Gets Deployed

**AWS Services (via LocalStack):**
- S3 Buckets (raw documents, embeddings, config)
- DynamoDB Tables (document registry, chunks, ingestion jobs)
- SQS Queues (ingestion, embedding, DLQ)
- CloudWatch Log Groups (for lambda functions)
- EventBridge Rules (scheduled tasks)
- IAM Roles and Policies

**Kubernetes Components:**
- API, UI, and ChromaDB deployments (via Terraform Kubernetes provider)
- Services and Ingress
- Network policies

### Prerequisites

- Docker Desktop with Kubernetes enabled
- Terraform 1.0+ installed
- LocalStack running via Docker Compose
- AWS CLI configured (even for local use)
- kubectl configured

### Infrastructure Setup

#### Starting LocalStack

```bash
docker-compose -f docker-compose.localstack.yml up -d
sleep 10
curl http://localhost:4566/_localstack/health
```

LocalStack runs on port 4566 and emulates all AWS services.

#### Terraform Provider Configuration

File: `infrastructure/method2-terraform-localstack/main.tf`

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3             = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    logs           = "http://localhost:4566"
    events         = "http://localhost:4566"
    iam            = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
}
```

**Key Points:**
- All endpoints point to LocalStack on port 4566
- Credentials are dummy values ("test")
- Skip validation flags prevent AWS account lookups
- Works with real AWS by removing endpoints block

### Terraform Module Structure

#### Storage Module (`modules/aws-resources/storage/main.tf`)

**S3 Buckets:**

```hcl
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

resource "aws_s3_bucket_versioning" "portfolio_raw" {
  bucket = aws_s3_bucket.portfolio_raw.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

**Purpose:**
- `portfolio-raw`: Stores uploaded documents
- `portfolio-embeddings`: Stores processed embeddings
- `portfolio-config`: Stores configuration files

**Versioning:** Enabled on raw bucket for document history.

**DynamoDB Tables:**

```hcl
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

  dynamic "server_side_encryption" {
    for_each = var.use_customer_managed_encryption ? [1] : []
    content {
      enabled     = true
      kms_key_arn = aws_kms_key.storage[0].arn
    }
  }
}
```

**Schema Details:**
- **Hash Key:** document_id (primary partition)
- **Range Key:** version (sort key)
- **GSI:** Queries by status with timestamp range
- **Encryption:** Optional KMS (conditional on var.use_customer_managed_encryption)

**Other Tables:**

```hcl
resource "aws_dynamodb_table" "embedding_chunks" {
  # Tracks individual text chunks and their embeddings
  hash_key       = "chunk_id"
  range_key      = "document_id"
  # GSI: query by document
}

resource "aws_dynamodb_table" "ingestion_jobs" {
  # Tracks document processing jobs
  hash_key       = "job_id"
  # GSI: query by status
}
```

**SQS Queues:**

```hcl
resource "aws_sqs_queue" "ingestion_queue" {
  name                       = "${var.project_name}-ingestion-queue"
  visibility_timeout_seconds = 300    # 5 minutes
  message_retention_seconds  = 86400  # 24 hours
}

resource "aws_sqs_queue" "embedding_queue" {
  name                       = "${var.project_name}-embedding-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
}

resource "aws_sqs_queue" "ingestion_dlq" {
  name                      = "${var.project_name}-ingestion-dlq"
  message_retention_seconds = 1209600  # 14 days
}

resource "aws_sqs_queue_redrive_policy" "ingestion_queue" {
  queue_url = aws_sqs_queue.ingestion_queue.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ingestion_dlq.arn
    maxReceiveCount     = 3  # Move to DLQ after 3 failures
  })
}
```

**Configuration:**
- **Visibility Timeout:** 300 seconds (time message is hidden from other consumers)
- **Retention:** 24 hours for main queues, 14 days for DLQ
- **DLQ Configuration:** Moves messages after 3 failed attempts

**CloudWatch Log Groups:**

```hcl
resource "aws_cloudwatch_log_group" "document_intake" {
  name              = "/aws/lambda/${var.project_name}-document-intake"
  retention_in_days = 7
  kms_key_id        = var.use_customer_managed_encryption ? aws_kms_key.storage[0].arn : null
}

resource "aws_cloudwatch_log_group" "document_processor" {
  name              = "/aws/lambda/${var.project_name}-document-processor"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "embedding_generator" {
  name              = "/aws/lambda/${var.project_name}-embedding-generator"
  retention_in_days = 7
}
```

**Logging Structure:**
- Follows AWS Lambda naming convention
- 7-day retention for local development
- Optional KMS encryption for compliance

#### KMS Encryption Module

File: `modules/aws-resources/storage/kms.tf`

```hcl
resource "aws_kms_key" "storage" {
  count = var.use_customer_managed_encryption ? 1 : 0

  description             = "KMS key for DynamoDB tables and CloudWatch log groups"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-storage-kms-key"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "storage" {
  count = var.use_customer_managed_encryption ? 1 : 0

  name          = "alias/${var.project_name}-storage"
  target_key_id = aws_kms_key.storage[0].key_id
}
```

**Configuration:**
- **Conditional:** Only created if `use_customer_managed_encryption = true`
- **Key Rotation:** Enabled for automatic annual rotation
- **Deletion Window:** 10 days (prevent accidental deletion)
- **Alias:** Easier reference than key ARN

#### Outputs Module

File: `modules/aws-resources/storage/outputs.tf`

```hcl
output "s3_buckets" {
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
```

These outputs can be referenced by other modules or exported to applications.

### Deployment Workflow

```bash
cd infrastructure/method2-terraform-localstack

# 1. Initialize (download providers)
terraform init

# 2. Plan (see what will be created)
terraform plan

# 3. Apply (create resources)
terraform apply

# 4. Verify
terraform output

# 5. Destroy (cleanup)
terraform destroy
```

### Testing AWS Services

After deployment, test services via LocalStack endpoint:

```bash
# List S3 buckets
aws s3 ls --endpoint-url=http://localhost:4566

# Upload file to S3
aws s3 cp test.md s3://portfolio-raw/incoming/ \
  --endpoint-url=http://localhost:4566

# Query DynamoDB
aws dynamodb scan \
  --table-name portfolio-document-registry \
  --endpoint-url=http://localhost:4566 | jq '.Items'

# Send SQS message
aws sqs send-message \
  --queue-url http://localhost:4566/000000000000/portfolio-ingestion-queue \
  --message-body "Test message" \
  --endpoint-url=http://localhost:4566
```

### Switching to Real AWS

To deploy to real AWS instead of LocalStack:

1. **Remove endpoints block** from `main.tf` provider
2. **Configure AWS credentials:**
   ```bash
   aws configure
   export AWS_ACCESS_KEY_ID="your-key"
   export AWS_SECRET_ACCESS_KEY="your-secret"
   ```
3. **Deploy:**
   ```bash
   terraform apply
   ```

**Warning:** This creates real AWS resources and may incur costs!

---

## Method 3: Helm + ArgoCD (Production)

### Purpose and Architecture

**When to use:**
- Production deployment to real AWS EKS
- GitOps workflow with automatic deployment
- Enterprise-grade infrastructure
- Automated rollouts and rollbacks
- Version controlled everything

### What Gets Deployed

**Kubernetes Resources (via Helm):**
- API Deployment (FastAPI)
- UI Deployment (React)
- ChromaDB Deployment (Vector DB)
- Services (ClusterIP for internal communication)
- Ingress (external access)
- NetworkPolicies (zero-trust networking)
- ResourceQuota (namespace limits)
- PersistentVolumeClaims (persistent storage)
- ServiceAccounts (security)
- SecurityContexts (hardened execution)

**GitOps (via ArgoCD):**
- Watches Git repository for changes
- Automatically syncs to cluster
- Supports rollback to previous versions
- Provides UI for deployment visualization

### Helm Chart Structure

#### Chart.yaml

```yaml
apiVersion: v2
name: portfolio
description: LinkOps Portfolio - RAG-powered AI platform
type: application
version: 0.1.0
appVersion: "1.0.0"
keywords:
  - portfolio
  - ai
  - rag
  - fastapi
  - react
home: https://github.com/shadow-link-industries/Portfolio
sources:
  - https://github.com/shadow-link-industries/Portfolio
maintainers:
  - name: jimmie012506
    email: jimmie012506@gmail.com
```

#### values.yaml (Default Values)

```yaml
# Image Configuration
image:
  repository: ghcr.io/shadow-link-industries/portfolio-api
  tag: "main-latest"
  pullPolicy: IfNotPresent

ui:
  image:
    repository: ghcr.io/shadow-link-industries/portfolio-ui
    tag: "main-latest"
    pullPolicy: IfNotPresent

# Deployment Configuration
replicaCount: 1

# Service Configuration
service:
  api:
    type: ClusterIP
    port: 8000
    targetPort: 8000
  ui:
    type: ClusterIP
    port: 80
    targetPort: 8080

# Ingress Configuration
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, OPTIONS"
  host: portfolio.localtest.me
  tls: false

# Resource Limits
resources:
  api:
    requests:
      cpu: "200m"
      memory: "512Mi"
    limits:
      cpu: "1"
      memory: "2Gi"
  ui:
    requests:
      cpu: "50m"
      memory: "128Mi"
    limits:
      cpu: "200m"
      memory: "256Mi"

# Security Context
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  fsGroup: 10001
  seccompProfile:
    type: RuntimeDefault

# Container Security
containerSecurityContext:
  runAsNonRoot: true
  runAsUser: 10001
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL

# Network Policy
networkPolicy:
  enabled: true
  ingressNamespace: "ingress-nginx"

# Pod Security Standards
podSecurityStandards:
  enabled: true
  enforce: "restricted"
  audit: "restricted"
  warn: "restricted"

# Resource Quotas
resourceQuotas:
  enabled: true
  hard:
    requests.cpu: "2"
    requests.memory: "4Gi"
    limits.cpu: "4"
    limits.memory: "8Gi"
    persistentvolumeclaims: "2"

# Environment Variables
env:
  api:
    LLM_PROVIDER: "claude"
    LLM_MODEL: "claude-3-5-sonnet-20241022"
    OLLAMA_URL: "http://localhost:11434"
    EMBED_MODEL: "nomic-embed-text"
  ui:
    VITE_API_BASE_URL: "http://portfolio.localtest.me/api"

# Secrets References
secretRefs:
  api:
    - name: portfolio-api-secrets
      keys:
        - CLAUDE_API_KEY
        - OPENAI_API_KEY
        - ELEVENLABS_API_KEY
        - DID_API_KEY

# Persistence
persistence:
  enabled: true
  size: 10Gi
  accessMode: ReadWriteOnce
  mountPath: /data

# ChromaDB
chroma:
  enabled: true
  image:
    repository: chromadb/chroma
    tag: "0.4.18"
  persistence:
    enabled: true
    size: 5Gi

# Autoscaling (disabled for now)
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
```

#### values.prod.yaml (Production Overrides)

```yaml
# Production image configuration
image:
  repository: ghcr.io/jimjrxieb/portfolio-api
  tag: "main-dev"
  pullPolicy: IfNotPresent

# Production ingress
ingress:
  enabled: true
  host: linksmlm.com
  tls: false  # Cloudflare handles TLS

# Production environment
env:
  api:
    DEBUG_MODE: "false"
    LOG_LEVEL: "INFO"
    LLM_PROVIDER: "claude"
    CORS_ALLOW_ORIGINS: "https://linksmlm.com"

# Security - slightly relaxed for local dev
networkPolicy:
  enabled: false  # For easier local testing
```

### Helm Template Examples

#### deployment-api.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "portfolio.fullname" . }}-api
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "portfolio.labels" . | nindent 4 }}
    app.kubernetes.io/component: api
spec:
  replicas: {{ .Values.replicaCount }}
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      {{- include "portfolio.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: api
  template:
    metadata:
      labels:
        {{- include "portfolio.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: api
    spec:
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "portfolio.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.securityContext | nindent 8 }}
      {{- if .Values.persistence.enabled }}
      initContainers:
        - name: fix-perms
          image: busybox:1.36
          securityContext:
            {{- toYaml .Values.initContainerSecurityContext | nindent 12 }}
          command:
            - sh
            - -c
            - |
              mkdir -p /data/uploads/images /data/uploads/audio /data/chroma
              chown -R {{ .Values.securityContext.runAsUser }}:{{ .Values.securityContext.runAsGroup }} /data
              chmod -R 755 /data
          volumeMounts:
            - name: data
              mountPath: /data
      {{- end }}
      containers:
        - name: api
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          securityContext:
            {{- toYaml .Values.containerSecurityContext | nindent 12 }}
            runAsUser: {{ .Values.securityContext.runAsUser }}
            runAsGroup: {{ .Values.securityContext.runAsGroup }}
          ports:
            - name: http
              containerPort: {{ .Values.service.api.targetPort }}
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /health/live
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health/ready
              port: http
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
          env:
            {{- range $key, $value := .Values.env.api }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
            {{- range .Values.secretRefs.api }}
            {{- range .keys }}
            - name: {{ . }}
              valueFrom:
                secretKeyRef:
                  name: {{ .name }}
                  key: {{ . }}
            {{- end }}
            {{- end }}
          resources:
            {{- toYaml .Values.resources.api | nindent 12 }}
          volumeMounts:
            {{- if .Values.persistence.enabled }}
            - name: data
              mountPath: {{ .Values.persistence.mountPath }}
            {{- end }}
            - name: tmp
              mountPath: /tmp
            - name: var-tmp
              mountPath: /var/tmp
            - name: var-cache
              mountPath: /var/cache
      volumes:
        {{- if .Values.persistence.enabled }}
        - name: data
          persistentVolumeClaim:
            claimName: {{ include "portfolio.fullname" . }}-data
        {{- end }}
        - name: tmp
          emptyDir: {}
        - name: var-tmp
          emptyDir: {}
        - name: var-cache
          emptyDir: {}
```

**Key Template Features:**
- Uses Helm template functions like `include`, `toYaml`, `nindent`
- References values from values.yaml
- Init container fixes file permissions
- Health probes for startup, readiness, and liveness
- Volume mounts for persistence and temporary storage

### ArgoCD Application Manifest

File: `argocd/portfolio-application.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: portfolio
  namespace: argocd
  labels:
    app.kubernetes.io/name: portfolio
    app.kubernetes.io/component: application
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/jimjrxieb/Portfolio.git
    path: infrastructure/method3-helm-argocd/helm-chart/portfolio
    targetRevision: HEAD
    helm:
      valueFiles:
        - values.yaml
      parameters:
        - name: global.imagePrefix
          value: ghcr.io/jimjrxieb/portfolio
        - name: ui.image.tag
          value: latest
        - name: api.image.tag
          value: latest
  destination:
    server: https://kubernetes.default.svc
    namespace: portfolio
  syncPolicy:
    automated:
      prune: true        # Delete resources not in Git
      selfHeal: true     # Auto-sync if cluster drifts
      allowEmpty: false  # Don't delete namespace
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m0s
  revisionHistoryLimit: 10
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas  # Ignore replica changes from HPA
```

**Key Configuration:**

- **Source:** Points to Git repo and Helm chart path
- **Destination:** Deploys to current cluster in `portfolio` namespace
- **Sync Policy:**
  - `automated.prune=true`: Removes resources deleted from Git
  - `automated.selfHeal=true`: Corrects cluster drift
  - `CreateNamespace=true`: Creates namespace if missing
- **Retry Policy:** Exponential backoff up to 3 minutes
- **Ignore Differences:** Ignores HPA-managed replica changes

### GitOps Workflow

```
Developer Changes → Git Push → GitHub Actions Build → Update Image Tag
                                                      ↓
ArgoCD Detects Change → Compares Git vs Cluster → Syncs Changes → Deployment Updated
                                                    ↑
                                            Watch for differences every 3 minutes
```

**Deployment Flow:**
1. Developer changes Helm values or deployment template
2. Commits and pushes to Git
3. ArgoCD detects change (automatic polling or webhook)
4. ArgoCD compares Git state vs cluster state
5. If different, automatically syncs (applies changes)
6. Kubernetes applies changes (rolling update)

---

## Kubernetes Resources Architecture

### Namespace Design

**Purpose:** Isolate Portfolio resources from other workloads

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: portfolio
  labels:
    name: portfolio
    environment: development
```

**Benefits:**
- Resource isolation (CPU, memory quotas per namespace)
- RBAC scoping (roles only apply within namespace)
- Network policy scoping (default-deny per namespace)
- Independent Secret management

### Deployment Strategy

**Pattern:** Rolling Update (gradual replacement)

```yaml
spec:
  replicas: 1
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # One extra pod during update
      maxUnavailable: 0  # Keep all pods available
```

For production with HPA enabled, use multiple replicas:
```yaml
replicas: 3  # Minimum for HA
```

### Pod Security Context

**Defense in Depth:** Multiple layers of container security

```yaml
spec:
  securityContext:
    runAsNonRoot: true          # Pod-level
    runAsUser: 10001             # UID 10001
    runAsGroup: 10001            # GID 10001
    fsGroup: 10001               # Volume ownership
    seccompProfile:
      type: RuntimeDefault       # Syscall filtering
  containers:
    - securityContext:
        readOnlyRootFilesystem: true  # Container-level
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
```

**Why Each Setting:**
- `runAsNonRoot`: Prevents root execution
- `runAsUser: 10001`: Non-system UID
- `readOnlyRootFilesystem`: Prevents modifying system
- `drop: ALL`: Removes all Linux capabilities
- `seccompProfile`: Filters dangerous syscalls

### Health Probes

**Three-tier health checking:**

```yaml
containers:
  - name: api
    livenessProbe:
      httpGet:
        path: /health/live
        port: 8000
      initialDelaySeconds: 30
      periodSeconds: 10
      failureThreshold: 3
    
    readinessProbe:
      httpGet:
        path: /health/ready
        port: 8000
      initialDelaySeconds: 10
      periodSeconds: 5
      failureThreshold: 3
    
    startupProbe:
      httpGet:
        path: /health/ready
        port: 8000
      initialDelaySeconds: 5
      periodSeconds: 5
      failureThreshold: 6
```

**Probe Types:**
- **Startup:** Waits for app to start (6 * 5s = 30 seconds max)
- **Readiness:** Traffic eligible when ready
- **Liveness:** Kills and restarts if not live

### Storage Architecture

**Two-tier persistence:**

```yaml
volumes:
  - name: data
    persistentVolumeClaim:
      claimName: chroma-data
  - name: tmp
    emptyDir: {}
  - name: var-cache
    emptyDir: {}

volumeMounts:
  - name: data
    mountPath: /data
  - name: tmp
    mountPath: /tmp
  - name: var-cache
    mountPath: /var/cache
```

**Storage Types:**
- **PVC:** Persisted across pod restarts (embeddings DB)
- **emptyDir:** Ephemeral, deleted with pod (temporary files)

### Service Discovery

**ClusterIP Services for internal communication:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: chroma
  namespace: portfolio
spec:
  selector:
    app: chroma
  ports:
    - port: 8000
      targetPort: 8000
  type: ClusterIP
```

**DNS:** Within cluster, accessible as `chroma.portfolio.svc.cluster.local`

### Ingress Routing

**NGINX Ingress Controller:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: portfolio
  namespace: portfolio
  annotations:
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
spec:
  ingressClassName: nginx
  rules:
    - host: portfolio.localtest.me
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: portfolio-api
                port:
                  number: 8000
          - path: /
            pathType: Prefix
            backend:
              service:
                name: portfolio-ui
                port:
                  number: 80
```

**Routing Logic:**
- `/api/*` → `portfolio-api:8000`
- `/*` → `portfolio-ui:80`
- External access via NGINX LoadBalancer

---

## Terraform Module Structure

### Module Organization

```
modules/
├── aws-resources/
│   ├── storage/          # S3, DynamoDB, SQS
│   │   ├── main.tf       # Resources
│   │   ├── kms.tf        # Encryption
│   │   ├── variables.tf  # Inputs
│   │   └── outputs.tf    # Outputs
│   ├── lambda/           # Lambda functions
│   └── secrets/          # Secret management
└── kubernetes-app/       # K8s deployments
    ├── main.tf
    ├── network-policies.tf
    ├── ingress.tf
    ├── variables.tf
    └── outputs.tf
```

### Resource Dependencies

```
KMS Key (optional)
  ↓
S3 Buckets ──→ Versioning
  ↓
DynamoDB Tables ──→ (encrypted by KMS)
  ↓
SQS Queues ──→ Dead Letter Queue Policy
  ↓
CloudWatch Log Groups (encrypted)
```

### Variable Management

**File: `variables.tf`**

```hcl
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "portfolio"
}

variable "environment" {
  description = "Environment (localstack, dev, prod)"
  type        = string
  default     = "localstack"
}

variable "use_customer_managed_encryption" {
  description = "Enable KMS encryption (false for dev, true for prod)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Environment = "localstack"
    ManagedBy   = "terraform"
  }
}
```

### State Management

**Best Practices:**
```bash
# Use remote state in production
terraform {
  backend "s3" {
    bucket         = "portfolio-terraform-state"
    key            = "portfolio/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

# Lock state to prevent concurrent modifications
terraform apply  # Acquires lock
terraform unlock # If stuck
```

### Destroying Resources

```bash
# See what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Destroy specific resource
terraform destroy -target=aws_s3_bucket.portfolio_raw
```

**Important:** In production, protect state file and add policy restrictions.

---

## Security Policies and Enforcement

### Security Layers

```
CI/CD Pipeline (Conftest)      ← Shift-left: catch issues early
         ↓
Admission Controller (Gatekeeper) ← Runtime: block non-compliant pods
         ↓
RBAC & Network Policies          ← Access control & segmentation
         ↓
Pod Security Standards            ← Container hardening
         ↓
Runtime Monitoring (Falco)        ← Detect anomalous behavior
```

### Gatekeeper Policies

**What:** OPA-based admission control enforcing policies at deployment time

**Three policy categories:**

#### 1. Security Policies

**File: `security/container-security.yaml`**

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: portfoliosecuritycontext
spec:
  crd:
    spec:
      names:
        kind: PortfolioSecurityContext
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package portfoliosecuritycontext

        # Deny root containers
        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          container.securityContext.runAsUser == 0
          msg := sprintf("Container '%s' cannot run as root", [container.name])
        }

        # Require security context
        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          not container.securityContext
          msg := sprintf("Container '%s' must define securityContext", [container.name])
        }

        # Deny privileged mode
        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          container.securityContext.privileged == true
          msg := sprintf("Container '%s' cannot run privileged", [container.name])
        }

        # Deny privilege escalation
        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          container.securityContext.allowPrivilegeEscalation == true
          msg := sprintf("Container '%s' cannot allow privilege escalation", [container.name])
        }

        # Require read-only root filesystem
        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          not container.securityContext.readOnlyRootFilesystem
          not container.name == "chromadb"  # Exception for ChromaDB
          msg := sprintf("Container '%s' should use readOnlyRootFilesystem", [container.name])
        }
---
apiVersion: config.gatekeeper.sh/v1alpha1
kind: PortfolioSecurityContext
metadata:
  name: portfolio-security-context
  namespace: portfolio
spec:
  match:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
      namespaces: ["portfolio"]
  parameters:
    allowedUsers: [10001]
```

#### 2. Image Security Policies

**File: `security/image-security.yaml`**

Controls which images can be deployed:

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: portfolioimagesecurity
spec:
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package portfolioimagesecurity

        # Block latest tags in production
        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          endswith(container.image, ":latest")
          input.review.object.metadata.namespace == "portfolio"
          msg := sprintf("Cannot use 'latest' tag in %s namespace", [input.review.object.metadata.namespace])
        }

        # Only allowed registries
        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          image := container.image
          not is_allowed_registry(image)
          msg := sprintf("Image %s not from allowed registry", [image])
        }

        is_allowed_registry(image) {
          startswith(image, "ghcr.io/jimjrxieb/")
        }
        is_allowed_registry(image) {
          startswith(image, "chromadb/")
        }

        # Require image tags
        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          not contains(container.image, ":")
          msg := sprintf("Image must have a tag: %s", [container.image])
        }

        # Require imagePullPolicy
        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          not container.imagePullPolicy
          msg := "Must specify imagePullPolicy"
        }
```

**Allowed Registries:**
- `ghcr.io/jimjrxieb/` - Portfolio images
- `chromadb/` - ChromaDB official
- `registry.k8s.io/` - Kubernetes core
- `docker.io/library/` - Docker official

#### 3. Resource Limits Policies

**File: `governance/resource-limits.yaml`**

Prevents resource starvation:

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: portfolioresourcelimits
spec:
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package portfolioresourcelimits

        # Require CPU limits
        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          not container.resources.limits.cpu
          msg := sprintf("Container '%s' must specify CPU limits", [container.name])
        }

        # Require memory limits
        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          not container.resources.limits.memory
          msg := sprintf("Container '%s' must specify memory limits", [container.name])
        }

        # Check CPU doesn't exceed 2 cores
        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          cpu_limit := container.resources.limits.cpu
          parse_cpu(cpu_limit) > 2000
          msg := sprintf("CPU limit exceeds maximum (2000m): %s", [cpu_limit])
        }
```

**Limits Enforced:**
- CPU: <= 2 cores (2000m)
- Memory: <= 2Gi
- All containers require requests and limits

### Pod Security Standards

**File: `compliance/pod-security-standards.yaml`**

Implements Kubernetes Pod Security Standards:

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: portfoliopodsecurity
spec:
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package portfoliopodsecurity

        # No host networking
        violation[{"msg": msg}] {
          input.review.object.spec.hostNetwork == true
          msg := "hostNetwork not allowed"
        }

        # No host PID
        violation[{"msg": msg}] {
          input.review.object.spec.hostPID == true
          msg := "hostPID not allowed"
        }

        # No host IPC
        violation[{"msg": msg}] {
          input.review.object.spec.hostIPC == true
          msg := "hostIPC not allowed"
        }

        # No dangerous capabilities
        denial_capabilities := ["SYS_ADMIN", "NET_ADMIN", "SYS_MODULE"]
        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          cap := container.securityContext.capabilities.add[_]
          cap in denial_capabilities
          msg := sprintf("Denied capability: %s", [cap])
        }

        # Require seccompProfile
        violation[{"msg": msg}] {
          not input.review.object.spec.securityContext.seccompProfile
          msg := "seccompProfile required"
        }
```

### Network Policies

**File: `shared-security/network-policies/default-deny-all.yaml`**

Zero-trust foundation:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: portfolio
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

**Effect:** All traffic denied by default. Must explicitly allow.

**Allow DNS Example:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: portfolio
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
```

### RBAC Configuration

**File: `shared-security/rbac/service-accounts.yaml`**

Least-privilege service accounts:

```yaml
apiVersion: v1
automountServiceAccountToken: false  # Prevent auto token mount
kind: ServiceAccount
metadata:
  name: portfolio-api
  namespace: portfolio
```

**Roles Example:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: portfolio-api
  namespace: portfolio
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "watch", "list"]
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["portfolio-api-secrets"]  # Only specific secret
    verbs: ["get"]
```

**Bindings:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: portfolio-api
  namespace: portfolio
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: portfolio-api
subjects:
  - kind: ServiceAccount
    name: portfolio-api
    namespace: portfolio
```

### Conftest Policies (CI/CD Shift-Left)

Located at project root in `conftest-policies/`, these catch issues before deployment.

**Example Policy:**

```rego
package kubernetes

violation[msg] {
  input.kind == "Deployment"
  not input.spec.template.spec.securityContext.runAsNonRoot
  msg = "Deployment must run as non-root"
}
```

**In CI/CD Pipeline:**

```bash
conftest test infrastructure/method1-simple-kubectl/*.yaml
# Blocks merge/deploy if policies violated
```

---

## Infrastructure Patterns & Best Practices

### 1. GitOps Pattern

**Principle:** Git as single source of truth

**Implementation:**
- Infrastructure code in Git
- ArgoCD watches repo
- Changes to repo = changes to cluster
- Easy rollback via Git history

**Workflow:**
```
Code Change → Commit → Push → ArgoCD Detects → Syncs → Deploy
```

### 2. Infrastructure as Code

**Benefits:**
- Reproducible deployments
- Version control
- Code review before deployment
- Disaster recovery (redeploy from code)

**Terraform example:**
```hcl
resource "aws_s3_bucket" "portfolio_raw" {
  bucket = "portfolio-raw"
}
# Change version, run terraform apply → updated in AWS
```

### 3. Separation of Concerns

**Three-layer architecture:**

```
Layer 1: Infrastructure (Method 2/3)
  ├─ AWS Services (Terraform)
  └─ Kubernetes Cluster (EKS)
         ↓
Layer 2: Application Platform (Helm)
  ├─ Deployments
  ├─ Services
  ├─ Ingress
  └─ Storage
         ↓
Layer 3: Application Code
  ├─ API (Python/FastAPI)
  ├─ UI (React/Vite)
  └─ ChromaDB
```

Each layer can be modified independently.

### 4. Resource Management

**Namespace Quotas:**

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: portfolio-quota
  namespace: portfolio
spec:
  hard:
    requests.cpu: "2"        # 2 cores total
    requests.memory: "4Gi"   # 4GB total
    limits.cpu: "4"          # 4 cores limit
    limits.memory: "8Gi"     # 8GB limit
    persistentvolumeclaims: "2"
```

Prevents single workload from starving others.

### 5. Health Management

**Three-probe strategy:**

```
StartupProbe (app initialization)
       ↓
Ready for traffic? (ReadinessProbe)
       ↓
Still healthy? (LivenessProbe - restart if not)
```

### 6. Persistence Strategy

**Three types:**

1. **PersistentVolume** - Long-term storage (ChromaDB embeddings)
2. **emptyDir** - Temporary (logs, temp files)
3. **Secrets** - Sensitive data (API keys)

### 7. Monitoring and Observability

**Integrated in Method 3:**
- Health probes (startup/readiness/liveness)
- Log aggregation (CloudWatch, ELK)
- Metrics (Prometheus)
- Dashboards (Grafana)
- Alerting (PagerDuty, Slack)

### 8. Secret Management

**Best Practices:**

```yaml
# Wrong - secrets in code
env:
  - name: API_KEY
    value: "sk_live_abc123xyz"

# Better - reference from Secret
env:
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: api-secrets
        key: API_KEY

# Best - use external secret manager (AWS Secrets Manager)
```

### 9. Image Management

**Policy:**

```yaml
# Wrong
image: portfolio-api:latest

# Better
image: ghcr.io/jimjrxieb/portfolio-api:main-abc1234

# Best - with digest
image: ghcr.io/jimjrxieb/portfolio-api@sha256:abc123...
```

### 10. Zero-Trust Networking

**Principle:** Deny by default, allow explicitly

```yaml
# Step 1: Deny all
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]

# Step 2: Allow specific traffic
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-to-chroma
spec:
  podSelector:
    matchLabels:
      app: portfolio-api
  policyTypes: [Egress]
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: chroma
      ports:
        - port: 8000
```

---

## Configuration Details

### Environment Variables by Component

#### API Container

```yaml
# LLM Configuration
LLM_PROVIDER: "claude"              # or "openai"
LLM_MODEL: "claude-3-haiku-..."     # Model identifier

# Embedding Configuration
EMBED_MODEL: "nomic-embed-text"     # Ollama model name
OLLAMA_URL: "http://localhost:11434" # Local or remote Ollama

# ChromaDB Configuration
CHROMA_URL: "file:///chroma-data"   # or HTTP endpoint
CHROMA_HOST: "chroma"                # K8s DNS name
CHROMA_PORT: "8000"

# Server Configuration
API_HOST: "0.0.0.0"                 # Listen on all interfaces
API_PORT: "8000"                    # Port number
CORS_ALLOW_ORIGINS: "*"             # Or specific origins

# Application Configuration
RAG_NAMESPACE: "portfolio"           # K8s namespace
DATA_DIR: "/data"                   # Mounted volume path
DEBUG_MODE: "false"                 # Debug logging
LOG_LEVEL: "INFO"                   # Logging level

# Optional Components
TTS_ENGINE: "disabled"              # Text-to-speech
AVATAR_ENGINE: "disabled"           # Avatar generation
```

#### UI Container

```yaml
# API Connection
VITE_API_BASE_URL: "http://portfolio.localtest.me/api"
# or "" for same-origin proxy

# Build Configuration
VITE_ENVIRONMENT: "production"
VITE_LOG_LEVEL: "info"
```

### Resource Allocation

**Development:**
- API: 200m CPU, 512Mi RAM (requests), 1 CPU, 2Gi RAM (limits)
- UI: 50m CPU, 128Mi RAM (requests), 200m CPU, 256Mi RAM (limits)
- ChromaDB: 100m CPU, 256Mi RAM (requests), 500m CPU, 512Mi RAM (limits)

**Production (with HPA):**
- API: Scale 2-10 replicas, same limits
- UI: 1-3 replicas
- ChromaDB: 1 replica (stateful, complex to scale)

### Storage Configuration

**Local Development (Method 1):**
- PV using hostPath: `/home/jimmie/linkops-industries/Portfolio/data/chroma`
- Size: 5Gi
- ReclaimPolicy: Retain

**LocalStack (Method 2):**
- S3 buckets via Terraform
- DynamoDB via Terraform
- Local ephemeral storage

**Production (Method 3):**
- EBS volumes via Kubernetes Storage Classes
- S3 for embeddings
- RDS for metadata (optional)

### Network Configuration

**Local DNS:**
- `.localtest.me` - Magic domain resolving to 127.0.0.1
- `linksmlm.com` - Custom domain via Cloudflare tunnel

**Ingress Class:**
- NGINX Controller
- Handles TLS termination
- Manages external access

### Security Context Summary

**Pod Level:**
- runAsNonRoot: true
- runAsUser: 10001
- runAsGroup: 10001
- fsGroup: 10001
- seccompProfile: RuntimeDefault

**Container Level:**
- readOnlyRootFilesystem: true (except ChromaDB)
- allowPrivilegeEscalation: false
- capabilities.drop: ALL

### Health Check Configuration

**API:**
- Startup: 5s initial delay, 5s period, 6 failures
- Readiness: 10s initial delay, 5s period, 3 failures
- Liveness: 30s initial delay, 10s period, 3 failures

**UI:**
- Readiness: 10s initial delay, 5s period
- Liveness: 15s initial delay, 30s period

**Path:** `/health`, `/health/live`, `/health/ready`

---

## Troubleshooting Guide

### Method 1 Issues

**Pods not starting:**
```bash
kubectl describe pod -n portfolio <pod-name>
kubectl logs -n portfolio <pod-name>
```

**Ollama connection:**
```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# Test from pod
kubectl exec -it -n portfolio $(kubectl get pod -n portfolio -l app=portfolio-api -o jsonpath='{.items[0].metadata.name}') -- \
  curl http://host.docker.internal:11434/api/tags
```

### Method 2 Issues

**LocalStack not responding:**
```bash
docker logs localstack
curl http://localhost:4566/_localstack/health
```

**Terraform errors:**
```bash
TF_LOG=DEBUG terraform apply  # Verbose logging
terraform state list          # See what exists
terraform state show aws_s3_bucket.portfolio_raw  # Inspect resource
```

### Method 3 Issues

**ArgoCD not syncing:**
```bash
kubectl describe app portfolio -n argocd
kubectl logs -n argocd argocd-application-controller
```

**Helm values not applied:**
```bash
helm template portfolio infrastructure/method3-helm-argocd/helm-chart/portfolio \
  -f values.yaml -f values.prod.yaml | head -50
```

---

## Summary

The Portfolio infrastructure provides three deployment options serving different needs:

- **Method 1:** Learn Kubernetes fundamentals locally
- **Method 2:** Test AWS services and Terraform IaC
- **Method 3:** Deploy to production with GitOps automation

Security is implemented at multiple layers:
- Conftest policies in CI/CD (shift-left)
- Gatekeeper admission control (runtime enforcement)
- Network policies (zero-trust)
- RBAC (least privilege)
- Security contexts (container hardening)

Each method shares the same application code and security policies while increasing deployment complexity and production-readiness.

---

**Document Version:** 1.0  
**Last Updated:** November 2025  
**Author:** Jimmie (Infrastructure Team)
