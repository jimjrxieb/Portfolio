from pydantic import BaseModel, AnyHttpUrl, constr

class TTSRequest(BaseModel):
    model_config = {"protected_namespaces": ()}
    
    text: constr(strip_whitespace=True, min_length=1, max_length=4000)
    voice_id: str | None = None
    model_id: str | None = "eleven_monolingual_v1"
    stability: float | None = 0.3
    similarity_boost: float | None = 0.75

class TTSResponse(BaseModel):
    url: AnyHttpUrl

class TalkRequest(BaseModel):
    text: constr(strip_whitespace=True, min_length=1, max_length=4000)
    image_url: AnyHttpUrl
    voice_id: str | None = None  # if omitted, uses default

class TalkResponse(BaseModel):
    talk_id: str
    status: str
    result_url: AnyHttpUrl | None = None