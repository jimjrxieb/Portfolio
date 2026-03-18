# LocalStack Quick Start Guide

**Ready to test your AWS integration locally? Start here!**

---

## Start LocalStack

```bash
cd /home/jimmie/linkops-industries/GP-copilot/GP-PROJECTS/ai-powered-project

# Start LocalStack + PostgreSQL + Redis
docker-compose -f docker-compose.localstack.yml up -d

# Verify all services are healthy (wait ~30 seconds)
docker-compose -f docker-compose.localstack.yml ps

# Check initialization logs
docker logs ai-powered-localstack --tail 50
```

**Expected Output**:
```
==========================================
LocalStack Initialization Complete!
==========================================

Services Ready:
  ✓ S3 Buckets: ai-powered-resumes, ai-powered-static, ai-powered-interviews
  ✓ DynamoDB Tables: FileMetadata, InterviewSessions
  ✓ SQS Queues: resume-processing-queue, interview-analysis-queue, failed-jobs-dlq
  ✓ Secrets Manager: openai-api-key, database-credentials, jwt-secret
```

---

## Quick Tests

```bash
# List S3 buckets
awslocal s3 ls

# List DynamoDB tables
awslocal dynamodb list-tables

# List SQS queues
awslocal sqs list-queues

# List secrets
awslocal secretsmanager list-secrets
```

---

## Add to Your Application

### 1. Install AWS SDK

```bash
npm install @aws-sdk/client-s3 @aws-sdk/client-dynamodb @aws-sdk/client-sqs @aws-sdk/client-secrets-manager
```

### 2. Configure AWS SDK

Create `config/aws.js`:

```javascript
const { S3Client } = require('@aws-sdk/client-s3');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { SQSClient } = require('@aws-sdk/client-sqs');
const { SecretsManagerClient } = require('@aws-sdk/client-secrets-manager');
const { DynamoDBDocumentClient } = require('@aws-sdk/lib-dynamodb');

const isLocal = process.env.NODE_ENV === 'development';

const config = isLocal ? {
  endpoint: 'http://localhost:4566',
  region: 'us-east-1',
  credentials: {
    accessKeyId: 'test',
    secretAccessKey: 'test'
  }
} : {
  region: process.env.AWS_REGION || 'us-east-1'
};

const s3Client = new S3Client(config);
const dynamoDBClient = new DynamoDBClient(config);
const dynamoDBDocClient = DynamoDBDocumentClient.from(dynamoDBClient);
const sqsClient = new SQSClient(config);
const secretsClient = new SecretsManagerClient(config);

module.exports = {
  s3Client,
  dynamoDBClient,
  dynamoDBDocClient,
  sqsClient,
  secretsClient
};
```

### 3. Example: Upload Resume to S3

```javascript
const { s3Client } = require('./config/aws');
const { PutObjectCommand } = require('@aws-sdk/client-s3');
const fs = require('fs');

async function uploadResume(userId, filePath, fileName) {
  const fileContent = fs.readFileSync(filePath);

  const command = new PutObjectCommand({
    Bucket: 'ai-powered-resumes',
    Key: `resumes/${userId}/${fileName}`,
    Body: fileContent,
    ContentType: 'application/pdf',
  });

  const result = await s3Client.send(command);
  console.log('Upload successful:', result);
  return result;
}

// Usage
uploadResume('user-123', '/tmp/resume.pdf', 'resume.pdf');
```

### 4. Example: Save to DynamoDB

```javascript
const { dynamoDBDocClient } = require('./config/aws');
const { PutCommand } = require('@aws-sdk/lib-dynamodb');
const { v4: uuidv4 } = require('uuid');

async function saveFileMetadata(userId, fileName, s3Key, fileSize) {
  const command = new PutCommand({
    TableName: 'FileMetadata',
    Item: {
      fileId: uuidv4(),
      userId,
      uploadedAt: Date.now(),
      fileName,
      s3Key,
      fileSize,
      status: 'uploaded',
    }
  });

  await dynamoDBDocClient.send(command);
  console.log('Metadata saved');
}

// Usage
saveFileMetadata('user-123', 'resume.pdf', 'resumes/user-123/resume.pdf', 52428);
```

### 5. Example: Send to SQS Queue

```javascript
const { sqsClient } = require('./config/aws');
const { SendMessageCommand } = require('@aws-sdk/client-sqs');

const QUEUE_URL = 'http://localhost:4566/000000000000/resume-processing-queue';

async function enqueueResumeProcessing(resumeId, userId) {
  const command = new SendMessageCommand({
    QueueUrl: QUEUE_URL,
    MessageBody: JSON.stringify({
      jobType: 'resume-parsing',
      resumeId,
      userId,
      timestamp: new Date().toISOString(),
    }),
  });

  const result = await sqsClient.send(command);
  console.log('Job enqueued:', result.MessageId);
  return result.MessageId;
}

// Usage
enqueueResumeProcessing('file-001', 'user-123');
```

### 6. Example: Get Secret

```javascript
const { secretsClient } = require('./config/aws');
const { GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');

async function getOpenAIKey() {
  const command = new GetSecretValueCommand({
    SecretId: 'ai-powered/openai-api-key'
  });

  const data = await secretsClient.send(command);
  const secret = JSON.parse(data.SecretString);
  return secret.apiKey;
}

// Usage
const apiKey = await getOpenAIKey();
console.log('API Key:', apiKey);
```

---

## Environment Variables

Add to `.env`:

```env
NODE_ENV=development

# AWS LocalStack
AWS_ENDPOINT=http://localhost:4566
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test

# S3 Buckets
S3_BUCKET_RESUMES=ai-powered-resumes
S3_BUCKET_STATIC=ai-powered-static
S3_BUCKET_INTERVIEWS=ai-powered-interviews

# DynamoDB Tables
DYNAMODB_TABLE_FILE_METADATA=FileMetadata
DYNAMODB_TABLE_INTERVIEW_SESSIONS=InterviewSessions

# SQS Queues
SQS_RESUME_QUEUE=http://localhost:4566/000000000000/resume-processing-queue
SQS_INTERVIEW_QUEUE=http://localhost:4566/000000000000/interview-analysis-queue
```

---

## Test End-to-End Flow

### Complete Resume Upload Flow

```javascript
// services/resumeService.js
const { uploadResume } = require('./s3Service');
const { saveFileMetadata } = require('./dynamoDBService');
const { enqueueResumeProcessing } = require('./sqsService');

async function handleResumeUpload(userId, file) {
  try {
    // 1. Upload to S3
    const s3Key = `resumes/${userId}/${file.name}`;
    await uploadResume(userId, file.path, file.name);
    console.log('✓ Uploaded to S3');

    // 2. Save metadata to DynamoDB
    const fileId = await saveFileMetadata(
      userId,
      file.name,
      s3Key,
      file.size
    );
    console.log('✓ Saved metadata to DynamoDB');

    // 3. Enqueue background job
    await enqueueResumeProcessing(fileId, userId);
    console.log('✓ Enqueued processing job');

    return { fileId, s3Key, status: 'uploaded' };
  } catch (error) {
    console.error('Upload failed:', error);
    throw error;
  }
}

// Usage
await handleResumeUpload('user-123', {
  name: 'resume.pdf',
  path: '/tmp/resume.pdf',
  size: 52428
});
```

---

## Stop LocalStack

```bash
docker-compose -f docker-compose.localstack.yml down

# Stop and remove volumes (clean slate)
docker-compose -f docker-compose.localstack.yml down -v
```

---

## Next Steps

1. **Integrate AWS SDK** - Add the examples above to your application
2. **Test Each Service** - Upload files, query DynamoDB, send messages
3. **Build Background Workers** - Process SQS messages for async jobs
4. **Add Error Handling** - Dead letter queues, retry logic
5. **Monitor Usage** - LocalStack dashboard at http://localhost:4566/_localstack/health

---

## When You're Ready: Phase 4 (Real AWS)

LocalStack code works **identically** on real AWS. Just change:

```javascript
// FROM (development):
const config = {
  endpoint: 'http://localhost:4566',
  region: 'us-east-1',
  credentials: { accessKeyId: 'test', secretAccessKey: 'test' }
};

// TO (production):
const config = {
  region: 'us-east-1'
  // AWS SDK automatically uses IAM credentials
};
```

Your LocalStack experience = Real AWS experience! 🚀

---

**For more details**: See [PHASE-3-COMPLETE.md](./PHASE-3-COMPLETE.md)
