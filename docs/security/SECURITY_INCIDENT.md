# Security Incident Report

## Incident Summary

**Date**: 2025-09-26
**Type**: Credentials Exposure
**Severity**: HIGH

## What Happened

GitLeaks security scanner detected exposed credentials in documentation files:

1. **ArgoCD admin password** in `docs/development/LOCAL-PLATFORM-SUMMARY.md`
2. **OpenAI API key** in `rag-pipeline/PIPELINE_INFO.md`

## Immediate Actions Taken

### ✅ Credential Removal

- Removed hardcoded ArgoCD password from documentation
- Removed OpenAI API key from pipeline documentation
- Updated files with placeholder values

### ⚠️ Required Actions

- [ ] **Regenerate OpenAI API key** (exposed key: `sk-proj-hah-DBF9...`)
- [ ] **Rotate ArgoCD admin password** if used in production
- [ ] **Review git history** for any other credential exposure

### 🔧 Additional Security Fixes Applied

#### **Path Traversal Vulnerabilities (HIGH)**

- **Fixed**: `api/routes/actions.py` - Added comprehensive path validation with `resolve()` and `is_relative_to()`
- **Fixed**: `api/routes/rag.py` - Added directory traversal protection for source path validation
- **Impact**: Prevented arbitrary file read attacks

#### **Insecure MD5 Hashing (LOW)**

- **Fixed**: `rag-pipeline/ingestion_engine.py` - Replaced MD5 with SHA-256
- **Fixed**: `rag-pipeline/legacy/ingest_knowledge.py` - Replaced MD5 with SHA-256
- **Fixed**: `rag-pipeline/legacy/setup_rag.py` - Replaced MD5 with SHA-256
- **Impact**: Improved cryptographic security for chunk IDs

#### **Pending: SSRF Vulnerabilities (LOW)**

- **Location**: `scripts/python3/tmp-test/test_golden_answers.py`
- **Issue**: Command line argument flows into requests.post URL
- **Status**: Low priority (test script only, not production code)

## Prevention Measures

- ✅ GitLeaks secrets scanner already active in CI/CD
- ✅ Pre-commit hooks scanning for secrets
- ✅ `.env` files in `.gitignore`

## Lessons Learned

1. **Documentation should never contain real credentials**
2. **Use placeholders or environment variable references**
3. **Security scanners work** - GitLeaks caught this immediately

## Next Steps

1. Regenerate the exposed OpenAI API key immediately
2. Store credentials in `.env` files (already gitignored)
3. Use environment variable placeholders in documentation

---

**This incident demonstrates the effectiveness of our automated security scanning pipeline.**
