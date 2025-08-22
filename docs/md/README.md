# Portfolio Platform - AI-Powered Interview Assistant

## 🎯 Overview

**Clean, organized codebase for Jimmie's AI-powered portfolio platform**. Features Sheyla, an Indian AI avatar (based on mother) who conducts technical interviews and presents project information through natural conversation.

### Key Features
- 🤖 **Sheyla AI Avatar**: Professional Indian lady voice with conversational interview capabilities
- 💬 **Intelligent Chat**: RAG-powered responses about projects and technical experience  
- 📱 **Simple Layout**: Avatar/chat on left, projects showcase on right
- ☸️ **Production Ready**: Kubernetes deployment with proper resource management
- 🔄 **Local + Cloud**: Local LLM with OpenAI GPT-4o mini fallback

---

## 📁 Clean Architecture

```
Portfolio/
├── chat/                   # 🗣️ SHEYLA'S PERSONALITY & RESPONSES
│   ├── engines/
│   │   └── conversation_engine.py   # Sheyla's conversation logic
│   └── data/
│       ├── sheyla_personality.md    # Sheyla's character and speaking style
│       └── interview_qa.md          # Pre-written Q&A for interviews
│
├── api/                    # 🔧 BACKEND SERVICES (How frontend talks to backend)
│   ├── main.py             # FastAPI entry point
│   ├── settings.py         # Centralized configuration
│   ├── routes/             # API endpoints
│   │   ├── chat.py         # Chat with Sheyla
│   │   ├── avatar.py       # Avatar creation/playback
│   │   └── health.py       # System health checks
│   ├── engines/            # Core processing
│   │   ├── rag_engine.py   # Knowledge retrieval
│   │   ├── llm_engine.py   # LLM integration
│   │   └── avatar_engine.py # Avatar generation
│   └── services/           # External integrations
│       ├── elevenlabs.py   # Text-to-speech
│       └── did.py          # Video avatar creation
│
├── rag/                    # 📚 RAG KNOWLEDGE MANAGEMENT
│   ├── notebooks/          # Jupyter notebooks for RAG experiments
│   └── data/               # Knowledge base documents
│
├── ui/                     # 🎨 SINGLE TRUTH FRONTEND
│   ├── src/
│   │   ├── components/     # React components (TypeScript)
│   │   │   ├── AvatarPanel.tsx    # Sheyla avatar interface (LEFT SIDE)
│   │   │   ├── ChatPanel.tsx      # Chat with Sheyla (LEFT SIDE)
│   │   │   └── Projects.tsx       # Project showcase (RIGHT SIDE)
│   │   ├── pages/
│   │   │   └── Landing.jsx        # Main page layout
│   │   └── services/
│   │       └── api.ts             # API client for backend
│   └── vite.config.js      # Development proxy configuration
│
├── data/                   # 📄 CENTRALIZED DATA
│   ├── knowledge/          # RAG knowledge base
│   ├── personas/           # Avatar configurations
│   └── vectors/            # Vector database storage
│
└── k8s/                    # ☸️ KUBERNETES DEPLOYMENT
    ├── base/               # Base manifests
    └── overlays/           # Environment-specific configs
```

---

## 🚀 Quick Start

### 1. Development Setup
```bash
# Start the full stack locally
docker-compose up

# UI available at: http://localhost:5173
# API available at: http://localhost:8000
# API docs at: http://localhost:8000/docs
```

### 2. Kubernetes Deployment  
```bash
# Deploy to local Kubernetes
./deploy-local-k8s.sh

# Or use Make targets
make deploy-kind     # KIND cluster
make deploy-minikube # Minikube cluster
```

### 3. Test Sheyla's Responses
```bash
# Chat with Sheyla directly
curl -X POST http://localhost:8000/api/chat \\
  -H "Content-Type: application/json" \\
  -d '{"message": "Tell me about LinkOps AI-BOX"}'

# Get quick prompts
curl http://localhost:8000/api/chat/prompts
```

---

## 🗣️ Sheyla Avatar Configuration

### Personality
- **Name**: Sheyla (based on mother)
- **Heritage**: Indian professional
- **Voice**: Warm, clear, technically competent
- **Role**: Portfolio representative and technical interviewer

### Key Talking Points
1. **LinkOps AI-BOX**: Conversational AI for property management
2. **LinkOps Afterlife**: Open-source digital legacy platform  
3. **Technical Expertise**: DevSecOps + AI/ML combination
4. **Business Value**: Practical solutions with measurable ROI

### Interview Q&A Coverage
- Technical background and expertise
- Project deep-dives with business impact
- Architecture and scalability discussions
- Problem-solving approach and methodology

---

## 🎨 UI Components (Single Truth)

### Left Side - Avatar & Chat
- **AvatarPanel.tsx**: Sheyla's intro and avatar display
- **ChatPanel.tsx**: Conversational interface with Sheyla
- **Features**: Session management, follow-up suggestions, citations

### Right Side - Projects  
- **Projects.tsx**: Showcase of LinkOps AI-BOX and Afterlife
- **Data Source**: `ui/src/data/knowledge/jimmie/projects.json`
- **Features**: Project descriptions, tech stacks, demo links

### Layout Logic
```jsx
// Landing.jsx - Main layout
<div className="grid md:grid-cols-2 gap-4">
  <div className="space-y-4">
    <AvatarPanel />        {/* Sheyla introduction */}
    <ChatPanel />          {/* Chat with Sheyla */}
  </div>
  <div className="space-y-4">
    <Projects />           {/* Project showcase */}
  </div>
</div>
```

---

## 🔧 API Endpoints

### Chat API
```bash
POST /api/chat              # Chat with Sheyla
GET  /api/chat/prompts      # Get conversation starters
GET  /api/chat/health       # Chat service health
```

### Avatar API  
```bash
POST /api/avatar/create     # Create custom avatar
POST /api/avatar/talk       # Generate avatar speech
GET  /api/assets/{file}     # Serve avatar assets
```

### Health & Debug
```bash
GET  /health                # Overall system health
GET  /api/health/detailed   # Detailed service status
```

---

## 📚 RAG Knowledge Management

### Knowledge Sources
```
data/knowledge/jimmie/
├── 01-bio.md               # Personal background
├── 02-devops.md            # DevSecOps experience  
├── 03-aiml.md              # AI/ML expertise
├── 04-projects.md          # Project details
├── 05-faq.md               # Common interview Q&A
├── 06-jade.md              # LinkOps AI-BOX specifics
├── 07-current-context.md   # Current work focus
└── 08-sheyla-avatar-context.md # Avatar personality
```

### RAG Ingestion
```bash
# Ingest knowledge base
kubectl exec deploy/portfolio-api -- python scripts/ingest.py

# Verify ingestion
curl http://localhost:8000/api/rag/health
```

---

## ☸️ Kubernetes Configuration

### Resource Allocation (4GB VM Optimized)
```yaml
# API Service
resources:
  requests: { cpu: "200m", memory: "512Mi" }
  limits:   { cpu: "1",    memory: "2Gi" }

# UI Service  
resources:
  requests: { cpu: "100m", memory: "256Mi" }
  limits:   { cpu: "500m", memory: "512Mi" }
```

### Services Deployed
- **portfolio-api**: FastAPI backend with health checks
- **portfolio-ui**: React frontend with Nginx
- **chromadb**: Vector database for RAG
- **ollama**: Local LLM server (optional)

---

## 🔄 LLM Configuration

### Primary: Local Efficiency
```bash
LLM_PROVIDER=ollama
LLM_MODEL=qwen/qwen2.5-1.5b-instruct  # 4GB RAM optimized
LLM_API_BASE=http://ollama:11434
```

### Fallback: Cloud Reliability  
```bash
LLM_PROVIDER=openai
LLM_MODEL=gpt-4o-mini                  # Fast, cost-effective
LLM_API_BASE=https://api.openai.com
LLM_API_KEY=sk-proj-your-key-here
```

### Configuration Switch
```bash
# Switch to OpenAI fallback
kubectl set env deploy/portfolio-api \\
  LLM_PROVIDER=openai \\
  LLM_MODEL=gpt-4o-mini \\
  LLM_API_KEY=$OPENAI_API_KEY
```

---

## 🧪 Testing & Validation

### API Testing
```bash
# Health checks
curl http://localhost:8000/health

# Chat functionality  
curl -X POST http://localhost:8000/api/chat \\
  -d '{"message": "What is LinkOps AI-BOX?"}'

# Avatar functionality
curl http://localhost:8000/api/avatar/health
```

### E2E Testing
```bash
# Playwright tests
cd ui && npm run test:e2e

# Golden answer validation
python test_golden_answers.py
```

---

## 📖 Documentation for Mentors

### Code Quality Features
- ✅ **Clean Architecture**: Microservice-style organization
- ✅ **Comprehensive Documentation**: Every component documented
- ✅ **Type Safety**: TypeScript frontend, Pydantic backend
- ✅ **Testing**: E2E tests + golden answer validation
- ✅ **Production Ready**: Resource limits, health checks, monitoring

### Key Review Areas
1. **API Structure**: `api/` - Clean FastAPI with proper separation
2. **Chat Logic**: `chat/` - Sheyla's personality and conversation engine
3. **UI Components**: `ui/src/components/` - Single truth components
4. **RAG Implementation**: `api/engines/rag_engine.py` - Vector search
5. **Deployment**: `k8s/` - Production-ready manifests

### Business Value Demonstration
- **LinkOps AI-BOX**: Property management automation with real ROI
- **Technical Expertise**: DevSecOps + AI/ML combination
- **Cost Optimization**: 4GB RAM deployment strategy
- **Practical AI**: Solutions that businesses can actually use

---

## 🔗 Project Links

- **Live Demo**: https://demo.linksmlm.com
- **GitHub**: https://github.com/jimjrxieb/shadow-link-industries
- **LinkOps Afterlife**: https://github.com/jimjrxieb/LinkOps-Afterlife

---

## 💼 Interview Scenarios

### Technical Deep-Dive
Ask Sheyla: *"How is the LinkOps AI-BOX architected?"*
- RAG architecture explanation
- Local LLM deployment strategy
- Kubernetes resource optimization

### Business Impact  
Ask Sheyla: *"What's the ROI of these solutions?"*
- Property management time savings (10-15 hours/week)
- Cost analysis and payback period
- Target market and customer validation

### Problem-Solving
Ask Sheyla: *"What's the biggest technical challenge solved?"*
- 4GB RAM constraint optimization
- Local-first with cloud fallbacks
- Production deployment strategies

---

**Ready for technical interviews with a clean, documented, production-ready codebase that demonstrates real business value.**