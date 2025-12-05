# RAG Grounding Fix - TLDR Summary

**Date:** 2025-12-04
**Category:** Portfolio Platform - Chat API Fix

---

## The Problem

Claude was hallucinating instead of using RAG context. Users would ask questions and get made-up answers not grounded in the knowledge base.

## Root Causes

1. **Empty ChromaDB** - K8s ChromaDB had 0 documents (deployment used emptyDir, lost data on restart)
2. **Weak Prompt Structure** - RAG context was loosely appended to user message
3. **No Grounding Instructions** - LLM wasn't told to ONLY use provided context
4. **High Temperature (0.7)** - Encouraged creative/hallucinated responses

## The Fix

### 1. Structured RAG Prompt Format
```
[KNOWLEDGE BASE CONTEXT]
{retrieved documents}
[END KNOWLEDGE BASE CONTEXT]

[USER QUESTION]
{user's question}
```

### 2. Explicit Grounding Instructions
- "ONLY use information from the KNOWLEDGE BASE CONTEXT"
- "DO NOT make up facts, projects, dates, or details"
- "If context doesn't have the answer, say so honestly"

### 3. Lower Temperature
- Changed from 0.7 to 0.4
- Lower = more deterministic, factual responses

## Files Changed

| File | What Changed |
|------|-------------|
| `api/routes/chat.py` | Added grounding instructions, structured context |
| `backend/engines/llm_interface.py` | Configurable temperature (default 0.4) |

## Current State

- API deployed with fixes
- ChromaDB empty (needs data ingestion when GPU available)
- Will respond: "I don't have specific information about that in my knowledge base"

## To Complete RAG Setup

When GPU is free:
```bash
cd Portfolio/rag-pipeline/03-ingest-rag-data
python3 ingest_clean.py
```

This ingests the 35 documents from `04-processed-rag-data/` into ChromaDB.

---

## Key Lesson

**Hallucination = Missing data + Weak prompts + High temperature**

Always verify:
1. Is data in the vector DB?
2. Is context being retrieved?
3. Is LLM instructed to use it?
4. Is temperature appropriate?
