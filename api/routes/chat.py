"""
Chat API Routes - Sheyla's Conversational Interface
Handles all chat interactions with personality and context awareness
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import List, Optional
import uuid

# Import our clean modules
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from backend.settings import (
    LLM_PROVIDER,
    LLM_MODEL,
    SYSTEM_PROMPT,
    RAG_NAMESPACE,
)
from backend.engines.rag_engine import RAGEngine
from backend.engines.llm_interface import LLMEngine

# Import Sheyla's conversation engine
# import sys
# from pathlib import Path
#
# sys.path.append(str(Path(__file__).parent.parent.parent))
# from chat.engines.conversation_engine import ConversationEngine, ConversationContext

# Temporary placeholders until conversation engine is available
class ConversationContext:
    def __init__(self, session_id=None, messages=None, **kwargs):
        self.session_id = session_id
        self.messages = messages or []
        self.user_focus = kwargs.get('user_focus', [])
        self.mentioned_projects = kwargs.get('mentioned_projects', [])

class ConversationEngine:
    def __init__(self):
        pass

    def generate_response(self, question=None, context=None, rag_results=None):
        """Placeholder that raises exception to trigger fallback LLM response"""
        raise NotImplementedError("Using fallback LLM response")

router = APIRouter()


# Request/Response Models
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


class Citation(BaseModel):
    text: str = Field(..., description="Cited text from knowledge base")
    source: str = Field(..., description="Source document or section")
    relevance_score: float = Field(..., description="Relevance score (0.0-1.0)")


class ChatResponse(BaseModel):
    answer: str = Field(..., description="Sheyla's response")
    citations: List[Citation] = Field(
        default=[], description="Knowledge base citations"
    )
    model: str = Field(..., description="LLM model used for response")
    session_id: str = Field(..., description="Conversation session ID")
    follow_up_suggestions: List[str] = Field(
        default=[], description="Suggested follow-up questions"
    )
    avatar_info: dict = Field(default={}, description="Avatar metadata")


# Initialize engines (lazy load to avoid startup crashes)
rag_engine = None
llm_engine = None
conversation_engine = ConversationEngine()

def get_rag_engine():
    global rag_engine
    if rag_engine is None:
        try:
            rag_engine = RAGEngine()
        except Exception as e:
            print(f"Warning: RAG engine initialization failed: {e}")
            rag_engine = None
    return rag_engine

def get_llm_engine():
    global llm_engine
    if llm_engine is None:
        try:
            llm_engine = LLMEngine()
        except Exception as e:
            print(f"Warning: LLM engine initialization failed: {e}")
            llm_engine = None
    return llm_engine

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
                session_id=session_id, messages=[]
            )
        context = conversation_store[session_id]

        # Step 1: Retrieve relevant context from RAG
        rag_results = []
        citations = []

        if request.include_citations:
            try:
                # Query knowledge base for relevant information
                engine = get_rag_engine()
                if engine:
                    rag_docs = engine.search(request.message, n_results=3)
                else:
                    rag_docs = []

                # rag_docs is a list of dicts with 'text', 'metadata', 'score'
                rag_results = [doc.get("text", "") for doc in rag_docs]

                # Create citations
                citations = [
                    Citation(
                        text=(
                            doc.get("text", "")[:200] + "..." if len(doc.get("text", "")) > 200 else doc.get("text", "")
                        ),
                        source=doc.get("metadata", {}).get("source", "Knowledge Base"),
                        relevance_score=1.0 - doc.get("score", 0.5),  # ChromaDB uses distance, smaller is better
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
                question=request.message, context=context, rag_results=rag_results
            )
        except Exception as e:
            print(f"Conversation engine error: {e}")
            # Fallback to direct LLM call
            response_text = await _fallback_llm_response(request.message, rag_results)

        # Step 3: Validate response for hallucinations and grounding
        # TODO: Re-enable validation when validation module is available
        # context_sources = [citation.source for citation in citations]
        # try:
        #     validation_result = await validate_response(
        #         ValidationRequest(
        #             response_text=response_text,
        #             question=request.message,
        #             context_sources=context_sources,
        #         )
        #     )
        #
        #     # If validation fails critically, use a safer fallback response
        #     if (
        #         not validation_result.is_valid
        #         and validation_result.confidence_score < 0.3
        #     ):
        #         response_text = (
        #             "I need to stay grounded in the information I have about Jimmie's work. "
        #             "Could you ask me something more specific about LinkOps AI-BOX, "
        #             "his DevSecOps experience, or the ZRS Management project?"
        #         )
        #
        # except Exception as e:
        #     print(f"Validation error: {e}")
        #     # Continue without validation if it fails

        # Step 4: Get follow-up suggestions
        # TODO: Implement get_follow_up_suggestions in ConversationEngine
        follow_up_suggestions = []

        # Step 5: Prepare response
        return ChatResponse(
            answer=response_text,
            citations=citations,
            model=f"{LLM_PROVIDER}/{LLM_MODEL}",
            session_id=session_id,
            follow_up_suggestions=follow_up_suggestions,
            avatar_info={
                "name": "Sheyla",
                "locale": "en-US",
                "description": "Warm and welcoming AI assistant with natural southern charm",
            },
        )

    except Exception as e:
        print(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail=f"Chat processing failed: {str(e)}")


async def _fallback_llm_response(message: str, rag_results: List[str]) -> str:
    """
    Fallback LLM response when conversation engine fails
    """
    try:
        # Get LLM engine
        engine = get_llm_engine()
        if not engine:
            return "I'm experiencing some technical difficulties with my AI engine. Please try again in a moment."

        # Prepare context with RAG results
        context_text = ""
        if rag_results:
            context_text = (
                "\n\nRelevant context from knowledge base:\n"
                + "\n".join(rag_results[:2])
            )

        # Prepare messages for LLM
        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"{message}{context_text}"},
        ]

        # Call LLM API
        response = await engine.chat_completion(messages)
        return response.get(
            "content",
            "I apologize, but I'm having trouble generating a response right now.",
        )

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
        "mentioned_projects": context.mentioned_projects,
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
        "active_sessions": len(conversation_store),
    }

    # Test LLM connectivity
    try:
        engine = get_llm_engine()
        if engine:
            health["llm_status"] = "connected"
        else:
            health["llm_status"] = "initialization failed"
    except Exception as e:
        health["llm_status"] = f"error: {str(e)}"

    # Test RAG connectivity
    try:
        engine = get_rag_engine()
        if engine:
            health["rag_status"] = "connected"
        else:
            health["rag_status"] = "initialization failed"
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
            "Can you walk me through a technical interview with Jimmie?",
        ],
        "categories": {
            "projects": [
                "Tell me about LinkOps AI-BOX",
                "What is LinkOps Afterlife?",
                "How do these projects work together?",
            ],
            "technical": [
                "What technologies does Jimmie use?",
                "How is the system architected?",
                "What about scalability and performance?",
            ],
            "business": [
                "What problem does this solve?",
                "What's the ROI and business impact?",
                "Who are the target customers?",
            ],
        },
    }
