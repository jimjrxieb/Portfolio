# RAG Pipeline - LangChain Style Setup

## 🚀 **System Overview**

Your RAG pipeline is a complete LangChain-style knowledge processing system that monitors new files, processes them through embedding generation, and makes them immediately available to the Jade AI assistant.

## 📊 **Current Status**

- **Total Documents:** 391 embedded documents in ChromaDB
- **Knowledge Base:** Comprehensive portfolio information + personal profile
- **Processing:** Automatic chunking (1000 chars, 200 overlap)
- **Embedding Model:** sentence-transformers/all-MiniLM-L6-v2

## 🔧 **Port Configuration**

| Service              | Port | Purpose                                 | Status     |
| -------------------- | ---- | --------------------------------------- | ---------- |
| **ChromaDB**         | 8001 | Vector database storage                 | ✅ Running |
| **Jade Brain API**   | 8002 | AI assistant with RAG integration       | ✅ Running |
| **RAG Pipeline API** | 8000 | Knowledge ingestion & Jupyter notebooks | ✅ Running |
| **UI Frontend**      | 5173 | Portfolio website with chat             | ✅ Running |

## 🚀 **Startup Commands**

### Start All Services

```bash
# Terminal 1: ChromaDB
cd /home/jimmie/linkops-industries/Portfolio
docker run -p 8001:8000 chromadb/chroma:latest

# Terminal 2: RAG Pipeline API
cd /home/jimmie/linkops-industries/Portfolio/rag-pipeline
DATA_DIR=../data CHROMA_URL=http://localhost:8001 python3 rag_api.py

# Terminal 3: Jade Brain
cd /home/jimmie/linkops-industries/Portfolio/Jade-Brain
CHROMA_URL=http://localhost:8001 RAG_API_URL=http://localhost:8003 OPENAI_API_KEY=sk-proj-hah-DBF9eRVOBi0ZunyFZwPnd7QqtYEkh6HbCliFj_WNrOdzr44uBHDwf2ZzNE2_BxY1cBfJG5T3BlbkFJgVsMRgJJ_IYfA4iz-ryO9JCeToVAcaVJO5i3ePU8xC_RWl7nQYmcv5qNTdWgGJIc6_RWl7nQYmcv5qNTdWgGJIc6_hwaIVtIA LLM_MODEL=gpt-4o-mini uvicorn api.jade_api:app --host 0.0.0.0 --port 8002 --reload

# Terminal 4: UI Frontend
cd /home/jimmie/linkops-industries/Portfolio/ui
npm run dev
```

## 📁 **Directory Structure**

```
rag-pipeline/
├── new-rag-data/              # Drop new files here (like your knowledge-base/)
├── proceed-rag-data/          # Processed files moved here with timestamps
│   └── 20250925_214118/       # Timestamped processing batches
├── batch_pipeline.py          # LangChain-style batch processor
├── process_new_data.sh        # Convenient processing script
├── ingestion_engine.py        # Core embedding and storage engine
├── rag_api.py                 # API for queries and notebook management
└── run_ingestion.py           # Initial knowledge base setup
```

## 🔄 **Usage - LangChain Style Workflow**

### Single Batch Processing (like running a notebook cell)

```bash
cd /home/jimmie/linkops-industries/Portfolio/rag-pipeline
./process_new_data.sh
```

### Continuous Monitoring (like Gradio.launch())

```bash
cd /home/jimmie/linkops-industries/Portfolio/rag-pipeline
./process_new_data.sh watch 30  # Check every 30 seconds
```

### Direct Python Usage

```bash
cd /home/jimmie/linkops-industries/Portfolio/rag-pipeline
DATA_DIR=../data CHROMA_URL=http://localhost:8001 python3 batch_pipeline.py
```

## 📊 **Processing Results Example**

```
Results: {
  'status': 'completed',
  'processed': 1,
  'errors': 0,
  'total_files': 1,
  'processing_time': '0.77s',
  'total_vectorstore_docs': 391,
  'results': [
    {
      'file': 'jimmie-profile.md',
      'status': 'success',
      'decision': 'embed',
      'reason': 'Embedded: Content contains queryable information',
      'chunks': 6
    }
  ]
}
```

## 🌐 **Access Points**

- **Portfolio Website:** http://localhost:5173
- **Chat with Jade:** Use UI or `curl -X POST http://localhost:8002/chat`
- **RAG API Health:** http://localhost:8000/health
- **Jade Health:** http://localhost:8002/health
- **Available Notebooks:** http://localhost:8000/notebooks

## ⚡ **Quick Testing**

Test new knowledge integration:

```bash
# Add a test file
echo "# Test Knowledge\nThis is test content for the RAG pipeline." > new-rag-data/test.md

# Process it
./process_new_data.sh

# Test with Jade
curl -X POST http://localhost:8002/chat -H "Content-Type: application/json" -d '{"message": "Tell me about the test content."}'
```

## 🎯 **Features Working**

✅ **LangChain-style batch processing** - Drop files and run
✅ **Automatic chunking and embedding** - sentence-transformers
✅ **ChromaDB vector storage** - 391 documents and growing
✅ **Immediate knowledge availability** - Jade accesses new info instantly
✅ **File archival system** - Timestamped organization
✅ **Self-referential AI responses** - Jade mentions being powered by your RAG system
✅ **Honest, grounded responses** - No fake expertise claims
✅ **Context-aware retrieval** - RAG results integrated with responses

## 🔧 **Environment Variables**

```bash
export DATA_DIR=../data
export CHROMA_URL=http://localhost:8001
export RAG_API_URL=http://localhost:8003
export OPENAI_API_KEY="your-openai-api-key-here"
export LLM_MODEL=gpt-4o-mini
```

---

**🎉 Your RAG pipeline works exactly like your familiar LangChain/Gradio workflow - just drop files in `new-rag-data/` and run the processor!**

Last Updated: 2025-09-25 21:43:00
