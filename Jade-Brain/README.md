# Jade-Brain 🧠

**Central Intelligence System for Jimmie Coleman's Portfolio**

Jade-Brain is the unified AI assistant that powers all conversations about Jimmie's work, projects, and expertise.

## Flow Architecture

```
Interviewer → Chatbox → Jade-Brain → RAG → LLM → Jade-Brain → Response
```

1. **User** asks question in chatbox on website
2. **Jade-Brain** receives query via API
3. **RAG Interface** searches knowledge base (208 chunks)
4. **LLM** (GPT-4o mini) generates response with context
5. **Response Generator** formats with Jade personality
6. **Final response** delivered to interviewer

## System Components

### 📁 **Structure**
```
/Jade-Brain/
├── config/                 # Central configuration
│   ├── llm_config.py      # GPT-4o mini settings
│   ├── rag_config.py      # Knowledge base config
│   └── personality_config.py # Jade's personality
├── personality/            # Jade's identity & responses
│   ├── jade_core.md       # Core personality
│   └── interview_responses.md # Q&A database
├── engines/               # Core intelligence
│   ├── jade_engine.py     # Main conversation engine
│   ├── rag_interface.py   # Knowledge base access
│   ├── llm_interface.py   # GPT-4o mini connection
│   └── response_generator.py # Response creation
├── knowledge/             # Jimmie's info
│   ├── jimmie_profile.md  # Core profile
│   └── projects/          # Project details
└── api/                   # Chatbox integration
    └── jade_api.py        # Main API endpoint
```

### 🔧 **Core Systems**

#### **LLM Configuration** (`config/llm_config.py`)
- **Model**: GPT-4o mini (from `.env`)
- **Provider**: OpenAI API
- **Settings**: 512 tokens, temp 0.7, streaming
- **Fallback**: Local Qwen model support

#### **RAG System** (`engines/rag_interface.py`)
- **Database**: ChromaDB persistent storage
- **Collection**: 208 knowledge chunks
- **Embedding**: sentence-transformers/all-MiniLM-L6-v2
- **Search**: Semantic similarity search

#### **Personality** (`config/personality_config.py`)
- **Name**: Jade
- **Role**: Portfolio AI Assistant
- **Traits**: Professional, warm, technical, business-focused
- **Style**: Adaptive technical depth, practical focus

## API Endpoints

### **Main Chat Endpoint**
```bash
POST /chat
{
  "message": "What is Jimmie's experience with AI/ML?",
  "context_type": "general"
}
```

**Response**:
```json
{
  "response": "Jimmie specializes in practical AI applications...",
  "context_used": true,
  "rag_results": 5,
  "model_used": "gpt-4o-mini",
  "response_time_ms": 1200,
  "status": "success"
}
```

### **System Status**
```bash
GET /status
```

**Response**:
```json
{
  "jade_brain_status": "active",
  "llm_available": true,
  "rag_available": true,
  "document_count": 208,
  "model": "gpt-4o-mini"
}
```

## Quick Start

### 1. **Test RAG System**
```bash
# Verify knowledge base is accessible
cd /home/jimmie/linkops-industries/Portfolio
python3 setup_rag.py
```

### 2. **Start Jade-Brain API**
```bash
cd Jade-Brain/api
python3 jade_api.py
```

### 3. **Test Chat**
```bash
curl -X POST http://localhost:8001/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Tell me about Jimmie"}'
```

## Configuration

### **Environment Variables** (`.env`)
```bash
# LLM Configuration
LLM_PROVIDER=openai
LLM_MODEL=gpt-4o-mini
OPENAI_API_KEY=your-key-here

# RAG Configuration
CHROMA_DIR=/path/to/chroma/data
```

### **Knowledge Base**
- **Source**: 25 markdown files
- **Chunks**: 208 semantic chunks
- **Topics**: DevOps, AI/ML, Projects, Business
- **Update**: Re-run `setup_rag.py` to refresh

## Integration

### **With Existing Systems**
- **Uses**: Existing RAG system from `setup_rag.py`
- **Config**: Same `.env` file as main Portfolio
- **Database**: Same ChromaDB instance
- **Model**: Same GPT-4o mini configuration

### **With Frontend Chatbox**
- **Endpoint**: `POST /chat`
- **CORS**: Configured for web integration
- **Response**: JSON with formatted text
- **Status**: Real-time system health

## Key Features

### ✅ **Personality Consistency**
- Always responds as Jade
- Professional yet warm tone
- Adapts technical depth to audience
- Emphasizes business value

### ✅ **Knowledge Access**
- 208 chunks of Jimmie's information
- Semantic search for relevant context
- Source attribution in responses
- Real-time knowledge base access

### ✅ **Smart Responses**
- RAG-grounded answers (no hallucination)
- Context-aware conversation
- Business metrics when relevant
- Technical details on request

### ✅ **Production Ready**
- FastAPI with proper error handling
- CORS configured for web integration
- Health checks and status endpoints
- Comprehensive logging

## Monitoring

### **System Health**
```bash
curl http://localhost:8001/health
curl http://localhost:8001/status
```

### **RAG Status**
- Document count: 208 chunks
- Search availability: Real-time check
- Knowledge freshness: Last update timestamp

### **LLM Status**
- Model: GPT-4o mini
- API connectivity: Real-time check
- Token usage: Per-request tracking

---

**Jade-Brain is the single source of truth for all conversations about Jimmie Coleman's work and expertise.**