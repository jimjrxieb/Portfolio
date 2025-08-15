# Current Project Context - LinkOps AIBOX Development

**Date:** 2025-08-15
**Status:** Active Development

## Current Project Overview

**Platform:** LinkOps AIBOX running **Jade AI Assistant** - An offline AI solution for clients, starting with ZRS Management in Orlando, FL.

### Core Technology Stack

- **LLM:** Phi-3 (fine-tuned via Google Colab with ZRS policies, housing laws, workflows)
- **RAG:** ChromaDB storing tenants/vendors/workflow documentation
- **RPA:** Automated onboarding and work order completion
- **MCP Tools:** Email and report automation capabilities
- **Voice:** Giancarlo Esposito style voice synthesis via ElevenLabs
- **Avatar:** Multi-photo + voice snippet + personality description → D-ID video generation

### Secondary Product

**LinkOps Afterlife** - Open-source avatar creation platform for preserving memories of loved ones who have passed away.

## Current Technical Issues

### 1. Chat API Problems
- UI displays "chat failed" error messages
- API loading **Qwen2.5-1.5B** by default instead of configured **Phi-3** model
- Suspect old API image running in Kubernetes pod
- Missing new health endpoints, RAG ingestion, and MCP integration features

### 2. Avatar Upload and Talk Feature
- Fixed locally in development environment
- Live deployment not using updated codebase

### 3. Incorrect Project Descriptions
- ZRS incorrectly shown as "Zero Risk Solutions" instead of "ZRS Management"
- Should display Jade AIBOX description for ZRS project
- LinkOps Afterlife copy also incorrect on live site

### 4. RAG Data Issues
- Likely no ingested documents in deployed ChromaDB instance
- Missing documentation for DevOps/AI/ML experience, ZRS, and Afterlife projects

## Recent Code Improvements (Not Yet Deployed)

### New Health Endpoints
- `/api/health/llm` - LLM model status checking
- `/api/health/rag` - RAG database connectivity verification

### RAG Ingestion System
- New ingestion script at `api/scripts/ingest.py`
- Automated document processing and ChromaDB population

### Enhanced Chat Route
- Improved context validation
- Better error handling and reporting
- More robust conversation flow

### MCP Integration Options
- **Option A:** FastAPI MCP adapter with `/api/actions/*` routes
- **Option B:** Standalone MCP server implementation

### Avatar Processing Pipeline
- Complete UI → API → D-ID → ElevenLabs integration
- Streamlined avatar creation and voice synthesis workflow

### Updated Project Information
- Corrected descriptions in `ModernHome.tsx` and `Projects.tsx`
- Accurate ZRS Management and LinkOps Afterlife details

## Immediate Action Plan

### Priority 1: Core Infrastructure
1. Switch LLM configuration to Ollama (Phi-3) in portfolio-api Deployment
2. Deploy new API image with latest fixes (dev-phi3 tag)
3. Execute RAG ingestion with prepared documentation

### Priority 2: Validation and Testing
4. Test health endpoints for LLM and RAG functionality
5. Run Playwright E2E tests for chat and avatar features
6. Verify ElevenLabs Giancarlo voice configuration in secrets/environment

### Priority 3: Development Experience
7. Add UI debug tags (`data-dev="..."`) for easier testing and debugging

## Success Criteria

The live portfolio should achieve:
- **Chat Functionality:** Respond using Phi-3 + RAG with ZRS/DevOps/AI knowledge
- **Voice Introduction:** Play Giancarlo voice introduction via ElevenLabs
- **Accurate Content:** Display correct project descriptions for all initiatives
- **Avatar Features:** Allow avatar creation and conversation without errors
- **MCP Demonstrations:** Ready for Model Context Protocol tool showcases

## Technical Context for Avatar Responses

This context enables the Jade AI assistant to provide accurate, current information about:
- LinkOps AIBOX development status and technical architecture
- ZRS Management client implementation details
- LinkOps Afterlife open-source project goals
- Current debugging and deployment challenges
- Immediate development priorities and success metrics

The assistant should reference this information when discussing current projects, technical capabilities, or development status with users through the chat interface.