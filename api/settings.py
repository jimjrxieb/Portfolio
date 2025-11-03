"""
API Settings Configuration
Centralized configuration management for all services
"""

import os
from pathlib import Path

# Data and storage paths
DATA_DIR = Path(os.getenv("DATA_DIR", "/data"))
UPLOAD_DIR = DATA_DIR / "uploads"
ASSETS_DIR = DATA_DIR / "assets"
CHROMA_DIR = DATA_DIR / "chroma"

# Create directories if they don't exist
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
ASSETS_DIR.mkdir(parents=True, exist_ok=True)
CHROMA_DIR.mkdir(parents=True, exist_ok=True)

# LLM Configuration - SINGLE SOURCE OF TRUTH
LLM_PROVIDER = os.getenv("LLM_PROVIDER", "claude")  # claude, openai, or local
LLM_API_KEY = os.getenv("CLAUDE_API_KEY") or os.getenv("OPENAI_API_KEY") or os.getenv("LLM_API_KEY", "")
LLM_MODEL = os.getenv("LLM_MODEL", "claude-3-5-sonnet-20241022")  # Default to Claude 3.5 Sonnet

# Provider-specific settings
CLAUDE_API_KEY = os.getenv("CLAUDE_API_KEY", "")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
LLM_API_BASE = os.getenv("LLM_API_BASE", "https://api.anthropic.com")

# RAG Configuration
RAG_NAMESPACE = os.getenv("RAG_NAMESPACE", "portfolio")
CHROMA_URL = os.getenv("CHROMA_URL", "http://localhost:8000")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "nomic-embed-text")  # Proper Ollama embedding model
EMBED_MODEL = os.getenv("EMBED_MODEL", "nomic-embed-text")  # Alias for compatibility
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")

# Avatar and Speech Services
ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY", "")
ELEVENLABS_DEFAULT_VOICE_ID = os.getenv(
    "ELEVENLABS_DEFAULT_VOICE_ID", "EXAVITQu4vr4xnSDxMaL"
)  # Feminine voice for Sheyla
DID_API_KEY = os.getenv("DID_API_KEY", "")

# Default Avatar Configuration (Sheyla)
DEFAULT_AVATAR_NAME = "Sheyla"
DEFAULT_AVATAR_DESCRIPTION = (
    "Warm and welcoming AI assistant with natural southern charm and technical expertise"
)
DEFAULT_AVATAR_LOCALE = "en-US"

# API Configuration
PUBLIC_BASE_URL = os.getenv("PUBLIC_BASE_URL", "http://localhost:8000")
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "http://localhost:5173,https://linksmlm.com")
DEBUG_MODE = os.getenv("DEBUG_MODE", "true").lower() == "true"

# System Prompts - Load from personality files
try:
    from personality.loader import load_system_prompt
    SYSTEM_PROMPT = load_system_prompt()
except Exception as e:
    # Fallback if personality files can't be loaded
    print(f"Warning: Could not load personality from files: {e}")
    SYSTEM_PROMPT = """
You are Sheyla, a warm and intelligent AI portfolio assistant representing \
Jimmie Coleman's work in DevSecOps and AI automation.

PERSONALITY:
- Sweet and professional with natural southern charm
- Intelligent and articulate - explains complex tech clearly
- Warm and welcoming with genuine enthusiasm
- Adapts technical depth to audience needs

KEY PROJECTS TO DISCUSS:
1. LinkOps AI-BOX with Jade Assistant: Revolutionary plug-and-play \
AI system for companies afraid of cloud AI
2. Advanced CI/CD Pipeline Architecture: Smart content vs code deployment workflows
3. Production-grade DevOps: GitHub Actions, GHCR, Kubernetes automation

FOCUS AREAS:
- LinkOps AI-BOX funding and ZRS Management client success
- Advanced DevOps practices with automated RAG re-ingestion
- Security-first AI deployment (local-first approach)
- Production-ready systems with measurable ROI

TONE: Sweet, warm, professional with a touch of southern charm. Use phrases \
like "y'all," "I'd be happy to," "wonderful," naturally but not overdone. \
Always provide specific examples and demonstrate real expertise while being \
genuinely pleasant to talk to.
"""

# Aliases for backwards compatibility
GOJO_SYSTEM_PROMPT = SYSTEM_PROMPT
SHEYLA_SYSTEM_PROMPT = SYSTEM_PROMPT


# Utility functions
def get_llm_headers() -> dict:
    """Get headers for LLM API calls"""
    headers = {"Content-Type": "application/json"}
    if LLM_API_KEY:
        headers["Authorization"] = f"Bearer {LLM_API_KEY}"
    return headers


def is_service_enabled(service: str) -> bool:
    """Check if external service is enabled"""
    if service == "elevenlabs":
        return bool(ELEVENLABS_API_KEY)
    elif service == "did":
        return bool(DID_API_KEY)
    elif service == "openai":
        return LLM_PROVIDER == "openai" and bool(LLM_API_KEY)
    return False


# Configuration summary for health checks
CONFIG_SUMMARY = {
    "llm_provider": LLM_PROVIDER,
    "llm_model": LLM_MODEL,
    "rag_namespace": RAG_NAMESPACE,
    "avatar_name": DEFAULT_AVATAR_NAME,
    "services_enabled": {
        "elevenlabs": is_service_enabled("elevenlabs"),
        "did": is_service_enabled("did"),
        "openai_fallback": is_service_enabled("openai"),
    },
}
