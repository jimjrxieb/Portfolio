# AI/ML experience
- **Companion LLM**: small model (Phi‑3 Mini or Qwen 1.5B) for warmth + speed
- **RAG**: Persona + talktracks + project docs ingested to Chroma; cite sources [1][2]
- **Fine-tuning**: Built JamesLLM on Colab via JSONL (Jade Box pipeline)
- **Pipelines**: Jade Box: sanitize → segment → embed → train; LangGraph wrapper for RPA/MCP tool calls

# Why small models?
They're inexpensive, private, and good enough with RAG. If I need higher quality,
I can flip to a provider temporarily.