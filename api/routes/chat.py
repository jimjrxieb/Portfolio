"""
Chat API Routes - Sheyla's Conversational Interface
Handles all chat interactions with personality and context awareness
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import List, Optional
import uuid
import httpx
import json

# Import our clean modules
from settings import (
    LLM_PROVIDER, LLM_API_BASE, LLM_MODEL, LLM_API_KEY,
    SHEYLA_SYSTEM_PROMPT, RAG_NAMESPACE, get_llm_headers
)
from engines.rag_engine import RAGEngine
from engines.llm_engine import LLMEngine

# Import Sheyla's conversation engine
import sys
from pathlib import Path
sys.path.append(str(Path(__file__).parent.parent.parent))
from chat.engines.conversation_engine import ConversationEngine, ConversationContext

router = APIRouter()

# Request/Response Models
class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4000, description="User's message to Sheyla")
    session_id: Optional[str] = Field(None, description="Conversation session ID")
    namespace: Optional[str] = Field(RAG_NAMESPACE, description="RAG knowledge namespace")
    include_citations: Optional[bool] = Field(True, description="Include source citations")

class Citation(BaseModel):
    text: str = Field(..., description="Cited text from knowledge base")
    source: str = Field(..., description="Source document or section")
    relevance_score: float = Field(..., description="Relevance score (0.0-1.0)")

class ChatResponse(BaseModel):
    answer: str = Field(..., description="Sheyla's response")
    citations: List[Citation] = Field(default=[], description="Knowledge base citations")
    model: str = Field(..., description="LLM model used for response")
    session_id: str = Field(..., description="Conversation session ID") 
    follow_up_suggestions: List[str] = Field(default=[], description="Suggested follow-up questions")
    avatar_info: dict = Field(default={}, description="Avatar metadata")

# Initialize engines
rag_engine = RAGEngine()
llm_engine = LLMEngine()
conversation_engine = ConversationEngine()

# Store conversation contexts (in production, use Redis or database)
conversation_store = {}

@router.post("/chat", response_model=ChatResponse)
async def chat_with_sheyla(request: ChatRequest):
    """
    Main chat endpoint - handles conversation with Sheyla avatar
    Combines RAG retrieval, personality, and LLM generation
    """
    try:
        # Get or create conversation context
        session_id = request.session_id or str(uuid.uuid4())
        if session_id not in conversation_store:
            conversation_store[session_id] = ConversationContext(
                session_id=session_id,
                messages=[]
            )
        context = conversation_store[session_id]
        
        # Step 1: Retrieve relevant context from RAG
        rag_results = []
        citations = []
        
        if request.include_citations:
            try:
                # Query knowledge base for relevant information
                rag_docs = rag_engine.search(request.message, k=3, namespace=request.namespace)
                rag_results = [doc.text for doc in rag_docs]
                
                # Create citations
                citations = [
                    Citation(
                        text=doc.text[:200] + "..." if len(doc.text) > 200 else doc.text,
                        source=getattr(doc, 'source', 'Knowledge Base'),
                        relevance_score=getattr(doc, 'score', 0.8)
                    )
                    for doc in rag_docs
                ]
            except Exception as e:
                print(f"RAG retrieval error: {e}")
                # Continue without RAG if it fails
        
        # Step 2: Generate response using Sheyla's conversation engine
        try:
            # Use conversation engine for personality and context
            response_text = conversation_engine.generate_response(
                question=request.message,
                context=context,
                rag_results=rag_results
            )
        except Exception as e:
            print(f"Conversation engine error: {e}")
            # Fallback to direct LLM call
            response_text = await _fallback_llm_response(request.message, rag_results)
        
        # Step 3: Get follow-up suggestions
        follow_up_suggestions = conversation_engine.get_follow_up_suggestions(context)
        
        # Step 4: Prepare response
        return ChatResponse(
            answer=response_text,
            citations=citations,
            model=f"{LLM_PROVIDER}/{LLM_MODEL}",
            session_id=session_id,
            follow_up_suggestions=follow_up_suggestions,
            avatar_info={
                "name": "Sheyla",
                "locale": "en-IN", 
                "description": "Professional Indian lady with warm, simple voice"
            }
        )
        
    except Exception as e:
        print(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail=f"Chat processing failed: {str(e)}")

async def _fallback_llm_response(message: str, rag_results: List[str]) -> str:
    """
    Fallback LLM response when conversation engine fails
    """
    try:
        # Prepare context with RAG results
        context_text = ""
        if rag_results:
            context_text = f"\\n\\nRelevant context from knowledge base:\\n" + "\\n".join(rag_results[:2])
        
        # Prepare messages for LLM
        messages = [
            {"role": "system", "content": SHEYLA_SYSTEM_PROMPT},
            {"role": "user", "content": f"{message}{context_text}"}
        ]
        
        # Call LLM API
        response = await llm_engine.chat_completion(messages)
        return response.get("content", "I apologize, but I'm having trouble generating a response right now.")
        
    except Exception as e:
        print(f"Fallback LLM error: {e}")
        return "I'm experiencing some technical difficulties. Please try again in a moment."

@router.get("/chat/sessions/{session_id}")
async def get_conversation_history(session_id: str):
    """Get conversation history for a session"""
    if session_id not in conversation_store:
        raise HTTPException(status_code=404, detail="Session not found")
    
    context = conversation_store[session_id]
    return {
        "session_id": session_id,
        "messages": context.messages,
        "user_focus": context.user_focus,
        "mentioned_projects": context.mentioned_projects
    }

@router.delete("/chat/sessions/{session_id}")
async def clear_conversation(session_id: str):
    """Clear conversation history for a session"""
    if session_id in conversation_store:
        del conversation_store[session_id]
    return {"message": "Conversation cleared"}

@router.get("/chat/health")
async def chat_health():
    """Health check for chat service"""
    health = {
        "chat_service": "healthy",
        "conversation_engine": "ready",
        "llm_provider": LLM_PROVIDER,
        "llm_model": LLM_MODEL,
        "rag_enabled": True,
        "active_sessions": len(conversation_store)
    }
    
    # Test LLM connectivity
    try:
        test_response = await llm_engine.health_check()
        health["llm_status"] = "connected"
    except Exception as e:
        health["llm_status"] = f"error: {str(e)}"
    
    # Test RAG connectivity  
    try:
        rag_engine.health_check()
        health["rag_status"] = "connected"
    except Exception as e:
        health["rag_status"] = f"error: {str(e)}"
    
    return health

@router.get("/chat/prompts")
async def get_quick_prompts():
    """Get suggested conversation starters"""
    return {
        "quick_prompts": [
            "Tell me about LinkOps AI-BOX and how it helps property managers",
            "What's Jimmie's background in DevSecOps and AI?",
            "How does the RAG system work in your projects?",
            "What's the business impact and ROI of these solutions?",
            "Can you walk me through a technical interview with Jimmie?"
        ],
        "categories": {
            "projects": [
                "Tell me about LinkOps AI-BOX",
                "What is LinkOps Afterlife?",
                "How do these projects work together?"
            ],
            "technical": [
                "What technologies does Jimmie use?",
                "How is the system architected?",
                "What about scalability and performance?"
            ],
            "business": [
                "What problem does this solve?",
                "What's the ROI and business impact?",
                "Who are the target customers?"
            ]
        }
    }