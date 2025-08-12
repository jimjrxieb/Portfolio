from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import os
import logging

from engines.llm_engine import get_llm_engine
from engines.rag_engine import get_rag_engine, format_prompt
from engines.avatar_engine import get_avatar_engine
from engines.speech_engine import get_speech_engine

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="James Portfolio API", version="1.0.0")

# CORS configuration
origins = os.getenv("CORS_ALLOW_ORIGINS", "*").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatRequest(BaseModel):
    message: str
    use_rag: bool = True

class AvatarRequest(BaseModel):
    script: str
    image_path: Optional[str] = None

@app.get("/")
def read_root():
    return {"message": "James Portfolio API", "version": "1.0.0"}

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "engines": {
            "llm": "ready",
            "rag": "ready", 
            "avatar": get_avatar_engine().get_status(),
            "speech": get_speech_engine().get_status()
        }
    }

@app.post("/chat")
async def chat(request: ChatRequest):
    try:
        llm_engine = get_llm_engine()
        
        if request.use_rag:
            rag_engine = get_rag_engine()
            contexts = rag_engine.search(request.message, n_results=3)
            prompt = format_prompt(request.message, contexts)
        else:
            prompt = request.message
        
        async def generate():
            async for chunk in llm_engine.generate(prompt, max_length=512):
                yield f"data: {chunk}\n\n"
            yield "data: [DONE]\n\n"
        
        return StreamingResponse(generate(), media_type="text/plain")
        
    except Exception as e:
        logger.error(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/avatar")
def generate_avatar(request: AvatarRequest):
    try:
        avatar_engine = get_avatar_engine()
        video_data = avatar_engine.generate_video(request.script, request.image_path)
        return {"video_data": video_data}
    except Exception as e:
        logger.error(f"Avatar generation error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/speech")
def text_to_speech(request: dict):
    try:
        text = request.get("text", "")
        if not text:
            raise HTTPException(status_code=400, detail="Text is required")
        
        speech_engine = get_speech_engine()
        audio_data = speech_engine.text_to_speech(text)
        return {"audio_data": audio_data}
    except Exception as e:
        logger.error(f"Speech generation error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/build-info")
def build_info():
    return {
        "version": "1.0.0",
        "build_time": "2025-01-01T00:00:00Z",
        "git_commit": "unknown",
        "environment": os.getenv("ENV", "development")
    }

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("API_PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)