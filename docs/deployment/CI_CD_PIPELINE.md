# CI/CD Pipeline Documentation

## Overview

The Portfolio platform uses GitHub Actions for continuous integration and deployment, implementing enterprise-grade security scanning, automated testing, and container image building.

## Pipeline Architecture

### **Workflow Trigger Events**

```yaml
on:
  push:
    branches: [main, develop]
    paths:
      - 'api/**'
      - 'ui/**'
      - 'Jade-Brain/**'
      - 'rag-pipeline/**'
      - 'charts/**'
      - 'k8s/**'
      - '.github/workflows/**'
      - 'Dockerfile*'
      - 'docker-compose.yml'
      - 'package*.json'
      - '**/requirements.txt'
  pull_request:
    branches: [main]
```

## Pipeline Stages

### **1. Quality Checks Stage**

#### **Environment Setup**
- **Node.js 20**: Frontend tooling and dependency management
- **Python 3.11**: Backend development and security tools
- **Dependency Caching**: npm and pip cache optimization

#### **Linting & Code Quality**
```yaml
steps:
  - UI Linting (ESLint)
  - Python Linting (Flake8) - API
  - Python Linting (Flake8) - RAG Pipeline
  - Code Formatting Check (Prettier)
  - TypeScript Type Checking
```

#### **Security Scanning**
```yaml
security-tools:
  - npm Security Audit (Node.js dependencies)
  - Bandit (Python static analysis)
  - Safety (Python dependency vulnerabilities)
  - GitLeaks (Secrets detection)
  - Semgrep (SAST - Snyk alternative)
```

### **2. Image Build Stage**

#### **Build Matrix Strategy**
```yaml
strategy:
  matrix:
    component:
      - { name: 'api', path: './api/Dockerfile', context: '.' }
      - { name: 'ui', path: './ui/Dockerfile', context: '.' }
```

#### **Container Registry**
- **Primary**: GitHub Container Registry (GHCR)
- **Authentication**: GitHub token
- **Image Tags**:
  - `main-{SHORT_SHA}` (commit-specific)
  - `latest` (latest main branch)

#### **Build Optimization**
```yaml
features:
  - Docker Buildx for multi-platform builds
  - GitHub Actions cache for layers
  - Registry cache for faster rebuilds
  - Parallel matrix builds
```

### **3. Security Scanning Stage**

#### **Container Vulnerability Scanning**
```yaml
trivy-configuration:
  severity: 'CRITICAL,HIGH,MEDIUM'
  vuln-type: 'os,library'
  scanners: 'vuln,secret,config'
  timeout: '15m0s'
  format: 'sarif'
```

#### **SARIF Reporting**
All security findings uploaded to GitHub Security tab:
- **Semgrep SAST**: Category `semgrep-sast`
- **Trivy API**: Category `trivy-api`
- **Trivy UI**: Category `trivy-ui`

### **4. Kubernetes Validation Stage**

#### **Conditional Execution**
Runs when commit messages contain:
- `k8s`, `kubernetes`, or `helm`

#### **Validation Steps**
```yaml
validation:
  - Helm chart linting
  - Helm template rendering
  - Kubernetes manifest YAML validation
  - Conftest policy enforcement
```

#### **Policy as Code (OPA/Conftest)**
```yaml
policies:
  - container-security.rego: Security contexts, resource limits
  - image-security.rego: Image tags, trusted registries
  - test-policy.rego: Basic deployment policies
```

### **5. Deployment Stage**

#### **Deployment Conditions**
```yaml
conditions:
  - github.ref == 'refs/heads/main'
  - github.event_name == 'push'
  - needs.build-images.result == 'success'
environment: production
```

#### **Deployment Summary**
Creates deployment instructions with:
- Container image locations (GHCR)
- Deployment commands
- Health check endpoints
- ArgoCD integration status

### **6. Notification Stage**

#### **Pipeline Summary**
Comprehensive reporting including:
- All stage results
- Security scanner status
- Platform architecture summary
- Next steps for deployment

## Security Integration

### **Secrets Management**
```yaml
secrets:
  GITHUB_TOKEN: GitHub Actions token
  OPENAI_API_KEY: OpenAI API access (optional)
```

### **Security Scanner Details**

#### **GitLeaks**
```yaml
purpose: Detect hardcoded secrets in code and git history
coverage:
  - API keys and tokens
  - Database credentials
  - Private keys
  - Cloud provider credentials
integration: GitHub Actions with automatic SARIF upload
```

#### **Semgrep (SAST)**
```yaml
purpose: Static Application Security Testing
rulesets:
  - p/security-audit: General vulnerabilities
  - p/secrets: Secret detection
  - p/python: Python-specific issues
  - p/javascript: JS/TS vulnerabilities
output: SARIF format to GitHub Security tab
```

#### **Trivy**
```yaml
purpose: Container image vulnerability scanning
scan-types:
  - vuln: OS and library vulnerabilities
  - secret: Embedded secrets
  - config: Container misconfigurations
reporting: SARIF to GitHub Security tab
```

#### **Bandit**
```yaml
purpose: Python security issue detection
detects:
  - SQL injection vulnerabilities
  - Hardcoded passwords
  - Unsafe function usage
  - Shell injection risks
output: JSON reports for analysis
```

#### **Safety**
```yaml
purpose: Python dependency vulnerability scanning
database: PyUp.io vulnerability database
scope: All requirements.txt files
output: JSON vulnerability reports
```

### **Policy Enforcement**

#### **Container Security Policies**
```rego
# Enforced via OPA/Conftest
rules:
  - No root containers (UID 0)
  - Security contexts required
  - No privileged containers
  - Resource limits mandatory
  - No privilege escalation
```

#### **Image Security Policies**
```rego
# Image governance
rules:
  - No 'latest' tags in production
  - Trusted registries only
  - Image pull policies required
  - Specific image tags mandatory
```

## Performance Optimization

### **Caching Strategy**
```yaml
caching:
  npm-dependencies: package-lock.json hash
  pip-dependencies: requirements.txt hash
  docker-layers: GitHub Actions cache
  registry-cache: Multi-stage builds
```

### **Parallel Execution**
```yaml
parallelization:
  - Security scanners run concurrently
  - Image builds use matrix strategy
  - Independent stage execution
```

### **Build Optimization**
```yaml
optimization:
  - Multi-stage Dockerfiles
  - Layer caching
  - Dependency pre-installation
  - Alpine Linux base images
```

## Error Handling & Resilience

### **Failure Handling**
```yaml
error-strategies:
  continue-on-error: true  # For security scanners
  retry-logic: 5 attempts with exponential backoff
  timeout-protection: 15-minute maximum per scanner
```

### **Debugging Features**
```yaml
debugging:
  - Docker context inspection
  - File existence verification
  - Detailed error logging
  - Build artifact preservation
```

## Monitoring & Observability

### **Pipeline Metrics**
- Build duration tracking
- Success/failure rates
- Security scanner performance
- Image size optimization

### **GitHub Integration**
```yaml
github-features:
  - Security tab integration (SARIF)
  - Pull request status checks
  - Deployment environment tracking
  - Artifact management
```

### **Notification System**
```yaml
notifications:
  - Pipeline completion status
  - Security finding summaries
  - Deployment readiness alerts
  - Performance metrics
```

## Configuration Management

### **Environment Variables**
```yaml
global:
  REGISTRY: ghcr.io
  IMAGE_NAME: jimjrxieb/portfolio

build-args:
  BUILD_DATE: GitHub run ID
  BUILD_SHA: Short commit SHA
```

### **Matrix Configuration**
```yaml
components:
  api:
    dockerfile: ./api/Dockerfile
    context: .
    security-scan: enabled
  ui:
    dockerfile: ./ui/Dockerfile
    context: .
    security-scan: enabled
```

## Maintenance & Updates

### **Regular Maintenance**
```yaml
schedule:
  - Weekly: Security scanner updates
  - Monthly: Base image updates
  - Quarterly: Action version updates
  - As-needed: Policy rule updates
```

### **Version Management**
```yaml
versioning:
  actions: Pinned to major versions (@v4, @v3)
  base-images: Specific tags (not latest)
  dependencies: Lock files committed
```

## Best Practices

### **Security**
- All scanners use continue-on-error for non-blocking
- SARIF upload for centralized vulnerability management
- Secrets scanning prevents credential leaks
- Policy as Code ensures compliance

### **Performance**
- Matrix builds for parallel execution
- Comprehensive caching strategy
- Optimized container images
- Efficient dependency management

### **Reliability**
- Retry mechanisms for transient failures
- Timeout protection against hanging builds
- Health checks for service validation
- Rollback capabilities via GitOps

---

**Last Updated**: September 26, 2025
**Pipeline Version**: 2.0 (Enhanced Security)
**GitHub Actions**: .github/workflows/main.yml