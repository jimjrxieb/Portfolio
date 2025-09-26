"""
Jade-Brain API
Main API endpoint for chatbox integration
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, Optional
import sys
from pathlib import Path
import logging

# Add engines to path
sys.path.append(str(Path(__file__).parent.parent / "engines"))
from response_generator import get_response_generator

logger = logging.getLogger(__name__)

# Pydantic models
class ChatRequest(BaseModel):
    message: str
    context_type: Optional[str] = "general"  # general, technical, business
    user_id: Optional[str] = None

class ChatResponse(BaseModel):
    response: str
    context_used: bool
    rag_results: int
    model_used: str
    response_time_ms: Optional[int] = None
    status: str

class SystemStatus(BaseModel):
    jade_brain_status: str
    llm_available: bool
    rag_available: bool
    document_count: int
    model: str

# Initialize FastAPI app
app = FastAPI(
    title="Jade-Brain API",
    description="AI Assistant for Jimmie Coleman's Portfolio",
    version="1.0.0"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure based on your needs
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize response generator
try:
    response_gen = get_response_generator()
    logger.info("Jade-Brain initialized successfully")
except Exception as e:
    logger.error(f"Failed to initialize Jade-Brain: {e}")
    response_gen = None

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "Jade-Brain API",
        "version": "1.0.0",
        "status": "active" if response_gen else "error"
    }

@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """Main chat endpoint for questions about Jimmie"""
    if not response_gen:
        raise HTTPException(status_code=503, detail="Jade-Brain not available")

    try:
        import time
        start_time = time.time()

        # Generate response
        result = response_gen.generate_response(request.message)

        # Calculate response time
        response_time = int((time.time() - start_time) * 1000)

        return ChatResponse(
            response=result["response"],
            context_used=result["context_used"],
            rag_results=result["rag_results"],
            model_used=result["model_used"],
            response_time_ms=response_time,
            status=result["status"]
        )

    except Exception as e:
        logger.error(f"Chat request failed: {e}")
        raise HTTPException(status_code=500, detail=f"Chat processing error: {str(e)}")

@app.get("/status", response_model=SystemStatus)
async def get_status():
    """Get system status"""
    if not response_gen:
        return SystemStatus(
            jade_brain_status="error",
            llm_available=False,
            rag_available=False,
            document_count=0,
            model="none"
        )

    try:
        status = response_gen.get_status()
        rag_status = response_gen.rag.get_status()

        return SystemStatus(
            jade_brain_status="active",
            llm_available=status["llm_configured"],
            rag_available=status["rag_available"],
            document_count=rag_status["document_count"],
            model=status["model"]
        )

    except Exception as e:
        logger.error(f"Status check failed: {e}")
        return SystemStatus(
            jade_brain_status="error",
            llm_available=False,
            rag_available=False,
            document_count=0,
            model="error"
        )

@app.get("/health")
async def health_check():
    """Simple health check"""
    return {"status": "healthy", "service": "jade-brain"}

# If running directly
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)