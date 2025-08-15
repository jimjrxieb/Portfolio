import base64, httpx
import sys
sys.path.append('/app')
from settings import settings

DID_TALKS_URL = "https://api.d-id.com/talks"          # REST create
DID_TALK_STATUS_URL = "https://api.d-id.com/talks/{id}"  # GET status

def _auth() -> dict:
    token = base64.b64encode(f"{settings.DID_API_KEY or ''}:".encode()).decode()
    return {"Authorization": f"Basic {token}"}

async def create_talk_with_audio(image_url: str, audio_url: str) -> dict:
    """
    Creates a D-ID talk using a static image and a hosted audio file.
    Returns the JSON payload (contains 'id', 'status', possibly 'result_url').
    """
    payload = {
        "source_url": image_url,
        # Use pre-generated audio from ElevenLabs
        "audio_url": audio_url,
        # You can add 'config' keys here (background, stitch, driver_url, etc.)
    }
    headers = {"accept": "application/json", "content-type": "application/json", **_auth()}
    async with httpx.AsyncClient(timeout=30.0) as client:
        r = await client.post(DID_TALKS_URL, headers=headers, json=payload)
        r.raise_for_status()
        return r.json()

async def get_talk_status(talk_id: str) -> dict:
    headers = {"accept": "application/json", **_auth()}
    url = DID_TALK_STATUS_URL.format(id=talk_id)
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.get(url, headers=headers)
        r.raise_for_status()
        return r.json()