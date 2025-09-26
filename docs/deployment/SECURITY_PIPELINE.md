# Portfolio Security Pipeline Documentation

## Overview

The Portfolio platform implements enterprise-grade security scanning throughout the CI/CD pipeline, providing comprehensive vulnerability detection, secrets scanning, and policy enforcement.

## Security Architecture

### 🔍 Multi-Layer Security Approach

```
┌─────────────────────────────────────────────────────────────┐
│                    Security Pipeline                        │
├─────────────────────────────────────────────────────────────┤
│  Code Analysis    │  Dependency Scan  │  Container Security │
│  • Semgrep SAST   │  • Safety (Python)│  • Trivy Scanner   │
│  • Bandit (Py)    │  • npm audit (JS) │  • Policy as Code  │
│  • ESLint (TS/JS) │  • Trivy (deps)   │  • Conftest/OPA    │
│  • GitLeaks       │                   │                    │
└─────────────────────────────────────────────────────────────┘
```

## Security Scanners

### 1. Static Application Security Testing (SAST)

#### **Semgrep** (Snyk Alternative)
- **Purpose**: Multi-language static analysis
- **Coverage**: Python, JavaScript, TypeScript, YAML, Docker
- **Rulesets**:
  - `p/security-audit`: General security vulnerabilities
  - `p/secrets`: Hardcoded secrets detection
  - `p/python`: Python-specific vulnerabilities
  - `p/javascript`: JavaScript/TypeScript vulnerabilities
- **Output**: SARIF format → GitHub Security tab
- **Categories**: `semgrep-sast`

#### **Bandit** (Python Security)
- **Purpose**: Python-specific security vulnerability detection
- **Detects**:
  - SQL injection vulnerabilities
  - Hardcoded passwords/secrets
  - Unsafe function usage
  - Shell injection risks
- **Output**: JSON reports (`bandit-report.json`)
- **Scope**: `api/` and `rag-pipeline/` directories

### 2. Dependency Vulnerability Scanning

#### **Safety** (Python Dependencies)
- **Purpose**: Python package vulnerability detection
- **Database**: PyUp.io vulnerability database
- **Scope**: All `requirements.txt` files
- **Output**: JSON reports (`safety-api-report.json`, `safety-rag-report.json`)

#### **npm audit** (Node.js Dependencies)
- **Purpose**: JavaScript/TypeScript package vulnerability detection
- **Severity**: Moderate and above
- **Scope**: `ui/package.json` and dependencies
- **Integration**: Part of build process

#### **Trivy Dependencies**
- **Purpose**: Container dependency scanning
- **Coverage**: OS packages and application dependencies
- **Integration**: Part of container image scanning

### 3. Secrets Detection

#### **GitLeaks**
- **Purpose**: Detect hardcoded secrets in code and git history
- **Coverage**:
  - API keys, tokens, passwords
  - Database connection strings
  - Private keys and certificates
  - Cloud credentials (AWS, GCP, Azure)
- **Scope**: Entire repository history
- **Integration**: GitHub Actions with GITHUB_TOKEN

#### **Semgrep Secrets Rules**
- **Purpose**: Additional secret pattern detection
- **Integration**: Part of Semgrep SAST scanning
- **Patterns**: 400+ secret detection rules

### 4. Container Security

#### **Trivy Container Scanner**
- **Purpose**: Comprehensive container image analysis
- **Scanning Types**:
  - `vuln`: OS and library vulnerabilities
  - `secret`: Secrets embedded in images
  - `config`: Container configuration issues
- **Severity Levels**: `CRITICAL,HIGH,MEDIUM`
- **Timeout**: 15 minutes per image
- **Output**: SARIF format → GitHub Security tab
- **Coverage**: Both API and UI container images

### 5. Policy as Code (OPA/Conftest)

#### **Conftest Integration**
- **Purpose**: Infrastructure security policy enforcement
- **Policy Language**: Open Policy Agent (OPA) Rego
- **Scope**:
  - Kubernetes manifests
  - Helm chart outputs
  - Docker configurations

#### **Security Policies**

##### `container-security.rego`
```rego
# Security requirements enforced:
- No root user containers (UID 0)
- Security contexts mandatory
- No privileged containers
- No privilege escalation
- Resource limits required (CPU/Memory)
```

##### `image-security.rego`
```rego
# Image security requirements:
- No 'latest' tags in production
- Image tags must be specified
- Trusted registries only (ghcr.io, chromadb, registry.k8s.io)
- Image pull policies required
- 'Always' pull policy for latest tags
```

##### `test-policy.rego`
```rego
# Basic deployment policies:
- Latest tag restrictions
- Root user restrictions
```

## CI/CD Integration

### Pipeline Phases

#### **1. Quality Checks Phase**
```yaml
security-steps:
  - npm-security-audit
  - bandit-python-analysis
  - safety-dependency-check
  - gitleaks-secrets-scan
  - semgrep-sast-analysis
```

#### **2. Container Security Phase**
```yaml
security-steps:
  - trivy-api-scan
  - trivy-ui-scan
  - sarif-upload
```

#### **3. Policy Validation Phase**
```yaml
security-steps:
  - helm-chart-validation
  - kubernetes-manifest-validation
  - conftest-policy-enforcement
```

### Reporting

#### **GitHub Security Tab**
All security findings are centralized in the GitHub Security tab through SARIF uploads:

- **Semgrep findings**: Category `semgrep-sast`
- **Trivy API findings**: Category `trivy-api`
- **Trivy UI findings**: Category `trivy-ui`

#### **Artifact Reports**
Local JSON reports generated for detailed analysis:
- `bandit-report.json` - Python security issues
- `safety-api-report.json` - API dependency vulnerabilities
- `safety-rag-report.json` - RAG pipeline dependency vulnerabilities

## Security Standards Compliance

### **Container Security Standards**
- ✅ Non-root containers enforced
- ✅ Security contexts mandatory
- ✅ Resource limits required
- ✅ Privilege escalation blocked
- ✅ Trusted registries only

### **Image Security Standards**
- ✅ No latest tags in production
- ✅ Image vulnerability scanning
- ✅ Secrets detection in images
- ✅ Configuration security checks

### **Code Security Standards**
- ✅ Static analysis for all languages
- ✅ Dependency vulnerability scanning
- ✅ Secrets detection and prevention
- ✅ Policy as Code enforcement

## Configuration

### **Environment Variables**
```yaml
GITHUB_TOKEN: Required for GitLeaks integration
```

### **Policy Directories**
```
scripts/python3/ci/security-policies/
├── container-security.rego    # Container security policies
├── image-security.rego        # Image security policies
└── test-policy.rego          # Basic deployment policies
```

### **Scanner Configuration**

#### Semgrep
```yaml
config: >-
  p/security-audit
  p/secrets
  p/python
  p/javascript
generateSarif: "1"
```

#### Trivy
```yaml
severity: 'CRITICAL,HIGH,MEDIUM'
vuln-type: 'os,library'
scanners: 'vuln,secret,config'
timeout: '15m0s'
```

## Troubleshooting

### **Common Issues**

#### False Positives
- **Semgrep**: Configure `.semgrepignore` for legitimate patterns
- **Bandit**: Use `# nosec` comments for verified safe code
- **Trivy**: Update base images to resolve OS vulnerabilities

#### Policy Violations
- **Container Security**: Ensure non-root users and resource limits
- **Image Security**: Use specific tags and trusted registries
- **Configuration**: Validate Kubernetes manifest security settings

### **Performance Optimization**
- **Parallel Scanning**: Security scanners run in parallel matrix
- **Caching**: Docker layer caching reduces scan times
- **Timeouts**: 15-minute timeout prevents hanging builds

## Maintenance

### **Regular Updates**
- **Scanner Versions**: Update action versions quarterly
- **Policy Rules**: Review and update OPA policies
- **Vulnerability Databases**: Scanners auto-update their databases

### **Monitoring**
- **GitHub Security Tab**: Monitor for new vulnerabilities
- **Pipeline Metrics**: Track scan duration and success rates
- **Policy Compliance**: Regular compliance reporting

## Benefits

### **Enterprise-Grade Security**
- **Comprehensive Coverage**: Multi-layer security scanning
- **Industry Standards**: Follows DevSecOps best practices
- **Automated Enforcement**: Policy as Code prevents misconfigurations

### **Developer Experience**
- **Shift-Left Security**: Early vulnerability detection
- **Centralized Reporting**: GitHub Security tab integration
- **Continuous Feedback**: Real-time security insights

### **Compliance Ready**
- **Audit Trail**: Complete security scanning history
- **Policy Documentation**: Codified security requirements
- **Vulnerability Tracking**: SARIF-based vulnerability management

---

**Last Updated**: September 26, 2025
**Version**: 1.0
**Status**: Production Ready