"""
Gojo 3D Avatar Creation Service
Creates and manages 3D Gojo avatar interactions with TTS and lip-sync
"""

from fastapi import FastAPI, HTTPException, UploadFile, File, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import Optional, List, Dict
import os
import json
from datetime import datetime
import openai
from tts_service_mock import get_tts_service
import asyncio
import chromadb
from chromadb.config import Settings

app = FastAPI(
    title="Gojo 3D Avatar Service",
    description="3D AI-powered avatar with TTS and lip-sync featuring Gojo character",
    version="2.0.0",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# OpenAI Configuration
openai.api_key = os.getenv("GPT_API_KEY")
GPT_MODEL = os.getenv("GPT_MODEL", "gpt-4o-mini")

# Initialize TTS Service (real or mock)
tts_service = get_tts_service()

# Initialize ChromaDB RAG client
try:
    chroma_client = chromadb.PersistentClient(
        path="../data/chroma", settings=Settings(allow_reset=True)
    )
    # Try to find the portfolio collection
    collections = chroma_client.list_collections()
    collection = None
    for col in collections:
        if "portfolio" in col.name and col.count() > 0:
            collection = col
            break

    if not collection:
        raise Exception("No portfolio collection found")
    print("✅ ChromaDB RAG system connected successfully")
except Exception as e:
    print(f"⚠️ ChromaDB not available: {e}")
    chroma_client = None
    collection = None

# Mount static files for avatar assets
app.mount("/avatars", StaticFiles(directory="avatars"), name="avatars")


# Gojo Character Configuration
# RAG Query Function
def query_rag_knowledge(question: str, max_results: int = 3) -> str:
    """Query the RAG system for relevant knowledge about Jimmie Coleman"""
    if not collection:
        return ""

    try:
        results = collection.query(
            query_texts=[question],
            n_results=max_results,
            include=["documents", "metadatas"],
        )

        if results and results["documents"] and results["documents"][0]:
            # Combine the relevant documents
            context_docs = results["documents"][0]
            return "\n\n".join(context_docs)
        return ""
    except Exception as e:
        print(f"RAG query error: {e}")
        return ""


GOJO_PERSONALITY = """
You are Gojo, a professional AI avatar representing Jimmie Coleman's portfolio.

APPEARANCE: Professional male with striking white hair and crystal blue eyes, confident and engaging presence.

PERSONALITY:
- Confident and technically excellent
- Passionate about innovative DevOps and AI/ML solutions
- Adapts technical depth based on audience (recruiters vs engineers)
- Professional but approachable

KEY EXPERTISE TO DISCUSS:
1. DevSecOps Excellence:
   - Advanced CI/CD pipeline architecture
   - Container orchestration with Kubernetes
   - Security-first development practices
   - Infrastructure as Code (Terraform, Ansible)

2. AI/ML Implementation:
   - RAG (Retrieval-Augmented Generation) systems
   - LLM integration and optimization
   - Machine learning pipeline development
   - Vector databases and embeddings

3. Portfolio Platform Architecture:
   - Microservices design patterns
   - Docker containerization
   - Real-time avatar systems
   - Full-stack development

SPEAKING STYLE:
- Clear, confident explanations
- Use specific technical examples
- Focus on business impact and ROI
- Mention measurable achievements
- Professional tone with enthusiasm for technology

Always provide concrete examples from Jimmie's experience and emphasize the practical, production-ready nature of his work.
"""


class ChatRequest(BaseModel):
    message: str
    context: Optional[str] = None
    audience_type: Optional[str] = "general"  # general, recruiter, technical


class ChatResponse(BaseModel):
    response: str
    avatar_state: str
    timestamp: datetime


class AvatarStatus(BaseModel):
    status: str
    character: str
    description: str
    capabilities: List[str]


class TTSRequest(BaseModel):
    text: str
    voice: Optional[str] = "en-US-DavisNeural"
    include_visemes: Optional[bool] = True


class TTSResponse(BaseModel):
    audio_base64: str
    visemes: List[Dict]
    duration_ms: float
    voice: str
    timestamp: datetime


class Avatar3DResponse(BaseModel):
    avatar_url: str
    character: str
    animations: List[str]
    blendshapes: List[str]


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "gojo-avatar-creation",
        "character": "Gojo",
        "model": GPT_MODEL,
        "timestamp": datetime.now(),
    }


@app.get("/status", response_model=AvatarStatus)
async def get_avatar_status():
    """Get current avatar status and capabilities"""
    return AvatarStatus(
        status="active",
        character="Gojo",
        description="Professional male with white hair and crystal blue eyes",
        capabilities=[
            "Technical interview responses",
            "DevOps expertise explanation",
            "AI/ML project discussions",
            "Portfolio platform demonstration",
            "Recruiter-friendly summaries",
        ],
    )


@app.post("/chat", response_model=ChatResponse)
async def chat_with_gojo(request: ChatRequest):
    """Chat with Gojo avatar about Jimmie's experience"""

    # Always use RAG if available, regardless of OpenAI API key
    rag_context = query_rag_knowledge(request.message)

    if not openai.api_key:
        # Use RAG-enhanced fallback responses when API key is not configured
        if rag_context:
            # If we have RAG context, use it to generate a response
            context_preview = (
                rag_context[:500] + "..." if len(rag_context) > 500 else rag_context
            )

            # Extract key information from RAG context for smarter responses
            if "linkops" in rag_context.lower() or "ai-box" in rag_context.lower():
                response_text = f"Based on Jimmie's portfolio: {context_preview}"
            elif "devops" in rag_context.lower() or "kubernetes" in rag_context.lower():
                response_text = (
                    f"Regarding Jimmie's DevSecOps expertise: {context_preview}"
                )
            elif (
                "technologies" in request.message.lower()
                or "tools" in request.message.lower()
            ):
                response_text = f"Jimmie's technical stack includes: {context_preview}"
            else:
                response_text = f"From Jimmie's experience: {context_preview}"
        else:
            # Basic fallback if no RAG context
            response_text = "Hello! I'm Gojo, Jimmie Coleman's AI portfolio assistant. I can tell you about his DevSecOps expertise, AI/ML projects like LinkOps AI-BOX, or his technical architecture experience. What would you like to know?"

        return ChatResponse(
            response=response_text, avatar_state="speaking", timestamp=datetime.now()
        )

    try:
        # Customize system prompt based on audience
        audience_context = ""
        if request.audience_type == "recruiter":
            audience_context = "\nAUDIENCE: You're speaking to a recruiter or hiring manager. Focus on business impact, leadership, and measurable results. Keep technical details accessible."
        elif request.audience_type == "technical":
            audience_context = "\nAUDIENCE: You're speaking to a technical interviewer or engineer. Provide detailed technical explanations, architecture decisions, and implementation specifics."

        system_prompt = GOJO_PERSONALITY + audience_context

        if request.context:
            system_prompt += f"\nADDITIONAL CONTEXT: {request.context}"

        # Add RAG context if available
        if rag_context:
            system_prompt += f"\nRELEVANT PORTFOLIO KNOWLEDGE:\n{rag_context}\n\nUse this knowledge to provide accurate, detailed responses about Jimmie's experience."

        # Call OpenAI API
        response = openai.chat.completions.create(
            model=GPT_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": request.message},
            ],
            max_tokens=500,
            temperature=0.7,
        )

        avatar_response = response.choices[0].message.content

        return ChatResponse(
            response=avatar_response, avatar_state="speaking", timestamp=datetime.now()
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Avatar chat failed: {str(e)}")


@app.get("/introduction")
async def get_introduction():
    """Get Gojo's standard introduction about Jimmie"""

    intro_prompt = """
    Provide a professional 2-3 sentence introduction about Jimmie Coleman that highlights:
    1. His expertise in DevSecOps and AI/ML
    2. The innovative portfolio platform he built
    3. His focus on practical, production-ready solutions
    
    Keep it engaging and suitable for both recruiters and technical audiences.
    """

    try:
        response = openai.chat.completions.create(
            model=GPT_MODEL,
            messages=[
                {"role": "system", "content": GOJO_PERSONALITY},
                {"role": "user", "content": intro_prompt},
            ],
            max_tokens=200,
            temperature=0.7,
        )

        return {
            "introduction": response.choices[0].message.content,
            "character": "Gojo",
            "timestamp": datetime.now(),
        }

    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Introduction generation failed: {str(e)}"
        )


@app.get("/projects")
async def get_projects_summary():
    """Get summary of key projects to discuss"""
    return {
        "projects": [
            {
                "name": "Portfolio Platform",
                "description": "AI-powered microservices platform with avatar interactions",
                "technologies": [
                    "FastAPI",
                    "React",
                    "Docker",
                    "ChromaDB",
                    "GPT-4o-mini",
                ],
                "highlights": [
                    "Microservices architecture",
                    "Real-time avatar",
                    "RAG pipeline",
                ],
            },
            {
                "name": "DevSecOps Pipeline",
                "description": "Automated CI/CD with security scanning and deployment",
                "technologies": ["GitHub Actions", "Docker", "Kubernetes", "Terraform"],
                "highlights": [
                    "Security-first",
                    "Automated deployment",
                    "Infrastructure as Code",
                ],
            },
            {
                "name": "AI/ML Systems",
                "description": "Production-ready machine learning and LLM integration",
                "technologies": ["Python", "Jupyter", "Vector Databases", "OpenAI API"],
                "highlights": [
                    "RAG implementation",
                    "LLM optimization",
                    "Production deployment",
                ],
            },
        ],
        "timestamp": datetime.now(),
    }


@app.post("/tts", response_model=TTSResponse)
async def text_to_speech_with_visemes(request: TTSRequest):
    """Convert text to speech with viseme data for 3D avatar lip-sync"""

    try:
        # Set voice if different from default
        if request.voice != tts_service.voice_name:
            tts_service.set_voice(request.voice)

        # Generate speech with visemes
        result = await tts_service.synthesize_with_visemes(request.text)

        return TTSResponse(
            audio_base64=result["audio_base64"],
            visemes=result["visemes"],
            duration_ms=result["duration_ms"],
            voice=result["voice"],
            timestamp=datetime.fromisoformat(result["timestamp"]),
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"TTS synthesis failed: {str(e)}")


@app.get("/tts/voices")
async def get_available_voices():
    """Get list of available TTS voices for Gojo"""
    try:
        voices = await tts_service.get_available_voices()
        return {
            "voices": voices,
            "current_voice": tts_service.voice_name,
            "timestamp": datetime.now(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get voices: {str(e)}")


@app.get("/avatar/3d", response_model=Avatar3DResponse)
async def get_3d_avatar():
    """Get 3D Gojo avatar configuration and assets"""
    return Avatar3DResponse(
        avatar_url="/avatars/gojo.vrm",  # VRM avatar file
        character="Gojo",
        animations=[
            "idle_breathe",
            "idle_shift_weight",
            "gesture_nod",
            "gesture_point",
            "gesture_explain",
            "blink_random",
        ],
        blendshapes=[
            "A",
            "I",
            "U",
            "E",
            "O",  # Vowel shapes for lip-sync
            "jawOpen",
            "jawLeft",
            "jawRight",
            "eyeBlinkLeft",
            "eyeBlinkRight",
            "eyeLookUp",
            "eyeLookDown",
            "eyeLookLeft",
            "eyeLookRight",
        ],
    )


@app.post("/chat/speak", response_model=Dict)
async def chat_and_speak(request: ChatRequest):
    """Combined chat and TTS generation for seamless avatar interaction"""

    if not openai.api_key:
        raise HTTPException(status_code=500, detail="OpenAI API key not configured")

    try:
        # First get the chat response
        audience_context = ""
        if request.audience_type == "recruiter":
            audience_context = "\nAUDIENCE: You're speaking to a recruiter or hiring manager. Focus on business impact, leadership, and measurable results. Keep technical details accessible."
        elif request.audience_type == "technical":
            audience_context = "\nAUDIENCE: You're speaking to a technical interviewer or engineer. Provide detailed technical explanations, architecture decisions, and implementation specifics."

        system_prompt = GOJO_PERSONALITY + audience_context

        if request.context:
            system_prompt += f"\nADDITIONAL CONTEXT: {request.context}"

        # Call OpenAI API
        response = openai.chat.completions.create(
            model=GPT_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": request.message},
            ],
            max_tokens=500,
            temperature=0.7,
        )

        avatar_response = response.choices[0].message.content

        # Generate TTS with visemes for the response
        tts_result = await tts_service.synthesize_with_visemes(avatar_response)

        return {
            "text_response": avatar_response,
            "tts_data": {
                "audio_base64": tts_result["audio_base64"],
                "visemes": tts_result["visemes"],
                "duration_ms": tts_result["duration_ms"],
            },
            "avatar_state": "speaking",
            "timestamp": datetime.now(),
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Chat and speak failed: {str(e)}")


@app.websocket("/ws/avatar")
async def websocket_avatar_stream(websocket: WebSocket):
    """WebSocket for real-time avatar control and streaming"""
    await websocket.accept()

    try:
        while True:
            # Receive commands from client
            data = await websocket.receive_json()
            command = data.get("command")

            if command == "speak":
                text = data.get("text", "")
                if text:
                    # Generate TTS with visemes
                    tts_result = await tts_service.synthesize_with_visemes(text)

                    # Send back audio and viseme data
                    await websocket.send_json(
                        {
                            "type": "tts_data",
                            "audio_base64": tts_result["audio_base64"],
                            "visemes": tts_result["visemes"],
                            "duration_ms": tts_result["duration_ms"],
                        }
                    )

            elif command == "gesture":
                gesture_type = data.get("gesture", "nod")
                await websocket.send_json(
                    {
                        "type": "gesture",
                        "animation": gesture_type,
                        "duration": 2000,  # 2 seconds
                    }
                )

            elif command == "idle":
                await websocket.send_json(
                    {
                        "type": "state_change",
                        "state": "idle",
                        "animation": "idle_breathe",
                    }
                )

    except Exception as e:
        print(f"WebSocket error: {e}")
    finally:
        await websocket.close()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=os.getenv("HOST", "127.0.0.1"), port=8000)
