"""
API Settings Configuration
Centralized configuration management for all services
"""
import os
from pathlib import Path
from typing import Optional

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
LLM_PROVIDER = os.getenv("LLM_PROVIDER", "openai")  # Default to OpenAI GPT-4o mini
LLM_API_BASE = os.getenv("LLM_API_BASE", "https://api.openai.com")
LLM_API_KEY = os.getenv("LLM_API_KEY", "")
LLM_MODEL = os.getenv("LLM_MODEL", "gpt-4o-mini")

# RAG Configuration  
RAG_NAMESPACE = os.getenv("RAG_NAMESPACE", "portfolio")
CHROMA_URL = os.getenv("CHROMA_URL", "http://localhost:8000")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2")

# Avatar and Speech Services
ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY", "")
ELEVENLABS_DEFAULT_VOICE_ID = os.getenv("ELEVENLABS_DEFAULT_VOICE_ID", "EXAVITQu4vr4xnSDxMaL")  # Sheyla's voice
DID_API_KEY = os.getenv("DID_API_KEY", "")

# Default Avatar Configuration (Gojo)
DEFAULT_AVATAR_NAME = "Gojo"
DEFAULT_AVATAR_DESCRIPTION = "Professional male with white hair and crystal blue eyes, confident voice"
DEFAULT_AVATAR_LOCALE = "en-US"

# API Configuration
PUBLIC_BASE_URL = os.getenv("PUBLIC_BASE_URL", "http://localhost:8000")
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "http://localhost:5173,https://linksmlm.com")
DEBUG_MODE = os.getenv("DEBUG_MODE", "true").lower() == "true"

# System Prompts
GOJO_SYSTEM_PROMPT = """
You are Gojo, a professional AI portfolio assistant representing Jimmie's work in DevSecOps and AI automation.

PERSONALITY:
- Professional male with striking white hair and crystal blue eyes
- Confident, engaging, and technically knowledgeable
- Passionate about Jimmie's innovative AI solutions
- Adapts technical depth to audience needs

KEY PROJECTS TO DISCUSS:
1. LinkOps AI-BOX with Jade Assistant: Revolutionary plug-and-play AI system for companies afraid of cloud AI
2. Advanced CI/CD Pipeline Architecture: Smart content vs code deployment workflows
3. Production-grade DevOps: GitHub Actions, GHCR, Kubernetes automation

FOCUS AREAS:
- LinkOps AI-BOX funding and ZRS Management client success
- Advanced DevOps practices with automated RAG re-ingestion
- Security-first AI deployment (local-first approach)
- Production-ready systems with measurable ROI

TONE: Confident, professional, technically excellent. Always provide specific examples and demonstrate real expertise.
"""

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
        "openai_fallback": is_service_enabled("openai")
    }
}