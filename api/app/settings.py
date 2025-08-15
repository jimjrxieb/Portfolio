from pydantic import AnyHttpUrl, Field
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Public site base used to construct URLs for /uploads/**
    PUBLIC_BASE_URL: AnyHttpUrl
    DATA_DIR: str = "/data"

    # ElevenLabs/D-ID (for avatar)
    ELEVENLABS_API_KEY: str | None = None
    ELEVENLABS_DEFAULT_VOICE_ID: str = "EXAVITQu4vr4xnSDxMaL"
    DID_API_KEY: str | None = None

    # LLM (OpenAI-compatible; works with vLLM/LM Studio/Ollama/OpenRouter)
    LLM_API_BASE: AnyHttpUrl
    LLM_API_KEY: str = Field("", description="Pass empty if your local server allows no key")
    LLM_MODEL_ID: str = "phi3:latest"

    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()