import uuid
import os
import httpx
from app.settings import settings

ELEVEN_TTS_URL_TMPL = "https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"


async def synthesize_tts_mp3(
    text: str,
    voice_id: str,
    model_id: str = "eleven_monolingual_v1",
    stability: float = 0.3,
    similarity_boost: float = 0.75,
) -> str:
    """
    Returns a local file path to the saved MP3 under /data/uploads/audio/{uuid}.mp3.
    """
    out_dir = os.path.join(settings.DATA_DIR, "uploads", "audio")
    os.makedirs(out_dir, exist_ok=True)
    file_id = f"{uuid.uuid4()}.mp3"
    out_path = os.path.join(out_dir, file_id)

    headers = {
        "xi-api-key": settings.ELEVENLABS_API_KEY or "",
        "accept": "audio/mpeg",
        "content-type": "application/json",
    }
    payload = {
        "text": text,
        "model_id": model_id,
        "voice_settings": {
            "stability": stability,
            "similarity_boost": similarity_boost,
        },
    }
    url = ELEVEN_TTS_URL_TMPL.format(voice_id=voice_id)

    timeout = httpx.Timeout(30.0, connect=10.0)
    async with httpx.AsyncClient(timeout=timeout) as client:
        resp = await client.post(url, headers=headers, json=payload)
        resp.raise_for_status()
        with open(out_path, "wb") as f:
            f.write(resp.content)

    return out_path
