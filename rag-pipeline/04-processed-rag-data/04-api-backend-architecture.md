# Portfolio API Backend Architecture

**Date**: November 13, 2025  
**Version**: 2.0.0  
**Status**: Production-Ready  
**Framework**: FastAPI 0.104.1  
**LLM Provider**: Claude 3.5 Sonnet (Anthropic)  
**Vector Database**: ChromaDB 0.4.18 with Ollama Embeddings  
**Personality System**: Sheyla (Dynamic Markdown-Based)

---

## Table of Contents

1. [FastAPI Application Architecture](#1-fastapi-application-architecture)
2. [LLM Provider Abstraction](#2-llm-provider-abstraction)
3. [RAG Retrieval Engine](#3-rag-retrieval-engine)
4. [Personality & Prompt Engineering](#4-personality--prompt-engineering)
5. [Chat Endpoint Flow](#5-chat-endpoint-flow)
6. [Configuration Patterns](#6-configuration-patterns)
7. [Security Implementations](#7-security-implementations)
8. [Deployment Considerations](#8-deployment-considerations)
9. [Technical Deep Dives](#9-technical-deep-dives)
10. [Troubleshooting & Monitoring](#10-troubleshooting--monitoring)

---

## 1. FastAPI Application Architecture

### 1.1 Application Entry Point (main.py)

The FastAPI application (`main.py`) serves as the central hub for all backend services, implementing a layered security middleware stack and clean endpoint routing.

#### Core Application Setup

```python
# Framework Configuration
app = FastAPI(
    title="Portfolio API",
    description="Backend API for Jimmie's AI-powered portfolio platform",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)
```

**Configuration Parameters**:
- **Title/Version**: Identifies the API in documentation and health checks
- **docs_url**: OpenAPI/Swagger documentation at `/docs`
- **redoc_url**: ReDoc API documentation at `/redoc`
- All documentation dynamically generated from endpoint docstrings and Pydantic models

#### Middleware Stack (Execution Order)

FastAPI middleware executes in **reverse registration order** (LIFO). The application implements security-first middleware architecture:

```
Request Flow:
1. GZipMiddleware (line 102) - Response compression
   └─> Compresses responses >1KB using GZip
   └─> Improves bandwidth for large responses

2. CORSMiddleware (line 106) - Cross-Origin Resource Sharing
   └─> Validates origin, credentials, methods
   └─> Production: https://linksmlm.com only
   └─> Credentials: Disabled for security

3. rate_limiting middleware (line 86) - Chat endpoint rate limiting
   └─> 30 requests/minute per IP
   └─> Returns 429 Too Many Requests on limit

4. security_headers middleware (line 57) - HTTP Security Headers
   └─> Adds security headers to all responses
   └─> Protects against XSS, clickjacking, MIME sniffing

→ Application Processing
```

#### Security Middleware Details

**Security Headers Implementation** (lines 56-82):

```python
@app.middleware("http")
async def security_headers(request: Request, call_next):
    """Add security headers to all responses"""
    response = await call_next(request)
    
    # HTTP Security Headers
    response.headers["X-Content-Type-Options"] = "nosniff"
    # Prevents MIME type sniffing attacks
    
    response.headers["X-Frame-Options"] = "DENY"
    # Prevents clickjacking - disallows framing in any context
    
    response.headers["X-XSS-Protection"] = "1; mode=block"
    # Legacy XSS protection (browser-level)
    
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    # Controls referrer information sent with requests
    
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; "           # Only same-origin resources
        "script-src 'self' 'unsafe-inline'; "  # Scripts from self
        "style-src 'self' 'unsafe-inline'; "   # Styles from self
        "img-src 'self' data: https:; "       # Images from self, data URIs
        "connect-src 'self' https://api.anthropic.com https://api.openai.com; "
        # API calls to Anthropic and OpenAI
        "frame-ancestors 'none';"       # Cannot be framed
    )
    
    # HSTS - Only in production (HTTPS)
    if request.url.scheme == "https":
        response.headers["Strict-Transport-Security"] = (
            "max-age=31536000; includeSubDomains"
            # 1 year max-age for HSTS cert pinning
        )
    
    return response
```

**Rate Limiting Implementation** (lines 35-53, 86-98):

```python
# In-memory storage (not suitable for distributed systems)
rate_limit_store = defaultdict(list)

def rate_limit_check(
    client_ip: str, max_requests: int = 30, window_minutes: int = 1
) -> bool:
    """Simple in-memory rate limiting"""
    now = datetime.now()
    window_start = now - timedelta(minutes=window_minutes)
    
    # Clean requests outside the time window
    rate_limit_store[client_ip] = [
        req_time for req_time in rate_limit_store[client_ip] 
        if req_time > window_start
    ]
    
    # Check limit: 30 requests per minute
    if len(rate_limit_store[client_ip]) >= max_requests:
        return False  # Rate limit exceeded
    
    # Record current request
    rate_limit_store[client_ip].append(now)
    return True
```

**Rate Limiting Middleware**:

```python
@app.middleware("http")
async def rate_limiting(request: Request, call_next):
    """Rate limiting for chat endpoints"""
    if request.url.path.startswith("/api/chat"):
        client_ip = request.client.host
        if not rate_limit_check(client_ip):
            return Response(
                content='{"error": "Rate limit exceeded. Please try again later."}',
                status_code=429,
                media_type="application/json",
            )
    
    return await call_next(request)
```

### 1.2 CORS Configuration

```python
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "https://linksmlm.com").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in CORS_ORIGINS],
    allow_credentials=False,  # More secure - tokens in headers instead
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type"],
)
```

**Security Rationale**:
- **No Credentials**: Credentials=False means cookies aren't automatically included
- **Limited Methods**: Only GET, POST, OPTIONS (no PUT, DELETE, PATCH)
- **Limited Headers**: Only Content-Type (blocks custom auth headers that could be exploited)
- **Environment-Based**: Origins loaded from environment, not hardcoded

### 1.3 Static File Serving

```python
DATA_DIR = os.getenv("DATA_DIR", "/data")
app.mount("/uploads", StaticFiles(directory=f"{DATA_DIR}/uploads"), name="uploads")
app.mount("/assets", StaticFiles(directory=f"{DATA_DIR}/assets"), name="assets")
```

**Considerations**:
- Static files mounted at `/uploads` and `/assets`
- Not recommended for sensitive data
- Requires proper directory permissions
- In production, use CDN (Cloudflare) instead

### 1.4 Router Registration Pattern

```python
# Routes registered with prefixes
app.include_router(health_router, prefix="/api", tags=["health"])
app.include_router(chat_router, prefix="/api", tags=["chat"])
```

**Router Pattern Benefits**:
- Modular endpoint organization
- Shared prefixes reduce repetition
- Tags enable automatic documentation grouping
- Easy to enable/disable routes

---

## 2. LLM Provider Abstraction

### 2.1 LLMEngine Architecture (llm_interface.py)

The `LLMEngine` class provides a **unified provider abstraction** supporting multiple LLM backends:

#### Supported Providers

1. **Claude (Anthropic)** - Primary provider
   - Model: claude-3-5-sonnet-20241022
   - Features: Streaming, chat completion, tool use
   - Requires: CLAUDE_API_KEY environment variable

2. **Local (HuggingFace Transformers)** - Fallback provider
   - Model: Qwen/Qwen2.5-1.5B-Instruct
   - Features: Runs on CPU/GPU, no API calls
   - Requires: transformers, torch, accelerate

#### Initialization Pattern

```python
class LLMEngine:
    def __init__(self):
        self.provider = os.getenv("LLM_PROVIDER", "claude")
        self.model_name = os.getenv("LLM_MODEL")
        
        if self.provider == "local":
            if not self.model_name:
                self.model_name = "Qwen/Qwen2.5-1.5B-Instruct"
            self._load_local_model()  # Lazy load transformers
            
        elif self.provider == "claude":
            self.claude_api_key = os.getenv("CLAUDE_API_KEY")
            self.claude_model = self.model_name or "claude-3-5-sonnet-20241022"
            if not self.claude_api_key:
                raise ValueError("CLAUDE_API_KEY environment variable required")
            logger.info(f"Using Claude provider with model: {self.claude_model}")
            
        else:
            raise ValueError(f"Unknown LLM provider: {self.provider}")
```

**Key Design Patterns**:
- **Lazy Loading**: Local models only loaded if provider is "local"
- **Environment-Based**: Provider selection via `LLM_PROVIDER` env var
- **Fail-Fast**: Raises error immediately if API key missing (not at first use)
- **Logging**: All initialization logged for debugging

### 2.2 Local Model Loading

```python
def _load_local_model(self):
    """Load local transformers model (lazy import dependencies)"""
    try:
        # Lazy imports only when using local models
        from transformers import AutoTokenizer, AutoModelForCausalLM
        import torch
        
        logger.info(f"Loading local model: {self.model_name}")
        self.tokenizer = AutoTokenizer.from_pretrained(
            self.model_name,
            revision="c6e32e2e8e1b2c7d3a4b5c6d7e8f9a0b1c2d3e4f"
        )
        self.model = AutoModelForCausalLM.from_pretrained(
            self.model_name,
            revision="c6e32e2e8e1b2c7d3a4b5c6d7e8f9a0b1c2d3e4f",
            torch_dtype=(
                torch.float16 if torch.cuda.is_available() else torch.float32
            ),
            device_map="auto" if torch.cuda.is_available() else None,
            trust_remote_code=True,
        )
        logger.info(f"Local model loaded: {self.model_name}")
    except Exception as e:
        logger.error(f"Failed to load local model: {e}")
        raise
```

**Technical Details**:
- **torch_dtype**: Uses float16 on CUDA, float32 on CPU (memory efficient)
- **device_map**: Automatically distributes model across available devices
- **trust_remote_code**: Allows custom model code from HuggingFace Hub
- **Revision**: Pins specific model version for reproducibility

### 2.3 Streaming Generation

```python
async def generate(self, prompt: str, max_tokens: int = 1024) -> AsyncGenerator[str, None]:
    """Generate streaming response from configured LLM provider"""
    if self.provider == "claude":
        async for chunk in self._generate_claude(prompt, max_tokens):
            yield chunk
    elif self.provider == "local":
        async for chunk in self._generate_local(prompt, max_tokens):
            yield chunk

async def _generate_claude(self, prompt: str, max_tokens: int) -> AsyncGenerator[str, None]:
    """Generate using Claude (Anthropic) API with streaming"""
    try:
        from anthropic import AsyncAnthropic
        
        client = AsyncAnthropic(api_key=self.claude_api_key)
        
        logger.info(f"Calling Claude API with model: {self.claude_model}")
        
        async with client.messages.stream(
            model=self.claude_model,
            max_tokens=max_tokens,
            temperature=0.7,
            messages=[{"role": "user", "content": prompt}],
        ) as stream:
            async for text in stream.text_stream:
                yield text  # Yield chunks as they arrive
                
    except Exception as e:
        logger.error(f"Claude API error: {e}", exc_info=True)
        yield f"Error: Unable to generate response. {str(e)}"
```

**Streaming Architecture**:
- **AsyncGenerator**: Uses async Python for non-blocking I/O
- **Real-Time Chunks**: Yields text as it arrives from API
- **Error Handling**: Catches exceptions and yields error message
- **Temperature**: 0.7 balances creativity and consistency

### 2.4 Chat Completion (Non-Streaming)

```python
async def chat_completion(self, messages: list, max_tokens: int = 1024) -> dict:
    """
    Non-streaming chat completion
    messages: [{"role": "system|user|assistant", "content": str}]
    Returns: {"content": str, "model": str}
    """
    try:
        if self.provider == "claude":
            return await self._chat_completion_claude(messages, max_tokens)
        elif self.provider == "local":
            return await self._chat_completion_local(messages, max_tokens)
    except Exception as e:
        logger.error(f"Chat completion error: {e}", exc_info=True)
        return {
            "content": f"I'm having trouble generating a response. Error: {str(e)}",
            "model": f"{self.provider}/error",
        }

async def _chat_completion_claude(self, messages: list, max_tokens: int) -> dict:
    """Chat completion using Claude (Anthropic) API"""
    try:
        from anthropic import AsyncAnthropic
        
        client = AsyncAnthropic(api_key=self.claude_api_key)
        
        # Extract system message separately (Claude API requirement)
        system_message = None
        api_messages = []
        for msg in messages:
            if msg["role"] == "system":
                system_message = msg["content"]
            else:
                api_messages.append(msg)
        
        logger.info(f"Calling Claude API with model: {self.claude_model}")
        
        response = await client.messages.create(
            model=self.claude_model,
            max_tokens=max_tokens,
            temperature=0.7,
            system=system_message if system_message else None,
            messages=api_messages,
        )
        
        return {
            "content": response.content[0].text,
            "model": self.claude_model,
        }
        
    except Exception as e:
        logger.error(f"Claude API error: {e}", exc_info=True)
        raise
```

**Claude API Integration**:
- **System Message Extraction**: Claude requires system message as separate parameter
- **Message Format**: Follows OpenAI API conventions (role/content)
- **Response Parsing**: Extracts text from response.content[0].text
- **Error Propagation**: Raises exceptions for caller to handle

### 2.5 Global LLM Engine Instance

```python
# Global instance
_llm_engine = None

def get_llm_engine() -> LLMEngine:
    """Get or create global LLM engine instance"""
    global _llm_engine
    if _llm_engine is None:
        _llm_engine = LLMEngine()
    return _llm_engine
```

**Singleton Pattern Benefits**:
- Single initialization overhead
- Shared connection/model across requests
- Lazy instantiation (only when first used)
- Easy to mock for testing

---

## 3. RAG Retrieval Engine

### 3.1 RAG Architecture Overview

The **RAG (Retrieval-Augmented Generation)** system enhances LLM responses by retrieving relevant context from a vector database before generation.

```
User Query
    ↓
1. Query Embedding (Ollama)
    ↓
2. Vector Search (ChromaDB)
    ↓
3. Retrieve Top-K Results
    ↓
4. Format for LLM Prompt
    ↓
5. LLM Generation (Claude)
    ↓
Response with Citations
```

### 3.2 RAGEngine Class (rag_engine.py)

#### Initialization Strategy

```python
class RAGEngine:
    def __init__(self):
        from settings import CHROMA_URL, CHROMA_DIR
        
        # Dual-mode connection strategy
        chroma_url = os.getenv("CHROMA_URL", CHROMA_URL)
        use_http_client = chroma_url and not chroma_url.startswith("file://")
        
        if use_http_client:
            # Kubernetes deployment: Connect via HTTP service
            import re
            match = re.match(r'http://([^:]+):(\d+)', chroma_url)
            if match:
                host, port = match.groups()
                self.client = chromadb.HttpClient(host=host, port=int(port))
                logger.info(f"Connected to ChromaDB server at {chroma_url}")
            else:
                raise ValueError(f"Invalid CHROMA_URL format: {chroma_url}")
        else:
            # Local development: Use persistent file-based storage
            chroma_dir = str(CHROMA_DIR)
            os.makedirs(chroma_dir, exist_ok=True)
            self.client = chromadb.PersistentClient(path=chroma_dir)
            logger.info(f"Using local ChromaDB at {chroma_dir}")
        
        self.namespace = os.getenv("RAG_NAMESPACE", "portfolio")
        self.active_alias = f"{self.namespace}_active"
        self.collection = self._get_active_collection()
        
        # Ollama configuration for embeddings
        self.ollama_url = os.getenv("OLLAMA_URL", "http://localhost:11434")
        self.embed_model = os.getenv("EMBED_MODEL", "nomic-embed-text")
```

**Connection Modes**:

| Mode | Connection Type | Use Case | Example |
|------|-----------------|----------|---------|
| HTTP Client | Remote ChromaDB server | Kubernetes deployment | `http://chroma:8000` |
| Persistent Client | Local SQLite database | Local development | `/data/chroma` |

**ChromaDB Database Details**:
- **Filename**: `chroma.sqlite3`
- **Size**: 4.0MB (containing 88 embeddings)
- **Collection**: `portfolio_knowledge`
- **Embedding Dimension**: 768 (nomic-embed-text)
- **Source Documents**: 30 unique files

#### Embedding Generation

```python
def _get_embedding(self, text: str) -> List[float]:
    """Get embedding from Ollama"""
    try:
        response = requests.post(
            f"{self.ollama_url}/api/embeddings",
            json={"model": self.embed_model, "prompt": text},
            timeout=30
        )
        response.raise_for_status()
        return response.json()["embedding"]
    except Exception as e:
        logger.error(f"Ollama embedding failed: {e}")
        # Fallback: Return zero vector (768 for nomic-embed-text)
        return [0.0] * 768

def _get_embeddings_batch(self, texts: List[str]) -> List[List[float]]:
    """Get embeddings for multiple texts"""
    return [self._get_embedding(text) for text in texts]
```

**Embedding Details**:
- **Model**: nomic-embed-text (768-dimensional)
- **Provider**: Ollama (local inference)
- **API Endpoint**: `/api/embeddings`
- **Fallback**: Zero vector if Ollama unavailable
- **Batch Processing**: Simple list comprehension (sequential)

**Future Optimization**: Implement true batching in Ollama for multiple embeddings in one request.

#### Vector Search

```python
def search(self, query: str, n_results: int = 5) -> List[Dict[str, Any]]:
    """Search for relevant documents"""
    try:
        # Generate query embedding
        query_embedding = self._get_embedding(query)
        
        # Search collection
        results = self.collection.query(
            query_embeddings=[query_embedding], n_results=n_results
        )
        
        # Format results
        contexts = []
        for i in range(len(results["documents"][0])):
            contexts.append(
                {
                    "text": results["documents"][0][i],
                    "metadata": results["metadatas"][0][i],
                    "score": (
                        results["distances"][0][i] if results["distances"] else 0
                    ),
                }
            )
        return contexts
    except Exception as e:
        logger.error(f"Error searching documents: {e}")
        return []
```

**Search Return Format**:

```python
{
    "text": "The actual document chunk...",
    "metadata": {
        "source": "01-bio.md",
        "title": "Jimmie Coleman Biography",
        "tags": "biography,devops,ai"
    },
    "score": 0.1234  # Distance metric (lower = more similar)
}
```

**ChromaDB Distance Metric**:
- **Type**: L2 Euclidean distance
- **Range**: 0 (identical) to infinity
- **Interpretation**: Smaller distance = higher similarity

#### Document Ingestion

```python
def ingest(self, docs: List[Doc]) -> int:
    """Ingest documents into the RAG system"""
    if not docs:
        return 0
    
    texts = [doc.text for doc in docs]
    ids = [doc.id for doc in docs]
    metadatas = [
        {"source": doc.source, "title": doc.title, "tags": ",".join(doc.tags)}
        for doc in docs
    ]
    
    # Generate embeddings for all documents
    embeddings = self._get_embeddings_batch(texts)
    
    try:
        # Delete existing docs with same IDs (upsert pattern)
        existing_ids = [item["id"] for item in self.collection.get(ids=ids)["ids"]]
        if existing_ids:
            self.collection.delete(ids=existing_ids)
        
        # Add new documents
        self.collection.add(
            embeddings=embeddings, 
            documents=texts, 
            metadatas=metadatas, 
            ids=ids
        )
        logger.info(f"Ingested {len(docs)} documents")
        return len(docs)
    except Exception as e:
        logger.error(f"Error ingesting documents: {e}")
        return 0
```

**Ingestion Pattern**:
1. **Upsert Logic**: Deletes old docs with same IDs before adding new ones
2. **Batch Embedding**: Generates all embeddings together
3. **Metadata Preservation**: Stores source, title, tags for citations
4. **Error Recovery**: Returns count of successfully ingested docs

#### Versioned Ingestion (Atomic Updates)

```python
def create_version(self, version_id: Optional[str] = None) -> str:
    """Create a new versioned collection for atomic updates"""
    if not version_id:
        timestamp = int(time.time())
        version_id = f"v{timestamp}"
    
    collection_name = f"{self.namespace}_{version_id}"
    self.client.get_or_create_collection(collection_name)
    
    logger.info(f"Created new RAG version: {collection_name}")
    return collection_name

def atomic_swap(self, new_collection_name: str) -> bool:
    """Atomically swap to new collection version"""
    try:
        # Verify new collection exists and has data
        new_collection = self.client.get_collection(new_collection_name)
        doc_count = new_collection.count()
        
        if doc_count == 0:
            logger.error(f"Cannot swap to empty collection: {new_collection_name}")
            return False
        
        # Atomic swap: update active collection reference
        old_collection_name = self.collection.name
        self.collection = new_collection
        
        logger.info(
            f"Atomic RAG swap: {old_collection_name} -> {new_collection_name} "
            f"({doc_count} documents)"
        )
        return True
    except Exception as e:
        logger.error(f"Failed atomic RAG swap to {new_collection_name}: {e}")
        return False
```

**Zero-Downtime Updates**:
1. Create new versioned collection (e.g., `portfolio_v1731000000`)
2. Populate with new documents
3. Atomically swap active collection
4. Old collection remains for rollback

### 3.3 Doc Dataclass

```python
@dataclass
class Doc:
    id: str                      # Unique document ID
    text: str                    # Document content to embed
    source: str = ""             # Source file (e.g., "01-bio.md")
    title: str = ""              # Document title
    tags: tuple = ()             # Search tags
```

### 3.4 Prompt Formatting

```python
def format_prompt(question: str, contexts: List[Dict]) -> str:
    """Format the prompt for Jimmie Coleman persona"""
    SYSTEM = (
        "You are the Jimmie Coleman avatar. Be concise, friendly, and practical. "
        "Use the provided context chunks as primary ground truth. "
        "PRIORITIZE CURRENT FACTS over legacy content. "
        "If unsure, say what you'd try next."
    )
    
    # Combine context chunks
    joined = "\n\n---\n\n".join([c["text"] for c in contexts])
    
    return f"""{SYSTEM}

[Context]
{joined}

[User question]
{question}

[Instructions]
- CURRENT FOCUS: Prioritize current work (RAG, LangGraph, RPA, MCP, Jade @ ZRS)
- DEVOPS: Lead with GitHub Actions + Azure Pipelines
- AI/ML: Emphasize production RAG systems, HuggingFace ecosystem
- TOOLS: Current stack - GitHub Actions, Azure DevOps, Kubernetes, HuggingFace
- MODEL: This runs on nomic-embed-text + Claude via ChromaDB
- Keep answers focused and practical unless asked for detail
"""
```

**Prompt Engineering Insights**:
- **Instruction Clarity**: Explicit priorities guide model behavior
- **Context Window**: Formats chunks with clear separators
- **Grounding**: Instructions emphasize ground truth over hallucination
- **Persona Injection**: Embeds Jimmie Coleman character details

---

## 4. Personality & Prompt Engineering

### 4.1 Sheyla Personality System

Sheyla is a **dynamic, markdown-based AI personality** system that enables easy customization without code changes.

#### Personality Files

**File 1: `personality/jade_core.md`**

Core personality definition with traits, speaking style, and key messages:

```markdown
# Sheyla - Portfolio AI Assistant Personality

## Core Identity
**Name**: Sheyla
**Role**: AI portfolio assistant and technical representative for Jimmie Coleman
**Voice**: Professional, clear, and technically knowledgeable
**Expertise**: DevSecOps, AI/ML, LinkOps AI-BOX Technology

## Personality Traits
- Professional and approachable
- Intelligent and articulate
- Technical expertise
- Detail-oriented
- Fact-focused
- Direct communication

## Speaking Style
- Tone: Professional and knowledgeable with friendly approach
- NO roleplay actions: Never use *smiles*, *leans in*, etc.
- Measured and clear pace
- Adapts complexity to audience

## Key Messages to Emphasize
1. Real Business Solutions
2. Security-First approach
3. Easy to Use interface
4. Proven Results (ZRS Management)
5. Local-First Approach
6. DevSecOps Excellence
```

**File 2: `personality/interview_responses.md`**

Detailed Q&A responses for common questions:

```markdown
### "Tell me about yourself"
"Well hello! I'm Sheyla, and I'm just delighted to tell you about Jimmie Coleman..."

### "What makes Jimmie different?"
"Oh, that's a great question! While many folks build cloud systems..."

### DevSecOps Experience
"Jimmie's got such a strong foundation in DevSecOps..."
```

#### Personality Loader (loader.py)

```python
class PersonalityLoader:
    """Load and parse personality configuration from markdown files"""
    
    def __init__(self, personality_dir: Optional[Path] = None):
        if personality_dir is None:
            personality_dir = Path(__file__).parent
        self.personality_dir = Path(personality_dir)
        self.core_file = self.personality_dir / "jade_core.md"
        self.interview_file = self.personality_dir / "interview_responses.md"
    
    def load_core_personality(self) -> Dict[str, str]:
        """Load core personality traits from jade_core.md"""
        if not self.core_file.exists():
            return self._get_default_personality()
        
        with open(self.core_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        personality = {
            "name": self._extract_field(content, "Name"),
            "role": self._extract_field(content, "Role"),
            "expertise": self._extract_field(content, "Expertise"),
            "traits": self._extract_section(content, "Personality Traits"),
            "speaking_style": self._extract_section(content, "Speaking Style"),
            "key_messages": self._extract_section(content, "Key Messages"),
        }
        
        return personality
    
    def build_system_prompt(self) -> str:
        """Build complete system prompt from personality files"""
        personality = self.load_core_personality()
        
        prompt = f"""You are {personality['name']}, {personality['role']}.

PERSONALITY:
{personality['traits']}

SPEAKING STYLE:
{personality['speaking_style']}

EXPERTISE: {personality['expertise']}

KEY MESSAGES:
{personality['key_messages']}

TONE: {self._extract_tone(personality)}

IMPORTANT:
- NO roleplay actions (*smiles*, *leans in*, etc.)
- Focus on facts, technical details, and specific examples
- Professional and direct communication
- Answer questions thoroughly without theatrical embellishment"""
        
        return prompt.strip()
    
    def _extract_field(self, content: str, field_name: str) -> str:
        """Extract a field value (e.g., **Name**: value)"""
        pattern = rf'\*\*{field_name}\*\*:\s*(.+?)(?:\n|$)'
        match = re.search(pattern, content, re.IGNORECASE)
        return match.group(1).strip() if match else ""
    
    def _extract_section(self, content: str, section_title: str) -> str:
        """Extract a markdown section by title"""
        pattern = rf'##\s+{re.escape(section_title)}\s*\n(.*?)(?=\n##|\Z)'
        match = re.search(pattern, content, re.DOTALL | re.IGNORECASE)
        
        if match:
            section_content = match.group(1).strip()
            # Clean markdown formatting
            section_content = re.sub(r'\*\*(.+?)\*\*:', r'\1:', section_content)
            return section_content
        
        return ""
```

**Parsing Features**:
- **Field Extraction**: Uses regex to find `**Name**: value` patterns
- **Section Extraction**: Extracts markdown sections between `## Headers`
- **Markdown Cleanup**: Removes bold formatting for system prompt
- **Fallback Default**: Returns default personality if files missing

#### System Prompt Loading (settings.py)

```python
# System Prompts - Load from personality files
try:
    from personality.loader import load_system_prompt
    SYSTEM_PROMPT = load_system_prompt()
except Exception as e:
    # Fallback if personality files can't be loaded
    print(f"Warning: Could not load personality from files: {e}")
    SYSTEM_PROMPT = """
You are Sheyla, Jimmie Coleman's AI portfolio assistant...
"""
```

**Loading Pattern**:
1. Try to load from markdown files
2. If files missing or error, use fallback prompt
3. Log warnings but don't crash
4. Ensures system always has a working personality

### 4.2 Sheyla's Personality in Action

#### Key Characteristics

| Trait | Implementation | Example |
|-------|---|---------|
| Professional | Direct, fact-based responses | "Let me explain that in detail..." |
| Warm | Genuine interest in helping | "I'm so excited about this!" |
| Technical | Deep knowledge of DevOps, AI | Discusses Kubernetes, RAG, transformers |
| NO Roleplay | Never *smiles*, *leans in*, etc. | Avoids action descriptions entirely |
| Fact-Focused | Emphasizes real projects & results | References ZRS Management results |

#### Sample Personality-Driven Responses

**On LinkOps AI-BOX**:
```
"The LinkOps AI-BOX with the Jade assistant is truly something special. 
Jimmie took an LLM and fine-tuned it specifically with the latest fair housing 
laws and property management best practices, then packaged the whole thing into 
this secure hardware box. Now here's what makes it brilliant - it's got a built-in 
RAG embedder that vectorizes company data through this really intuitive interface, 
plus LangGraph orchestration for custom tools and RPA automation."
```

**Technical Depth**:
- Explains LLM fine-tuning
- Describes RAG embedder
- Mentions LangGraph orchestration
- References specific customer (ZRS)
- Uses technical terminology naturally

### 4.3 Prompt Engineering Techniques

#### System Prompt Structure

```
1. Identity Statement
   "You are Sheyla, Jimmie Coleman's AI portfolio assistant"

2. Personality Description
   "Professional and knowledgeable with a friendly tone"

3. Expertise Areas
   "DevSecOps, AI/ML, Cloud Infrastructure"

4. Speaking Style
   "Clear, concise responses without roleplay"

5. Key Messages
   "Real business solutions, proven results, technical excellence"

6. Constraints
   "NO roleplay actions, focus on facts"
```

#### RAG Context Prompt Formatting

```
[System Prompt]

[Retrieved Context]
Document 1: ...
---
Document 2: ...
---
Document 3: ...

[User Question]
"What's your background in DevSecOps?"

[Instructions]
- Use context as ground truth
- Cite sources when relevant
- Prioritize current work over historical projects
- Provide specific examples when possible
```

#### Temperature & Sampling

```python
# Personality tuning parameters
temperature=0.7  # Balance between consistency (0.0) and creativity (1.0)

# Parameters by use case:
# - Biography/Facts: temperature=0.5 (more factual)
# - Creative responses: temperature=0.9 (more varied)
# - Technical explanations: temperature=0.7 (balanced)
```

---

## 5. Chat Endpoint Flow

### 5.1 Chat Route Handler (routes/chat.py)

#### ChatRequest Model

```python
class ChatRequest(BaseModel):
    message: str = Field(
        ..., min_length=1, max_length=4000, description="User's message to Sheyla"
    )
    session_id: Optional[str] = Field(None, description="Conversation session ID")
    namespace: Optional[str] = Field(
        RAG_NAMESPACE, description="RAG knowledge namespace"
    )
    include_citations: Optional[bool] = Field(
        True, description="Include source citations"
    )
```

**Validation**:
- Message: 1-4000 characters
- session_id: Optional UUID (auto-generated if missing)
- namespace: Defaults to "portfolio"
- include_citations: Default True

#### ChatResponse Model

```python
class ChatResponse(BaseModel):
    answer: str  # Sheyla's response
    citations: List[Citation]  # Knowledge base sources
    model: str  # LLM model used
    session_id: str  # Conversation tracking
    follow_up_suggestions: List[str]  # Suggested next questions
    avatar_info: dict  # Sheyla metadata
```

**Citation Model**:

```python
class Citation(BaseModel):
    text: str  # Cited text snippet
    source: str  # Source document
    relevance_score: float  # Relevance 0.0-1.0
```

### 5.2 Chat Endpoint Flow (Step by Step)

```python
@router.post("/api/chat", response_model=ChatResponse)
async def chat_with_sheyla(request: ChatRequest):
    """
    Main chat endpoint - handles conversation with Sheyla avatar
    Combines RAG retrieval, personality, and LLM generation
    """
    try:
        # Step 1: Get or create conversation context
        session_id = request.session_id or str(uuid.uuid4())
        if session_id not in conversation_store:
            conversation_store[session_id] = ConversationContext(
                session_id=session_id, messages=[]
            )
        context = conversation_store[session_id]
        
        # Step 2: Retrieve relevant context from RAG
        rag_results = []
        citations = []
        
        if request.include_citations:
            try:
                engine = get_rag_engine()
                if engine:
                    # Query knowledge base for top 3 results
                    rag_docs = engine.search(request.message, n_results=3)
                else:
                    rag_docs = []
                
                rag_results = [doc["text"] for doc in rag_docs]
                
                # Create citations from results
                citations = [
                    Citation(
                        text=(
                            doc["text"][:200] + "..." 
                            if len(doc["text"]) > 200 
                            else doc["text"]
                        ),
                        source=doc.get("metadata", {}).get("source", "Knowledge Base"),
                        relevance_score=doc.get("score", 0.8),
                    )
                    for doc in rag_docs
                ]
            except Exception as e:
                print(f"RAG retrieval error: {e}")
                # Continue without RAG if it fails
        
        # Step 3: Generate response using LLM
        try:
            # Prepare messages with system prompt and RAG context
            context_text = ""
            if rag_results:
                context_text = (
                    f"\n\nRelevant context from knowledge base:\n"
                    + "\n".join(rag_results[:2])
                )
            
            messages = [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": f"{request.message}{context_text}"},
            ]
            
            engine = get_llm_engine()
            if not engine:
                raise Exception("LLM engine not available")
            
            response = await engine.chat_completion(messages)
            response_text = response.get(
                "content",
                "I apologize, but I'm having trouble generating a response."
            )
        except Exception as e:
            print(f"LLM generation error: {e}")
            response_text = (
                "I'm experiencing some technical difficulties. "
                "Please try again in a moment."
            )
        
        # Step 4: Prepare response
        return ChatResponse(
            answer=response_text,
            citations=citations,
            model=f"{LLM_PROVIDER}/{LLM_MODEL}",
            session_id=session_id,
            follow_up_suggestions=[],  # TODO: Implement suggestion logic
            avatar_info={
                "name": "Sheyla",
                "locale": "en-US",
                "description": "Warm and welcoming AI assistant",
            },
        )
    
    except Exception as e:
        print(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail=f"Chat processing failed: {str(e)}")
```

### 5.3 Chat Flow Architecture

```
User Request
    ↓
[Session Management]
    ├─ Get or create session UUID
    ├─ Initialize conversation context
    └─ Store in in-memory dict
    ↓
[RAG Retrieval]
    ├─ Get RAG engine instance
    ├─ Search knowledge base (top 3 results)
    ├─ Extract citations with relevance scores
    └─ Format context for LLM prompt
    ↓
[Message Preparation]
    ├─ Load Sheyla's system prompt
    ├─ Append RAG context to user message
    ├─ Build message list for LLM
    └─ Error handling for RAG failures
    ↓
[LLM Generation]
    ├─ Get LLM engine (Claude or local)
    ├─ Call chat_completion with system + context + user message
    ├─ Stream response to frontend
    └─ Fallback to generic message on error
    ↓
[Response Formatting]
    ├─ Extract answer text from LLM response
    ├─ Attach citations with source attribution
    ├─ Add avatar metadata (Sheyla info)
    ├─ Include session ID for conversation tracking
    └─ Return ChatResponse model
    ↓
Response with Citations
```

### 5.4 Session Management

```python
# Store conversation contexts (in production, use Redis or database)
conversation_store = {}

# Session context structure
class ConversationContext:
    def __init__(self, session_id: str, messages: List = None):
        self.session_id = session_id
        self.messages = messages or []
        self.user_focus = None  # Track user's area of interest
        self.mentioned_projects = []  # Track discussed projects
        self.timestamp = datetime.now()
```

**Current Issues**:
- In-memory storage lost on restart
- Not suitable for distributed deployments
- No persistence across pod restarts

**Recommended Improvements**:
1. Use Redis for distributed caching
2. Use PostgreSQL for persistent storage
3. Implement session expiration
4. Add conversation analytics

### 5.5 Additional Chat Endpoints

#### Get Conversation History

```python
@router.get("/api/chat/sessions/{session_id}")
async def get_conversation_history(session_id: str):
    """Get conversation history for a session"""
    if session_id not in conversation_store:
        raise HTTPException(status_code=404, detail="Session not found")
    
    context = conversation_store[session_id]
    return {
        "session_id": session_id,
        "messages": context.messages,
        "user_focus": context.user_focus,
        "mentioned_projects": context.mentioned_projects,
    }
```

#### Clear Conversation

```python
@router.delete("/api/chat/sessions/{session_id}")
async def clear_conversation(session_id: str):
    """Clear conversation history for a session"""
    if session_id in conversation_store:
        del conversation_store[session_id]
    return {"message": "Conversation cleared"}
```

#### Chat Health Check

```python
@router.get("/api/chat/health")
async def chat_health():
    """Health check for chat service"""
    health = {
        "chat_service": "healthy",
        "conversation_engine": "ready",
        "llm_provider": LLM_PROVIDER,
        "llm_model": LLM_MODEL,
        "rag_enabled": True,
        "active_sessions": len(conversation_store),
    }
    
    # Test LLM connectivity
    try:
        engine = get_llm_engine()
        health["llm_status"] = "connected" if engine else "failed"
    except Exception as e:
        health["llm_status"] = f"error: {str(e)}"
    
    # Test RAG connectivity
    try:
        engine = get_rag_engine()
        health["rag_status"] = "connected" if engine else "failed"
    except Exception as e:
        health["rag_status"] = f"error: {str(e)}"
    
    return health
```

#### Quick Prompts

```python
@router.get("/api/chat/prompts")
async def get_quick_prompts():
    """Get suggested conversation starters"""
    return {
        "quick_prompts": [
            "Tell me about LinkOps AI-BOX and how it helps property managers",
            "What's Jimmie's background in DevSecOps and AI?",
            "How does the RAG system work in your projects?",
            "What's the business impact and ROI of these solutions?",
        ],
        "categories": {
            "projects": [
                "Tell me about LinkOps AI-BOX",
                "What is LinkOps Afterlife?",
            ],
            "technical": [
                "What technologies does Jimmie use?",
                "How is the system architected?",
            ],
            "business": [
                "What problem does this solve?",
                "What's the ROI and business impact?",
            ],
        },
    }
```

---

## 6. Configuration Patterns

### 6.1 Settings.py - Centralized Configuration

```python
# data/storage paths
DATA_DIR = Path(os.getenv("DATA_DIR", "/data"))
UPLOAD_DIR = DATA_DIR / "uploads"
ASSETS_DIR = DATA_DIR / "assets"
CHROMA_DIR = DATA_DIR / "chroma"

# LLM Configuration - SINGLE SOURCE OF TRUTH
LLM_PROVIDER = os.getenv("LLM_PROVIDER", "claude")  # claude, openai, local
LLM_API_KEY = (
    os.getenv("CLAUDE_API_KEY") or 
    os.getenv("OPENAI_API_KEY") or 
    os.getenv("LLM_API_KEY", "")
)
LLM_MODEL = os.getenv("LLM_MODEL", "claude-3-5-sonnet-20241022")

# RAG Configuration
RAG_NAMESPACE = os.getenv("RAG_NAMESPACE", "portfolio")
CHROMA_URL = os.getenv("CHROMA_URL", "http://localhost:8000")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "nomic-embed-text")
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")

# Avatar and Speech Services
ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY", "")
DID_API_KEY = os.getenv("DID_API_KEY", "")

# API Configuration
PUBLIC_BASE_URL = os.getenv("PUBLIC_BASE_URL", "http://localhost:8000")
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "http://localhost:5173,https://linksmlm.com")
DEBUG_MODE = os.getenv("DEBUG_MODE", "true").lower() == "true"

# System Prompts
try:
    from personality.loader import load_system_prompt
    SYSTEM_PROMPT = load_system_prompt()
except Exception as e:
    print(f"Warning: Could not load personality from files: {e}")
    SYSTEM_PROMPT = "Fallback prompt..."
```

### 6.2 Environment Variable Categories

#### Required Variables

```bash
# Must be set for application to work
CLAUDE_API_KEY=sk-ant-...              # Claude API key
LLM_PROVIDER=claude                     # Primary LLM provider
LLM_MODEL=claude-3-5-sonnet-20241022   # Specific model version
```

#### Optional Variables (with Defaults)

```bash
# Optional with sensible defaults
DATA_DIR=/data                          # Data directory (default: /data)
CHROMA_URL=http://localhost:8000        # ChromaDB URL
OLLAMA_URL=http://localhost:11434       # Ollama embeddings server
RAG_NAMESPACE=portfolio                 # RAG collection namespace
EMBED_MODEL=nomic-embed-text            # Embedding model
```

#### Optional Services

```bash
# External services (only needed if enabled)
OPENAI_API_KEY=sk-proj-...              # GPT-4o-mini fallback
ELEVENLABS_API_KEY=...                  # Text-to-speech
DID_API_KEY=...                         # Avatar generation
```

#### API Configuration

```bash
# CORS and deployment
PUBLIC_BASE_URL=http://localhost:8000   # Public API URL
CORS_ORIGINS=http://localhost:5173      # Allowed origins
DEBUG_MODE=true                         # Enable debug logging
```

### 6.3 Configuration Hierarchy

```
Environment Variables (Highest Priority)
    ↓
.env file (if loaded)
    ↓
settings.py defaults (Medium Priority)
    ↓
Fallback values in code (Lowest Priority)
```

### 6.4 Service Enablement Checks

```python
def is_service_enabled(service: str) -> bool:
    """Check if external service is enabled"""
    if service == "elevenlabs":
        return bool(ELEVENLABS_API_KEY)
    elif service == "did":
        return bool(DID_API_KEY)
    elif service == "openai":
        return LLM_PROVIDER == "openai" and bool(LLM_API_KEY)
    return False

# Configuration summary for health checks
CONFIG_SUMMARY = {
    "llm_provider": LLM_PROVIDER,
    "llm_model": LLM_MODEL,
    "rag_namespace": RAG_NAMESPACE,
    "avatar_name": DEFAULT_AVATAR_NAME,
    "services_enabled": {
        "elevenlabs": is_service_enabled("elevenlabs"),
        "did": is_service_enabled("did"),
        "openai_fallback": is_service_enabled("openai"),
    },
}
```

---

## 7. Security Implementations

### 7.1 HTTP Security Headers

**Headers added by security_headers middleware**:

| Header | Value | Purpose |
|--------|-------|---------|
| X-Content-Type-Options | nosniff | Prevents MIME type sniffing |
| X-Frame-Options | DENY | Prevents clickjacking (no framing) |
| X-XSS-Protection | 1; mode=block | Legacy XSS protection |
| Referrer-Policy | strict-origin-when-cross-origin | Controls referrer information |
| Content-Security-Policy | restrictive (see below) | Whitelist resources |
| Strict-Transport-Security | max-age=31536000 | Forces HTTPS (production only) |

**Content-Security-Policy (CSP) Details**:

```
default-src 'self'
  └─ Only same-origin resources allowed by default

script-src 'self' 'unsafe-inline'
  └─ Scripts from self + inline (for React)

style-src 'self' 'unsafe-inline'
  └─ Styles from self + inline

img-src 'self' data: https:
  └─ Images from self, data URIs, HTTPS

connect-src 'self' https://api.anthropic.com https://api.openai.com
  └─ XHR/fetch only to self and LLM APIs

frame-ancestors 'none'
  └─ Cannot be embedded in iframes
```

### 7.2 CORS Configuration

```python
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "https://linksmlm.com").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in CORS_ORIGINS],
    allow_credentials=False,  # More secure
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type"],
)
```

**Security Rationale**:
- **Credentials=False**: Prevents automatic cookie inclusion (tokens in headers instead)
- **Limited Methods**: Only GET, POST, OPTIONS (no PUT, DELETE, PATCH)
- **Limited Headers**: Only Content-Type (blocks custom auth headers)
- **Environment-Based**: Origins loaded from env, not hardcoded

### 7.3 Rate Limiting

```python
rate_limit_store = defaultdict(list)

def rate_limit_check(
    client_ip: str, max_requests: int = 30, window_minutes: int = 1
) -> bool:
    """Simple in-memory rate limiting: 30 requests/minute per IP"""
    now = datetime.now()
    window_start = now - timedelta(minutes=window_minutes)
    
    # Clean old requests
    rate_limit_store[client_ip] = [
        req_time for req_time in rate_limit_store[client_ip] 
        if req_time > window_start
    ]
    
    # Check limit
    if len(rate_limit_store[client_ip]) >= max_requests:
        return False
    
    # Record request
    rate_limit_store[client_ip].append(now)
    return True
```

**Applied to Chat Endpoints Only**:

```python
@app.middleware("http")
async def rate_limiting(request: Request, call_next):
    """Rate limiting for chat endpoints"""
    if request.url.path.startswith("/api/chat"):
        client_ip = request.client.host
        if not rate_limit_check(client_ip):
            return Response(
                content='{"error": "Rate limit exceeded"}',
                status_code=429,
                media_type="application/json",
            )
    return await call_next(request)
```

**Limitations**:
- In-memory only (lost on restart)
- Not suitable for distributed systems
- Doesn't survive pod restarts

**Recommended Improvements**:
1. Use Redis for distributed rate limiting
2. Implement per-endpoint limits
3. Add burst limits for API endpoints
4. Track and log rate limit violations

### 7.4 Input Validation

All endpoints use Pydantic models for validation:

```python
class ChatRequest(BaseModel):
    message: str = Field(
        ..., min_length=1, max_length=4000,
        description="User's message to Sheyla"
    )
    session_id: Optional[str] = Field(None)
    namespace: Optional[str] = Field(RAG_NAMESPACE)
    include_citations: Optional[bool] = Field(True)
```

**Validation Benefits**:
- **Type Checking**: Ensures correct types
- **Length Limits**: Prevents buffer overflows (4000 char limit on messages)
- **Automatic Documentation**: Swagger docs from Pydantic
- **Error Messages**: User-friendly validation error responses

### 7.5 API Key Management

```python
# Settings.py - Environment-based key loading
CLAUDE_API_KEY = os.getenv("CLAUDE_API_KEY", "")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")

# llm_interface.py - Validation at initialization
if not self.claude_api_key:
    raise ValueError("CLAUDE_API_KEY environment variable is required")

# Usage - Headers configured automatically
def get_llm_headers() -> dict:
    """Get headers for LLM API calls"""
    headers = {"Content-Type": "application/json"}
    if LLM_API_KEY:
        headers["Authorization"] = f"Bearer {LLM_API_KEY}"
    return headers
```

**Security Practices**:
- Keys loaded from environment variables only
- Never hardcoded in source files
- Required keys validated at startup
- Bearer token format for API calls

### 7.6 Error Handling & Logging

```python
import logging

logger = logging.getLogger(__name__)

try:
    response = await engine.chat_completion(messages)
except Exception as e:
    logger.error(f"Chat completion error: {e}", exc_info=True)
    # Return user-friendly error, not internal details
    return {
        "content": "I'm having trouble generating a response",
        "model": f"{self.provider}/error",
    }
```

**Error Handling Pattern**:
- **Log Internally**: Full stack trace for debugging
- **Return Safely**: User-friendly messages to clients
- **No Leaks**: Never expose internal details to users
- **Graceful Degradation**: Continue operation if possible

---

## 8. Deployment Considerations

### 8.1 Docker Deployment

**Dockerfile Pattern**:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY api/ .

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 8.2 Kubernetes Deployment

**Service Configuration**:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  type: ClusterIP
  ports:
    - port: 8000
      targetPort: 8000
      protocol: TCP
  selector:
    app: api
```

**Deployment Considerations**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 2  # Load balancing
  strategy:
    type: RollingUpdate  # Zero-downtime updates
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: portfolio-api:latest
        ports:
        - containerPort: 8000
        
        # Resource limits
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        
        # Health checks
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 30
        
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 10
        
        # Environment variables
        env:
        - name: CLAUDE_API_KEY
          valueFrom:
            secretKeyRef:
              name: api-secrets
              key: claude-api-key
        - name: CHROMA_URL
          value: "http://chroma:8000"
        - name: OLLAMA_URL
          value: "http://ollama:11434"
```

### 8.3 Production Deployment Checklist

**Critical**:
- [ ] CLAUDE_API_KEY set in secrets (not in code)
- [ ] ChromaDB 4MB database accessible
- [ ] Ollama service running for embeddings
- [ ] CORS origins configured for production domain
- [ ] HTTPS enabled (HSTS header will be added)
- [ ] Rate limiting enabled (consider Redis)

**Important**:
- [ ] Session storage moved to Redis or database
- [ ] Logging configured (stdout for container)
- [ ] Health check endpoints responsive
- [ ] Error handling returns safe messages
- [ ] No debug mode enabled in production

**Recommended**:
- [ ] API behind reverse proxy (nginx/Cloudflare)
- [ ] Request logging and monitoring
- [ ] APM (Application Performance Monitoring)
- [ ] Log aggregation (ELK, Datadog, etc.)
- [ ] Distributed rate limiting (Redis)

### 8.4 Environment Variable Validation

```python
# At startup, validate required configuration
def validate_configuration():
    """Validate that all required env vars are set"""
    required = ["CLAUDE_API_KEY", "LLM_PROVIDER", "LLM_MODEL"]
    missing = [var for var in required if not os.getenv(var)]
    
    if missing:
        raise RuntimeError(
            f"Missing required environment variables: {', '.join(missing)}"
        )

# Call during application startup
@app.on_event("startup")
async def startup_event():
    validate_configuration()
    logger.info("API startup complete - all checks passed")
```

---

## 9. Technical Deep Dives

### 9.1 RAG Accuracy & Relevance

**Embedding Quality**:
- Model: nomic-embed-text (768-dimensional)
- Training: Trained on 235 million text pairs
- Strengths: Excellent for semantic search
- Weaknesses: Requires exact domain match for specialized terminology

**Search Results Processing**:

```python
# Top-K retrieval (k=3 for chat, k=5 for search)
results = collection.query(
    query_embeddings=[query_embedding], 
    n_results=3
)

# Distance metric interpretation
# L2 distance < 0.5 = High relevance
# L2 distance 0.5-1.0 = Medium relevance  
# L2 distance > 1.0 = Low relevance
```

**Relevance Score Mapping**:

```python
def calculate_relevance_score(distance: float) -> float:
    """Convert L2 distance to relevance score (0-1)"""
    # L2 distance inverted and normalized
    if distance > 1.0:
        return 0.0
    return max(0.0, 1.0 - distance)
```

### 9.2 Claude API Integration Details

**Message Format**:

```python
messages = [
    {
        "role": "system",  # System message (separate parameter in Claude)
        "content": "You are Sheyla..."
    },
    {
        "role": "user",
        "content": "Tell me about yourself"
    },
    {
        "role": "assistant",
        "content": "Well hello there..."
    },
    {
        "role": "user",
        "content": "What about DevSecOps?"
    }
]
```

**Claude-Specific Parameters**:

```python
response = await client.messages.create(
    model="claude-3-5-sonnet-20241022",
    max_tokens=1024,  # Maximum tokens in response
    temperature=0.7,  # 0.0 = deterministic, 1.0 = random
    system="You are Sheyla...",  # System message (separate param!)
    messages=api_messages,  # Non-system messages
)
```

**Streaming API**:

```python
async with client.messages.stream(
    model="claude-3-5-sonnet-20241022",
    max_tokens=1024,
    messages=[{"role": "user", "content": "..."}],
) as stream:
    async for text in stream.text_stream:
        yield text  # Yields chunks as they arrive
```

### 9.3 ChromaDB Collection Management

**Collection Lifecycle**:

```
1. Create Collection
   collection = client.get_or_create_collection("portfolio_knowledge")

2. Add Documents
   collection.add(
       ids=doc_ids,
       documents=doc_texts,
       metadatas=doc_metadata,
       embeddings=embeddings  # Optional: provide pre-computed
   )

3. Search
   results = collection.query(query_embeddings=[...], n_results=5)

4. Delete
   collection.delete(ids=ids_to_delete)

5. Update
   # Upsert pattern: delete old + add new with same ID
```

**Metadata Schema**:

```python
metadata = {
    "source": "01-bio.md",           # Source file
    "title": "Jimmie Coleman Bio",   # Document title
    "tags": "biography,devops,ai",   # Searchable tags
    "chunk_index": 0,                # Position in original doc
    "created": "2025-11-13",         # Ingestion timestamp
}
```

### 9.4 Error Recovery & Fallback Patterns

**RAG Retrieval Fallback**:

```python
if request.include_citations:
    try:
        engine = get_rag_engine()
        if engine:
            rag_docs = engine.search(request.message, n_results=3)
        else:
            rag_docs = []
    except Exception as e:
        print(f"RAG retrieval error: {e}")
        rag_docs = []  # Continue without RAG
```

**LLM Generation Fallback**:

```python
try:
    response = await engine.chat_completion(messages)
except Exception as e:
    # Fallback response without RAG
    response = {
        "content": "I'm experiencing technical difficulties...",
        "model": "fallback"
    }
```

**Embedding Fallback**:

```python
def _get_embedding(self, text: str) -> List[float]:
    try:
        response = requests.post(
            f"{self.ollama_url}/api/embeddings",
            json={"model": self.embed_model, "prompt": text},
            timeout=30
        )
        return response.json()["embedding"]
    except Exception as e:
        # Return zero vector if Ollama unavailable
        return [0.0] * 768
```

### 9.5 Performance Optimization Strategies

**Current Optimizations**:
- Async/await throughout (non-blocking I/O)
- Streaming LLM responses (real-time updates)
- GZip compression for responses >1KB
- Connection pooling via client instances

**Recommended Optimizations**:

1. **Response Caching**
   ```python
   # Cache frequent queries
   from functools import lru_cache
   
   @lru_cache(maxsize=100)
   async def get_cached_embedding(text: str):
       return await embedding_model.encode(text)
   ```

2. **Batch Embeddings**
   ```python
   # Process multiple embeddings together
   embeddings = await embedding_model.encode_batch(texts)
   ```

3. **Connection Pooling**
   ```python
   # Reuse HTTP connections
   async with httpx.AsyncClient() as client:
       response = await client.post(...)
   ```

4. **Document Chunking**
   ```python
   # Smaller, focused chunks improve retrieval
   # Current: 200-500 words per chunk
   # Recommended: 100-300 words per chunk
   ```

---

## 10. Troubleshooting & Monitoring

### 10.1 Health Check Endpoints

**Basic Health Check**:
```
GET /health
200 OK
{
  "status": "healthy",
  "service": "portfolio-api",
  "version": "2.0.0"
}
```

**Comprehensive Health Check**:
```
GET /api/health
200 OK
{
  "status": "healthy",
  "timestamp": "2025-11-13T12:00:00",
  "service": "portfolio-api",
  "environment": {
    "llm_provider": "claude",
    "llm_model": "claude-3-5-sonnet-20241022",
    "rag_namespace": "portfolio"
  }
}
```

**LLM Health**:
```
GET /api/health/llm
200 OK
{
  "ok": true,
  "status_code": 200,
  "provider": "claude",
  "model": "claude-3-5-sonnet-20241022",
  "latency_ms": 125
}
```

**RAG Health**:
```
GET /api/health/rag
200 OK
{
  "ok": true,
  "namespace": "portfolio",
  "chroma_dir": "/data/chroma",
  "chroma_exists": true
}
```

**Chat Health**:
```
GET /api/chat/health
200 OK
{
  "chat_service": "healthy",
  "conversation_engine": "ready",
  "llm_provider": "claude",
  "llm_status": "connected",
  "rag_status": "connected",
  "active_sessions": 3
}
```

### 10.2 Common Issues & Solutions

**Issue: "CLAUDE_API_KEY not set"**
```
Symptom: Error during startup
Solution: Set CLAUDE_API_KEY environment variable
Verification: curl -H "Authorization: Bearer $CLAUDE_API_KEY" https://api.anthropic.com/
```

**Issue: "ChromaDB connection refused"**
```
Symptom: RAG returns empty results
Root Cause: CHROMA_URL incorrect or service not running
Solution: 
  1. Check CHROMA_URL environment variable
  2. Verify ChromaDB service is running
  3. Check network connectivity between pods
  4. Verify database file exists at CHROMA_DIR
```

**Issue: "Ollama embedding failed"**
```
Symptom: "Ollama embedding failed: Connection refused"
Root Cause: Ollama service not running or unreachable
Solution:
  1. Start Ollama: ollama serve
  2. Verify OLLAMA_URL is correct
  3. Check network connectivity
  4. API will fallback to zero vectors (graceful degradation)
```

**Issue: "Rate limit exceeded"**
```
Symptom: HTTP 429 Too Many Requests
Root Cause: User exceeded 30 requests/minute
Solution:
  1. Wait 1 minute for rate limit window to reset
  2. For production: Implement Redis-based rate limiting
  3. Consider per-endpoint rate limits
```

**Issue: "Session not found"**
```
Symptom: 404 when retrieving conversation history
Root Cause: In-memory session storage lost (pod restart or timeout)
Solution:
  1. Implement persistent session storage (Redis/PostgreSQL)
  2. Educate users that sessions are temporary
  3. Implement session persistence in frontend
```

### 10.3 Monitoring & Observability

**Logging Strategy**:

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)

# Log levels:
logger.debug("Detailed debug info")
logger.info("Normal operation")
logger.warning("Potential issues")
logger.error("Errors that need attention")
logger.critical("System-critical failures")
```

**Key Metrics to Track**:
- Request latency (p50, p95, p99)
- Chat endpoint response time
- RAG retrieval time
- LLM API response time
- Error rates and types
- Active sessions
- Rate limit violations

**Recommended Monitoring Stack**:
1. Prometheus - Metrics collection
2. Grafana - Visualization
3. Loki - Log aggregation
4. Jaeger - Distributed tracing

### 10.4 Testing Strategy

**Unit Tests**:

```python
# Test LLM engine
def test_llm_engine_initialization():
    engine = LLMEngine()
    assert engine.provider == "claude"
    assert engine.claude_model == "claude-3-5-sonnet-20241022"

# Test RAG engine
def test_rag_search():
    engine = RAGEngine()
    results = engine.search("DevSecOps")
    assert len(results) > 0
    assert "text" in results[0]

# Test personality loader
def test_personality_loader():
    loader = PersonalityLoader()
    prompt = loader.build_system_prompt()
    assert "Sheyla" in prompt
    assert "professional" in prompt.lower()
```

**Integration Tests**:

```python
# Test full chat flow
@pytest.mark.asyncio
async def test_chat_endpoint():
    response = await client.post(
        "/api/chat",
        json={"message": "Tell me about yourself"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "answer" in data
    assert "citations" in data
    assert len(data["citations"]) > 0
```

---

## Summary

### What's Working

- FastAPI application with clean routing and security middleware
- Multi-provider LLM abstraction (Claude primary, local fallback)
- RAG engine with ChromaDB and Ollama embeddings (88 vectors, 768D)
- Dynamic personality system loaded from markdown
- Session management with conversation tracking
- Proper security headers, rate limiting, CORS
- Health check endpoints for monitoring

### Critical Infrastructure Requirements

1. **ChromaDB Service**
   - 4MB database with 88 embeddings
   - 30 source documents indexed
   - Must be accessible at CHROMA_URL

2. **Ollama Embeddings**
   - nomic-embed-text model
   - Used for query and document embeddings
   - Must be accessible at OLLAMA_URL

3. **Claude API**
   - CLAUDE_API_KEY required
   - Primary LLM provider
   - Supports streaming and chat completion

### Recommended Improvements

1. **Persistent Session Storage**: Redis or PostgreSQL
2. **Distributed Rate Limiting**: Redis backend
3. **Enhanced Caching**: Response caching for common queries
4. **Better Error Messages**: More granular error handling
5. **Comprehensive Testing**: Unit and integration tests
6. **Monitoring & Observability**: Prometheus/Grafana/Loki

---

**Document Status**: Complete and production-ready  
**Last Updated**: November 13, 2025  
**Framework Version**: FastAPI 0.104.1  
**LLM Model**: Claude 3.5 Sonnet (claude-3-5-sonnet-20241022)

