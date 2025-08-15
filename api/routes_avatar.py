from fastapi import APIRouter, HTTPException
from schemas import TTSRequest, TTSResponse, TalkRequest, TalkResponse
from services.elevenlabs import synthesize_tts_mp3
from services.did import create_talk_with_audio, get_talk_status
from mcp_client import mcp_client
from pydantic import BaseModel
from settings import settings
import os

router = APIRouter(prefix="/api", tags=["avatar"])

class MCPAvatarRequest(BaseModel):
    text: str
    image_url: str
    voice_style: str = "default"

class MCPAvatarResponse(BaseModel):
    result: str
    status: str

def _public_upload_url(local_path: str) -> str:
    # Map local /data/uploads/** -> PUBLIC_BASE_URL/uploads/**
    rel = os.path.relpath(local_path, settings.DATA_DIR).replace(os.path.sep, "/")
    return f"{settings.PUBLIC_BASE_URL}/{rel}"

@router.post("/voice/tts", response_model=TTSResponse)
async def tts(req: TTSRequest):
    try:
        voice = req.voice_id or settings.ELEVENLABS_DEFAULT_VOICE_ID
        mp3_path = await synthesize_tts_mp3(
            text=req.text,
            voice_id=voice,
            model_id=req.model_id or "eleven_monolingual_v1",
            stability=req.stability or 0.3,
            similarity_boost=req.similarity_boost or 0.75,
        )
        return {"url": _public_upload_url(mp3_path)}
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"TTS failed: {e}")

@router.post("/avatar/talk", response_model=TalkResponse)
async def talk(req: TalkRequest):
    try:
        # 1) Make speech with ElevenLabs
        voice = req.voice_id or settings.ELEVENLABS_DEFAULT_VOICE_ID
        mp3_path = await synthesize_tts_mp3(
            text=req.text, voice_id=voice,
            model_id="eleven_monolingual_v1", stability=0.3, similarity_boost=0.75
        )
        audio_url = _public_upload_url(mp3_path)

        # 2) Ask D-ID to lip-sync your image with the audio
        created = await create_talk_with_audio(req.image_url, audio_url)
        return {
            "talk_id": created.get("id", ""),
            "status": created.get("status", "created"),
            "result_url": created.get("result_url")
        }
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Avatar creation failed: {e}")

@router.get("/avatar/talk/{talk_id}", response_model=TalkResponse)
async def talk_status(talk_id: str):
    try:
        data = await get_talk_status(talk_id)
        return {
            "talk_id": data.get("id", talk_id),
            "status": data.get("status", "unknown"),
            "result_url": data.get("result_url")
        }
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Avatar status failed: {e}")

@router.post("/avatar/create-mcp", response_model=MCPAvatarResponse)
async def create_avatar_mcp(req: MCPAvatarRequest):
    """
    MCP-powered avatar creation with enhanced error handling and tool integration.
    This endpoint uses the MCP client for improved reliability.
    """
    try:
        result = await mcp_client.create_avatar_with_text(
            text=req.text,
            image_url=req.image_url,
            voice_style=req.voice_style
        )
        
        # Determine status from result
        if "Avatar video ready:" in result:
            status = "completed"
        elif "Avatar still processing" in result:
            status = "processing"
        elif "failed" in result.lower():
            status = "error"
        else:
            status = "unknown"
        
        return {
            "result": result,
            "status": status
        }
        
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"MCP avatar creation failed: {e}")