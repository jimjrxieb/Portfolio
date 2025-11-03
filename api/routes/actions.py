# Avatar actions with fallback handling
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse, FileResponse
from uuid import uuid4
from pathlib import Path
import os
import settings

router = APIRouter(prefix="/api/actions/avatar", tags=["avatar"])

DATA_DIR = Path(settings.DATA_DIR).resolve()
UPLOADS = DATA_DIR / "uploads"
ASSETS = DATA_DIR / "assets"
UPLOADS.mkdir(parents=True, exist_ok=True)
ASSETS.mkdir(parents=True, exist_ok=True)

# Seed a default intro if present in container (copied from UI/public/intro.mp3 during build)
DEFAULT_INTRO = Path(os.getenv("DEFAULT_INTRO", "/app/default_intro.mp3"))
DEFAULT_VOICE = os.getenv("DEFAULT_VOICE", settings.ELEVENLABS_DEFAULT_VOICE_ID)


def elevenlabs_enabled():
    return bool(settings.ELEVENLABS_API_KEY)


def did_enabled():
    return bool(settings.DID_API_KEY)


@router.post("/create")
async def create_avatar(photo: UploadFile = File(...), voice: str = Form(None)):
    if not photo.content_type or not photo.content_type.startswith("image/"):
        raise HTTPException(400, "photo must be an image/*")

    avatar_id = f"av_{uuid4().hex[:10]}"
    dest = UPLOADS / f"{avatar_id}.jpg"

    with dest.open("wb") as f:
        f.write(await photo.read())

    return {"avatar_id": avatar_id}


@router.post("/talk")
async def talk(payload: dict):
    text = payload.get("text", "")
    voice = payload.get("voice")

    if not text:
        raise HTTPException(400, "text is required")

    # If ElevenLabs is configured, call TTS service
    if elevenlabs_enabled():
        try:
            from app.services.elevenlabs import synthesize_tts_mp3

            voice_id = voice or DEFAULT_VOICE
            mp3_path = await synthesize_tts_mp3(
                text=text,
                voice_id=voice_id,
                model_id="eleven_monolingual_v1",
                stability=0.3,
                similarity_boost=0.75,
            )
            # Return relative URL that gets served by assets endpoint
            rel_path = os.path.relpath(mp3_path, DATA_DIR)
            return {"url": f"/api/assets/{rel_path}"}
        except Exception:
            # Fall back to default intro on TTS failure
            import logging

            logging.warning("Unhandled exception occurred")

    # Fallback: return a stable local intro mp3
    if DEFAULT_INTRO.exists():
        return {"url": "/api/assets/default-intro"}

    # Create a minimal silence file as last resort
    silent = ASSETS / "silence.mp3"
    if not silent.exists():
        # Create a minimal MP3 file (this is a placeholder - ideally ship a real silent MP3)
        silent.write_bytes(b"")

    return {"url": "/api/assets/silence"}


@router.get("/photo/{avatar_id}")
async def avatar_photo(avatar_id: str):
    path = UPLOADS / f"{avatar_id}.jpg"
    if not path.exists():
        raise HTTPException(404, "not found")
    return JSONResponse({"url": f"/api/assets/uploads/{avatar_id}.jpg"})


# Simple static file server for assets (photo + audio)
assets_router = APIRouter()


@assets_router.get("/api/assets/{path:path}")
def serve_asset(path: str):
    import re

    # Security: Comprehensive path traversal protection
    # Reject any path with directory traversal attempts
    if ".." in path or path.startswith("/") or "\\" in path:
        raise HTTPException(status_code=404, detail="Invalid path")

    # Additional security: only allow alphanumeric, dash, underscore, dot, and forward slash
    if not re.match(r"^[a-zA-Z0-9._/-]+$", path):
        raise HTTPException(status_code=404, detail="Invalid path characters")

    # Normalize and validate path
    try:
        # Sanitize the input path - remove any potentially dangerous components
        sanitized_path = path.strip().replace("\\", "").replace("..", "")

        # Check uploads first
        clean_path = sanitized_path.replace("uploads/", "")
        up_path = (UPLOADS / clean_path).resolve()

        # Ensure the resolved path is within the uploads directory
        if (
            up_path.is_relative_to(UPLOADS.resolve())
            and up_path.exists()
            and up_path.is_file()
        ):
            # Additional security check: ensure the final path is safe
            if ".." not in str(up_path) and str(up_path).startswith(
                str(UPLOADS.resolve())
            ):
                return FileResponse(up_path)

        # Then assets directory
        asset_path = (ASSETS / sanitized_path).resolve()

        # Ensure the resolved path is within the assets directory
        if (
            asset_path.is_relative_to(ASSETS.resolve())
            and asset_path.exists()
            and asset_path.is_file()
        ):
            # Additional security check: ensure the final path is safe
            if ".." not in str(asset_path) and str(asset_path).startswith(
                str(ASSETS.resolve())
            ):
                return FileResponse(asset_path)

    except (ValueError, OSError):
        # Handle any path resolution errors
        raise HTTPException(status_code=404, detail="File not found")

    # Special cases for fallbacks - only allow exact matches
    if path == "default-intro" and DEFAULT_INTRO.exists():
        return FileResponse(DEFAULT_INTRO, media_type="audio/mpeg")

    if path == "silence":
        silent_path = ASSETS / "silence.mp3"
        if silent_path.exists():
            return FileResponse(silent_path, media_type="audio/mpeg")

    raise HTTPException(404, "asset not found")


@router.get("/rag/count")
def rag_count(namespace: str = None):
    """Get count of documents in RAG collection"""
    ns = namespace or settings.RAG_NAMESPACE

    try:
        from app.engines.rag_engine import RAGEngine

        engine = RAGEngine()
        collection = engine.get_collection(ns)

        # Try to get count directly
        try:
            count = collection.count()
        except Exception:
            # Fallback: get all documents and count them
            docs = collection.get(limit=1_000_000)
            count = len(docs.get("documents", []))

        return {"namespace": ns, "count": count}
    except Exception as e:
        raise HTTPException(500, f"RAG count failed: {e}")
