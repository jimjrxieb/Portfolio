# Scripts Organization

This folder contains all utility scripts organized by language and purpose.

## Structure

```
scripts/
├── bash/
│   ├── ci/          # Continuous Integration
│   ├── cd/          # Continuous Deployment
│   └── tmp-test/    # Temporary testing scripts
└── python3/
    ├── ci/          # Python CI utilities
    ├── cd/          # Python CD utilities
    └── tmp-test/    # Python test utilities
```

## CI Scripts (Continuous Integration)
**Purpose:** Pre-push linting, secrets scanning, formatting, fix scripts

### bash/ci/
- `create-dev-secrets.sh` - Development environment secrets setup
- `husky.sh` - Git hooks for pre-commit/pre-push validation
- `setup-dev.sh` - Development environment setup and formatting

### python3/ci/
- *Future Python linting and security scanning scripts*

## CD Scripts (Continuous Deployment)
**Purpose:** Deployment health checks, workflow tests, docker startup, individual servers

### bash/cd/
- `build-and-push.sh` - Docker build and registry push
- `deploy-clean-api.sh` - Clean API deployment
- `deploy-from-registry.sh` - Registry-based deployment
- `generate-security-report.sh` - Security compliance reporting
- `github-webhook-listener.sh` - GitHub webhook handling
- `kubelet-hardening.sh` - Kubernetes node security hardening
- `local-platform-info.sh` - Platform information gathering
- `release.sh` - Release automation
- `setup-local-platform.sh` - Local platform setup
- `start-services.sh` - RAG pipeline service startup
- `verify-clean-api.sh` - API deployment verification
- `verify.sh` - General verification utilities

### python3/cd/
- `health-check.py` - ChromaDB health checking
- `validate-api.py` - API endpoint validation

## TMP-TEST Scripts
**Purpose:** Quick tests and temporary utilities

### bash/tmp-test/
- `deploy-local-k8s.sh` - Local Kubernetes testing
- `rag_smoketest.sh` - RAG pipeline smoke testing
- `test-gpt4o-mini-direct.sh` - Direct GPT-4o mini testing
- `test-local-deploy.sh` - Local deployment testing
- `test-openai-fallback.sh` - OpenAI fallback testing
- `test-setup.sh` - General test setup

### python3/tmp-test/
- `ingest_comprehensive_docs.py` - Document ingestion testing
- `quick_api.py` - Quick API testing
- `rag_api.py` - RAG API testing
- `rag_lab.py` - RAG experimentation
- `test_golden_answers.py` - Golden answer validation
- `test_security_hardening.py` - Security hardening tests
- `test_ui_grounding.py` - UI grounding tests

## Usage Examples

```bash
# CI - Run pre-push validation
./scripts/bash/ci/husky.sh

# CD - Deploy and verify API
./scripts/bash/cd/deploy-clean-api.sh
./scripts/bash/cd/verify-clean-api.sh

# TMP-TEST - Quick RAG testing
./scripts/bash/tmp-test/rag_smoketest.sh
```

## Future Additions

Scripts should be added to appropriate ci/cd/tmp-test folders based on their purpose:
- **CI:** Linting, formatting, security scanning, pre-commit validation
- **CD:** Deployment, health checks, service startup, infrastructure validation
- **TMP-TEST:** Quick tests, experiments, temporary utilities
