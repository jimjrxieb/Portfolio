# AI/ML Experience

## Current Focus: RAG + LangGraph + Robotic Process Automation
- **RAG Systems**: Production-grade retrieval-augmented generation using HuggingFace embeddings + vector stores
- **LangGraph**: Building multi-agent workflows and complex reasoning chains for enterprise automation
- **RPA Integration**: Combining LLMs with robotic process automation for intelligent document processing and workflow automation
- **MCP (Model Context Protocol)**: Implementing standardized interfaces for tool-calling and context management

## This Portfolio System
- Local **Qwen2.5-1.5B-Instruct** (HuggingFace model) + RAG pipeline for grounded responses
- ChromaDB vector store with sentence-transformers embeddings
- Kubernetes deployment with persistent volumes for model/data storage
- RAG pipeline: curated markdown → embeddings → top-k retrieval → contextualized LLM prompt

## Production AI/ML Work
- **Enterprise RAG**: Multi-tenant knowledge bases with real-time ingestion and query optimization
- **Agent Orchestration**: LangGraph-based systems for complex multi-step reasoning and tool use
- **Document Intelligence**: OCR + NLP pipelines for automated document processing and extraction
- **Model Optimization**: Quantization (QLoRA/LoRA), inference optimization, and deployment at scale

## Technical Approach
- **Small Models First**: Prefer efficient models (1.5B-7B params) that fit on single GPUs for cost-effective deployment
- **HuggingFace Ecosystem**: Leveraging transformers, datasets, and inference endpoints for rapid prototyping
- **Vector Databases**: ChromaDB, Pinecone, and Weaviate for production RAG systems
- **Observability**: Comprehensive logging and metrics for LLM performance monitoring